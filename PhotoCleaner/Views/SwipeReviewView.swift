import SwiftUI

/// 左滑保留、右滑标记删除（只做标记，确认后才真正删除）
struct SwipeReviewView: View {
    @EnvironmentObject var store: CleanupStore
    let ids: [String]

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

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 14) {
            if loaded && pos >= queue.count {
                finishedView
            } else {
                progressHeader
                ZStack {
                    ForEach(visibleIndices.reversed(), id: \.self) { i in
                        if let item = store.item(queue[i]) {
                            card(for: item, isTop: i == pos, depth: i - pos)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
            if !(loaded && pos >= queue.count) { controls }
        }
        .padding(.bottom, 12)
        .onAppear {
            guard !loaded else { return }
            queue = store.undecided(ids).filter { store.item($0) != nil }
            loaded = true
            prefetch()
        }
        .onChange(of: pos) { _ in prefetch() }
        .fullScreenCover(item: $preview) { PhotoDetailView(item: $0) }
    }

    /// 拖动进度 0…1，后排卡片随之上移
    private var lift: CGFloat { min(1, abs(offset.width) / threshold) }

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
                Text("左滑保留 · 右滑标记删除 · 不会立即删除")
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
        let drag = isTop ? offset : .zero
        let deleteAmount = Double(max(0, drag.width) / threshold)
        let keepAmount = Double(max(0, -drag.width) / threshold)
        let d = CGFloat(depth) - (depth > 0 ? lift : 0)

        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                AssetImageView(asset: item.asset, targetSize: geo.size, contentMode: .fill,
                               showsLoading: true,
                               loaded: Binding(get: { loadedIDs.contains(item.id) },
                                               set: { if $0 { loadedIDs.insert(item.id) } }))
                    .frame(width: geo.size.width, height: geo.size.height)

                LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 4) {
                    if !tags(for: item).isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tags(for: item), id: \.self) { Tag(text: $0) }
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
                .padding(16)

                // 拖动时的提示
                hint(icon: "trash", text: "标记删除", color: Theme.danger)
                    .opacity(deleteAmount)
                    .scaleEffect(CGFloat(0.85 + min(1, deleteAmount) * 0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                hint(icon: "checkmark", text: "保留", color: Theme.green)
                    .opacity(keepAmount)
                    .scaleEffect(CGFloat(0.85 + min(1, keepAmount) * 0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
        .shadow(color: .black.opacity(isTop ? 0.10 : 0.04), radius: isTop ? 14 : 6, y: isTop ? 6 : 2)
        .scaleEffect(1 - d * 0.04)
        .offset(y: d * 10)
        .offset(x: drag.width, y: drag.height * 0.25)
        .rotationEffect(.degrees(Double(drag.width) / 22))
        .allowsHitTesting(isTop)
        .onTapGesture { preview = item }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { v in
                    guard !flying else { return }
                    let wasPast = abs(offset.width) > threshold
                    offset = v.translation
                    if !wasPast && abs(offset.width) > threshold { Haptics.light() }
                }
                .onEnded { v in
                    guard !flying else { return }
                    let dx = v.translation.width
                    // 必须明显横向拖动（横向 > 纵向的 1.5 倍）且越过阈值才算数，防止误触
                    let horizontal = abs(dx) > abs(v.translation.height) * 1.5
                    if horizontal && dx > threshold {
                        swipe(.delete)
                    } else if horizontal && dx < -threshold {
                        swipe(.keep)
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                    }
                }
        )
        .animation(Theme.spring, value: pos)
    }

    private func tags(for item: PhotoItem) -> [String] {
        var t: [String] = []
        if item.isScreenshot { t.append("截图") }
        if item.isVideo { t.append("视频") }
        if let a = item.analysis {
            if a.sharpness < store.blurThreshold { t.append("模糊") }
            if a.brightness < 35 { t.append("过暗") }
            if a.brightness > 240 { t.append("过曝") }
        }
        return t
    }

    private func hint(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glassSurface(Capsule())
    }

    private var controls: some View {
        GlassGroup(spacing: 24) { controlRow }
    }

    private var controlRow: some View {
        HStack(spacing: 32) {
            CircleButton(icon: "checkmark", color: Theme.green, size: 60) { swipe(.keep) }
                .disabled(pos >= queue.count)
            CircleButton(icon: "arrow.uturn.backward", color: Theme.text2, size: 46) { undo() }
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.4 : 1)
            CircleButton(icon: "xmark", color: Theme.danger, size: 60) { swipe(.delete) }
                .disabled(pos >= queue.count)
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
                        LazyVGrid(columns: gridColumns, spacing: 6) {
                            ForEach(marked, id: \.self) { id in
                                if let item = store.item(id) {
                                    ThumbnailCell(item: item)
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

    private func swipe(_ decision: Decision) {
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
        withAnimation(.easeIn(duration: 0.22)) {
            offset = CGSize(width: decision == .delete ? 700 : -700, height: offset.height + 30)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            store.set(id, decision)
            history.append(id)
            offset = .zero
            pos += 1
            flying = false
        }
    }

    /// 提前加载后面几张，划到时图片已经准备好
    private func prefetch() {
        let next = queue.dropFirst(pos).prefix(8).compactMap { store.item($0) }
        for item in next {
            Task { _ = await PhotoLibraryService.shared.image(for: item.asset,
                                                               targetSize: CGSize(width: 900, height: 1400),
                                                               allowNetwork: true) }
        }
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

/// 照片上的小标签（半透明白）
struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.white.opacity(0.22), in: Capsule())
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
