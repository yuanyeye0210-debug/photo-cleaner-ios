import AppIntents

// 快捷指令 / Siri / 聚焦搜索里的「相册清理」动作。都只是打开 App 跳到对应页面。

struct RandomTenIntent: AppIntent {
    static var title: LocalizedStringResource = "随机整理 10 张"
    static var description = IntentDescription("打开相册清理，随机挑 10 张还没整理过的照片滑一滑。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.pending = .quick(QuickMode.random.rawValue)
        return .result()
    }
}

struct OnThisDayIntent: AppIntent {
    static var title: LocalizedStringResource = "那年今日"
    static var description = IntentDescription("打开往年今天拍的照片。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.pending = .quick(QuickMode.onThisDay.rawValue)
        return .result()
    }
}

struct CleanScreenshotsIntent: AppIntent {
    static var title: LocalizedStringResource = "清理截图"
    static var description = IntentDescription("打开截图分类，滑动挑出要删的截图。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.pending = .category(CleanCategory.screenshots.rawValue)
        return .result()
    }
}

struct ReviewDeleteIntent: AppIntent {
    static var title: LocalizedStringResource = "确认待删除"
    static var description = IntentDescription("打开待删除列表，确认后删除。")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLinkRouter.shared.pending = .review
        return .result()
    }
}

struct PhotoCleanerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RandomTenIntent(), phrases: [
            "用\(.applicationName)随机整理",
            "\(.applicationName)随机整理 10 张",
        ])
        AppShortcut(intent: OnThisDayIntent(), phrases: [
            "\(.applicationName)那年今日",
        ])
        AppShortcut(intent: CleanScreenshotsIntent(), phrases: [
            "用\(.applicationName)清理截图",
        ])
        AppShortcut(intent: ReviewDeleteIntent(), phrases: [
            "\(.applicationName)确认待删除",
        ])
    }
}
