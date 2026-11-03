import SwiftUI

/// 网格多选：点一下标记/取消删除，长按预览
struct GridSelectView: View {
    @EnvironmentObject var store: CleanupStore
    let ids: [String]
    @State private var preview: PhotoItem?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        ScrollView {
            HStack(spacing: 10) {
                Button {
                    Haptics.medium()
                    withAnimation(Motion.snappy) { store.markAll(ids.filter { store.decision(for: $0) != .keep }, .delete) }
                } label: {
                    Label("全选删除", systemImage: "checkmark.circle.fill")
                        .font(MM.text(14, .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10).padding(.horizontal, 16)
                        .background(MM.inkDark, in: Capsule())
                }
                .buttonStyle(PressableStyle())

                Button {
                    Haptics.light()
                    withAnimation(Motion.snappy) { store.markAll(ids.filter { store.toDelete.contains($0) }, nil) }
                } label: {
                    Label("全部取消", systemImage: "xmark")
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)

            Text("点一下标记删除，长按查看大图。标记了「保留」的照片不会被全选。")
                .font(MM.text(12))
                .foregroundStyle(MM.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 8) {
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
                            .staggerIn(min(idx, 12))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 100)
        }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }
}
