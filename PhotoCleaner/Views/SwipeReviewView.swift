import SwiftUI

/// 左滑删除、右滑保留（参考 immich-swipe / tidybyte 的交互）
struct SwipeReviewView: View {
    @EnvironmentObject var store: CleanupStore
    let ids: [String]
    let colors: [Color]

    @State private var queue: [String] = []
    @State private var pos = 0
    @State private var offset: CGSize = .zero
    @State private var history: [String] = []
    @State private var loaded = false
    @State private var preview: PhotoItem?
    @State private var flying = false

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 16) {
            if loaded && pos >= queue.count {
                finishedView
            } else {
                progressBar
                ZStack {
                    ForEach(visibleIndices.reversed(), id: \.self) { i in
                        if let item = store.item(queue[i]) {
                            card(for: item, isTop: i == pos, depth: i - pos)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
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

    /// 拖动进度 0…1，用于后排卡片联动
    private var liftProgress: CGFloat { min(1, abs(offset.width) / threshold) }

    private var visibleIndices: [Int] {
        guard pos < queue.count else { return [] }
        return Array(pos..<min(pos + 3, queue.count))
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(min(pos + 1, queue.count))")
                    .font(MM.display(22, .semibold))
                    .foregroundColor(MM.ink)
                    + Text(" / \(queue.count)")
                    .font(MM.display(14, .medium))
                    .foregroundColor(MM.muted)
                Spacer()
                Chip(text: "← 左滑删除", fg: MM.danger, bg: MM.danger.opacity(0.1))
                Chip(text: "右滑保留 →", fg: MM.success, bg: MM.successBg)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MM.lineSoft)
                    Capsule()
                        .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(pos) / CGFloat(max(1, queue.count)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pos)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func card(for item: PhotoItem, isTop: Bool, depth: Int) -> some View {
        let drag = isTop ? offset : .zero
        let deleteOpacity = Double(max(0, -drag.width) / threshold)
        let keepOpacity = Double(max(0, drag.width) / threshold)

        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // 视差：图片比卡片略大，拖动时反向位移
                AssetImageView(asset: item.asset, targetSize: geo.size, contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(1.08)
                    .offset(x: -drag.width * 0.06, y: -drag.height * 0.04)

                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if item.isScreenshot { Tag(text: "截图", color: Color(hex: 0x6D4AFF)) }
                        if item.isVideo { Tag(text: "视频", color: MM.sky) }
                        if let a = item.analysis, a.sharpness < store.blurThreshold { Tag(text: "模糊", color: Color(hex: 0xF0498F)) }
                        if let a = item.analysis, a.brightness < 35 { Tag(text: "过暗", color: MM.inkDark) }
                        if let a = item.analysis, a.brightness > 240 { Tag(text: "过曝", color: Color(hex: 0xFF9F45)) }
                    }
                    Text(Fmt.date(item.creationDate))
                        .font(MM.text(17, .bold))
                    Text("\(Fmt.bytes(item.fileSize)) · \(item.pixelWidth)×\(item.pixelHeight)")
                        .font(MM.display(13, .medium))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(18)

                // 滑动时的提示章
                stamp(text: "删除", icon: "trash.fill", colors: MM.deleteGradient)
                    .opacity(deleteOpacity)
                    .scaleEffect(CGFloat(0.7 + min(1, deleteOpacity) * 0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(24)
                stamp(text: "保留", icon: "heart.fill", colors: [MM.success, Color(hex: 0x34D399)])
                    .opacity(keepOpacity)
                    .scaleEffect(CGFloat(0.7 + min(1, keepOpacity) * 0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(6)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: MM.glow.opacity(isTop ? 0.2 : 0.08), radius: 20, y: 10)
        // 顶卡被拖动时，后面的卡片逐渐「升上来」
        .scaleEffect(1 - (CGFloat(depth) - liftProgress * (depth > 0 ? 1 : 0)) * 0.05)
        .offset(y: (CGFloat(depth) - liftProgress * (depth > 0 ? 1 : 0)) * 14)
        .rotation3DEffect(.degrees(Double(drag.height) / -40), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
        .offset(x: drag.width, y: drag.height * 0.3)
        .rotationEffect(.degrees(Double(drag.width) / 18))
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { offset = .zero }
                    }
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pos)
    }

    /// 滑动时出现的渐变胶囊标签
    private func stamp(text: String, icon: String, colors: [Color]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(MM.text(18, .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: Capsule())
        .shadow(color: colors[0].opacity(0.4), radius: 10, y: 4)
    }

    private var controls: some View {
        HStack(spacing: 28) {
            CircleButton(icon: "xmark", color: MM.danger, size: 66, filled: true, colors: MM.deleteGradient) { swipe(.delete) }
                .disabled(pos >= queue.count)
            CircleButton(icon: "arrow.uturn.backward", color: MM.ink, size: 50) { undo() }
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.4 : 1)
            CircleButton(icon: "heart.fill", color: MM.success, size: 66, filled: true, colors: [MM.success, Color(hex: 0x34D399)]) { swipe(.keep) }
                .disabled(pos >= queue.count)
        }
    }

    private var markedInQueue: [String] {
        queue.filter { store.toDelete.contains($0) }
    }

    private var finishedView: some View {
        VStack(spacing: 14) {
            Spacer()
            GradientArt(colors: colors, radius: 32)
                .frame(width: 112, height: 112)
                .overlay(Image(systemName: "party.popper.fill").font(.system(size: 46)).foregroundStyle(.white))
                .shadow(color: (colors.first ?? MM.brand).opacity(0.3), radius: 18, y: 8)
            Text("这一类看完啦").font(MM.display(24, .semibold)).foregroundStyle(MM.ink)
            Text("本轮标记删除 \(markedInQueue.count) 项，可释放 \(Fmt.bytes(store.bytes(of: markedInQueue)))")
                .font(MM.text(14))
                .foregroundStyle(MM.ink2)
            Text("回到首页点底部「去确认」即可统一删除")
                .font(MM.text(12))
                .foregroundStyle(MM.muted)
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
            offset = CGSize(width: decision == .delete ? -700 : 700, height: offset.height + 40)
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            pos = max(0, pos - 1)
            offset = .zero
        }
    }
}

struct Tag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(MM.text(11, .bold))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().fill(color.opacity(0.35)))
            .foregroundStyle(.white)
    }
}

struct CircleButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    var filled: Bool = false
    var colors: [Color] = []
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(filled ? Color.white : color)
                .frame(width: size, height: size)
                .background {
                    if filled {
                        Circle().fill(LinearGradient(colors: colors.isEmpty ? [color] : colors,
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                    } else {
                        Circle().fill(Color.white).overlay(Circle().stroke(MM.line, lineWidth: 1))
                    }
                }
                .shadow(color: (filled ? color : MM.glow).opacity(0.25), radius: 12, y: 5)
        }
        .buttonStyle(PressableStyle())
    }
}
