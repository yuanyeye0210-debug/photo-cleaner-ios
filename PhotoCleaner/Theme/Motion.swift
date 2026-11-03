import SwiftUI

// 6 个精致交互（参考抖音「西瓜同学」：让 AI 做的 App 更精致的 6 个交互）
// 01 完成反馈按钮  02 勾选联动  03 叠卡展开  04 吸附卡加画线  05 惯性滚轮  06 圆形扩散转场

enum Motion {
    static let snap = Animation.interpolatingSpring(stiffness: 210, damping: 19)     // 吸附，带一点回弹
    static let fan = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let reveal = Animation.easeInOut(duration: 0.5)
    static let draw = Animation.easeOut(duration: 0.6)
    static let wheel = Animation.interpolatingSpring(mass: 1, stiffness: 80, damping: 13) // 惯性滚动后吸到刻度、轻微回弹
}

// MARK: - 01 完成反馈按钮：按钮 → 圆 → 勾 → 粒子迸开

enum CompletionPhase: Equatable { case idle, working, done }

struct CompletionButton: View {
    let title: String
    var tint: Color = Theme.danger
    let phase: CompletionPhase
    let action: () -> Void

    @State private var check: CGFloat = 0
    @State private var burst = false
    private let h: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let collapsed = phase != .idle
            ZStack {
                ParticleRing(active: burst, color: Theme.green)
                RoundedRectangle(cornerRadius: collapsed ? h / 2 : Theme.rButton, style: .continuous)
                    .fill(phase == .done ? Theme.green : tint)
                    .frame(width: collapsed ? h : geo.size.width, height: h)
                switch phase {
                case .idle:
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                case .working:
                    ProgressView().tint(.white)
                case .done:
                    CheckShape()
                        .trim(from: 0, to: check)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 20, height: 15)
                }
            }
            .frame(width: geo.size.width, height: h)
        }
        .frame(height: h)
        .contentShape(Rectangle())
        .onTapGesture { if phase == .idle { action() } }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: phase)
        .onChange(of: phase) { p in
            guard p == .done else { check = 0; burst = false; return }
            Haptics.success()
            withAnimation(.easeOut(duration: 0.28).delay(0.12)) { check = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { burst = true }
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// 一圈小粒子向外迸开、淡出
struct ParticleRing: View {
    let active: Bool
    var color: Color = Theme.green
    var count = 14
    var radius: CGFloat = 58

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) / Double(count) * 2 * Double.pi
                let r = i % 2 == 0 ? radius : radius * 0.78
                Circle()
                    .fill(i % 3 == 0 ? Color.white : color)
                    .frame(width: i % 2 == 0 ? 6 : 4, height: i % 2 == 0 ? 6 : 4)
                    .offset(x: active ? CGFloat(cos(angle)) * r : 0,
                            y: active ? CGFloat(sin(angle)) * r : 0)
                    .animation(.easeOut(duration: 0.5), value: active)
                    .opacity(active ? 0 : 1)
                    .scaleEffect(active ? 0.4 : 1)
                    .animation(.easeIn(duration: 0.65), value: active)
            }
        }
        .opacity(active ? 1 : 0)
    }
}

struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - 02 勾选联动：进度环 + 滚动数字 + 顶部底色，一个动作三处一起变

struct ProgressRing: View {
    let value: Double
    var tint: Color = Theme.green
    var lineWidth: CGFloat = 5
    var body: some View {
        ZStack {
            Circle().stroke(Theme.bgElevated, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(Theme.springSoft, value: value)
    }
}

/// 页面顶部的联动头：进度环、已处理数字滚动、背景随进度染色
struct LinkedProgressHeader: View {
    let done: Int
    let total: Int
    let marked: Int
    let markedBytes: Int64
    var tint: Color = Theme.green

    private var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                ProgressRing(value: progress, tint: tint)
                if done >= total && total > 0 {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(tint)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(Theme.number(11, .semibold))
                        .foregroundStyle(Theme.text2)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(done)")
                        .font(Theme.number(26, .bold))
                        .foregroundStyle(Theme.text)
                        .contentTransition(.numericText())
                    Text("/ \(total)")
                        .font(Theme.number(15, .semibold))
                        .foregroundStyle(Theme.text2)
                }
                Text(done >= total && total > 0 ? "全部看完" : "已处理")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("删除 \(marked)")
                    .font(Theme.number(15, .semibold))
                    .foregroundStyle(marked > 0 ? Theme.danger : Theme.text3)
                    .contentTransition(.numericText())
                Text(Fmt.bytes(markedBytes))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.text2)
            }
        }
        .padding(14)
        .background {
            ZStack {
                Theme.card
                tint.opacity(0.04 + 0.16 * progress)     // 底色随进度变化
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .animation(Theme.springSoft, value: done)
        .animation(Theme.spring, value: marked)
    }
}

// MARK: - 03 叠卡展开：点一下依次展开，收起时原路叠回去

enum FanAxis { case horizontal, vertical }

struct FanOut: ViewModifier {
    let index: Int
    let count: Int
    let expanded: Bool
    let step: CGFloat          // 展开后相邻两张的距离
    var axis: FanAxis = .vertical

    func body(content: Content) -> some View {
        let depth = CGFloat(min(index, 3))
        let collapsed = -CGFloat(index) * step + depth * 9
        content
            .scaleEffect(expanded ? 1 : 1 - depth * 0.05, anchor: axis == .vertical ? .bottom : .trailing)
            .offset(x: axis == .horizontal && !expanded ? collapsed : 0,
                    y: axis == .vertical && !expanded ? collapsed : 0)
            .rotationEffect(.degrees(axis == .horizontal && !expanded ? Double(depth) * 3 : 0))
            .opacity(expanded || index < 4 ? 1 : 0)
            .zIndex(Double(count - index))
            .animation(Motion.fan.delay(expanded ? Double(index) * 0.06 : Double(max(0, count - 1 - index)) * 0.045),
                       value: expanded)
    }
}

extension View {
    func fanOut(index: Int, count: Int, expanded: Bool, step: CGFloat, axis: FanAxis = .vertical) -> some View {
        modifier(FanOut(index: index, count: count, expanded: expanded, step: step, axis: axis))
    }
}

// MARK: - 04 吸附卡 + 画线：竖向滑动，松手吸到最近一张，停稳后时间线再画出来

struct SnapTimeline<Item: Identifiable, Card: View>: View {
    let items: [Item]
    var cardHeight: CGFloat = 210
    var spacing: CGFloat = 18
    @Binding var index: Int
    let card: (Item, Bool) -> Card

    @State private var dragY: CGFloat = 0
    @State private var draw: CGFloat = 0
    @State private var token = 0

    init(items: [Item], cardHeight: CGFloat = 210, spacing: CGFloat = 18, index: Binding<Int>,
         @ViewBuilder card: @escaping (Item, Bool) -> Card) {
        self.items = items
        self.cardHeight = cardHeight
        self.spacing = spacing
        self._index = index
        self.card = card
    }

    var body: some View {
        GeometryReader { geo in
            let step = cardHeight + spacing
            let top = (geo.size.height - cardHeight) / 2
            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    let y = top + CGFloat(i - index) * step + dragY
                    let dist = abs(y - top) / step
                    if dist < 2.6 {
                        HStack(alignment: .top, spacing: 12) {
                            TimelineMarker(active: i == index, draw: i == index ? draw : 0)
                                .frame(width: 18)
                            card(item, i == index)
                        }
                        .frame(height: cardHeight)
                        .scaleEffect(1 - min(dist, 1.5) * 0.05)
                        .opacity(1 - min(dist, 2) * 0.35)
                        .offset(y: y)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { v in
                        token += 1
                        if draw > 0 { withAnimation(.easeOut(duration: 0.12)) { draw = 0 } }
                        var t = v.translation.height
                        if (index == 0 && t > 0) || (index == items.count - 1 && t < 0) { t *= 0.35 }
                        dragY = t
                    }
                    .onEnded { v in
                        let delta = Int((-v.predictedEndTranslation.height / step).rounded())
                        let target = min(max(index + max(-3, min(3, delta)), 0), max(0, items.count - 1))
                        if target != index { Haptics.light() }
                        withAnimation(Motion.snap) {
                            index = target
                            dragY = 0
                        }
                        settle()
                    }
            )
        }
        .clipped()
        .onAppear { settle() }
        .onChange(of: index) { _ in settle() }
    }

    /// 等卡片停稳再画线
    private func settle() {
        token += 1
        let mine = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            guard mine == token else { return }
            draw = 0
            withAnimation(Motion.draw) { draw = 1 }
        }
    }
}

struct TimelineMarker: View {
    let active: Bool
    let draw: CGFloat
    var tint: Color = Theme.orange

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(active ? tint : Theme.card)
                .overlay(Circle().stroke(active ? tint : Theme.text3, lineWidth: 1.5))
                .frame(width: 11, height: 11)
                .padding(.top, 22)
                .scaleEffect(active ? 1 : 0.85)
            ZStack(alignment: .top) {
                VerticalLine().stroke(Theme.fill, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                VerticalLine().trim(from: 0, to: draw)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .frame(width: 2)
        }
        .animation(Theme.spring, value: active)
    }
}

struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}

// MARK: - 05 惯性滚轮：甩动后逐渐减速，吸到刻度并轻微回弹

struct InertiaWheel: View {
    let values: [Int]
    @Binding var selection: Int
    var rowHeight: CGFloat = 38
    var visibleRows = 5
    var tint: Color = Theme.orange
    var label: (Int) -> String = { "\($0)" }

    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var lastTick = -1

    private var selectedIndex: Int {
        values.indices.min(by: { abs(values[$0] - selection) < abs(values[$1] - selection) }) ?? 0
    }

    private func clamp(_ i: Int) -> Int { min(max(i, 0), max(0, values.count - 1)) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(height: rowHeight)
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                let y = CGFloat(i) * rowHeight + offset
                let d = abs(y) / rowHeight
                if d < CGFloat(visibleRows) / 2 + 0.8 {
                    Text(label(v))
                        .font(Theme.number(d < 0.5 ? 21 : 17, d < 0.5 ? .bold : .regular))
                        .foregroundStyle(d < 0.5 ? tint : Theme.text2)
                        .scaleEffect(1 - min(d, 3) * 0.07)
                        .opacity(1 - min(d, 3) * 0.28)
                        .rotation3DEffect(.degrees(Double(-y / rowHeight) * 16), axis: (x: 1, y: 0, z: 0))
                        .offset(y: y)
                }
            }
        }
        .frame(height: rowHeight * CGFloat(visibleRows))
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { v in
                    if dragStart == nil { dragStart = offset }
                    var o = (dragStart ?? 0) + v.translation.height
                    let minO = -CGFloat(values.count - 1) * rowHeight
                    if o > 0 { o *= 0.35 } else if o < minO { o = minO + (o - minO) * 0.35 }
                    offset = o
                    let i = clamp(Int((-o / rowHeight).rounded()))
                    if i != lastTick { lastTick = i; Haptics.selection() }
                }
                .onEnded { v in
                    let base = dragStart ?? offset
                    dragStart = nil
                    // 用预测的落点模拟惯性：甩得越快走得越远，然后吸到最近刻度
                    let projected = base + v.predictedEndTranslation.height * 1.15
                    let i = clamp(Int((-projected / rowHeight).rounded()))
                    withAnimation(Motion.wheel) { offset = -CGFloat(i) * rowHeight }
                    if values.indices.contains(i) { selection = values[i] }
                }
        )
        .onAppear { offset = -CGFloat(selectedIndex) * rowHeight; lastTick = selectedIndex }
        .accessibilityElement()
        .accessibilityValue(label(selection))
        .accessibilityAdjustableAction { dir in
            let i = selectedIndex + (dir == .increment ? 1 : -1)
            let c = clamp(i)
            selection = values[c]
            withAnimation(Motion.wheel) { offset = -CGFloat(c) * rowHeight }
        }
    }
}

// MARK: - 06 圆形扩散转场：从指尖处扩散铺满，返回时原路缩回

struct CircleRevealShape: Shape {
    var center: CGPoint
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        let maxR = corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
        let r = maxR * progress
        return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }
}

extension View {
    /// 带点击位置（全局坐标）的点按
    func onTapPoint(_ action: @escaping (CGPoint) -> Void) -> some View {
        gesture(SpatialTapGesture(coordinateSpace: .global).onEnded { action($0.location) })
    }
}
