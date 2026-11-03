import XCTest
#if canImport(PhotoCleaner)
@testable import PhotoCleaner
#else
@testable import CleanCore
#endif

/// 算法单元测试（同一份文件：iOS 上测 App 目标，Linux 上测 CleanCore 包）
final class ImageMathTests: XCTestCase {

    // 生成测试图片
    private func checkerboard(_ w: Int, _ h: Int, cell: Int = 4) -> GrayImage {
        var p = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { p[y * w + x] = ((x / cell + y / cell) % 2 == 0) ? 230 : 25 } }
        return GrayImage(width: w, height: h, pixels: p)
    }

    private func boxBlur(_ img: GrayImage, radius: Int) -> GrayImage {
        var out = img.pixels
        for y in 0..<img.height {
            for x in 0..<img.width {
                var s = 0, n = 0
                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let xx = x + dx, yy = y + dy
                        if xx >= 0, yy >= 0, xx < img.width, yy < img.height { s += img.at(xx, yy); n += 1 }
                    }
                }
                out[y * img.width + x] = UInt8(s / n)
            }
        }
        return GrayImage(width: img.width, height: img.height, pixels: out)
    }

    private func gradient9x8(reversed: Bool = false, offset: Int = 0) -> GrayImage {
        var p = [UInt8](repeating: 0, count: 72)
        for y in 0..<8 { for x in 0..<9 {
            let v = reversed ? (8 - x) * 20 : x * 20
            p[y * 9 + x] = UInt8(min(255, v + y * 3 + offset))
        } }
        return GrayImage(width: 9, height: 8, pixels: p)
    }

    func testHamming() {
        XCTAssertEqual(ImageMath.hamming(0, 0), 0)
        XCTAssertEqual(ImageMath.hamming(0, UInt64.max), 64)
        XCTAssertEqual(ImageMath.hamming(0b1011, 0b0001), 2)
    }

    func testDHashIdenticalAndBrightnessInvariant() {
        let a = ImageMath.dHash(gradient9x8())
        let b = ImageMath.dHash(gradient9x8(offset: 30)) // 整体变亮，结构不变
        XCTAssertEqual(ImageMath.hamming(a, b), 0)
    }

    func testDHashDifferentImages() {
        let a = ImageMath.dHash(gradient9x8())
        let c = ImageMath.dHash(gradient9x8(reversed: true))
        XCTAssertGreaterThan(ImageMath.hamming(a, c), 40)
    }

    func testLaplacianSharpVsBlurry() {
        let sharp = checkerboard(64, 64)
        let blurry = boxBlur(sharp, radius: 3)
        let vs = ImageMath.laplacianVariance(sharp)
        let vb = ImageMath.laplacianVariance(blurry)
        XCTAssertGreaterThan(vs, vb * 10, "清晰图的拉普拉斯方差应远大于模糊图 sharp=\(vs) blurry=\(vb)")
        let flat = GrayImage(width: 32, height: 32, pixels: [UInt8](repeating: 128, count: 1024))
        XCTAssertEqual(ImageMath.laplacianVariance(flat), 0, accuracy: 1e-9)
    }

    func testMeanBrightness() {
        let img = GrayImage(width: 2, height: 2, pixels: [0, 255, 0, 255])
        XCTAssertEqual(ImageMath.meanBrightness(img), 127.5, accuracy: 1e-9)
    }

    func testFittedSize() {
        let (w, h) = ImageMath.fittedSize(width: 4032, height: 3024, maxSide: 256)
        XCTAssertEqual(w, 256)
        XCTAssertEqual(h, 192)
        let (w2, h2) = ImageMath.fittedSize(width: 100, height: 50, maxSide: 256)
        XCTAssertEqual(w2, 100)
        XCTAssertEqual(h2, 50)
    }

    func testGrouping() {
        let base: UInt64 = 0xF0F0_F0F0_0F0F_0F0F
        let entries = [
            HashEntry(id: "a", hash: base, time: 1000),
            HashEntry(id: "b", hash: base ^ 0b111, time: 5_000_000),        // 距离 3：重复图，时间无关
            HashEntry(id: "c", hash: base ^ 0xFF, time: 1060),              // 距离 8：时间相近 -> 连拍
            HashEntry(id: "d", hash: base ^ 0xFF00, time: 9_000_000),       // 与 a 距离 8 但时间很远：不应合并
            HashEntry(id: "e", hash: ~base, time: 1001),                    // 完全不同
        ]
        // a–b 重复、a–c 连拍，但 b–c 不相似 → 完全连接下 c 不能进 {a, b}
        let groups = SimilarityGrouper.groups(entries)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), Set(["a", "b"]))
    }

    func testGroupingWithDistantPairDoesNotChain() {
        // d 与 c 汉明距离 0（重复），c 与 a 是连拍，但 a 与 d 既不近也不像 → 不会经过 c 把 a、d 连成一组
        let base: UInt64 = 0x1234_5678_9ABC_DEF0
        let entries = [
            HashEntry(id: "a", hash: base, time: 0),
            HashEntry(id: "c", hash: base ^ 0xFF, time: 30),
            HashEntry(id: "d", hash: base ^ 0xFF, time: 99_999),
        ]
        XCTAssertEqual(SimilarityGrouper.groups(entries), [["c", "d"]])
    }

    func testBestIndex() {
        XCTAssertEqual(SimilarityGrouper.bestIndex(sharpness: [10, 300, 120], pixels: [1, 1, 1]), 1)
        // 清晰度接近时选分辨率高的
        XCTAssertEqual(SimilarityGrouper.bestIndex(sharpness: [100, 102], pixels: [100, 400]), 1)
    }
}
