import SwiftUI
import UIKit

// MARK: - 轨迹画

struct RouteArtView: View {
    let points: [GeoPoint]
    var style: RouteArtStyle = .neon
    var lineWidth: CGFloat = 3.2
    var showsBaseline: Bool = true

    var body: some View {
        Canvas { ctx, size in
            guard points.count > 1 else { return }
            let path = RouteGeometry.path(points: points, in: size, padding: 18)
            let colors = style.colors

            if showsBaseline {
                var grid = Path()
                let step: CGFloat = 22
                var y: CGFloat = step
                while y < size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                ctx.stroke(grid, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
            }

            switch style {
            case .neon:
                ctx.addFilter(.blur(radius: 10))
                ctx.stroke(path, with: .color(colors[0].opacity(0.8)), style: .init(lineWidth: lineWidth * 3.4, lineCap: .round, lineJoin: .round))
                ctx.drawLayer { layer in
                    layer.addFilter(.shadow(color: colors[0].opacity(0.9), radius: 12))
                    layer.stroke(path, with: .color(.white), style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }

            case .ink:
                ctx.stroke(path, with: .color(.white.opacity(0.92)), style: .init(lineWidth: lineWidth * 0.8, lineCap: .round, lineJoin: .round))
                ctx.stroke(path, with: .color(.white.opacity(0.12)), style: .init(lineWidth: lineWidth * 5, lineCap: .round, lineJoin: .round))

            case .gradient:
                ctx.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: colors),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: .init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

            case .dots:
                let sampled = RouteGeometry.sample(points: points, in: size, padding: 18, every: 3)
                for (i, p) in sampled.enumerated() {
                    let r = 1.4 + 1.6 * Double(i % 3) / 2
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(colors[i % colors.count].opacity(0.85)))
                }

            case .contour:
                for i in 0..<4 {
                    let inset = CGFloat(i) * 5
                    var copy = path
                    copy = copy.applying(CGAffineTransform(translationX: 0, y: inset))
                    ctx.stroke(
                        copy,
                        with: .color(colors[i % colors.count].opacity(0.55 - Double(i) * 0.1)),
                        style: .init(lineWidth: lineWidth * 0.6, lineCap: .round, lineJoin: .round)
                    )
                }

            case .aurora:
                ctx.addFilter(.blur(radius: 16))
                for (i, c) in colors.enumerated() {
                    var copy = path
                    copy = copy.applying(CGAffineTransform(translationX: CGFloat(i - 1) * 7, y: CGFloat(i - 1) * -4))
                    ctx.stroke(copy, with: .color(c.opacity(0.55)), style: .init(lineWidth: lineWidth * 4.5, lineCap: .round, lineJoin: .round))
                }
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 0.4))
                    layer.stroke(path, with: .color(.white.opacity(0.95)), style: .init(lineWidth: lineWidth * 0.9, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: - 几何

enum RouteGeometry {

    static func normalized(_ points: [GeoPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        var minLat = points[0].lat, maxLat = points[0].lat
        var minLon = points[0].lon, maxLon = points[0].lon
        for p in points {
            minLat = min(minLat, p.lat); maxLat = max(maxLat, p.lat)
            minLon = min(minLon, p.lon); maxLon = max(maxLon, p.lon)
        }
        let spanLat = max(maxLat - minLat, 1e-9)
        let spanLon = max(maxLon - minLon, 1e-9)

        return points.map { p in
            CGPoint(
                x: (p.lon - minLon) / spanLon,
                y: 1 - (p.lat - minLat) / spanLat
            )
        }
    }

    static func path(points: [GeoPoint], in size: CGSize, padding: CGFloat) -> Path {
        let unit = normalized(points)
        let avail = CGSize(width: max(1, size.width - padding * 2), height: max(1, size.height - padding * 2))
        let scale = min(avail.width, avail.height)
        let offsetX = (size.width - scale) / 2
        let offsetY = (size.height - scale) / 2

        var path = Path()
        for (i, p) in unit.enumerated() {
            let cg = CGPoint(x: offsetX + p.x * scale, y: offsetY + p.y * scale)
            if i == 0 { path.move(to: cg) } else { path.addLine(to: cg) }
        }
        return path
    }

    static func sample(points: [GeoPoint], in size: CGSize, padding: CGFloat, every: Int) -> [CGPoint] {
        let unit = normalized(points)
        let avail = min(size.width - padding * 2, size.height - padding * 2)
        let offsetX = (size.width - avail) / 2
        let offsetY = (size.height - avail) / 2
        var result: [CGPoint] = []
        for (i, p) in unit.enumerated() where i % max(1, every) == 0 {
            result.append(CGPoint(x: offsetX + p.x * avail, y: offsetY + p.y * avail))
        }
        return result
    }
}

// MARK: - 分享卡

struct RouteArtShareCard: View {
    let run: RouteRun
    var template: ShareTemplate = .card

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x101014), Color(hex: 0x08080A)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(run.title)
                        .font(.system(size: template == .minimal ? 18 : 24, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Text(Brand.name)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.textFaint)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)

                RouteArtView(points: run.points, style: run.style, lineWidth: 3.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 10)

                HStack(spacing: 26) {
                    metric(distanceText, "公里")
                    metric(paceText, "配速")
                    metric(timeText, "时长")
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 360, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: template == .poster ? 0 : 28, style: .continuous))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textFaint)
        }
    }

    private var distanceText: String { String(format: "%.2f", run.distanceM / 1000) }

    private var paceText: String {
        guard run.paceSecPerKm > 0 else { return "—" }
        return String(format: "%d′%02d″", run.paceSecPerKm / 60, run.paceSecPerKm % 60)
    }

    private var timeText: String {
        String(format: "%d:%02d", run.durationSec / 60, run.durationSec % 60)
    }
}

// MARK: - 系统分享

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 渲染成图片

@MainActor
enum Snapshotter {
    static func image<V: View>(of view: V, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }
}
