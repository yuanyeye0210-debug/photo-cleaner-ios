import SwiftUI

struct TrainingHomeView: View {
    @EnvironmentObject private var store: AppStore

    @State private var draft: SessionDraft?
    @State private var showSession = false
    @State private var detail: WorkoutSession?
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    weekStats
                    planCard
                    startRow
                    historyList
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("训练")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .sheet(isPresented: $showSession, onDismiss: { draft = nil }) {
            SessionView(draft: draft ?? .empty())
        }
        .sheet(item: $detail) { session in
            SessionDetailView(session: session)
        }
        .toast($toast)
    }

    // MARK: - 本周

    private var weekStats: some View {
        let week = store.weekSessions
        let sets = week.reduce(0) { $0 + $1.totalSets }
        let volume = week.reduce(0) { $0 + $1.totalVolume }
        return HStack(spacing: 10) {
            StatTile(value: "\(week.count)", label: "本周训练", tint: Palette.green)
            StatTile(value: "\(sets)", label: "总组数", tint: Palette.text)
            StatTile(value: "\(Int(volume / 1000))t", label: "总容量", tint: Palette.blue)
        }
    }

    // MARK: - 计划

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("四周计划")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.text)
                    if let plan = store.state.plan {
                        Text("\(plan.goal.rawValue) · 每周 \(store.state.profile.daysPerWeek) 练")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textDim)
                    }
                }
                Spacer()
                Button {
                    regenerate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                        Text("重排").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.cardHigh))
                }
                .buttonStyle(.plain)
            }

            if let plan = store.state.plan {
                HStack(spacing: 6) {
                    ForEach(plan.days) { day in
                        dayChip(day)
                    }
                }
            }

            if let today = store.todaysPlannedDay {
                VStack(alignment: .leading, spacing: 8) {
                    Text(today.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.green)
                    ForEach(today.exercises) { ex in
                        HStack {
                            Text(ex.name).font(.system(size: 14)).foregroundStyle(Palette.text)
                            Spacer()
                            Text("\(ex.sets)×\(ex.reps)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textFaint)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.cardSoft))
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private func dayChip(_ day: PlannedDay) -> some View {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let isToday = day.weekday == weekday
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return VStack(spacing: 5) {
            Text(names[max(0, min(6, day.weekday - 1))])
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isToday ? Color.black : Palette.textDim)
            Circle()
                .fill(day.rest ? Palette.cardHigh : (isToday ? Color.black : Palette.green.opacity(0.7)))
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isToday ? Color.white : Palette.cardSoft)
        )
    }

    // MARK: - 开始

    private var startRow: some View {
        HStack(spacing: 10) {
            Button {
                draft = .fromPlan(store.todaysPlannedDay)
                showSession = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                    Text("按计划开练").font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            }
            .buttonStyle(.plain)

            Button {
                draft = .empty()
                showSession = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 52, height: 50)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardHigh))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 历史

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "训练历史", trailing: "\(store.state.sessions.count) 次")

            if store.recentSessions.isEmpty {
                EmptyHint(icon: "clock.arrow.circlepath", title: "还没有训练", message: "按计划开练，记录会自动出现在这里。")
            } else {
                ForEach(store.recentSessions) { session in
                    Button {
                        detail = session
                    } label: {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteSession(id: session.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func regenerate() {
        let p = store.state.profile
        store.setPlan(PlanGenerator.generate(goal: p.goal, days: p.daysPerWeek, experience: p.experience))
        toast = "计划已按 \(p.goal.rawValue) / 每周 \(p.daysPerWeek) 练重排"
    }
}

// MARK: - 行

struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: session.kind.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.green)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Palette.green.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textDim)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    private var subtitle: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return "\(f.string(from: session.date)) · \(session.totalSets) 组 · \(Int(session.totalVolume)) kg"
    }
}

// MARK: - 详情

struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            StatTile(value: "\(session.durationSec / 60)′", label: "时长")
                            StatTile(value: "\(session.totalSets)", label: "组数")
                            StatTile(value: "\(Int(session.totalVolume))", label: "容量 kg")
                        }

                        ForEach(session.exercises) { ex in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ex.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                ForEach(ex.sets.indices, id: \.self) { idx in
                                    let set = ex.sets[idx]
                                    HStack {
                                        Text("第 \(idx + 1) 组")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Palette.textFaint)
                                        Spacer()
                                        Text("\(fmt(set.weight)) kg × \(ex.isTimed ? "\(set.seconds)″" : "\(set.reps)")")
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Palette.text)
                                        if let rpe = set.rpe {
                                            Text("@\(fmt(rpe))")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Palette.textDim)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle(session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - 动作库

struct ExerciseGroupBox: Identifiable {
    let group: MuscleGroup
    let list: [Exercise]
    var id: String { group.rawValue }
}

struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let onPick: (Exercise) -> Void

    private var groups: [ExerciseGroupBox] {
        let filtered = SeedData.library.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        }
        return MuscleGroup.allCases.compactMap { g in
            let list = filtered.filter { $0.group == g }
            return list.isEmpty ? nil : ExerciseGroupBox(group: g, list: list)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if groups.isEmpty {
                            EmptyHint(icon: "magnifyingglass", title: "没找到", message: "换个关键词试试。")
                        }
                        ForEach(groups) { box in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(box.group.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(box.group.tint)
                                ForEach(box.list) { exercise in
                                    Button {
                                        onPick(exercise)
                                        dismiss()
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.name)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(Palette.text)
                                                Text(exercise.cue)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Palette.textFaint)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text(exercise.equipment.rawValue)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(Palette.textDim)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Capsule().fill(Palette.cardHigh))
                                        }
                                        .padding(13)
                                        .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(Metrics.page)
                }
            }
            .searchable(text: $query, prompt: "搜动作")
            .navigationTitle("动作库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
        }
    }
}
