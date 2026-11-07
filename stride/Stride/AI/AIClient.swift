import Foundation
import Combine

// MARK: - 配置

struct AIConfig: Codable, Hashable {
    var baseURL: String = "https://api.openai.com/v1"
    var apiKey: String = ""
    var chatModel: String = "gpt-4o-mini"
    var visionModel: String = "gpt-4o-mini"
    var temperature: Double = 0.6

    var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !baseURL.isEmpty
    }
}

final class AISettings: ObservableObject {
    static let shared = AISettings()
    private let key = "stride.ai.config"

    @Published var config: AIConfig {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AIConfig.self, from: data) {
            config = decoded
        } else {
            config = AIConfig()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var isConfigured: Bool { config.isConfigured }
}

// MARK: - 错误

enum AIError: LocalizedError {
    case notConfigured
    case badResponse(String)
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "还没有配置 AI 服务。到「我的 → AI 服务」填一个 OpenAI 兼容的地址和 Key。"
        case .badResponse(let s):
            return "返回格式不对：\(s)"
        case .http(let code, let body):
            return "HTTP \(code)：\(body.prefix(160))"
        }
    }
}

// MARK: - 客户端（OpenAI 兼容协议）

struct AIClient {

    struct Message: Encodable {
        let role: String
        let content: Content

        enum CodingKeys: String, CodingKey { case role, content }

        enum Content: Encodable {
            case text(String)
            case parts([[String: String]])

            func encode(to encoder: Encoder) throws {
                var c = encoder.singleValueContainer()
                switch self {
                case .text(let s):
                    try c.encode(s)
                case .parts(let p):
                    try c.encode(p)
                }
            }
        }
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg
        }
        let choices: [Choice]
    }

    static func complete(
        system: String?,
        messages: [Message],
        model: String,
        config: AIConfig,
        maxTokens: Int = 700
    ) async throws -> String {
        guard config.isConfigured else { throw AIError.notConfigured }

        var payload: [Message] = []
        if let system, !system.isEmpty {
            payload.append(Message(role: "system", content: .text(system)))
        }
        payload.append(contentsOf: messages)

        let body = ChatRequest(
            model: model,
            messages: payload,
            temperature: config.temperature,
            max_tokens: maxTokens
        )

        return try await send(body, config: config)
    }

    static func chat(
        system: String?,
        user: String,
        config: AIConfig,
        model: String? = nil,
        maxTokens: Int = 700
    ) async throws -> String {
        try await complete(
            system: system,
            messages: [Message(role: "user", content: .text(user))],
            model: model ?? config.chatModel,
            config: config,
            maxTokens: maxTokens
        )
    }

    static func vision(
        imageBase64JPEG: String,
        prompt: String,
        config: AIConfig,
        maxTokens: Int = 800
    ) async throws -> String {
        let parts: [[String: String]] = [
            ["type": "text", "text": prompt],
            ["type": "image_url", "image_url": "data:image/jpeg;base64,\(imageBase64JPEG)"]
        ]
        return try await complete(
            system: nil,
            messages: [Message(role: "user", content: .parts(parts))],
            model: config.visionModel,
            config: config,
            maxTokens: maxTokens
        )
    }

    // MARK: - 传输

    private static func send(_ body: ChatRequest, config: AIConfig) async throws -> String {
        var urlString = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasSuffix("/") { urlString.removeLast() }
        if !urlString.hasSuffix("/chat/completions") { urlString += "/chat/completions" }

        guard let url = URL(string: urlString) else {
            throw AIError.badResponse("Base URL 不是合法网址")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.badResponse("没有 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AIError.http(http.statusCode, text)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIError.badResponse("choices 为空")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - JSON 提取工具

enum JSONExtract {
    /// 从模型回复里抠出第一段 JSON（容忍 ```json 包裹和前后废话）
    static func firstObject(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        let slice = text[start...end]
        return String(slice).data(using: .utf8)
    }
}
