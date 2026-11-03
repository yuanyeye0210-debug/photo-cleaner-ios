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
        XCTAssertEqual(VisionRules.distance(unit([1, 0]), unit([0, 1])), Float(2).squareRoot(), accuracy: 1e-5)
    }

    func testAIGroupingUsesFeaturesWithinTimeWindow() {
        let base: UInt64 = 0xF0F0_F0F0_0F0F_0F0F
        let entries = [
            // 换了角度：dHash 差很多（~32 位），但 AI 特征很近、时间相近 → 相似
            HashEntry(id: "a", hash: base, time: 1000, feature: unit([1, 0.2, 0]), labels: ["cat", "sofa", "indoor"]),
            HashEntry(id: "b", hash: base ^ 0xFFFF_FFFF, time: 1030, feature: unit([1, 0.3, 0]), labels: ["cat", "sofa", "pillow"]),
            // 时间相近但内容完全不同 → 不合并
            HashEntry(id: "c", hash: base ^ 0xFF00_0000_0000, time: 1010, feature: unit([0, 0, 1])),
            // 时间很远、dHash 接近、AI 特征几乎一样 → 重复图
            HashEntry(id: "d", hash: base ^ 0x3FF, time: 9_000_000, feature: unit([1, 0.21, 0])),
            // 时间很远、dHash 很远 → 不比较 AI 特征，不合并
            HashEntry(id: "e", hash: ~base, time: 5_000_000, feature: unit([1, 0.2, 0])),
        ]
        // 去掉 d 时 a、b 一组（主体标签一致）
        XCTAssertEqual(SimilarityGrouper.groups(entries.filter { $0.id != "d" }), [["a", "b"]])
        // 有 d 时：a–d 是重复图（更像），b–d 不相似 → 完全连接只留 {a, d}，b 不会被链进来
        let groups = SimilarityGrouper.groups(entries)
        XCTAssertEqual(groups, [["a", "d"]])
    }

    // MARK: 分组准确度（完全连接、主体、比例、人脸、「不是相似」）

    private let far: UInt64 = 0xFFFF_FFFF_0000_0000   // 和 0 差 32 位：dHash 不能当主体证据

    func testCompleteLinkagePreventsChaining() {
        // A 像 B（0.29），B 像 C（0.25），但 A 和 C 差很远（0.54）→ 只能有 {B, C}
        let l = ["dog", "grass"]
        let a = HashEntry(id: "A", hash: 0, time: 0, feature: unit([1, 0, 0]), labels: l)
        let b = HashEntry(id: "B", hash: far, time: 20, feature: unit([1, 0.3, 0]), labels: l)
        let c = HashEntry(id: "C", hash: 0x00FF_00FF_00FF_00FF, time: 40, feature: unit([1, 0.62, 0]), labels: l)
        XCTAssertNotNil(SimilarityGrouper.link(a, b))
        XCTAssertNotNil(SimilarityGrouper.link(b, c))
        XCTAssertNil(SimilarityGrouper.link(a, c))
        XCTAssertEqual(SimilarityGrouper.groups([a, b, c]), [["B", "C"]])
        XCTAssertEqual(SimilarityGrouper.groupsReference([a, b, c]), [["B", "C"]])
    }

    func testLongChainSplitsIntoTightGroups() {
        // 10 张逐渐变化的照片：单链接会连成一长串，完全连接下每组任意两张都必须相似
        let entries = (0..<10).map { i in
            HashEntry(id: "p\(i)", hash: UInt64(i) * 0x1111_1111_1111_1111, time: Double(i) * 5,
                      feature: unit([1, Float(i) * 0.2, 0]), labels: ["beach"])
        }
        let groups = SimilarityGrouper.groups(entries)
        XCTAssertGreaterThan(groups.count, 1)
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for g in groups {
            for x in g { for y in g where x < y {
                XCTAssertNotNil(SimilarityGrouper.link(byID[x]!, byID[y]!), "\(x)–\(y) 不相似却在同一组")
            } }
        }
    }

    func testDifferentSubjectNotGrouped() {
        // 同一时间、特征 0.29，但标签完全不同、dHash 差很多 → 不算相似
        let a = HashEntry(id: "a", hash: 0, time: 0, feature: unit([1, 0, 0]), labels: ["food", "plate"])
        let b = HashEntry(id: "b", hash: far, time: 10, feature: unit([1, 0.3, 0]), labels: ["cat", "sofa"])
        XCTAssertNil(SimilarityGrouper.link(a, b))
        // 标签不知道时，dHash ≤ 16 也能证明主体一致
        let c = HashEntry(id: "c", hash: 0xFFFF, time: 10, feature: unit([1, 0.3, 0]))
        XCTAssertNotNil(SimilarityGrouper.link(HashEntry(id: "a0", hash: 0, time: 0, feature: unit([1, 0, 0])), c))
    }

    func testTimeWindowAndFeatureThreshold() {
        let a = HashEntry(id: "a", hash: 0, time: 0, feature: unit([1, 0, 0]), labels: ["dog"])
        // 0.29：在 90 秒内算相似，超过 90 秒不算
        XCTAssertNotNil(SimilarityGrouper.link(a, HashEntry(id: "b", hash: far, time: 85, feature: unit([1, 0.3, 0]), labels: ["dog"])))
        XCTAssertNil(SimilarityGrouper.link(a, HashEntry(id: "c", hash: far, time: 100, feature: unit([1, 0.3, 0]), labels: ["dog"])))
        // 0.39：以前 0.45 会算，现在不算
        XCTAssertNil(SimilarityGrouper.link(a, HashEntry(id: "d", hash: far, time: 10, feature: unit([1, 0.41, 0]), labels: ["dog"])))
    }

    func testAspectRatioMismatchNotGroupedUnlessDuplicate() {
        // 截图（19.5:9 ≈ 2.17）和照片（4:3 ≈ 1.33）：比例差 1.63 倍
        let shot = HashEntry(id: "s", hash: 0, time: 0, feature: unit([1, 0, 0]), aspect: 2.17, labels: ["text"])
        let photo = HashEntry(id: "p", hash: far, time: 5, feature: unit([1, 0.3, 0]), aspect: 1.33, labels: ["text"])
        XCTAssertNil(SimilarityGrouper.link(shot, photo))
        // 但重复图（特征几乎一样）不看比例
        let dup = HashEntry(id: "d", hash: far, time: 5, feature: unit([1, 0.05, 0]), aspect: 1.33)
        XCTAssertNotNil(SimilarityGrouper.link(shot, dup))
        XCTAssertEqual(HashEntry.aspect(width: 1170, height: 2532)!, 2.164, accuracy: 0.01)
    }

    func testFaceCountDifference() {
        let a = HashEntry(id: "a", hash: 0, time: 0, feature: unit([1, 0, 0]), labels: ["people"], faces: 1)
        XCTAssertNotNil(SimilarityGrouper.link(a, HashEntry(id: "b", hash: far, time: 5, feature: unit([1, 0.3, 0]), labels: ["people"], faces: 2)))
        XCTAssertNil(SimilarityGrouper.link(a, HashEntry(id: "c", hash: far, time: 5, feature: unit([1, 0.3, 0]), labels: ["people"], faces: 3)))
    }

    func testNotSimilarExclusion() {
        let a = HashEntry(id: "a", hash: 0, time: 0, feature: unit([1, 0, 0]))
        let b = HashEntry(id: "b", hash: 1, time: 5, feature: unit([1, 0, 0]))
        let c = HashEntry(id: "c", hash: 3, time: 8, feature: unit([1, 0, 0]))
        XCTAssertEqual(SimilarityGrouper.groups([a, b, c]), [["a", "b", "c"]])
        // 用户把 c 从 {a, b, c} 里移出：记下 c–a、c–b
        let ex: Set<String> = [PairKey.make("c", "a"), PairKey.make("c", "b")]
        XCTAssertEqual(SimilarityGrouper.groups([a, b, c], excluded: ex), [["a", "b"]])
        XCTAssertEqual(SimilarityGrouper.groupsReference([a, b, c], excluded: ex), [["a", "b"]])
        XCTAssertEqual(PairKey.make("b", "a"), "a|b")
        XCTAssertEqual(PairKey.ids("a|b")?.1, "b")
    }

    func testSubjectLabelsAndJaccard() {
        let l = VisionRules.subjectLabels([("dog", 0.9), ("grass", 0.5), ("x", 0.2), ("a", 0.31), ("b", 0.4), ("c", 0.35), ("d", 0.33)])
        XCTAssertEqual(l, ["dog", "grass", "b", "c", "d"])
        XCTAssertEqual(SimilarityGrouper.jaccard(["a", "b"], ["b", "c"]), 1.0 / 3, accuracy: 0.001)
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
        let t = VisionRules.tags(labels: [("food", 0.9), ("dog", 0.3), ("receipt", 0.7), ("unknown_xyz", 0.5)], hasQR: true)
        XCTAssertEqual(t, [.food, .document, .qrCode])
        // 有人物时不算风景
        XCTAssertFalse(VisionRules.tags(labels: [("mountain", 0.9), ("people", 0.8)], hasQR: false).contains(.scenery))
        XCTAssertTrue(VisionRules.tags(labels: [("mountain", 0.9)], hasQR: false).contains(.scenery))
    }

    func testStricterContentTags() {
        // 宠物：0.65 不够 0.7
        XCTAssertFalse(VisionRules.tags(labels: [("dog", 0.65)], hasQR: false).contains(.pet))
        // 宠物 0.8，但最主要的是车（0.9）→ 不算宠物
        XCTAssertFalse(VisionRules.tags(labels: [("car", 0.9), ("dog", 0.8)], hasQR: false).contains(.pet))
        // animal / mammal 这类大类排在前面不影响
        XCTAssertTrue(VisionRules.tags(labels: [("animal", 0.95), ("mammal", 0.94), ("dog", 0.9)], hasQR: false).contains(.pet))
        // 美食同理
        XCTAssertFalse(VisionRules.tags(labels: [("food", 0.69)], hasQR: false).contains(.food))
        XCTAssertFalse(VisionRules.tags(labels: [("person", 0.95), ("dessert", 0.8)], hasQR: false).contains(.food))
        // 文档：0.55 不够 0.6，文字多时 0.5 就够
        XCTAssertFalse(VisionRules.tags(labels: [("receipt", 0.55)], hasQR: false).contains(.document))
        XCTAssertTrue(VisionRules.tags(labels: [("receipt", 0.55)], hasQR: false, textHeavy: true).contains(.document))
        // 二维码只看条码识别
        XCTAssertFalse(VisionRules.tags(labels: [("qr_code", 0.99), ("barcode", 0.99)], hasQR: false).contains(.qrCode))
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
