import SwiftUI

struct CoachView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ai: AISettings

    @State private var input = ""
    @State private var sending = false
    @State private var showSettings = false
    @State private var toast: String?

    private var messages: [ChatTurn] { store.state.chats }

    private var userCount: Int {
        messages.filter { $0.role == .user }.count
    }

    private var remaining: Int {
        Gate.coachRemaining(used: userCount)
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if messages.count <= 1 {
                                suggestions
                            }
                            ForEach(messages) { turn in
                                bubble(turn)
                                    .id(turn.id)
                            }
                            if sending {
                                typing
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, Metrics.page)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: sending) { _, isSending in
                        if isSending {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }
                composer
            }
        }
        .navigationTitle("教练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Palette.textDim)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            AISettingsView()
        }
        .toast($toast)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.purple.opacity(0.16)).frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.purple)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ai.isConfigured ? "AI 教练 · 在线" : "AI 教练 · 本地模式")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(ai.isConfigured ? "已接入 \(ai.config.chatModel)" : "配置 Key 后可对话；本地模式已覆盖常见问题")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(remaining)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.green)
                Text("剩余")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.textFaint)
            }
        }
        .padding(.horizontal, Metrics.page)
        .padding(.vertical, 10)
        .background(Palette.bg)
        .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .bottom)
    }

    // MARK: - 建议

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("试试这样问")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
            ForEach(suggested, id: \.self) { text in
                Button {
                    input = text
                } label: {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Palette.card))
                        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var suggested: [String] {
        [
            "今天练什么？",
            "卧推 62.5 做了 8 次，下次加多少？",
            "这周睡得很差，要不要减载？",
            "我还差多少蛋白？"
        ]
    }

    // MARK: - 气泡

    private func bubble(_ turn: ChatTurn) -> some View {
        HStack {
            if turn.role == .user { Spacer(minLength: 44) }

            Text(turn.text)
                .font(.system(size: 14.5))
                .foregroundStyle(turn.role == .user ? Color.black : Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(turn.role == .user ? Color.white : Palette.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(turn.role == .user ? .clear : Palette.stroke, lineWidth: 1)
                )
                .textSelection(.enabled)

            if turn.role == .coach { Spacer(minLength: 44) }
        }
    }

    private var typing: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Palette.textDim)
                        .frame(width: 6, height: 6)
                        .opacity(0.4)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.15), value: sending)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
            Spacer()
        }
    }

    // MARK: - 输入

    private var composer: some View {
        HStack(spacing: 9) {
            TextField("问点具体的，比如「深蹲该加多少」", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card))

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(input.isEmpty || sending ? Palette.textFaint : Color.black)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(input.isEmpty || sending ? Palette.card : Color.white))
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
        }
        .padding(.horizontal, Metrics.page)
        .padding(.vertical, 10)
        .background(Palette.bg)
        .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .top)
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }

        guard Gate.canUseCoach(used: userCount) else {
            toast = "对话额度用完了"
            return
        }

        input = ""
        store.appendChat(ChatTurn(role: .user, text: text))
        sending = true
        defer { sending = false }

        let result = await CoachEngine.ask(text, store: store, config: ai.config)
        store.appendChat(ChatTurn(role: .coach, text: result.answer))
    }
}
