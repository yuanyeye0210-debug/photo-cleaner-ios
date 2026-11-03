import Foundation

/// 相似照片分组（并查集）。
/// 规则（dHash 汉明距离 d，AI 特征距离 f，特征向量已归一化，f 范围 0~2）：
///  - d <= strictThreshold(4)：几乎一模一样（重复图），不论拍摄时间
///  - 两张都有 AI 特征时：
///      · 拍摄时间相差 <= timeWindow(180 秒) 且 f <= featureNear(0.45)：同一场景的连拍 / 换了角度的相似照片
///      · 时间不近，但 d <= dupPrefilter(20，用便宜的 dHash 先筛一遍) 且 f <= featureDup(0.25)：
///        裁剪、压缩、保存了两次的重复图
///  - 没有 AI 特征时（老系统或分析失败）：d <= looseThreshold(10) 且时间相近，与以前一样
struct HashEntry: Sendable {
    let id: String
    let hash: UInt64
    let time: TimeInterval?
    var feature: QFeature? = nil

    init(id: String, hash: UInt64, time: TimeInterval?, qfeature: QFeature?) {
        self.id = id; self.hash = hash; self.time = time; self.feature = qfeature
    }

    /// 测试用：传入归一化 float 特征
    init(id: String, hash: UInt64, time: TimeInterval?, feature: [Float]? = nil) {
        self.init(id: id, hash: hash, time: time, qfeature: feature.flatMap { QFeature(normalized: $0) })
    }
}

/// 64 位哈希按 8 段、每段 8 位建索引。
/// 鸽笼原理：两个哈希相差 ≤ 7 位时，最多弄脏 7 段，至少有 1 段完全相同 → 一定能被找到。
/// 相差更多位的也常常能找到（只要有一段没变），但不保证。
struct BandIndex {
    static let bandCount = 8
    static let bigBucket = 400
    static let bigBucketNeighbors = 40
    private var buckets: [[UInt64: [Int]]]

    init(hashes: [UInt64]) {
        buckets = Array(repeating: [:], count: Self.bandCount)
        for (i, h) in hashes.enumerated() {
            for b in 0..<Self.bandCount {
                buckets[b][Self.band(b, of: h), default: []].append(i)
            }
        }
    }

    @inline(__always) static func band(_ b: Int, of h: UInt64) -> UInt64 {
        (h >> UInt64(b * 8)) & 0xFF
    }

    /// 所有至少有一段相同的配对 (i < j)，每对只出现一次
    func candidatePairs(hashes: [UInt64]) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        var seen = Set<UInt64>()
        for b in 0..<Self.bandCount {
            for (_, raw) in buckets[b] where raw.count > 1 {
                // 一段相同的照片特别多（比如大量纯黑照片）时，按完整哈希排序后只和相邻的比，避免配对数爆炸
                let big = raw.count > Self.bigBucket
                let list = big ? raw.sorted { hashes[$0] < hashes[$1] } : raw
                for x in 0..<(list.count - 1) {
                    let upper = big ? min(list.count, x + 1 + Self.bigBucketNeighbors) : list.count
                    for y in (x + 1)..<upper {
                        let i = list[x], j = list[y]
                        let key = UInt64(min(i, j)) << 32 | UInt64(max(i, j))
                        if seen.insert(key).inserted { out.append((min(i, j), max(i, j))) }
                    }
                }
            }
        }
        return out
    }
}

/// 挑「推荐保留」用的指标
struct BestCandidate: Sendable {
    var faceQuality: Float? = nil   // 人脸拍摄质量 0~1（没人脸为 nil）
    var aesthetics: Float? = nil    // 美观评分 -1~1（iOS 18 以上才有）
    var sharpness: Double
    var pixels: Int
}

enum SimilarityGrouper {
    /// 快速版：
    ///  1. 按拍摄时间排序，只在 timeWindow 秒内的照片之间两两比较（连拍、换角度）
    ///  2. 时间不近的「重复图」用 BandIndex 找候选：dHash ≤ 7 位一定能找到，更大的差距大多也能找到
    /// 结果和逐对比较（groupsReference）在「时间相近」和「dHash ≤ 7」的情况下完全一致。
    static func groups(_ entries: [HashEntry],
                       strictThreshold: Int = 4,
                       looseThreshold: Int = 10,
                       timeWindow: TimeInterval = 180,
                       featureNear: Float = 0.45,
                       featureDup: Float = 0.25,
                       dupPrefilter: Int = 20) -> [[String]] {
        let n = entries.count
        guard n > 1 else { return [] }
        var uf = UnionFind(n)

        func test(_ i: Int, _ j: Int, close: Bool) {
            let a = entries[i], b = entries[j]
            let d = ImageMath.hamming(a.hash, b.hash)
            if d <= strictThreshold { uf.union(i, j); return }
            if let fa = a.feature, let fb = b.feature {
                guard close || d <= dupPrefilter else { return }
                let f = fa.distance(to: fb)
                if (close && f <= featureNear) || f <= featureDup { uf.union(i, j) }
            } else if close && d <= looseThreshold {
                uf.union(i, j)
            }
        }

        // 1. 时间窗口
        let timed = (0..<n).compactMap { i in entries[i].time.map { (i, $0) } }.sorted { $0.1 < $1.1 }
        for x in 0..<timed.count {
            var y = x + 1
            while y < timed.count, timed[y].1 - timed[x].1 <= timeWindow {
                test(timed[x].0, timed[y].0, close: true)
                y += 1
            }
        }

        // 2. 跨时间的重复图（只看时间不近的配对，近的上面已经比过）
        let hashes = entries.map(\.hash)
        for (i, j) in BandIndex(hashes: hashes).candidatePairs(hashes: hashes) {
            if let a = entries[i].time, let b = entries[j].time, abs(a - b) <= timeWindow { continue }
            test(i, j, close: false)
        }

        return collect(entries, &uf)
    }

    /// 逐对比较的参考实现（O(n²)，只用于测试对照）
    static func groupsReference(_ entries: [HashEntry],
                                strictThreshold: Int = 4,
                                looseThreshold: Int = 10,
                                timeWindow: TimeInterval = 180,
                                featureNear: Float = 0.45,
                                featureDup: Float = 0.25,
                                dupPrefilter: Int = 20) -> [[String]] {
        let n = entries.count
        guard n > 1 else { return [] }
        var uf = UnionFind(n)
        for i in 0..<(n - 1) {
            for j in (i + 1)..<n {
                let d = ImageMath.hamming(entries[i].hash, entries[j].hash)
                if d <= strictThreshold { uf.union(i, j); continue }
                var close = false
                if let a = entries[i].time, let b = entries[j].time, abs(a - b) <= timeWindow { close = true }
                if let fa = entries[i].feature, let fb = entries[j].feature {
                    guard close || d <= dupPrefilter else { continue }
                    let f = fa.distance(to: fb)
                    if (close && f <= featureNear) || f <= featureDup { uf.union(i, j) }
                } else if close && d <= looseThreshold {
                    uf.union(i, j)
                }
            }
        }
        return collect(entries, &uf)
    }

    private static func collect(_ entries: [HashEntry], _ uf: inout UnionFind) -> [[String]] {
        var buckets: [Int: [String]] = [:]
        for i in 0..<entries.count {
            buckets[uf.find(i), default: []].append(entries[i].id)
        }
        return buckets.values
            .filter { $0.count > 1 }
            .map { $0.sorted() }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0[0] < $1[0] }
    }

    /// 选出一组里最值得保留的：清晰度最高，其次分辨率/文件更大
    static func bestIndex(sharpness: [Double], pixels: [Int]) -> Int {
        bestIndex(zip(sharpness, pixels).map { BestCandidate(sharpness: $0, pixels: $1) })
    }

    /// 推荐保留：人脸质量最好（没闭眼、表情好）→ 美观评分最高 → 最清晰 → 分辨率最高。
    /// 每一级只有差距明显时才决定，差不多就看下一级。
    static func bestIndex(_ c: [BestCandidate]) -> Int {
        guard !c.isEmpty else { return 0 }
        var best = 0
        for i in 1..<c.count where isBetter(c[i], than: c[best]) {
            best = i
        }
        return best
    }

    static func isBetter(_ a: BestCandidate, than b: BestCandidate) -> Bool {
        // 1. 人脸质量（有人脸的优先于没检测到人脸的）
        switch (a.faceQuality, b.faceQuality) {
        case let (x?, y?) where abs(x - y) > 0.05: return x > y
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        // 2. 美观评分
        if let x = a.aesthetics, let y = b.aesthetics, abs(x - y) > 0.1 { return x > y }
        // 3. 清晰度
        if a.sharpness > b.sharpness * 1.05 { return true }
        if b.sharpness > a.sharpness * 1.05 { return false }
        // 4. 分辨率
        return a.pixels > b.pixels
    }
}

/// 并查集
struct UnionFind {
    private var parent: [Int]
    init(_ n: Int) { parent = Array(0..<n) }

    mutating func find(_ i: Int) -> Int {
        var r = i
        while parent[r] != r { r = parent[r] }
        var c = i
        while parent[c] != r { let next = parent[c]; parent[c] = r; c = next }
        return r
    }

    mutating func union(_ a: Int, _ b: Int) {
        let ra = find(a), rb = find(b)
        if ra != rb { parent[rb] = ra }
    }
}
