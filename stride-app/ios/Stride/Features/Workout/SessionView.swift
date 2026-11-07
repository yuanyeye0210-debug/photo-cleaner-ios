import SwiftUI
import Combine

struct SessionDraft {
    var title: String
    var kind: SessionKind
    var exercises: [LoggedExercise]

    static func empty() -> SessionDraft {
        SessionDraft(title: "自由训练", kind: .strength, exercises: [])
    }

    static func fromPlan(_ day: PlannedDay?) -> SessionDraft {
        guard let day, !day.exercises.isEmpty else { return empty() }

        let list: [LoggedExercise] = day.exercises.map { planned in
            let lib = SeedData.library.first { $0.name == planned.name }
            let timed = lib?.isTimed ?? planned.reps.contains("秒")
            let sets = (0..<max(1, planned.sets)).map { _ in
                SetEntry(weight: 0, reps: timed ? 0 : 8, seconds: timed ? 45 : 0)
            }
            return LoggedExercise(
                exerciseID: lib?.id ?? UUID(),
                name: planned.name,
                group: lib?.group ?? .chest,
                isTimed: timed,
                restSec: 90,
                sets: sets
            )
        }
        return SessionDraft(title: day.title, kind: .strength, exercises: list)
    }

    static func from(_ session: WorkoutSession) -> SessionDraft {
        SessionDraft(title: session.title, kind: session.kind, exercises: session.exercises)
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var doneSets: Int { exercises.reduce(0) { $0 + $1.doneSets.count } }
}

struct SessionView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthKitManager
    @EnvironmentObject private var watch: WatchSession
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SessionDraft
    @State private var startedAt = Date()
    @State private var elapsed = 0
    @State private var restLeft = 0
    @State private var restTotal = 0
    @State private var showLibrary = false
    @State private var showFinishConfirm = false
    @State private var toast: String?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(draft: SessionDraft = .empty()) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                VStack(spacing: 0) {
                    summaryBar
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            if draft.exercises.isEmpty {
                                EmptyHint(icon: "dumbbell", title: "空训练", message: "从动作库加几个动作开始。")
                            }
                            ForEach(draft.exercises.indices, id: \.self) { i in
                                exerciseCard(index: i)
                            }
                            addButton
                        }
                        .padding(.horizontal, Metrics.page)
                        .padding(.bottom, 120)
                    }
                }

                if restLeft > 0 {
                    restBar
                }
            }
            .navigationTitle(draft.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Palette.textDim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showFinishConfirm = true }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.green)
                }
            }
            .onReceive(ticker) { _ in
                elapsed = Int(Date().timeIntervalSince(startedAt))
                if restLeft > 0 { restLeft -= 1 }
            }
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView { exercise in
                    add(exercise)
                }
            }
            .alert("结束这次训练？", isPresented: $showFinishConfirm) {
                Button("取消", role: .cancel) {}
                Button("保存") { save() }
            } message: {
                Text("已记录 \(draft.doneSets) 组，用时 \(elapsed / 60) 分钟。")
            }
            .toast($toast)
        }
    }

    // MARK: - 顶部汇总

    private var summaryBar: some View {
        HStack(spacing: 0) {
            metric("\(elapsed / 60):\(String(format: "%02d", elapsed % 60))", "用时")
            divider
            metric("\(draft.doneSets)/\(draft.totalSets)", "组数")
            divider
            metric("\(Int(volume))", "容量 kg")
        }
        .padding(.vertical, 12)
        .background(Palette.card)
        .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .bottom)
    }

    private var divider: some View {
        Rectangle().fill(Palette.stroke).frame(width: 0.5, height: 26)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    private var volume: Double {
        draft.exercises.reduce(0) { $0 + $1.volume }
    }

    // MARK: - 动作卡

    private func exerciseCard(index: Int) -> some View {
        let ex = draft.exercises[index]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text("\(ex.group.rawValue) · 休息 \(ex.restSec)″")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)
                }
                Spacer()
                Button {
                    draft.exercises.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textFaint)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Text("组").frame(width: 26, alignment: .leading)
                Text("重量").frame(maxWidth: .infinity, alignment: .leading)
                Text(ex.isTimed ? "秒" : "次数").frame(maxWidth: .infinity, alignment: .leading)
                Text("RPE").frame(width: 44, alignment: .leading)
                Spacer().frame(width: 30)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Palette.textFaint)

            ForEach(ex.sets.indices, id: \.self) { j in
                setRow(exerciseIndex: index, setIndex: j)
            }

            Button {
                var sets = draft.exercises[index].sets
                let last = sets.last
                sets.append(
                    SetEntry(
                        weight: last?.weight ?? 0,
                        reps: last?.reps ?? 8,
                        seconds: last?.seconds ?? 0
                    )
                )
                draft.exercises[index].sets = sets
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    Text("加一组").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Palette.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private func setRow(exerciseIndex i: Int, setIndex j: Int) -> some View {
        let set = draft.exercises[i].sets[j]
        return HStack(spacing: 8) {
            Text("\(j + 1)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textFaint)
                .frame(width: 26, alignment: .leading)

            TextField("0", value: $draft.exercises[i].sets[j].weight, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.text)
                .padding(.vertical, 7)
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: 9).fill(Palette.cardHigh))
                .frame(maxWidth: .infinity)

            if draft.exercises[i].isTimed {
                TextField("0", value: $draft.exercises[i].sets[j].seconds, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 9)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Palette.cardHigh))
                    .frame(maxWidth: .infinity)
            } else {
                TextField("0", value: $draft.exercises[i].sets[j].reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 9)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Palette.cardHigh))
                    .frame(maxWidth: .infinity)
            }

            TextField("—", value: Binding(
                get: { draft.exercises[i].sets[j].rpe ?? 0 },
                set: { draft.exercises[i].sets[j].rpe = $0 == 0 ? nil : $0 }
            ), format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textDim)
                .padding(.vertical, 7)
                .padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 9).fill(Palette.cardHigh))
                .frame(width: 44)

            Button {
                toggleSet(i: i, j: j)
            } label: {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(set.done ? Palette.green : Palette.strokeHi)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
        }
        .opacity(set.done ? 0.75 : 1)
    }

    // MARK: - 加动作

    private var addButton: some View {
        Button {
            showLibrary = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill").font(.system(size: 15))
                Text("添加动作").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .card(radius: 20, fill: Palette.cardSoft, stroke: Palette.stroke)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 休息条

    private var restBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Palette.cardHigh, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: restTotal > 0 ? Double(restLeft) / Double(restTotal) : 0)
                        .stroke(Palette.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(restLeft)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("休息中").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.text)
                    Text("下一组准备好了就继续").font(.system(size: 11)).foregroundStyle(Palette.textDim)
                }
                Spacer()
                Button {
                    restLeft = 0
                    restTotal = 0
                } label: {
                    Text("跳过")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.cardHigh)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: -4)
            )
            .padding(.horizontal, Metrics.page)
            .padding(.bottom, 12)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: restLeft > 0)
    }

    // MARK: - 行为

    private func toggleSet(i: Int, j: Int) {
        draft.exercises[i].sets[j].done.toggle()
        if draft.exercises[i].sets[j].done {
            let rest = draft.exercises[i].restSec
            restTotal = rest
            restLeft = rest
            watch.push(
                workoutTitle: draft.title,
                elapsed: elapsed,
                setIndex: draft.doneSets,
                totalSets: draft.totalSets
            )
            watch.push(restSeconds: rest, running: true)
        } else {
            restLeft = 0
        }
    }

    private func add(_ exercise: Exercise) {
        let sets = (0..<3).map { _ in
            SetEntry(weight: 0, reps: exercise.isTimed ? 0 : 8, seconds: exercise.isTimed ? 45 : 0)
        }
        draft.exercises.append(
            LoggedExercise(
                exerciseID: exercise.id,
                name: exercise.name,
                group: exercise.group,
                isTimed: exercise.isTimed,
                restSec: 90,
                sets: sets
            )
        )
    }

    private func save() {
        let session = WorkoutSession(
            date: startedAt,
            title: draft.title,
            kind: draft.kind,
            exercises: draft.exercises,
            durationSec: max(elapsed, 60),
            kcal: estimateKcal(),
            writtenToHealth: false
        )
        store.addSession(session)
        Task {
            let ok = await health.save(workout: session)
            if ok { toast = "已写入 Apple 健康" }
        }
        dismiss()
    }

    private func estimateKcal() -> Int {
        let minutes = Double(max(elapsed, 60)) / 60.0
        let avgMET = draft.exercises.isEmpty ? 5.0 : 6.0
        let weight = store.state.profile.weightKg
        // kcal/min = MET × 3.5 × kg / 200
        let perMinute = avgMET * 3.5 * weight / 200.0
        return max(20, Int(perMinute * minutes))
    }
}
