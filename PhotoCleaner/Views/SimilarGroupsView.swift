import SwiftUI

/// 相似照片分组：自动推荐每组最清晰的一张
struct SimilarGroupsView: View {
    @EnvironmentObject var store: CleanupStore
    @State private var confirmAll = false
    @State private var preview: PhotoItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if store.phase != .done {
                    VStack(spacing: 8) {
                        ProgressView(value: store.progress)
                        Text(store.progressText).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }

                if store.similarGroups.isEmpty && store.phase == .done {
                    EmptyStateView(icon: "checkmark.circle.fill", title: "没有相似照片", message: "你的相册里没有发现连拍或重复照片")
                        .frame(minHeight: 400)
                }

                if !store.similarGroups.isEmpty {
                    summary
                }

                ForEach(Array(store.similarGroups.enumerated()), id: \.offset) { _, group in
                    GroupCard(group: group, preview: $preview)
                }
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("相似照片")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("每组只保留推荐的最佳一张，其余全部标记删除？", isPresented: $confirmAll, titleVisibility: .visible) {
            Button("全部处理（\(extraCount) 张标记删除）", role: .destructive) {
                withAnimation {
                    for g in store.similarGroups { store.keepBestDeleteRest(g) }
                }
                Haptics.success()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只是标记，不会立刻删除。最后还需要你在确认页再确认一次。")
        }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }

    private var extraCount: Int {
        store.similarGroups.reduce(0) { $0 + max(0, $1.count - 1) }
    }

    private var extraBytes: Int64 {
        store.similarGroups.reduce(Int64(0)) { sum, g in
            let best = store.bestID(in: g)
            return sum + store.bytes(of: g.filter { $0 != best })
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("找到 \(store.similarGroups.count) 组相似照片")
                .font(.headline)
            Text("每组只留最好的一张，可释放约 \(Fmt.bytes(extraBytes))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                Haptics.medium()
                confirmAll = true
            } label: {
                Label("一键智能清理全部", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct GroupCard: View {
    @EnvironmentObject var store: CleanupStore
    let group: [String]
    @Binding var preview: PhotoItem?

    var body: some View {
        let best = store.bestID(in: group)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(group.count) 张相似")
                    .font(.headline)
                if let first = group.first, let item = store.item(first) {
                    Text(Fmt.date(item.creationDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.bytes(store.bytes(of: group)))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group, id: \.self) { id in
                        if let item = store.item(id) {
                            ThumbnailCell(item: item, badge: id == best ? "★ 最佳" : nil)
                                .frame(width: 118, height: 118)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(id == best ? Color.yellow : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    Haptics.light()
                                    store.toggleDelete(id)
                                }
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    preview = item
                                }
                        }
                    }
                }
            }
            HStack {
                Button {
                    Haptics.medium()
                    withAnimation { store.keepBestDeleteRest(group) }
                } label: {
                    Label("保留最佳，删除其余 \(group.count - 1) 张", systemImage: "sparkles")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("全部保留") {
                    Haptics.light()
                    withAnimation { store.markAll(group, .keep) }
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
