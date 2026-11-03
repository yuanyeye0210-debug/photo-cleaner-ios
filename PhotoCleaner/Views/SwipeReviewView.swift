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

    private var visibleIndices: [Int] {
        guard pos < queue.count else { return [] }
        return Array(pos..<min(pos + 3, queue.count))
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(min(pos + 1, queue.count)) / \(queue.count)")
                    .font(.subheadline.bold().monospacedDigit())
                Spacer()
                Label("左滑删除", systemImage: "arrow.left").foregroundStyle(.red)
                Text("·").foregroundStyle(.secondary)
                Label("右滑保留", systemImage: "arrow.right").foregroundStyle(.green)
            }
            .font(.caption)
            ProgressView(value: Double(pos), total: Double(max(1, queue.count)))
                .tint(colors.first ?? .blue)
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
                AssetImageView(asset: item.asset, targetSize: geo.size, contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)

                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if item.isScreenshot { Tag(text: "截图", color: .blue) }
                        if item.isVideo { Tag(text: "视频", color: .green) }
                        if let a = item.analysis, a.sharpness < store.blurThreshold { Tag(text: "模糊", color: .orange) }
                        if let a = item.analysis, a.brightness < 35 { Tag(text: "过暗", color: .gray) }
                        if let a = item.analysis, a.brightness > 240 { Tag(text: "过曝", color: .yellow) }
                    }
                    Text(Fmt.date(item.creationDate))
                        .font(.headline)
                    Text("\(Fmt.bytes(item.fileSize)) · \(item.pixelWidth)×\(item.pixelHeight)")
                        .font(.caption)
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(18)

                // 滑动时的提示章
                stamp(text: "删除", color: .red, angle: 15)
                    .opacity(deleteOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(24)
                stamp(text: "保留", color: .green, angle: -15)
                    .opacity(keepOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(isTop ? 0.18 : 0.06), radius: 16, y: 8)
        .scaleEffect(1 - CGFloat(depth) * 0.05)
        .offset(y: CGFloat(depth) * 14)
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

    private func stamp(text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(angle))
    }

    private var controls: some View {
        HStack(spacing: 28) {
            CircleButton(icon: "xmark", color: .red, size: 66) { swipe(.delete) }
                .disabled(pos >= queue.count)
            CircleButton(icon: "arrow.uturn.backward", color: .orange, size: 50) { undo() }
                .disabled(history.isEmpty)
                .opacity(history.isEmpty ? 0.4 : 1)
            CircleButton(icon: "heart.fill", color: .green, size: 66) { swipe(.keep) }
                .disabled(pos >= queue.count)
        }
    }

    private var markedInQueue: [String] {
        queue.filter { store.toDelete.contains($0) }
    }

    private var finishedView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 60))
                .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            Text("这一类看完啦").font(.title2.bold())
            Text("本轮标记删除 \(markedInQueue.count) 项，可释放 \(Fmt.bytes(store.bytes(of: markedInQueue)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("回到首页点底部红色按钮即可统一删除")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
    }
}

struct CircleButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .shadow(color: color.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}
