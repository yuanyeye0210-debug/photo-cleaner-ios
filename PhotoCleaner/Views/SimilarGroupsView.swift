import SwiftUI

/// 分组清理：相似照片（推荐最好的一张）、完全重复（留最早的原件）、连拍（留系统选中的一张）
struct SimilarGroupsView: View {
    @EnvironmentObject var store: CleanupStore
    var category: CleanCategory = .similar
    @State private var confirmAll = false
    @State private var preview: PhotoItem?

    private var groups: [[String]] { store.groups(for: category) }

    private var emptyTitle: String {
        switch category {
        case .exactDuplicates: return String(localized: "没有完全重复的文件")
        case .bursts: return String(localized: "没有连拍")
        default: return String(localized: "没有相似照片")
        }
    }

    private var emptyMessage: String {
        switch category {
        case .exactDuplicates: return String(localized: "相册里没有一模一样的照片或视频")
        case .bursts: return String(localized: "相册里没有连拍照片")
        default: return String(localized: "相册里没有发现长得像的照片")
        }
    }

    private var summaryText: String {
        switch category {
        case .exactDuplicates: return String(localized: "文件一模一样，每组留最早的一份")
        case .bursts: return String(localized: "每组连拍留系统挑中的一张（你在相册里选过的优先）")
        default: return String(localized: "每组留最好的一张（看表情、AI 评分和清晰度）")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if store.isScanning && category != .bursts {
                    VStack(alignment: .leading, spacing: 8) {
                        ThinProgress(value: store.progress)
                        Text(store.progressText).font(Theme.caption).foregroundStyle(Theme.text3)
                    }
                    .card(padding: 16)
                }

                if groups.isEmpty && !store.isScanning {
                    EmptyStateView(icon: "checkmark", title: emptyTitle, message: emptyMessage)
                        .frame(minHeight: 400)
                }

                if !groups.isEmpty {
                    summary
                    SectionHeader(title: String(localized: "\(groups.count) 组"),
                                  trailing: String(localized: "点照片切换选择 · 长按看大图"))
                }

                ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                    GroupCard(group: group, category: category, preview: $preview)
                        .fadeIn(idx + 1)
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("每组只保留一张，其余全部选为删除？", isPresented: $confirmAll, titleVisibility: .visible) {
            Button("全部处理（\(extraCount) 张）", role: .destructive) {
                withAnimation(Theme.spring) {
                    if category == .similar {
                        for g in groups { store.keepBestDeleteRest(g, category: category) }
                    } else {
                        store.keepOneInAllGroups(category)
                    }
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
        groups.reduce(0) { $0 + max(0, $1.count - 1) }
    }

    private var extraBytes: Int64 {
        groups.reduce(Int64(0)) { sum, g in
            let best = store.keeperID(in: g, category: category)
            return sum + store.bytes(of: g.filter { $0 != best })
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summaryText)
                        .font(Theme.callout)
                        .foregroundStyle(Theme.text2)
                    Text("可释放 \(Fmt.bytes(extraBytes))")
                        .font(Theme.number(26, .bold))
                        .foregroundStyle(Theme.text)
                }
                Spacer()
                IconBadge(icon: category == .similar ? "sparkles" : category.icon, tint: category.tint)
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
    var category: CleanCategory = .similar
    @Binding var preview: PhotoItem?
    @State private var expanded = false
    @State private var confirmDeleteAll = false

    private var title: String {
        switch category {
        case .exactDuplicates: return String(localized: "\(group.count) 份相同")
        case .bursts: return String(localized: "\(group.count) 张连拍")
        default: return String(localized: "\(group.count) 张相似")
        }
    }

    var body: some View {
        let best = store.keeperID(in: group, category: category)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
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
                    PillBadge(text: expanded ? String(localized: "收起") : Fmt.bytes(store.bytes(of: group)),
                              tint: Theme.blue, style: .soft)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(expanded ? Text("收起") : Text("展开这一组"))
            }
            // 03 叠卡展开：一组照片先叠在一起，点一下依次摊开，收起时原路叠回
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(group.enumerated()), id: \.element) { i, id in
                        if let item = store.item(id) {
                          VStack(spacing: 6) {
                            ThumbnailCell(item: item, isBest: id == best)
                                .frame(width: 104, height: 104)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint(expanded ? Text("点按切换是否删除，长按查看大图") : Text("点按展开这一组"))
                                .accessibilityAction(named: Text("查看大图")) { preview = item }
                                .onTapGesture {
                                    Haptics.light()
                                    if expanded { store.toggleDelete(id) } else { expanded = true }
                                }
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    preview = item
                                }
                            // 分错了：把这张从组里拿出来，并记住（重新扫描也不会再分进来）
                            if expanded && category == .similar {
                                Button {
                                    Haptics.light()
                                    withAnimation(Theme.spring) { store.markNotSimilar(id, in: group) }
                                } label: {
                                    Label(String(localized: "不是相似"), systemImage: "rectangle.badge.minus")
                                        .font(Theme.caption)
                                        .foregroundStyle(Theme.text2)
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(Capsule().fill(Theme.fill))
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityHint(Text("把这张移出这一组，以后也不再分进来"))
                                .transition(.opacity)
                            }
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
                    withAnimation(Theme.spring) { store.keepBestDeleteRest(group, category: category) }
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
            Button {
                Haptics.light()
                confirmDeleteAll = true
            } label: {
                Label(String(localized: "整组全部删除"), systemImage: "trash")
            }
            .buttonStyle(SecondaryButtonStyle(tint: Theme.danger))
            .accessibilityHint(Text("这一组全部标记删除，一张都不保留"))
        }
        .card(padding: 14)
        .confirmationDialog(String(localized: "这组 \(group.count) 张全部标记删除，不保留？"),
                            isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button(String(localized: "全部标记删除"), role: .destructive) {
                Haptics.medium()
                withAnimation(Theme.spring) { _ = store.deleteWholeGroup(group) }
            }
            Button(String(localized: "取消"), role: .cancel) {}
        } message: {
            let fav = group.filter { store.item($0)?.isFavorite == true }.count
            if fav > 0 {
                Text("其中 \(fav) 张是收藏，不会被标记。标记后还要在「清理」页确认，系统也会再问一次才真正删除。")
            } else {
                Text("标记后还要在「清理」页确认，系统也会再问一次才真正删除。")
            }
        }
    }
}
