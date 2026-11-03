import SwiftUI

/// 设置（从首页头像以玻璃弹层打开）
struct SettingsView: View {
    @EnvironmentObject var store: CleanupStore
    @AppStorage("userName") private var userName = "叶原野"
    @State private var confirmReset = false

    private let blurValues = Array(stride(from: 10, through: 300, by: 5))
    private let largeValues = Array(2...50)
    private let limitValues = Array(stride(from: 500, through: 20000, by: 500))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 名字（首页问候语用）
                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "person.fill", tint: Theme.purple, title: "称呼")
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
                    CardHeader(icon: "slider.horizontal.3", tint: Theme.orange, title: "识别设置") {
                        PillBadge(text: "上下甩动", tint: Theme.orange)
                    }
                    HStack(spacing: 8) {
                        wheel("模糊阈值", values: blurValues,
                              selection: Binding(get: { Int(store.blurThreshold) }, set: { store.blurThreshold = Double($0) }),
                              tint: Theme.green)
                        wheel("大文件 MB", values: largeValues,
                              selection: Binding(get: { Int(store.largeFileMB) }, set: { store.largeFileMB = Double($0) }),
                              tint: Theme.orange)
                        wheel("分析张数", values: limitValues,
                              selection: $store.analyzeLimit,
                              tint: Theme.blue)
                    }
                    Text("模糊阈值越大，越多照片被判为模糊（默认 60）。相似、模糊、过暗/过曝需要逐张分析，改了分析张数后回首页点刷新。")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.text2)
                }
                .card(padding: 18)

                VStack(alignment: .leading, spacing: 12) {
                    CardHeader(icon: "checkmark.circle.fill", tint: Theme.green, title: "记录")
                    HStack(alignment: .firstTextBaseline) {
                        Text("已标记保留").font(Theme.callout).foregroundStyle(Theme.text2)
                        Spacer()
                        BigNumber(value: "\(store.kept.count)", unit: "张", size: 24)
                    }
                    Button("清除「保留」记录", role: .destructive) { confirmReset = true }
                        .glassButton()
                        .tint(Theme.danger)
                }
                .card(padding: 18)

                VStack(alignment: .leading, spacing: 10) {
                    CardHeader(icon: "lock.fill", tint: Theme.blue, title: "关于")
                    Text("所有分析都在本机完成，不联网、不上传。删除使用系统相册接口，删除前系统会再次确认。")
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
    }

    private func wheel(_ title: String, values: [Int], selection: Binding<Int>, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.caption).foregroundStyle(Theme.text2)
            InertiaWheel(values: values, selection: selection, rowHeight: 34, tint: tint)
        }
        .padding(.vertical, 8)
        .background(Theme.bgElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
