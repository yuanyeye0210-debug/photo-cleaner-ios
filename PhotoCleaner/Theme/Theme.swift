import SwiftUI

/// 唯一的设计来源：简约清新主题（薄荷绿单一强调色 · 浅灰底 · 白卡片 · 系统字体）
/// 所有界面只从这里取颜色、字体、圆角、间距和动画。
enum Theme {
    // MARK: 颜色
    static let accent = Color(hex: 0x2AA876)            // 薄荷绿：唯一强调色
    static let accentSoft = Color(hex: 0x2AA876, alpha: 0.10)
    static let danger = Color(hex: 0xD9534F)            // 柔和红：只用于删除
    static let dangerSoft = Color(hex: 0xD9534F, alpha: 0.09)

    static let bg = Color(hex: 0xF7F8FA)                // 页面底色
    static let card = Color.white                       // 卡片
    static let fill = Color(hex: 0xF1F3F5)              // 次级填充（分段控件、次按钮、占位）
    static let hairline = Color(hex: 0xE9ECEF)          // 1px 细线

    static let text = Color(hex: 0x1F2328)              // 主文字
    static let text2 = Color(hex: 0x5F6670)             // 次文字
    static let text3 = Color(hex: 0x9AA1AA)             // 弱文字

    // MARK: 圆角 / 间距
    static let rCard: CGFloat = 16
    static let rTile: CGFloat = 10
    static let rButton: CGFloat = 14
    static let pagePadding: CGFloat = 20
    static let gap: CGFloat = 12

    // MARK: 字体（全部系统字体）
    static let largeTitle = Font.system(size: 30, weight: .bold)
    static let title = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15)
    static let callout = Font.system(size: 14)
    static let caption = Font.system(size: 12)
    static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    // MARK: 动画
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let springSoft = Animation.spring(response: 0.5, dampingFraction: 0.88)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: - 卡片

struct CardModifier: ViewModifier {
    var radius: CGFloat = Theme.rCard
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.035), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func card(radius: CGFloat = Theme.rCard, padding: CGFloat? = nil) -> some View {
        modifier(CardModifier(radius: radius, padding: padding))
    }

    /// 轻微的依次出现（只做透明度 + 少量位移）
    func fadeIn(_ index: Int = 0) -> some View { modifier(FadeIn(index: index)) }
}

struct FadeIn: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear {
                guard !shown else { return }
                withAnimation(Theme.springSoft.delay(Double(min(index, 8)) * 0.04)) { shown = true }
            }
    }
}

// MARK: - 按钮

/// 主按钮：实心强调色（destructive 时为柔和红）
struct PrimaryButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(destructive ? Theme.danger : Theme.accent,
                        in: RoundedRectangle(cornerRadius: Theme.rButton, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

/// 次按钮：浅灰底，文字为强调色或灰色
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.text
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tint)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

// MARK: - 小组件

/// 圆形浅色图标底 + 细线 SF Symbol
struct IconBadge: View {
    let icon: String
    var tint: Color = Theme.accent
    var size: CGFloat = 34
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.44, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// 分段控件（滑块用 matchedGeometryEffect 平滑移动）
struct Segmented<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { opt in
                Button {
                    Haptics.light()
                    withAnimation(Theme.spring) { selection = opt }
                } label: {
                    Text(label(opt))
                        .font(.system(size: 14, weight: opt == selection ? .semibold : .regular))
                        .foregroundStyle(opt == selection ? Theme.text : Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if opt == selection {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// 细进度条
struct ThinProgress: View {
    let value: Double
    var tint: Color = Theme.accent
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.fill)
                Capsule().fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: 4)
        .animation(Theme.springSoft, value: value)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text3)
                .textCase(.uppercase)
            Spacer()
            if let trailing {
                Text(trailing).font(Theme.caption).foregroundStyle(Theme.text3)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}
