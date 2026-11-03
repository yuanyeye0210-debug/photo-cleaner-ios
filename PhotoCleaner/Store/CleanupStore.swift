import Photos
import SwiftUI
import WidgetKit

/// 全局状态：扫描、分类、标记、删除
@MainActor
final class CleanupStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, analyzing, paused, done
    }

    // MARK: 权限 & 扫描状态
    @Published var authStatus: PHAuthorizationStatus = PhotoLibraryService.authorizationStatus
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progress: Double = 0
    @Published private(set) var progressText: String = ""
    /// 往年今天拍的（只在照片列表变化时重算）
    @Published private(set) var onThisDayIDs: [String] = []
    /// 需要 AI 分析的照片总数 / 已有分析结果的数量（含缓存）
    @Published private(set) var analyzableCount = 0
    @Published private(set) var analyzedCount = 0

    // MARK: 数据
    @Published private(set) var items: [PhotoItem] = []
    @Published private(set) var categoryIDs: [CleanCategory: [String]] = [:]
    @Published private(set) var cleanableIDs: [String] = []
    @Published private(set) var similarGroups: [[String]] = []
    @Published private(set) var exactGroups: [[String]] = []
    @Published private(set) var burstGroups: [[String]] = []
    @Published private(set) var months: [MonthGroup] = []
    @Published private(set) var totalBytes: Int64 = 0
    /// 原图只在 iCloud、没下载所以没分析的照片
    @Published private(set) var cloudOnlyIDs: Set<String> = []

    // MARK: 用户决定（存成文件，下次打开还在）
    @Published private(set) var state = DecisionState()
    var toDelete: Set<String> { state.toDelete }
    var kept: Set<String> { state.kept }
    var later: Set<String> { state.later }

    // MARK: 统计
    @Published private(set) var stats = CleanupStats()
    @Published private(set) var randomSample: [String] = []

    // MARK: 设置
    @Published var blurThreshold: Double {
        didSet { defaults.set(blurThreshold, forKey: Keys.blur); rebuildCategories() }
    }
    @Published var largeFileMB: Double {
        didSet { defaults.set(largeFileMB, forKey: Keys.large); rebuildCategories() }
    }
    /// 允许从 iCloud 下载原图来分析（会用流量）
    @Published var allowCloudAnalysis: Bool {
        didSet {
            defaults.set(allowCloudAnalysis, forKey: Keys.cloud)
            if allowCloudAnalysis && !cloudOnlyIDs.isEmpty && !isScanning { startScan() }
        }
    }

    @Published var lastDeleteMessage: String?

    private var index: [String: Int] = [:]
    private var burstKeeperIDs: Set<String> = []
    private let defaults = UserDefaults.standard
    private var scanTask: Task<Void, Never>?
    private var sizeTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var cache: AnalysisCache?
    private var pauseRequested = false
    private var needsRefresh = false
    private var observer: LibraryObserver?

    private enum Keys {
        static let blur = "blurThreshold"
        static let large = "largeFileMB"
        static let cloud = "allowCloudAnalysis"
        // 旧版本存在 UserDefaults 里，第一次启动时迁移到文件
        static let legacyToDelete = "toDeleteIDs"
        static let legacyKept = "keptIDs"
        static let legacyLimit = "analyzeLimit"
    }

    // MARK: 文件位置（Application Support，不会被系统清掉）
    nonisolated static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PhotoCleaner", isDirectory: true)
    }
    nonisolated static var cacheURL: URL { folder.appendingPathComponent("analysis-cache.plist") }
    nonisolated static var decisionsURL: URL { folder.appendingPathComponent("decisions.json") }
    nonisolated static var statsURL: URL { folder.appendingPathComponent("stats.json") }

    init() {
        let d = UserDefaults.standard
        blurThreshold = d.object(forKey: Keys.blur) as? Double ?? 60
        largeFileMB = d.object(forKey: Keys.large) as? Double ?? 8
        allowCloudAnalysis = d.bool(forKey: Keys.cloud)
        if let s = DecisionState.load(from: Self.decisionsURL) {
            state = s
        } else {
            var s = DecisionState()
            s.toDelete = Set(d.stringArray(forKey: Keys.legacyToDelete) ?? [])
            s.kept = Set(d.stringArray(forKey: Keys.legacyKept) ?? [])
            state = s
            try? s.save(to: Self.decisionsURL)
            d.removeObject(forKey: Keys.legacyToDelete)
            d.removeObject(forKey: Keys.legacyKept)
        }
        d.removeObject(forKey: Keys.legacyLimit)
        stats = CleanupStats.load(from: Self.statsURL)
        observer = LibraryObserver { [weak self] in
            Task { @MainActor in self?.libraryChanged() }
        }
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

    var isScanning: Bool { phase == .loading || phase == .analyzing }

    /// 增量扫描：读取相册 → 只分析缓存里没有（或编辑过）的照片
    func startScan() {
        guard hasAccess else { return }
        observer?.register()
        pauseRequested = false
        needsRefresh = false
        scanTask?.cancel()
        scanTask = Task { await scan() }
    }

    func pauseAnalysis() {
        guard phase == .analyzing else { return }
        pauseRequested = true
    }

    func resumeAnalysis() { startScan() }

    /// 相册变了（别的 App 拍照、删除、编辑）：等 1.5 秒没有新变化再刷新
    private func libraryChanged() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            if isScanning || phase == .paused { needsRefresh = true } else { startScan() }
        }
    }

    /// 清除分析缓存并重新分析全部照片
    func resetAnalysisCache() {
        cache?.removeAll()
        try? FileManager.default.removeItem(at: Self.cacheURL)
        startScan()
    }

    var cachedCount: Int { cache?.count ?? 0 }

    private struct Built: @unchecked Sendable {
        var items: [PhotoItem] = []
        var bursts: [[String]] = []
        var keepers: Set<String> = []
        var todo: [String] = []
        var cloudOnly: Set<String> = []
        var analyzable = 0
    }

    private func scan() async {
        phase = .loading
        progress = 0
        progressText = String(localized: "正在读取相册…")

        if cache == nil {
            let url = Self.cacheURL
            cache = await Task.detached(priority: .userInitiated) { AnalysisCache.load(from: url) }.value
        }
        guard let cache else { return }
        let allowCloud = allowCloudAnalysis

        // 1. 读取元数据（不读真实文件大小，先用缓存或估算值，后台再补）
        let built = await Task.detached(priority: .userInitiated) {
            Self.buildItems(cache: cache, allowCloud: allowCloud)
        }.value
        if Task.isCancelled { return }

        setItems(built.items)
        burstGroups = built.bursts
        burstKeeperIDs = built.keepers
        cloudOnlyIDs = built.cloudOnly
        analyzableCount = built.analyzable
        analyzedCount = built.analyzable - built.todo.count - built.cloudOnly.count
        let existing = Set(index.keys)
        state.prune(existing: existing)
        persistDecisions()
        cache.prune(keeping: existing)
        similarGroups = similarGroups.map { $0.filter { existing.contains($0) } }.filter { $0.count > 1 }
        exactGroups = exactGroups.map { $0.filter { existing.contains($0) } }.filter { $0.count > 1 }
        rebuildCategories()

        // 2. 后台补真实文件大小
        startSizePass()

        // 3. 只分析新照片（缓存里没有的）。同时最多 4 张并行，结果成批写回界面
        phase = .analyzing
        let todo = built.todo.compactMap { item($0) }
        let paused = await analyze(todo, cache: cache, allowCloud: allowCloud)
        if Task.isCancelled { return }
        applyPending(final: true)

        if paused {
            await finishGrouping(cache: cache)
            if Task.isCancelled { return }
            phase = .paused
            progressText = String(localized: "已暂停分析")
            saveCache()
            updateWidget()
            return
        }

        // 4. 分组：完全重复（需要真实大小）、相似、人脸质量
        await sizeTask?.value
        if Task.isCancelled { return }
        await findExactDuplicates(cache: cache)
        if Task.isCancelled { return }
        await finishGrouping(cache: cache)
        if Task.isCancelled { return }
        await scoreFaces(cache: cache)
        if Task.isCancelled { return }

        rebuildCategories()
        progress = 1
        progressText = String(localized: "分析完成")
        phase = .done
        saveCache()
        updateWidget()
        if !todo.isEmpty { Haptics.success() }
        if needsRefresh { startScan() }
    }

    nonisolated private static func makeItem(_ a: PHAsset, cache: AnalysisCache) -> PhotoItem {
        let mod = a.modificationDate
        let e = cache.entry(for: a.localIdentifier, modified: mod)
        let isVideo = a.mediaType == .video
        let est = FileSizes.estimate(pixelWidth: a.pixelWidth, pixelHeight: a.pixelHeight,
                                     isVideo: isVideo, duration: a.duration)
        return PhotoItem(id: a.localIdentifier,
                         asset: a,
                         fileSize: e?.size ?? est,
                         sizeExact: e?.size != nil,
                         liveVideoBytes: e?.liveVideoBytes ?? 0,
                         creationDate: a.creationDate,
                         modificationDate: mod,
                         isVideo: isVideo,
                         isScreenshot: a.mediaSubtypes.contains(.photoScreenshot),
                         isFavorite: a.isFavorite,
                         isLivePhoto: a.mediaSubtypes.contains(.photoLive),
                         duration: a.duration,
                         burstID: a.burstIdentifier,
                         pixelWidth: a.pixelWidth,
                         pixelHeight: a.pixelHeight,
                         analysis: e?.result)
    }

    nonisolated private static func buildItems(cache: AnalysisCache, allowCloud: Bool) -> Built {
        var b = Built()
        let assets = PhotoLibraryService.shared.fetchAllAssets()
        b.items.reserveCapacity(assets.count)
        for a in assets {
            b.items.append(makeItem(a, cache: cache))
            // 连拍：把系统相册里默认不显示的帧也取出来
            guard a.representsBurst, let bid = a.burstIdentifier else { continue }
            let frames = PhotoLibraryService.shared.burstFrames(bid)
            guard frames.count > 1 else { continue }
            var ids: [String] = []
            var fr: [BurstRules.Frame] = []
            for f in frames {
                if f.localIdentifier != a.localIdentifier {
                    var it = makeItem(f, cache: cache)
                    it.burstHidden = true
                    it.burstID = bid
                    b.items.append(it)
                }
                ids.append(f.localIdentifier)
                fr.append(.init(id: f.localIdentifier,
                                userPick: f.burstSelectionTypes.contains(.userPick),
                                autoPick: f.burstSelectionTypes.contains(.autoPick),
                                representative: f.representsBurst))
            }
            if let k = BurstRules.keeper(fr) { b.keepers.insert(k) }
            b.bursts.append(ids)
        }
        // 视频、收藏、隐藏的连拍帧不分析；新的照片先分析
        let plan = AnalysisPlanner.plan(b.items.map {
            AnalysisPlanner.Asset(id: $0.id, modified: $0.modificationDate,
                                  analyzable: !$0.isVideo && !$0.isFavorite && !$0.burstHidden)
        }, cache: cache, skipCloudOnly: !allowCloud)
        b.todo = plan.todo
        b.cloudOnly = plan.cloudOnly
        b.analyzable = b.items.reduce(0) { $0 + ((!$1.isVideo && !$1.isFavorite && !$1.burstHidden) ? 1 : 0) }
        return b
    }

    // MARK: 分析

    private var pendingResults: [(String, AnalysisResult?, Bool)] = []
    private var lastApply = Date()
    private var appliedSinceRebuild = 0

    /// 返回 true 表示被用户暂停
    private func analyze(_ todo: [PhotoItem], cache: AnalysisCache, allowCloud: Bool) async -> Bool {
        let total = todo.count
        guard total > 0 else { return false }
        var done = 0
        var next = 0
        var sinceSave = 0
        let maxConcurrent = 4
        var paused = false
        progressText = String(localized: "正在用 AI 分析照片…")
        await withTaskGroup(of: (String, AnalysisResult?, Bool).self) { group in
            while next < min(maxConcurrent, total) {
                group.addTask(operation: Self.analyzeOp(todo[next], allowCloud: allowCloud)); next += 1
            }
            while let r = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                let mod = item(r.0)?.modificationDate
                cache.setResult(r.1, for: r.0, modified: mod, cloudOnly: r.1 == nil && r.2)
                pendingResults.append(r)
                done += 1
                sinceSave += 1
                if pauseRequested {
                    paused = true
                    group.cancelAll()
                    break
                }
                if next < total { group.addTask(operation: Self.analyzeOp(todo[next], allowCloud: allowCloud)); next += 1 }
                if pendingResults.count >= 24 || Date().timeIntervalSince(lastApply) > 0.6 || done == total {
                    applyPending(final: false)
                    progress = Double(done) / Double(total)
                }
                if sinceSave >= 1000 { sinceSave = 0; saveCache() }
            }
        }
        return paused
    }

    /// 一次性写回一批分析结果（减少界面刷新次数）
    private func applyPending(final: Bool) {
        lastApply = Date()
        guard !pendingResults.isEmpty else {
            if final { rebuildCategories() }
            return
        }
        var copy = items
        var cloud = cloudOnlyIDs
        for (id, r, inCloud) in pendingResults {
            if let i = index[id] { copy[i].analysis = r }
            if r == nil && inCloud { cloud.insert(id) } else { cloud.remove(id) }
            if r != nil { analyzedCount += 1 }
        }
        appliedSinceRebuild += pendingResults.count
        pendingResults.removeAll()
        items = copy
        if cloud != cloudOnlyIDs { cloudOnlyIDs = cloud }
        if final || appliedSinceRebuild >= 600 {
            appliedSinceRebuild = 0
            rebuildCategories()
        }
    }

    /// 单张照片的完整分析：dHash / 清晰度 / 亮度 + Vision（特征、内容、美观、二维码），候选再做文字识别。
    /// 第二个返回值：原图只在 iCloud、没能分析
    nonisolated static func analyzeAsset(_ asset: PHAsset, isScreenshot: Bool, allowNetwork: Bool) async -> (AnalysisResult?, Bool) {
        let (image, inCloud) = await PhotoLibraryService.shared.analysisImage(for: asset, side: 384, allowNetwork: allowNetwork)
        guard let image, let cg = image.cgImage, var r = ImageAnalyzer.analyze(cg) else { return (nil, inCloud) }
        if Task.isCancelled { return (r, false) }
        let v = VisionAnalyzer.analyze(cg, orientation: VisionAnalyzer.orientation(image.imageOrientation))
        r.feature = v.feature.flatMap { QFeature(normalized: $0) }
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
                                                                allowNetwork: allowNetwork,
                                                                cache: false),
               let bcg = big.cgImage {
                let lines = VisionAnalyzer.recognizeText(bcg, orientation: VisionAnalyzer.orientation(big.imageOrientation))
                r.textChecked = true
                r.textLines = lines.count
                r.textChars = lines.reduce(0) { $0 + $1.count }
                r.verificationCode = VisionRules.verificationCode(in: lines)
            }
        }
        return (r, false)
    }

    nonisolated private static func analyzeOp(_ it: PhotoItem, allowCloud: Bool) -> @Sendable () async -> (String, AnalysisResult?, Bool) {
        let asset = it.asset, shot = it.isScreenshot
        return {
            let (r, cloud) = await CleanupStore.analyzeAsset(asset, isScreenshot: shot, allowNetwork: allowCloud)
            return (asset.localIdentifier, r, cloud)
        }
    }

    nonisolated private static func hashOp(_ it: PhotoItem) -> @Sendable () async -> (String, String?) {
        let asset = it.asset
        return { (asset.localIdentifier, await PhotoLibraryService.sha256(of: asset)) }
    }

    nonisolated private static func faceOp(_ it: PhotoItem) -> @Sendable () async -> (String, Float?) {
        let asset = it.asset
        return { (asset.localIdentifier, await CleanupStore.faceQuality(asset)) }
    }

    nonisolated static func faceQuality(_ asset: PHAsset) async -> Float? {
        guard let image = await PhotoLibraryService.shared.image(for: asset,
                                                                 targetSize: CGSize(width: 768, height: 768),
                                                                 contentMode: .aspectFit,
                                                                 cache: false),
              let cg = image.cgImage else { return nil }
        return VisionAnalyzer.faceQuality(cg, orientation: VisionAnalyzer.orientation(image.imageOrientation))
    }

    // MARK: 文件大小（后台批量读，结果进缓存）

    private func startSizePass() {
        sizeTask?.cancel()
        guard let cache else { return }
        let targets = items.filter { !$0.sizeExact }.map { ($0.id, $0.asset, $0.modificationDate) }
        guard !targets.isEmpty else { sizeTask = nil; return }
        sizeTask = Task(priority: .utility) {
            var start = 0
            var chunks = 0
            while start < targets.count {
                if Task.isCancelled { return }
                let chunk = Array(targets[start..<min(start + 300, targets.count)])
                start += 300
                let res: [(String, Int64, Int64)] = await Task.detached(priority: .utility) {
                    chunk.compactMap { (id, asset, mod) in
                        guard let s = PhotoLibraryService.resourceSizes(of: asset) else { return nil }
                        cache.setSize(s.total, liveVideoBytes: s.liveVideo, for: id, modified: mod)
                        return (id, s.total, s.liveVideo)
                    }
                }.value
                if Task.isCancelled { return }
                var copy = items
                for (id, total, live) in res {
                    guard let i = index[id] else { continue }
                    copy[i].fileSize = total
                    copy[i].sizeExact = true
                    copy[i].liveVideoBytes = live
                }
                items = copy
                totalBytes = copy.reduce(0) { $0 + $1.fileSize }
                chunks += 1
                if chunks % 10 == 0 { rebuildCategories() }
            }
            rebuildCategories()
        }
    }

    // MARK: 分组

    /// 完全重复：同尺寸、同大小的才算 SHA-256（结果进缓存）
    private func findExactDuplicates(cache: AnalysisCache) async {
        let cands = items.filter { $0.sizeExact && !$0.isFavorite && !$0.burstHidden }
            .map { ExactDuplicates.Candidate(id: $0.id, width: $0.pixelWidth, height: $0.pixelHeight, size: $0.fileSize) }
        let ids = ExactDuplicates.buckets(cands).flatMap { $0 }
        guard !ids.isEmpty else { exactGroups = []; return }
        progressText = String(localized: "正在查找完全重复的文件…")
        var digests: [String: String] = [:]
        var todo: [PhotoItem] = []
        for id in ids {
            guard let it = item(id) else { continue }
            if let d = cache.entry(for: id, modified: it.modificationDate)?.digest { digests[id] = d } else { todo.append(it) }
        }
        var next = 0
        await withTaskGroup(of: (String, String?).self) { group in
            while next < min(2, todo.count) { group.addTask(operation: Self.hashOp(todo[next])); next += 1 }
            while let r = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                let id = r.0, d = r.1
                if let d {
                    digests[id] = d
                    cache.update(id, modified: item(id)?.modificationDate) { $0.digest = d }
                }
                if next < todo.count { group.addTask(operation: Self.hashOp(todo[next])); next += 1 }
            }
        }
        exactGroups = ExactDuplicates.groups(digests: digests)
    }

    /// 相似分组（AI 特征 + dHash + 拍摄时间），截图、收藏、隐藏的连拍帧不参与；去掉已经算完全重复的
    private func finishGrouping(cache: AnalysisCache) async {
        progressText = String(localized: "正在查找相似照片…")
        let entries = items.compactMap { item -> HashEntry? in
            guard let a = item.analysis, !item.isScreenshot, !item.isFavorite, !item.burstHidden else { return nil }
            return HashEntry(id: item.id, hash: a.dHash, time: item.creationDate?.timeIntervalSince1970,
                             qfeature: a.feature)
        }
        let groups = await Task.detached(priority: .userInitiated) {
            SimilarityGrouper.groups(entries)
        }.value
        if Task.isCancelled { return }
        let exact = exactGroups
        similarGroups = ExactDuplicates.subtract(groups, exact: exact) { self.keeperID(in: $0, category: .exactDuplicates) }
        rebuildCategories()
    }

    /// 相似组里的照片算人脸质量，用来挑「推荐保留」（算过的进缓存，不重复算）
    private func scoreFaces(cache: AnalysisCache) async {
        let targets = similarGroups.flatMap { $0 }.compactMap { item($0) }.filter { $0.analysis?.faceChecked != true }
        guard !targets.isEmpty else { return }
        progressText = String(localized: "正在挑选每组最好的一张…")
        var next = 0
        var results: [(String, Float?)] = []
        await withTaskGroup(of: (String, Float?).self) { group in
            while next < min(4, targets.count) { group.addTask(operation: Self.faceOp(targets[next])); next += 1 }
            while let r = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                results.append(r)
                if next < targets.count { group.addTask(operation: Self.faceOp(targets[next])); next += 1 }
            }
        }
        var copy = items
        for (id, q) in results {
            guard let i = index[id], var a = copy[i].analysis else { continue }
            a.faceChecked = true
            a.faceQuality = q
            copy[i].analysis = a
            cache.update(id, modified: copy[i].modificationDate) { $0.result = a }
        }
        items = copy
    }

    private func setItems(_ new: [PhotoItem]) {
        items = new
        index = Dictionary(new.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        totalBytes = new.reduce(0) { $0 + $1.fileSize }
        onThisDayIDs = BatchModes.onThisDay(quickPool.map { ($0.id, $0.creationDate) })
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
        // 收藏的照片永远不进任何清理分类；隐藏的连拍帧只出现在「连拍」里
        let pool = items.filter { !$0.isFavorite && !$0.burstHidden }
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
        map[.livePhotos] = photos.filter { $0.isLivePhoto && !$0.isScreenshot }
            .sorted { $0.liveVideoBytes > $1.liveVideoBytes }.map(\.id)
        map[.similar] = similarGroups.flatMap { $0 }
        map[.exactDuplicates] = exactGroups.flatMap { $0 }
        map[.bursts] = burstGroups.flatMap { $0 }.filter { item($0)?.isFavorite == false }
        categoryIDs = map
        // 可清理：不含视频、大文件、实况照片和美食/宠物/风景这种「看情况」的类别
        cleanableIDs = Array(Set(CleanCategory.allCases
            .filter { $0 != .videos && $0 != .large && $0 != .livePhotos && !$0.isBrowse }
            .flatMap { map[$0] ?? [] }))

        // 按月
        let cal = Calendar.current
        var buckets: [String: [String]] = [:]
        var titles: [String: String] = [:]
        for item in items where !item.burstHidden {
            guard let d = item.creationDate else { continue }
            let c = cal.dateComponents([.year, .month], from: d)
            let key = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            buckets[key, default: []].append(item.id)
            if titles[key] == nil { titles[key] = Fmt.monthFormatter.string(from: d) }
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

    func groups(for category: CleanCategory) -> [[String]] {
        switch category {
        case .exactDuplicates: return exactGroups
        case .bursts: return burstGroups.map { $0.filter { item($0)?.isFavorite == false || burstKeeperIDs.contains($0) } }
                                        .filter { $0.count > 1 }
        default: return similarGroups
        }
    }

    func bytes(of ids: [String]) -> Int64 {
        ids.reduce(0) { $0 + (item($1)?.fileSize ?? 0) }
    }

    func bytes(of ids: Set<String>) -> Int64 {
        ids.reduce(0) { $0 + (item($1)?.fileSize ?? 0) }
    }

    var toDeleteBytes: Int64 { bytes(of: state.toDelete) }

    /// 删掉待删除列表真正能省下的空间（压缩 / 转换过的原件只算差值）
    var toDeleteFreedBytes: Int64 {
        state.toDelete.reduce(0) { $0 + state.freedBytes(id: $1, size: item($1)?.fileSize ?? 0) }
    }

    func decision(for id: String) -> Decision? {
        if state.toDelete.contains(id) { return .delete }
        if state.kept.contains(id) { return .keep }
        return nil
    }

    /// 尚未决定的项目（「稍后再看」的也先跳过）
    func undecided(_ ids: [String], includeLater: Bool = false) -> [String] {
        ids.filter { !state.toDelete.contains($0) && !state.kept.contains($0) && (includeLater || !state.later.contains($0)) }
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

    /// 每组保留哪张：完全重复留最早的原件，连拍留系统选中的那张，相似留最好的
    func keeperID(in group: [String], category: CleanCategory) -> String? {
        switch category {
        case .exactDuplicates:
            return group.compactMap { item($0) }.min {
                ($0.creationDate ?? .distantFuture, $0.id) < ($1.creationDate ?? .distantFuture, $1.id)
            }?.id
        case .bursts:
            return group.first { burstKeeperIDs.contains($0) } ?? group.first
        default:
            return bestID(in: group)
        }
    }

    var hasPendingFailures: Bool { !state.failed.isEmpty }
    var failedCount: Int { state.failed.count }

    // MARK: - 小批量模式

    private var quickPool: [PhotoItem] { items.filter { !$0.isFavorite && !$0.burstHidden } }

    func quickIDs(_ mode: QuickMode) -> [String] {
        switch mode {
        case .onThisDay:
            return onThisDayIDs
        case .random:
            return randomSample
        case .later:
            return items.filter { state.later.contains($0.id) }.map(\.id)
        }
    }

    /// 重新抽 10 张还没整理过的
    func newRandomSample() {
        randomSample = BatchModes.random(undecided(quickPool.map(\.id)), count: 10)
    }

    func isMonthCleaned(_ id: String) -> Bool { state.cleanedMonths.contains(id) }

    func toggleMonthCleaned(_ id: String) {
        if state.cleanedMonths.contains(id) { state.cleanedMonths.remove(id) } else { state.cleanedMonths.insert(id) }
        persistDecisions()
    }

    // MARK: - 标记

    func set(_ id: String, _ decision: Decision?) {
        switch decision {
        case .delete:
            state.toDelete.insert(id); state.kept.remove(id)
        case .keep:
            state.kept.insert(id); state.toDelete.remove(id)
        case .none:
            state.toDelete.remove(id); state.kept.remove(id)
        }
        state.later.remove(id)
        persistDecisions()
    }

    /// 上滑：稍后再看（不删也不留，从队列里先拿走）
    func setLater(_ id: String) {
        state.toDelete.remove(id); state.kept.remove(id)
        state.later.insert(id)
        persistDecisions()
    }

    func toggleDelete(_ id: String) {
        set(id, state.toDelete.contains(id) ? nil : .delete)
    }

    func markAll(_ ids: [String], _ decision: Decision?) {
        var s = state
        for id in ids {
            switch decision {
            case .delete: s.toDelete.insert(id); s.kept.remove(id)
            case .keep: s.kept.insert(id); s.toDelete.remove(id)
            case .none: s.toDelete.remove(id); s.kept.remove(id)
            }
            s.later.remove(id)
        }
        state = s
        persistDecisions()
    }

    /// 一组里保留最佳，其余标记删除
    func keepBestDeleteRest(_ group: [String], category: CleanCategory = .similar) {
        guard let best = keeperID(in: group, category: category) else { return }
        var del = group
        // 收藏的照片永远不自动标记删除
        del.removeAll { $0 == best || item($0)?.isFavorite == true }
        markAll(del, .delete)
        set(best, .keep)
    }

    /// 整组全部删除（不保留任何一张；收藏的不动）。返回实际标记的数量
    @discardableResult
    func deleteWholeGroup(_ group: [String]) -> Int {
        let del = GroupActions.deleteAll(group) { item($0)?.isFavorite == true }
        markAll(del, .delete)
        return del.count
    }

    /// 完全重复 / 连拍：所有组一键只留一张
    func keepOneInAllGroups(_ category: CleanCategory) {
        var del: [String] = [], keep: [String] = []
        for g in groups(for: category) {
            guard let k = keeperID(in: g, category: category) else { continue }
            keep.append(k)
            del.append(contentsOf: g.filter { $0 != k && item($0)?.isFavorite != true })
        }
        markAll(del, .delete)
        markAll(keep, .keep)
    }

    func resetKept() {
        state.kept.removeAll()
        persistDecisions()
    }

    /// 压缩 / 转换成功：原件进待删除，记下新文件大小
    func registerReplacement(original: String, newBytes: Int64) {
        state.replacements[original] = newBytes
        state.toDelete.insert(original)
        state.kept.remove(original)
        state.later.remove(original)
        persistDecisions()
    }

    func isReplaced(_ id: String) -> Bool { state.replacements[id] != nil }

    // MARK: - 保存

    /// 决定改了：0.4 秒后写文件（连续滑动只写一次）
    private func persistDecisions() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            writeDecisions()
            updateWidget()
        }
    }

    private func writeDecisions() {
        let s = state, url = Self.decisionsURL
        Task.detached(priority: .utility) { try? s.save(to: url) }
    }

    private func saveCache() {
        guard let cache, cache.isDirty else { return }
        let url = Self.cacheURL
        Task.detached(priority: .utility) { try? cache.save(to: url) }
    }

    private func saveStats() {
        let s = stats, url = Self.statsURL
        Task.detached(priority: .utility) { try? s.save(to: url) }
    }

    /// 切到后台：立刻保存全部
    func flush() {
        saveTask?.cancel()
        writeDecisions()
        saveCache()
        updateWidget()
    }

    /// 给桌面小组件的数据（App Group；免费签名下可能不可用，小组件会自己读相册数量）
    func updateWidget() {
        let snap = WidgetSnapshot(cleanableCount: cleanableIDs.count,
                                  cleanableBytes: bytes(of: cleanableIDs),
                                  screenshots: ids(in: .screenshots).count,
                                  pending: state.toDelete.count,
                                  freedTotal: stats.totalBytes,
                                  updated: Date())
        if let d = UserDefaults(suiteName: WidgetSnapshot.appGroup) {
            d.set(snap.encoded(), forKey: WidgetSnapshot.key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 删除

    /// 删除全部已标记项，返回 true 表示至少删掉了一项
    func deleteMarked() async -> Bool {
        await delete(Array(state.toDelete))
    }

    /// 删除指定项（系统会弹窗二次确认）。一项一项核对：成功的移除，失败的留在待删除里
    func delete(_ ids: [String]) async -> Bool {
        guard !ids.isEmpty else { return false }
        var sizes: [String: Int64] = [:]
        for id in ids { sizes[id] = state.freedBytes(id: id, size: item(id)?.fileSize ?? 0) }
        let r = await PhotoLibraryService.shared.delete(ids: ids)
        let o = r.outcome
        if o.cancelled {
            lastDeleteMessage = String(localized: "已取消删除")
            return false
        }
        let deletedNow = o.deleted.filter { r.existedBefore.contains($0) }
        let freed = deletedNow.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
        let gone = Set(o.deleted)
        if !gone.isEmpty { removeItems(gone) }
        var s = state
        s.toDelete.subtract(gone)
        s.failed = Set(o.failed)
        s.prune(existing: Set(index.keys))
        state = s
        writeDecisions()
        if !deletedNow.isEmpty {
            stats.record(.deleted, count: deletedNow.count, bytes: freed)
            saveStats()
        }
        updateWidget()
        if o.failed.isEmpty {
            lastDeleteMessage = String(localized: "已删除 \(o.deleted.count) 项，释放 \(Fmt.bytes(freed))。可在系统相册「最近删除」中恢复。")
            Haptics.success()
        } else if o.deleted.isEmpty {
            lastDeleteMessage = String(localized: "没有删掉：\(r.error ?? String(localized: "系统拒绝了删除"))。照片还在待删除里，可以再试一次。")
        } else {
            lastDeleteMessage = String(localized: "已删除 \(o.deleted.count) 项，释放 \(Fmt.bytes(freed))；有 \(o.failed.count) 项没删掉，还留在待删除里。")
            Haptics.success()
        }
        return !o.deleted.isEmpty
    }

    private func removeItems(_ gone: Set<String>) {
        setItems(items.filter { !gone.contains($0.id) })
        func strip(_ g: [[String]]) -> [[String]] {
            g.map { $0.filter { !gone.contains($0) } }.filter { $0.count > 1 }
        }
        similarGroups = strip(similarGroups)
        exactGroups = strip(exactGroups)
        burstGroups = strip(burstGroups)
        cloudOnlyIDs.subtract(gone)
        randomSample.removeAll { gone.contains($0) }
        rebuildCategories()
    }
}
