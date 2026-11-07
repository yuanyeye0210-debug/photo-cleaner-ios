import Foundation

/// 渐进式超负荷 + 自感强度（RPE）自动调节。
/// 这是"渐进式 AI 学习"的本地内核：不联网也能给出下一次该加多少。
enum ProgressiveEngine {

    /// Epley 公式估 1RM
    static func e1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    /// 训练量（组数 × 次数 × 重量）
    static func volume(sets: [SetEntry]) -> Double {
        sets.filter(\.done).reduce(0) { $0 + $1.volume }
    }

    /// 估算一次力量训练的净训练量指数（用于周负荷监控）
    static func loadIndex(sets: [SetEntry], rpe: Double?) -> Double {
        let v = volume(sets: sets)
        guard let rpe, rpe > 0 else { return v }
        return v * (rpe / 8.0)
    }

    struct Suggestion {
        var weight: Double
        var reps: Int
        var sets: Int
        var headline: String
        var detail: String
    }

    /// 依据最近一次表现给出下一次的处方
    static func suggest(
        lastSets: [SetEntry],
        referenceWeight: Double,
        referenceReps: Int,
        goal: Goal
    ) -> Suggestion {
        let done = lastSets.filter(\.done)
        guard let best = done.max(by: { $0.weight < $1.weight }) else {
            return Suggestion(
                weight: referenceWeight,
                reps: referenceReps,
                sets: 3,
                headline: "首次记录",
                detail: "从 \(fmt(referenceWeight)) kg × \(referenceReps) 开始，留 2 次余力。"
            )
        }

        let avgRPE = done.compactMap(\.rpe).reduce(0, +) / Double(max(1, done.compactMap(\.rpe).count))
        let hitAllReps = done.allSatisfy { $0.reps >= referenceReps }
        let increment: Double = best.weight >= 60 ? 2.5 : (best.weight >= 20 ? 2.0 : 1.0)

        var weight = best.weight
        var reps = best.reps
        var headline = "维持负荷"
        var detail = "上次 \(fmt(best.weight)) kg × \(best.reps) 完成度不错，这次先把动作质量做满。"

        if avgRPE >= 9.3 {
            weight = max(0, best.weight - increment)
            reps = referenceReps
            headline = "主动减载"
            detail = "上次 RPE \(fmt1(avgRPE)) 偏高，降 \(fmt(increment)) kg 换取恢复，别硬顶。"
        } else if hitAllReps && avgRPE <= 8.6 {
            if best.reps >= referenceReps + 2 && goal != .cut {
                weight = best.weight + increment
                reps = referenceReps
                headline = "加重量"
                detail = "上次 \(best.reps) 次还有余力，加到 \(fmt(weight)) kg 回到 \(referenceReps) 次区间。"
            } else {
                reps = best.reps + 1
                headline = "加次数"
                detail = "重量不动，把 \(best.reps) 次推到 \(reps) 次；到 \(referenceReps + 2) 次再加重量。"
            }
        } else if !hitAllReps {
            reps = max(referenceReps - 2, 3)
            headline = "减次数保质量"
            detail = "上次有组没做满，这次把每组次数降到 \(reps)，先把目标次数吃干净。"
        }

        return Suggestion(
            weight: weight,
            reps: reps,
            sets: max(3, min(5, done.count)),
            headline: headline,
            detail: detail
        )
    }

    /// 本周每个肌群的组数是否达标（10–20 组 / 周）
    static func weeklySetBalance(sessions: [WorkoutSession], calendar: Calendar = .current) -> [MuscleGroup: Int] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [:] }
        var result: [MuscleGroup: Int] = [:]
        for s in sessions where s.date >= start {
            for ex in s.exercises {
                result[ex.group, default: 0] += ex.doneSets.count
            }
        }
        return result
    }

    /// 连续两周负荷下降超过 25% → 建议减载周
    static func needsDeload(weeklyVolumes: [Double]) -> Bool {
        guard weeklyVolumes.count >= 2 else { return false }
        let last = weeklyVolumes[weeklyVolumes.count - 1]
        let prev = weeklyVolumes[weeklyVolumes.count - 2]
        guard prev > 0 else { return false }
        return last < prev * 0.75
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private static func fmt1(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}
