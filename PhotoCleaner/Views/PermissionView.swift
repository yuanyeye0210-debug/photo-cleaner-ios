import SwiftUI
import Photos

struct PermissionView: View {
    @EnvironmentObject var store: CleanupStore

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: CleanCategory.similar.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: .purple.opacity(0.35), radius: 24, y: 10)
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 10) {
                Text("相册清理")
                    .font(.largeTitle.bold())
                Text("自动找出相似照片、截图、模糊照片和大视频，\n滑一滑就能清理，释放手机空间。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                Label("所有分析都在手机本地完成，不上传任何照片", systemImage: "lock.shield.fill")
                Label("删除前一定会让你确认", systemImage: "checkmark.seal.fill")
                Label("删掉的照片 30 天内可在「最近删除」恢复", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 28)

            Spacer()

            if store.authStatus == .denied || store.authStatus == .restricted {
                Text("你之前拒绝了相册权限，请到「设置」里打开。")
                    .font(.footnote)
                    .foregroundStyle(.red)
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
                    Text("允许访问相册，开始扫描").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var colors: [Color] = CleanCategory.similar.colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
