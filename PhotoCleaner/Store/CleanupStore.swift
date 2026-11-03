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
                                     isFavorite: a.isFavorite,
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

        // 2. 逐张 AI 分析（相似 / 模糊 / 亮度 / 内容 / 质量 / 文字），视频和收藏不分析。同时最多 4 张并行
        phase = .analyzing
        let targetArray = Array(items.filter { !$0.isVideo && !$0.isFavorite }.prefix(analyzeLimit))
        let total = targetArray.count
        var done = 0
        var nextIndex = 0
        let maxConcurrent = 4
        var pending: [(String, AnalysisResult?)] = []
        await withTaskGroup(of: (String, AnalysisResult?).self) { group in
            while nextIndex < min(maxConcurrent, total) {
                let asset = targetArray[nextIndex].asset
                let shot = targetArray[nextIndex].isScreenshot
                nextIndex += 1
                group.addTask {
                    (asset.localIdentifier, await CleanupStore.analyzeAsset(asset, isScreenshot: shot))
                }
            }
            while let r = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                pending.append(r)
                done += 1
                if nextIndex < total {
                    let asset = targetArray[nextIndex].asset
                    let shot = targetArray[nextIndex].isScreenshot
                    nextIndex += 1
                    group.addTask {
                        (asset.localIdentifier, await CleanupStore.analyzeAsset(asset, isScreenshot: shot))
                    }
                }
                if pending.count >= 8 || done == total {
                    applyResults(pending)
                    pending.removeAll()
                    progress = 0.2 + 0.7 * Double(done) / Double(max(1, total))
                    progressText = "正在用 AI 分析照片… \(done)/\(total)"
                }
                if done % 240 == 0 { rebuildCategories() }
            }
        }
        if Task.isCancelled { return }
        applyResults(pending)

        // 3. 相似分组（AI 特征 + dHash + 拍摄时间），截图和收藏不参与
        progressText = "正在查找相似照片…"
        let entries = items.compactMap { item -> HashEntry? in
            guard let a = item.analysis, !item.isScreenshot, !item.isFavorite else { return nil }
            return HashEntry(id: item.id, hash: a.dHash, time: item.creationDate?.timeIntervalSince1970,
                             feature: a.feature)
        }
        let groups = await Task.detached(priority: .userInitiated) {
            SimilarityGrouper.groups(entries)
        }.value
        if Task.isCancelled { return }
        similarGroups = groups
        rebuildCategories()

        // 4. 相似组里的照片算人脸质量，用来挑「推荐保留」
        let faceTargets = groups.flatMap { $0 }.compactMap { item($0)?.asset }
        if !faceTargets.isEmpty {
            progress = 0.92
            progressText = "正在挑选每组最好的一张…"
            var fDone = 0
            var fNext = 0
            await withTaskGroup(of: (String, Float?).self) { group in
                while fNext < min(maxConcurrent, faceTargets.count) {
                    let asset = faceTargets[fNext]
                    fNext += 1
                    group.addTask { (asset.localIdentifier, await CleanupStore.faceQuality(asset)) }
                }
                while let r = await group.next() {
                    if Task.isCancelled { group.cancelAll(); break }
                    if let i = index[r.0] { items[i].analysis?.faceQuality = r.1 }
                    fDone += 1
                    if fNext < faceTargets.count {
                        let asset = faceTargets[fNext]
                        fNext += 1
                        group.addTask { (asset.localIdentifier, await CleanupStore.faceQuality(asset)) }
                    }
                    if fDone % 8 == 0 {
                        progress = 0.92 + 0.08 * Double(fDone) / Double(faceTargets.count)
                    }
                }
            }
            if Task.isCancelled { return }
        }

        rebuildCategories()
        progress = 1
        progressText = "分析完成"
        phase = .done
        Haptics.success()
    }

    /// 一次性写回一批分析结果（减少界面刷新次数）
    private func applyResults(_ results: [(String, AnalysisResult?)]) {
        guard !results.isEmpty else { return }
        var copy = items
        for (id, r) in results {
            if let i = index[id] { copy[i].analysis = r }
        }
        items = copy
    }

    /// 单张照片的完整分析：dHash / 清晰度 / 亮度 + Vision（特征、内容、美观、二维码），候选再做文字识别
    nonisolated static func analyzeAsset(_ asset: PHAsset, isScreenshot: Bool) async -> AnalysisResult? {
        guard let image = await PhotoLibraryService.shared.image(for: asset,
                                                                 targetSize: CGSize(width: 384, height: 384),
                                                                 contentMode: .aspectFit),
              let cg = image.cgImage,
              var r = ImageAnalyzer.analyze(cg) else { return nil }
        if Task.isCancelled { return r }
        let v = VisionAnalyzer.analyze(cg, orientation: VisionAnalyzer.orientation(image.imageOrientation))
        r.feature = v.feature
        r.aesthetics = v.aesthetics
        r.isUtility = v.isUtility
        r.tags = VisionRules.tags(labels: v.labels, hasQR: v.hasQR)

        let w = asset.pixelWidth, h = asset.pixelHeight
        let aspect = Double(max(w, h)) / Double(max(1, min(w, h)))
        if VisionRules.shouldRecognizeText(isScreenshot: isScreenshot, isUtility: v.isUtility, tags: r.tags,
                                           textLikelihood: VisionRules.textLikelihood(labels: v.labels),
                                           brightness: r.brightness, aspect: aspect) {
            let (tw, th) = VisionRules.textTargetSize(width: w, height: h)
            if let big = await PhotoLibraryService.shared.image(for: asset,
                                                                targetSize: CGSize(width: tw, height: th),
                                                                contentMode: .aspectFit,
                                                                cache: false),
               let bcg = big.cgImage {
                let lines = VisionAnalyzer.recognizeText(bcg, orientation: VisionAnalyzer.orientation(big.imageOrientation))
                r.textChecked = true
                r.textLines = lines.count
                r.textChars = lines.reduce(0) { $0 + $1.count }
                r.verificationCode = VisionRules.verificationCode(in: lines)
            }
        }
        return r
    }

    nonisolated static func faceQuality(_ asset: PHAsset) async -> Float? {
        guard let image = await PhotoLibraryService.shared.image(for: asset,
                                                                 targetSize: CGSize(width: 768, height: 768),
                                                                 contentMode: .aspectFit,
                                                                 cache: false),
              let cg = image.cgImage else { return nil }
        return VisionAnalyzer.faceQuality(cg, orientation: VisionAnalyzer.orientation(image.imageOrientation))
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

    // MARK: - 分类规则（滑动卡片上的小标签也用这些）

    func isBlurry(_ item: PhotoItem) -> Bool {
        guard let a = item.analysis, !item.isScreenshot, !a.tags.contains(.qrCode) else { return false }
        return a.sharpness < blurThreshold
    }

    func isPoorLight(_ item: PhotoItem) -> Bool {
        guard let a = item.analysis else { return false }
        return VisionRules.isPoorLight(brightness: a.brightness, isScreenshot: item.isScreenshot,
                                       isUtility: a.isUtility, textHeavy: a.textHeavy,
                                       tags: a.tags, aspect: item.aspect)
    }

    func isLowQuality(_ item: PhotoItem) -> Bool {
        guard let a = item.analysis else { return false }
        return VisionRules.isLowQuality(aesthetics: a.aesthetics, isUtility: a.isUtility, isScreenshot: item.isScreenshot)
    }

    func isDocument(_ item: PhotoItem) -> Bool {
        guard let a = item.analysis, !item.isScreenshot else { return false }
        if a.tags.contains(.document) { return true }
        // 工具性照片（iOS 18 评分）且不是文字很多的聊天图 → 也算文档/票据
        return a.isUtility == true && !a.textHeavy && !a.tags.contains(.screenshotLike) && !a.tags.contains(.qrCode)
    }

    func isTextImage(_ item: PhotoItem) -> Bool {
        guard let a = item.analysis else { return false }
        if a.verificationCode != nil { return true }
        return !item.isScreenshot && a.textHeavy && !a.tags.contains(.document)
    }

    func rebuildCategories() {
        var map: [CleanCategory: [String]] = [:]
        let largeBytes = Int64(largeFileMB * 1_000_000)
        // 收藏的照片永远不进任何清理分类
        let pool = items.filter { !$0.isFavorite }
        let photos = pool.filter { !$0.isVideo }
        map[.screenshots] = pool.filter { $0.isScreenshot }.map(\.id)
        map[.videos] = pool.filter { $0.isVideo }.sorted { $0.fileSize > $1.fileSize }.map(\.id)
        map[.large] = photos.filter { $0.fileSize >= largeBytes }
            .sorted { $0.fileSize > $1.fileSize }.map(\.id)
        map[.blurry] = photos.filter { isBlurry($0) }
            .sorted { ($0.analysis?.sharpness ?? 0) < ($1.analysis?.sharpness ?? 0) }.map(\.id)
        map[.poorLight] = photos.filter { isPoorLight($0) }.map(\.id)
        map[.lowQuality] = photos.filter { isLowQuality($0) }
            .sorted { ($0.analysis?.aesthetics ?? 0) < ($1.analysis?.aesthetics ?? 0) }.map(\.id)
        map[.documents] = photos.filter { isDocument($0) }.map(\.id)
        map[.textImages] = photos.filter { isTextImage($0) }.map(\.id)
        map[.qrCodes] = photos.filter { $0.analysis?.tags.contains(.qrCode) == true }.map(\.id)
        map[.food] = photos.filter { !$0.isScreenshot && $0.analysis?.tags.contains(.food) == true }.map(\.id)
        map[.pets] = photos.filter { !$0.isScreenshot && $0.analysis?.tags.contains(.pet) == true }.map(\.id)
        map[.scenery] = photos.filter { !$0.isScreenshot && $0.analysis?.tags.contains(.scenery) == true }.map(\.id)
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

    /// 推荐保留的一张：人脸质量 → AI 美观评分 → 清晰度 → 分辨率
    func bestID(in group: [String]) -> String? {
        let its = group.compactMap { item($0) }
        guard !its.isEmpty else { return nil }
        let i = SimilarityGrouper.bestIndex(its.map {
            BestCandidate(faceQuality: $0.analysis?.faceQuality,
                          aesthetics: $0.analysis?.aesthetics,
                          sharpness: $0.analysis?.sharpness ?? 0,
                          pixels: $0.pixelCount)
        })
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
        // 收藏的照片永远不自动标记删除
        del.removeAll { $0 == best || item($0)?.isFavorite == true }
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

    /// 删除全部已标记项，返回 true 表示删除成功
    func deleteMarked() async -> Bool {
        await delete(Array(toDelete))
    }

    /// 删除指定项（系统会弹窗二次确认），返回 true 表示删除成功
    func delete(_ ids: [String]) async -> Bool {
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
        toDelete.subtract(gone)
        persist()
        rebuildCategories()
        lastDeleteMessage = "已删除 \(ids.count) 项，释放 \(Fmt.bytes(freed))。可在系统相册「最近删除」中恢复。"
        Haptics.success()
        return true
    }
}
