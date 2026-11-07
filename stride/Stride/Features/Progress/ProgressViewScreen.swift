import SwiftUI
import Charts

struct ProgressViewScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthKitManager

    @State private var tab: Int = 0
    @State private var selectedRun: RouteRun?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    segmented

                    if tab == 0 {
                        statsRow
                        volumeCard
                        weightCard
                        balanceCard
                        prCard
                    } else {
                        runsGrid
                    }
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("进度")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .sheet(item: $selectedRun) { run in
            RouteDetailView(run: run)
        }
    }

    private var segmented: some View {
        HStack(spacing: 6) {
            segment("数据", index: 0)
            segment("足迹", index: 1)
        }
        .padding(4)
        .background(Capsule().fill(Palette.card))
    }

    private func segment(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { tab = index }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tab == index ? Color.black : Palette.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(tab == index ? Color.white : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 概览

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.streak)", label: "连续天数", tint: Palette.green)
            StatTile(value: "\(store.state.sessions.count)", label: "总训练", tint: Palette.text)
            StatTile(
                value: "\(Int(store.state.sessions.reduce(0) { $0 + $1.totalVolume } / 1000))t",
                label: "累计容量",
                tint: Palette.blue
            )
        }
    }

    private var volumeCard: some View {
        let data = store.weeklyVolume
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("每周容量")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                if let last = data.last {
                    Text("\(Int(last.volume)) kg")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.green)
                }
            }

            if data.isEmpty {
                EmptyHint(icon: "chart.bar", title: "还没有数据", message: "练两次就会有曲线。")
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("周", item.week, unit: .weekOfYear),
                        y: .value("容量", item.volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Palette.green, Palette.green.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 150)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private var weightCard: some View {
        let points = store.state.snapshots.sorted { $0.date < $1.date }
        let current = points.first?.weightKg ?? store.state.profile.weightKg
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("体重")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text(String(format: "%.1f kg", current))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.blue)
            }

            if points.count < 2 {
                EmptyHint(icon: "scalemass", title: "数据不足", message: "记录两次体重后显示趋势。")
            } else {
                Chart(points) { snap in
                    LineMark(
                        x: .value("日", snap.date),
                        y: .value("kg", snap.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Palette.blue)

                    AreaMark(
                        x: .value("日", snap.date),
                        y: .value("kg", snap.weightKg)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Palette.blue.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 120)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private var balanceCard: some View {
        let balance = ProgressiveEngine.weeklySetBalance(sessions: store.state.sessions)
        let maxSets = max(1, balance.values.max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本周肌群分布")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("目标 10–20 组")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }

            if balance.isEmpty {
                Text("本周还没有训练记录")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textFaint)
            } else {
                ForEach(MuscleGroup.allCases) { group in
                    let sets = balance[group] ?? 0
                    if sets > 0 {
                        HStack(spacing: 10) {
                            Text(group.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(group.tint)
                                .frame(width: 32, alignment: .leading)
                            BarProgress(progress: Double(sets) / Double(maxSets), color: group.tint, height: 6)
                            Text("\(sets)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.textDim)
                                .frame(width: 22, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    private var prCard: some View {
        let lifts = ["杠铃卧推", "深蹲", "罗马尼亚硬拉", "站姿推举"]
        return VStack(alignment: .leading, spacing: 12) {
            Text("主力动作")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.text)

            ForEach(lifts, id: \.self) { name in
                let history = store.history(for: name)
                let e1rm = history.last?.e1rm ?? 0
                let best = history.map(\.e1rm).max() ?? 0
                HStack {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text(history.isEmpty ? "—" : "\(Int(e1rm)) kg")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text(history.isEmpty ? "" : "最好 \(Int(best))")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                        .frame(width: 62, alignment: .trailing)
                }
            }
        }
        .padding(18)
        .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 足迹

    private var runsGrid: some View {
        VStack(spacing: 12) {
            if store.state.runs.isEmpty {
                EmptyHint(icon: "map", title: "还没有轨迹", message: "跑一次，就会留下一条线。")
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(store.state.runs) { run in
                        Button {
                            selectedRun = run
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                RouteArtView(points: run.points, style: run.style, lineWidth: 2.4)
                                    .frame(height: 118)
                                    .background(Palette.cardSoft)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(run.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Palette.text)
                                        .lineLimit(1)
                                    Text(String(format: "%.2f km · %@", run.distanceM / 1000, run.style.title))
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(Palette.textFaint)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
