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
                HStack(spacing: 0) {
                    ForEach(AppTab.allCases) { t in
                        VStack(spacing: 3) {
                            Image(systemName: t.icon).font(.system(size: 19, weight: .semibold))
                            Text(t.title).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(t == tab ? Theme.blue : Theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background {
                            if t == tab {
                                Capsule().fill(Color.white.opacity(0.12))
                                    .matchedGeometryEffect(id: "tabSel", in: tabNS)
                            }
                        }
                        .contentShape(Capsule())
                        .onTapPoint { select(t, at: $0) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(t == tab ? [.isButton, .isSelected] : .isButton)
                    }
                }
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
