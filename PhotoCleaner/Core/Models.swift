import Photos
import SwiftUI

/// 相册里的一项（照片或视频）
struct PhotoItem: Identifiable, @unchecked Sendable {
    let id: String              // PHAsset.localIdentifier
    let asset: PHAsset
    var fileSize: Int64         // 先用缓存或估算值，后台再补成真实大小
    var sizeExact = false       // fileSize 是否是真实大小
    var liveVideoBytes: Int64 = 0   // 实况照片里视频部分的大小
    let creationDate: Date?
    var modificationDate: Date? = nil
    let isVideo: Bool
    let isScreenshot: Bool
    var isFavorite: Bool = false   // 系统相册里收藏（❤️）过的：永远不进清理分类
    var isLivePhoto = false
    var isScreenRecording = false
    var duration: Double = 0
    var burstID: String? = nil
    var burstHidden = false     // 连拍里没被选为封面的帧（系统相册默认不显示）
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
    case similar, exactDuplicates, bursts, screenshots, textImages, documents, qrCodes, lowQuality, blurry, poorLight
    case livePhotos, large, videos
    case food, pets, scenery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .similar: return String(localized: "相似照片")
        case .exactDuplicates: return String(localized: "完全重复")
        case .bursts: return String(localized: "连拍")
        case .livePhotos: return String(localized: "实况照片")
        case .screenshots: return String(localized: "截图")
        case .blurry: return String(localized: "模糊照片")
        case .large: return String(localized: "大文件")
        case .videos: return String(localized: "视频")
        case .poorLight: return String(localized: "过暗/过曝")
        case .textImages: return String(localized: "文字图片")
        case .documents: return String(localized: "文档/票据")
        case .qrCodes: return String(localized: "二维码")
        case .lowQuality: return String(localized: "低质量照片")
        case .food: return String(localized: "美食")
        case .pets: return String(localized: "宠物")
        case .scenery: return String(localized: "风景")
        }
    }

    /// 需要逐张 AI 分析才能得出的分类（分析中显示转圈）
    var needsAnalysis: Bool {
        switch self {
        case .screenshots, .large, .videos, .livePhotos, .bursts: return false
        default: return true
        }
    }

    /// 「回顾」类：不算进可清理空间，只是方便按内容翻看
    var isBrowse: Bool {
        self == .food || self == .pets || self == .scenery
    }

    var subtitle: String {
        switch self {
        case .similar: return String(localized: "长得像的几张，留一张最好的")
        case .exactDuplicates: return String(localized: "一模一样的文件，一键只留一份")
        case .bursts: return String(localized: "连拍只留一张")
        case .livePhotos: return String(localized: "转成静态照片，省下视频部分")
        case .screenshots: return String(localized: "聊天记录、验证码截图")
        case .blurry: return String(localized: "手抖、失焦的照片")
        case .large: return String(localized: "占空间最多的照片")
        case .videos: return String(localized: "按大小排序的视频")
        case .poorLight: return String(localized: "太黑或太亮，基本看不清")
        case .textImages: return String(localized: "聊天记录、长图、验证码")
        case .documents: return String(localized: "票据、文件、证件照片")
        case .qrCodes: return String(localized: "用过的付款码、海报二维码")
        case .lowQuality: return String(localized: "AI 评分很低的照片")
        case .food: return String(localized: "吃过的美食，留几张就够")
        case .pets: return String(localized: "猫猫狗狗，挑出拍废的")
        case .scenery: return String(localized: "风景照，挑出重复的")
        }
    }

    var icon: String {
        switch self {
        case .similar: return "square.on.square"
        case .exactDuplicates: return "doc.on.doc"
        case .bursts: return "square.stack.3d.down.right"
        case .livePhotos: return "livephoto"
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

/// 小批量整理模式
enum QuickMode: String, CaseIterable, Identifiable, Hashable {
    case onThisDay, random, later
    var id: String { rawValue }
    var title: String {
        switch self {
        case .onThisDay: return String(localized: "那年今日")
        case .random: return String(localized: "随机 10 张")
        case .later: return String(localized: "稍后再看")
        }
    }
    var icon: String {
        switch self {
        case .onThisDay: return "calendar"
        case .random: return "dice"
        case .later: return "clock.arrow.circlepath"
        }
    }
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
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMdHHmm")
        return f
    }()

    static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f
    }()

    static func date(_ d: Date?) -> String {
        guard let d else { return String(localized: "未知日期") }
        return dayFormatter.string(from: d)
    }

    static func duration(_ s: Double) -> String {
        let t = Int(s.rounded())
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60)
                         : String(format: "%d:%02d", t / 60, t % 60)
    }
}
