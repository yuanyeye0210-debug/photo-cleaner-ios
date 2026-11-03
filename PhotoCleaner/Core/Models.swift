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
    var isFavorite: Bool = false   // 系统相册里收藏（❤️）过的：永远不进清理分类
    let pixelWidth: Int
    let pixelHeight: Int
    var analysis: AnalysisResult?

    var pixelCount: Int { pixelWidth * pixelHeight }
    /// 长宽比（≥1）
    var aspect: Double {
        let a = Double(max(pixelWidth, pixelHeight)), b = Double(max(1, min(pixelWidth, pixelHeight)))
        return a / b
    }
}

/// 清理分类
enum CleanCategory: String, CaseIterable, Identifiable, Hashable {
    // 顺序就是首页 / 分类页的显示顺序：先清理类，最后是「回顾」类（美食、宠物、风景）
    case similar, screenshots, textImages, documents, qrCodes, lowQuality, blurry, poorLight, large, videos
    case food, pets, scenery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .similar: return "相似照片"
        case .screenshots: return "截图"
        case .blurry: return "模糊照片"
        case .large: return "大文件"
        case .videos: return "视频"
        case .poorLight: return "过暗/过曝"
        case .textImages: return "文字图片"
        case .documents: return "文档/票据"
        case .qrCodes: return "二维码"
        case .lowQuality: return "低质量照片"
        case .food: return "美食"
        case .pets: return "宠物"
        case .scenery: return "风景"
        }
    }

    /// 需要逐张 AI 分析才能得出的分类（分析中显示转圈）
    var needsAnalysis: Bool {
        switch self {
        case .screenshots, .large, .videos: return false
        default: return true
        }
    }

    /// 「回顾」类：不算进可清理空间，只是方便按内容翻看
    var isBrowse: Bool {
        self == .food || self == .pets || self == .scenery
    }

    var subtitle: String {
        switch self {
        case .similar: return "连拍和重复，留一张最好的"
        case .screenshots: return "聊天记录、验证码截图"
        case .blurry: return "手抖、失焦的照片"
        case .large: return "占空间最多的照片"
        case .videos: return "按大小排序的视频"
        case .poorLight: return "太黑或太亮，基本看不清"
        case .textImages: return "聊天记录、长图、验证码"
        case .documents: return "票据、文件、证件照片"
        case .qrCodes: return "用过的付款码、海报二维码"
        case .lowQuality: return "AI 评分很低的照片"
        case .food: return "吃过的美食，留几张就够"
        case .pets: return "猫猫狗狗，挑出拍废的"
        case .scenery: return "风景照，挑出重复的"
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
        case .textImages: return "text.bubble"
        case .documents: return "doc.text"
        case .qrCodes: return "qrcode"
        case .lowQuality: return "hand.thumbsdown"
        case .food: return "fork.knife"
        case .pets: return "pawprint"
        case .scenery: return "mountain.2"
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
