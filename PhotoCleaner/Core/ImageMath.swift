import Foundation

/// 8 位灰度图（纯数据结构，不依赖 UIKit，便于单元测试）
struct GrayImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height, "像素数量与尺寸不匹配")
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    @inline(__always) func at(_ x: Int, _ y: Int) -> Int {
        Int(pixels[y * width + x])
    }
}

/// 图像分析的纯算法部分。
/// 参考：
///  - dHash 思路来自 JohannesBuchner/imagehash（Python 感知哈希库）与 jenssegers/imagehash
///  - 模糊检测（拉普拉斯方差）思路来自 WillBrennan/BlurDetection2 / OpenCV 常用做法
enum ImageMath {
    /// 差值哈希 dHash：输入必须是 9x8 的灰度图，比较每行相邻像素，得到 64 位哈希。
    static func dHash(_ img: GrayImage) -> UInt64 {
        precondition(img.width == 9 && img.height == 8, "dHash 需要 9x8 灰度图")
        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for y in 0..<8 {
            for x in 0..<8 {
                if img.at(x, y) > img.at(x + 1, y) {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }

    /// 两个哈希的汉明距离（不同的位数），越小越相似
    @inline(__always) static func hamming(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }

    /// 拉普拉斯方差：值越小图片越模糊。
    /// 卷积核 [0 1 0; 1 -4 1; 0 1 0]
    static func laplacianVariance(_ img: GrayImage) -> Double {
        let w = img.width, h = img.height
        guard w >= 3, h >= 3 else { return 0 }
        var sum = 0.0
        var sumSq = 0.0
        var n = 0.0
        img.pixels.withUnsafeBufferPointer { p in
            for y in 1..<(h - 1) {
                let row = y * w
                for x in 1..<(w - 1) {
                    let c = Int(p[row + x])
                    let v = Int(p[row + x - 1]) + Int(p[row + x + 1])
                        + Int(p[row - w + x]) + Int(p[row + w + x]) - 4 * c
                    let d = Double(v)
                    sum += d
                    sumSq += d * d
                    n += 1
                }
            }
        }
        let mean = sum / n
        return max(0, sumSq / n - mean * mean)
    }

    /// 平均亮度 0...255
    static func meanBrightness(_ img: GrayImage) -> Double {
        guard !img.pixels.isEmpty else { return 0 }
        var total = 0
        for p in img.pixels { total += Int(p) }
        return Double(total) / Double(img.pixels.count)
    }

    /// 等比缩放到最长边不超过 maxSide 后的尺寸
    static func fittedSize(width: Int, height: Int, maxSide: Int) -> (Int, Int) {
        guard width > 0, height > 0 else { return (1, 1) }
        let scale = min(1.0, Double(maxSide) / Double(max(width, height)))
        return (max(3, Int((Double(width) * scale).rounded())),
                max(3, Int((Double(height) * scale).rounded())))
    }
}
