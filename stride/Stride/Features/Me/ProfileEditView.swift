import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Profile()
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    nameCard
                    goalCard
                    bodyCard
                    targetCard
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 120)
            }

            VStack {
                Spacer()
                Button {
                    store.state.profile = draft
                    store.saveNow()
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 14)
            }
        }
        .navigationTitle("我的资料")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = store.state.profile }
        .toast($toast)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("昵称")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
            TextField("你的名字", text: $draft.nickname)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13).fill(Palette.cardSoft))
        }
        .padding(16)
        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目标")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)

            HStack(spacing: 6) {
                ForEach(Goal.allCases) { goal in
                    Button {
                        draft.goal = goal
                    } label: {
                        Text(goal.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(draft.goal == goal ? Color.black : Palette.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(draft.goal == goal ? Color.white : Palette.cardSoft))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(Palette.stroke)

            Text("经验")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)

            HStack(spacing: 6) {
                ForEach(Experience.allCases) { level in
                    Button {
                        draft.experience = level
                    } label: {
                        Text(level.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(draft.experience == level ? Color.black : Palette.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(draft.experience == level ? Color.white : Palette.cardSoft))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("每周训练")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Stepper(value: $draft.daysPerWeek, in: 2...6) {
                    Text("\(draft.daysPerWeek) 天")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.green)
                }
                .labelsHidden()
                Text("\(draft.daysPerWeek) 天")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(16)
        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("身体数据")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)

            numberRow(title: "身高 (cm)", value: $draft.heightCm, format: "%.0f")
            numberRow(title: "体重 (kg)", value: $draft.weightKg, format: "%.1f")
            numberRow(title: "年龄", value: Binding(
                get: { Double(draft.age) },
                set: { draft.age = Int($0) }
            ), format: "%.0f")

            Toggle(isOn: $draft.sexMale) {
                Text("男性")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textDim)
            }
            .tint(Palette.green)
        }
        .padding(16)
        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
    }

    private func numberRow(title: String, value: Binding<Double>, format: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textDim)
            Spacer()
            TextField("0", value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = $0 }
            ), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text)
                .frame(width: 80)
        }
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按你的数据算出的目标")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
            HStack(spacing: 10) {
                StatTile(value: "\(Int(draft.bmr))", label: "基础代谢", tint: Palette.text)
                StatTile(value: "\(Int(draft.tdee))", label: "总消耗", tint: Palette.blue)
                StatTile(value: "\(draft.kcalTarget)", label: "建议摄入", tint: Palette.green)
            }
            HStack(spacing: 10) {
                StatTile(value: "\(draft.proteinTarget) g", label: "蛋白质", tint: Palette.green)
                StatTile(value: "\(Int(Double(draft.kcalTarget) * 0.42 / 4)) g", label: "碳水", tint: Palette.blue)
                StatTile(value: "\(Int(Double(draft.kcalTarget) * 0.28 / 9)) g", label: "脂肪", tint: Palette.amber)
            }
        }
        .padding(16)
        .card(radius: 20, fill: Palette.cardSoft, stroke: Palette.stroke)
    }
}

// MARK: - 计划编辑

struct PlanEditorView: View {
    @EnvironmentObject private var store: AppStore
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(store.state.plan?.days ?? []) { day in
                        dayCard(day)
                    }

                    Button {
                        let p = store.state.profile
                        store.setPlan(PlanGenerator.generate(goal: p.goal, days: p.daysPerWeek, experience: p.experience))
                        toast = "已按当前目标重排 4 周"
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                            Text("重新生成").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.page)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("训练计划")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    private func dayCard(_ day: PlannedDay) -> some View {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let weekday = day.weekday >= 1 && day.weekday <= 7 ? names[day.weekday - 1] : "?"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("周\(weekday)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(day.rest ? Palette.textFaint : Palette.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(day.rest ? Palette.cardHigh : Palette.green.opacity(0.14)))
                Text(day.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
            }

            ForEach(day.exercises) { ex in
                HStack(alignment: .top) {
                    Text(ex.name)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Palette.text)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(ex.sets) × \(ex.reps)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.textDim)
                        if !ex.note.isEmpty {
                            Text(ex.note)
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.textFaint)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(16)
        .card(radius: 20, fill: Palette.card, stroke: Palette.stroke)
    }
}
