import Photos
import SwiftUI
import UIKit

/// 左滑标记删除、右滑保留、上滑稍后再看（只做标记，确认后才真正删除）
struct SwipeReviewView: View {
    @EnvironmentObject var store: CleanupStore
    let ids: [String]
    /// 「稍后再看」模式：队列就是稍后再看的照片
    var includeLater = false

    private enum Action { case delete, keep, later }

    @State private var queue: [String] = []
    @State private var pos = 0
    @State private var offset: CGSize = .zero
    @State private var history: [String] = []
    @State private var loaded = false
    @State private var preview: PhotoItem?
    @State private var flying = false
    @State private var phase: CompletionPhase = .idle
    @State private var deletedCount = 0
    /// 每张卡片的图片是否已显示（没显示出来不允许标记删除，防止误删）
    @State private var loadedIDs: Set<String> = []
    @State private var showNotLoaded = false
    /// 卡片尺寸（预取用同一尺寸，PhotoKit 缓存才命中）
    @State private var cardSize: CGSize = .zero
    /// 正在预取的照片
    @State private var caching: [PHAsset] = []
    /// 卡片标签（换卡时算一次，拖动时不重复算）
    @State private var tagCache: [String: [String]] = [:]

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 14) {
            if loaded && pos >= queue.count {
                finishedView
            } else {
                progressHeader.zIndex(2)
                ZStack {
                    ForEach(visibleIndices.reversed(), id: \.self) { i in
                        if let item = store.item(queue[i]) {
                            card(for: item, isTop: i == pos, depth: i - pos)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { cardSize = g.size; prefetch() }
                        .onChange(of: g.size) { cardSize = $0 }
                })
                .overlay(alignment: .top) {
                    if showNotLoaded {
                        Text("图片还没加载出来，先别删")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .glassSurface(Capsule())
                            .padding(.top, 14)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(Theme.spring, value: showNotLoaded)
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 6)
                .zIndex(1)
            }
            if !(loaded && pos >= queue.count) { controls.zIndex(2) }
        }
        .padding(.bottom, 12)
        // 滑卡片时关掉「从屏幕边缘/内容区右滑返回」，免得快滑时退回上一页；左上角返回按钮照常可用
        .background(PopGestureBlocker().frame(width: 0, height: 0))
        .onAppear {
            guard !loaded else { return }
            queue = store.undecided(ids, includeLater: includeLater).filter { store.item($0) != nil }
            loaded = true
            prefetch()
        }
        .onChange(of: pos) { _ in prefetch() }
        .onDisappear { stopPrefetch() }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }

    /// 拖动进度 0…1，后排卡片随之上移
    private var lift: CGFloat { min(1, max(abs(offset.width), max(0, -offset.height)) / threshold) }

    private var visibleIndices: [Int] {
        guard pos < queue.count else { return [] }
        return Array(pos..<min(pos + 3, queue.count))
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(min(pos + 1, queue.count)) / \(queue.count)")
                    .font(Theme.number(13, .medium))
                    .foregroundStyle(Theme.text2)
                    .contentTransition(.numericText())
                Spacer()
                Text("左滑删除 · 右滑保留 · 上滑稍后")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text3)
            }
            ThinProgress(value: Double(pos) / Double(max(1, queue.count)), tint: Theme.green)
        }
        .padding(.horizontal, Theme.pagePadding)
        .animation(Theme.spring, value: pos)
    }

    @ViewBuilder
    private func card(for item: PhotoItem, isTop: Bool, depth: Int) -> some View {
        let drag: CGSize = isTop ? offset : .zero
        let deleteAmount: Double = Double(max(0, -drag.width) / threshold)
        let keepAmount: Double = Double(max(0, drag.width) / threshold)
        let upward: Bool = abs(drag.height) > abs(drag.width)
        let laterAmount: Double = upward ? Double(max(0, -drag.height) / threshold) : 0
        let liftNow: CGFloat = depth > 0 ? lift : 0
        let d: CGFloat = CGFloat(depth) - liftNow
        let face = cardFace(item, deleteAmount: deleteAmount, keepAmount: keepAmount, laterAmount: laterAmount)
        let placed = positioned(face, isTop: isTop, d: d, drag: drag)
        interactive(placed, item: item, isTop: isTop)
    }

    private func cardFace(_ item: PhotoItem, deleteAmount: Double, keepAmount: Double, laterAmount: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                AssetImageView(asset: item.asset, targetSize: geo.size, contentMode: .fill,
                               showsLoading: true,
                               loaded: Binding(get: { loadedIDs.contains(item.id) },
                                               set: { if $0 { loadedIDs.insert(item.id) } }))
                    .frame(width: geo.size.width, height: geo.size.height)

                // 底部压暗，白色照片上也看得清标签和日期
                LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    let itemTags = tagCache[item.id] ?? tags(for: item)
                    if !itemTags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(itemTags, id: \.self) { Tag(text: $0) }
                        }
                        .padding(.bottom, 2)
                    }
                    Text(Fmt.date(item.creationDate))
                        .font(Theme.headline)
                    Text("\(Fmt.bytes(item.fileSize)) · \(item.pixelWidth)×\(item.pixelHeight)")
                        .font(Theme.number(12, .regular))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                .padding(16)
                .allowsHitTesting(false)

                // 拖动时的提示（只在拖向那个方向时才画）
                if deleteAmount > 0.01 {
                    hint(icon: "trash", text: String(localized: "标记删除"), color: Theme.danger)
                        .opacity(deleteAmount)
                        .scaleEffect(CGFloat(0.85 + min(1, deleteAmount) * 0.15))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(16)
                }
                if keepAmount > 0.01 {
                    hint(icon: "checkmark", text: String(localized: "保留"), color: Theme.green)
                        .opacity(keepAmount)
                        .scaleEffect(CGFloat(0.85 + min(1, keepAmount) * 0.15))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(16)
                }
                if laterAmount > 0.01 {
                    hint(icon: "clock.arrow.circlepath", text: String(localized: "稍后再看"), color: Theme.blue)
                        .opacity(laterAmount)
                        .scaleEffect(CGFloat(0.85 + min(1, laterAmount) * 0.15))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private func positioned<V: View>(_ v: V, isTop: Bool, d: CGFloat, drag: CGSize) -> some View {
        let lift: CGFloat = drag.height < 0 ? drag.height * 0.7 : drag.height * 0.25
        let angle = Double(drag.width) / 22
        return v
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // 点按/拖动只认看得见的圆角卡片，不会抢到上面的按钮
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
        // 阴影只画在背后的圆角矩形上（给整张照片加阴影，每帧都要离屏渲染，拖动会卡）
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.fill)
                .shadow(color: .black.opacity(isTop ? 0.10 : 0.04), radius: isTop ? 14 : 6, y: isTop ? 6 : 2)
        )
        .scaleEffect(1 - d * CGFloat(0.04))
        .offset(y: d * CGFloat(10))
        .offset(x: drag.width, y: lift)
        .rotationEffect(.degrees(angle))
    }

    private func interactive<V: View>(_ v: V, item: PhotoItem, isTop: Bool) -> some View {
        v
        .allowsHitTesting(isTop)
        .onTapGesture { preview = item }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(!isTop)
        .accessibilityLabel(accessibilityText(for: item))
        .accessibilityHint(Text("向左滑标记删除，向右滑保留，向上滑稍后再看。也可以用操作菜单。"))
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(named: Text("标记删除")) { swipe(.delete) }
        .accessibilityAction(named: Text("保留")) { swipe(.keep) }
        .accessibilityAction(named: Text("稍后再看")) { swipe(.later) }
        .accessibilityAction(named: Text("查看大图")) { preview = item }
        // 用 highPriorityGesture：卡片上的拖动优先于外层手势
        .highPriorityGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    guard !flying else { return }
                    let wasPast = abs(offset.width) > threshold || -offset.height > threshold
                    // 拖动时用 interactiveSpring：跟手又不生硬
                    var t = Transaction()
                    t.animation = .interactiveSpring(response: 0.18, dampingFraction: 0.86)
                    withTransaction(t) { offset = v.translation }
                    if !wasPast && (abs(offset.width) > threshold || -offset.height > threshold) { Haptics.light() }
                }
                .onEnded { v in
                    guard !flying else { return }
                    // 慢拖过 110pt，或快甩过 60pt 且按速度预测能过 110pt；方向必须明显（1.5 倍）
                    let outcome = SwipeLogic.decide(dx: Double(v.translation.width), dy: Double(v.translation.height),
                                                    predictedDX: Double(v.predictedEndTranslation.width),
                                                    predictedDY: Double(v.predictedEndTranslation.height))
                    switch outcome {
                    case .delete: swipe(.delete)
                    case .keep: swipe(.keep)
                    case .later: swipe(.later)
                    case .none:
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                    }
                }
        )
        .animation(Theme.spring, value: pos)
    }

    private func tags(for item: PhotoItem) -> [String] {
        var t: [String] = []
        if item.isScreenshot { t.append(String(localized: "截图")) }
        if item.isVideo { t.append(String(localized: "视频")) }
        if item.isLivePhoto { t.append(String(localized: "实况")) }
        if item.burstID != nil { t.append(String(localized: "连拍")) }
        if store.later.contains(item.id) { t.append(String(localized: "稍后再看")) }
        if let a = item.analysis {
            if let code = a.verificationCode { t.append(String(localized: "验证码 \(code)")) }
            if a.tags.contains(.qrCode) { t.append(String(localized: "二维码")) }
            if a.tags.contains(.document) { t.append(String(localized: "文档")) }
            if a.textHeavy && !item.isScreenshot { t.append(String(localized: "文字多")) }
            if store.isBlurry(item) { t.append(String(localized: "模糊")) }
            if store.isPoorLight(item) { t.append(a.brightness < 35 ? String(localized: "过暗") : String(localized: "过曝")) }
            if store.isLowQuality(item) { t.append(String(localized: "低质量")) }
        }
        return Array(t.prefix(4))
    }

    private func accessibilityText(for item: PhotoItem) -> String {
        let kind = item.isVideo ? String(localized: "视频") : String(localized: "照片")
        var parts = [kind, Fmt.date(item.creationDate), Fmt.bytes(item.fileSize)]
        parts.append(contentsOf: tags(for: item))
        return parts.joined(separator: ", ")
    }

    private func hint(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 14).padding(.vertical, 8)
        // 跟着卡片移动的提示不用毛玻璃（每帧重新模糊很费），用半透明深色底
        .background(Capsule().fill(Color.black.opacity(0.6)))
        .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
    }

    private var controls: some View {
        GlassGroup(spacing: 24) { controlRow }
    }

    private var controlRow: some View {
        HStack(spacing: 24) {
            CircleButton(icon: "xmark", color: Theme.danger, size: 60) { swipe(.delete) }
                .disabled(pos >= queue.count)
                .accessibilityLabel(Text("标记删除"))
            CircleButton(icon: "arrow.uturn.backward", color: Theme.text2, size: 46) { undo() }
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.4 : 1)
                .accessibilityLabel(Text("撤销"))
            CircleButton(icon: "clock.arrow.circlepath", color: Theme.blue, size: 46) { swipe(.later) }
                .disabled(pos >= queue.count)
                .accessibilityLabel(Text("稍后再看"))
            CircleButton(icon: "checkmark", color: Theme.green, size: 60) { swipe(.keep) }
                .disabled(pos >= queue.count)
                .accessibilityLabel(Text("保留"))
        }
        .padding(.top, 4)
    }

    private var markedInQueue: [String] {
        queue.filter { store.toDelete.contains($0) }
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 84), spacing: 6)]

    /// 一类看完：列出本轮标记的照片，点缩略图可取消，确认后才真正删除
    private var finishedView: some View {
        let marked = markedInQueue
        return ScrollView {
            VStack(spacing: 12) {
                IconBadge(icon: "checkmark", tint: Theme.green, size: 56)
                    .padding(.top, 12)
                Text(phase == .done ? "已删除 \(deletedCount) 项" : "这一类看完了")
                    .font(Theme.title).foregroundStyle(Theme.text)
                if phase != .done {
                    if marked.isEmpty {
                        Text("没有标记要删除的照片").font(Theme.callout).foregroundStyle(Theme.text2)
                    } else {
                        Text("标记了 \(marked.count) 项，可释放 \(Fmt.bytes(store.bytes(of: marked)))")
                            .font(Theme.callout).foregroundStyle(Theme.text2)
                        Text("照片还没删除 · 点缩略图可取消标记")
                            .font(Theme.caption).foregroundStyle(Theme.text3)
                        Text("开了 iCloud 照片的话，删除会同步到你所有设备")
                            .font(Theme.caption).foregroundStyle(Theme.text3)
                        LazyVGrid(columns: gridColumns, spacing: 6) {
                            ForEach(marked, id: \.self) { id in
                                if let item = store.item(id) {
                                    ThumbnailCell(item: item)
                                        .accessibilityLabel(Text("已标记删除，点按取消"))
                                        .accessibilityAddTraits(.isButton)
                                        .onTapGesture {
                                            Haptics.light()
                                            withAnimation(Theme.spring) { store.set(id, .keep) }
                                        }
                                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                                }
                            }
                        }
                        .padding(.horizontal, Theme.pagePadding)
                    }
                } else {
                    Text("可在系统相册「最近删除」中恢复").font(Theme.caption).foregroundStyle(Theme.text3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) {
            if !marked.isEmpty || phase != .idle {
                CompletionButton(title: "确认删除 \(marked.count) 项", tint: Theme.danger, phase: phase) {
                    confirmDelete(marked)
                }
                .padding(.horizontal, Theme.pagePadding)
                .padding(.bottom, 6)
            }
        }
        .animation(Theme.spring, value: marked.count)
    }

    private func confirmDelete(_ ids: [String]) {
        guard !ids.isEmpty, phase == .idle else { return }
        Haptics.warning()
        phase = .working
        Task {
            // 系统会再弹一次确认框，用户点「删除」后才真正删除
            if await store.delete(ids) {
                deletedCount = ids.count
                phase = .done
            } else {
                phase = .idle
            }
        }
    }

    private func swipe(_ decision: Action) {
        guard pos < queue.count, !flying else { return }
        let id = queue[pos]
        // 图片还没显示出来时不允许标记删除，弹回并提示
        if decision == .delete && !loadedIDs.contains(id) {
            Haptics.warning()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
            showNotLoaded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { showNotLoaded = false }
            return
        }
        flying = true
        if decision == .delete { Haptics.medium() } else { Haptics.light() }
        // 飞出用弹簧，衔接手指松开时的速度
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            switch decision {
            case .delete: offset = CGSize(width: -700, height: offset.height + 30)
            case .keep: offset = CGSize(width: 700, height: offset.height + 30)
            case .later: offset = CGSize(width: offset.width, height: -1100)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switch decision {
            case .delete: store.set(id, .delete)
            case .keep: store.set(id, .keep)
            case .later: store.setLater(id)
            }
            history.append(id)
            offset = .zero
            pos += 1
            flying = false
        }
    }

    /// 卡片的像素尺寸（和 AssetImageView 请求的一样）
    private var cardPixelSize: CGSize {
        let s = UIScreen.main.scale
        return CGSize(width: (cardSize.width * s).rounded(), height: (cardSize.height * s).rounded())
    }

    /// 提前让 PhotoKit 准备后面 4 张（固定卡片尺寸，用 startCaching，不再一次开 8 个大图请求）；
    /// 划过去的停掉。标签也在这里算好，拖动时不重复算
    private func prefetch() {
        guard pos < queue.count else { stopPrefetch(); return }
        let window = queue.dropFirst(pos).prefix(5).compactMap { store.item($0) }
        var tc: [String: [String]] = [:]
        for item in window.prefix(3) { tc[item.id] = tagCache[item.id] ?? tags(for: item) }
        tagCache = tc
        guard cardSize.width > 0 else { return }
        let next = Array(window.dropFirst().map(\.asset))
        let nextIDs = Set(next.map(\.localIdentifier))
        let stop = caching.filter { !nextIDs.contains($0.localIdentifier) }
        let oldIDs = Set(caching.map(\.localIdentifier))
        let start = next.filter { !oldIDs.contains($0.localIdentifier) }
        PhotoLibraryService.shared.updateCaching(start: start, stop: stop, targetSize: cardPixelSize)
        caching = next
    }

    private func stopPrefetch() {
        PhotoLibraryService.shared.updateCaching(start: [], stop: caching, targetSize: cardPixelSize)
        caching = []
    }

    private func undo() {
        guard let last = history.popLast(), !flying else { return }
        Haptics.rigid()
        store.set(last, nil)
        withAnimation(Theme.spring) {
            pos = max(0, pos - 1)
            offset = .zero
        }
    }
}

/// 在当前页面显示期间禁用导航栏的滑动返回（iOS 26 还有一个整屏内容区右滑返回，也要一起关），离开时恢复
struct PopGestureBlocker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ vc: Controller, context: Context) { vc.apply() }
    static func dismantleUIViewController(_ vc: Controller, coordinator: ()) { vc.restore() }

    final class Controller: UIViewController {
        private weak var nav: UINavigationController?
        private var saved: (edge: Bool, content: Bool)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent == nil { restore() } else { apply() }
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            restore()
        }

        func apply() {
            guard let nav = navigationController ?? nav else { return }
            self.nav = nav
            if saved == nil {
                var content = true
                if #available(iOS 26.0, *) { content = nav.interactiveContentPopGestureRecognizer?.isEnabled ?? true }
                saved = (nav.interactivePopGestureRecognizer?.isEnabled ?? true, content)
            }
            nav.interactivePopGestureRecognizer?.isEnabled = false
            if #available(iOS 26.0, *) { nav.interactiveContentPopGestureRecognizer?.isEnabled = false }
        }

        func restore() {
            guard let nav, let saved else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = saved.edge
            if #available(iOS 26.0, *) { nav.interactiveContentPopGestureRecognizer?.isEnabled = saved.content }
            self.saved = nil
        }
    }
}

/// 照片上的小标签（半透明白）
struct Tag: View {
    let text: String
    var body: some View {
        Text.loc(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.black.opacity(0.5), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
            .foregroundStyle(.white)
    }
}

/// 玻璃圆形按钮（iOS 26 液态玻璃，可按压变形）
struct CircleButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        GlassCircleButton(icon: icon, tint: color, size: size, action: action)
    }
}
