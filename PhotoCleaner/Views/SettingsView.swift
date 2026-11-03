import SwiftUI

/// 设置（从首页头像以玻璃弹层打开）
struct SettingsView: View {
    @EnvironmentObject var store: CleanupStore
    @AppStorage("userName") private var userName = "叶原野"
    @State private var confirmReset = false

    private let blurValues = Array(stride(from: 10, through: 300, by: 5))
    private let largeValues = Array(2...50)
    @State private var confirmCache = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 名字（首页问候语用）
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "person.fill", tint: Theme.purple, title: String(localized: "称呼"))
                    TextField("你的名字", text: $userName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("首页显示「\(Theme.greeting())，\(userName.isEmpty ? "你好" : userName)」")
                        .font(Theme.caption).foregroundStyle(Theme.text2)
                }
                .card(padding: 18)

                // 05 惯性滚轮
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "slider.horizontal.3", tint: Theme.orange, title: String(localized: "识别设置")) {
                        PillBadge(text: String(localized: "上下甩动"), tint: Theme.orange)
                    }
                    HStack(spacing: 8) {
                        wheel("模糊阈值", values: blurValues,
                              selection: Binding(get: { Int(store.blurThreshold) }, set: { store.blurThreshold = Double($0) }),
                              tint: Theme.green)
                        wheel("大文件 MB", values: largeValues,
                              selection: Binding(get: { Int(store.largeFileMB) }, set: { store.largeFileMB = Double($0) }),
                              tint: Theme.orange)
                    }
                    Text("模糊阈值越大，越多照片被判为模糊（默认 60）。")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text2)
                }
                .card(padding: 18)

                // 分析：全部照片、结果缓存、暂停 / 继续、iCloud
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "cpu", tint: Theme.blue, title: String(localized: "分析")) {
                        PillBadge(text: String(localized: "\(store.analyzedCount) / \(store.analyzableCount)"), tint: Theme.blue, style: .soft)
                    }
                    Text("会分析相册里的全部照片。分析结果存在本机，下次打开只分析新拍的或编辑过的照片。")
                        .font(Theme.caption).foregroundStyle(Theme.text2)
                    HStack(spacing: 8) {
                        if store.phase == .analyzing {
                            Button { store.pauseAnalysis() } label: { Label(String(localized: "暂停分析"), systemImage: "pause.fill") }
                                .buttonStyle(SecondaryButtonStyle(tint: Theme.blue))
                        } else if store.phase == .paused {
                            Button { store.resumeAnalysis() } label: { Label(String(localized: "继续分析"), systemImage: "play.fill") }
                                .buttonStyle(SecondaryButtonStyle(tint: Theme.blue))
                        }
                        Spacer()
                        Button(String(localized: "清除缓存重新分析")) { confirmCache = true }
                            .buttonStyle(SecondaryButtonStyle(tint: Theme.text2))
                            .disabled(store.isScanning)
                    }
                    Toggle(isOn: $store.allowCloudAnalysis) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("允许从 iCloud 下载来分析").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                            Text("\(store.cloudOnlyIDs.count) 张原图只在 iCloud。打开后会用流量下载缩略图来分析").font(Theme.caption).foregroundStyle(Theme.text3)
                        }
                    }
                    .tint(Theme.accent)
                }
                .card(padding: 18)

                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "checkmark.circle.fill", tint: Theme.green, title: String(localized: "记录"))
                    HStack(alignment: .firstTextBaseline) {
                        Text("已标记保留").font(Theme.callout).foregroundStyle(Theme.text2)
                        Spacer()
                        BigNumber(value: "\(store.kept.count)", unit: String(localized: "张"), size: 24)
                    }
                    Button("清除「保留」记录", role: .destructive) { confirmReset = true }
                        .glassButton()
                        .tint(Theme.danger)
                }
                .card(padding: 18)

                VStack(alignment: .leading, spacing: 10) {
                    CardHeader(icon: "lock.fill", tint: Theme.blue, title: String(localized: "关于"))
                    Text("所有分析都在本机完成，不上传任何照片（只有打开 iCloud 下载开关时才会从你自己的 iCloud 下载原图）。删除使用系统相册接口，删除前系统会再次确认。")
                        .font(Theme.callout).foregroundStyle(Theme.text2)
                    Text("用苹果 Vision 本机 AI 识别相似照片、内容（文档、二维码、美食、宠物、风景）、文字和人脸表情。照片质量评分需要 iOS 18 及以上。")
                        .font(Theme.callout).foregroundStyle(Theme.text2)
                    Text("在系统相册里收藏（❤️）过的照片不会出现在任何清理分类里，也不会被自动标记删除。")
                        .font(Theme.callout).foregroundStyle(Theme.text2)
                    Group {
                        Link("immich-swipe（滑动清理交互）", destination: URL(string: "https://github.com/dev-nick421/immich-swipe")!)
                        Link("czkawka（相似图查找）", destination: URL(string: "https://github.com/qarmin/czkawka")!)
                        Link("imagehash（dHash 感知哈希）", destination: URL(string: "https://github.com/JohannesBuchner/imagehash")!)
                        Link("BlurDetection2（拉普拉斯模糊检测）", destination: URL(string: "https://github.com/WillBrennan/BlurDetection2")!)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.blue)
                }
                .card(padding: 18)
            }
            .padding(Theme.pagePadding)
        }
        .background(Theme.bg.opacity(0.4).ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("确定清除保留记录？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("清除", role: .destructive) { store.resetKept() }
        }
        .confirmationDialog("清除分析缓存？全部照片会重新分析一遍。", isPresented: $confirmCache, titleVisibility: .visible) {
            Button("清除并重新分析", role: .destructive) { store.resetAnalysisCache() }
        }
    }

    private func wheel(_ title: LocalizedStringKey, values: [Int], selection: Binding<Int>, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.caption).foregroundStyle(Theme.text2)
            InertiaWheel(values: values, selection: selection, rowHeight: 34, tint: tint)
        }
        .padding(.vertical, 8)
        .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
