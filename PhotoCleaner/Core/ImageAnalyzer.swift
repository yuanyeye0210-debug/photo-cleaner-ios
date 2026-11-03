import CoreGraphics
import Foundation

/// 单张图片的分析结果
struct AnalysisResult: Sendable {
    var dHash: UInt64
    var sharpness: Double   // 拉普拉斯方差，越大越清晰
    var brightness: Double  // 平均亮度 0...255

    // MARK: AI（苹果 Vision，本机运行）
    var feature: [Float]? = nil         // 图像特征向量（已归一化），用于 AI 相似度
    var aesthetics: Float? = nil        // 美观评分 -1~1（iOS 18+）
    var isUtility: Bool? = nil          // 工具性照片：票据、文档、截图等（iOS 18+）
    var tags: Set<ContentTag> = []      // 内容识别：文档、二维码、美食、宠物、风景
    var textChecked = false             // 是否做过文字识别
    var textLines = 0
    var textChars = 0
    var verificationCode: String? = nil
    var faceQuality: Float? = nil       // 人脸拍摄质量 0~1（只对相似组里的照片计算）

    var textHeavy: Bool { VisionRules.isTextHeavy(lines: textLines, chars: textChars) }
}

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
