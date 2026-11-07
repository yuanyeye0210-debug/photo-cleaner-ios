import SwiftUI
import UIKit

struct RouteDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var run: RouteRun
    @State private var showShare = false
    @State private var shareImage: UIImage?
    @State private var showMembership = false
    @State private var toast: String?

    init(run: RouteRun) {
        _run = State(initialValue: run)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        artCard
                        statsRow
                        stylePicker
                        templatePicker
                        shareButton
                    }
                    .padding(.horizontal, Metrics.page)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(run.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
            .sheet(isPresented: $showShare) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                        .presentationDetents([.medium, .large])
                }
            }
            .membershipSheet($showMembership)
            .toast($toast)
        }
    }

    private var artCard: some View {
        VStack(spacing: 0) {
            RouteArtView(points: run.points, style: run.style, lineWidth: 3.6)
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color(hex: 0x111114), Color(hex: 0x08080A)], startPoint: .top, endPoint: .bottom)
                )
        }
        .card(radius: 26, fill: Palette.cardSoft, stroke: Palette.stroke)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: String(format: "%.2f", run.distanceM / 1000), label: "公里")
            StatTile(value: paceText, label: "配速")
            StatTile(value: timeText, label: "时长")
        }
    }

    private var paceText: String {
        guard run.paceSecPerKm > 0 else { return "—" }
        return String(format: "%d′%02d″", run.paceSecPerKm / 60, run.paceSecPerKm % 60)
    }

    private var timeText: String {
        String(format: "%d:%02d", run.durationSec / 60, run.durationSec % 60)
    }

    private var stylePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("画风")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(RouteArtStyle.allCases.count) 套")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RouteArtStyle.allCases) { style in
                        chip(
                            title: style.title,
                            on: run.style == style,
                            locked: !Gate.canUse(style: style)
                        ) {
                            apply(style)
                        }
                    }
                }
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分享模板")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShareTemplate.allCases) { template in
                        chip(
                            title: template.title,
                            on: run.templateRaw == template.rawValue,
                            locked: !Gate.canUse(template: template)
                        ) {
                            apply(template)
                        }
                    }
                }
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private func chip(title: String, on: Bool, locked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
                }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(on ? Color.black : Palette.text)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(on ? Color.white : Palette.cardHigh)
            )
        }
        .buttonStyle(.plain)
    }

    private var shareButton: some View {
        HStack(spacing: 10) {
            Button {
                render()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .bold))
                    Text("分享").font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            }
            .buttonStyle(.plain)

            Button {
                UIPasteboard.general.string = shareText
                toast = "文案已复制"
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 52, height: 50)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.cardHigh))
            }
            .buttonStyle(.plain)
        }
    }

    private var shareText: String {
        "\(run.title)｜\(String(format: "%.2f", run.distanceM / 1000)) km｜配速 \(paceText)｜用时 \(timeText) — \(Brand.name)"
    }

    private func apply(_ style: RouteArtStyle) {
        guard Gate.canUse(style: style) else {
            showMembership = true
            return
        }
        run.style = style
        store.updateRun(run)
    }

    private func apply(_ template: ShareTemplate) {
        guard Gate.canUse(template: template) else {
            showMembership = true
            return
        }
        run.templateRaw = template.rawValue
        store.updateRun(run)
    }

    private func render() {
        guard let template = ShareTemplate(rawValue: run.templateRaw) else { return }
        let card = RouteArtShareCard(run: run, template: template)
        if let image = Snapshotter.image(of: card) {
            shareImage = image
            showShare = true
        } else {
            toast = "渲染失败，换一个画风试试"
        }
    }
}
