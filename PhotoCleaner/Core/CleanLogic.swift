import Foundation

// 不依赖 Photos / UIKit 的清理逻辑，方便单元测试

// MARK: - 用户决定（存成文件，不再放 UserDefaults）

struct DecisionState: Codable, Equatable, Sendable {
    var toDelete: Set<String> = []
    var kept: Set<String> = []
    var later: Set<String> = []          // 上滑「稍后再看」
    var cleanedMonths: Set<String> = []  // 标记为「已清理」的月份 "2026-11"
    var failed: Set<String> = []         // 上次删除失败的
    /// 已压缩 / 已转成静态照片的原件 → 新文件的大小（删原件时只算真正省下的空间）
    var replacements: [String: Int64] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey { case toDelete, kept, later, cleanedMonths, failed, replacements }

    // 字段缺失时用默认值，老文件、新版本都能读
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        toDelete = try c.decodeIfPresent(Set<String>.self, forKey: .toDelete) ?? []
        kept = try c.decodeIfPresent(Set<String>.self, forKey: .kept) ?? []
        later = try c.decodeIfPresent(Set<String>.self, forKey: .later) ?? []
        cleanedMonths = try c.decodeIfPresent(Set<String>.self, forKey: .cleanedMonths) ?? []
        failed = try c.decodeIfPresent(Set<String>.self, forKey: .failed) ?? []
        replacements = try c.decodeIfPresent([String: Int64].self, forKey: .replacements) ?? [:]
    }

    /// 删掉一张照片时真正省下的空间
    func freedBytes(id: String, size: Int64) -> Int64 {
        guard let r = replacements[id] else { return size }
        return max(0, size - r)
    }

    /// 删掉相册里已不存在的照片的记录
    mutating func prune(existing: Set<String>) {
        toDelete.formIntersection(existing)
        kept.formIntersection(existing)
        later.formIntersection(existing)
        failed.formIntersection(existing)
        replacements = replacements.filter { existing.contains($0.key) }
    }

    static func load(from url: URL) -> DecisionState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DecisionState.self, from: data)
    }

    func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - 删除结果（区分：成功 / 部分失败 / 用户取消）

struct DeleteOutcome: Equatable, Sendable {
    var deleted: [String]
    var failed: [String]
    var cancelled: Bool

    /// requested：要删的；stillExisting：删完以后再查一遍还在的；cancelled：用户在系统弹窗点了「不允许」
    static func make(requested: [String], stillExisting: Set<String>, cancelled: Bool) -> DeleteOutcome {
        if cancelled { return DeleteOutcome(deleted: [], failed: [], cancelled: true) }
        let deleted = requested.filter { !stillExisting.contains($0) }
        let failed = requested.filter { stillExisting.contains($0) }
        return DeleteOutcome(deleted: deleted, failed: failed, cancelled: false)
    }
}

// MARK: - 累计清理统计

struct CleanupStats: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case deleted, compressed, livePhoto }

    struct Event: Codable, Equatable, Sendable {
        var date: Date
        var kind: Kind
        var count: Int
        var bytes: Int64
    }

    struct Day: Equatable, Sendable {
        var date: Date   // 当天 0 点
        var bytes: Int64
        var count: Int
    }

    var events: [Event] = []
    /// 超过上限后把最老的记录合并进 base，总数不丢
    var baseCount = 0
    var baseBytes: Int64 = 0
    static let maxEvents = 3000

    mutating func record(_ kind: Kind, count: Int, bytes: Int64, at date: Date = Date()) {
        guard count > 0 || bytes > 0 else { return }
        events.append(Event(date: date, kind: kind, count: count, bytes: max(0, bytes)))
        if events.count > Self.maxEvents {
            let drop = events.prefix(events.count - Self.maxEvents)
            baseCount += drop.reduce(0) { $0 + $1.count }
            baseBytes += drop.reduce(0) { $0 + $1.bytes }
            events.removeFirst(drop.count)
        }
    }

    var totalBytes: Int64 { baseBytes + events.reduce(0) { $0 + $1.bytes } }
    var totalCount: Int { baseCount + events.reduce(0) { $0 + $1.count } }
    var deletedCount: Int { events.filter { $0.kind == .deleted }.reduce(0) { $0 + $1.count } }
    var sessions: Int { events.filter { $0.kind == .deleted }.count }

    /// 最近 days 天每天释放的空间（含今天，旧的在前，没有记录的天为 0）
    func daily(days: Int = 30, now: Date = Date(), calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: now)
        var out: [Day] = []
        for k in stride(from: days - 1, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -k, to: today) else { continue }
            out.append(Day(date: d, bytes: 0, count: 0))
        }
        guard let first = out.first?.date else { return out }
        for e in events where e.date >= first {
            let d = calendar.startOfDay(for: e.date)
            if let i = out.firstIndex(where: { $0.date == d }) {
                out[i].bytes += e.bytes
                out[i].count += e.count
            }
        }
        return out
    }

    func bytes(lastDays days: Int, now: Date = Date(), calendar: Calendar = .current) -> Int64 {
        daily(days: days, now: now, calendar: calendar).reduce(0) { $0 + $1.bytes }
    }

    static func load(from url: URL) -> CleanupStats {
        guard let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(CleanupStats.self, from: data) else { return CleanupStats() }
        return s
    }

    func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - 小批量整理

enum BatchModes {
    /// 那年今日：往年同月同日拍的（不含今年），新的在前
    static func onThisDay(_ entries: [(id: String, date: Date?)], today: Date = Date(), calendar: Calendar = .current) -> [String] {
        let t = calendar.dateComponents([.year, .month, .day], from: today)
        return entries.compactMap { e -> (String, Date)? in
            guard let d = e.date else { return nil }
            let c = calendar.dateComponents([.year, .month, .day], from: d)
            guard c.month == t.month, c.day == t.day, (c.year ?? 0) < (t.year ?? 0) else { return nil }
            return (e.id, d)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }

    /// 随机抽 count 张
    static func random<G: RandomNumberGenerator>(_ ids: [String], count: Int, using g: inout G) -> [String] {
        Array(ids.shuffled(using: &g).prefix(count))
    }

    static func random(_ ids: [String], count: Int) -> [String] {
        var g = SystemRandomNumberGenerator()
        return random(ids, count: count, using: &g)
    }
}

// MARK: - 完全相同的重复

enum ExactDuplicates {
    struct Candidate: Sendable {
        let id: String
        let width: Int
        let height: Int
        let size: Int64      // 必须是真实大小
    }

    /// 先按「分辨率 + 文件大小」分桶，只有落在同一桶里的才值得算文件指纹
    static func buckets(_ items: [Candidate]) -> [[String]] {
        var map: [String: [String]] = [:]
        for c in items where c.size > 0 {
            map["\(c.width)x\(c.height)x\(c.size)", default: []].append(c.id)
        }
        return map.values.filter { $0.count > 1 }.map { $0.sorted() }.sorted { $0[0] < $1[0] }
    }

    /// 按文件指纹分组（指纹相同 = 内容完全一样）
    static func groups(digests: [String: String]) -> [[String]] {
        var map: [String: [String]] = [:]
        for (id, d) in digests { map[d, default: []].append(id) }
        return map.values.filter { $0.count > 1 }.map { $0.sorted() }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0[0] < $1[0] }
    }

    /// 相似组里去掉「完全相同」组的多余副本（每个完全相同组只留 keeper），剩不到 2 张的组丢掉
    static func subtract(_ similar: [[String]], exact: [[String]], keeper: ([String]) -> String?) -> [[String]] {
        var extra = Set<String>()
        for g in exact {
            let k = keeper(g) ?? g.first
            for id in g where id != k { extra.insert(id) }
        }
        return similar.map { $0.filter { !extra.contains($0) } }.filter { $0.count > 1 }
    }
}

// MARK: - 连拍：挑要留的那张

enum BurstRules {
    struct Frame: Sendable {
        let id: String
        let userPick: Bool
        let autoPick: Bool
        let representative: Bool
    }

    /// 用户在相册里选过的 → 系统自动挑的 → 封面 → 第一张
    static func keeper(_ frames: [Frame]) -> String? {
        frames.first(where: \.userPick)?.id
            ?? frames.first(where: \.autoPick)?.id
            ?? frames.first(where: \.representative)?.id
            ?? frames.first?.id
    }
}

// MARK: - 小组件共享数据

struct WidgetSnapshot: Codable, Equatable, Sendable {
    var cleanableCount: Int = 0
    var cleanableBytes: Int64 = 0
    var screenshots: Int = 0
    var pending: Int = 0
    var freedTotal: Int64 = 0
    var updated: Date = Date()

    static let appGroup = "group.com.yeyuanye.photocleaner"
    static let key = "widgetSnapshot"

    func encoded() -> Data? { try? JSONEncoder().encode(self) }
    static func decode(_ data: Data?) -> WidgetSnapshot? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

// MARK: - 深链接（小组件、快捷指令打开某个页面）

enum DeepLink: Equatable, Sendable {
    case home
    case category(String)   // CleanCategory.rawValue
    case quick(String)      // 小批量模式：onThisDay / random / later
    case review

    static let scheme = "photocleaner"

    var url: URL {
        switch self {
        case .home: return URL(string: "\(Self.scheme)://home")!
        case .category(let c): return URL(string: "\(Self.scheme)://category/\(c)")!
        case .quick(let q): return URL(string: "\(Self.scheme)://quick/\(q)")!
        case .review: return URL(string: "\(Self.scheme)://review")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        let arg = url.pathComponents.filter { $0 != "/" }.first
        switch url.host {
        case "home": self = .home
        case "review": self = .review
        case "category": guard let a = arg else { return nil }; self = .category(a)
        case "quick": guard let a = arg else { return nil }; self = .quick(a)
        default: return nil
        }
    }
}
