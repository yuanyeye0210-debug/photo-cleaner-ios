import SwiftUI

/// 某个分类：可在「滑动筛选」和「网格多选」之间切换
struct CategoryView: View {
    @EnvironmentObject var store: CleanupStore
    let title: String
    let ids: [String]

    enum Mode: String, CaseIterable, Identifiable {
        case swipe = "滑动筛选"
        case grid = "网格多选"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .swipe

    private var markedCount: Int { ids.filter { store.toDelete.contains($0) }.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Segmented(options: Mode.allCases, selection: $mode, label: { $0.rawValue })
                HStack {
                    Text("\(ids.count) 项 · \(Fmt.bytes(store.bytes(of: ids)))")
                        .foregroundStyle(Theme.text3)
                    Spacer()
                    if markedCount > 0 {
                        Text("已选删除 \(markedCount)")
                            .foregroundStyle(Theme.danger)
                            .contentTransition(.numericText())
                    }
                }
                .font(Theme.caption)
                .animation(Theme.spring, value: markedCount)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 8)

            if ids.isEmpty {
                EmptyStateView(icon: "checkmark", title: "这里很干净",
                               message: store.phase == .done ? "没有找到需要清理的内容" : "还在分析中，稍后再来看看")
            } else {
                switch mode {
                case .swipe:
                    SwipeReviewView(ids: ids)
                case .grid:
                    GridSelectView(ids: ids)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            IconBadge(icon: icon, size: 56)
            Text(title).font(Theme.title).foregroundStyle(Theme.text)
                .padding(.top, 4)
            Text(message)
                .font(Theme.callout)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
