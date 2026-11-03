import Photos
import UIKit

/// 封装 PhotoKit：权限、读取、缩略图、删除
final class PhotoLibraryService {
    static let shared = PhotoLibraryService()
    let imageManager = PHCachingImageManager()
    /// 内存缓存：每张照片已加载过的最大图，打开大图时可立刻先显示
    private let memCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 400
        return c
    }()

    func cachedImage(for id: String) -> UIImage? {
        memCache.object(forKey: id as NSString)
    }

    private func remember(_ img: UIImage, for id: String) {
        let key = id as NSString
        if let old = memCache.object(forKey: key),
           old.size.width * old.scale >= img.size.width * img.scale { return }
        memCache.setObject(img, forKey: key)
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

    /// 文件大小：累加该资源的所有文件（实况照片含视频部分）。
    /// PHAssetResource 的 fileSize 通过 KVC 读取（社区常用做法）；取不到时按像素估算。
    static func fileSize(of asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        var total: Int64 = 0
        for r in resources {
            if let n = r.value(forKey: "fileSize") as? NSNumber {
                total += n.int64Value
            }
        }
        if total > 0 { return total }
        let px = Int64(asset.pixelWidth * asset.pixelHeight)
        if asset.mediaType == .video {
            return Int64(max(1, asset.duration) * 1_500_000) // 约 12Mbps
        }
        return px / 3
    }

    /// 请求一张图片（只回调一次的 highQualityFormat 模式）
    func image(for asset: PHAsset,
               targetSize: CGSize,
               contentMode: PHImageContentMode = .aspectFill,
               allowNetwork: Bool = false) async -> UIImage? {
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
        if let img { remember(img, for: asset.localIdentifier) }
        return img
    }

    /// 渐进加载：先尽快给一张低清图（本地已有的），再给高清图。用于全屏大图。
    func progressiveImages(for asset: PHAsset,
                           targetSize: CGSize,
                           contentMode: PHImageContentMode = .aspectFit) -> AsyncStream<(UIImage, Bool)> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            let id = imageManager.requestImage(for: asset,
                                               targetSize: targetSize,
                                               contentMode: contentMode,
                                               options: options) { [weak self] image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let failed = info?[PHImageErrorKey] != nil || ((info?[PHImageCancelledKey] as? Bool) ?? false)
                if let image {
                    self?.remember(image, for: asset.localIdentifier)
                    continuation.yield((image, !degraded))
                }
                if !degraded || failed { continuation.finish() }
            }
            continuation.onTermination = { [weak self] _ in
                self?.imageManager.cancelImageRequest(id)
            }
        }
    }

    /// 真正删除：系统会弹出“允许删除 N 张照片吗？”确认框。
    /// 删除后照片进入系统相册的“最近删除”，30 天内可恢复。
    func delete(ids: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        guard assets.count > 0 else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
