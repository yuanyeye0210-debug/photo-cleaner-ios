import SwiftUI

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.text)
            Spacer()
            if let trailing {
                if let action {
                    Button(trailing, action: action)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                } else {
                    Text(trailing)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textFaint)
                }
            }
        }
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    var subtitle: String? = nil
    var enabled: Bool = true
    var tint: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.65)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 17 : 12)
            .foregroundStyle(enabled ? Color.black : Palette.textDim)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(enabled ? tint : Palette.cardHigh)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(Palette.text)
            .background(Capsule().fill(Palette.cardHigh))
            .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Check row (会员权益列表用)

struct CheckRow: View {
    let text: String
    var bold: Bool = false
    var size: CGFloat = 16

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.82, weight: .bold))
                .foregroundStyle(Palette.text)
                .frame(width: 16, alignment: .leading)
            Text(text)
                .font(.system(size: size, weight: bold ? .semibold : .regular))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Badge / pill

struct Pill: View {
    let text: String
    var fg: Color = Palette.greenText
    var bg: Color = Palette.greenDeep
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(bg))
    }
}

struct WhiteBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white))
    }
}

struct DarkBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Palette.cardHigh))
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = Palette.text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(radius: Metrics.radiusSmall, fill: Palette.cardSoft)
    }
}

// MARK: - Radio

struct RadioDot: View {
    var on: Bool

    var body: some View {
        ZStack {
            if on {
                Circle().fill(Color.white)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.black)
            } else {
                Circle().strokeBorder(Palette.strokeHi, lineWidth: 2)
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Empty state

struct EmptyHint: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.textFaint)
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.text)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

// MARK: - Toast

struct ToastView: View {
    let text: String
    var icon: String = "checkmark.circle.fill"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Palette.green)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Capsule().fill(Palette.cardHigh))
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
    }
}

extension View {
    func toast(_ text: Binding<String?>) -> some View {
        overlay(alignment: .top) {
            if let value = text.wrappedValue {
                ToastView(text: value)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: value) {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation(.easeOut(duration: 0.2)) { text.wrappedValue = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: text.wrappedValue)
    }
}
