import XCTest
import UIKit

/// 上线前自检：在模拟器里真的打开 App，走一遍首页 → 分类滑动筛选 → 网格多选 → 相似照片 → 分类/清理页，
/// 截图存档，并检查：
/// - 每个分类页只有一个「滑动筛选 / 网格多选」切换和一行进度（不会界面套界面）
/// - 卡片上的照片确实显示出来了（不是一块灰色）
/// - 照片不会溢出到卡片上面
final class LayoutVerifyTests: XCTestCase {
    let app = XCUIApplication()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    lazy var dir: String = ProcessInfo.processInfo.environment["VERIFY_SHOTS"] ?? NSTemporaryDirectory()

    // MARK: 工具

    @discardableResult
    func shot(_ name: String) -> XCUIScreenshot {
        let s = XCUIScreen.main.screenshot()
        try? s.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        let a = XCTAttachment(screenshot: s); a.name = name; a.lifetime = .keepAlways; add(a)
        return s
    }

    func log(_ line: String) {
        print("VERIFY: \(line)")
        let url = URL(fileURLWithPath: dir).appendingPathComponent("report.txt")
        let data = (line + "\n").data(using: .utf8)!
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); h.closeFile() }
        else { try? data.write(to: url) }
    }

    func check(_ ok: Bool, _ what: String) {
        log((ok ? "PASS " : "FAIL ") + what)
        XCTAssertTrue(ok, what)
    }

    func any(_ predicate: String, _ args: CVarArg...) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: predicate, argumentArray: args))
    }

    func handlePermission() {
        let allow = app.buttons["允许访问相册"]
        if allow.waitForExistence(timeout: 8) { allow.tap(); sleep(2) }
        for _ in 0..<8 {
            var tapped = false
            for label in ["允许完全访问", "Allow Full Access", "允许访问所有照片", "Allow Access to All Photos", "好", "OK"] {
                for root in [springboard, app] {
                    let b = root.buttons[label]
                    if b.exists { b.tap(); tapped = true; sleep(2); break }
                }
                if tapped { break }
            }
            if !tapped {
                if app.buttons["允许访问相册"].exists { app.buttons["允许访问相册"].tap(); sleep(2); continue }
                break
            }
        }
    }

    /// 等分析完：首页圆环的说明从「已分析 x%」变成「可清理 x%」
    func waitForScan(maxSeconds: Int) -> Bool {
        let done = any("label BEGINSWITH %@ AND label ENDSWITH %@", "可清理 ", "%")
        var waited = 0
        while waited < maxSeconds {
            if done.firstMatch.exists { return true }
            sleep(15); waited += 15
            if waited % 60 == 0 { shot(String(format: "00-scan-%03ds", waited)) }
        }
        return done.firstMatch.exists
    }

    func scrollTop() { for _ in 0..<4 { app.swipeDown(velocity: .fast) } ; sleep(1) }

    /// 在首页找到某一行并点开（label 形如「截图，3 项，…」）；跳过 0 项
    @discardableResult
    func openFromHome(_ prefix: String, allowEmpty: Bool = false) -> Bool {
        scrollTop()
        for _ in 0..<8 {
            let e = any("label BEGINSWITH %@", prefix).firstMatch
            if e.exists {
                if !allowEmpty && e.label.hasPrefix(prefix + "0 ") { log("skip \(e.label)"); return false }
                if e.isHittable { log("open \(e.label)"); e.tap(); sleep(3); return true }
            }
            app.swipeUp(velocity: 600)
        }
        log("not found: \(prefix)")
        return false
    }

    func back() {
        let b = app.navigationBars.buttons.firstMatch
        if b.exists { b.tap() } else { app.swipeRight() }
        sleep(2)
    }

    /// 截图里某块区域「有内容」的比例：和最常见颜色差得多的像素占多少
    func contentRatio(_ s: XCUIScreenshot, _ rect: CGRect) -> Double {
        guard let cg = s.image.cgImage else { return 0 }
        let scale = CGFloat(cg.width) / app.windows.firstMatch.frame.width
        let r = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard r.width > 4, r.height > 4, let crop = cg.cropping(to: r) else { return 0 }
        let w = 64, h = 64
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        var lum = [Int](); lum.reserveCapacity(w * h)
        for i in 0..<(w * h) {
            lum.append((Int(px[i * 4]) * 3 + Int(px[i * 4 + 1]) * 6 + Int(px[i * 4 + 2])) / 10)
        }
        var hist = [Int](repeating: 0, count: 256); for l in lum { hist[l] += 1 }
        let mode = hist.firstIndex(of: hist.max()!)!
        return Double(lum.filter { abs($0 - mode) > 14 }.count) / Double(lum.count)
    }

    /// 滑动筛选页的检查：一个切换、一行进度、卡片照片显示出来、没有溢出到卡片上面
    func verifySwipeScreen(_ name: String) {
        let card = app.descendants(matching: .any)["swipeCard"]
        check(card.waitForExistence(timeout: 15), "\(name): 有滑动卡片")
        sleep(4)
        let s = shot(name)
        check(app.buttons.matching(NSPredicate(format: "label == %@", "滑动筛选")).count == 1, "\(name): 只有一个「滑动筛选」")
        check(app.buttons.matching(NSPredicate(format: "label == %@", "网格多选")).count == 1, "\(name): 只有一个「网格多选」")
        let remain = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "还剩 ")).count
        check(remain == 1, "\(name): 只有一行「还剩 N 张」(实际 \(remain))")
        guard card.exists else { return }
        let f = card.frame
        log("\(name): card \(f) label=\(card.label)")
        // 卡片上半部分（不含底部日期文字）要有图片内容
        let body = CGRect(x: f.minX + 8, y: f.minY + 8, width: f.width - 16, height: f.height * 0.6)
        let ratio = contentRatio(s, body)
        check(ratio > 0.15, "\(name): 卡片照片已显示（内容像素 \(String(format: "%.2f", ratio))）")
        // 卡片上方 3~11pt 的细条应该是纯背景（照片没有溢出到卡片外面）
        let above = CGRect(x: f.minX + 30, y: f.minY - 11, width: f.width - 60, height: 8)
        let leak = contentRatio(s, above)
        check(leak < 0.05, "\(name): 照片没有溢出到卡片上方（\(String(format: "%.2f", leak))）")
    }

    // MARK: 测试

    func testScreensLookRight() throws {
        continueAfterFailure = true
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        addUIInterruptionMonitor(withDescription: "photos") { alert in
            for label in ["允许完全访问", "Allow Full Access", "允许访问所有照片", "Allow Access to All Photos"] {
                let b = alert.buttons[label]
                if b.exists { b.tap(); return true }
            }
            return false
        }
        app.launch()
        sleep(3)
        shot("00-launch")
        handlePermission()
        app.tap()
        let scanned = waitForScan(maxSeconds: 900)
        log("scan finished: \(scanned)")
        scrollTop()
        shot("01-home")
        app.swipeUp(velocity: 500); sleep(1); shot("01-home-2")
        app.swipeUp(velocity: 500); sleep(1); shot("01-home-3")

        // 1) 截图分类（用户反馈出问题的那页）
        if openFromHome("截图，") {
            verifySwipeScreen("02-screenshots-swipe")
            // 往右滑保留一张，看下一张
            let card = app.descendants(matching: .any)["swipeCard"]
            if card.exists {
                let c = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                c.press(forDuration: 0.1, thenDragTo: c.withOffset(CGVector(dx: 320, dy: 0)))
                sleep(2)
                verifySwipeScreen("03-screenshots-next")
            }
            // 网格多选
            let grid = app.buttons["网格多选"]
            if grid.exists {
                grid.tap(); sleep(3)
                shot("04-screenshots-grid")
                check(app.buttons.matching(NSPredicate(format: "label == %@", "滑动筛选")).count == 1, "网格: 只有一个「滑动筛选」")
                check(!app.descendants(matching: .any)["swipeCard"].exists, "网格: 没有滑动卡片")
                check(app.images.count > 0, "网格: 有缩略图（\(app.images.count)）")
                app.buttons["滑动筛选"].tap(); sleep(2)
                verifySwipeScreen("05-screenshots-back-to-swipe")
            }
            back()
        } else {
            log("截图分类为空，跳过")
        }

        // 2) 其他会出现滑动筛选的分类（有哪个用哪个）
        for name in ["模糊照片", "过暗/过曝", "二维码", "风景"] {
            if openFromHome("\(name)，") {
                verifySwipeScreen("06-\(name.replacingOccurrences(of: "/", with: "-"))-swipe")
                back()
                break
            }
        }

        // 3) 小批量：随机 10 张（一定有照片）
        if openFromHome("随机 10 张", allowEmpty: true) {
            verifySwipeScreen("07-random10-swipe")
            back()
        }

        // 4) 相似照片
        if openFromHome("相似照片，") {
            sleep(2)
            shot("08-similar")
            check(app.buttons.matching(NSPredicate(format: "label == %@", "滑动筛选")).count == 0, "相似照片: 没有混进滑动筛选界面")
            app.swipeUp(velocity: 500); sleep(1); shot("09-similar-2")
            back()
        }

        // 5) 分类页 / 清理页
        scrollTop()
        for (i, t) in ["分类", "清理"].enumerated() {
            let b = app.buttons[t]
            if b.exists { b.tap() } else {
                let f = app.windows.firstMatch.frame
                let tabsW = f.width - 32 - 12 - 64 - 10
                let x = 16 + 5 + tabsW / 3 * (CGFloat(i + 1) + 0.5)
                app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: x / f.width, dy: (f.height - 70) / f.height)).tap()
            }
            sleep(2)
            shot("1\(i)-tab-\(t)")
        }
        log("done")
    }
}
