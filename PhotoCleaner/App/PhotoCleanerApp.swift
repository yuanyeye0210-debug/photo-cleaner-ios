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
                NavigationStack {
                    DashboardView()
                }
            } else {
                PermissionView()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.light)
        .onAppear {
            if store.hasAccess && store.phase == .idle { store.startScan() }
        }
    }
}
