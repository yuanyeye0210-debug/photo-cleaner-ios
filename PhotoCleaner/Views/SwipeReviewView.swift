import SwiftUI

/// 左滑删除、右滑保留（参考 immich-swipe / tidybyte 的交互）
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
                .padding(.horizontal, Theme.pagePadding)
                .padding(.top, 6)
            }
            controls
        }
        .padding(.bottom, 12)
        .onAppear {
            guard !loaded else { return }
            queue = store.undecided(ids).filter { store.item($0) != nil }
            loaded = true
        }
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
                Text("左滑删除 · 右滑保留")
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
        let deleteAmount = Double(max(0, -drag.width) / threshold)
        let keepAmount = Double(max(0, drag.width) / threshold)
        let d = CGFloat(depth) - (depth > 0 ? lift : 0)

        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                AssetImageView(asset: item.asset, targetSize: geo.size, contentMode: .fill)
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
                hint(icon: "trash", text: "删除", color: Theme.danger)
                    .opacity(deleteAmount)
                    .scaleEffect(CGFloat(0.85 + min(1, deleteAmount) * 0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(16)
                hint(icon: "checkmark", text: "保留", color: Theme.green)
                    .opacity(keepAmount)
                    .scaleEffect(CGFloat(0.85 + min(1, keepAmount) * 0.15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            DragGesture()
                .onChanged { v in
                    guard !flying else { return }
                    let wasPast = abs(offset.width) > threshold
                    offset = v.translation
                    if !wasPast && abs(offset.width) > threshold { Haptics.light() }
                }
                .onEnded { v in
                    guard !flying else { return }
                    if v.translation.width < -threshold || v.predictedEndTranslation.width < -threshold * 2.2 {
                        swipe(.delete)
                    } else if v.translation.width > threshold || v.predictedEndTranslation.width > threshold * 2.2 {
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
            CircleButton(icon: "xmark", color: Theme.danger, size: 60) { swipe(.delete) }
                .disabled(pos >= queue.count)
            CircleButton(icon: "arrow.uturn.backward", color: Theme.text2, size: 46) { undo() }
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.4 : 1)
            CircleButton(icon: "checkmark", color: Theme.green, size: 60) { swipe(.keep) }
                .disabled(pos >= queue.count)
        }
        .padding(.top, 4)
    }

    private var markedInQueue: [String] {
        queue.filter { store.toDelete.contains($0) }
    }

    private var finishedView: some View {
        VStack(spacing: 10) {
            Spacer()
            IconBadge(icon: "checkmark", tint: Theme.green, size: 56)
            Text("这一类看完了").font(Theme.title).foregroundStyle(Theme.text)
                .padding(.top, 4)
            Text("本轮选了 \(markedInQueue.count) 项删除，可释放 \(Fmt.bytes(store.bytes(of: markedInQueue)))")
                .font(Theme.callout)
                .foregroundStyle(Theme.text2)
            Text("回到首页，点底部「待删除」统一确认")
                .font(Theme.caption)
                .foregroundStyle(Theme.text3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func swipe(_ decision: Decision) {
        guard pos < queue.count, !flying else { return }
        flying = true
        let id = queue[pos]
        if decision == .delete { Haptics.medium() } else { Haptics.light() }
        withAnimation(.easeIn(duration: 0.22)) {
            offset = CGSize(width: decision == .delete ? -700 : 700, height: offset.height + 30)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            store.set(id, decision)
            history.append(id)
            offset = .zero
            pos += 1
            flying = false
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
