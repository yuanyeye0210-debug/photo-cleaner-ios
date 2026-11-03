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
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: store.progress).tint(MM.brand)
                        Text(store.progressText).font(MM.text(12)).foregroundStyle(MM.muted)
                    }
                    .padding(16)
                    .mmCard(radius: 18, shadow: .subtle)
                }

                if store.similarGroups.isEmpty && store.phase == .done {
                    EmptyStateView(icon: "checkmark.circle.fill", title: "没有相似照片", message: "你的相册里没有发现连拍或重复照片")
                        .frame(minHeight: 400)
                }

                if !store.similarGroups.isEmpty {
                    summary
                }

                ForEach(Array(store.similarGroups.enumerated()), id: \.offset) { idx, group in
                    GroupCard(group: group, preview: $preview)
                        .staggerIn(min(idx + 1, 8))
                }
            }
            .padding(18)
            .padding(.bottom, 80)
        }
        .background(MM.canvas.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.similarGroups.count) 组相似照片")
                    .font(MM.display(28, .semibold))
                Text("每组只留最好的一张，可释放约 \(Fmt.bytes(extraBytes))")
                    .font(MM.text(14, .medium))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            Button {
                Haptics.medium()
                confirmAll = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                    Text("一键智能清理全部")
                }
                .font(MM.text(15, .bold))
                .foregroundStyle(MM.inkDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: CleanCategory.similar.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                DriftingBlobs(colors: [Color(hex: 0x7C5CFF)])
            }
            .clipShape(RoundedRectangle(cornerRadius: MM.rCard, style: .continuous))
        )
        .shadow(color: MM.brand.opacity(0.3), radius: 20, y: 10)
        .staggerIn(0)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(group.count) 张相似")
                        .font(MM.text(16, .bold))
                        .foregroundStyle(MM.ink)
                    if let first = group.first, let item = store.item(first) {
                        Text(Fmt.date(item.creationDate))
                            .font(MM.text(12))
                            .foregroundStyle(MM.muted)
                    }
                }
                Spacer()
                Chip(text: Fmt.bytes(store.bytes(of: group)))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group, id: \.self) { id in
                        if let item = store.item(id) {
                            ThumbnailCell(item: item, badge: id == best ? "最佳" : nil)
                                .frame(width: 118, height: 118)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MM.rTile, style: .continuous)
                                        .stroke(id == best ? MM.brand : Color.clear, lineWidth: 3)
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
            HStack(spacing: 8) {
                Button {
                    Haptics.medium()
                    withAnimation(Motion.snappy) { store.keepBestDeleteRest(group) }
                } label: {
                    Label("留最佳，删其余 \(group.count - 1) 张", systemImage: "sparkles")
                        .font(MM.text(13, .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        .background(MM.inkDark, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                Spacer()
                Button("全部保留") {
                    Haptics.light()
                    withAnimation(Motion.snappy) { store.markAll(group, .keep) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .mmCard(radius: MM.rCard)
    }
}
