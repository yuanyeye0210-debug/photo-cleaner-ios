import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthKitManager

    @State private var showWorkoutSheet = false
    @State private var showFoodSheet = false
    @State private var showRunSheet = false
    @State private var showCoachSheet = false
    @State private var showMembership = false
    @State private var healthMetrics: HealthKitManager.DayMetrics?

    private var profile: Profile { store.state.profile }
    private var snapshot: DailySnapshot { store.todaySnapshot }
    private var nutrition: (kcal: Double, p: Double, c: Double, f: Double) { store.todayNutrition }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "早上好"
        case 11..<14: return "中午好"
        case 14..<18: return "下午好"
        case 18..<23: return "晚上好"
        default: return "该睡了"
        }
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    activityCard
                    quickActions
                    planCard
                    nutritionCard
                    recentCard
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            let metrics = await health.todayMetrics()
            if metrics.steps > 0 || metrics.activeKcal > 0 {
                healthMetrics = metrics
            }
        }
        .sheet(isPresented: $showWorkoutSheet) {
            SessionView(draft: SessionDraft.fromPlan(store.todaysPlannedDay))
        }
        .sheet(isPresented: $showFoodSheet) {
            FoodScanView()
        }
        .sheet(isPresented: $showRunSheet) {
            RunCaptureView()
        }
        .sheet(isPresented: $showCoachSheet) {
            NavigationStack { CoachView() }
        }
        .membershipSheet($showMembership)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textDim)
                Text(profile.nickname)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Palette.text)
                Text(dateLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textFaint)
            }
            Spacer()
            Button {
                showMembership = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(store.state.membership.tier == .max ? "MAX" : "升级")
                        .font(.system(size: 11, weight: .heavy))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.top, 8)
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 EEEE"
        return f.string(from: Date())
    }

    // MARK: - 活跃卡

    private var activityCard: some View {
        HStack(spacing: 18) {
            RingStat(
                progress: Double(kcalToday) / Double(max(1, profile.kcalTarget * 2 / 3)),
                value: "\(kcalToday)",
                unit: "kcal",
                caption: "活动",
                colors: [Palette.green, Color(hex: 0x2AD4C8)],
                size: 132
            )

            VStack(alignment: .leading, spacing: 12) {
                statLine(icon: "figure.walk", value: "\(stepsToday)", unit: "步", hint: "目标 10,000")
                statLine(icon: "clock.fill", value: "\(snapshot.exerciseMin)", unit: "分钟", hint: "本周 \(store.weekSessions.count) 练")
                statLine(icon: "flame.fill", value: "\(store.streak)", unit: "天连击", hint: "别断")
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .card(radius: 28, fill: Palette.card, stroke: Palette.stroke)
    }

    private var stepsToday: Int {
        max(snapshot.steps, healthMetrics?.steps ?? 0)
    }

    private var kcalToday: Int {
        max(snapshot.activeKcal, healthMetrics?.activeKcal ?? 0)
    }

    private func statLine(icon: String, value: String, unit: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.textFaint)
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textDim)
            }
            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textFaint)
        }
    }

    // MARK: - 快捷入口

    private var quickActions: some View {
        HStack(spacing: 10) {
            quick(icon: "dumbbell.fill", title: "开练", tint: Palette.green) { showWorkoutSheet = true }
            quick(icon: "camera.fill", title: "记一餐", tint: Palette.amber) { showFoodSheet = true }
            quick(icon: "figure.run", title: "记跑", tint: Palette.blue) { showRunSheet = true }
            quick(icon: "sparkles", title: "问教练", tint: Palette.purple) { showCoachSheet = true }
        }
    }

    private func quick(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(tint.opacity(0.12)))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textDim)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 今日计划

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("今日计划")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Spacer()
                if let day = store.todaysPlannedDay {
                    Pill(text: day.title, fg: Palette.text, bg: Palette.cardHigh)
                }
            }

            if let day = store.todaysPlannedDay {
                ForEach(day.exercises.prefix(4)) { ex in
                    HStack {
                        Text(ex.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(ex.sets) × \(ex.reps)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.textDim)
                    }
                }
                if day.exercises.count > 4 {
                    Text("还有 \(day.exercises.count - 4) 个动作")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                }

                Button {
                    showWorkoutSheet = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                        Text("开始训练").font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

            } else {
                Text("今天是恢复日")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text("走 20 分钟 + 髋活动度，明天再顶。")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textDim)
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 营养

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("营养")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Spacer()
                Text("\(Int(nutrition.kcal)) / \(profile.kcalTarget) kcal")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.text)
            }

            BarProgress(progress: nutrition.kcal / Double(max(1, profile.kcalTarget)), color: Palette.amber, height: 8)

            HStack(spacing: 14) {
                MacroBar(title: "蛋白", current: nutrition.p, target: Double(profile.proteinTarget), color: Palette.green)
                MacroBar(title: "碳水", current: nutrition.c, target: 240, color: Palette.blue)
                MacroBar(title: "脂肪", current: nutrition.f, target: 65, color: Palette.amber)
            }

            if store.todayFoods.isEmpty {
                Text("还没记录。拍张照，AI 帮你算。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textFaint)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.todayFoods.prefix(6)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.items.first?.name ?? entry.meal.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Palette.text)
                                Text("\(Int(entry.kcal)) kcal")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Palette.textFaint)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.cardSoft))
                        }
                    }
                }
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 最近一次训练

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近", trailing: "全部")

            if let last = store.recentSessions.first {
                HStack(spacing: 13) {
                    Image(systemName: last.kind.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.green)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.green.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(last.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.text)
                        Text("\(relativeDay(last.date)) · \(last.totalSets) 组 · \(Int(last.totalVolume)) kg")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textDim)
                    }
                    Spacer()
                    Text("\(last.durationSec / 60)′")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textFaint)
                }
            } else {
                EmptyHint(icon: "dumbbell", title: "还没有记录", message: "点「开练」建第一次训练。")
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        return "\(days) 天前"
    }
}
