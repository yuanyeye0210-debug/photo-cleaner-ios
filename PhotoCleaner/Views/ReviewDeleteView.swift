import SwiftUI

/// 最终确认页：汇总所有待删除项，真正调用系统删除
struct ReviewDeleteView: View {
    @EnvironmentObject var store: CleanupStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    private var sortedIDs: [String] {
        store.toDelete.sorted { (store.item($0)?.fileSize ?? 0) > (store.item($1)?.fileSize ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Chip(text: "共 \(store.toDelete.count) 项", fg: .white, bg: Color.white.opacity(0.22))
                    Text("可释放空间")
                        .font(MM.text(14, .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 8)
                    Text(Fmt.bytes(store.toDeleteBytes))
                        .font(MM.display(50, .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(Motion.smooth, value: store.toDeleteBytes)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(
                    ZStack {
                        LinearGradient(colors: MM.deleteGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        DriftingBlobs(colors: [MM.pink])
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MM.rCard, style: .continuous))
                )
                .shadow(color: MM.danger.opacity(0.3), radius: 20, y: 10)
                .staggerIn(0)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundStyle(MM.brand)
                    Text("点下方按钮后，iPhone 会弹出系统确认框。删除的照片进入「最近删除」，30 天内可恢复。点缩略图可从清单移除。")
                        .font(MM.text(13))
                        .foregroundStyle(MM.ink2)
                }
                .padding(14)
                .mmCard(radius: 16, shadow: .none, fill: MM.surface)

                SectionHeader(title: "待删除清单", trailing: "按大小排序")

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(sortedIDs, id: \.self) { id in
                        if let item = store.item(id) {
                            ThumbnailCell(item: item)
                                .onTapGesture {
                                    Haptics.light()
                                    withAnimation(Motion.snappy) { store.set(id, nil) }
                                }
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(18)
            .padding(.bottom, 100)
        }
        .background(MM.canvas.ignoresSafeArea())
        .navigationTitle("确认删除")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空清单") {
                    withAnimation(Motion.snappy) { store.markAll(Array(store.toDelete), nil) }
                }
                .font(MM.text(14, .medium))
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
                    Image(systemName: "trash.fill")
                    Text("删除 \(store.toDelete.count) 项，释放 \(Fmt.bytes(store.toDeleteBytes))")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(colors: MM.deleteGradient))
            .disabled(store.toDelete.isEmpty || deleting)
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
        }
    }
}
