import SwiftUI

enum Route: Hashable {
    case category(CleanCategory)
    case month(String)
    case review
    case settings
}

/// 首页：总览 + 分类 + 按月份
struct DashboardView: View {
    @EnvironmentObject var store: CleanupStore
    private let columns = [GridItem(.flexible(), spacing: Theme.gap), GridItem(.flexible(), spacing: Theme.gap)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SummaryCard()
                    .fadeIn(0)

                if store.authStatus == .limited {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle").foregroundStyle(Theme.accent)
                        Text("你只授权了部分照片，只能清理这些照片。可到「设置 › 隐私 › 照片」改为「完全访问」。")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
                }

                SectionHeader(title: "分类")
                LazyVGrid(columns: columns, spacing: Theme.gap) {
                    ForEach(Array(CleanCategory.allCases.enumerated()), id: \.element) { idx, cat in
                        NavigationLink(value: Route.category(cat)) {
                            CategoryCard(category: cat)
                        }
                        .buttonStyle(PressableStyle())
                        .fadeIn(idx + 1)
                    }
                }

                if !store.months.isEmpty {
                    SectionHeader(title: "按月份", trailing: "\(store.months.count) 个月")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.gap) {
                            ForEach(store.months.prefix(24)) { m in
                                NavigationLink(value: Route.month(m.id)) {
                                    MonthCard(month: m)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.vertical, 2)
                    }
                    .padding(.horizontal, -Theme.pagePadding)
                }

                Spacer(minLength: 96)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("相册清理")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        Haptics.light()
                        store.startScan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.phase == .loading || store.phase == .analyzing)
                    NavigationLink(value: Route.settings) {
                        Image(systemName: "gearshape")
                    }
                }
                .font(.system(size: 16, weight: .regular))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.toDelete.isEmpty {
                NavigationLink(value: Route.review) {
                    PendingBar()
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: store.toDelete.isEmpty)
        .navigationDestination(for: Route.self) { route in
            destination(for: route)
        }
        .alert("完成", isPresented: Binding(get: { store.lastDeleteMessage != nil },
                                           set: { if !$0 { store.lastDeleteMessage = nil } })) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(store.lastDeleteMessage ?? "")
        }
    }
}

extension DashboardView {
    @ViewBuilder
    func destination(for route: Route) -> some View {
        switch route {
        case .category(let c):
            if c == .similar {
                SimilarGroupsView()
            } else {
                CategoryView(title: c.title, ids: store.ids(in: c))
            }
        case .month(let key):
            CategoryView(title: store.months.first(where: { $0.id == key })?.title ?? key,
                         ids: store.months.first(where: { $0.id == key })?.ids ?? [])
        case .review:
            ReviewDeleteView()
        case .settings:
            SettingsView()
        }
    }
}

/// 底部「待删除」条
private struct PendingBar: View {
    @EnvironmentObject var store: CleanupStore
    var body: some View {
        HStack(spacing: 12) {
            IconBadge(icon: "trash", tint: Theme.danger, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("待删除 \(store.toDelete.count) 项")
                    .font(Theme.headline)
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                    .animation(Theme.spring, value: store.toDelete.count)
                Text("可释放 \(Fmt.bytes(store.toDeleteBytes))")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            Text("查看")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text3)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }
}

/// 总览卡：总占用 + 扫描进度 / 可清理提示
struct SummaryCard: View {
    @EnvironmentObject var store: CleanupStore

    private var cleanableIDs: [String] {
        Array(Set(CleanCategory.allCases
            .filter { $0 != .videos && $0 != .large }
            .flatMap { store.ids(in: $0) }))
    }

    private var scanning: Bool { store.phase == .loading || store.phase == .analyzing }

    var body: some View {
        let cleanable = cleanableIDs
        let cleanableBytes = store.bytes(of: cleanable)
        let ratio = store.totalBytes > 0 ? Double(cleanableBytes) / Double(store.totalBytes) : 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("相册占用")
                    .font(Theme.callout)
                    .foregroundStyle(Theme.text2)
                Spacer()
                Text("\(store.items.count) 项")
                    .font(Theme.number(13, .regular))
                    .foregroundStyle(Theme.text3)
            }
            Text(Fmt.bytes(store.totalBytes))
                .font(Theme.number(36, .bold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .animation(Theme.springSoft, value: store.totalBytes)

            if scanning {
                VStack(alignment: .leading, spacing: 8) {
                    ThinProgress(value: store.progress)
                    Text(store.progressText)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text3)
                }
            } else if store.phase == .done {
                VStack(alignment: .leading, spacing: 8) {
                    ThinProgress(value: ratio)
                    HStack(spacing: 4) {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        Text("约 \(Fmt.bytes(cleanableBytes)) 可清理 · \(cleanable.count) 张")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.text2)
                    }
                }
            } else {
                Text("点右上角刷新开始扫描")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text3)
            }
        }
        .card(padding: 18)
    }
}

/// 分类卡：白底 + 小图标 + 数字 + 名称
struct CategoryCard: View {
    @EnvironmentObject var store: CleanupStore
    let category: CleanCategory

    var body: some View {
        let ids = store.ids(in: category)
        let pending = store.undecided(ids).count
        let analyzing = store.phase != .done && (category == .similar || category == .blurry || category == .poorLight)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                IconBadge(icon: category.icon)
                Spacer()
                if analyzing {
                    ProgressView().scaleEffect(0.7)
                } else if pending > 0 && pending < ids.count {
                    Text("\(pending) 待看")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text3)
                }
            }
            Spacer(minLength: 14)
            Text("\(ids.count)")
                .font(Theme.number(26, .semibold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .animation(Theme.spring, value: ids.count)
            HStack(alignment: .firstTextBaseline) {
                Text(category.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 4)
                Text(Fmt.bytes(store.bytes(of: ids)))
                    .font(Theme.number(12, .regular))
                    .foregroundStyle(Theme.text3)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .card(padding: 14)
    }
}

struct MonthCard: View {
    @EnvironmentObject var store: CleanupStore
    let month: MonthGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let first = month.ids.first, let item = store.item(first) {
                AssetImageView(asset: item.asset, targetSize: CGSize(width: 128, height: 96))
                    .frame(width: 128, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rTile, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(month.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text("\(month.ids.count) 项")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text3)
            }
            .padding(.horizontal, 2)
        }
        .card(radius: 14, padding: 8)
    }
}
