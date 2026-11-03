import SwiftUI
import CoreText

/// 设计规范：参考 MiniMax 官网的设计语言（白底 + 彩色渐变产品卡、胶囊按钮、紫色调阴影、Outfit/DM Sans 字体）
/// 来源：https://www.minimax.io 、https://design.hagicode.com/designs/minimax/
enum MM {
    // MARK: 颜色
    static let canvas = Color.white
    static let surface = Color(hex: 0xF7F8FA)          // 次级底色（极浅灰）
    static let ink = Color(hex: 0x222222)               // 主文字
    static let inkDark = Color(hex: 0x181E25)           // 深色按钮 / 深色面
    static let ink2 = Color(hex: 0x45515E)              // 次文字
    static let muted = Color(hex: 0x8E8E93)             // 弱文字
    static let line = Color(hex: 0xE5E7EB)
    static let lineSoft = Color(hex: 0xF2F3F5)
    static let pill = Color.black.opacity(0.05)         // 胶囊导航底

    static let brand = Color(hex: 0x1456F0)
    static let blue500 = Color(hex: 0x3B82F6)
    static let blueLight = Color(hex: 0x60A5FA)
    static let sky = Color(hex: 0x3DAEFF)
    static let pink = Color(hex: 0xEA5EC1)
    static let danger = Color(hex: 0xF43F5E)
    static let success = Color(hex: 0x16A34A)
    static let successBg = Color(hex: 0xE8FFEA)

    /// 官网首屏那种粉-珊瑚-橙渐变
    static let heroGradient: [Color] = [Color(hex: 0xE24BB4), Color(hex: 0xF4607A), Color(hex: 0xFB9A5B)]
    /// 删除相关：珊瑚红渐变
    static let deleteGradient: [Color] = [Color(hex: 0xF43F5E), Color(hex: 0xFB7185), Color(hex: 0xFB923C)]

    // MARK: 阴影
    static let glow = Color(red: 44 / 255, green: 30 / 255, blue: 116 / 255)

    // MARK: 圆角
    static let rCard: CGFloat = 24
    static let rArt: CGFloat = 18
    static let rTile: CGFloat = 14

    // MARK: 字体（Outfit 负责标题与数字，DM Sans 负责界面文字；中文自动回落到苹方）
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "OutfitThin-Bold"
        case .medium, .regular, .light, .thin, .ultraLight: name = "OutfitThin-Medium"
        default: name = "OutfitThin-SemiBold"
        }
        return FontRegistry.available(name) ? .custom(name, size: size) : .system(size: size, weight: weight, design: .rounded)
    }

    static func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold: name = "DMSans9pt-Bold"
        case .medium: name = "DMSans9pt-Medium"
        default: name = "DMSans9pt-Regular"
        }
        return FontRegistry.available(name) ? .custom(name, size: size) : .system(size: size, weight: weight)
    }
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

/// 运行时注册包内字体（不依赖 Info.plist 路径）
enum FontRegistry {
    private static var registered = Set<String>()

    static func registerAll() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        for name in ["OutfitThin-Medium", "OutfitThin-SemiBold", "OutfitThin-Bold",
                     "DMSans9pt-Regular", "DMSans9pt-Medium", "DMSans9pt-Bold"]
        where UIFont(name: name, size: 12) != nil {
            registered.insert(name)
        }
    }

    static func available(_ name: String) -> Bool { registered.contains(name) }
}

// MARK: - 卡片

enum MMShadow { case glow, subtle, none }

struct MMCardModifier: ViewModifier {
    var radius: CGFloat = MM.rCard
    var shadow: MMShadow = .glow
    var fill: Color = MM.canvas

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(MM.lineSoft, lineWidth: 1))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    private var shadowColor: Color {
        switch shadow {
        case .glow: return MM.glow.opacity(0.13)
        case .subtle: return Color.black.opacity(0.06)
        case .none: return .clear
        }
    }
    private var shadowRadius: CGFloat { shadow == .glow ? 16 : 6 }
    private var shadowY: CGFloat { shadow == .glow ? 6 : 3 }
}

extension View {
    func mmCard(radius: CGFloat = MM.rCard, shadow: MMShadow = .glow, fill: Color = MM.canvas) -> some View {
        modifier(MMCardModifier(radius: radius, shadow: shadow, fill: fill))
    }
}

/// MiniMax 产品卡里的渐变「插画区」：渐变 + 两团柔光
struct GradientArt: View {
    let colors: [Color]
    var radius: CGFloat = MM.rArt

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 28)
                    .offset(x: geo.size.width * 0.45, y: -geo.size.height * 0.45)
                Circle()
                    .fill((colors.last ?? .purple).opacity(0.9))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 30)
                    .offset(x: -geo.size.width * 0.25, y: geo.size.height * 0.55)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - 按钮

/// 主按钮：深色胶囊（MiniMax 的 Primary Dark）；传 colors 则为渐变胶囊
struct PrimaryButtonStyle: ButtonStyle {
    var colors: [Color]? = nil
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MM.text(16, .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 22)
            .background(background)
            .clipShape(Capsule())
            .shadow(color: (colors?.first ?? MM.inkDark).opacity(0.22), radius: 14, y: 6)
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

    @ViewBuilder private var background: some View {
        if let colors {
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
        } else {
            MM.inkDark
        }
    }
}

/// 次按钮：浅灰胶囊
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = MM.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MM.text(14, .medium))
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(hex: 0xF0F0F0), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 顶部小圆按钮（胶囊导航风格）
struct IconPill: View {
    let icon: String
    var action: (() -> Void)? = nil
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(MM.ink)
            .frame(width: 40, height: 40)
            .background(MM.pill, in: Circle())
    }
}

/// 胶囊分段控件（替代系统 segmented）
struct PillSegment<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    var icon: ((T) -> String)? = nil
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { opt in
                let on = opt == selection
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = opt }
                } label: {
                    HStack(spacing: 6) {
                        if let icon { Image(systemName: icon(opt)).font(.system(size: 13, weight: .semibold)) }
                        Text(label(opt)).font(MM.text(14, .medium))
                    }
                    .foregroundStyle(on ? Color.white : MM.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if on {
                            Capsule().fill(MM.inkDark).matchedGeometryEffect(id: "seg", in: ns)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MM.pill, in: Capsule())
    }
}

/// 小标签胶囊
struct Chip: View {
    let text: String
    var fg: Color = MM.ink2
    var bg: Color = MM.pill
    var body: some View {
        Text(text)
            .font(MM.text(12, .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(bg, in: Capsule())
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(MM.display(22, .semibold)).foregroundStyle(MM.ink)
            Spacer()
            if let trailing {
                Text(trailing).font(MM.text(13, .medium)).foregroundStyle(MM.muted)
            }
        }
        .padding(.top, 6)
    }
}
