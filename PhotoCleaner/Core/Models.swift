import Photos
import SwiftUI

/// 相册里的一项（照片或视频）
struct PhotoItem: Identifiable, @unchecked Sendable {
    let id: String              // PHAsset.localIdentifier
    let asset: PHAsset
    let fileSize: Int64
    let creationDate: Date?
    let isVideo: Bool
    let isScreenshot: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    var analysis: AnalysisResult?

    var pixelCount: Int { pixelWidth * pixelHeight }
}

/// 清理分类
enum CleanCategory: String, CaseIterable, Identifiable, Hashable {
    case similar, screenshots, blurry, large, videos, poorLight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .similar: return "相似照片"
        case .screenshots: return "截图"
        case .blurry: return "模糊照片"
        case .large: return "大文件"
        case .videos: return "视频"
        case .poorLight: return "过暗/过曝"
        }
    }

    var subtitle: String {
        switch self {
        case .similar: return "连拍和重复，留一张最好的"
        case .screenshots: return "聊天记录、验证码截图"
        case .blurry: return "手抖、失焦的照片"
        case .large: return "占空间最多的照片"
        case .videos: return "按大小排序的视频"
        case .poorLight: return "太黑或太亮，基本看不清"
        }
    }

    var icon: String {
        switch self {
        case .similar: return "square.on.square"
        case .screenshots: return "iphone"
        case .blurry: return "camera.aperture"
        case .large: return "externaldrive"
        case .videos: return "video"
        case .poorLight: return "sun.max"
        }
    }
}

/// 用户对一张照片的决定
enum Decision {
    case delete, keep
}

/// 按月分组
struct MonthGroup: Identifiable {
    let id: String      // "2026-11"
    let title: String   // "2026年11月"
    let ids: [String]
}

enum Fmt {
    static func bytes(_ n: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB]
        return f.string(fromByteCount: n)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f
    }()

    static func date(_ d: Date?) -> String {
        guard let d else { return "未知日期" }
        return dayFormatter.string(from: d)
    }
}
