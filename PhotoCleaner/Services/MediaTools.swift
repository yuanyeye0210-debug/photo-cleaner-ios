import AVFoundation
import Photos

/// 视频压缩（HEVC）和实况照片转静态照片。
/// 新文件保留原来的拍摄时间、地点和收藏标记；原件不会自动删除，
/// 而是放进「待删除」，由用户在确认列表里确认后才走系统删除。
enum MediaTools {
    enum Failure: LocalizedError {
        case unavailable, alreadyEfficient, noSavings, exportFailed(String?), saveFailed(String?)

        var errorDescription: String? {
            switch self {
            case .unavailable: return String(localized: "原文件不在本机（可能只在 iCloud）")
            case .alreadyEfficient: return String(localized: "已经是高效格式")
            case .noSavings: return String(localized: "压缩后不会更小，已跳过")
            case .exportFailed(let m): return m ?? String(localized: "压缩失败")
            case .saveFailed(let m): return m ?? String(localized: "保存失败")
            }
        }
    }

    struct Output: Sendable {
        let newID: String
        let newBytes: Int64
    }

    private final class Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

    // MARK: - 视频压缩

    static func avAsset(for asset: PHAsset, allowNetwork: Bool) async -> AVAsset? {
        let opts = PHVideoRequestOptions()
        opts.version = .current
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = allowNetwork
        return await withCheckedContinuation { (cont: CheckedContinuation<AVAsset?, Never>) in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: opts) { av, _, _ in
                cont.resume(returning: av)
            }
        }
    }

    static func isHEVC(_ av: AVAsset) async -> Bool {
        guard let track = try? await av.loadTracks(withMediaType: .video).first,
              let descs = try? await track.load(.formatDescriptions) else { return false }
        return descs.contains { CMFormatDescriptionGetMediaSubType($0) == kCMVideoCodecType_HEVC }
    }

    /// 压缩成 HEVC（最高画质），返回新视频的 id 和大小
    static func compressVideo(_ asset: PHAsset, originalBytes: Int64, allowNetwork: Bool,
                              progress: @escaping @Sendable (Double) -> Void) async throws -> Output {
        guard let av = await avAsset(for: asset, allowNetwork: allowNetwork) else { throw Failure.unavailable }
        if await isHEVC(av) { throw Failure.alreadyEfficient }
        guard let session = AVAssetExportSession(asset: av, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw Failure.exportFailed(nil)
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("hevc-\(UUID().uuidString).mov")
        session.outputURL = out
        session.outputFileType = .mov
        session.shouldOptimizeForNetworkUse = false

        let sessionBox = Box(session)
        let poll = Task {
            while !Task.isCancelled {
                progress(Double(sessionBox.value.progress))
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionBox.value.exportAsynchronously { cont.resume() }
        }
        poll.cancel()
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: out)
            throw Failure.exportFailed(session.error?.localizedDescription)
        }
        let newBytes = ((try? FileManager.default.attributesOfItem(atPath: out.path)[.size]) as? NSNumber)?.int64Value ?? 0
        // 至少省 5% 才值得替换
        guard newBytes > 0, originalBytes <= 0 || Double(newBytes) < Double(originalBytes) * 0.95 else {
            try? FileManager.default.removeItem(at: out)
            throw Failure.noSavings
        }
        progress(1)
        do {
            let id = try await save(from: asset) { req in
                let o = PHAssetResourceCreationOptions()
                o.shouldMoveFile = true
                req.addResource(with: .video, fileURL: out, options: o)
            }
            return Output(newID: id, newBytes: newBytes)
        } catch {
            try? FileManager.default.removeItem(at: out)
            throw Failure.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - 实况照片 → 静态照片

    /// 只保留照片部分（编辑过的用编辑后的版本），返回新照片的 id 和大小
    static func convertLivePhoto(_ asset: PHAsset, allowNetwork: Bool) async throws -> Output {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let photo = resources.first(where: { $0.type == .fullSizePhoto })
                ?? resources.first(where: { $0.type == .photo }) else { throw Failure.unavailable }
        let opts = PHAssetResourceRequestOptions()
        opts.isNetworkAccessAllowed = allowNetwork
        let buffer = Box(Data())
        let ok: Bool = await withCheckedContinuation { cont in
            PHAssetResourceManager.default().requestData(for: photo, options: opts) { chunk in
                buffer.value.append(chunk)
            } completionHandler: { error in
                cont.resume(returning: error == nil)
            }
        }
        let data = buffer.value
        guard ok, !data.isEmpty else { throw Failure.unavailable }
        do {
            let id = try await save(from: asset) { req in
                let o = PHAssetResourceCreationOptions()
                o.uniformTypeIdentifier = photo.uniformTypeIdentifier
                o.originalFilename = photo.originalFilename
                req.addResource(with: .photo, data: data, options: o)
            }
            return Output(newID: id, newBytes: Int64(data.count))
        } catch {
            throw Failure.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - 保存（保留日期、地点、收藏）

    private static func save(from original: PHAsset, _ build: @escaping (PHAssetCreationRequest) -> Void) async throws -> String {
        let newID = Box<String?>(nil)
        let created = original.creationDate
        let location = original.location
        let favorite = original.isFavorite
        try await PHPhotoLibrary.shared().performChanges {
            let req = PHAssetCreationRequest.forAsset()
            build(req)
            req.creationDate = created
            req.location = location
            req.isFavorite = favorite
            newID.value = req.placeholderForCreatedAsset?.localIdentifier
        }
        guard let id = newID.value else { throw Failure.saveFailed(nil) }
        return id
    }
}
