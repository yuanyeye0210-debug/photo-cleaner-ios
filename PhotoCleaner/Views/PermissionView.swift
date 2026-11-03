import SwiftUI
import Photos

/// 首次打开：MiniMax 首屏风格（粉橙渐变光晕 + 大标题 + 深色胶囊按钮）
struct PermissionView: View {
    @EnvironmentObject var store: CleanupStore
    @State private var appear = false

    var body: some View {
        ZStack(alignment: .top) {
            MM.canvas.ignoresSafeArea()
            // 顶部渐变光晕
            GradientArt(colors: MM.heroGradient, radius: 0)
                .frame(height: 420)
                .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 40)
                cardStack
                    .scaleEffect(appear ? 1 : 0.9)
                    .opacity(appear ? 1 : 0)
                Spacer(minLength: 28)

                VStack(spacing: 10) {
                    Text("相册清理")
                        .font(MM.display(40, .semibold))
                        .foregroundStyle(MM.ink)
                    Text("相似照片、截图、模糊照片、大视频\n自动分好类，滑一滑就清理干净")
                        .font(MM.text(16))
                        .foregroundStyle(MM.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                VStack(spacing: 10) {
                    promise("lock.fill", "所有分析都在手机本地完成，不上传")
                    promise("checkmark.seal.fill", "删除前一定会让你确认")
                    promise("arrow.uturn.backward", "删掉的照片 30 天内可在「最近删除」恢复")
                }
                .padding(18)
                .mmCard(radius: 20, shadow: .subtle, fill: MM.surface)
                .padding(.top, 26)

                Spacer()

                if store.authStatus == .denied || store.authStatus == .restricted {
                    Text("你之前拒绝了相册权限，请到「设置」里打开。")
                        .font(MM.text(13, .medium))
                        .foregroundStyle(MM.danger)
                        .padding(.bottom, 10)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("去设置开启").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {
                        Task { await store.requestAccess() }
                    } label: {
                        HStack(spacing: 8) {
                            Text("允许访问相册，开始扫描")
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appear = true }
        }
    }

    /// 三张错落的彩色卡片，模仿 MiniMax 首页的产品卡
    private var cardStack: some View {
        ZStack {
            miniCard(CleanCategory.screenshots.colors, icon: "iphone")
                .rotationEffect(.degrees(-12)).offset(x: -78, y: 14)
            miniCard(CleanCategory.blurry.colors, icon: "drop.halffull")
                .rotationEffect(.degrees(12)).offset(x: 78, y: 14)
            miniCard(CleanCategory.similar.colors, icon: "sparkles")
                .scaleEffect(1.12)
        }
        .frame(height: 190)
    }

    private func miniCard(_ colors: [Color], icon: String) -> some View {
        GradientArt(colors: colors, radius: 26)
            .frame(width: 120, height: 150)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .padding(5)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: MM.glow.opacity(0.18), radius: 16, y: 8)
    }

    private func promise(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MM.brand)
                .frame(width: 28, height: 28)
                .background(MM.brand.opacity(0.1), in: Circle())
            Text(text)
                .font(MM.text(14))
                .foregroundStyle(MM.ink2)
            Spacer(minLength: 0)
        }
    }
}
