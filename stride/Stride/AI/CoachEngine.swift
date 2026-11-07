import Foundation

/// 教练的本地兜底：没配 AI Key 也能给出基于你真实记录的回答。
/// 配了 Key 就走模型，本地逻辑不再参与。
@MainActor
enum CoachEngine {

    static let systemPrompt = """
    你是一名严谨的力量训练教练，中文回答，说话直接、不客套。
    规则：
    1. 只基于用户给出的训练记录做判断，不知道就说不知道，不要编数据。
    2. 建议必须具体到重量、次数、组数或时长。
    3. 提到风险时给替代动作，不说"建议就医"这类废话除非用户描述的是锐痛。
    4. 回答控制在 120 字以内，必要时用短句分点。
    """

    static func context(store: AppStore) -> String {
        let p = store.state.profile
        var lines: [String] = []
        let body = String(format: "%.0fcm / %.1fkg", p.heightCm, p.weightKg)
        lines.append("用户：\(p.nickname)，\(p.age) 岁，\(body)，目标 \(p.goal.rawValue)，经验 \(p.experience.rawValue)，每周 \(p.daysPerWeek) 练。")

        let recent = store.recentSessions.prefix(4)
        if recent.isEmpty {
            lines.append("最近没有训练记录。")
        } else {
            lines.append("最近训练：")
            for s in recent {
                let ex = s.exercises.prefix(3).map { "\($0.name) \($0.doneSets.count)组" }.joined(separator: "、")
                lines.append("- \(dayString(s.date)) \(s.title)：\(ex)")
            }
        }

        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        if !balance.isEmpty {
            let text = balance.sorted { $0.key.rawValue < $1.key.rawValue }
                .map { "\($0.key.rawValue)\($0.value)" }
                .joined(separator: " ")
            lines.append("本周组数：\(text)")
        }

        if let today = store.todaysPlannedDay {
            lines.append("今天计划：\(today.title)")
        }

        let n = store.todayNutrition
        lines.append("今日摄入：\(Int(n.kcal)) kcal / 蛋白 \(Int(n.p))g（目标 \(p.kcalTarget) kcal，蛋白 \(p.proteinTarget)g）")
        return lines.joined(separator: "\n")
    }

    static func ask(_ text: String, store: AppStore, config: AIConfig) async -> (answer: String, usedAI: Bool) {
        if config.isConfigured {
            do {
                let full = "以下是用户当前状态：\n\(context(store: store))\n\n用户说：\(text)"
                let answer = try await AIClient.chat(
                    system: systemPrompt,
                    user: full,
                    config: config,
                    maxTokens: 600
                )
                return (answer, true)
            } catch {
                let local = localReply(text, store: store)
                return (local + "\n\n（AI 服务调用失败：\(error.localizedDescription)，以上是本地分析。）", false)
            }
        }
        return (localReply(text, store: store), false)
    }

    // MARK: - 本地规则

    static func localReply(_ text: String, store: AppStore) -> String {
        let q = text.lowercased()

        if q.contains("痛") || q.contains("疼") || q.contains("伤") {
            return """
            先分清两件事：关节的锐痛 → 今天换动作，别硬顶；肌肉的酸胀 → 可以练但降 20% 负荷。
            替代方案：卧推痛肩 → 改哑铃中立握或器械推；深蹲痛膝 → 改箱式深蹲，控制下放深度。
            连续 3 天不缓解就去看看，别在 App 里赌。
            """
        }

        if q.contains("睡") || q.contains("累") || q.contains("疲") || q.contains("没劲") {
            let vols = store.weeklyVolume.map(\.volume)
            if ProgressiveEngine.needsDeload(weeklyVolumes: vols) {
                let last = vols.last ?? 0
                let prev = max(1, vols.dropLast().last ?? 1)
                let dropPercent = Int((1 - last / prev) * 100)
                return """
                这周训练量比上周掉了 \(dropPercent)%，确实是该减载的信号。
                这周所有主动作降到 70% 重量、组数砍一半，把睡眠补回来，下周再顶。
                """
            }
            return """
            状态差就别硬上大重量。今天做主项 3 组 × 6 次，重量取平时 80%，做完还有余力就收工。
            训练量可以少，动作质量不能降。
            """
        }

        for name in ["卧推", "深蹲", "硬拉", "划船", "推举", "引体"] {
            if q.contains(name) {
                return exerciseAdvice(name: name, store: store)
            }
        }

        if q.contains("今天") || q.contains("练什么") {
            if let day = store.todaysPlannedDay {
                let list = day.exercises.prefix(4).map { "\($0.name) \($0.sets)×\($0.reps)" }.joined(separator: "，")
                return "今天计划是「\(day.title)」：\(list)。组间休息 90 秒，主动作可以放到 150 秒。"
            }
            return "今天没有排训练。要么做 20 分钟快走 + 活动度，要么直接把明天的计划提前——别连着两天全休。"
        }

        if q.contains("吃") || q.contains("热量") || q.contains("蛋白") {
            let n = store.todayNutrition
            let p = store.state.profile
            let left = max(0, p.kcalTarget - Int(n.kcal))
            let proteinLeft = max(0, p.proteinTarget - Int(n.p))
            return """
            今天已摄入 \(Int(n.kcal)) kcal，还剩 \(left) kcal；蛋白差 \(proteinLeft)g。
            补法：\(proteinLeft)g 蛋白 ≈ \(Int(Double(proteinLeft) / 0.22))g 鸡胸，或 3 勺乳清。
            """
        }

        // 默认：给本周总结
        let week = store.weekSessions
        let sets = week.reduce(0) { $0 + $1.totalSets }
        let vol = week.reduce(0) { $0 + $1.totalVolume }
        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        let weakest = balance.min { $0.value < $1.value }?.key.rawValue ?? "腿"

        return """
        本周 \(week.count) 练、\(sets) 组、总容量 \(Int(vol)) kg。
        组数最少的部位是\(weakest)，下次训练优先补上。
        想问具体动作就把重量和次数丢给我，比如「卧推 62.5 做了 8 次」。
        """
    }

    private static func exerciseAdvice(name: String, store: AppStore) -> String {
        let history = store.history(for: name)
        guard let last = history.last else {
            return "还没有\(name)的记录。第一次先做 3 组 × 8 次，重量选能留 2 次余力的，我记下来之后再给建议。"
        }
        let best = history.map(\.e1rm).max() ?? 0
        let recentSets = store.recentSessions
            .flatMap(\.exercises)
            .first { $0.name == name }?
            .doneSets ?? []

        let suggestion = ProgressiveEngine.suggest(
            lastSets: recentSets,
            referenceWeight: last.e1rm * 0.78,
            referenceReps: 8,
            goal: store.state.profile.goal
        )

        return """
        \(name)：上次估算 1RM \(Int(last.e1rm)) kg，历史最好 \(Int(best)) kg。
        这次建议 \(suggestion.headline)：\(suggestion.sets) 组 × \(suggestion.reps) 次 @ \(format(suggestion.weight)) kg。
        \(suggestion.detail)
        """
    }

    private static func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }

    private static func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: d)
    }
}
