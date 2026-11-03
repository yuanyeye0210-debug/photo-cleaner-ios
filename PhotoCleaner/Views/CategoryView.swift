import SwiftUI

/// 某个分类：可在「滑动筛选」和「网格多选」之间切换
struct CategoryView: View {
    @EnvironmentObject var store: CleanupStore
    let title: String
    let colors: [Color]
    let ids: [String]

    enum Mode: String, CaseIterable, Identifiable {
        case swipe = "滑动筛选"
        case grid = "网格多选"
        var id: String { rawValue }
        var icon: String { self == .swipe ? "hand.draw" : "square.grid.3x3" }
    }
    @State private var mode: Mode = .swipe

    private var markedCount: Int { ids.filter { store.toDelete.contains($0) }.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                PillSegment(options: Mode.allCases, selection: $mode, label: { $0.rawValue }, icon: { $0.icon })

                HStack(spacing: 8) {
                    Chip(text: "共 \(ids.count) 项")
                    Chip(text: Fmt.bytes(store.bytes(of: ids)))
                    Spacer()
                    if markedCount > 0 {
                        Chip(text: "已标记删除 \(markedCount)", fg: MM.danger, bg: MM.danger.opacity(0.1))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: markedCount)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 10)

            if ids.isEmpty {
                EmptyStateView(icon: "checkmark", title: "这里很干净",
                               message: store.phase == .done ? "没有找到需要清理的内容" : "还在分析中，稍后再来看看")
            } else {
                switch mode {
                case .swipe:
                    SwipeReviewView(ids: ids, colors: colors)
                case .grid:
                    GridSelectView(ids: ids)
                }
            }
        }
        .background(MM.canvas.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var colors: [Color] = [MM.success, Color(hex: 0x34D399)]

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            GradientArt(colors: colors, radius: 32)
                .frame(width: 112, height: 112)
                .overlay(Image(systemName: icon).font(.system(size: 44, weight: .bold)).foregroundStyle(.white))
                .shadow(color: colors[0].opacity(0.3), radius: 18, y: 8)
            Text(title).font(MM.display(24, .semibold)).foregroundStyle(MM.ink)
            Text(message)
                .font(MM.text(14))
                .foregroundStyle(MM.ink2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
