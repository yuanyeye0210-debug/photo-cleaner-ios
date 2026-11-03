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
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                ProgressView()
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

/// 网格里的一格：缩略图 + 标记
struct ThumbnailCell: View {
    @EnvironmentObject var store: CleanupStore
    let item: PhotoItem
    var badge: String? = nil

    var body: some View {
        let decision = store.decision(for: item.id)
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                AssetImageView(asset: item.asset, targetSize: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(decision == .delete ? Color.red.opacity(0.28) : Color.clear)

                if decision == .delete {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                } else if decision == .keep {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .padding(6)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.yellow, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        Spacer()
                        Text(item.isVideo ? "▶︎ " + Fmt.bytes(item.fileSize) : Fmt.bytes(item.fileSize))
                            .font(.caption2.monospacedDigit())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.black.opacity(0.45), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(5)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: decision)
    }
}

/// 全屏预览
struct PhotoDetailView: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AssetImageView(asset: item.asset,
                           targetSize: UIScreen.main.bounds.size,
                           contentMode: .fit,
                           allowNetwork: true)
                .background(Color.black)
                .ignoresSafeArea()
            VStack(alignment: .trailing, spacing: 6) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.25))
                }
                Text("\(Fmt.date(item.creationDate)) · \(Fmt.bytes(item.fileSize)) · \(item.pixelWidth)×\(item.pixelHeight)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
        }
        .onTapGesture { dismiss() }
    }
}
