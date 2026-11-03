import Photos
import SwiftUI
import WidgetKit

// 桌面小组件：显示截图数、那年今日、待删除（如果 App Group 可用），点按直接跳到对应页面。
// 免费 Apple ID 侧载时没有 App Group，所以数字直接用 PhotoKit 读，不依赖主 App 共享数据。

struct CleanerEntry: TimelineEntry {
    let date: Date
    let authorized: Bool
    let screenshots: Int
    let onThisDay: Int
    let total: Int
    let snapshot: WidgetSnapshot?
}

struct CleanerProvider: TimelineProvider {
    func placeholder(in context: Context) -> CleanerEntry {
        CleanerEntry(date: Date(), authorized: true, screenshots: 128, onThisDay: 12, total: 8000, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CleanerEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CleanerEntry>) -> Void) {
        let entry = Self.load()
        // 每 3 小时刷新一次，过了零点「那年今日」也会更新
        let cal = Calendar.current
        let next = min(Date().addingTimeInterval(3 * 3600),
                       cal.startOfDay(for: Date().addingTimeInterval(86400)).addingTimeInterval(60))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    static func load() -> CleanerEntry {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let ok = status == .authorized || status == .limited
        let snap = WidgetSnapshot.decode(UserDefaults(suiteName: WidgetSnapshot.appGroup)?.data(forKey: WidgetSnapshot.key))
        guard ok else {
            return CleanerEntry(date: Date(), authorized: false, screenshots: 0, onThisDay: 0, total: 0, snapshot: snap)
        }
        let shots = PHFetchOptions()
        shots.predicate = NSPredicate(format: "mediaType == %d AND (mediaSubtypes & %d) != 0 AND favorite == NO",
                                      PHAssetMediaType.image.rawValue, PHAssetMediaSubtype.photoScreenshot.rawValue)
        let screenshots = PHAsset.fetchAssets(with: shots).count

        let total = PHAsset.fetchAssets(with: PHFetchOptions()).count

        // 那年今日：往前 30 年里每年的今天
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var preds: [NSPredicate] = []
        for y in 1...30 {
            guard let start = cal.date(byAdding: .year, value: -y, to: today),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { continue }
            preds.append(NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate))
        }
        let otd = PHFetchOptions()
        otd.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "favorite == NO"),
            NSCompoundPredicate(orPredicateWithSubpredicates: preds),
        ])
        let onThisDay = PHAsset.fetchAssets(with: otd).count

        return CleanerEntry(date: Date(), authorized: true, screenshots: screenshots,
                            onThisDay: onThisDay, total: total, snapshot: snap)
    }
}

private enum W {
    static let bg = Color(red: 0.06, green: 0.06, blue: 0.07)
    static let text2 = Color.white.opacity(0.62)
    static let accent = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.62, blue: 0.25)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.36)

    static func bytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}

struct CleanerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CleanerEntry

    var body: some View {
        Group {
            if !entry.authorized {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark").font(.title2).foregroundStyle(W.orange)
                    Text("打开 App 允许访问相册").font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .widgetURL(DeepLink.home.url)
            } else if family == .systemSmall {
                small
            } else {
                medium
            }
        }
        .foregroundStyle(.white)
        .containerBackground(W.bg, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(W.accent)
                Spacer()
                Text("相册清理").font(.system(size: 11, weight: .semibold)).foregroundStyle(W.text2)
            }
            Spacer()
            Text("\(entry.screenshots)").font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
            Text("张截图可清理").font(.system(size: 12)).foregroundStyle(W.text2)
            if entry.onThisDay > 0 {
                Text("那年今日 \(entry.onThisDay) 张").font(.system(size: 12, weight: .semibold)).foregroundStyle(W.orange)
            }
        }
        .widgetURL(DeepLink.category("screenshots").url)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(W.accent)
                Text("相册清理").font(.system(size: 13, weight: .semibold))
                Spacer()
                if let s = entry.snapshot, s.freedTotal > 0 {
                    Text("已释放 \(W.bytes(s.freedTotal))").font(.system(size: 11)).foregroundStyle(W.text2)
                } else {
                    Text("共 \(entry.total) 项").font(.system(size: 11)).foregroundStyle(W.text2)
                }
            }
            HStack(spacing: 8) {
                tile(icon: "camera.viewfinder", tint: W.accent, value: "\(entry.screenshots)",
                     label: String(localized: "截图"), link: DeepLink.category("screenshots").url)
                tile(icon: "calendar", tint: W.orange, value: "\(entry.onThisDay)",
                     label: String(localized: "那年今日"), link: DeepLink.quick("onThisDay").url)
                if let s = entry.snapshot, s.pending > 0 {
                    tile(icon: "trash.fill", tint: W.danger, value: "\(s.pending)",
                         label: String(localized: "待删除"), link: DeepLink.review.url)
                } else {
                    tile(icon: "dice.fill", tint: Color.purple, value: "10",
                         label: String(localized: "随机整理"), link: DeepLink.quick("random").url)
                }
            }
        }
    }

    private func tile(icon: String, tint: Color, value: String, label: String, link: URL) -> some View {
        Link(destination: link) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.system(size: 11)).foregroundStyle(W.text2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel(Text("\(label) \(value)"))
    }
}

struct PhotoCleanerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PhotoCleanerWidget", provider: CleanerProvider()) { entry in
            CleanerWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("相册清理"))
        .description(Text("看看有多少截图可以清理，以及那年今日拍的照片。"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PhotoCleanerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PhotoCleanerWidget()
    }
}
