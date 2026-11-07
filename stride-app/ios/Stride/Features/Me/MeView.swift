import SwiftUI

struct MeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ai: AISettings
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var watch: WatchSession

    @State private var showMembership = false
    @State private var toast: String?
    @State private var syncing = false

    private var profile: Profile { store.state.profile }

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    profileCard
                    membershipBanner
                    statsRow
                    accountSection
                    toolSection
                    aboutSection
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Palette.bg, for: .navigationBar)
        .membershipSheet($showMembership)
        .toast($toast)
    }

    // MARK: - 资料

    private var profileCard: some View {
        NavigationLink {
            ProfileEditView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Palette.green.opacity(0.35), Palette.blue.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 62, height: 62)
                    Text(String(profile.nickname.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(Palette.text)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text("\(profile.goal.rawValue) · 每周 \(profile.daysPerWeek) 练 · \(profile.experience.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textFaint)
            }
            .padding(16)
            .card(radius: 24, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 会员

    private var membershipBanner: some View {
        Button {
            showMembership = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.state.membership.tier == .max ? "\(Brand.tierMax) 已解锁" : "升级到 \(Brand.tierMax)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("AI 不限次数 · 全部画风 · 全部模板")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x1E3A28), Color(hex: 0x14202A)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Palette.green.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.state.sessions.count)", label: "训练")
            StatTile(value: "\(store.streak)", label: "连续")
            StatTile(value: "\(store.state.runs.count)", label: "轨迹")
        }
    }

    // MARK: - 账户 / 连接

    private var accountSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                AISettingsView()
            } label: {
                SettingRow(
                    icon: "sparkles",
                    title: "AI 服务",
                    value: ai.isConfigured ? ai.config.chatModel : "未配置",
                    tint: Palette.purple
                )
            }
            .buttonStyle(.plain)

            divider

            Button {
                syncHealth()
            } label: {
                SettingRow(
                    icon: "heart.fill",
                    title: "Apple 健康",
                    value: syncing ? "同步中…" : (health.authorized ? "已授权" : "未授权"),
                    tint: Palette.red
                )
            }
            .buttonStyle(.plain)

            divider

            Button {
                watch.activate()
                toast = watch.supported ? "手表桥接已启动" : "这台设备不支持 Watch 连接"
            } label: {
                SettingRow(
                    icon: "applewatch",
                    title: "Apple Watch",
                    value: watch.reachable ? "在线" : (watch.supported ? "已配对未连接" : "不可用"),
                    tint: Palette.green
                )
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                PlaylistImportView()
            } label: {
                SettingRow(icon: "music.note.list", title: "歌单链接导入", value: "解析", tint: Palette.pink)
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                LyricsView()
            } label: {
                SettingRow(icon: "text.alignleft", title: "歌词同步", value: "不限次数", tint: Palette.blue)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var toolSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PluginsView()
            } label: {
                SettingRow(icon: "square.grid.2x2", title: "插件市场", value: "4 个小工具", tint: Palette.amber)
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                RepCounterView()
            } label: {
                SettingRow(icon: "figure.strengthtraining.functional", title: "视觉动作计数", value: "相机", tint: Palette.green)
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                PlanEditorView()
            } label: {
                SettingRow(icon: "calendar", title: "训练计划", value: "\(profile.daysPerWeek) 天/周", tint: Palette.blue)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            SettingRow(icon: "info.circle", title: "版本", value: "1.0 (1)", tint: Palette.textDim)
            divider
            SettingRow(icon: "lock.shield", title: "数据存储", value: "仅本机", tint: Palette.textDim)
            divider
            Button {
                store.resetTodayQuotas()
                toast = "今日额度已重置"
            } label: {
                SettingRow(icon: "arrow.counterclockwise", title: "重置今日额度", value: "", tint: Palette.textDim)
            }
            .buttonStyle(.plain)
        }
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private func syncHealth() {
        syncing = true
        Task {
            if !health.authorized {
                await health.requestAuthorization()
            }
            let metrics = await health.todayMetrics()
            if metrics.steps > 0 || metrics.activeKcal > 0 {
                var snap = store.todaySnapshot
                snap.steps = max(snap.steps, metrics.steps)
                snap.activeKcal = max(snap.activeKcal, metrics.activeKcal)
                snap.restingHR = metrics.restingHR
                if metrics.weightKg > 0 { snap.weightKg = metrics.weightKg }
                if let idx = store.state.snapshots.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
                    store.state.snapshots[idx] = snap
                } else {
                    store.state.snapshots.append(snap)
                }
                store.saveNow()
                toast = "已同步今日健康数据"
            } else {
                toast = health.lastError ?? "没有拿到健康数据（模拟器常见）"
            }
            syncing = false
        }
    }
}

// MARK: - 行

struct SettingRow: View {
    let icon: String
    let title: String
    var value: String = ""
    var tint: Color = Palette.text

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.12)))

            Text(title)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(Palette.text)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textFaint)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
