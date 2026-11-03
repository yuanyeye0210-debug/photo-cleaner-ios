import CoreGraphics
import Foundation

/// 把 CGImage 画成灰度小图后调用 ImageMath 计算
enum ImageAnalyzer {
    static func grayscale(_ cg: CGImage, width: Int, height: Int) -> GrayImage? {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let ok: Bool = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? GrayImage(width: width, height: height, pixels: pixels) : nil
    }

    static func analyze(_ cg: CGImage) -> AnalysisResult? {
        guard let tiny = grayscale(cg, width: 9, height: 8) else { return nil }
        let (w, h) = ImageMath.fittedSize(width: cg.width, height: cg.height, maxSide: 256)
        guard let small = grayscale(cg, width: w, height: h) else { return nil }
        return AnalysisResult(dHash: ImageMath.dHash(tiny),
                              sharpness: ImageMath.laplacianVariance(small),
                              brightness: ImageMath.meanBrightness(small))
    }
}
