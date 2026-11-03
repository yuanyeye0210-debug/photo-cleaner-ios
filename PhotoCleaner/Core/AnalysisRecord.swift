import Foundation

/// 量化后的 AI 特征向量（每维 1 字节）。
/// Vision 的特征向量有 768 维 float（3 KB），全相册几万张放内存和缓存里太大，
/// 归一化后每维都在 -1~1 之间，乘 127 存成 Int8，距离误差很小（< 0.01），体积只有原来的 1/4。
struct QFeature: Codable, Sendable, Equatable {
    var q: [Int8]

    /// 输入需要已归一化（单位长度）
    init?(normalized v: [Float]) {
        guard !v.isEmpty else { return nil }
        q = v.map { x in
            let s = (x * 127).rounded()
            return Int8(max(-127, min(127, s.isFinite ? s : 0)))
        }
    }

    init(raw: [Int8]) { q = raw }

    /// 欧氏距离，和归一化 float 向量的距离同一量纲（0~2）
    func distance(to other: QFeature) -> Float {
        let n = min(q.count, other.q.count)
        guard n > 0 else { return .infinity }
        var s: Int32 = 0
        q.withUnsafeBufferPointer { a in
            other.q.withUnsafeBufferPointer { b in
                for i in 0..<n {
                    let d = Int32(a[i]) - Int32(b[i])
                    s &+= d * d
                }
            }
        }
        return Float(s).squareRoot() / 127
    }
}

/// 单张图片的分析结果（会存进本机缓存，下次打开不用重新分析）
struct AnalysisResult: Sendable, Codable, Equatable {
    var dHash: UInt64
    var sharpness: Double   // 拉普拉斯方差，越大越清晰
    var brightness: Double  // 平均亮度 0...255

    // MARK: AI（苹果 Vision，本机运行）
    var feature: QFeature? = nil        // 图像特征向量（量化），用于 AI 相似度
    var aesthetics: Float? = nil        // 美观评分 -1~1（iOS 18+）
    var isUtility: Bool? = nil          // 工具性照片：票据、文档、截图等（iOS 18+）
    var tags: Set<ContentTag> = []      // 内容识别：文档、二维码、美食、宠物、风景
    var textChecked = false             // 是否做过文字识别
    var textLines = 0
    var textChars = 0
    var verificationCode: String? = nil
    var faceChecked = false             // 是否算过人脸质量
    var faceQuality: Float? = nil       // 人脸拍摄质量 0~1（只对相似组里的照片计算）

    init(dHash: UInt64, sharpness: Double, brightness: Double) {
        self.dHash = dHash
        self.sharpness = sharpness
        self.brightness = brightness
    }

    var textHeavy: Bool { VisionRules.isTextHeavy(lines: textLines, chars: textChars) }
}
