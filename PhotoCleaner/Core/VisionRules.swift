import Foundation

/// AI（苹果 Vision）识别结果 → 清理分类的纯规则部分（不依赖 Vision / UIKit，便于单元测试）
enum ContentTag: String, Sendable, Hashable, Codable {
    case document      // 文档 / 票据 / 证件
    case qrCode        // 含二维码
    case food          // 美食
    case pet           // 宠物
    case scenery       // 风景
    case screenshotLike // 看起来像截图（保存下来的聊天记录、网页长图等）
}

enum VisionRules {
    // MARK: - 内容识别（VNClassifyImageRequest 的标签）

    /// 文档类标签（置信度 ≥ documentConfidence）
    static let documentLabels: Set<String> = [
        "document", "receipt", "printed_page", "ticket", "passport",
        "handwriting", "sticky_note", "menu", "business_card", "id_card", "money",
    ]
    static let foodLabels: Set<String> = ["food", "dessert", "baked_goods", "meal", "dish", "fast_food", "seafood"]
    static let petLabels: Set<String> = ["cat", "dog", "kitten", "puppy", "canine", "feline", "hamster", "rabbit", "parrot"]
    static let sceneryLabels: Set<String> = [
        "mountain", "sunset_sunrise", "beach", "ocean", "lake", "waterfall", "desert", "forest",
        "shore", "cliff", "canyon", "river", "landscape", "night_sky", "blue_sky", "glacier", "volcano",
    ]
    /// 可能有大量文字的标签（决定要不要做文字识别）
    static let textLabels: Set<String> = ["document", "printed_page", "receipt", "screenshot", "handwriting", "text", "menu", "sign"]

    /// 文档 / 票据：置信度 >= 0.6；文字很多时放宽到 0.5
    static let documentConfidence: Float = 0.6
    static let documentTextConfidence: Float = 0.5
    /// 美食 / 宠物 / 风景：置信度 >= 0.7，并且必须是「最主要的标签」（跳过 genericLabels 这类大类后排第一）
    static let foodConfidence: Float = 0.7
    static let petConfidence: Float = 0.7
    static let sceneryConfidence: Float = 0.7
    static let screenshotConfidence: Float = 0.5
    static let peopleConfidence: Float = 0.5
    /// 相似分组用的主体标签：前 5 个、置信度 >= 0.3
    static let subjectLabelCount = 5
    static let subjectLabelConfidence: Float = 0.3
    /// Vision 的标签是分层的（狗的照片同时有 animal / mammal / dog），判断「主要标签」时跳过这些大类
    static let genericLabels: Set<String> = [
        "animal", "mammal", "outdoor", "indoor", "structure", "plant", "sky", "land", "water", "liquid",
        "material", "people", "adult", "child", "textile", "wood", "foliage", "consumable", "conveyance",
    ]

    /// 按置信度排序后，跳过大类，第一个具体标签
    static func topSpecificLabel(_ labels: [(String, Float)]) -> String? {
        labels.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }.first { !genericLabels.contains($0.0) }?.0
    }

    /// 相似分组用：前 5 个置信度 >= 0.3 的标签
    static func subjectLabels(_ labels: [(String, Float)]) -> [String] {
        labels.filter { $0.1 >= subjectLabelConfidence }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .prefix(subjectLabelCount).map(\.0)
    }

    /// 把分类标签（identifier, confidence）映射成我们关心的少量内容标签；不认识的标签直接忽略。
    /// 二维码只看真正的条码识别结果（hasQR），不看分类标签。
    static func tags(labels: [(String, Float)], hasQR: Bool, textHeavy: Bool = false) -> Set<ContentTag> {
        var conf: [String: Float] = [:]
        for (id, c) in labels { conf[id] = max(conf[id] ?? 0, c) }
        func maxConf(_ set: Set<String>) -> Float {
            set.reduce(Float(0)) { max($0, conf[$1] ?? 0) }
        }
        let top = topSpecificLabel(labels)
        func isTop(_ set: Set<String>) -> Bool { top.map { set.contains($0) } ?? false }
        var out: Set<ContentTag> = []
        if hasQR { out.insert(.qrCode) }
        if maxConf(documentLabels) >= (textHeavy ? documentTextConfidence : documentConfidence) { out.insert(.document) }
        if maxConf(foodLabels) >= foodConfidence && isTop(foodLabels) { out.insert(.food) }
        if maxConf(petLabels) >= petConfidence && isTop(petLabels) { out.insert(.pet) }
        let hasPeople = (conf["people"] ?? 0) >= peopleConfidence || (conf["portrait"] ?? 0) >= peopleConfidence
        if !hasPeople && maxConf(sceneryLabels) >= sceneryConfidence && isTop(sceneryLabels) { out.insert(.scenery) }
        if (conf["screenshot"] ?? 0) >= screenshotConfidence { out.insert(.screenshotLike) }
        return out
    }

    /// 文字相关标签的最高置信度
    static func textLikelihood(labels: [(String, Float)]) -> Float {
        labels.reduce(Float(0)) { textLabels.contains($1.0) ? max($0, $1.1) : $0 }
    }

    // MARK: - 文字识别

    /// 只对「可能是文字图」的候选做文字识别（省电省时）
    static func shouldRecognizeText(isScreenshot: Bool, isUtility: Bool?, tags: Set<ContentTag>,
                                    textLikelihood: Float, brightness: Double, aspect: Double) -> Bool {
        isScreenshot || isUtility == true || tags.contains(.document) || tags.contains(.screenshotLike)
            || textLikelihood >= 0.3 || aspect >= 2.0 || brightness >= 200
    }

    /// 文字识别用的图片尺寸：普通图最长边 1024；长图保证短边约 900，最长不超过 4096
    static func textTargetSize(width: Int, height: Int) -> (Int, Int) {
        guard width > 0, height > 0 else { return (1024, 1024) }
        let long = Double(max(width, height)), short = Double(min(width, height))
        var scale = 1024.0 / long
        if long / short >= 2.0 { scale = 900.0 / short }
        scale = min(scale, 4096.0 / long, 1.0)
        return (max(1, Int((Double(width) * scale).rounded())), max(1, Int((Double(height) * scale).rounded())))
    }

    /// 文字很多：行数 ≥ 6 或字数 ≥ 80（中文一个字算一个）
    static func isTextHeavy(lines: Int, chars: Int) -> Bool {
        lines >= 6 || chars >= 80
    }

    static let codeKeywords = ["验证码", "校验码", "动态码", "确认码", "激活码", "verification", "code", "otp", "passcode"]

    /// 找验证码：文字里有「验证码」等关键词，并且有一串独立的 4~8 位数字
    static func verificationCode(in lines: [String]) -> String? {
        let text = lines.joined(separator: "\n")
        let lower = text.lowercased()
        guard codeKeywords.contains(where: { lower.contains($0) }) else { return nil }
        guard let re = try? NSRegularExpression(pattern: "(?<![0-9])[0-9]{4,8}(?![0-9])") else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: m.range)
    }

    // MARK: - 分类规则

    /// 低质量照片：美观评分（-1~1）低于此值且不是工具性照片
    static let lowQualityScore: Float = -0.3

    static func isLowQuality(aesthetics: Float?, isUtility: Bool?, isScreenshot: Bool) -> Bool {
        guard let s = aesthetics, !isScreenshot, isUtility != true else { return false }
        return s < lowQualityScore
    }

    /// 过暗 / 过曝：排除截图、文档、文字图、二维码、长图（白底聊天截图曾被误判为过曝）
    static func isPoorLight(brightness: Double, isScreenshot: Bool, isUtility: Bool?, textHeavy: Bool,
                            tags: Set<ContentTag>, aspect: Double) -> Bool {
        guard brightness < 35 || brightness > 240 else { return false }
        if isScreenshot || isUtility == true || textHeavy || aspect >= 2.0 { return false }
        if tags.contains(.document) || tags.contains(.qrCode) || tags.contains(.screenshotLike) { return false }
        return true
    }

    // MARK: - 特征向量

    /// L2 归一化：不同版本的 Vision 特征向量都换算到单位长度，距离范围统一为 0~2
    static func normalized(_ v: [Float]) -> [Float]? {
        var s: Float = 0
        for x in v { s += x * x }
        guard s > 0, s.isFinite else { return nil }
        let inv = 1 / s.squareRoot()
        return v.map { $0 * inv }
    }

    /// 欧氏距离（输入应已归一化）。0 = 一模一样，约 0.3 以内几乎相同，约 1 以上完全不同
    static func distance(_ a: [Float], _ b: [Float]) -> Float {
        let n = min(a.count, b.count)
        guard n > 0 else { return .infinity }
        var s: Float = 0
        a.withUnsafeBufferPointer { pa in
            b.withUnsafeBufferPointer { pb in
                for i in 0..<n {
                    let d = pa[i] - pb[i]
                    s += d * d
                }
            }
        }
        return s.squareRoot()
    }
}
