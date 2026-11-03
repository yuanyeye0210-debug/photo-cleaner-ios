import Charts
import Photos
import SwiftUI

// MARK: - 首页：iCloud 卡

/// 原图只在 iCloud 的照片：显示数量 + 允许下载来分析的开关
struct CloudCard: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(icon: "icloud.fill", tint: Theme.blue, title: String(localized: "iCloud 照片")) {
                PillBadge(text: String(localized: "\(store.cloudOnlyIDs.count) 张未分析"), tint: Theme.blue, style: .soft)
            }
            Text(store.cloudOnlyIDs.isEmpty
                 ? String(localized: "只在 iCloud 的照片都分析完了。")
                 : String(localized: "这些照片的原图只在 iCloud、没下载到本机，所以还没做 AI 分析（相似、模糊等分类里不会有它们）。"))
                .font(Theme.caption)
                .foregroundStyle(Theme.text2)
            Toggle(isOn: $store.allowCloudAnalysis) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("允许从 iCloud 下载来分析").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    Text("会用流量和电量，建议连着 Wi-Fi").font(Theme.caption).foregroundStyle(Theme.text3)
                }
            }
            .tint(Theme.accent)
        }
        .card(padding: 18)
    }
}

// MARK: - 首页：累计清理统计 + 近 30 天图表

struct StatsCard: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        let days = store.stats.daily(days: 30)
        let month = days.reduce(Int64(0)) { $0 + $1.bytes }
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(icon: "chart.bar.fill", tint: Theme.green, title: String(localized: "清理记录")) {
                PillBadge(text: String(localized: "近 30 天 \(Fmt.bytes(month))"), tint: Theme.green, style: .soft)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("累计释放").font(.system(size: 14)).foregroundStyle(Theme.text2)
                    Text(Fmt.bytes(store.stats.totalBytes))
                        .font(Theme.number(30, .bold)).foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("累计删除").font(.system(size: 14)).foregroundStyle(Theme.text2)
                    BigNumber(value: "\(store.stats.totalCount)", unit: String(localized: "项"), size: 30)
                }
                .frame(width: 130, alignment: .leading)
            }
            if store.stats.totalCount == 0 {
                Text("还没有清理记录。删除照片后，这里会按天显示释放了多少空间。")
                    .font(Theme.caption).foregroundStyle(Theme.text3)
            } else {
                Chart(days, id: \.date) { d in
                    BarMark(x: .value(String(localized: "日期"), d.date, unit: .day),
                            y: .value(String(localized: "释放 MB"), Double(d.bytes) / 1_000_000))
                        .foregroundStyle(Theme.green.gradient)
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(Theme.text3)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel().foregroundStyle(Theme.text3)
                    }
                }
                .frame(height: 120)
                .accessibilityLabel(Text("近 30 天释放了 \(Fmt.bytes(month))"))
            }
        }
        .card(padding: 18)
    }
}

// MARK: - 首页：小批量整理

struct QuickModesCard: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        HStack(spacing: Theme.gap) {
            ForEach(QuickMode.allCases) { m in
                NavigationLink(value: Route.quick(m)) {
                    VStack(alignment: .leading, spacing: 8) {
                        IconBadge(icon: m.icon, tint: tint(m), size: 30)
                        Text(m.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(detail(m)).font(Theme.caption).foregroundStyle(Theme.text2).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(radius: 20, padding: 12)
                }
                .buttonStyle(PressableStyle())
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func tint(_ m: QuickMode) -> Color {
        switch m {
        case .onThisDay: return Theme.orange
        case .random: return Theme.purple
        case .later: return Theme.blue
        }
    }

    private func detail(_ m: QuickMode) -> String {
        switch m {
        case .onThisDay: return String(localized: "\(store.undecided(store.quickIDs(.onThisDay)).count) 张")
        case .random: return String(localized: "滑一滑")
        case .later: return String(localized: "\(store.later.count) 张")
        }
    }
}

/// 小批量模式：那年今日 / 随机 10 张 / 稍后再看
struct QuickModeView: View {
    @EnvironmentObject var store: CleanupStore
    let mode: QuickMode
    @State private var ids: [String]?
    @State private var batch = 0

    var body: some View {
        Group {
            if let ids {
                if ids.isEmpty {
                    EmptyStateView(icon: mode.icon, title: emptyTitle, message: emptyMessage, tint: Theme.blue)
                        .background(Theme.bg.ignoresSafeArea())
                        .navigationTitle(mode.title)
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    CategoryView(title: mode.title, ids: ids, tint: Theme.blue, includeLater: mode == .later)
                        .id(batch)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.bg.ignoresSafeArea())
            }
        }
        .toolbar {
            if mode == .random {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.light()
                        load()
                        batch += 1
                    } label: { Image(systemName: "dice") }
                    .accessibilityLabel(Text("换一批"))
                }
            }
        }
        .onAppear { if ids == nil { load() } }
    }

    private func load() {
        if mode == .random { store.newRandomSample() }
        ids = store.quickIDs(mode)
    }

    private var emptyTitle: String {
        switch mode {
        case .onThisDay: return String(localized: "往年今天没有照片")
        case .random: return String(localized: "都整理完了")
        case .later: return String(localized: "没有稍后再看的照片")
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .onThisDay: return String(localized: "明天再来看看")
        case .random: return String(localized: "没有还没看过的照片了")
        case .later: return String(localized: "滑照片时往上滑，就会放到这里")
        }
    }
}

// MARK: - 视频压缩（HEVC）

struct CompressVideosView: View {
    @EnvironmentObject var store: CleanupStore
    @State private var selected: Set<String> = []
    @State private var status: [String: RowStatus] = [:]
    @State private var running = false
    @State private var current: String?
    @State private var currentProgress: Double = 0
    @State private var preview: PhotoItem?

    enum RowStatus: Equatable { case done(Int64), skipped(String), failed(String) }

    private var videos: [PhotoItem] {
        store.ids(in: .videos).compactMap { store.item($0) }.filter { !store.isReplaced($0.id) || status[$0.id] != nil }
    }

    var body: some View {
        let list = videos
        let selBytes = list.filter { selected.contains($0.id) }.reduce(Int64(0)) { $0 + $1.fileSize }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    CardHeader(icon: "wand.and.stars", tint: Theme.pink, title: String(localized: "压缩成 HEVC"))
                    Text("用苹果的 HEVC（H.265）重新编码，画质几乎不变，通常能省 30%~50%。已经是 HEVC 的会自动跳过。")
                        .font(Theme.caption).foregroundStyle(Theme.text2)
                    Text("新视频保留原来的拍摄时间、地点和收藏。原视频放进「待删除」，你确认后才会真的删除。压缩时请保持 App 在前台。")
                        .font(Theme.caption).foregroundStyle(Theme.text3)
                    if !selected.isEmpty {
                        Text("已选 \(selected.count) 个，预计省 \(Fmt.bytes(FileSizes.estimatedHEVCSavings(selBytes)))")
                            .font(Theme.number(15, .semibold)).foregroundStyle(Theme.text)
                    }
                }
                .card(padding: 16)

                if list.isEmpty {
                    EmptyStateView(icon: "video", title: String(localized: "没有视频"), message: String(localized: "相册里没有可以压缩的视频"))
                        .frame(minHeight: 300)
                } else {
                    HStack {
                        Button(selected.count == list.count ? String(localized: "取消全选") : String(localized: "全选")) {
                            Haptics.light()
                            selected = selected.count == list.count ? [] : Set(list.map(\.id))
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.accent))
                        .disabled(running)
                        Spacer()
                    }
                    ForEach(list, id: \.id) { v in row(v) }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 120)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(Text("压缩视频"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty || running {
                Button {
                    run(list.filter { selected.contains($0.id) })
                } label: {
                    HStack {
                        if running { ProgressView().tint(.white) }
                        Text(running ? String(localized: "正在压缩…") : String(localized: "压缩选中的 \(selected.count) 个"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(running)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 6)
            }
        }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func row(_ v: PhotoItem) -> some View {
        let isSel = selected.contains(v.id)
        return HStack(spacing: 12) {
            AssetImageView(asset: v.asset, targetSize: CGSize(width: 64, height: 64))
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onTapGesture { preview = v }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Fmt.bytes(v.fileSize)) · \(Fmt.duration(v.duration))")
                    .font(Theme.number(15, .semibold)).foregroundStyle(Theme.text)
                Text(Fmt.date(v.creationDate)).font(Theme.caption).foregroundStyle(Theme.text3)
                Group {
                    if current == v.id {
                        ThinProgress(value: currentProgress, tint: Theme.pink)
                    } else {
                        switch status[v.id] {
                        case .done(let saved):
                            Text("已压缩，省了 \(Fmt.bytes(saved))").foregroundStyle(Theme.green)
                        case .skipped(let why):
                            Text(why).foregroundStyle(Theme.text3)
                        case .failed(let why):
                            Text(why).foregroundStyle(Theme.danger)
                        case .none:
                            Text("预计省 \(Fmt.bytes(FileSizes.estimatedHEVCSavings(v.fileSize)))").foregroundStyle(Theme.text2)
                        }
                    }
                }
                .font(Theme.caption)
            }
            Spacer()
            Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSel ? Theme.accent : Theme.text3)
        }
        .padding(12)
        .card(radius: 18, padding: 0)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !running, status[v.id] == nil else { return }
            Haptics.light()
            if isSel { selected.remove(v.id) } else { selected.insert(v.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : .isButton)
    }

    private func run(_ list: [PhotoItem]) {
        guard !running, !list.isEmpty else { return }
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            for v in list {
                current = v.id
                currentProgress = 0
                do {
                    let out = try await MediaTools.compressVideo(v.asset, originalBytes: v.fileSize,
                                                                 allowNetwork: store.allowCloudAnalysis) { p in
                        Task { @MainActor in currentProgress = p }
                    }
                    store.registerReplacement(original: v.id, newBytes: out.newBytes)
                    status[v.id] = .done(max(0, v.fileSize - out.newBytes))
                } catch let e as MediaTools.Failure {
                    switch e {
                    case .alreadyEfficient, .noSavings: status[v.id] = .skipped(e.localizedDescription)
                    default: status[v.id] = .failed(e.localizedDescription)
                    }
                } catch {
                    status[v.id] = .failed(error.localizedDescription)
                }
                selected.remove(v.id)
            }
            current = nil
            running = false
            UIApplication.shared.isIdleTimerDisabled = false
            let ok = status.values.filter { if case .done = $0 { return true } else { return false } }.count
            if ok > 0 {
                Haptics.success()
                store.lastDeleteMessage = String(localized: "压缩好了 \(ok) 个视频。原视频已放进「待删除」，到「清理」页确认删除后才会真正省出空间。")
            }
        }
    }
}

// MARK: - 实况照片 → 静态照片

struct LivePhotosView: View {
    @EnvironmentObject var store: CleanupStore
    @State private var selected: Set<String> = []
    @State private var running = false
    @State private var done = 0
    @State private var total = 0
    @State private var failures: [String] = []
    @State private var preview: PhotoItem?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 6)]

    private var photos: [PhotoItem] {
        store.ids(in: .livePhotos).compactMap { store.item($0) }.filter { !store.isReplaced($0.id) }
    }

    /// 视频部分大小：读到真实值就用，没读到按整张的 45% 估
    private func liveBytes(_ p: PhotoItem) -> Int64 {
        p.liveVideoBytes > 0 ? p.liveVideoBytes : p.fileSize * 45 / 100
    }

    var body: some View {
        let list = photos
        let saving = list.filter { selected.contains($0.id) }.reduce(Int64(0)) { $0 + liveBytes($1) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    CardHeader(icon: "livephoto", tint: Theme.orange, title: String(localized: "转成静态照片"))
                    Text("实况照片里带了一段 3 秒的小视频。转成静态照片只保留照片（编辑过的保留编辑后的样子），拍摄时间、地点和收藏都不变。")
                        .font(Theme.caption).foregroundStyle(Theme.text2)
                    Text("原来的实况照片放进「待删除」，你确认后才会真的删除。")
                        .font(Theme.caption).foregroundStyle(Theme.text3)
                    Text("全部 \(list.count) 张，可省约 \(Fmt.bytes(list.reduce(Int64(0)) { $0 + liveBytes($1) }))")
                        .font(Theme.number(15, .semibold)).foregroundStyle(Theme.text)
                    if running {
                        ThinProgress(value: Double(done) / Double(max(1, total)), tint: Theme.orange)
                        Text("正在转换 \(done)/\(total)").font(Theme.caption).foregroundStyle(Theme.text2)
                    }
                    if !failures.isEmpty {
                        Text("有 \(failures.count) 张没转成功：\(failures.first ?? "")")
                            .font(Theme.caption).foregroundStyle(Theme.danger)
                    }
                }
                .card(padding: 16)

                if list.isEmpty {
                    EmptyStateView(icon: "livephoto", title: String(localized: "没有实况照片"),
                                   message: store.isScanning ? String(localized: "还在读取相册，稍后再来看看") : String(localized: "相册里没有需要转换的实况照片"))
                        .frame(minHeight: 300)
                } else {
                    HStack {
                        Button(selected.count == list.count ? String(localized: "取消全选") : String(localized: "全选")) {
                            Haptics.light()
                            selected = selected.count == list.count ? [] : Set(list.map(\.id))
                        }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.accent))
                        .disabled(running)
                        Spacer()
                        Text("点选 · 长按看大图").font(Theme.caption).foregroundStyle(Theme.text3)
                    }
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(list, id: \.id) { p in
                            let isSel = selected.contains(p.id)
                            ZStack(alignment: .topTrailing) {
                                AssetImageView(asset: p.asset, targetSize: CGSize(width: 110, height: 110))
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.rTile, style: .continuous))
                                Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(isSel ? Theme.accent : .white)
                                    .shadow(color: .black.opacity(0.4), radius: 2)
                                    .padding(6)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Text(Fmt.bytes(liveBytes(p)))
                                    .font(Theme.number(10, .medium)).foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 2).padding(6)
                            }
                            .onTapGesture {
                                guard !running else { return }
                                Haptics.light()
                                if isSel { selected.remove(p.id) } else { selected.insert(p.id) }
                            }
                            .onLongPressGesture(minimumDuration: 0.35) { preview = p }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("实况照片，\(Fmt.date(p.creationDate))，视频部分 \(Fmt.bytes(liveBytes(p)))"))
                            .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction(named: Text("查看大图")) { preview = p }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.bottom, 120)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(Text("实况照片"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !selected.isEmpty || running {
                Button { run(list.filter { selected.contains($0.id) }) } label: {
                    HStack {
                        if running { ProgressView().tint(.white) }
                        Text(running ? String(localized: "正在转换…")
                                     : String(localized: "转换 \(selected.count) 张，省约 \(Fmt.bytes(saving))"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(running)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 6)
            }
        }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }

    private func run(_ list: [PhotoItem]) {
        guard !running, !list.isEmpty else { return }
        running = true
        done = 0
        total = list.count
        failures = []
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            var ok = 0
            for p in list {
                do {
                    let out = try await MediaTools.convertLivePhoto(p.asset, allowNetwork: store.allowCloudAnalysis)
                    store.registerReplacement(original: p.id, newBytes: out.newBytes)
                    ok += 1
                } catch {
                    failures.append(error.localizedDescription)
                }
                selected.remove(p.id)
                done += 1
            }
            running = false
            UIApplication.shared.isIdleTimerDisabled = false
            if ok > 0 {
                Haptics.success()
                store.lastDeleteMessage = String(localized: "已生成 \(ok) 张静态照片。原实况照片已放进「待删除」，到「清理」页确认删除后才会真正省出空间。")
            }
        }
    }
}
