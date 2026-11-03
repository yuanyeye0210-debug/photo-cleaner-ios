import SwiftUI

/// 相似照片分组：自动推荐每组最清晰的一张
struct SimilarGroupsView: View {
    @EnvironmentObject var store: CleanupStore
    @State private var confirmAll = false
    @State private var preview: PhotoItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.phase != .done {
                    VStack(alignment: .leading, spacing: 8) {
                        ThinProgress(value: store.progress)
                        Text(store.progressText).font(Theme.caption).foregroundStyle(Theme.text3)
                    }
                    .card(padding: 16)
                }

                if store.similarGroups.isEmpty && store.phase == .done {
                    EmptyStateView(icon: "checkmark", title: "没有相似照片", message: "相册里没有发现连拍或重复照片")
                        .frame(minHeight: 400)
                }

                if !store.similarGroups.isEmpty {
                    summary
                    SectionHeader(title: "\(store.similarGroups.count) 组", trailing: "点照片切换选择 · 长按看大图")
                }

                ForEach(Array(store.similarGroups.enumerated()), id: \.offset) { idx, group in
                    GroupCard(group: group, preview: $preview)
                        .fadeIn(idx + 1)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("相似照片")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("每组只保留推荐的一张，其余全部选为删除？", isPresented: $confirmAll, titleVisibility: .visible) {
            Button("全部处理（\(extraCount) 张）", role: .destructive) {
                withAnimation(Theme.spring) {
                    for g in store.similarGroups { store.keepBestDeleteRest(g) }
                }
                Haptics.success()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只是标记，不会立刻删除。最后还要在确认页再确认一次。")
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("每组留最清晰的一张")
                        .font(Theme.callout)
                        .foregroundStyle(Theme.text2)
                    Text("可释放 \(Fmt.bytes(extraBytes))")
                        .font(Theme.number(26, .bold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                IconBadge(icon: "sparkles", tint: Theme.purple)
            }
            Button {
                Haptics.medium()
                confirmAll = true
            } label: {
                Text("一键处理全部 \(extraCount) 张").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .card(padding: 18)
        .fadeIn(0)
    }
}

private struct GroupCard: View {
    @EnvironmentObject var store: CleanupStore
    let group: [String]
    @Binding var preview: PhotoItem?
    @State private var expanded = false

    var body: some View {
        let best = store.bestID(in: group)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(group.count) 张相似")
                    .font(Theme.headline)
                    .foregroundStyle(Theme.text)
                if let first = group.first, let item = store.item(first) {
                    Text(Fmt.date(item.creationDate))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text3)
                }
                Spacer()
                Button {
                    Haptics.light()
                    expanded.toggle()
                } label: {
                    PillBadge(text: expanded ? "收起" : Fmt.bytes(store.bytes(of: group)),
                              tint: Theme.blue, style: .soft)
                }
                .buttonStyle(PressableStyle())
            }
            // 03 叠卡展开：一组照片先叠在一起，点一下依次摊开，收起时原路叠回
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(group.enumerated()), id: \.element) { i, id in
                        if let item = store.item(id) {
                            ThumbnailCell(item: item, isBest: id == best)
                                .frame(width: 104, height: 104)
                                .onTapGesture {
                                    Haptics.light()
                                    if expanded { store.toggleDelete(id) } else { expanded = true }
                                }
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    preview = item
                                }
                                .fanOut(index: i, count: group.count, expanded: expanded, step: 110, axis: .horizontal)
                        }
                    }
                }
                .padding(2)
            }
            .scrollDisabled(!expanded)
            HStack(spacing: 8) {
                Button {
                    Haptics.medium()
                    withAnimation(Theme.spring) { store.keepBestDeleteRest(group) }
                } label: {
                    Text("保留推荐，删其余 \(group.count - 1) 张")
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.accent))
                Spacer()
                Button("全部保留") {
                    Haptics.light()
                    withAnimation(Theme.spring) { store.markAll(group, .keep) }
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.text2))
            }
        }
        .card(padding: 14)
    }
}
