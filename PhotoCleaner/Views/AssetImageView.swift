import SwiftUI
import Photos

/// 异步加载 PHAsset 缩略图 / 大图
struct AssetImageView: View {
    let asset: PHAsset
    var targetSize: CGSize = CGSize(width: 300, height: 300)
    var contentMode: ContentMode = .fill
    var allowNetwork: Bool = false

    @State private var image: UIImage?

    var body: some View {
        // 没加载完时先用内存里已有的图（比如网格/卡片里的缩略图），避免出现空白
        let shown = image ?? PhotoLibraryService.shared.cachedImage(for: asset.localIdentifier)
        ZStack {
            Theme.fill
            if let image = shown {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            }
        }
        .clipped()
        .task(id: asset.localIdentifier) {
            let scale = UIScreen.main.scale
            let size = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
            let img = await PhotoLibraryService.shared.image(for: asset,
                                                             targetSize: size,
                                                             contentMode: contentMode == .fill ? .aspectFill : .aspectFit,
                                                             allowNetwork: allowNetwork)
            withAnimation(.easeOut(duration: 0.2)) { image = img }
        }
    }
}

/// 网格里的一格：缩略图 + 选择状态
struct ThumbnailCell: View {
    @EnvironmentObject var store: CleanupStore
    let item: PhotoItem
    var isBest: Bool = false

    var body: some View {
        let decision = store.decision(for: item.id)
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                AssetImageView(asset: item.asset, targetSize: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(Color.black.opacity(decision == .delete ? 0.45 : 0))

                // 右上角选择圈：删除 = 柔和红勾，保留 = 绿色勾，未定 = 空心圈
                ZStack {
                    Circle()
                        .fill(decision == .delete ? Theme.danger : (decision == .keep ? Theme.green : Color.black.opacity(0.25)))
                    Circle().stroke(Color.white, lineWidth: 1.5)
                    if decision != nil {
                        Image(systemName: decision == .delete ? "trash" : "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .transition(.scale)
                    }
                }
                .frame(width: 22, height: 22)
                .padding(6)

                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        if isBest {
                            Text("推荐保留")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.purple, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(item.isVideo ? "▶︎ " + Fmt.bytes(item.fileSize) : Fmt.bytes(item.fileSize))
                            .font(Theme.number(10, .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                    .padding(6)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.rTile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rTile, style: .continuous)
                .stroke(isBest ? Theme.purple : (decision == .delete ? Theme.danger.opacity(0.6) : Color.clear), lineWidth: 2)
        )
        .scaleEffect(decision == .delete ? 0.95 : 1)
        .animation(Theme.spring, value: decision)
    }
}

/// 全屏预览：先立刻显示已缓存的缩略图，再渐进换成高清图
struct PhotoDetailView: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isFinal = false

    var body: some View {
        let shown = image ?? PhotoLibraryService.shared.cachedImage(for: item.id)
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            Group {
                if let shown {
                    Image(uiImage: shown)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.black
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .overlay {
                if shown == nil {
                    VStack(spacing: 10) {
                        ProgressView().tint(.white).controlSize(.large)
                        Text("正在加载…").font(Theme.caption).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            HStack(spacing: 10) {
                Text("\(Fmt.date(item.creationDate)) · \(Fmt.bytes(item.fileSize))")
                    .font(Theme.caption)
                    .foregroundStyle(.white.opacity(0.85))
                if shown != nil && !isFinal {
                    ProgressView().tint(.white).controlSize(.mini)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .glassSurface(Circle(), interactive: true)
                }
            }
            .padding()
        }
        .onTapGesture { dismiss() }
        .task(id: item.id) {
            let scale = UIScreen.main.scale
            let b = UIScreen.main.bounds.size
            let size = CGSize(width: b.width * scale, height: b.height * scale)
            for await (img, done) in PhotoLibraryService.shared.progressiveImages(for: item.asset, targetSize: size) {
                image = img
                if done { isFinal = true }
            }
            isFinal = true
        }
    }
}
