import SwiftUI

struct RingView: View {
    var progress: Double
    var lineWidth: CGFloat = 12
    var colors: [Color] = [Palette.green, Color(hex: 0x2AD4C8)]
    var track: Color = Palette.cardHigh

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    AngularGradient(colors: colors + [colors.first ?? Palette.green], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
    }
}

struct RingStat: View {
    let progress: Double
    let value: String
    let unit: String
    let caption: String
    var colors: [Color] = [Palette.green, Color(hex: 0x2AD4C8)]
    var size: CGFloat = 128

    var body: some View {
        ZStack {
            RingView(progress: progress, lineWidth: 13, colors: colors)
            VStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Text(caption)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.textFaint)
                    .padding(.top, 1)
            }
        }
        .frame(width: size, height: size)
    }
}

struct BarProgress: View {
    var progress: Double
    var color: Color = Palette.green
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.cardHigh)
                Capsule()
                    .fill(color)
                    .frame(width: max(3, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}

struct MacroBar: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textDim)
                Spacer()
                Text("\(Int(current))/\(Int(target))g")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            BarProgress(progress: target > 0 ? current / target : 0, color: color, height: 5)
        }
    }
}
