import XCTest
#if canImport(PhotoCleaner)
@testable import PhotoCleaner
#else
@testable import CleanCore
#endif

/// AI 识别相关的纯规则测试（不需要真机 / Vision）
final class VisionRulesTests: XCTestCase {

    private func unit(_ v: [Float]) -> [Float] { VisionRules.normalized(v)! }

    func testNormalizedAndDistance() {
        let a = unit([3, 4])
        XCTAssertEqual(a[0], 0.6, accuracy: 1e-6)
        XCTAssertEqual(a[1], 0.8, accuracy: 1e-6)
        XCTAssertNil(VisionRules.normalized([0, 0]))
        XCTAssertEqual(VisionRules.distance(a, a), 0, accuracy: 1e-6)
        // 正交单位向量距离 = √2
        XCTAssertEqual(VisionRules.distance(unit([1, 0]), unit([0, 1])), 2.0.squareRoot(), accuracy: 1e-5)
    }

    func testAIGroupingUsesFeaturesWithinTimeWindow() {
        let base: UInt64 = 0xF0F0_F0F0_0F0F_0F0F
        let entries = [
            // 换了角度：dHash 差很多（~32 位），但 AI 特征很近、时间相近 → 相似
            HashEntry(id: "a", hash: base, time: 1000, feature: unit([1, 0.2, 0])),
            HashEntry(id: "b", hash: base ^ 0xFFFF_FFFF, time: 1030, feature: unit([1, 0.3, 0])),
            // 时间相近但内容完全不同 → 不合并
            HashEntry(id: "c", hash: base ^ 0xFF00_0000_0000, time: 1010, feature: unit([0, 0, 1])),
            // 时间很远、dHash 接近、AI 特征几乎一样 → 重复图
            HashEntry(id: "d", hash: base ^ 0x3FF, time: 9_000_000, feature: unit([1, 0.21, 0])),
            // 时间很远、dHash 很远 → 不比较 AI 特征，不合并
            HashEntry(id: "e", hash: ~base, time: 5_000_000, feature: unit([1, 0.2, 0])),
        ]
        let groups = SimilarityGrouper.groups(entries)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), Set(["a", "b", "d"]))
    }

    func testBestIndexPrefersFaceThenAesthetics() {
        let c = [
            BestCandidate(faceQuality: 0.3, aesthetics: 0.5, sharpness: 500, pixels: 100),
            BestCandidate(faceQuality: 0.8, aesthetics: 0.1, sharpness: 100, pixels: 100),
            BestCandidate(faceQuality: 0.82, aesthetics: 0.4, sharpness: 100, pixels: 100),
        ]
        XCTAssertEqual(SimilarityGrouper.bestIndex(c), 2) // 人脸差不多时看美观评分
        let noFace = [
            BestCandidate(aesthetics: 0.1, sharpness: 300, pixels: 100),
            BestCandidate(aesthetics: 0.6, sharpness: 100, pixels: 100),
        ]
        XCTAssertEqual(SimilarityGrouper.bestIndex(noFace), 1)
    }

    func testContentTags() {
        let t = VisionRules.tags(labels: [("food", 0.9), ("dog", 0.3), ("receipt", 0.7), ("unknown_xyz", 0.99)], hasQR: true)
        XCTAssertEqual(t, [.food, .document, .qrCode])
        // 有人物时不算风景
        XCTAssertFalse(VisionRules.tags(labels: [("mountain", 0.9), ("people", 0.8)], hasQR: false).contains(.scenery))
        XCTAssertTrue(VisionRules.tags(labels: [("mountain", 0.9)], hasQR: false).contains(.scenery))
    }

    func testVerificationCode() {
        XCTAssertEqual(VisionRules.verificationCode(in: ["【某某】您的验证码是 482913，5分钟内有效"]), "482913")
        XCTAssertEqual(VisionRules.verificationCode(in: ["Your verification code: 7731"]), "7731")
        XCTAssertNil(VisionRules.verificationCode(in: ["今天花了 1234 元"]))
        XCTAssertNil(VisionRules.verificationCode(in: ["验证码 123"]))
    }

    func testPoorLightExcludesTextAndLongImages() {
        // 白底聊天长图：以前被当成过曝
        XCTAssertFalse(VisionRules.isPoorLight(brightness: 245, isScreenshot: false, isUtility: nil,
                                               textHeavy: false, tags: [], aspect: 1496.0 / 393.0))
        XCTAssertFalse(VisionRules.isPoorLight(brightness: 245, isScreenshot: false, isUtility: nil,
                                               textHeavy: true, tags: [], aspect: 1.3))
        XCTAssertTrue(VisionRules.isPoorLight(brightness: 245, isScreenshot: false, isUtility: false,
                                              textHeavy: false, tags: [], aspect: 1.33))
        XCTAssertTrue(VisionRules.isPoorLight(brightness: 20, isScreenshot: false, isUtility: nil,
                                              textHeavy: false, tags: [], aspect: 1.33))
    }

    func testLowQualityAndTextHelpers() {
        XCTAssertTrue(VisionRules.isLowQuality(aesthetics: -0.6, isUtility: false, isScreenshot: false))
        XCTAssertFalse(VisionRules.isLowQuality(aesthetics: -0.6, isUtility: true, isScreenshot: false))
        XCTAssertFalse(VisionRules.isLowQuality(aesthetics: nil, isUtility: nil, isScreenshot: false))
        XCTAssertTrue(VisionRules.isTextHeavy(lines: 6, chars: 10))
        XCTAssertFalse(VisionRules.isTextHeavy(lines: 2, chars: 20))
        let (w, h) = VisionRules.textTargetSize(width: 4032, height: 3024)
        XCTAssertEqual(w, 1024)
        XCTAssertEqual(h, 768)
        let (lw, lh) = VisionRules.textTargetSize(width: 1170, height: 6000) // 长截图：短边 ~900，长边 ≤ 4096
        XCTAssertLessThanOrEqual(lh, 4096)
        XCTAssertGreaterThanOrEqual(lw, 700)
    }
}
