import SwiftUI

/// 交互动效工具（参考 vibecoding 社区的画廊交互：弹簧物理、错峰入场、3D 封面流、棘轮式吸附滚动、
/// 共享元素过渡、数字滚动、视差）
enum Motion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
    static let smooth = Animation.spring(response: 0.55, dampingFraction: 0.85)
}

/// 错峰入场：卡片依次从下方弹入
struct StaggerIn: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 24)
            .scaleEffect(shown ? 1 : 0.94, anchor: .bottom)
            .onAppear {
                guard !shown else { return }
                withAnimation(Motion.bouncy.delay(Double(index) * 0.06)) { shown = true }
            }
    }
}

/// 横向滚动时的 3D 封面流 + 视差（越靠边越倾斜、越小）
struct CoverFlow: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            let screenMid = UIScreen.main.bounds.width / 2
            let delta = (frame.midX - screenMid) / UIScreen.main.bounds.width   // -1 … 1
            content
                .rotation3DEffect(.degrees(Double(-delta) * 18), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .scaleEffect(1 - min(abs(delta), 1) * 0.08)
        }
    }
}

/// 棘轮式吸附滚动：iOS 17 起逐项吸附；iOS 16 自然滚动
struct SnapScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollTargetBehavior(.viewAligned)
        } else {
            content
        }
    }
}

struct SnapTarget: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.scrollTargetLayout()
        } else {
            content
        }
    }
}

/// 数字变化时「跳一下」
struct PopOnChange<V: Equatable>: ViewModifier {
    let value: V
    @State private var pop = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pop ? 1.15 : 1)
            .onChange(of: value) { _ in
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pop = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(Motion.snappy) { pop = false }
                }
            }
    }
}

/// 缓慢漂移的光斑（用于渐变卡，营造「流动」质感）
struct DriftingBlobs: View {
    var colors: [Color]
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.30))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 34)
                    .offset(x: geo.size.width * (phase ? 0.42 : 0.18), y: -geo.size.height * (phase ? 0.35 : 0.15))
                Circle()
                    .fill((colors.first ?? .pink).opacity(0.85))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 36)
                    .offset(x: -geo.size.width * (phase ? 0.30 : 0.10), y: geo.size.height * (phase ? 0.45 : 0.6))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { phase = true }
        }
    }
}

extension View {
    func staggerIn(_ index: Int) -> some View { modifier(StaggerIn(index: index)) }
    func coverFlow() -> some View { modifier(CoverFlow()) }
    func snapScroll() -> some View { modifier(SnapScroll()) }
    func snapTarget() -> some View { modifier(SnapTarget()) }
    func popOnChange<V: Equatable>(_ value: V) -> some View { modifier(PopOnChange(value: value)) }
}
