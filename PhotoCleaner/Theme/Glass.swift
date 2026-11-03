import SwiftUI

// 液态玻璃（Liquid Glass）
// iOS 26+：使用系统 .glassEffect / GlassEffectContainer / glassEffectID / .glass 按钮样式
// iOS 16–25：退回 .ultraThinMaterial + 高光描边 + 柔和投影

extension View {
    /// 给任意视图加一层玻璃
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(Self.makeGlass(interactive: interactive, tint: tint), in: shape)
        } else {
            self
                .background(tint?.opacity(0.22) ?? Color.clear, in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(GlassHighlight.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        }
    }

    @available(iOS 26, *)
    fileprivate static func makeGlass(interactive: Bool, tint: Color?) -> Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint.opacity(0.35)) }
        if interactive { g = g.interactive() }
        return g
    }

    /// 玻璃形变用的 ID（iOS 26 才有效果）
    @ViewBuilder
    func glassID(_ id: String, in ns: Namespace.ID) -> some View {
        if #available(iOS 26, *) {
            self.glassEffectID(id, in: ns)
        } else {
            self
        }
    }

    /// 玻璃按钮：prominent = 实心主操作
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self.buttonStyle(FallbackGlassButtonStyle(prominent: prominent))
        }
    }

    /// 玻璃底的弹出层（iOS 26 系统默认就是玻璃）
    @ViewBuilder
    func glassSheetBackground() -> some View {
        if #available(iOS 26, *) {
            self
        } else if #available(iOS 16.4, *) {
            self.presentationBackground(.ultraThinMaterial)
        } else {
            self
        }
    }
}

/// 旧系统上的高光描边（模拟玻璃边缘的反光）
enum GlassHighlight {
    static let stroke = LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.06), Color.white.opacity(0.16)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct FallbackGlassButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassSurface(Capsule(), tint: prominent ? Theme.accent : nil)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

/// 玻璃容器：iOS 26 上让相邻玻璃共享采样、可以相互融合形变
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

/// 圆形玻璃图标按钮（顶部工具按钮、滑动操作按钮）
struct GlassCircleButton: View {
    let icon: String
    var tint: Color = Theme.text
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .glassSurface(Circle(), interactive: true)
        }
        .buttonStyle(PressableStyle())
    }
}
