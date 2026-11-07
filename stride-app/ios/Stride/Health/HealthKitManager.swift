import Foundation
import HealthKit

/// Apple 健康双向同步。
/// 读：步数 / 活动能量 / 心率 / 体重；写：训练能量 + 训练记录。
/// 需要在 Xcode 的 Signing & Capabilities 里加 HealthKit（真机才有数据，模拟器返回空）。
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    @Published var available = HKHealthStore.isHealthDataAvailable()
    @Published var authorized = false
    @Published var lastError: String?
    @Published var lastSync: Date?

    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let step = HKObjectType.quantityType(forIdentifier: .stepCount) { set.insert(step) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(energy) }
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { set.insert(hr) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(mass) }
        return set
    }

    private var shareTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { set.insert(energy) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { set.insert(mass) }
        return set
    }

    // MARK: - 授权

    func requestAuthorization() async {
        guard available else {
            lastError = "这台设备没有 Apple 健康"
            return
        }
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                store.requestAuthorization(toShare: shareTypes, read: readTypes) { ok, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else if ok {
                        cont.resume(returning: ())
                    } else {
                        cont.resume(throwing: HKError(.errorAuthorizationDenied))
                    }
                }
            }
            authorized = true
            lastError = nil
        } catch {
            authorized = false
            lastError = readable(error)
        }
    }

    // MARK: - 读

    struct DayMetrics {
        var steps: Int = 0
        var activeKcal: Int = 0
        var restingHR: Int = 0
        var weightKg: Double = 0
    }

    func todayMetrics() async -> DayMetrics {
        var result = DayMetrics()
        guard available else { return result }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        if let steps = await sum(.stepCount, predicate: predicate) {
            result.steps = Int(steps)
        }
        if let energy = await sum(.activeEnergyBurned, predicate: predicate) {
            result.activeKcal = Int(energy)
        }
        if let hr = await latest(.heartRate) {
            result.restingHR = Int(hr)
        }
        if let mass = await latest(.bodyMass) {
            result.weightKg = mass
        }
        lastSync = Date()
        return result
    }

    private func sum(_ id: HKQuantityTypeIdentifier, predicate: NSPredicate) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: Self.unit(for: id))
                cont.resume(returning: value)
            }
            store.execute(q)
        }
    }

    private func latest(_ id: HKQuantityTypeIdentifier) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { cont in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: sort) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                cont.resume(returning: sample?.quantity.doubleValue(for: Self.unit(for: id)))
            }
            store.execute(q)
        }
    }

    private static func unit(for id: HKQuantityTypeIdentifier) -> HKUnit {
        switch id {
        case .stepCount: return .count()
        case .activeEnergyBurned: return .kilocalorie()
        case .heartRate: return HKUnit.count().unitDivided(by: .minute())
        case .bodyMass: return .gramUnit(with: .kilo)
        default: return .count()
        }
    }

    // MARK: - 写

    func save(workout session: WorkoutSession) async -> Bool {
        guard available else { return false }
        let end = session.date.addingTimeInterval(TimeInterval(max(60, session.durationSec)))
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration(for: session.kind), device: .local())

        do {
            try await builder.beginCollection(at: session.date)
            if session.kcal > 0,
               let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                let sample = HKQuantitySample(
                    type: energyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(session.kcal)),
                    start: session.date,
                    end: end
                )
                try await builder.addSamples([sample])
            }
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            lastSync = Date()
            return true
        } catch {
            lastError = readable(error)
            return false
        }
    }

    private func configuration(for kind: SessionKind) -> HKWorkoutConfiguration {
        let c = HKWorkoutConfiguration()
        switch kind {
        case .strength:
            c.activityType = .traditionalStrengthTraining
        case .run:
            c.activityType = .running
        case .ride:
            c.activityType = .cycling
        case .mobility:
            c.activityType = .flexibility
        }
        return c
    }

    private func readable(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == HKErrorDomain {
            switch ns.code {
            case HKError.errorAuthorizationDenied.rawValue:
                return "健康权限被拒绝：到 设置 → 健康 → 数据访问 里打开"
            case HKError.errorHealthDataUnavailable.rawValue:
                return "健康数据不可用（模拟器常见）"
            default:
                return "健康错误 \(ns.code)"
            }
        }
        return error.localizedDescription
    }
}
