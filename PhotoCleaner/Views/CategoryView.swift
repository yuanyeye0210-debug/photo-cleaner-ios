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
    }
    @State private var mode: Mode = .swipe

    var body: some View {
        VStack(spacing: 0) {
            Picker("模式", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            HStack {
                Text("共 \(ids.count) 项 · \(Fmt.bytes(store.bytes(of: ids)))")
                Spacer()
                Text("已标记删除 \(ids.filter { store.toDelete.contains($0) }.count)")
                    .foregroundStyle(.red)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.bottom, 4)

            if ids.isEmpty {
                EmptyStateView(icon: "checkmark.circle.fill", title: "这里很干净", message: store.phase == .done ? "没有找到需要清理的内容" : "还在分析中，稍后再来看看")
            } else {
                switch mode {
                case .swipe:
                    SwipeReviewView(ids: ids, colors: colors)
                case .grid:
                    GridSelectView(ids: ids)
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text(title).font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
