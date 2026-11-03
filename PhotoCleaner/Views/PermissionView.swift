import SwiftUI
import Photos

/// 首次打开：说明用途并请求相册权限
struct PermissionView: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            IconBadge(icon: "photo.on.rectangle.angled", size: 64)
                .fadeIn(0)
            Text("相册清理")
                .font(Theme.largeTitle)
                .foregroundStyle(Theme.text)
                .padding(.top, 24)
                .fadeIn(1)
            Text("自动找出相似照片、截图、模糊照片和大视频，\n滑一滑就能清理，释放手机空间。")
                .font(Theme.body)
                .foregroundStyle(Theme.text2)
                .lineSpacing(4)
                .padding(.top, 8)
                .fadeIn(2)

            VStack(alignment: .leading, spacing: 18) {
                row("lock", "所有分析都在手机本地完成，不上传任何照片")
                row("checkmark.shield", "删除前一定会让你确认")
                row("arrow.uturn.backward", "删掉的照片 30 天内可在「最近删除」恢复")
            }
            .padding(.top, 36)
            .fadeIn(3)

            Spacer()
            Spacer()

            if store.authStatus == .denied || store.authStatus == .restricted {
                Text("你之前拒绝了相册权限，请到「设置」里打开。")
                    .font(Theme.callout)
                    .foregroundStyle(Theme.text2)
                    .padding(.bottom, 12)
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
                    Text("允许访问相册").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
        }
    }
}
