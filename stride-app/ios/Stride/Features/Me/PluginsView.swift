import SwiftUI
import Combine

struct PluginsView: View {
    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Text("全部小工具免费，不订阅也能用。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    OneRMCalculator()
                    PlateCalculator()
                    RestTimerTool()
                    TempoTool()
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("插件市场")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 1RM

private struct OneRMEntry: Identifiable {
    let id: Int
    let reps: Int
    let weight: Double
}

private struct OneRMCalculator: View {
    @State private var weight: Double = 80
    @State private var reps: Int = 5

    private var e1rm: Double { ProgressiveEngine.e1RM(weight: weight, reps: reps) }

    private var table: [OneRMEntry] {
        [1, 3, 5, 8, 10, 12].map { r in
            OneRMEntry(id: r, reps: r, weight: e1rm / (1 + Double(r) / 30.0))
        }
    }

    var body: some View {
        ToolCard(icon: "function", title: "1RM 计算", tint: Palette.green) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    numberBox(title: "重量 kg", value: $weight)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("次数")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textFaint)
                        Stepper("\(reps)", value: $reps, in: 1...20)
                            .labelsHidden()
                            .tint(Palette.green)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Int(e1rm))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text("kg 估算 1RM")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                    Spacer()
                }

                VStack(spacing: 5) {
                    ForEach(table) { row in
                        HStack {
                            Text("\(row.reps) 次")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textDim)
                            Spacer()
                            Text("\(Int(row.weight)) kg")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.text)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 杠铃片

private struct PlateRow: Identifiable {
    let plate: Double
    let count: Int
    var id: Double { plate }
}

private struct PlateCalculator: View {
    @State private var target: Double = 100
    @State private var bar: Double = 20

    private let plates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    private var perSide: [PlateRow] {
        var remaining = max(0, (target - bar) / 2)
        var result: [PlateRow] = []
        for p in plates {
            let count = Int(remaining / p)
            if count > 0 {
                result.append(PlateRow(plate: p, count: count))
                remaining -= Double(count) * p
            }
        }
        return result
    }

    var body: some View {
        ToolCard(icon: "circle.grid.cross", title: "杠铃片", tint: Palette.blue) {
            VStack(spacing: 12) {
                HStack {
                    numberBox(title: "目标总重", value: $target)
                    numberBox(title: "空杆", value: $bar)
                }

                if perSide.isEmpty {
                    Text(target <= bar ? "只有空杆" : "这个重量凑不出来")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 6) {
                        ForEach(perSide) { item in
                            VStack(spacing: 2) {
                                Text("\(Int(item.plate))")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Palette.text)
                                Text("×\(item.count)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.textFaint)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Palette.cardSoft))
                        }
                    }
                    Text("每侧")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textFaint)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - 休息计时

private struct RestTimerTool: View {
    @State private var total: Int = 90
    @State private var left: Int = 0
    @State private var running = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ToolCard(icon: "timer", title: "休息计时", tint: Palette.amber) {
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach([45, 60, 90, 120, 180], id: \.self) { sec in
                        Button {
                            total = sec
                            left = sec
                            running = true
                        } label: {
                            Text("\(sec)″")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(total == sec ? Color.black : Palette.textDim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(total == sec ? Color.white : Palette.cardSoft))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(left == 0 ? Palette.textFaint : Palette.text)
                    Spacer()
                    Button {
                        if left == 0 { left = total }
                        running.toggle()
                    } label: {
                        Text(running ? "暂停" : "开始")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onReceive(ticker) { _ in
            guard running, left > 0 else { return }
            left -= 1
            if left == 0 { running = false }
        }
    }
}

// MARK: - 节奏

private struct TempoTool: View {
    @State private var bpm: Double = 128

    private var beat: Double { 60.0 / max(1, bpm) }

    var body: some View {
        ToolCard(icon: "metronome", title: "音乐节奏 → 动作节奏", tint: Palette.pink) {
            VStack(spacing: 10) {
                HStack {
                    Text("BPM")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textDim)
                    Spacer()
                    Text("\(Int(bpm))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                Slider(value: $bpm, in: 60...180, step: 1)
                    .tint(Palette.pink)

                HStack(spacing: 8) {
                    timing("离心 3 秒", "\(Int(3 / beat)) 拍")
                    timing("底部 1 秒", "\(Int(1 / beat)) 拍")
                    timing("向心 1 秒", "\(Int(1 / beat)) 拍")
                }

                Text("每拍 \(String(format: "%.2f", beat)) 秒，一次动作约 \(Int(5 / beat)) 拍。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func timing(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 11).fill(Palette.cardSoft))
    }
}

// MARK: - 容器

private struct ToolCard<Content: View>: View {
    let icon: String
    let title: String
    let tint: Color
    let content: () -> Content

    init(icon: String, title: String, tint: Color, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.tint = tint
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.12)))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
            }
            content()
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }
}

private struct numberBox: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textFaint)
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 11).fill(Palette.cardSoft))
        }
        .frame(maxWidth: .infinity)
    }
}
