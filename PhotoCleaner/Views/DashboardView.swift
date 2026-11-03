import SwiftUI

enum Route: Hashable {
    case category(CleanCategory)
    case month(String)
    case review
    case settings
}

struct DashboardView: View {
    @EnvironmentObject var store: CleanupStore
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HeaderCard()

                if store.authStatus == .limited {
                    Label("你只授权了部分照片，只能清理这些照片。可到「设置 › 隐私 › 照片」改为「完全访问」。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }

                SectionTitle(text: "智能分类")
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(CleanCategory.allCases) { cat in
                        NavigationLink(value: Route.category(cat)) {
                            CategoryCard(category: cat)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                if !store.months.isEmpty {
                    SectionTitle(text: "按月份整理")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.months.prefix(24)) { m in
                                NavigationLink(value: Route.month(m.id)) {
                                    MonthChip(month: m)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("相册清理")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.light()
                    store.startScan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.phase == .loading || store.phase == .analyzing)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.toDelete.isEmpty {
                NavigationLink(value: Route.review) {
                    HStack {
                        Image(systemName: "trash.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("待删除 \(store.toDelete.count) 项")
                                .font(.headline)
                            Text("可释放 \(Fmt.bytes(store.toDeleteBytes))")
                                .font(.caption)
                                .opacity(0.9)
                        }
                        Spacer()
                        Text("去确认")
                            .font(.subheadline.bold())
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .red.opacity(0.3), radius: 14, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.toDelete.isEmpty)
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
                CategoryView(title: c.title, colors: c.colors, ids: store.ids(in: c))
            }
        case .month(let key):
            CategoryView(title: store.months.first(where: { $0.id == key })?.title ?? key,
                         colors: CleanCategory.screenshots.colors,
                         ids: store.months.first(where: { $0.id == key })?.ids ?? [])
        case .review:
            ReviewDeleteView()
        case .settings:
            SettingsView()
        }
    }
}

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title3.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}

/// 顶部总览卡片：总数、总大小、扫描进度
struct HeaderCard: View {
    @EnvironmentObject var store: CleanupStore

    private var cleanableCount: Int {
        Set(CleanCategory.allCases
            .filter { $0 != .videos && $0 != .large }
            .flatMap { store.ids(in: $0) }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("相册共占用")
                        .font(.subheadline)
                        .opacity(0.85)
                    Text(Fmt.bytes(store.totalBytes))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(store.items.count)")
                        .font(.title2.bold().monospacedDigit())
                    Text("张照片和视频")
                        .font(.caption)
                        .opacity(0.85)
                }
            }

            if store.phase == .loading || store.phase == .analyzing {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: store.progress)
                        .tint(.white)
                    Text(store.progressText)
                        .font(.caption)
                        .opacity(0.9)
                }
            } else {
                HStack {
                    Image(systemName: "sparkles")
                    Text(store.phase == .done
                         ? "发现 \(cleanableCount) 张可能可以清理的照片"
                         : "点右上角刷新开始扫描")
                        .font(.subheadline.weight(.medium))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: [Color(red: 0.30, green: 0.33, blue: 0.98), Color(red: 0.64, green: 0.32, blue: 0.96)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.white.opacity(0.12)).frame(width: 180, height: 180).offset(x: 130, y: -60)
                Circle().fill(Color.white.opacity(0.08)).frame(width: 120, height: 120).offset(x: -140, y: 70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .purple.opacity(0.25), radius: 18, y: 8)
    }
}

struct CategoryCard: View {
    @EnvironmentObject var store: CleanupStore
    let category: CleanCategory

    var body: some View {
        let ids = store.ids(in: category)
        let pending = store.undecided(ids).count
        let analyzing = store.phase != .done && (category == .similar || category == .blurry || category == .poorLight)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(LinearGradient(colors: category.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Spacer()
                if analyzing {
                    ProgressView().scaleEffect(0.8)
                } else if pending > 0 {
                    Text("\(pending) 待看")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(category.colors[0].opacity(0.15), in: Capsule())
                        .foregroundStyle(category.colors[0])
                }
            }
            Text(category.title)
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(ids.count)")
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Fmt.bytes(store.bytes(of: ids)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(category.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

struct MonthChip: View {
    @EnvironmentObject var store: CleanupStore
    let month: MonthGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let first = month.ids.first, let item = store.item(first) {
                AssetImageView(asset: item.asset, targetSize: CGSize(width: 120, height: 90))
                    .frame(width: 120, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text(month.title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Text("\(month.ids.count) 项 · 待看 \(store.undecided(month.ids).count)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
