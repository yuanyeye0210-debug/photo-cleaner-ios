import CoreGraphics
import ImageIO
import UIKit
import Vision

/// 苹果 Vision 框架的本机 AI 识别（不联网、不上传）。所有方法都是同步的，请在后台线程调用。
enum VisionAnalyzer {
    struct Basic: Sendable {
        var feature: [Float]?
        var aesthetics: Float?
        var isUtility: Bool?
        var labels: [(String, Float)] = []
        var hasQR = false
    }

    static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    /// 特征向量 + 内容识别 + 美观评分 + 二维码：一次 perform 一起跑（共用一次解码和缩放）
    static func analyze(_ cg: CGImage, orientation: CGImagePropertyOrientation) -> Basic {
        var out = Basic()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])

        let fp = VNGenerateImageFeaturePrintRequest()          // AI 相似度
        if #available(iOS 17.0, *) {
            fp.revision = VNGenerateImageFeaturePrintRequestRevision2
        }
        let cls = VNClassifyImageRequest()                      // 内容识别
        let bc = VNDetectBarcodesRequest()                      // 二维码
        bc.symbologies = [.qr]
        var requests: [VNRequest] = [fp, cls, bc]
        var aesthetics: VNRequest?
        if #available(iOS 18.0, *) {                            // 美观评分
            let a = VNCalculateImageAestheticsScoresRequest()
            aesthetics = a
            requests.append(a)
        }

        if (try? handler.perform(requests)) == nil {
            // 合并执行失败（某个请求不支持当前设备）：逐个补跑没有结果的
            for r in requests where (r.results ?? []).isEmpty {
                _ = try? handler.perform([r])
            }
        }

        if let obs = fp.results?.first { out.feature = vector(from: obs) }
        if let res = cls.results {
            out.labels = res.filter { $0.confidence >= 0.1 }.map { ($0.identifier, $0.confidence) }
        }
        if let r = bc.results, !r.isEmpty { out.hasQR = true }
        if #available(iOS 18.0, *), let a = aesthetics as? VNCalculateImageAestheticsScoresRequest,
           let o = a.results?.first {
            out.aesthetics = o.overallScore
            out.isUtility = o.isUtility
        }
        return out
    }

    /// 文字识别（中文 + 英文）。返回每行文字
    static func recognizeText(_ cg: CGImage, orientation: CGImagePropertyOrientation) -> [String] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate   // 中文只有 accurate 模式支持
        req.usesLanguageCorrection = false
        req.recognitionLanguages = ["zh-Hans", "en-US"]
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
        guard (try? handler.perform([req])) != nil, let res = req.results else { return [] }
        return res.compactMap { $0.topCandidates(1).first?.string }
    }

    /// 人脸拍摄质量（0~1，越高越好：睁眼、清晰、表情自然）。多张脸取平均；没人脸返回 nil
    static func faceQuality(_ cg: CGImage, orientation: CGImagePropertyOrientation) -> Float? {
        let req = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation, options: [:])
        guard (try? handler.perform([req])) != nil, let res = req.results else { return nil }
        let qs: [Float] = res.compactMap { $0.faceCaptureQuality }
        guard !qs.isEmpty else { return nil }
        return qs.reduce(0, +) / Float(qs.count)
    }

    private static func vector(from obs: VNFeaturePrintObservation) -> [Float]? {
        let n = obs.elementCount
        guard n > 0 else { return nil }
        var v = [Float](repeating: 0, count: n)
        switch obs.elementType {
        case .float:
            obs.data.withUnsafeBytes { raw in
                let p = raw.bindMemory(to: Float.self)
                for i in 0..<min(n, p.count) { v[i] = p[i] }
            }
        case .double:
            obs.data.withUnsafeBytes { raw in
                let p = raw.bindMemory(to: Double.self)
                for i in 0..<min(n, p.count) { v[i] = Float(p[i]) }
            }
        default:
            return nil
        }
        return VisionRules.normalized(v)
    }
}
