import SwiftUI

/// 最终确认页：汇总所有待删除项，真正调用系统删除
struct ReviewDeleteView: View {
    @EnvironmentObject var store: CleanupStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 6)]

    private var sortedIDs: [String] {
        store.toDelete.sorted { (store.item($0)?.fileSize ?? 0) > (store.item($1)?.fileSize ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("可释放空间")
                        .font(Theme.callout)
                        .foregroundStyle(Theme.text2)
                    Text(Fmt.bytes(store.toDeleteBytes))
                        .font(Theme.number(36, .bold))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                        .animation(Theme.springSoft, value: store.toDeleteBytes)
                    Text("共 \(store.toDelete.count) 项 · 删除后进入「最近删除」，30 天内可恢复")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 18)

                SectionHeader(title: "待删除", trailing: "点缩略图可移出")

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(sortedIDs, id: \.self) { id in
                        if let item = store.item(id) {
                            ThumbnailCell(item: item)
                                .onTapGesture {
                                    Haptics.light()
                                    withAnimation(Theme.spring) { store.set(id, nil) }
                                }
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("确认删除")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") {
                    withAnimation(Theme.spring) { store.markAll(Array(store.toDelete), nil) }
                }
                .disabled(store.toDelete.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.warning()
                deleting = true
                Task {
                    let ok = await store.deleteMarked()
                    deleting = false
                    if ok { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if deleting { ProgressView().tint(.white) }
                    Text("删除 \(store.toDelete.count) 项")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(destructive: true))
            .disabled(store.toDelete.isEmpty || deleting)
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Theme.bg.opacity(0.95).ignoresSafeArea())
        }
    }
}
