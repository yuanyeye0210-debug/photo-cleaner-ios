import SwiftUI

/// 某个分类：可在「滑动筛选」和「网格多选」之间切换
struct CategoryView: View {
    @EnvironmentObject var store: CleanupStore
    let title: String
    let ids: [String]
    var tint: Color = Theme.green
    var includeLater = false
    var category: CleanCategory? = nil

    enum Mode: String, CaseIterable, Identifiable {
        case swipe, grid
        var id: String { rawValue }
        var title: String {
            switch self {
            case .swipe: return String(localized: "滑动筛选")
            case .grid: return String(localized: "网格多选")
            }
        }
    }
    @State private var mode: Mode = .swipe

    var body: some View {
        let marked = ids.filter { store.toDelete.contains($0) }
        let done = ids.filter { store.decision(for: $0) != nil }.count
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // 02 勾选联动：标记任何一张，进度环 / 数字 / 底色同时变化
                LinkedProgressHeader(done: done, total: ids.count,
                                     marked: marked.count, markedBytes: store.bytes(of: marked),
                                     tint: tint)
                Segmented(options: Mode.allCases, selection: $mode, label: { $0.title })
                if category == .videos && !ids.isEmpty {
                    NavigationLink(value: Route.compressVideos) {
                        HStack(spacing: 10) {
                            IconBadge(icon: "wand.and.stars", tint: Theme.pink, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("压缩成 HEVC 省空间").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                                Text("画质几乎不变，原视频确认后再删").font(Theme.caption).foregroundStyle(Theme.text2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text3)
                        }
                        .card(radius: 18, padding: 12)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, 4)
            .padding(.bottom, 8)

            if ids.isEmpty {
                EmptyStateView(icon: "checkmark", title: String(localized: "这里很干净"),
                               message: store.isScanning ? String(localized: "还在分析中，稍后再来看看") : String(localized: "没有找到需要清理的内容"))
            } else {
                switch mode {
                case .swipe:
                    SwipeReviewView(ids: ids, includeLater: includeLater)
                case .grid:
                    GridSelectView(ids: ids)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = Theme.green

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            IconBadge(icon: icon, tint: tint, size: 60)
            Text.loc(title).font(Theme.title).foregroundStyle(Theme.text)
                .padding(.top, 4)
            Text.loc(message)
                .font(Theme.callout)
                .foregroundStyle(Theme.text2)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
