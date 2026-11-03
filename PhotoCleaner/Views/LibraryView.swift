import SwiftUI

/// 「分类」页：叠卡展开的分类列表 + 吸附时间线
struct LibraryView: View {
    @EnvironmentObject var store: CleanupStore

    enum Mode: String, CaseIterable, Identifiable {
        case stack = "分类"
        case timeline = "时间线"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .stack

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("分类")
                .font(Theme.largeTitle)
                .foregroundStyle(Theme.text)
                .padding(.top, 8)
            Segmented(options: Mode.allCases, selection: $mode, label: { $0.rawValue })

            switch mode {
            case .stack:
                ScrollView {
                    CategoryStack()
                        .padding(.top, 4)
                        .padding(.bottom, 120)
                }
            case .timeline:
                MonthTimeline()
                    .padding(.bottom, 92)
            }
        }
        .padding(.horizontal, Theme.pagePadding)
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// 03 叠卡展开：分类卡叠在一起，点一下依次展开，再点「收起」原路叠回去
struct CategoryStack: View {
    @EnvironmentObject var store: CleanupStore
    @State private var expanded = false
    private let rowHeight: CGFloat = 78
    private let spacing: CGFloat = 10

    var body: some View {
        let cats = CleanCategory.allCases
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(expanded ? "\(cats.count) 个分类" : "点卡片展开 \(cats.count) 个分类")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text2)
                Spacer()
                Button {
                    Haptics.light()
                    expanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(expanded ? "收起" : "展开")
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .glassSurface(Capsule(), interactive: true)
                }
                .buttonStyle(PressableStyle())
                .animation(Theme.spring, value: expanded)
            }

            VStack(spacing: spacing) {
                ForEach(Array(cats.enumerated()), id: \.element) { i, cat in
                    NavigationLink(value: Route.category(cat)) { row(cat) }
                        .buttonStyle(PressableStyle())
                        .allowsHitTesting(expanded)
                        .overlay {
                            if !expanded {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { Haptics.light(); expanded = true }
                            }
                        }
                    .fanOut(index: i, count: cats.count, expanded: expanded, step: rowHeight + spacing)
                }
            }
            .frame(height: expanded ? nil : rowHeight + 30, alignment: .top)
            .animation(Motion.fan, value: expanded)
        }
    }

    private func row(_ cat: CleanCategory) -> some View {
        let ids = store.ids(in: cat)
        return HStack(spacing: 12) {
            IconBadge(icon: cat.icon, tint: cat.tint, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(cat.title).font(Theme.headline).foregroundStyle(Theme.text)
                Text(cat.subtitle).font(Theme.caption).foregroundStyle(Theme.text2).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(ids.count)").font(Theme.number(20, .bold)).foregroundStyle(Theme.text)
                Text(Fmt.bytes(store.bytes(of: ids))).font(Theme.caption).foregroundStyle(Theme.text2)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text3)
        }
        .padding(.horizontal, 16)
        .frame(height: rowHeight)
        .card(radius: 22)
    }
}

/// 04 吸附卡 + 画线：按月份浏览
struct MonthTimeline: View {
    @EnvironmentObject var store: CleanupStore
    @State private var index = 0

    var body: some View {
        if store.months.isEmpty {
            EmptyStateView(icon: "calendar", title: "还没有数据", message: "扫描完成后按月份显示")
        } else {
            SnapTimeline(items: store.months, cardHeight: 200, index: $index) { month, active in
                MonthTimelineCard(month: month, active: active)
            }
        }
    }
}

struct MonthTimelineCard: View {
    @EnvironmentObject var store: CleanupStore
    let month: MonthGroup
    let active: Bool

    var body: some View {
        let marked = month.ids.filter { store.toDelete.contains($0) }.count
        let parts = month.id.split(separator: "-")
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(parts.count == 2 ? String(Int(parts[1]) ?? 0) : month.title)
                    .font(Theme.number(40, .bold))
                    .foregroundStyle(active ? Theme.orange : Theme.text)
                Text("月").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text2)
                Text(parts.first.map { String($0) } ?? "").font(Theme.caption).foregroundStyle(Theme.text3)
                Spacer()
                if marked > 0 { PillBadge(text: "删除 \(marked)", tint: Theme.danger) }
            }
            HStack(spacing: 6) {
                ForEach(month.ids.prefix(4), id: \.self) { id in
                    if let item = store.item(id) {
                        AssetImageView(asset: item.asset, targetSize: CGSize(width: 80, height: 80))
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            HStack {
                Text("\(month.ids.count) 项 · \(Fmt.bytes(store.bytes(of: month.ids)))")
                    .font(Theme.caption).foregroundStyle(Theme.text2)
                Spacer()
                NavigationLink(value: Route.month(month.id)) {
                    PillBadge(text: "整理", tint: Theme.blue, style: .soft, chevron: true)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .card()
        .overlay(RoundedRectangle(cornerRadius: Theme.rCard, style: .continuous)
            .stroke(active ? Theme.orange.opacity(0.35) : Color.clear, lineWidth: 1))
    }
}
