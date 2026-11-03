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
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("可释放空间")
                        .font(.subheadline)
                        .opacity(0.85)
                    Text(Fmt.bytes(store.toDeleteBytes))
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                    Text("共 \(store.toDelete.count) 项")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(LinearGradient(colors: [.red, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                Label("点击下方按钮后，iPhone 会弹出系统确认框。删除的照片会进入「最近删除」，30 天内可以恢复。点一下缩略图可从清单中移除。", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(sortedIDs, id: \.self) { id in
                        if let item = store.item(id) {
                            ThumbnailCell(item: item)
                                .onTapGesture {
                                    Haptics.light()
                                    withAnimation { store.set(id, nil) }
                                }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("确认删除")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空清单") {
                    withAnimation { store.markAll(Array(store.toDelete), nil) }
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
                HStack {
                    if deleting { ProgressView().tint(.white) }
                    Image(systemName: "trash.fill")
                    Text("删除 \(store.toDelete.count) 项，释放 \(Fmt.bytes(store.toDeleteBytes))")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(colors: [.red, .pink]))
            .disabled(store.toDelete.isEmpty || deleting)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
