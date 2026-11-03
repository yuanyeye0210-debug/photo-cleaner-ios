import SwiftUI

enum Route: Hashable {
    case category(CleanCategory)
    case month(String)
    case review
    case settings
}

/// 首页：MiniMax 风格 —— 白底、粉橙渐变总览卡、彩色产品卡分类
struct DashboardView: View {
    @EnvironmentObject var store: CleanupStore
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topBar
                HeaderCard()
                    .staggerIn(0)

                if store.authStatus == .limited {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(MM.brand)
                        Text("你只授权了部分照片，只能清理这些照片。可到「设置 › 隐私 › 照片」改为「完全访问」。")
                            .font(MM.text(13))
                            .foregroundStyle(MM.ink2)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mmCard(radius: 16, shadow: .none, fill: MM.brand.opacity(0.06))
                }

                SectionHeader(title: "智能分类", trailing: "\(CleanCategory.allCases.count) 类")
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(CleanCategory.allCases.enumerated()), id: \.element) { idx, cat in
                        NavigationLink(value: Route.category(cat)) {
                            CategoryCard(category: cat)
                        }
                        .buttonStyle(PressableStyle())
                        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })
                        .staggerIn(idx + 1)
                    }
                }

                if !store.months.isEmpty {
                    SectionHeader(title: "按月份整理", trailing: "左右滑动")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.months.prefix(24)) { m in
                                NavigationLink(value: Route.month(m.id)) {
                                    MonthChip(month: m)
                                        .frame(width: 144, height: 166)
                                        .coverFlow()
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .snapTarget()
                        .padding(.horizontal, 2)
                        .padding(.vertical, 12)
                    }
                    .snapScroll()
                    .padding(.horizontal, -2)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 18)
        }
        .background(MM.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if !store.toDelete.isEmpty {
                NavigationLink(value: Route.review) {
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(LinearGradient(colors: MM.deleteGradient, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                            .popOnChange(store.toDelete.count)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("待删除 \(store.toDelete.count) 项")
                                .font(MM.text(15, .bold))
                                .contentTransition(.numericText())
                                .animation(Motion.snappy, value: store.toDelete.count)
                            Text("可释放 \(Fmt.bytes(store.toDeleteBytes))")
                                .font(MM.text(12))
                                .opacity(0.7)
                        }
                        Spacer()
                        Text("去确认")
                            .font(MM.text(14, .bold))
                            .foregroundStyle(MM.inkDark)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(Color.white, in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 8).padding(.trailing, 8).padding(.vertical, 8)
                    .background(MM.inkDark, in: Capsule())
                    .shadow(color: MM.glow.opacity(0.3), radius: 18, y: 8)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
                }
                .buttonStyle(PressableStyle())
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

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("相册清理")
                    .font(MM.display(30, .semibold))
                    .foregroundStyle(MM.ink)
                Text("Photo Cleaner")
                    .font(MM.text(13, .medium))
                    .foregroundStyle(MM.muted)
            }
            Spacer()
            NavigationLink(value: Route.settings) {
                IconPill(icon: "slider.horizontal.3")
            }
            .buttonStyle(PressableStyle())
            Button {
                Haptics.light()
                store.startScan()
            } label: {
                IconPill(icon: "arrow.clockwise")
            }
            .buttonStyle(PressableStyle())
            .disabled(store.phase == .loading || store.phase == .analyzing)
            .opacity(store.phase == .loading || store.phase == .analyzing ? 0.4 : 1)
        }
        .padding(.top, 8)
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
                         colors: CleanCategory.similar.colors,
                         ids: store.months.first(where: { $0.id == key })?.ids ?? [])
        case .review:
            ReviewDeleteView()
        case .settings:
            SettingsView()
        }
    }
}

/// 顶部总览卡片：MiniMax 首屏的粉-珊瑚-橙渐变
struct HeaderCard: View {
    @EnvironmentObject var store: CleanupStore

    private var cleanableCount: Int {
        Set(CleanCategory.allCases
            .filter { $0 != .videos && $0 != .large }
            .flatMap { store.ids(in: $0) }).count
    }

    private var scanning: Bool { store.phase == .loading || store.phase == .analyzing }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Chip(text: scanning ? "正在扫描" : (store.phase == .done ? "扫描完成" : "未扫描"),
                     fg: .white, bg: Color.white.opacity(0.22))
                Spacer()
                Text("\(store.items.count) 项")
                    .font(MM.display(15, .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("相册共占用")
                    .font(MM.text(14, .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text(Fmt.bytes(store.totalBytes))
                    .font(MM.display(46, .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(Motion.smooth, value: store.totalBytes)
            }

            if scanning {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.25))
                            Capsule().fill(Color.white)
                                .frame(width: max(8, geo.size.width * CGFloat(store.progress)))
                                .animation(.easeOut(duration: 0.3), value: store.progress)
                        }
                    }
                    .frame(height: 8)
                    Text(store.progressText)
                        .font(MM.text(12, .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                    Text(store.phase == .done
                         ? "发现 \(cleanableCount) 张可能可以清理的照片"
                         : "点右上角刷新开始扫描")
                        .font(MM.text(14, .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(MM.inkDark)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color.white.opacity(0.92), in: Capsule())
            }
        }
        .padding(22)
        .background(
            ZStack {
                LinearGradient(colors: MM.heroGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                DriftingBlobs(colors: [Color(hex: 0x8B5CF6)])
            }
            .clipShape(RoundedRectangle(cornerRadius: MM.rCard, style: .continuous))
        )
        .shadow(color: MM.heroGradient[1].opacity(0.35), radius: 20, y: 10)
    }
}

/// 分类卡：仿 MiniMax 官网「Flagship Models」卡 —— 白色外框 + 内嵌渐变插画区 + 下方文字
struct CategoryCard: View {
    @EnvironmentObject var store: CleanupStore
    let category: CleanCategory

    var body: some View {
        let ids = store.ids(in: category)
        let pending = store.undecided(ids).count
        let analyzing = store.phase != .done && (category == .similar || category == .blurry || category == .poorLight)
        VStack(alignment: .leading, spacing: 0) {
            GradientArt(colors: category.colors)
                .frame(height: 112)
                .overlay(alignment: .topLeading) {
                    Image(systemName: category.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.22), in: Circle())
                        .padding(10)
                }
                .overlay(alignment: .topTrailing) {
                    Group {
                        if analyzing {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else if pending > 0 {
                            Text("\(pending) 待看")
                                .font(MM.text(11, .bold))
                                .foregroundStyle(category.colors[0])
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.white, in: Capsule())
                        }
                    }
                    .padding(12)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(ids.count)")
                            .font(MM.display(36, .semibold))
                            .contentTransition(.numericText())
                            .animation(Motion.snappy, value: ids.count)
                        Text("项").font(MM.text(12, .medium)).opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.bottom, 8)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(category.title)
                        .font(MM.text(15, .bold))
                        .foregroundStyle(MM.ink)
                    Spacer()
                    Text(Fmt.bytes(store.bytes(of: ids)))
                        .font(MM.display(12, .medium))
                        .foregroundStyle(MM.muted)
                }
                Text(category.subtitle)
                    .font(MM.text(11.5))
                    .foregroundStyle(MM.ink2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .padding(6)
        .mmCard(radius: MM.rCard)
    }
}

struct MonthChip: View {
    @EnvironmentObject var store: CleanupStore
    let month: MonthGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if let first = month.ids.first, let item = store.item(first) {
                    AssetImageView(asset: item.asset, targetSize: CGSize(width: 132, height: 100))
                        .frame(width: 132, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Text("\(month.ids.count)")
                    .font(MM.display(12, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(month.title)
                    .font(MM.text(14, .bold))
                    .foregroundStyle(MM.ink)
                Text("待看 \(store.undecided(month.ids).count)")
                    .font(MM.text(11.5))
                    .foregroundStyle(MM.muted)
            }
            .padding(.horizontal, 4)
        }
        .padding(6)
        .padding(.bottom, 4)
        .mmCard(radius: 22, shadow: .glow)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
