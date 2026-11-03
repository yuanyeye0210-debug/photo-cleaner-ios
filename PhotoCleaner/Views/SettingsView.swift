import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: CleanupStore
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("模糊判定阈值：\(Int(store.blurThreshold))")
                    Slider(value: $store.blurThreshold, in: 10...300, step: 5)
                    Text("数值越大，越多照片会被判为模糊。默认 60。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Text("大文件标准：≥ \(Int(store.largeFileMB)) MB")
                    Slider(value: $store.largeFileMB, in: 2...50, step: 1)
                }
                Stepper("最多分析最近 \(store.analyzeLimit) 张", value: $store.analyzeLimit, in: 500...20000, step: 500)
            } header: {
                Text("识别设置")
            } footer: {
                Text("相似、模糊、过暗/过曝需要逐张分析，照片越多越慢。修改分析数量后请回首页点刷新。")
            }

            Section("记录") {
                Text("已标记保留：\(store.kept.count) 张")
                Button("清除「保留」记录（让它们重新出现）", role: .destructive) {
                    confirmReset = true
                }
            }

            Section("关于") {
                Text("所有分析都在本机完成，不联网、不上传。删除使用系统相册接口，删除前系统会再次确认。")
                    .font(.footnote)
                Link("参考：immich-swipe（滑动清理交互）", destination: URL(string: "https://github.com/dev-nick421/immich-swipe")!)
                Link("参考：czkawka（相似图查找）", destination: URL(string: "https://github.com/qarmin/czkawka")!)
                Link("参考：imagehash（dHash 感知哈希）", destination: URL(string: "https://github.com/JohannesBuchner/imagehash")!)
                Link("参考：BlurDetection2（拉普拉斯模糊检测）", destination: URL(string: "https://github.com/WillBrennan/BlurDetection2")!)
            }
            .font(.subheadline)
        }
        .navigationTitle("设置")
        .confirmationDialog("确定清除保留记录？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("清除", role: .destructive) { store.resetKept() }
        }
    }
}
