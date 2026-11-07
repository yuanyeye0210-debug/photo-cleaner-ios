import Foundation

/// 品牌与可替换常量。改名只动这里 + 工程 Build Settings 里的 Bundle ID。
enum Brand {
    static let name = "Stride"
    static let nameZH = "步迹"
    static let tagline = "练得清楚，才练得下去"
    static let bundleID = "com.yg.stride"
    static let supportEmail = "support@example.com"

    /// 会员品牌名（会员方案页标题用）
    static let tierMax = "\(name) Max"
    static let tierPro = "\(name) Pro"
}

/// 全局开关：这是你自己的发行版，所有权益默认全开。
/// 想真做订阅时把它设为 false，并把 PurchaseService 换成 StoreKit 2 实现。
enum LaunchFlags {
    static let everythingUnlocked = true
    static let showMembershipEntry = true
    static let simulateWatch = true
}
