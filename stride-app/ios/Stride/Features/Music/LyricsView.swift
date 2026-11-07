import SwiftUI
import Combine

// MARK: - LRC

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: Double
    let text: String
}

enum LRCParser {

    static func parse(_ raw: String) -> [LyricLine] {
        var result: [LyricLine] = []

        for rawLine in raw.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            var stamps: [Double] = []

            while line.hasPrefix("["), let end = line.firstIndex(of: "]") {
                let inside = String(line[line.index(after: line.startIndex)..<end])
                if let t = stamp(inside) { stamps.append(t) }
                line = String(line[line.index(after: end)...])
            }

            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !stamps.isEmpty else { continue }
            for t in stamps {
                result.append(LyricLine(time: t, text: text))
            }
        }
        return result.sorted { $0.time < $1.time }
    }

    private static func stamp(_ s: String) -> Double? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let minute = Double(parts[0]),
              let second = Double(parts[1])
        else { return nil }
        return minute * 60 + second
    }

    static func timestamp(_ seconds: Double) -> String {
        String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60))
    }
}

// MARK: - 页面

struct LyricsView: View {
    @State private var lrc = sample
    @State private var lines: [LyricLine] = []
    @State private var playing = false
    @State private var elapsed: Double = 0
    @State private var showEditor = true

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var currentIndex: Int {
        lines.lastIndex { $0.time <= elapsed } ?? -1
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 12) {
                toolbar
                if showEditor {
                    editor
                } else {
                    lyricsList
                }
                Spacer(minLength: 0)
                playerBar
            }
            .padding(.horizontal, Metrics.page)
            .padding(.top, 6)
        }
        .navigationTitle("歌词同步")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if lines.isEmpty { lines = LRCParser.parse(lrc) }
        }
        .onReceive(ticker) { _ in
            guard playing else { return }
            elapsed += 0.2
            if elapsed > (lines.last?.time ?? 0) + 3 { playing = false }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.snappy) { showEditor.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showEditor ? "text.alignleft" : "square.and.pencil")
                        .font(.system(size: 11, weight: .bold))
                    Text(showEditor ? "看同步" : "粘歌词")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Palette.cardHigh))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(lines.count) 行 · 不限次数")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("粘贴 .lrc，格式 [mm:ss.xx]歌词")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)

            TextEditor(text: $lrc)
                .scrollContentBackground(.hidden)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.text)
                .frame(maxHeight: .infinity)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardSoft))

            Button {
                lines = LRCParser.parse(lrc)
                elapsed = 0
                playing = false
                showEditor = false
            } label: {
                Text("解析")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
    }

    private var lyricsList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if lines.isEmpty {
                        EmptyHint(icon: "text.alignleft", title: "还没有歌词", message: "回到「粘歌词」解析一份 LRC。")
                    }
                    ForEach(lines.indices, id: \.self) { index in
                        let line = lines[index]
                        Text(line.text)
                            .font(.system(size: index == currentIndex ? 20 : 15,
                                          weight: index == currentIndex ? .bold : .regular))
                            .foregroundStyle(index == currentIndex ? Palette.text : Palette.textFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                            .animation(.easeOut(duration: 0.2), value: currentIndex)
                    }
                }
                .padding(.vertical, 20)
            }
            .onChange(of: currentIndex) { _, newValue in
                guard newValue >= 0, newValue < lines.count else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(lines[newValue].id, anchor: .center)
                }
            }
        }
    }

    private var playerBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text(LRCParser.timestamp(elapsed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.textDim)
                Spacer()
                Text(LRCParser.timestamp(lines.last?.time ?? 0))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.textFaint)
            }

            Slider(value: $elapsed, in: 0...max(1, (lines.last?.time ?? 1) + 2))
                .tint(Palette.green)

            HStack(spacing: 10) {
                Button {
                    playing.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(playing ? "暂停" : "跟着走")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color.white))
                }
                .buttonStyle(.plain)

                Button {
                    elapsed = 0
                    playing = false
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                        .frame(width: 50, height: 48)
                        .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Palette.cardHigh))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
        .padding(.bottom, 10)
    }
}

// MARK: - 示例歌词

private let sample = """
[00:00.00]Stride 训练歌单
[00:06.00]把手机架稳
[00:11.50]第一组，找感觉
[00:17.00]离心三秒，别抢
[00:23.00]呼吸跟上节奏
[00:29.00]还差两次
[00:35.00]顶住
[00:41.00]落地稳住
[00:47.00]这一组结束
[00:53.00]休息九十秒
[01:00.00]下一组，加两公斤
"""
