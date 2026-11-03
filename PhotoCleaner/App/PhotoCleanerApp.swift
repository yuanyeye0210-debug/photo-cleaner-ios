import SwiftUI

@main
struct PhotoCleanerApp: App {
    @StateObject private var store = CleanupStore()

    init() {
        FontRegistry.registerAll()
    }

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
                NavigationStack {
                    DashboardView()
                }
            } else {
                PermissionView()
            }
        }
        .tint(MM.brand)
        .preferredColorScheme(.light)
        .onAppear {
            if store.hasAccess && store.phase == .idle { store.startScan() }
        }
    }
}
