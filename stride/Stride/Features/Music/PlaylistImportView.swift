import SwiftUI

// MARK: - 数据

struct WorkoutTrack: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var bpm: Int

    var band: String {
        switch bpm {
        case ..<120: return "热身"
        case 120..<150: return "主训"
        default: return "冲刺"
        }
    }
}

struct WorkoutPlaylist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var rawLink: String
    var tracks: [WorkoutTrack]
    var createdAt: Date = Date()
}

final class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()
    private let key = "stride.playlists"

    @Published var items: [WorkoutPlaylist] = [] {
        didSet { persist() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([WorkoutPlaylist].self, from: data) {
            items = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 解析

enum PlaylistParser {

    static func host(of link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host else { return "未知来源" }
        if host.contains("apple") { return "Apple Music" }
        if host.contains("spotify") { return "Spotify" }
        if host.contains("163.com") { return "网易云音乐" }
        if host.contains("qq.com") { return "QQ 音乐" }
        return host
    }

    static func identifier(of link: String) -> String {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return "—" }
        let parts = url.pathComponents.filter { $0 != "/" }
        if let last = parts.last { return last }
        return url.lastPathComponent.isEmpty ? "—" : url.lastPathComponent
    }

    static func looksLikeLink(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("http://") || t.hasPrefix("https://")
    }

    /// 每行一首；行尾数字当成 BPM，没有就用 120
    static func parseTracks(_ text: String) -> [WorkoutTrack] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                let numbers = line.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
                let bpm = numbers.first { $0 >= 60 && $0 <= 200 } ?? 120
                let title = line
                    .replacingOccurrences(of: "\(bpm)", with: "")
                    .replacingOccurrences(of: "bpm", with: "")
                    .replacingOccurrences(of: "BPM", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " -–—|·\t"))
                return WorkoutTrack(title: title.isEmpty ? "未命名" : title, bpm: bpm)
            }
    }
}

// MARK: - 页面

struct PlaylistImportView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var playlists = PlaylistStore.shared

    @State private var link = ""
    @State private var trackText = ""
    @State private var parsedHost = ""
    @State private var parsedID = ""
    @State private var generated: [WorkoutTrack] = []
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    linkCard
                    if !parsedHost.isEmpty { linkInfo }
                    tracksCard
                    if !generated.isEmpty { resultCard }
                    savedCard
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("歌单导入")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("粘贴歌单链接")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            TextField("https://music.apple.com/… 或 open.spotify.com/…", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))

            Button {
                parse()
            } label: {
                Text("解析")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white))
            }
            .buttonStyle(.plain)
            .disabled(!PlaylistParser.looksLikeLink(link))
            .opacity(PlaylistParser.looksLikeLink(link) ? 1 : 0.4)

            Text("只解析链接结构和曲目名，不抓取平台内容；曲目时间轴由你自己粘进来。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textFaint)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var linkInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("来源", parsedHost)
            row("歌单 ID", parsedID)
        }
        .padding(16)
        .card(radius: 18, fill: Palette.green.opacity(0.07), stroke: Palette.green.opacity(0.22))
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(size: 12)).foregroundStyle(Palette.textDim)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
        }
    }

    private var tracksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("曲目列表")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("每行一首，行尾可写 BPM")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textFaint)
            }

            TextEditor(text: $trackText)
                .scrollContentBackground(.hidden)
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
                .frame(height: 140)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))

            Button {
                generated = PlaylistParser.parseTracks(trackText).sorted { $0.bpm < $1.bpm }
            } label: {
                Text("按节奏分档")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardHigh))
            }
            .buttonStyle(.plain)
            .disabled(trackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("训练歌单")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("\(generated.count) 首")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }

            ForEach(["热身", "主训", "冲刺"], id: \.self) { band in
                let list = generated.filter { $0.band == band }
                if !list.isEmpty {
                    Text(band)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(band == "主训" ? Palette.green : Palette.textDim)
                    ForEach(list) { track in
                        HStack {
                            Text(track.title)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.text)
                                .lineLimit(1)
                            Spacer()
                            Text("\(track.bpm)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textFaint)
                        }
                    }
                }
            }

            Button {
                save()
            } label: {
                Text("保存这份歌单")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("已保存")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            if playlists.items.isEmpty {
                Text("还没有歌单")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textFaint)
            } else {
                ForEach(playlists.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(Palette.text)
                            Text("\(item.host) · \(item.tracks.count) 首")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textFaint)
                        }
                        Spacer()
                        Button {
                            playlists.items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textFaint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private func parse() {
        parsedHost = PlaylistParser.host(of: link)
        parsedID = PlaylistParser.identifier(of: link)
        toast = "已解析 \(parsedHost)"
    }

    private func save() {
        let playlist = WorkoutPlaylist(
            name: parsedHost.isEmpty ? "训练歌单" : "\(parsedHost) 歌单",
            host: parsedHost.isEmpty ? "手动" : parsedHost,
            rawLink: link,
            tracks: generated
        )
        playlists.items.insert(playlist, at: 0)
        toast = "已保存"
    }
}
