import SwiftUI

/// 网格多选：点一下标记/取消删除，长按预览
struct GridSelectView: View {
    @EnvironmentObject var store: CleanupStore
    let ids: [String]
    @State private var preview: PhotoItem?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 6)]

    var body: some View {
        ScrollView {
            HStack(spacing: 10) {
                Button {
                    Haptics.medium()
                    withAnimation { store.markAll(ids.filter { store.decision(for: $0) != .keep }, .delete) }
                } label: {
                    Label("全选删除", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    Haptics.light()
                    withAnimation { store.markAll(ids.filter { store.toDelete.contains($0) }, nil) }
                } label: {
                    Label("全部取消", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Text("点一下标记删除，长按查看大图。标记了「保留」的照片不会被全选。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(ids, id: \.self) { id in
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
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 100)
        }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }
}
