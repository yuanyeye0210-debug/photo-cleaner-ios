import Photos
import SwiftUI

/// 全局状态：扫描、分类、标记、删除
@MainActor
final class CleanupStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, analyzing, done
    }

    // MARK: 权限 & 扫描状态
    @Published var authStatus: PHAuthorizationStatus = PhotoLibraryService.authorizationStatus
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var progressText: String = ""

    // MARK: 数据
    @Published private(set) var items: [PhotoItem] = []
    @Published private(set) var categoryIDs: [CleanCategory: [String]] = [:]
    @Published private(set) var similarGroups: [[String]] = []
    @Published private(set) var months: [MonthGroup] = []
    @Published private(set) var totalBytes: Int64 = 0

    // MARK: 用户决定（本地持久化，下次打开还在）
    @Published private(set) var toDelete: Set<String> = []
    @Published private(set) var kept: Set<String> = []

    // MARK: 设置
    @Published var blurThreshold: Double {
        didSet { defaults.set(blurThreshold, forKey: Keys.blur); rebuildCategories() }
    }
    @Published var largeFileMB: Double {
        didSet { defaults.set(largeFileMB, forKey: Keys.large); rebuildCategories() }
    }
    @Published var analyzeLimit: Int {
        didSet { defaults.set(analyzeLimit, forKey: Keys.limit) }
    }

    @Published var lastDeleteMessage: String?

    private var index: [String: Int] = [:]
    private let defaults = UserDefaults.standard
    private var scanTask: Task<Void, Never>?

    private enum Keys {
        static let blur = "blurThreshold"
        static let large = "largeFileMB"
        static let limit = "analyzeLimit"
        static let toDelete = "toDeleteIDs"
        static let kept = "keptIDs"
    }

    init() {
        let d = UserDefaults.standard
        blurThreshold = d.object(forKey: Keys.blur) as? Double ?? 60
        largeFileMB = d.object(forKey: Keys.large) as? Double ?? 8
        analyzeLimit = d.object(forKey: Keys.limit) as? Int ?? 3000
        toDelete = Set(d.stringArray(forKey: Keys.toDelete) ?? [])
        kept = Set(d.stringArray(forKey: Keys.kept) ?? [])
    }

    // MARK: - 权限

    var hasAccess: Bool {
        authStatus == .authorized || authStatus == .limited
    }

    func requestAccess() async {
        authStatus = await PhotoLibraryService.requestAuthorization()
        if hasAccess { startScan() }
    }

    // MARK: - 扫描

    func startScan() {
        scanTask?.cancel()
        scanTask = Task { await scan() }
    }

    private func scan() async {
        phase = .loading
        progress = 0
        progressText = "正在读取相册…"

        // 1. 读取元数据（大小、截图标记、日期）
        let metas: [PhotoItem] = await Task.detached(priority: .userInitiated) {
            let assets = PhotoLibraryService.shared.fetchAllAssets()
            var out: [PhotoItem] = []
            out.reserveCapacity(assets.count)
            for (i, a) in assets.enumerated() {
                if Task.isCancelled { break }
                out.append(PhotoItem(id: a.localIdentifier,
                                     asset: a,
                                     fileSize: PhotoLibraryService.fileSize(of: a),
                                     creationDate: a.creationDate,
                                     isVideo: a.mediaType == .video,
                                     isScreenshot: a.mediaSubtypes.contains(.photoScreenshot),
                                     pixelWidth: a.pixelWidth,
                                     pixelHeight: a.pixelHeight,
                                     analysis: nil))
                if i % 200 == 0 {
                    let p = Double(i) / Double(max(1, assets.count))
                    await MainActor.run {
                        self.progress = p * 0.2
                        self.progressText = "正在读取相册… \(i)/\(assets.count)"
                    }
                }
            }
            return out
        }.value
        if Task.isCancelled { return }

        setItems(metas)
        pruneDecisions()
        rebuildCategories()

        // 2. 逐张分析（相似 / 模糊 / 亮度），截图和视频不分析
        phase = .analyzing
        let targets = items.filter { !$0.isVideo && !$0.isScreenshot }.prefix(analyzeLimit)
        let total = targets.count
        var done = 0
        let chunkSize = 12
        let targetArray = Array(targets)
        var start = 0
        while start < total {
            if Task.isCancelled { return }
            let chunk = targetArray[start..<min(start + chunkSize, total)]
            let results = await withTaskGroup(of: (String, AnalysisResult?).self) { group -> [(String, AnalysisResult?)] in
                for item in chunk {
                    let asset = item.asset
                    group.addTask {
                        (asset.localIdentifier, await CleanupStore.analyzeAsset(asset))
                    }
                }
                var out: [(String, AnalysisResult?)] = []
                for await r in group { out.append(r) }
                return out
            }
            for (id, r) in results {
                if let i = index[id] { items[i].analysis = r }
            }
            done += chunk.count
            start += chunkSize
            progress = 0.2 + 0.75 * Double(done) / Double(max(1, total))
            progressText = "正在智能分析 \(done)/\(total)"
            if done % 240 == 0 { rebuildCategories() }
        }

        // 3. 相似分组
        progressText = "正在查找相似照片…"
        let entries = items.compactMap { item -> HashEntry? in
            guard let a = item.analysis else { return nil }
            return HashEntry(id: item.id, hash: a.dHash, time: item.creationDate?.timeIntervalSince1970)
        }
        let groups = await Task.detached(priority: .userInitiated) {
            SimilarityGrouper.groups(entries)
        }.value
        similarGroups = groups
        rebuildCategories()
        progress = 1
        progressText = "分析完成"
        phase = .done
        Haptics.success()
    }

    nonisolated static func analyzeAsset(_ asset: PHAsset) async -> AnalysisResult? {
        guard let image = await PhotoLibraryService.shared.image(for: asset,
                                                                 targetSize: CGSize(width: 256, height: 256),
                                                                 contentMode: .aspectFit),
              let cg = image.cgImage else { return nil }
        return ImageAnalyzer.analyze(cg)
    }

    private func setItems(_ new: [PhotoItem]) {
        items = new
        index = Dictionary(uniqueKeysWithValues: new.enumerated().map { ($1.id, $0) })
        totalBytes = new.reduce(0) { $0 + $1.fileSize }
    }

    /// 删除已不存在的照片的标记
    private func pruneDecisions() {
        toDelete = toDelete.filter { index[$0] != nil }
        kept = kept.filter { index[$0] != nil }
        persist()
    }

    func rebuildCategories() {
        var map: [CleanCategory: [String]] = [:]
        let largeBytes = Int64(largeFileMB * 1_000_000)
        map[.screenshots] = items.filter { $0.isScreenshot }.map(\.id)
        map[.videos] = items.filter { $0.isVideo }.sorted { $0.fileSize > $1.fileSize }.map(\.id)
        map[.large] = items.filter { !$0.isVideo && $0.fileSize >= largeBytes }
            .sorted { $0.fileSize > $1.fileSize }.map(\.id)
        map[.blurry] = items.filter {
            guard let a = $0.analysis else { return false }
            return a.sharpness < blurThreshold
        }.sorted { ($0.analysis?.sharpness ?? 0) < ($1.analysis?.sharpness ?? 0) }.map(\.id)
        map[.poorLight] = items.filter {
            guard let a = $0.analysis else { return false }
            return a.brightness < 35 || a.brightness > 240
        }.map(\.id)
        map[.similar] = similarGroups.flatMap { $0 }
        categoryIDs = map

        // 按月
        let cal = Calendar(identifier: .gregorian)
        var buckets: [String: [String]] = [:]
        var titles: [String: String] = [:]
        for item in items {
            guard let d = item.creationDate else { continue }
            let c = cal.dateComponents([.year, .month], from: d)
            let y = c.year ?? 0, m = c.month ?? 0
            let key = String(format: "%04d-%02d", y, m)
            buckets[key, default: []].append(item.id)
            titles[key] = "\(y)年\(m)月"
        }
        months = buckets.keys.sorted(by: >).map { MonthGroup(id: $0, title: titles[$0] ?? $0, ids: buckets[$0] ?? []) }
    }

    // MARK: - 查询

    func item(_ id: String) -> PhotoItem? {
        guard let i = index[id] else { return nil }
        return items[i]
    }

    func ids(in category: CleanCategory) -> [String] {
        categoryIDs[category] ?? []
    }

    func bytes(of ids: [String]) -> Int64 {
        ids.reduce(0) { $0 + (item($1)?.fileSize ?? 0) }
    }

    var toDeleteBytes: Int64 { bytes(of: Array(toDelete)) }

    func decision(for id: String) -> Decision? {
        if toDelete.contains(id) { return .delete }
        if kept.contains(id) { return .keep }
        return nil
    }

    /// 尚未决定的项目
    func undecided(_ ids: [String]) -> [String] {
        ids.filter { !toDelete.contains($0) && !kept.contains($0) }
    }

    /// 推荐保留的一张（组内最清晰的）
    func bestID(in group: [String]) -> String? {
        let its = group.compactMap { item($0) }
        guard !its.isEmpty else { return nil }
        let i = SimilarityGrouper.bestIndex(sharpness: its.map { $0.analysis?.sharpness ?? 0 },
                                            pixels: its.map { $0.pixelCount })
        return its[i].id
    }

    // MARK: - 标记

    func set(_ id: String, _ decision: Decision?) {
        switch decision {
        case .delete:
            toDelete.insert(id); kept.remove(id)
        case .keep:
            kept.insert(id); toDelete.remove(id)
        case .none:
            toDelete.remove(id); kept.remove(id)
        }
        persist()
    }

    func toggleDelete(_ id: String) {
        set(id, toDelete.contains(id) ? nil : .delete)
    }

    func markAll(_ ids: [String], _ decision: Decision?) {
        for id in ids {
            switch decision {
            case .delete: toDelete.insert(id); kept.remove(id)
            case .keep: kept.insert(id); toDelete.remove(id)
            case .none: toDelete.remove(id); kept.remove(id)
            }
        }
        persist()
    }

    /// 相似组：保留最佳，其余标记删除
    func keepBestDeleteRest(_ group: [String]) {
        guard let best = bestID(in: group) else { return }
        var del = group
        del.removeAll { $0 == best }
        markAll(del, .delete)
        set(best, .keep)
    }

    func resetKept() {
        kept.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(Array(toDelete), forKey: Keys.toDelete)
        defaults.set(Array(kept), forKey: Keys.kept)
    }

    // MARK: - 删除

    /// 返回 true 表示删除成功
    func deleteMarked() async -> Bool {
        let ids = Array(toDelete)
        guard !ids.isEmpty else { return false }
        let freed = bytes(of: ids)
        do {
            try await PhotoLibraryService.shared.delete(ids: ids)
        } catch {
            lastDeleteMessage = "已取消删除"
            return false
        }
        let gone = Set(ids)
        setItems(items.filter { !gone.contains($0.id) })
        similarGroups = similarGroups
            .map { $0.filter { !gone.contains($0) } }
            .filter { $0.count > 1 }
        toDelete.removeAll()
        persist()
        rebuildCategories()
        lastDeleteMessage = "已删除 \(ids.count) 项，释放 \(Fmt.bytes(freed))。可在系统相册「最近删除」中恢复。"
        Haptics.success()
        return true
    }
}
