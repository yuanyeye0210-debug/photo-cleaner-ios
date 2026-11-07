import Foundation

/// 本地周期化生成器：不联网也能产出 4 周计划。
/// 训练日的选择基于每周天数，动作基于动作库，组次基于经验水平。
enum PlanGenerator {

    static func generate(goal: Goal, days: Int, experience: Experience) -> TrainingPlan {
        let split = splitTemplate(days: max(3, min(6, days)))
        var planned: [PlannedDay] = []

        // 训练日优先落在 周一/二/四/五/六/日（1 = 周日）
        let weekdayOrder = [2, 3, 5, 6, 4, 7]
        var trainingDays = Set(weekdayOrder.prefix(split.count))

        for weekday in 1...7 {
            if trainingDays.contains(weekday),
               let idx = weekdayOrder.firstIndex(of: weekday),
               idx < split.count {
                let day = split[idx]
                planned.append(
                    PlannedDay(
                        weekday: weekday,
                        title: day.title,
                        focus: day.focus,
                        exercises: exercises(for: day, goal: goal, experience: experience),
                        rest: false
                    )
                )
            } else {
                planned.append(
                    PlannedDay(
                        weekday: weekday,
                        title: "恢复",
                        focus: nil,
                        exercises: [
                            PlannedExercise(name: "快走 20 分钟", sets: 1, reps: "20 min", note: "心率 110 左右"),
                            PlannedExercise(name: "髋与胸椎活动度", sets: 3, reps: "8 次/侧", note: "慢速，不追幅度")
                        ],
                        rest: true
                    )
                )
            }
        }
        _ = trainingDays

        return TrainingPlan(
            createdAt: Date(),
            goal: goal,
            weeks: 4,
            days: planned.sorted { $0.weekday < $1.weekday },
            generatedBy: "progressive-engine"
        )
    }

    // MARK: - 分化模板

    private struct SplitDay {
        let title: String
        let focus: MuscleGroup?
        let exerciseNames: [String]
    }

    private static func splitTemplate(days: Int) -> [SplitDay] {
        switch days {
        case 3:
            return [
                SplitDay(title: "全身 A · 蹲", focus: .legs, exerciseNames: ["深蹲", "杠铃卧推", "杠铃划船", "平板支撑"]),
                SplitDay(title: "全身 B · 髋", focus: .back, exerciseNames: ["罗马尼亚硬拉", "站姿推举", "引体向上", "悬垂举腿"]),
                SplitDay(title: "全身 C · 推", focus: .chest, exerciseNames: ["上斜哑铃卧推", "高位下拉", "保加利亚分腿蹲", "面拉"])
            ]
        case 4:
            return [
                SplitDay(title: "推 · 胸肩三头", focus: .chest, exerciseNames: ["杠铃卧推", "上斜哑铃卧推", "哑铃侧平举", "绳索下压"]),
                SplitDay(title: "拉 · 背二头", focus: .back, exerciseNames: ["引体向上", "杠铃划船", "坐姿绳索划船", "杠铃弯举"]),
                SplitDay(title: "腿 · 股四", focus: .legs, exerciseNames: ["深蹲", "腿举", "保加利亚分腿蹲", "站姿提踵"]),
                SplitDay(title: "上肢 · 容量", focus: .shoulders, exerciseNames: ["站姿推举", "高位下拉", "绳索夹胸", "面拉"])
            ]
        case 5:
            return [
                SplitDay(title: "推", focus: .chest, exerciseNames: ["杠铃卧推", "上斜哑铃卧推", "哑铃侧平举", "绳索下压"]),
                SplitDay(title: "拉", focus: .back, exerciseNames: ["引体向上", "杠铃划船", "高位下拉", "锤式弯举"]),
                SplitDay(title: "腿", focus: .legs, exerciseNames: ["深蹲", "罗马尼亚硬拉", "腿举", "站姿提踵"]),
                SplitDay(title: "上肢 · 容量", focus: .shoulders, exerciseNames: ["站姿推举", "绳索夹胸", "面拉", "杠铃弯举"]),
                SplitDay(title: "下肢 · 后链", focus: .legs, exerciseNames: ["罗马尼亚硬拉", "保加利亚分腿蹲", "腿举", "健腹轮"])
            ]
        default:
            return [
                SplitDay(title: "推 A", focus: .chest, exerciseNames: ["杠铃卧推", "上斜哑铃卧推", "哑铃侧平举", "绳索下压"]),
                SplitDay(title: "拉 A", focus: .back, exerciseNames: ["引体向上", "杠铃划船", "坐姿绳索划船", "杠铃弯举"]),
                SplitDay(title: "腿 A", focus: .legs, exerciseNames: ["深蹲", "腿举", "站姿提踵", "健腹轮"]),
                SplitDay(title: "推 B", focus: .shoulders, exerciseNames: ["站姿推举", "双杠臂屈伸", "绳索夹胸", "锤式弯举"]),
                SplitDay(title: "拉 B", focus: .back, exerciseNames: ["高位下拉", "面拉", "杠铃划船", "悬垂举腿"]),
                SplitDay(title: "腿 B", focus: .legs, exerciseNames: ["罗马尼亚硬拉", "保加利亚分腿蹲", "腿举", "平板支撑"])
            ]
        }
    }

    private static func exercises(for day: SplitDay, goal: Goal, experience: Experience) -> [PlannedExercise] {
        let baseSets: Int = {
            switch experience {
            case .beginner: return 3
            case .intermediate: return 4
            case .advanced: return 4
            }
        }()
        let repRange: String = {
            switch goal {
            case .cut: return "8–12"
            case .recomp: return "6–10"
            case .bulk: return "5–8"
            case .endurance: return "12–15"
            }
        }()

        return day.exerciseNames.map { name in
            let lib = SeedData.library.first { $0.name == name }
            let isCore = lib?.group == .core
            return PlannedExercise(
                name: name,
                sets: isCore ? 3 : baseSets,
                reps: lib?.isTimed == true ? "40–60 秒" : repRange,
                note: lib?.cue ?? ""
            )
        }
    }
}
