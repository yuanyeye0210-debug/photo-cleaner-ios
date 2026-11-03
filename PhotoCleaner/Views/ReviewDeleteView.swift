import SwiftUI

/// 最终确认页：汇总所有待删除项，真正调用系统删除
/// 01 完成反馈按钮：点删除 → 按钮收成圆 → 打勾 → 一圈粒子迸开
struct ReviewDeleteView: View {
    @EnvironmentObject var store: CleanupStore
    @Environment(\.dismiss) private var dismiss
    var inTab = false
    @State private var phase: CompletionPhase = .idle
    @State private var deletedCount = 0

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 6)]

    private var sortedIDs: [String] {
        store.toDelete.sorted { (store.item($0)?.fileSize ?? 0) > (store.item($1)?.fileSize ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if inTab {
                    Text("清理").font(Theme.largeTitle).foregroundStyle(Theme.text).padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 14) {
                    CardHeader(icon: "trash.fill", tint: Theme.danger, title: "可释放空间") {
                        PillBadge(text: "\(store.toDelete.count) 项", tint: Theme.orange)
                    }
                    BigNumber(value: phase == .done ? "\(deletedCount)" : Fmt.bytes(store.toDeleteBytes),
                              unit: phase == .done ? "项已删除" : nil, size: 44)
                    Text("删除后进入「最近删除」，30 天内可恢复")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text2)
                }
                .card(padding: 18)

                if store.toDelete.isEmpty && phase != .done {
                    EmptyStateView(icon: "trash", title: "还没有待删除", message: "在分类里左滑或点选照片，会出现在这里", tint: Theme.blue)
                        .frame(minHeight: 300)
                } else {
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
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, inTab ? 200 : 120)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(inTab ? "" : "确认删除")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(inTab ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") {
                    withAnimation(Theme.spring) { store.markAll(Array(store.toDelete), nil) }
                }
                .disabled(store.toDelete.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.toDelete.isEmpty || phase != .idle {
                deleteBar
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, inTab ? 86 : 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: store.toDelete.isEmpty)
    }

    /// 玻璃底栏 + 完成反馈按钮
    private var deleteBar: some View {
        HStack(spacing: 12) {
            if phase == .idle {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.toDelete.count) 项").font(Theme.number(17, .bold)).foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text(Fmt.bytes(store.toDeleteBytes)).font(Theme.caption).foregroundStyle(Theme.text2)
                }
                .transition(.opacity)
            }
            CompletionButton(title: "删除", tint: Theme.danger, phase: phase) { runDelete() }
        }
        .padding(10)
        .glassSurface(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(Theme.spring, value: phase)
    }

    private func runDelete() {
        Haptics.warning()
        let count = store.toDelete.count
        phase = .working
        Task {
            let ok = await store.deleteMarked()
            if ok {
                deletedCount = count
                phase = .done
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                if inTab { phase = .idle } else { dismiss() }
            } else {
                phase = .idle
            }
        }
    }
}
