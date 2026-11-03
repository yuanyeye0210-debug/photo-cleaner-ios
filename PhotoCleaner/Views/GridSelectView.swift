import SwiftUI

/// 网格多选：点一下标记/取消删除，长按预览
struct GridSelectView: View {
    @EnvironmentObject var store: CleanupStore
    let ids: [String]
    @State private var preview: PhotoItem?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 6)]

    var body: some View {
        ScrollView {
            HStack(spacing: 8) {
                Button {
                    Haptics.medium()
                    withAnimation(Theme.spring) { store.markAll(ids.filter { store.decision(for: $0) != .keep }, .delete) }
                } label: {
                    Label("全选", systemImage: "checkmark.circle")
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.accent))

                Button {
                    Haptics.light()
                    withAnimation(Theme.spring) { store.markAll(ids.filter { store.toDelete.contains($0) }, nil) }
                } label: {
                    Label("取消全选", systemImage: "circle")
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.text2))
                Spacer()
            }
            .padding(.horizontal, Theme.pagePadding)

            Text("点一下选中删除，长按看大图。已标记「保留」的不会被全选。")
                .font(Theme.caption)
                .foregroundStyle(Theme.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 2)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(ids.enumerated()), id: \.element) { idx, id in
                    if let item = store.item(id) {
                        ThumbnailCell(item: item)
                            .onTapGesture {
                                Haptics.light()
                                store.toggleDelete(id)
                            }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                Haptics.medium()
                                preview = item
                            }
                            .fadeIn(idx)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 100)
        }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }
}
