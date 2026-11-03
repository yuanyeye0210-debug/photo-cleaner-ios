import XCTest
#if canImport(PhotoCleaner)
@testable import PhotoCleaner
#else
@testable import CleanCore
#endif

/// 缓存、分组索引、统计、删除结果、小批量模式等纯逻辑测试
final class CleanLogicTests: XCTestCase {

    // MARK: 量化特征

    func testQuantizedDistanceMatchesFloat() {
        let a = VisionRules.normalized([1, 0.2, 0.1, -0.4])!
        let b = VisionRules.normalized([0.9, 0.3, 0.0, -0.3])!
        let qa = QFeature(normalized: a)!, qb = QFeature(normalized: b)!
        XCTAssertEqual(qa.distance(to: qb), VisionRules.distance(a, b), accuracy: 0.02)
        XCTAssertEqual(qa.distance(to: qa), 0, accuracy: 1e-6)
        XCTAssertNil(QFeature(normalized: []))
    }

    // MARK: 分析缓存

    func testCacheKeyedByModificationDate() {
        let cache = AnalysisCache()
        let d1 = Date(timeIntervalSince1970: 1000), d2 = Date(timeIntervalSince1970: 2000)
        var r = AnalysisResult(dHash: 42, sharpness: 10, brightness: 100)
        r.tags = [.qrCode]
        r.verificationCode = "123456"
        cache.setResult(r, for: "a", modified: d1)
        cache.setSize(5000, liveVideoBytes: 1200, for: "a", modified: d1)
        XCTAssertEqual(cache.result(for: "a", modified: d1), r)
        XCTAssertEqual(cache.size(for: "a", modified: d1), 5000)
        // 照片被编辑过（修改时间变了）→ 视为没有缓存
        XCTAssertNil(cache.result(for: "a", modified: d2))
        // 用新修改时间写入会清掉旧数据
        cache.setSize(7000, liveVideoBytes: nil, for: "a", modified: d2)
        XCTAssertNil(cache.result(for: "a", modified: d2))
        XCTAssertEqual(cache.size(for: "a", modified: d2), 7000)
    }

    func testCacheRoundTripAndVersion() throws {
        let cache = AnalysisCache()
        var r = AnalysisResult(dHash: .max, sharpness: 1.5, brightness: 20)
        r.feature = QFeature(normalized: VisionRules.normalized([1, 2, 3])!)
        r.aesthetics = -0.5
        r.faceChecked = true
        r.faceQuality = 0.7
        cache.setResult(r, for: "x", modified: nil)
        cache.setResult(nil, for: "cloud", modified: nil, cloudOnly: true)
        let data = try cache.encode()
        XCTAssertFalse(cache.isDirty)
        let back = AnalysisCache.decode(data)
        XCTAssertEqual(back.count, 2)
        XCTAssertEqual(back.result(for: "x", modified: nil), r)
        XCTAssertEqual(back.entry(for: "cloud", modified: nil)?.cloudOnly, true)
        // 坏数据 = 空缓存
        XCTAssertEqual(AnalysisCache.decode(Data([1, 2, 3])).count, 0)
    }

    func testCachePrune() {
        let cache = AnalysisCache()
        cache.setSize(1, liveVideoBytes: nil, for: "a", modified: nil)
        cache.setSize(1, liveVideoBytes: nil, for: "b", modified: nil)
        cache.prune(keeping: ["a"])
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.size(for: "a", modified: nil))
    }

    func testPlannerOnlyAnalyzesMissing() {
        let cache = AnalysisCache()
        cache.setResult(AnalysisResult(dHash: 1, sharpness: 1, brightness: 1), for: "done", modified: nil)
        cache.setResult(nil, for: "cloud", modified: nil, cloudOnly: true)
        let assets: [AnalysisPlanner.Asset] = [
            .init(id: "new", modified: nil, analyzable: true),
            .init(id: "done", modified: nil, analyzable: true),
            .init(id: "cloud", modified: nil, analyzable: true),
            .init(id: "video", modified: nil, analyzable: false),
        ]
        let p = AnalysisPlanner.plan(assets, cache: cache, skipCloudOnly: true)
        XCTAssertEqual(p.todo, ["new"])
        XCTAssertEqual(Set(p.cached.keys), ["done"])
        XCTAssertEqual(p.cloudOnly, ["cloud"])
        // 打开「允许从 iCloud 下载」后重试
        XCTAssertEqual(AnalysisPlanner.plan(assets, cache: cache, skipCloudOnly: false).todo, ["new", "cloud"])
    }

    // MARK: 分组索引

    func testBandIndexFindsAllPairsWithinSevenBits() {
        var rng = SplitMix(seed: 7)
        var hashes: [UInt64] = []
        for _ in 0..<60 {
            let base = rng.next()
            hashes.append(base)
            // 随机翻转 1~7 位
            var h = base
            let flips = Int(rng.next() % 7) + 1
            for _ in 0..<flips { h ^= 1 << (rng.next() % 64) }
            hashes.append(h)
        }
        let pairs = Set(BandIndex(hashes: hashes).candidatePairs(hashes: hashes).map { "\($0.0)-\($0.1)" })
        for i in stride(from: 0, to: hashes.count, by: 2) {
            XCTAssertTrue(pairs.contains("\(i)-\(i + 1)"), "pair \(i) missed")
        }
    }

    func testFastGroupingMatchesReference() {
        var rng = SplitMix(seed: 11)
        var entries: [HashEntry] = []
        var t: TimeInterval = 0
        for i in 0..<400 {
            let base = rng.next()
            t += Double(rng.next() % 900)
            let f = VisionRules.normalized((0..<16).map { _ in Float(rng.next() % 1000) / 1000 - 0.5 })
            entries.append(HashEntry(id: "p\(i)", hash: base, time: t, feature: f))
            if i % 5 == 0 {
                // 连拍：时间近、哈希近
                var h = base
                for _ in 0..<5 { h ^= 1 << (rng.next() % 64) }
                entries.append(HashEntry(id: "p\(i)b", hash: h, time: t + 20, feature: f))
            }
            if i % 7 == 0 {
                // 跨时间的重复：哈希差 ≤ 6 位
                var h = base
                for _ in 0..<6 { h ^= 1 << (rng.next() % 64) }
                entries.append(HashEntry(id: "p\(i)d", hash: h, time: t + 5_000_000, feature: f))
            }
        }
        let fast = SimilarityGrouper.groups(entries)
        let ref = SimilarityGrouper.groupsReference(entries)
        XCTAssertFalse(ref.isEmpty)
        XCTAssertEqual(fast, ref)
    }

    func testBigBucketDoesNotExplode() {
        // 2000 张哈希一模一样的（比如纯黑照片）：仍然分成一组，且不会卡住
        let entries = (0..<2000).map { HashEntry(id: String(format: "k%04d", $0), hash: 0, time: Double($0) * 10_000) }
        let g = SimilarityGrouper.groups(entries)
        XCTAssertEqual(g.count, 1)
        XCTAssertEqual(g[0].count, 2000)
    }

    // MARK: 删除结果

    func testDeleteOutcome() {
        let ok = DeleteOutcome.make(requested: ["a", "b", "c"], stillExisting: ["b"], cancelled: false)
        XCTAssertEqual(ok.deleted, ["a", "c"])
        XCTAssertEqual(ok.failed, ["b"])
        XCTAssertFalse(ok.cancelled)
        let c = DeleteOutcome.make(requested: ["a"], stillExisting: ["a"], cancelled: true)
        XCTAssertTrue(c.cancelled)
        XCTAssertTrue(c.deleted.isEmpty && c.failed.isEmpty)
    }

    func testDecisionStatePruneAndRoundTrip() throws {
        var s = DecisionState()
        s.toDelete = ["a", "gone"]; s.kept = ["b"]; s.later = ["c", "gone2"]; s.cleanedMonths = ["2026-11"]
        s.prune(existing: ["a", "b", "c"])
        XCTAssertEqual(s.toDelete, ["a"]); XCTAssertEqual(s.later, ["c"])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dec-\(UUID().uuidString).json")
        try s.save(to: url)
        XCTAssertEqual(DecisionState.load(from: url), s)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: 统计

    func testStatsDailyAndTotals() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        var s = CleanupStats()
        s.record(.deleted, count: 3, bytes: 300, at: now)
        s.record(.deleted, count: 1, bytes: 100, at: now.addingTimeInterval(-86_400))
        s.record(.compressed, count: 1, bytes: 50, at: now.addingTimeInterval(-40 * 86_400))
        s.record(.deleted, count: 0, bytes: 0, at: now)   // 空记录忽略
        XCTAssertEqual(s.events.count, 3)
        XCTAssertEqual(s.totalBytes, 450)
        XCTAssertEqual(s.totalCount, 5)
        let days = s.daily(days: 30, now: now, calendar: cal)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.last?.bytes, 300)
        XCTAssertEqual(days[28].bytes, 100)
        XCTAssertEqual(s.bytes(lastDays: 30, now: now, calendar: cal), 400)
    }

    func testStatsCapKeepsTotals() {
        var s = CleanupStats()
        for i in 0..<(CleanupStats.maxEvents + 10) {
            s.record(.deleted, count: 1, bytes: 10, at: Date(timeIntervalSince1970: Double(i)))
        }
        XCTAssertEqual(s.events.count, CleanupStats.maxEvents)
        XCTAssertEqual(s.totalCount, CleanupStats.maxEvents + 10)
        XCTAssertEqual(s.totalBytes, Int64(CleanupStats.maxEvents + 10) * 10)
    }

    // MARK: 小批量

    func testOnThisDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day, hour: 12))!
        }
        let today = d(2026, 11, 4)
        let entries: [(id: String, date: Date?)] = [
            ("y2020", d(2020, 11, 4)), ("y2024", d(2024, 11, 4)), ("today", d(2026, 11, 4)),
            ("other", d(2024, 11, 5)), ("nodate", nil),
        ]
        XCTAssertEqual(BatchModes.onThisDay(entries, today: today, calendar: cal), ["y2024", "y2020"])
    }

    func testRandomIsSubset() {
        var g = SplitMix(seed: 3)
        let ids = (0..<50).map { "i\($0)" }
        let r = BatchModes.random(ids, count: 10, using: &g)
        XCTAssertEqual(r.count, 10)
        XCTAssertEqual(Set(r).count, 10)
        XCTAssertTrue(Set(r).isSubset(of: Set(ids)))
        XCTAssertEqual(BatchModes.random(["a"], count: 10).count, 1)
    }

    // MARK: 重复 / 连拍

    func testExactDuplicates() {
        let c: [ExactDuplicates.Candidate] = [
            .init(id: "a", width: 10, height: 10, size: 100),
            .init(id: "b", width: 10, height: 10, size: 100),
            .init(id: "c", width: 10, height: 10, size: 101),
            .init(id: "z", width: 10, height: 10, size: 0),
            .init(id: "y", width: 10, height: 10, size: 0),
        ]
        XCTAssertEqual(ExactDuplicates.buckets(c), [["a", "b"]])
        XCTAssertEqual(ExactDuplicates.groups(digests: ["a": "h1", "b": "h1", "c": "h2"]), [["a", "b"]])
        let sim = ExactDuplicates.subtract([["a", "b", "x"], ["a", "b"]], exact: [["a", "b"]], keeper: { $0.first })
        XCTAssertEqual(sim, [["a", "x"]])
    }

    func testBurstKeeper() {
        typealias F = BurstRules.Frame
        XCTAssertEqual(BurstRules.keeper([F(id: "1", userPick: false, autoPick: true, representative: true),
                                          F(id: "2", userPick: true, autoPick: false, representative: false)]), "2")
        XCTAssertEqual(BurstRules.keeper([F(id: "1", userPick: false, autoPick: false, representative: false),
                                          F(id: "2", userPick: false, autoPick: false, representative: true)]), "2")
        XCTAssertNil(BurstRules.keeper([]))
    }

    // MARK: 其他

    func testDeepLinkRoundTrip() {
        for l in [DeepLink.home, .review, .category("screenshots"), .quick("onThisDay")] {
            XCTAssertEqual(DeepLink(url: l.url), l)
        }
        XCTAssertNil(DeepLink(url: URL(string: "https://example.com")!))
    }

    func testWidgetSnapshotCoding() {
        let s = WidgetSnapshot(cleanableCount: 3, cleanableBytes: 9, screenshots: 2, pending: 1, freedTotal: 5,
                               updated: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(WidgetSnapshot.decode(s.encoded()), s)
        XCTAssertNil(WidgetSnapshot.decode(nil))
    }

    func testVerificationCodeVariants() {
        XCTAssertEqual(VisionRules.verificationCode(in: ["【某银行】您的验证码是 482913，5分钟内有效"]), "482913")
        XCTAssertEqual(VisionRules.verificationCode(in: ["Your verification code: 7781"]), "7781")
        XCTAssertNil(VisionRules.verificationCode(in: ["订单号 20261104123456"]))
        XCTAssertNil(VisionRules.verificationCode(in: ["验证码 12"]))
        XCTAssertNil(VisionRules.verificationCode(in: ["动态码 123456789"]))
    }

    func testFileSizeEstimate() {
        XCTAssertEqual(FileSizes.estimate(pixelWidth: 300, pixelHeight: 100, isVideo: false, duration: 0), 10_000)
        XCTAssertEqual(FileSizes.estimate(pixelWidth: 0, pixelHeight: 0, isVideo: true, duration: 10), 15_000_000)
        XCTAssertEqual(FileSizes.estimatedHEVCSavings(1000), 400)
    }
    func testDeleteWholeGroupSkipsFavoritesAndKeepsNoKeeper() {
        let fav: Set<String> = ["b"]
        XCTAssertEqual(GroupActions.deleteAll(["a", "b", "c"]) { fav.contains($0) }, ["a", "c"])
        XCTAssertEqual(GroupActions.deleteAll(["a", "c"]) { _ in false }, ["a", "c"])
        XCTAssertTrue(GroupActions.deleteAll(["b"]) { fav.contains($0) }.isEmpty)
    }
}

/// 可复现的随机数（测试用）
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
