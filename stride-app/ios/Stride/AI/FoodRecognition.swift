import Foundation
import UIKit

// MARK: - 本地食物库（没网、没 Key 时也能算）

enum FoodDatabase {

    struct Template: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let kcal100: Double
        let p100: Double
        let c100: Double
        let f100: Double
        let defaultGrams: Double

        func item(grams: Double) -> FoodItem {
            let k = grams / 100.0
            return FoodItem(
                name: name,
                grams: grams,
                kcal: (kcal100 * k).rounded(),
                protein: (p100 * k * 10).rounded() / 10,
                carbs: (c100 * k * 10).rounded() / 10,
                fat: (f100 * k * 10).rounded() / 10
            )
        }
    }

    static let all: [Template] = [
        Template(name: "鸡胸肉", kcal100: 165, p100: 31, c100: 0, f100: 3.6, defaultGrams: 150),
        Template(name: "鸡腿肉（去皮）", kcal100: 209, p100: 26, c100: 0, f100: 11, defaultGrams: 150),
        Template(name: "牛里脊", kcal100: 143, p100: 22, c100: 0, f100: 6, defaultGrams: 150),
        Template(name: "牛腩", kcal100: 332, p100: 17, c100: 0, f100: 29, defaultGrams: 120),
        Template(name: "猪里脊", kcal100: 155, p100: 20, c100: 1, f100: 8, defaultGrams: 120),
        Template(name: "三文鱼", kcal100: 208, p100: 20, c100: 0, f100: 13, defaultGrams: 130),
        Template(name: "鳕鱼", kcal100: 82, p100: 18, c100: 0, f100: 0.7, defaultGrams: 150),
        Template(name: "虾仁", kcal100: 99, p100: 21, c100: 0, f100: 0.9, defaultGrams: 120),
        Template(name: "鸡蛋", kcal100: 143, p100: 13, c100: 1.1, f100: 9.5, defaultGrams: 100),
        Template(name: "蛋白", kcal100: 52, p100: 11, c100: 0.7, f100: 0.2, defaultGrams: 100),
        Template(name: "全脂牛奶", kcal100: 61, p100: 3.2, c100: 4.8, f100: 3.3, defaultGrams: 250),
        Template(name: "无糖豆浆", kcal100: 31, p100: 3.0, c100: 1.2, f100: 1.6, defaultGrams: 250),
        Template(name: "希腊酸奶", kcal100: 97, p100: 9, c100: 4, f100: 5, defaultGrams: 150),
        Template(name: "乳清蛋白粉", kcal100: 400, p100: 80, c100: 8, f100: 6, defaultGrams: 30),
        Template(name: "白米饭", kcal100: 116, p100: 2.6, c100: 25.9, f100: 0.3, defaultGrams: 200),
        Template(name: "糙米饭", kcal100: 116, p100: 2.5, c100: 24, f100: 0.9, defaultGrams: 200),
        Template(name: "全麦吐司", kcal100: 250, p100: 10, c100: 45, f100: 3, defaultGrams: 70),
        Template(name: "燕麦片", kcal100: 389, p100: 17, c100: 66, f100: 7, defaultGrams: 50),
        Template(name: "意大利面（熟）", kcal100: 158, p100: 5.8, c100: 31, f100: 0.9, defaultGrams: 200),
        Template(name: "红薯", kcal100: 86, p100: 1.6, c100: 20, f100: 0.1, defaultGrams: 200),
        Template(name: "土豆", kcal100: 77, p100: 2, c100: 17, f100: 0.1, defaultGrams: 200),
        Template(name: "玉米", kcal100: 86, p100: 3.3, c100: 19, f100: 1.4, defaultGrams: 150),
        Template(name: "西兰花", kcal100: 34, p100: 2.8, c100: 6.6, f100: 0.4, defaultGrams: 150),
        Template(name: "菠菜", kcal100: 23, p100: 2.9, c100: 3.6, f100: 0.4, defaultGrams: 100),
        Template(name: "生菜", kcal100: 15, p100: 1.4, c100: 2.9, f100: 0.2, defaultGrams: 100),
        Template(name: "番茄", kcal100: 18, p100: 0.9, c100: 3.9, f100: 0.2, defaultGrams: 150),
        Template(name: "黄瓜", kcal100: 15, p100: 0.7, c100: 3.6, f100: 0.1, defaultGrams: 150),
        Template(name: "牛油果", kcal100: 160, p100: 2, c100: 9, f100: 15, defaultGrams: 100),
        Template(name: "香蕉", kcal100: 89, p100: 1.1, c100: 23, f100: 0.3, defaultGrams: 120),
        Template(name: "苹果", kcal100: 52, p100: 0.3, c100: 14, f100: 0.2, defaultGrams: 180),
        Template(name: "蓝莓", kcal100: 57, p100: 0.7, c100: 14, f100: 0.3, defaultGrams: 80),
        Template(name: "坚果混合", kcal100: 607, p100: 20, c100: 21, f100: 54, defaultGrams: 25),
        Template(name: "花生酱", kcal100: 588, p100: 25, c100: 20, f100: 50, defaultGrams: 20),
        Template(name: "橄榄油", kcal100: 884, p100: 0, c100: 0, f100: 100, defaultGrams: 10),
        Template(name: "美式咖啡", kcal100: 2, p100: 0.1, c100: 0, f100: 0, defaultGrams: 300),
        Template(name: "拿铁（全脂）", kcal100: 56, p100: 3.0, c100: 5.0, f100: 2.6, defaultGrams: 300),
        Template(name: "可乐", kcal100: 42, p100: 0, c100: 10.6, f100: 0, defaultGrams: 330),
        Template(name: "啤酒", kcal100: 43, p100: 0.5, c100: 3.6, f100: 0, defaultGrams: 330),
        Template(name: "汉堡", kcal100: 295, p100: 13, c100: 30, f100: 13, defaultGrams: 200),
        Template(name: "炒饭", kcal100: 168, p100: 4.5, c100: 26, f100: 5, defaultGrams: 300),
        Template(name: "牛肉面", kcal100: 122, p100: 7, c100: 16, f100: 3, defaultGrams: 500),
        Template(name: "煎饺", kcal100: 240, p100: 8, c100: 26, f100: 11, defaultGrams: 180)
    ]

    static func search(_ query: String) -> [Template] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    static func find(_ name: String) -> Template? {
        all.first { $0.name == name } ?? all.first { $0.name.contains(name) }
    }
}

// MARK: - 拍照识别

enum FoodRecognition {

    static let prompt = """
    识别这张餐食照片里的食物。只输出 JSON，不要任何解释文字，格式：
    {"items":[{"name":"食物名","grams":估算克数,"kcal":热量,"protein":蛋白质克,"carbs":碳水克,"fat":脂肪克}]}
    要求：名称用中文；克数按常见份量估算；数值是这份食物的总量而不是每 100g。
    """

    private struct Payload: Decodable {
        struct Item: Decodable {
            let name: String
            let grams: Double
            let kcal: Double
            let protein: Double
            let carbs: Double
            let fat: Double
        }
        let items: [Item]
    }

    static func estimate(image: UIImage, config: AIConfig) async throws -> [FoodItem] {
        guard config.isConfigured else { throw AIError.notConfigured }

        let small = downscale(image, maxEdge: 900)
        guard let data = small.jpegData(compressionQuality: 0.62) else {
            throw AIError.badResponse("图片编码失败")
        }
        let b64 = data.base64EncodedString()

        let raw = try await AIClient.vision(
            imageBase64JPEG: b64,
            prompt: prompt,
            config: config,
            maxTokens: 900
        )

        guard let jsonData = JSONExtract.firstObject(from: raw) else {
            throw AIError.badResponse("模型没给 JSON：\(raw.prefix(80))")
        }
        let payload = try JSONDecoder().decode(Payload.self, from: jsonData)
        guard !payload.items.isEmpty else { throw AIError.badResponse("没识别出食物") }

        return payload.items.map {
            FoodItem(
                name: $0.name,
                grams: $0.grams,
                kcal: $0.kcal,
                protein: $0.protein,
                carbs: $0.carbs,
                fat: $0.fat
            )
        }
    }

    static func downscale(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
