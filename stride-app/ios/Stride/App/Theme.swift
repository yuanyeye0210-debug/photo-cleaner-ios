import SwiftUI

// MARK: - Palette

enum Palette {
    static let bg        = Color(hex: 0x0A0A0B)
    static let surface   = Color(hex: 0x131315)
    static let card      = Color(hex: 0x1A1A1D)
    static let cardHigh  = Color(hex: 0x232327)
    static let cardSoft  = Color(hex: 0x141417)
    static let stroke    = Color(hex: 0x2C2C31)
    static let strokeHi  = Color(hex: 0x3C3C43)
    static let text      = Color.white
    static let textDim   = Color(hex: 0x9A9AA1)
    static let textFaint = Color(hex: 0x66666D)
    static let green     = Color(hex: 0x5CE08F)
    static let greenText = Color(hex: 0x7BEDA9)
    static let greenDeep = Color(hex: 0x16351F)
    static let amber     = Color(hex: 0xFFB86B)
    static let red       = Color(hex: 0xFF6B6B)
    static let blue      = Color(hex: 0x6BA8FF)
    static let purple    = Color(hex: 0xB48CFF)
    static let pink      = Color(hex: 0xFF87B7)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Metrics

enum Metrics {
    static let radius: CGFloat = 26
    static let radiusSmall: CGFloat = 16
    static let radiusTiny: CGFloat = 10
    static let page: CGFloat = 16
    static let gap: CGFloat = 12
}

// MARK: - Card

struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.radius
    var fill: Color = Palette.card
    var stroke: Color? = Palette.stroke
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke ?? .clear, lineWidth: lineWidth)
            )
    }
}

extension View {
    func card(
        radius: CGFloat = Metrics.radius,
        fill: Color = Palette.card,
        stroke: Color? = Palette.stroke,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(CardBackground(radius: radius, fill: fill, stroke: stroke, lineWidth: lineWidth))
    }

    func pagePadding() -> some View {
        padding(.horizontal, Metrics.page)
    }
}

// MARK: - Typography helpers

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Screen scaffold

struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            // 顶部一层很淡的绿色辉光，和截图里那种"黑底 + 一点点光"一致
            RadialGradient(
                colors: [Palette.green.opacity(0.10), .clear],
                center: .init(x: 0.5, y: -0.15),
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}
