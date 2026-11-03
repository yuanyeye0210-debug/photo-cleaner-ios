import CryptoKit
import Photos
import UIKit

/// 封装 PhotoKit：权限、读取、缩略图、删除
/// NSCache 和 PHCachingImageManager 都是线程安全的
final class PhotoLibraryService: @unchecked Sendable {
    static let shared = PhotoLibraryService()
    let imageManager = PHCachingImageManager()
    /// 内存缓存分两档：小图（缩略图，最长边 ≤ 600 像素）和大图（卡片 / 全屏）。
    /// 以前只留「最大的一张」，缩略图格子里也画的是卡片大图，滚动时很费。
    private let thumbCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 600
        return c
    }()
    private let largeCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 24
        return c
    }()
    static let thumbMaxPixels: CGFloat = 600

    /// 卡片 / 大图先显示：优先大图
    func cachedImage(for id: String) -> UIImage? {
        largeCache.object(forKey: id as NSString) ?? thumbCache.object(forKey: id as NSString)
    }

    /// 缩略图先显示：优先小图
    func cachedThumbnail(for id: String) -> UIImage? {
        thumbCache.object(forKey: id as NSString) ?? largeCache.object(forKey: id as NSString)
    }

    private func remember(_ img: UIImage, for id: String) {
        let key = id as NSString
        let side = max(img.size.width, img.size.height) * img.scale
        let cache = side <= Self.thumbMaxPixels ? thumbCache : largeCache
        if let old = cache.object(forKey: key),
           max(old.size.width, old.size.height) * old.scale >= side { return }
        cache.setObject(img, forKey: key)
    }

    /// 在后台线程先解码好（不然第一次显示时在主线程解码 HEIC/JPEG，滑动会掉帧）
    static func prepared(_ img: UIImage) async -> UIImage {
        await img.byPreparingForDisplay() ?? img
    }

    /// 卡片用的请求参数（预取 startCaching 和真正请求必须用同一套，缓存才命中）
    static func cardOptions() -> PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        return options
    }

    /// 预取：提前让 PhotoKit 准备好这几张（固定尺寸）；不再需要的停掉
    func updateCaching(start: [PHAsset], stop: [PHAsset], targetSize: CGSize) {
        guard targetSize.width > 0, targetSize.height > 0 else { return }
        if !stop.isEmpty {
            imageManager.stopCachingImages(for: stop, targetSize: targetSize, contentMode: .aspectFill, options: Self.cardOptions())
        }
        if !start.isEmpty {
            imageManager.startCachingImages(for: start, targetSize: targetSize, contentMode: .aspectFill, options: Self.cardOptions())
        }
    }

    private init() {
        imageManager.allowsCachingHighQualityImages = false
    }

    static var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// 读取全部照片和视频（新的在前）
    func fetchAllAssets() -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d",
                                     PHAssetMediaType.image.rawValue,
                                     PHAssetMediaType.video.rawValue)
        let result = PHAsset.fetchAssets(with: opts)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    /// 连拍的全部帧（包括系统相册里默认不显示的）
    func burstFrames(_ burstID: String) -> [PHAsset] {
        let opts = PHFetchOptions()
        opts.includeAllBurstAssets = true
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let r = PHAsset.fetchAssets(withBurstIdentifier: burstID, options: opts)
        var out: [PHAsset] = []
        r.enumerateObjects { a, _, _ in out.append(a) }
        return out
    }

    /// 这些照片里还在相册中的
    func existingIDs(_ ids: [String]) -> Set<String> {
        guard !ids.isEmpty else { return [] }
        let r = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var out = Set<String>()
        r.enumerateObjects { a, _, _ in out.insert(a.localIdentifier) }
        return out
    }

    /// 真实文件大小：累加该资源的所有文件（实况照片含视频部分）。
    /// PHAssetResource 的 fileSize 通过 KVC 读取（社区常用做法）；取不到返回 nil。
    /// 比较慢（每张约 1~3ms），只在后台批量调用。
    static func resourceSizes(of asset: PHAsset) -> (total: Int64, liveVideo: Int64)? {
        let resources = PHAssetResource.assetResources(for: asset)
        var total: Int64 = 0, live: Int64 = 0
        for r in resources {
            guard let n = r.value(forKey: "fileSize") as? NSNumber else { continue }
            total += n.int64Value
            if r.type == .pairedVideo || r.type == .fullSizePairedVideo { live = max(live, n.int64Value) }
        }
        return total > 0 ? (total, live) : nil
    }

    /// 原文件的 SHA-256（不联网；原图只在 iCloud 时返回 nil）
    static func sha256(of asset: PHAsset) async -> String? {
        let resources = PHAssetResource.assetResources(for: asset)
        let primaryTypes: [PHAssetResourceType] = asset.mediaType == .video ? [.video] : [.photo]
        guard let res = resources.first(where: { primaryTypes.contains($0.type) }) ?? resources.first else { return nil }
        let opts = PHAssetResourceRequestOptions()
        opts.isNetworkAccessAllowed = false
        final class Hasher: @unchecked Sendable { var h = SHA256() }
        let hasher = Hasher()
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            PHAssetResourceManager.default().requestData(for: res, options: opts) { chunk in
                hasher.h.update(data: chunk)
            } completionHandler: { error in
                if error != nil { cont.resume(returning: nil); return }
                let d = hasher.h.finalize()
                cont.resume(returning: d.map { String(format: "%02x", $0) }.joined())
            }
        }
    }

    /// 分析用的小图：同时告诉调用方「原图只在 iCloud、没下载」
    func analysisImage(for asset: PHAsset, side: CGFloat, allowNetwork: Bool) async -> (UIImage?, inCloud: Bool) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowNetwork
        options.isSynchronous = false
        return await withCheckedContinuation { (cont: CheckedContinuation<(UIImage?, inCloud: Bool), Never>) in
            imageManager.requestImage(for: asset, targetSize: CGSize(width: side, height: side),
                                      contentMode: .aspectFit, options: options) { image, info in
                let cloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                cont.resume(returning: (image, cloud && image == nil))
            }
        }
    }

    /// 请求一张图片（只回调一次的 highQualityFormat 模式）
    func image(for asset: PHAsset,
               targetSize: CGSize,
               contentMode: PHImageContentMode = .aspectFill,
               allowNetwork: Bool = false,
               cache: Bool = true) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowNetwork
        options.isSynchronous = false
        let img = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
            imageManager.requestImage(for: asset,
                                      targetSize: targetSize,
                                      contentMode: contentMode,
                                      options: options) { image, _ in
                cont.resume(returning: image)
            }
        }
        guard let raw = img else { return nil }
        // 要显示的图先在后台解码；分析用的（cache = false）不需要
        guard cache else { return raw }
        let ready = await Self.prepared(raw)
        remember(ready, for: asset.localIdentifier)
        return ready
    }

    /// 渐进加载：先尽快给一张低清图（本地已有的），再给高清图。用于全屏大图。
    func progressiveImages(for asset: PHAsset,
                           targetSize: CGSize,
                           contentMode: PHImageContentMode = .aspectFit) -> AsyncStream<(UIImage, Bool)> {
        AsyncStream { continuation in
            let options = Self.cardOptions()
            let id = imageManager.requestImage(for: asset,
                                               targetSize: targetSize,
                                               contentMode: contentMode,
                                               options: options) { [weak self] image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let failed = info?[PHImageErrorKey] != nil || ((info?[PHImageCancelledKey] as? Bool) ?? false)
                if let image, degraded {
                    continuation.yield((image, false))      // 低清图很小，直接给
                    if failed { continuation.finish() }
                } else if let image {
                    // 高清图先在后台解码好再显示
                    Task.detached(priority: .userInitiated) {
                        let ready = await PhotoLibraryService.prepared(image)
                        self?.remember(ready, for: asset.localIdentifier)
                        continuation.yield((ready, true))
                        continuation.finish()
                    }
                } else if !degraded || failed {
                    continuation.finish()
                }
            }
            continuation.onTermination = { [weak self] _ in
                self?.imageManager.cancelImageRequest(id)
            }
        }
    }

    /// 真正删除：系统会弹出“允许删除 N 张照片吗？”确认框。
    /// 删除后照片进入系统相册的“最近删除”，30 天内可恢复。
    /// 删完再查一遍哪些还在，区分成功 / 部分失败 / 用户取消。
    func delete(ids: [String]) async -> (outcome: DeleteOutcome, existedBefore: Set<String>, error: String?) {
        let before = existingIDs(ids)
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: Array(before), options: nil)
        guard assets.count > 0 else {
            return (DeleteOutcome.make(requested: ids, stillExisting: [], cancelled: false), before, nil)
        }
        var cancelled = false
        var message: String?
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
        } catch {
            let ns = error as NSError
            if ns.domain == PHPhotosErrorDomain && ns.code == PHPhotosError.Code.userCancelled.rawValue {
                cancelled = true
            } else {
                message = ns.localizedDescription
            }
        }
        let still = existingIDs(ids)
        // 用户取消时可能一个都没删
        if cancelled && still.count < before.count { cancelled = false }
        return (DeleteOutcome.make(requested: ids, stillExisting: still, cancelled: cancelled), before, message)
    }
}

/// 相册变化通知（在别的 App 里拍照、删除、编辑后自动增量刷新）
final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let onChange: @Sendable () -> Void
    private var registered = false

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func register() {
        guard !registered else { return }
        registered = true
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        if registered { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}
