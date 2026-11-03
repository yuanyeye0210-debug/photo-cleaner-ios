import Foundation

/// 本机分析缓存：按照片 ID + 修改时间保存分析结果和文件大小。
/// 照片被编辑过（修改时间变了）就当作没缓存，重新分析，避免用旧结果分错组。
/// 存成一个二进制 plist 文件，几万张也就十几 MB，一次读完。
final class AnalysisCache: @unchecked Sendable {
    /// 分析算法变了就加 1，旧缓存自动作废
    static let version = 3   // 3：分类阈值提高 + 记录主体标签和人脸数（分组更准）

    struct Entry: Codable, Sendable, Equatable {
        var modified: Double?
        var result: AnalysisResult?
        var size: Int64?             // 真实文件大小（所有资源之和）
        var liveVideoBytes: Int64?   // 实况照片里视频部分的大小
        var cloudOnly: Bool?         // 上次分析时原图只在 iCloud
        var digest: String?          // 原文件 SHA-256（只给疑似完全重复的算）
    }

    private struct File: Codable {
        var version: Int
        var entries: [String: Entry]
    }

    private var entries: [String: Entry]
    private let lock = NSLock()
    private(set) var isDirty = false

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }

    init(entries: [String: Entry] = [:]) {
        self.entries = entries
    }

    var count: Int { locked { entries.count } }

    private static func key(_ d: Date?) -> Double? { d?.timeIntervalSince1970 }

    /// 只有修改时间一致才返回
    func entry(for id: String, modified: Date?) -> Entry? {
        locked {
            guard let e = entries[id], e.modified == Self.key(modified) else { return nil }
            return e
        }
    }

    func result(for id: String, modified: Date?) -> AnalysisResult? {
        entry(for: id, modified: modified)?.result
    }

    func size(for id: String, modified: Date?) -> Int64? {
        entry(for: id, modified: modified)?.size
    }

    /// 修改一条；修改时间对不上时先清空旧数据
    func update(_ id: String, modified: Date?, _ change: (inout Entry) -> Void) {
        locked {
            let m = Self.key(modified)
            var e = entries[id] ?? Entry(modified: m)
            if e.modified != m { e = Entry(modified: m) }
            change(&e)
            entries[id] = e
            isDirty = true
        }
    }

    func setResult(_ r: AnalysisResult?, for id: String, modified: Date?, cloudOnly: Bool = false) {
        update(id, modified: modified) {
            $0.result = r
            $0.cloudOnly = cloudOnly ? true : nil
        }
    }

    func setSize(_ size: Int64, liveVideoBytes: Int64?, for id: String, modified: Date?) {
        update(id, modified: modified) {
            $0.size = size
            $0.liveVideoBytes = liveVideoBytes
        }
    }

    /// 删掉相册里已经没有的照片
    func prune(keeping ids: Set<String>) {
        locked {
            let before = entries.count
            entries = entries.filter { ids.contains($0.key) }
            if entries.count != before { isDirty = true }
        }
    }

    func removeAll() {
        locked { entries.removeAll(); isDirty = true }
    }

    // MARK: 读写

    func encode() throws -> Data {
        let snapshot: [String: Entry] = locked {
            isDirty = false
            return entries
        }
        let enc = PropertyListEncoder()
        enc.outputFormat = .binary
        return try enc.encode(File(version: Self.version, entries: snapshot))
    }

    /// 解码失败或版本不同 = 空缓存（最坏情况就是重新分析）
    static func decode(_ data: Data) -> AnalysisCache {
        guard let f = try? PropertyListDecoder().decode(File.self, from: data), f.version == version else {
            return AnalysisCache()
        }
        return AnalysisCache(entries: f.entries)
    }

    static func load(from url: URL) -> AnalysisCache {
        guard let data = try? Data(contentsOf: url) else { return AnalysisCache() }
        return decode(data)
    }

    func save(to url: URL) throws {
        let data = try encode()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

/// 决定哪些照片需要分析（新照片在前）
enum AnalysisPlanner {
    struct Asset: Sendable {
        let id: String
        let modified: Date?
        let analyzable: Bool    // 照片、非收藏、非隐藏连拍帧
    }

    /// 返回 (已有缓存的结果, 需要分析的 ID)。`skipCloudOnly` 为真时，上次因为只在 iCloud 没分析成的不再重试
    static func plan(_ assets: [Asset], cache: AnalysisCache, skipCloudOnly: Bool) -> (cached: [String: AnalysisResult], todo: [String], cloudOnly: Set<String>) {
        var cached: [String: AnalysisResult] = [:]
        var todo: [String] = []
        var cloud: Set<String> = []
        for a in assets where a.analyzable {
            let e = cache.entry(for: a.id, modified: a.modified)
            if let r = e?.result {
                cached[a.id] = r
            } else if e?.cloudOnly == true {
                cloud.insert(a.id)
                if !skipCloudOnly { todo.append(a.id) }
            } else {
                todo.append(a.id)
            }
        }
        return (cached, todo, cloud)
    }
}

/// 文件大小估算（真实大小还没读到时先用）
enum FileSizes {
    static func estimate(pixelWidth: Int, pixelHeight: Int, isVideo: Bool, duration: Double) -> Int64 {
        if isVideo { return Int64(max(1, duration) * 1_500_000) } // 约 12 Mbps
        return Int64(pixelWidth) * Int64(pixelHeight) / 3           // HEIC 约 0.33 字节/像素
    }

    /// 转成 HEVC 预计能省的空间（已经是 HEVC 的实际会跳过）
    static func estimatedHEVCSavings(_ bytes: Int64) -> Int64 {
        bytes * 4 / 10
    }
}

