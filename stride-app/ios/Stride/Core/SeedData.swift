import Foundation

enum SeedData {

    static func seed(_ s: inout AppState) {
        s.exercises = library
        s.sessions = makeSessions()
        s.foods = makeFoods()
        s.runs = makeRuns()
        s.snapshots = makeSnapshots()
        s.chats = makeChats()
        s.plan = PlanGenerator.generate(goal: s.profile.goal, days: s.profile.daysPerWeek, experience: s.profile.experience)
    }

    // MARK: - 动作库

    static let library: [Exercise] = [
        Exercise(name: "杠铃卧推", group: .chest, equipment: .barbell, met: 6.0, cue: "肩胛后缩下沉，杠铃触胸不留弹"),
        Exercise(name: "上斜哑铃卧推", group: .chest, equipment: .dumbbell, met: 5.5, cue: "30 度上斜，肘部 45 度夹角"),
        Exercise(name: "双杠臂屈伸", group: .chest, equipment: .bodyweight, met: 6.5, cue: "身体前倾，下到肩低于肘"),
        Exercise(name: "绳索夹胸", group: .chest, equipment: .cable, met: 4.5, cue: "肘微屈固定，用胸把把手抱合"),

        Exercise(name: "引体向上", group: .back, equipment: .bodyweight, met: 7.0, cue: "先沉肩再拉，胸口找杠"),
        Exercise(name: "杠铃划船", group: .back, equipment: .barbell, met: 6.0, cue: "髋主导，杠铃贴腿上拉"),
        Exercise(name: "高位下拉", group: .back, equipment: .machine, met: 5.0, cue: "下拉到锁骨，别用二头抢"),
        Exercise(name: "坐姿绳索划船", group: .back, equipment: .cable, met: 5.0, cue: "胸挺住，肩胛先动再收肘"),

        Exercise(name: "深蹲", group: .legs, equipment: .barbell, met: 7.5, cue: "脚掌三点压实，膝盖跟脚尖同向"),
        Exercise(name: "罗马尼亚硬拉", group: .legs, equipment: .barbell, met: 7.0, cue: "屈髋不屈腰，腘绳肌拉长感"),
        Exercise(name: "保加利亚分腿蹲", group: .legs, equipment: .dumbbell, met: 7.0, cue: "前脚踩稳，后脚只是支点"),
        Exercise(name: "腿举", group: .legs, equipment: .machine, met: 5.5, cue: "别锁膝，下放到腰不卷"),
        Exercise(name: "站姿提踵", group: .legs, equipment: .machine, met: 4.0, cue: "顶点停 1 秒，下放到底"),

        Exercise(name: "站姿推举", group: .shoulders, equipment: .barbell, met: 6.0, cue: "核心收紧，杠过头顶后收下巴"),
        Exercise(name: "哑铃侧平举", group: .shoulders, equipment: .dumbbell, met: 4.0, cue: "小指略高，别耸肩"),
        Exercise(name: "面拉", group: .shoulders, equipment: .cable, met: 4.0, cue: "拉向眉心，外旋收尾"),

        Exercise(name: "杠铃弯举", group: .arms, equipment: .barbell, met: 4.0, cue: "肘固定，离心 3 秒"),
        Exercise(name: "绳索下压", group: .arms, equipment: .cable, met: 4.0, cue: "肘夹紧，底端完全伸直"),
        Exercise(name: "锤式弯举", group: .arms, equipment: .dumbbell, met: 4.0, cue: "拇指朝上，稳住手腕"),

        Exercise(name: "悬垂举腿", group: .core, equipment: .bodyweight, met: 5.0, cue: "骨盆后倾，别只抬腿"),
        Exercise(name: "平板支撑", group: .core, equipment: .bodyweight, isTimed: true, met: 3.5, cue: "肋骨收拢，臀腿绷紧"),
        Exercise(name: "健腹轮", group: .core, equipment: .bodyweight, met: 5.0, cue: "腰不塌，用腹回拉"),

        Exercise(name: "跑步", group: .cardio, equipment: .bodyweight, isTimed: true, met: 9.8, cue: "步频 170+，落地在身体正下方"),
        Exercise(name: "划船机", group: .cardio, equipment: .machine, isTimed: true, met: 8.5, cue: "腿-髋-手，回程反过来")
    ]

    // MARK: - 历史训练

    private static func ex(_ name: String, _ weights: [Double], _ reps: [Int], rest: Int = 90) -> LoggedExercise {
        let lib = library.first { $0.name == name }
        var sets: [SetEntry] = []
        for (i, w) in weights.enumerated() {
            sets.append(SetEntry(weight: w, reps: reps[min(i, reps.count - 1)], rpe: 8.0, done: true))
        }
        return LoggedExercise(
            exerciseID: lib?.id ?? UUID(),
            name: name,
            group: lib?.group ?? .chest,
            isTimed: lib?.isTimed ?? false,
            restSec: rest,
            sets: sets
        )
    }

    private static func session(
        daysAgo: Int,
        title: String,
        exercises: [LoggedExercise],
        minutes: Int,
        kcal: Int
    ) -> WorkoutSession {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return WorkoutSession(
            date: date,
            title: title,
            kind: .strength,
            exercises: exercises,
            durationSec: minutes * 60,
            kcal: kcal,
            syncedToWatch: daysAgo <= 2,
            writtenToHealth: daysAgo <= 2
        )
    }

    static func makeSessions() -> [WorkoutSession] {
        [
            session(daysAgo: 1, title: "推 · 上斜", exercises: [
                ex("杠铃卧推", [60, 60, 62.5, 62.5], [10, 9, 8, 8]),
                ex("上斜哑铃卧推", [22, 22, 24], [10, 10, 8]),
                ex("哑铃侧平举", [8, 8, 8], [15, 14, 12]),
                ex("绳索下压", [25, 25, 25], [14, 12, 12])
            ], minutes: 62, kcal: 420),

            session(daysAgo: 3, title: "拉 · 背厚度", exercises: [
                ex("引体向上", [0, 0, 0], [9, 8, 7], rest: 120),
                ex("杠铃划船", [55, 57.5, 57.5], [10, 9, 9]),
                ex("高位下拉", [55, 57.5, 57.5], [12, 11, 10]),
                ex("面拉", [20, 20, 20], [15, 15, 15], rest: 60)
            ], minutes: 58, kcal: 395),

            session(daysAgo: 5, title: "腿 · 深蹲容量", exercises: [
                ex("深蹲", [80, 85, 85, 85], [8, 6, 6, 5], rest: 150),
                ex("罗马尼亚硬拉", [70, 75, 75], [10, 9, 9]),
                ex("腿举", [120, 130, 130], [12, 12, 10]),
                ex("站姿提踵", [40, 40, 40], [18, 16, 15], rest: 45)
            ], minutes: 68, kcal: 505),

            session(daysAgo: 8, title: "推 · 卧推力量", exercises: [
                ex("杠铃卧推", [62.5, 65, 65, 62.5], [8, 6, 5, 8]),
                ex("站姿推举", [37.5, 37.5, 37.5], [8, 8, 7]),
                ex("绳索夹胸", [18, 18, 18], [15, 14, 12]),
                ex("锤式弯举", [12, 12, 12], [12, 12, 10])
            ], minutes: 60, kcal: 410),

            session(daysAgo: 10, title: "拉 · 引体", exercises: [
                ex("引体向上", [0, 0, 0, 0], [8, 7, 6, 5], rest: 120),
                ex("坐姿绳索划船", [55, 55, 57.5], [12, 12, 10]),
                ex("杠铃弯举", [27.5, 27.5, 27.5], [10, 9, 8]),
                ex("悬垂举腿", [0, 0, 0], [12, 10, 9])
            ], minutes: 55, kcal: 375),

            session(daysAgo: 12, title: "腿 · 后链", exercises: [
                ex("罗马尼亚硬拉", [75, 80, 82.5], [10, 8, 8], rest: 150),
                ex("保加利亚分腿蹲", [16, 16, 16], [10, 10, 9]),
                ex("腿举", [130, 140, 140], [12, 10, 10]),
                ex("健腹轮", [0, 0, 0], [10, 8, 8])
            ], minutes: 64, kcal: 470),

            session(daysAgo: 15, title: "推 · 上斜", exercises: [
                ex("上斜哑铃卧推", [24, 24, 26], [10, 9, 8]),
                ex("双杠臂屈伸", [0, 0, 0], [12, 10, 9]),
                ex("哑铃侧平举", [8, 8, 9], [15, 13, 12]),
                ex("绳索下压", [25, 27.5, 27.5], [12, 10, 10])
            ], minutes: 57, kcal: 385),

            session(daysAgo: 17, title: "拉 · 背厚度", exercises: [
                ex("杠铃划船", [55, 55, 57.5], [10, 10, 8]),
                ex("引体向上", [0, 0, 0], [8, 7, 6]),
                ex("高位下拉", [52.5, 55, 55], [12, 10, 10]),
                ex("面拉", [20, 22.5, 22.5], [15, 14, 12])
            ], minutes: 56, kcal: 380),

            session(daysAgo: 20, title: "腿 · 深蹲力量", exercises: [
                ex("深蹲", [85, 90, 92.5, 85], [6, 4, 3, 6], rest: 180),
                ex("罗马尼亚硬拉", [70, 75, 75], [10, 8, 8]),
                ex("站姿提踵", [40, 42.5, 42.5], [18, 15, 15])
            ], minutes: 61, kcal: 455),

            session(daysAgo: 23, title: "推 · 卧推容量", exercises: [
                ex("杠铃卧推", [60, 60, 60, 60, 60], [10, 10, 9, 9, 8]),
                ex("站姿推举", [35, 37.5, 37.5], [10, 8, 8]),
                ex("绳索夹胸", [17.5, 17.5, 17.5], [15, 14, 14])
            ], minutes: 52, kcal: 350),

            session(daysAgo: 25, title: "拉 · 引体", exercises: [
                ex("引体向上", [0, 0, 0], [7, 7, 6], rest: 120),
                ex("坐姿绳索划船", [52.5, 55, 55], [12, 10, 10]),
                ex("杠铃弯举", [25, 27.5, 27.5], [12, 10, 9])
            ], minutes: 49, kcal: 335)
        ]
    }

    // MARK: - 饮食

    static func makeFoods() -> [FoodEntry] {
        let cal = Calendar.current
        let breakfast = cal.date(bySettingHour: 8, minute: 10, second: 0, of: Date()) ?? Date()
        let lunch = cal.date(bySettingHour: 12, minute: 40, second: 0, of: Date()) ?? Date()
        let snack = cal.date(bySettingHour: 16, minute: 5, second: 0, of: Date()) ?? Date()

        return [
            FoodEntry(date: snack, meal: .snack, items: [
                FoodItem(name: "希腊酸奶", grams: 150, kcal: 145, protein: 15, carbs: 8, fat: 5),
                FoodItem(name: "蓝莓", grams: 80, kcal: 46, protein: 1, carbs: 11, fat: 0)
            ], recognizedByAI: true),
            FoodEntry(date: lunch, meal: .lunch, items: [
                FoodItem(name: "鸡胸肉", grams: 180, kcal: 297, protein: 56, carbs: 0, fat: 6),
                FoodItem(name: "糙米饭", grams: 200, kcal: 232, protein: 5, carbs: 48, fat: 2),
                FoodItem(name: "西兰花", grams: 150, kcal: 51, protein: 4, carbs: 10, fat: 1)
            ], recognizedByAI: true),
            FoodEntry(date: breakfast, meal: .breakfast, items: [
                FoodItem(name: "全麦吐司", grams: 70, kcal: 175, protein: 7, carbs: 32, fat: 2),
                FoodItem(name: "鸡蛋", grams: 100, kcal: 143, protein: 13, carbs: 1, fat: 10),
                FoodItem(name: "美式咖啡", grams: 300, kcal: 6, protein: 0, carbs: 1, fat: 0)
            ])
        ]
    }

    // MARK: - 足迹

    static func makeRuns() -> [RouteRun] {
        var runs: [RouteRun] = []
        let base = (lat: 31.2304, lon: 121.4737)   // 人民广场附近
        let specs: [(daysAgo: Int, title: String, km: Double, min: Int, style: RouteArtStyle)] = [
            (2, "夜跑 · 外滩", 6.42, 34, .neon),
            (4, "晨跑 · 苏州河", 5.18, 29, .ink),
            (7, "间歇 · 世纪公园", 8.05, 44, .gradient),
            (11, "恢复跑", 3.60, 22, .dots),
            (14, "长距离", 12.30, 71, .contour),
            (18, "节奏跑", 7.00, 39, .aurora)
        ]
        for spec in specs {
            let date = Calendar.current.date(byAdding: .day, value: -spec.daysAgo, to: Date()) ?? Date()
            runs.append(
                RouteRun(
                    date: date,
                    title: spec.title,
                    distanceM: spec.km * 1000,
                    durationSec: spec.min * 60,
                    points: loop(center: base, radius: 0.004 + spec.km / 3000, count: 220, seed: spec.daysAgo),
                    styleRaw: spec.style.rawValue
                )
            )
        }
        return runs
    }

    /// 生成一条自然的闭环轨迹（不是正圆，带谐波扰动）
    static func loop(center: (lat: Double, lon: Double), radius: Double, count: Int, seed: Int) -> [GeoPoint] {
        var pts: [GeoPoint] = []
        for i in 0..<count {
            let t = Double(i) / Double(count) * 2 * Double.pi
            let wobble = 1
                + 0.18 * sin(3 * t + Double(seed))
                + 0.10 * cos(5 * t + Double(seed) * 0.7)
                + 0.05 * sin(9 * t)
            let lat = center.lat + radius * wobble * cos(t) * 0.9
            let lon = center.lon + radius * wobble * sin(t) * 1.15
            pts.append(GeoPoint(lat: lat, lon: lon))
        }
        return pts
    }

    // MARK: - 概览

    static func makeSnapshots() -> [DailySnapshot] {
        var result: [DailySnapshot] = []
        let values: [(Int, Int, Int)] = [
            (8420, 520, 62), (10240, 610, 71), (5230, 280, 0), (11800, 720, 84),
            (9100, 560, 58), (4300, 210, 0), (12650, 780, 96), (7800, 470, 52),
            (10400, 650, 68), (6900, 400, 45), (11200, 700, 80), (5600, 300, 0),
            (9800, 600, 66), (8700, 540, 54)
        ]
        for (i, v) in values.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            result.append(
                DailySnapshot(
                    date: date,
                    steps: v.0,
                    activeKcal: v.1,
                    exerciseMin: v.2,
                    restingHR: 52 + (i % 5),
                    weightKg: 76.0 - Double(i) * 0.05
                )
            )
        }
        return result
    }

    // MARK: - 教练开场

    static func makeChats() -> [ChatTurn] {
        [
            ChatTurn(role: .coach, text: "我是你的教练。今天想练什么——推、拉，还是腿？\n也可以直接把感受丢给我：「昨天卧推 62.5 做了 8 次还有余力」。")
        ]
    }
}
