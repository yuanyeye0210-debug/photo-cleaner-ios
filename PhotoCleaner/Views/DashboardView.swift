import SwiftUI

enum Route: Hashable {
    case category(CleanCategory)
    case month(String)
    case review
    case settings
}

struct RouteDestination: View {
    @EnvironmentObject var store: CleanupStore
    let route: Route

    var body: some View {
        switch route {
        case .category(let c):
            if c == .similar {
                SimilarGroupsView()
            } else {
                CategoryView(title: c.title, ids: store.ids(in: c), tint: c.tint)
            }
        case .month(let key):
            CategoryView(title: store.months.first(where: { $0.id == key })?.title ?? key,
                         ids: store.months.first(where: { $0.id == key })?.ids ?? [],
                         tint: Theme.orange)
        case .review:
            ReviewDeleteView()
        case .settings:
            SettingsView()
        }
    }
}

/// 首页：问候 + 相册状态（分段圆环 + 2×2 指标）+ 待删除 + 分类
struct DashboardView: View {
    @EnvironmentObject var store: CleanupStore
    @AppStorage("userName") private var userName = "叶原野"
    var openSettings: () -> Void = {}

    private let columns = [GridItem(.flexible(), spacing: Theme.gap), GridItem(.flexible(), spacing: Theme.gap)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                greeting
                    .padding(.bottom, 4)

                StatusCard()
                    .fadeIn(0)

                if store.authStatus == .limited {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Theme.blue)
                        Text("你只授权了部分照片，只能清理这些照片。可到「设置 › 隐私 › 照片」改为「完全访问」。")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
                }

                NavigationLink(value: Route.review) {
                    PendingCard()
                }
                .buttonStyle(PressableStyle())
                .fadeIn(1)

                SectionHeader(title: "分类", trailing: store.phase == .done ? "分析完成" : store.progressText)
                LazyVGrid(columns: columns, spacing: Theme.gap) {
                    ForEach(Array(CleanCategory.allCases.enumerated()), id: \.element) { idx, cat in
                        NavigationLink(value: Route.category(cat)) {
                            CategoryCard(category: cat)
                        }
                        .buttonStyle(PressableStyle())
                        .fadeIn(idx + 2)
                    }
                }

                Spacer(minLength: 110)
            }
            .padding(.horizontal, Theme.pagePadding)
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("完成", isPresented: Binding(get: { store.lastDeleteMessage != nil },
                                           set: { if !$0 { store.lastDeleteMessage = nil } })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(store.lastDeleteMessage ?? "")
        }
    }

    /// 「夜深了，叶原野」+ 右侧头像（点开设置弹层）
    private var greeting: some View {
        HStack {
            Text("\(Theme.greeting())，\(userName)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Button(action: openSettings) {
                Text(String(userName.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.purple)
                    .frame(width: 46, height: 46)
                    .background(Theme.purple.opacity(0.2), in: Circle())
                    .glassSurface(Circle(), interactive: true)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("设置")
        }
        .padding(.top, 8)
    }
}

/// 相册状态：分段圆环（紫色弧 + 橙色大数字）+ 2×2 指标
struct StatusCard: View {
    @EnvironmentObject var store: CleanupStore

    private var scanning: Bool { store.phase == .loading || store.phase == .analyzing }

    var body: some View {
        let cleanable = store.cleanableIDs
        let cleanableBytes = store.bytes(of: cleanable)
        let ratio = store.totalBytes > 0 ? Double(cleanableBytes) / Double(store.totalBytes) : 0
        let videos = store.items.filter { $0.isVideo }.count
        VStack(alignment: .leading, spacing: 18) {
            CardHeader(icon: "gauge.with.dots.needle.33percent", tint: Theme.orange, title: "相册状态") {
                if scanning {
                    PillBadge(text: "扫描中", icon: "clock.fill")
                } else {
                    PillBadge(text: "可清理", icon: "exclamationmark.circle.fill")
                }
            }
            HStack(spacing: 18) {
                SegmentedRingGauge(value: scanning ? store.progress : ratio,
                                   center: "\(Int(((scanning ? store.progress : ratio) * 100).rounded()))",
                                   caption: scanning ? "扫描 %" : "可清理 %")
                    .frame(width: 148, height: 148)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                    Metric(icon: "photo.fill", tint: Theme.purple, label: "照片", value: "\(store.items.count - videos)")
                    Metric(icon: "video.fill", tint: Theme.pink, label: "视频", value: "\(videos)")
                    Metric(icon: "externaldrive.fill", tint: Theme.orange, label: "占用", value: Fmt.bytes(store.totalBytes))
                    Metric(icon: "sparkles", tint: Theme.blue, label: "可清理", value: Fmt.bytes(cleanableBytes))
                }
            }
        }
        .card(padding: 18)
    }
}

/// 待删除：大数字 + 小单位 + 细进度条（勾选联动：选中照片时这里同步变化）
struct PendingCard: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        let cleanableBytes = max(store.bytes(of: store.cleanableIDs), 1)
        let ratio = min(1, Double(store.toDeleteBytes) / Double(cleanableBytes))
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(icon: "trash.fill", tint: Theme.danger, title: "待删除") {
                if store.toDelete.isEmpty {
                    PillBadge(text: "未选择", tint: Theme.orange)
                } else {
                    PillBadge(text: "去确认", tint: Theme.blue, style: .soft, chevron: true)
                }
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已选").font(.system(size: 14)).foregroundStyle(Theme.text2)
                    BigNumber(value: "\(store.toDelete.count)", unit: "项")
                }
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("可释放").font(.system(size: 14)).foregroundStyle(Theme.text2)
                        Text(store.toDelete.isEmpty ? "--" : Fmt.bytes(store.toDeleteBytes))
                            .font(Theme.number(17, .semibold)).foregroundStyle(Theme.text)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("已保留").font(.system(size: 14)).foregroundStyle(Theme.text2)
                        Text("\(store.kept.count)")
                            .font(Theme.number(17, .semibold)).foregroundStyle(Theme.text)
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 130, alignment: .leading)
            }
            VStack(spacing: 8) {
                HStack {
                    Text("可清理共 \(Fmt.bytes(store.bytes(of: store.cleanableIDs)))")
                        .font(.system(size: 13)).foregroundStyle(Theme.text2)
                    Spacer()
                    Text("\(Int((ratio * 100).rounded()))%")
                        .font(Theme.number(14, .semibold)).foregroundStyle(Theme.orange)
                        .contentTransition(.numericText())
                }
                ThinProgress(value: ratio, tint: Theme.orange)
            }
        }
        .card(padding: 18)
        .animation(Theme.spring, value: store.toDelete.count)
    }
}

/// 分类卡：圆徽章 + 标题 + 大数字 + 单位
struct CategoryCard: View {
    @EnvironmentObject var store: CleanupStore
    let category: CleanCategory

    var body: some View {
        let ids = store.ids(in: category)
        let pending = store.undecided(ids).count
        let analyzing = store.phase != .done && category.needsAnalysis
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                IconBadge(icon: category.icon, tint: category.tint, size: 30)
                Text(category.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if analyzing { ProgressView().scaleEffect(0.7) }
            }
            BigNumber(value: "\(ids.count)", unit: "项", size: 32)
            HStack {
                Text(Fmt.bytes(store.bytes(of: ids)))
                Spacer()
                if pending > 0 && pending < ids.count { Text("\(pending) 待看") }
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 22, padding: 14)
    }
}

extension CleanupStore {
    /// 可清理（不含视频、大文件和美食/宠物/风景这种「看情况」的类别）
    var cleanableIDs: [String] {
        Array(Set(CleanCategory.allCases
            .filter { $0 != .videos && $0 != .large && !$0.isBrowse }
            .flatMap { ids(in: $0) }))
    }
}
