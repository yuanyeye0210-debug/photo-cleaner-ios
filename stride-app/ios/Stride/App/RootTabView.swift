import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("今日", systemImage: "sun.horizon.fill") }
            .tag(0)

            NavigationStack {
                TrainingHomeView()
            }
            .tabItem { Label("训练", systemImage: "dumbbell.fill") }
            .tag(1)

            NavigationStack {
                ProgressViewScreen()
            }
            .tabItem { Label("进度", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(2)

            NavigationStack {
                CoachView()
            }
            .tabItem { Label("教练", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(3)

            NavigationStack {
                MeView()
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .tag(4)
        }
        .background(Palette.bg)
    }
}
