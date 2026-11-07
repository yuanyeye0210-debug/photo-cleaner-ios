import Foundation
import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {

    @Published var state: AppState {
        didSet { scheduleSave() }
    }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private let calendar = Calendar.current

    // MARK: - 生命周期

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stride", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("state.json")
        self.fileURL = url

        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            self.state = decoded
        } else {
            self.state = AppState()
        }

        if !state.seeded {
            SeedData.seed(&state)
            state.seeded = true
            saveNow()
        }
    }

    // MARK: - 持久化

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Stride] save failed:", error)
        }
    }

    // MARK: - 派生数据

    var todaySessions: [WorkoutSession] {
        state.sessions.filter { calendar.isDateInToday($0.date) }
    }

    var weekSessions: [WorkoutSession] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return state.sessions
            .filter { $0.date >= start }
            .sorted { $0.date > $1.date }
    }

    var recentSessions: [WorkoutSession] {
        state.sessions.sorted { $0.date > $1.date }
    }

    var todayNutrition: (kcal: Double, p: Double, c: Double, f: Double) {
        let today = state.foods.filter { calendar.isDateInToday($0.date) }
        return (
            today.reduce(0) { $0 + $1.kcal },
            today.reduce(0) { $0 + $1.protein },
            today.reduce(0) { $0 + $1.carbs },
            today.reduce(0) { $0 + $1.fat }
        )
    }

    var todayFoods: [FoodEntry] {
        state.foods
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    var todaySnapshot: DailySnapshot {
        if let s = state.snapshots.first(where: { calendar.isDateInToday($0.date) }) { return s }
        return DailySnapshot(date: Date(), steps: 0, activeKcal: 0, exerciseMin: 0, restingHR: 0, weightKg: state.profile.weightKg)
    }

    var streak: Int {
        var count = 0
        var day = calendar.startOfDay(for: Date())
        let days = Set(state.sessions.map { calendar.startOfDay(for: $0.date) })
        while days.contains(day) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var weeklyVolume: [WeekVolume] {
        var buckets: [Date: Double] = [:]
        for s in state.sessions {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: s.date)?.start else { continue }
            buckets[start, default: 0] += s.totalVolume
        }
        return buckets
            .map { WeekVolume(week: $0.key, volume: $0.value) }
            .sorted { $0.week < $1.week }
    }

    var kcalSeries: [(day: Date, kcal: Int)] {
        state.snapshots
            .sorted { $0.date < $1.date }
            .map { (day: $0.date, kcal: $0.activeKcal) }
    }

    func personalBest(for exerciseName: String) -> Double {
        state.sessions
            .flatMap(\.exercises)
            .filter { $0.name == exerciseName }
            .map(\.topWeight)
            .max() ?? 0
    }

    func history(for exerciseName: String) -> [(date: Date, e1rm: Double)] {
        var result: [(Date, Double)] = []
        for s in state.sessions.sorted(by: { $0.date < $1.date }) {
            for ex in s.exercises where ex.name == exerciseName {
                if let best = ex.doneSets.max(by: { $0.weight < $1.weight }), best.weight > 0 {
                    result.append((s.date, ProgressiveEngine.e1RM(weight: best.weight, reps: best.reps)))
                }
            }
        }
        return result
    }

    // MARK: - 变更

    func addSession(_ session: WorkoutSession) {
        state.sessions.insert(session, at: 0)
        if let idx = state.snapshots.firstIndex(where: { calendar.isDateInToday($0.date) }) {
            state.snapshots[idx].exerciseMin += max(1, session.durationSec / 60)
            state.snapshots[idx].activeKcal += session.kcal
        } else {
            state.snapshots.append(
                DailySnapshot(
                    date: Date(),
                    steps: 0,
                    activeKcal: session.kcal,
                    exerciseMin: max(1, session.durationSec / 60),
                    restingHR: 0,
                    weightKg: state.profile.weightKg
                )
            )
        }
    }

    func deleteSession(id: UUID) {
        state.sessions.removeAll { $0.id == id }
    }

    func addFood(_ entry: FoodEntry) {
        state.foods.insert(entry, at: 0)
    }

    func deleteFood(id: UUID) {
        state.foods.removeAll { $0.id == id }
    }

    func addRun(_ run: RouteRun) {
        state.runs.insert(run, at: 0)
    }

    func updateRun(_ run: RouteRun) {
        if let idx = state.runs.firstIndex(where: { $0.id == run.id }) {
            state.runs[idx] = run
        }
    }

    func appendChat(_ turn: ChatTurn) {
        state.chats.append(turn)
    }

    func clearChat() {
        state.chats = []
    }

    func setPlan(_ plan: TrainingPlan) {
        state.plan = plan
    }

    func resetTodayQuotas() {
        state.quotas.reset("food")
        saveNow()
    }

    // MARK: - 今天的训练建议

    var todaysPlannedDay: PlannedDay? {
        guard let plan = state.plan else { return nil }
        let weekday = calendar.component(.weekday, from: Date())
        return plan.days.first { $0.weekday == weekday && !$0.rest }
    }

    func exercise(named name: String) -> Exercise? {
        state.exercises.first { $0.name == name }
    }
}
