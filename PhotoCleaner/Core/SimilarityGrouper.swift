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
    var feature: [Float]? = nil
}

/// 挑「推荐保留」用的指标
struct BestCandidate: Sendable {
    var faceQuality: Float? = nil   // 人脸拍摄质量 0~1（没人脸为 nil）
    var aesthetics: Float? = nil    // 美观评分 -1~1（iOS 18 以上才有）
    var sharpness: Double
    var pixels: Int
}

enum SimilarityGrouper {
    static func groups(_ entries: [HashEntry],
                       strictThreshold: Int = 4,
                       looseThreshold: Int = 10,
                       timeWindow: TimeInterval = 180,
                       featureNear: Float = 0.45,
                       featureDup: Float = 0.25,
                       dupPrefilter: Int = 20) -> [[String]] {
        let n = entries.count
        guard n > 1 else { return [] }
        var parent = Array(0..<n)

        func find(_ i: Int) -> Int {
            var r = i
            while parent[r] != r { r = parent[r] }
            var c = i
            while parent[c] != r { let next = parent[c]; parent[c] = r; c = next }
            return r
        }
        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[rb] = ra }
        }

        for i in 0..<(n - 1) {
            let hi = entries[i].hash
            let ti = entries[i].time
            let fi = entries[i].feature
            for j in (i + 1)..<n {
                let d = ImageMath.hamming(hi, entries[j].hash)
                if d <= strictThreshold {
                    union(i, j)
                    continue
                }
                var close = false
                if let a = ti, let b = entries[j].time, abs(a - b) <= timeWindow { close = true }
                if let fa = fi, let fb = entries[j].feature {
                    guard close || d <= dupPrefilter else { continue }
                    let f = VisionRules.distance(fa, fb)
                    if (close && f <= featureNear) || f <= featureDup {
                        union(i, j)
                    }
                } else if close && d <= looseThreshold {
                    union(i, j)
                }
            }
        }

        var buckets: [Int: [String]] = [:]
        for i in 0..<n {
            buckets[find(i), default: []].append(entries[i].id)
        }
        return buckets.values
            .filter { $0.count > 1 }
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
