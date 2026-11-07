import Foundation
import SwiftUI

// MARK: - 档位

enum Tier: String, Codable, CaseIterable, Identifiable {
    case free, pro, max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "免费版"
        case .pro: return Brand.tierPro
        case .max: return Brand.tierMax
        }
    }

    /// 每日 AI 热量识别次数
    var foodLimitPerDay: Int {
        switch self {
        case .free: return 10
        case .pro: return 40
        case .max: return .max
        }
    }

    /// AI 教练对话总次数
    var coachLimit: Int {
        switch self {
        case .free: return 20
        case .pro: return 300
        case .max: return .max
        }
    }

    var supportsICloudSync: Bool { self != .free || LaunchFlags.everythingUnlocked }
    var supportsPlaylistImport: Bool { self != .free || LaunchFlags.everythingUnlocked }
    var supportsPlanGenerator: Bool { self != .free || LaunchFlags.everythingUnlocked }
    var supportsAllShareTemplates: Bool { self != .free || LaunchFlags.everythingUnlocked }
}

// MARK: - 权益网关

enum Gate {
    /// 这是你自己的发行版：默认全部放行。
    static var current: Tier { LaunchFlags.everythingUnlocked ? .max : .free }

    static func canUseFoodAI(used: Int, tier: Tier = current) -> Bool {
        used < tier.foodLimitPerDay
    }

    static func canUseCoach(used: Int, tier: Tier = current) -> Bool {
        used < tier.coachLimit
    }

    static func canUse(style: RouteArtStyle, tier: Tier = current) -> Bool {
        !style.isPremium || tier.supportsAllShareTemplates
    }

    static func canUse(template: ShareTemplate, tier: Tier = current) -> Bool {
        !template.isPremium || tier.supportsAllShareTemplates
    }

    static func foodRemaining(used: Int, tier: Tier = current) -> Int {
        tier.foodLimitPerDay == .max ? 999 : max(0, tier.foodLimitPerDay - used)
    }

    static func coachRemaining(used: Int, tier: Tier = current) -> Int {
        tier.coachLimit == .max ? 999 : max(0, tier.coachLimit - used)
    }
}

// MARK: - 套餐目录（与会员方案页一一对应）

struct MembershipPlan: Identifiable, Hashable {
    let id: String
    let tier: Tier
    let title: String
    let badge: String?
    let priceText: String
    let perMonthText: String?
    let strikeText: String?
    let savingText: String?
    let months: Int
    let blurb: String?

    var monthlyPrice: Double {
        switch id {
        case "max.yearly": return 14.99 / 12
        case "max.half": return 7.99 / 6
        case "max.monthly": return 1.99
        case "pro.monthly": return 1.99
        default: return 0
        }
    }
}

enum MembershipCatalog {

    static let maxPlans: [MembershipPlan] = [
        MembershipPlan(
            id: "max.yearly",
            tier: .max,
            title: "年付",
            badge: "最划算",
            priceText: "14,99 € / 年",
            perMonthText: "折合 1,25 €/月",
            strikeText: "23,88 €",
            savingText: "省 8,89 € · -37%",
            months: 12,
            blurb: nil
        ),
        MembershipPlan(
            id: "max.half",
            tier: .max,
            title: "半年付",
            badge: nil,
            priceText: "7,99 € / 半年",
            perMonthText: "折合 1,33 €/月",
            strikeText: "11,94 €",
            savingText: "省 3,95 € · -33%",
            months: 6,
            blurb: nil
        ),
        MembershipPlan(
            id: "max.monthly",
            tier: .max,
            title: "月付",
            badge: nil,
            priceText: "1,99 € / 月",
            perMonthText: nil,
            strikeText: nil,
            savingText: nil,
            months: 1,
            blurb: nil
        )
    ]

    static let proPlans: [MembershipPlan] = [
        MembershipPlan(
            id: "pro.monthly",
            tier: .pro,
            title: Brand.tierPro,
            badge: nil,
            priceText: "1,99 € / 月",
            perMonthText: nil,
            strikeText: nil,
            savingText: nil,
            months: 1,
            blurb: "为自律者而生"
        )
    ]

    static let maxBenefits: [String] = [
        "AI 热量识别不限次数",
        "AI 教练对话不限次数",
        "渐进式 AI 学习",
        "iCloud 数据同步",
        "歌单链接导入解析",
        "含 Pro 全部权益"
    ]

    static let proBenefits: [String] = [
        "每天 40 次 AI 热量识别",
        "更充裕的 AI 教练对话额度",
        "AI 生成训练计划",
        "渐进式 AI 学习",
        "iCloud 数据同步",
        "歌单链接导入解析",
        "全部足迹画风与分享模板"
    ]

    struct FreePerk: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    static let freePerks: [FreePerk] = [
        FreePerk(icon: "figure.strengthtraining.traditional", text: "完整训练与记录"),
        FreePerk(icon: "camera.viewfinder", text: "每天 10 次 AI 热量识别"),
        FreePerk(icon: "sparkles", text: "AI 教练对话免费体验 20 次"),
        FreePerk(icon: "applewatch", text: "Apple Watch 连接与实时同步"),
        FreePerk(icon: "square.grid.2x2", text: "插件市场全部小工具"),
        FreePerk(icon: "figure.strengthtraining.functional", text: "视觉动作计数"),
        FreePerk(icon: "heart.fill", text: "Apple 健康双向同步"),
        FreePerk(icon: "map", text: "3 套足迹画风 · 1 套分享模板"),
        FreePerk(icon: "music.note", text: "歌词同步不限次数")
    ]

    static func plan(id: String) -> MembershipPlan? {
        (maxPlans + proPlans).first { $0.id == id }
    }
}

// MARK: - 购买服务

/// 本地模拟实现：这是你自己的 App，不做真实扣费。
/// 要做真订阅时，把这里换成 StoreKit 2 的 Product.purchase()，其余 UI 不用改。
@MainActor
final class PurchaseService: ObservableObject {

    @Published var isBusy = false
    @Published var lastError: String?

    func purchase(plan: MembershipPlan, into store: AppStore) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        try? await Task.sleep(nanoseconds: 450_000_000)

        store.state.membership = MembershipState(
            planID: plan.id,
            tier: plan.tier,
            startedAt: Date(),
            renewsAt: Calendar.current.date(byAdding: .month, value: plan.months, to: Date()) ?? Date(),
            isTrial: false
        )
        store.saveNow()
        return true
    }

    func restore(into store: AppStore) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        try? await Task.sleep(nanoseconds: 350_000_000)
        if LaunchFlags.everythingUnlocked {
            store.state.membership.tier = .max
            store.saveNow()
            return true
        }
        return false
    }
}
