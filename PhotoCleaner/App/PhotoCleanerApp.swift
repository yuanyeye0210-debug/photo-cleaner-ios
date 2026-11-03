import SwiftUI

@main
struct PhotoCleanerApp: App {
    @StateObject private var store = CleanupStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        Group {
            if store.hasAccess {
                MainTabs()
            } else {
                PermissionView()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)      // 强制深色
        .onAppear {
            if store.hasAccess && store.phase == .idle { store.startScan() }
        }
    }
}

enum AppTab: Int, CaseIterable, Identifiable {
    case home, library, clean
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: return "首页"
        case .library: return "分类"
        case .clean: return "清理"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .library: return "square.grid.2x2.fill"
        case .clean: return "trash.fill"
        }
    }
}

/// 三个页签 + 悬浮玻璃页签栏 + 独立圆形操作按钮
/// 切页用「圆形扩散转场」：往右的页签从指尖处扩散铺满，往左时当前页原路缩回
struct MainTabs: View {
    @EnvironmentObject var store: CleanupStore

    @State private var tab: AppTab = .home
    @State private var leaving: AppTab?
    @State private var expanding = true
    @State private var reveal: CGFloat = 1
    @State private var origins: [AppTab: CGPoint] = [:]
    @State private var paths: [AppTab: [Route]] = [:]
    @State private var showSettings = false
    /// 手指在页签栏上拖动时的位置（全局坐标 x）；nil 表示没在拖
    @State private var dragX: CGFloat?
    @State private var hoverTab: AppTab?

    @Namespace private var glassNS
    @Namespace private var tabNS

    private var scanning: Bool { store.phase == .loading || store.phase == .analyzing }
    private var tabBarVisible: Bool { (paths[tab] ?? []).isEmpty }

    /// 正在做转场的那一层
    private var animatingTab: AppTab? {
        guard let leaving else { return nil }
        return expanding ? tab : leaving
    }

    private var layers: [AppTab] {
        guard let leaving else { return [tab] }
        return expanding ? [leaving, tab] : [tab, leaving]
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ForEach(layers) { t in
                page(t)
                    .mask {
                        CircleRevealShape(center: origins[t] ?? CGPoint(x: 200, y: 900),
                                          progress: t == animatingTab ? reveal : 1)
                            .ignoresSafeArea()
                    }
                    .zIndex(t == animatingTab ? 1 : 0)
                    .allowsHitTesting(leaving == nil)
            }
        }
        .overlay(alignment: .bottom) {
            if tabBarVisible {
                tabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: tabBarVisible)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showSettings = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .glassSheetBackground()
            .preferredColorScheme(.dark)
        }
    }

    private func pathBinding(_ t: AppTab) -> Binding<[Route]> {
        Binding(get: { paths[t] ?? [] }, set: { paths[t] = $0 })
    }

    @ViewBuilder
    private func page(_ t: AppTab) -> some View {
        NavigationStack(path: pathBinding(t)) {
            Group {
                switch t {
                case .home:
                    DashboardView(openSettings: { showSettings = true })
                case .library:
                    LibraryView()
                case .clean:
                    ReviewDeleteView(inTab: true)
                }
            }
            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
        }
    }

    private func select(_ t: AppTab, at point: CGPoint) {
        guard t != tab, leaving == nil else { return }
        Haptics.light()
        let forward = t.rawValue > tab.rawValue
        if forward { origins[t] = point }
        expanding = forward
        reveal = forward ? 0 : 1
        withAnimation(Theme.spring) {
            leaving = tab
            tab = t
        }
        DispatchQueue.main.async {
            withAnimation(Motion.reveal) { reveal = forward ? 1 : 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            leaving = nil
            reveal = 1
        }
    }

    // MARK: 悬浮玻璃页签栏 + 圆形按钮（iOS 26 上两块玻璃会相互融合形变）

    private var tabBar: some View {
        GlassGroup(spacing: 18) {
            HStack(spacing: 12) {
                GeometryReader { geo in
                    let frame = geo.frame(in: .global)
                    let count = CGFloat(AppTab.allCases.count)
                    let segW = frame.width / count
                    let shown = hoverTab ?? tab
                    // 高亮胶囊：拖动时跟着手指走，松手吸附到选中的页签
                    let center: CGFloat = {
                        if let x = dragX {
                            return min(max(x - frame.minX, segW / 2), frame.width - segW / 2)
                        }
                        return (CGFloat(tab.rawValue) + 0.5) * segW
                    }()
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(dragX == nil ? 0.12 : 0.18))
                            .frame(width: segW, height: 54)
                            .scaleEffect(dragX == nil ? 1 : 1.08)
                            .offset(x: center - segW / 2)
                            .animation(dragX == nil ? .spring(response: 0.4, dampingFraction: 0.75)
                                                    : .interactiveSpring(response: 0.18, dampingFraction: 0.86),
                                       value: center)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragX == nil)

                        HStack(spacing: 0) {
                            ForEach(AppTab.allCases) { t in
                                VStack(spacing: 3) {
                                    Image(systemName: t.icon).font(.system(size: 19, weight: .semibold))
                                    Text(t.title).font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(t == shown ? Theme.blue : Theme.text)
                                .scaleEffect(dragX != nil && t == shown ? 1.1 : 1)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shown)
                                .frame(width: segW, height: 54)
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(t == tab ? [.isButton, .isSelected] : .isButton)
                                .accessibilityAction { select(t, at: CGPoint(x: frame.minX + (CGFloat(t.rawValue) + 0.5) * segW, y: frame.midY)) }
                            }
                        }
                    }
                    .contentShape(Capsule())
                    // 按住左右拖：手在哪高亮就到哪，松手切到对应页签；轻点也能直接切
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .onChanged { v in
                                dragX = v.location.x
                                let i = Int(((v.location.x - frame.minX) / segW).rounded(.down))
                                let t = AppTab(rawValue: min(max(i, 0), AppTab.allCases.count - 1)) ?? tab
                                if t != hoverTab {
                                    if hoverTab != nil { Haptics.light() }
                                    hoverTab = t
                                }
                            }
                            .onEnded { v in
                                let target = hoverTab ?? tab
                                dragX = nil
                                hoverTab = nil
                                select(target, at: v.location)
                            }
                    )
                }
                .frame(height: 54)
                .padding(5)
                .glassSurface(Capsule(), interactive: true)
                .glassID("tabs", in: glassNS)

                if tab != .clean {
                    Button {
                        Haptics.medium()
                        store.startScan()
                    } label: {
                        Image(systemName: scanning ? "hourglass" : "arrow.clockwise")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 64, height: 64)
                            .contentShape(Circle())
                            .glassSurface(Circle(), interactive: true)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(scanning)
                    .glassID("action", in: glassNS)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .accessibilityLabel("重新扫描")
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: tab)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}
