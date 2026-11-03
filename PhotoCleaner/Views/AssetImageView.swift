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
            MM.surface
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                ProgressView().tint(MM.muted)
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
            withAnimation(.easeOut(duration: 0.25)) { image = img }
        }
    }
}

/// 网格里的一格：缩略图 + 标记（MiniMax 风格的圆角与胶囊标签）
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
                    .scaleEffect(decision == .delete ? 1.06 : 1)
                    .overlay(decision == .delete ? MM.danger.opacity(0.32) : Color.clear)

                if decision == .delete {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(LinearGradient(colors: MM.deleteGradient, startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                } else if decision == .keep {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(MM.success, in: Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .padding(6)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .background(Circle().fill(Color.black.opacity(0.12)))
                        .frame(width: 24, height: 24)
                        .padding(7)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        if let badge {
                            Text(badge)
                                .font(MM.text(10, .bold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(LinearGradient(colors: [MM.brand, MM.sky], startPoint: .leading, endPoint: .trailing), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(item.isVideo ? "▶︎ " + Fmt.bytes(item.fileSize) : Fmt.bytes(item.fileSize))
                            .font(MM.display(10, .medium))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.black.opacity(0.4), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .padding(6)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: MM.rTile, style: .continuous))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: decision)
    }
}

/// 全屏预览
struct PhotoDetailView: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            AssetImageView(asset: item.asset,
                           targetSize: UIScreen.main.bounds.size,
                           contentMode: .fit,
                           allowNetwork: true)
                .background(Color.black)
                .ignoresSafeArea()
            HStack {
                Text("\(Fmt.date(item.creationDate)) · \(Fmt.bytes(item.fileSize))")
                    .font(MM.text(13, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .environment(\.colorScheme, .dark)
            .padding()
        }
        .onTapGesture { dismiss() }
    }
}
