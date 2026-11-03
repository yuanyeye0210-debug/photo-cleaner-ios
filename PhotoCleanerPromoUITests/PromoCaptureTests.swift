import XCTest

/// 宣传视频素材：自动操作 App 并截图（只在 Promo Capture 流程里运行，不参与正常构建和测试）
final class PromoCaptureTests: XCTestCase {
    let app = XCUIApplication()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    lazy var dir: String = ProcessInfo.processInfo.environment["PROMO_SHOTS"] ?? NSTemporaryDirectory()

    func shot(_ name: String) {
        let safe = name.replacingOccurrences(of: "/", with: "-")
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(safe).png"))
    }

    func mark(_ name: String) {
        let line = "\(Date().timeIntervalSince1970) \(name)\n"
        let url = URL(fileURLWithPath: dir).appendingPathComponent("marks.txt")
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
        } else {
            try? line.data(using: .utf8)!.write(to: url)
        }
    }

    func handleAlerts() {
        for _ in 0..<5 {
            var tapped = false
            for label in ["允许完全访问", "Allow Full Access", "允许访问所有照片", "Allow Access to All Photos", "打开", "Open", "好", "OK", "允许", "Allow"] {
                let b = springboard.buttons[label]
                if b.exists { b.tap(); tapped = true; sleep(1); break }
            }
            if !tapped { break }
        }
    }

    func element(prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        let w = app.windows.firstMatch
        let f = w.frame
        return w.coordinate(withNormalizedOffset: CGVector(dx: x / f.width, dy: y / f.height))
    }

    func tab(_ i: Int) {
        let f = app.windows.firstMatch.frame
        let tabsW = f.width - 32 - 12 - 64 - 10
        let x = 16 + 5 + tabsW / 3 * (CGFloat(i) + 0.5)
        point(x, f.height - 34 - 4 - 32).tap()
        sleep(2)
    }

    func scrollTop() { for _ in 0..<4 { app.swipeDown(velocity: .fast) } }

    @discardableResult
    func openFromHome(_ prefix: String) -> Bool {
        scrollTop()
        for _ in 0..<6 {
            let e = element(prefix: prefix)
            if e.exists && e.isHittable { e.tap(); sleep(3); return true }
            app.swipeUp(velocity: 600)
        }
        return false
    }

    func back() {
        let b = app.navigationBars.buttons.firstMatch
        if b.exists { b.tap() } else { app.swipeRight() }
        sleep(2)
    }

    func drag(_ dx: CGFloat, _ dy: CGFloat) {
        let f = app.windows.firstMatch.frame
        let s = point(f.width / 2, f.height * 0.58)
        s.press(forDuration: 0.15, thenDragTo: s.withOffset(CGVector(dx: dx, dy: dy)),
                withVelocity: XCUIGestureVelocity(420), thenHoldForDuration: 0.05)
    }

    func testCapture() throws {
        continueAfterFailure = true
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        mark("launch")
        app.launch()
        sleep(3)
        shot("00-permission")
        let allow = app.buttons["允许访问相册"]
        if allow.exists { allow.tap(); sleep(2); handleAlerts() }
        handleAlerts()
        sleep(2)
        mark("home-scan"); shot("01-home-scanning")
        sleep(25); shot("02-home-scanning2")
        sleep(50)
        mark("home"); shot("03-home")
        app.swipeUp(velocity: 500); sleep(1); shot("04-home-2")
        app.swipeUp(velocity: 500); sleep(1); shot("05-home-3")
        app.swipeUp(velocity: 500); sleep(1); shot("06-home-4")

        // 相似照片 + 整组全部删除
        if openFromHome("相似照片，") {
            mark("similar"); shot("cat-similar")
            let del = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "整组全部删除")).firstMatch
            if del.exists { del.tap(); sleep(2); shot("similar-deleteall"); 
                let c = app.buttons["取消"]; if c.exists { c.tap() } else { app.tap() }; sleep(1) }
            app.swipeUp(velocity: 500); sleep(1); shot("cat-similar-2")
            back()
        }
        for name in ["完全重复", "连拍", "截图", "文字图片", "文档/票据", "二维码", "低质量照片", "模糊照片", "过暗/过曝", "实况照片", "大文件", "美食", "宠物", "风景"] {
            if openFromHome("\(name)，") { shot("cat-\(name)"); back() }
        }

        // 滑动演示（录屏里按 marks 剪）
        for name in ["模糊照片", "风景", "截图", "文字图片"] {
            if openFromHome("\(name)，") {
                sleep(3)
                mark("swipe-start"); shot("swipe-0")
                mark("swipe-left"); drag(-320, 10); sleep(2); shot("swipe-1")
                mark("swipe-right"); drag(320, 10); sleep(2); shot("swipe-2")
                mark("swipe-up"); drag(0, -380); sleep(2); shot("swipe-3")
                mark("swipe-left2"); drag(-320, 10); sleep(2); shot("swipe-4")
                mark("swipe-end")
                back()
                break
            }
        }

        // 清理页 / 分类页
        tab(2); mark("clean"); shot("tab-clean"); app.swipeUp(velocity: 500); sleep(1); shot("tab-clean-2")
        tab(1); mark("library"); shot("tab-library"); app.swipeUp(velocity: 500); sleep(1); shot("tab-library-2")
        tab(0); sleep(1)
        if openFromHome("那年今日") { shot("quick-onThisDay"); back() }
        if openFromHome("随机 10 张") { shot("quick-random"); back() }
        scrollTop()
        let settings = app.buttons["设置"]
        if settings.exists { settings.tap(); sleep(2); shot("settings"); app.swipeDown(velocity: .fast); sleep(1) }
        mark("done")
    }
}
