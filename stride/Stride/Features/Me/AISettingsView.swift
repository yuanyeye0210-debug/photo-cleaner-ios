import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var ai: AISettings
    @Environment(\.dismiss) private var dismiss

    @State private var draft = AIConfig()
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        note

                        field(title: "接口地址", hint: "OpenAI 兼容，例如 https://api.openai.com/v1 或自建网关", text: $draft.baseURL, secure: false)
                        field(title: "API Key", hint: "只存在本机 UserDefaults，不会上传", text: $draft.apiKey, secure: true)
                        field(title: "对话模型", hint: "例如 gpt-4o-mini / qwen-vl-max", text: $draft.chatModel, secure: false)
                        field(title: "视觉模型", hint: "用于热量识别，需要支持图片输入", text: $draft.visionModel, secure: false)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("温度")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                Text(String(format: "%.1f", draft.temperature))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.green)
                            }
                            Slider(value: $draft.temperature, in: 0...1.2, step: 0.1)
                                .tint(Palette.green)
                        }
                        .padding(14)
                        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)

                        testButton
                        saveButton
                    }
                    .padding(Metrics.page)
                }
            }
            .navigationTitle("AI 服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
            }
            .onAppear { draft = ai.config }
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Palette.blue)
            Text("不填也能用：教练会切到本地规则引擎，热量识别可以手动记录。填好之后所有 AI 功能才接真模型。")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 16, fill: Palette.blue.opacity(0.07), stroke: Palette.blue.opacity(0.2))
    }

    private func field(title: String, hint: String, text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
            Group {
                if secure {
                    SecureField(hint, text: text)
                } else {
                    TextField(hint, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 14))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))
            Text(hint)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    private var testButton: some View {
        Button {
            Task { await test() }
        } label: {
            HStack(spacing: 6) {
                if testing {
                    ProgressView().tint(Palette.text)
                } else {
                    Image(systemName: "bolt.horizontal.fill").font(.system(size: 12))
                }
                Text(testing ? "测试中…" : "测试连接")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .card(radius: 16, fill: Palette.card, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
        .disabled(testing)

        .overlay(alignment: .bottomLeading) {
            if let testResult {
                Text(testResult)
                    .font(.system(size: 11))
                    .foregroundStyle(testOK ? Palette.green : Palette.red)
                    .padding(.top, 4)
                    .offset(y: 18)
            }
        }
    }

    private var saveButton: some View {
        Button {
            ai.config = draft
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
    }

    private func test() async {
        testing = true
        testResult = nil
        defer { testing = false }
        do {
            let reply = try await AIClient.chat(
                system: nil,
                user: "只回复两个字：可用",
                config: draft,
                maxTokens: 16
            )
            testOK = true
            testResult = "连接成功：\(reply.prefix(24))"
        } catch {
            testOK = false
            testResult = error.localizedDescription
        }
    }
}
