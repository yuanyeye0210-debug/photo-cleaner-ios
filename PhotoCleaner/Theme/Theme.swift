import SwiftUI

/// 唯一的设计变量来源：深色「健康卡片」主题
/// 近黑底 + 深灰圆角卡片 + 白色粗标题 + 灰色次要文字；每类一个克制的点缀色，不用渐变
enum Theme {
    // MARK: 颜色
    static let bg = Color(hex: 0x000000)                // 页面底色（近黑）
    static let bgElevated = Color(hex: 0x0B0B0C)        // 圆环轨道 / 凹陷区域
    static let card = Color(hex: 0x1C1C1E)              // 卡片
    static let fill = Color(hex: 0x2C2C2E)              // 次级填充（进度轨道、次按钮）
    static let fillHigh = Color(hex: 0x3A3A3C)          // 选中滑块
    static let hairline = Color.white.opacity(0.07)     // 卡片细边

    static let text = Color.white                       // 主文字
    static let text2 = Color(hex: 0x8E8E93)             // 次文字
    static let text3 = Color(hex: 0x5E5E63)             // 弱文字

    // 点缀色（每类一个，克制使用）
    static let purple = Color(hex: 0x8E7CF6)
    static let orange = Color(hex: 0xF2A23C)
    static let pink = Color(hex: 0xF0567A)
    static let blue = Color(hex: 0x4C8DF6)
    static let green = Color(hex: 0x3CC47C)

    static let accent = orange                          // 主操作、关键数字
    static let accentSoft = orange.opacity(0.14)
    static let danger = Color(hex: 0xFF5A4F)            // 只用于删除
    static let dangerSoft = Color(hex: 0xFF5A4F, alpha: 0.14)

    // MARK: 尺寸
    static let rCard: CGFloat = 24
    static let rTile: CGFloat = 12
    static let rButton: CGFloat = 18
    static let pagePadding: CGFloat = 16
    static let gap: CGFloat = 12

    // MARK: 字体（系统 SF）
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 20, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15)
    static let callout = Font.system(size: 14)
    static let caption = Font.system(size: 12)
    static func number(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight).monospacedDigit()
    }

    // MARK: 动画
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let springSoft = Animation.spring(response: 0.5, dampingFraction: 0.88)

    /// 按时间问候：夜深了 / 早上好 / 中午好 / 下午好 / 晚上好
    static func greeting(_ date: Date = Date()) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: return String(localized: "早上好")
        case 11..<14: return String(localized: "中午好")
        case 14..<18: return String(localized: "下午好")
        case 18..<23: return String(localized: "晚上好")
        default: return String(localized: "夜深了")
        }
    }
}

extension CleanCategory {
    /// 分类点缀色
    var tint: Color {
        switch self {
        case .similar: return Theme.purple
        case .exactDuplicates: return Theme.blue
        case .bursts: return Theme.purple
        case .livePhotos: return Theme.orange
        case .screenshots: return Theme.blue
        case .blurry: return Theme.green
        case .large: return Theme.orange
        case .videos: return Theme.pink
        case .poorLight: return Theme.orange
        case .textImages: return Theme.blue
        case .documents: return Theme.green
        case .qrCodes: return Theme.purple
        case .lowQuality: return Theme.pink
        case .food: return Theme.orange
        case .pets: return Theme.pink
        case .scenery: return Theme.green
        }
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

// MARK: - 卡片

struct CardModifier: ViewModifier {
    var radius: CGFloat = Theme.rCard
    var padding: CGFloat? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
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

/// 主按钮：实心橙色（destructive 时为红色）
struct PrimaryButtonStyle: ButtonStyle {
    var destructive = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(destructive ? Color.white : Color.black)
            .padding(.vertical, 15)
            .padding(.horizontal, 20)
            .background(destructive ? Theme.danger : Theme.accent,
                        in: RoundedRectangle(cornerRadius: Theme.rButton, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

/// 次按钮：深灰底
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.text
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tint)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(Theme.fill, in: Capsule())
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

/// 圆形着色图标底（参考图卡片标题左侧的小圆徽章）
struct IconBadge: View {
    let icon: String
    var tint: Color = Theme.accent
    var size: CGFloat = 34
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: Circle())
            .overlay(Circle().stroke(tint.opacity(0.28), lineWidth: 1))
    }
}

/// 右侧胶囊徽章：outline = 橙色描边「参考分」，soft = 蓝色「趋势 >」
struct PillBadge: View {
    enum Style { case outline, soft }
    let text: String
    var icon: String? = nil
    var tint: Color = Theme.orange
    var style: Style = .outline
    var chevron = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
            Text.loc(text).font(.system(size: 13, weight: .semibold))
            if chevron { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(style == .outline ? 0.12 : 0.16), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(style == .outline ? 0.45 : 0), lineWidth: 1))
    }
}

/// 卡片标题行：小圆徽章 + 白色标题 + 右侧胶囊
struct CardHeader<Trailing: View>: View {
    var icon: String? = nil
    var tint: Color = Theme.accent
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon { IconBadge(icon: icon, tint: tint, size: 36) }
            Text.loc(title).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.text)
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(icon: String? = nil, tint: Color = Theme.accent, title: String) {
        self.init(icon: icon, tint: tint, title: title, trailing: { EmptyView() })
    }
}

/// 大号粗数字 + 小单位（「29 步」）
struct BigNumber: View {
    let value: String
    var unit: String? = nil
    var size: CGFloat = 46
    var tint: Color = Theme.text
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(Theme.number(size, .bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            if let unit {
                Text.loc(unit).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(Theme.text2)
            }
        }
        .animation(Theme.springSoft, value: value)
    }
}

/// 2×2 指标格中的一项：着色小图标 + 灰色标签 + 白色数值
struct Metric: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            IconBadge(icon: icon, tint: tint, size: 30)
            Text.loc(label).font(.system(size: 13)).foregroundStyle(Theme.text2)
            Text(value)
                .font(Theme.number(17, .semibold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
                .animation(Theme.spring, value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 分段圆环：黑色轨道分 4 段，紫色弧表示进度，中间大号橙色数字
struct SegmentedRingGauge: View {
    let value: Double
    let center: String
    var caption: String? = nil
    var segments = 4
    var tint: Color = Theme.purple
    var centerTint: Color = Theme.orange
    var lineWidth: CGFloat = 13

    var body: some View {
        let seg = 1.0 / Double(segments)
        let gap = 0.035
        let v = min(max(value, 0), 1)
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let a = Double(i) * seg + gap / 2
                let b = Double(i + 1) * seg - gap / 2
                Circle()
                    .trim(from: CGFloat(a), to: CGFloat(b))
                    .stroke(Theme.bgElevated, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: CGFloat(a), to: CGFloat(min(b, max(a, v))))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .opacity(v > a ? 1 : 0)
            }
            .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(center)
                    .font(Theme.number(40, .bold))
                    .foregroundStyle(centerTint)
                    .contentTransition(.numericText())
                if let caption {
                    Text(caption).font(Theme.caption).foregroundStyle(Theme.text2)
                }
            }
        }
        .padding(lineWidth / 2)
        .animation(Theme.springSoft, value: value)
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
                                Capsule()
                                    .fill(Theme.fillHigh)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
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
                    .frame(width: max(value > 0 ? 4 : 0, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: 5)
        .animation(Theme.springSoft, value: value)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text.loc(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
            Spacer()
            if let trailing {
                Text.loc(trailing).font(Theme.caption).foregroundStyle(Theme.text2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}

extension Text {
    /// 组件收到的 String 当作本地化 key 去查翻译；查不到就原样显示。含 % 的（数字、百分比）不查。
    static func loc(_ s: String) -> Text {
        s.contains("%") ? Text(verbatim: s) : Text(LocalizedStringKey(s))
    }
}
