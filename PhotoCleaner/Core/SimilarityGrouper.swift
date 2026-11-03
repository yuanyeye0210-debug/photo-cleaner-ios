import Foundation

/// 相似照片分组。
/// 第一步找「可能相似」的配对（时间窗口内两两比较 + 跨时间用 BandIndex 找重复图），
/// 第二步用「完全连接」合并：一组里任意两张都必须彼此相似，避免 A 像 B、B 像 C 就把 A、C 也拉进来（链式误分组）。
///
/// 两张照片算相似（linkable）的规则（dHash 汉明距离 d，AI 特征距离 f，0~2）：
///  - 用户点过「不是相似」的配对：永远不算
///  - d <= strictThreshold(4)：几乎一模一样（重复图），不论时间、比例
///  - 两张都有 AI 特征：
///      · 重复图：f <= featureDup(0.25)，并且时间相近或 d <= dupPrefilter(20)（不看比例）
///      · 同一场景（连拍 / 换角度）：拍摄时间相差 <= timeWindow(90 秒)、f <= featureNear(0.32)、
///        长宽比相近（长边/短边之比相差 <= aspectRatioMax 1.4 倍）、人脸数相差 <= 1、
///        并且主体一致：识别标签（前 5 个、置信度 >= 0.3）Jaccard >= labelJaccard(0.25)，或 d <= subjectHash(16)
///  - 没有 AI 特征（老系统或分析失败）：时间相近、比例相近且 d <= looseThreshold(10)
struct HashEntry: Sendable {
    let id: String
    let hash: UInt64
    let time: TimeInterval?
    var feature: QFeature? = nil
    /// 长边/短边（>= 1）；nil = 不知道
    var aspect: Double? = nil
    /// 识别标签（前 5 个，置信度 >= 0.3）；nil 或空 = 不知道
    var labels: [String]? = nil
    /// 人脸数；nil = 不知道
    var faces: Int? = nil

    init(id: String, hash: UInt64, time: TimeInterval?, qfeature: QFeature?,
         aspect: Double? = nil, labels: [String]? = nil, faces: Int? = nil) {
        self.id = id; self.hash = hash; self.time = time; self.feature = qfeature
        self.aspect = aspect; self.labels = labels; self.faces = faces
    }

    /// 测试用：传入归一化 float 特征
    init(id: String, hash: UInt64, time: TimeInterval?, feature: [Float]? = nil,
         aspect: Double? = nil, labels: [String]? = nil, faces: Int? = nil) {
        self.init(id: id, hash: hash, time: time, qfeature: feature.flatMap { QFeature(normalized: $0) },
                  aspect: aspect, labels: labels, faces: faces)
    }

    /// 宽、高 → 长边/短边
    static func aspect(width: Int, height: Int) -> Double? {
        guard width > 0, height > 0 else { return nil }
        return Double(max(width, height)) / Double(min(width, height))
    }
}

/// 分组参数（iOS / Android 两边一致）
struct GroupingParams: Sendable {
    var strictThreshold = 4
    var looseThreshold = 10
    var timeWindow: TimeInterval = 90
    var featureNear: Float = 0.32
    var featureDup: Float = 0.25
    var dupPrefilter = 20
    var subjectHash = 16
    var labelJaccard: Double = 0.25
    var aspectRatioMax: Double = 1.4
    var maxFaceDiff = 1

    static let standard = GroupingParams()
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
    /// 两张标签的 Jaccard 相似度（交集/并集）
    static func jaccard(_ a: [String], _ b: [String]) -> Double {
        let x = Set(a), y = Set(b)
        let u = x.union(y).count
        return u == 0 ? 0 : Double(x.intersection(y).count) / Double(u)
    }

    /// 两张照片能不能放进同一组；返回 nil = 不能，否则返回「距离」（越小越像，用来决定合并顺序）
    static func link(_ a: HashEntry, _ b: HashEntry, _ p: GroupingParams = .standard) -> Float? {
        let d = ImageMath.hamming(a.hash, b.hash)
        if d <= p.strictThreshold { return Float(d) / 64 }
        var close = false
        if let x = a.time, let y = b.time, abs(x - y) <= p.timeWindow { close = true }
        var aspectOK = true
        if let x = a.aspect, let y = b.aspect, max(x, y) / max(min(x, y), 0.0001) > p.aspectRatioMax { aspectOK = false }
        if let fa = a.feature, let fb = b.feature {
            guard close || d <= p.dupPrefilter else { return nil }
            let f = fa.distance(to: fb)
            if f <= p.featureDup { return f }                       // 重复图（裁剪/压缩/存了两次）
            guard close, aspectOK, f <= p.featureNear else { return nil }
            if let x = a.faces, let y = b.faces, abs(x - y) > p.maxFaceDiff { return nil }
            var subject = d <= p.subjectHash
            if !subject, let la = a.labels, let lb = b.labels, !la.isEmpty, !lb.isEmpty {
                subject = jaccard(la, lb) >= p.labelJaccard
            }
            return subject ? f : nil
        }
        return close && aspectOK && d <= p.looseThreshold ? Float(d) / 64 : nil
    }

    /// 快速版：
    ///  1. 按拍摄时间排序，只在 timeWindow 秒内的照片之间两两比较（连拍、换角度）
    ///  2. 时间不近的「重复图」用 BandIndex 找候选：dHash ≤ 7 位一定能找到，更大的差距大多也能找到
    ///  3. 完全连接合并（见 merge）
    static func groups(_ entries: [HashEntry], params p: GroupingParams = .standard,
                       excluded: Set<String> = []) -> [[String]] {
        let n = entries.count
        guard n > 1 else { return [] }
        var edges: [(Float, Int, Int)] = []
        func consider(_ i: Int, _ j: Int) {
            let (x, y) = i < j ? (i, j) : (j, i)
            if !excluded.isEmpty && excluded.contains(PairKey.make(entries[x].id, entries[y].id)) { return }
            if let w = link(entries[x], entries[y], p) { edges.append((w, x, y)) }
        }
        // 1. 时间窗口
        let timed = (0..<n).compactMap { i in entries[i].time.map { (i, $0) } }.sorted { $0.1 < $1.1 }
        for x in 0..<timed.count {
            var y = x + 1
            while y < timed.count, timed[y].1 - timed[x].1 <= p.timeWindow {
                consider(timed[x].0, timed[y].0)
                y += 1
            }
        }
        // 2. 跨时间的重复图（只看时间不近的配对，近的上面已经比过）
        let hashes = entries.map(\.hash)
        for (i, j) in BandIndex(hashes: hashes).candidatePairs(hashes: hashes) {
            if let a = entries[i].time, let b = entries[j].time, abs(a - b) <= p.timeWindow { continue }
            consider(i, j)
        }
        return merge(entries, edges: edges, params: p, excluded: excluded)
    }

    /// 逐对比较的参考实现（O(n²)，只用于测试对照）
    static func groupsReference(_ entries: [HashEntry], params p: GroupingParams = .standard,
                                excluded: Set<String> = []) -> [[String]] {
        let n = entries.count
        guard n > 1 else { return [] }
        var edges: [(Float, Int, Int)] = []
        for i in 0..<(n - 1) {
            for j in (i + 1)..<n {
                if !excluded.isEmpty && excluded.contains(PairKey.make(entries[i].id, entries[j].id)) { continue }
                if let w = link(entries[i], entries[j], p) { edges.append((w, i, j)) }
            }
        }
        return merge(entries, edges: edges, params: p, excluded: excluded)
    }

    /// 完全连接合并：按距离从小到大处理配对，两组只有在「所有跨组配对都相似」时才合并。
    /// 所以每组里任意两张都彼此相似，不会出现链式误分组。
    static func merge(_ entries: [HashEntry], edges: [(Float, Int, Int)], params p: GroupingParams,
                      excluded: Set<String>) -> [[String]] {
        let sorted = edges.sorted { ($0.0, $0.1, $0.2) < ($1.0, $1.1, $1.2) }
        var cluster = Array(0..<entries.count)
        var members: [Int: [Int]] = [:]
        func ok(_ i: Int, _ j: Int) -> Bool {
            if !excluded.isEmpty && excluded.contains(PairKey.make(entries[i].id, entries[j].id)) { return false }
            return link(entries[i], entries[j], p) != nil
        }
        for (_, i, j) in sorted {
            let ci = cluster[i], cj = cluster[j]
            if ci == cj { continue }
            let a = members[ci] ?? [ci], b = members[cj] ?? [cj]
            var all = true
            outer: for x in a {
                for y in b where !ok(x, y) { all = false; break outer }
            }
            guard all else { continue }
            let (keep, drop) = a.count >= b.count ? (ci, cj) : (cj, ci)
            let moved = members[drop] ?? [drop]
            for m in moved { cluster[m] = keep }
            members[keep] = (members[keep] ?? [keep]) + moved
            members[drop] = nil
        }
        return members.values
            .filter { $0.count > 1 }
            .map { $0.map { entries[$0].id }.sorted() }
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
