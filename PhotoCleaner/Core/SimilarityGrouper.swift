import Foundation

/// 相似照片分组（并查集）。
/// 规则：
///  - 汉明距离 <= strictThreshold：几乎一模一样（重复图），不论拍摄时间
///  - 汉明距离 <= looseThreshold 且拍摄时间相差 <= timeWindow 秒：连拍 / 相似照片
struct HashEntry: Sendable {
    let id: String
    let hash: UInt64
    let time: TimeInterval?
}

enum SimilarityGrouper {
    static func groups(_ entries: [HashEntry],
                       strictThreshold: Int = 4,
                       looseThreshold: Int = 10,
                       timeWindow: TimeInterval = 180) -> [[String]] {
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
            for j in (i + 1)..<n {
                let d = ImageMath.hamming(hi, entries[j].hash)
                if d <= strictThreshold {
                    union(i, j)
                } else if d <= looseThreshold,
                          let a = ti, let b = entries[j].time,
                          abs(a - b) <= timeWindow {
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
        guard !sharpness.isEmpty else { return 0 }
        var best = 0
        for i in 1..<sharpness.count {
            if sharpness[i] > sharpness[best] * 1.05 ||
                (abs(sharpness[i] - sharpness[best]) <= sharpness[best] * 0.05 && pixels[i] > pixels[best]) {
                best = i
            }
        }
        return best
    }
}
