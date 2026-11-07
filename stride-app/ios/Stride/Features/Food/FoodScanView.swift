import SwiftUI
import UIKit
import PhotosUI

struct FoodScanView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var ai: AISettings
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem?
    @State private var items: [FoodItem] = []
    @State private var meal: Meal = .lunch
    @State private var busy = false
    @State private var errorText: String?
    @State private var query = ""
    @State private var showSettings = false
    @State private var recognizedByAI = false

    private var usedToday: Int { store.state.quotas.used("food") }
    private var remaining: Int { Gate.foodRemaining(used: usedToday) }

    private var totalKcal: Double { items.reduce(0) { $0 + $1.kcal } }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        quotaBar
                        photoCard

                        if let errorText {
                            errorCard(errorText)
                        }

                        if !items.isEmpty {
                            itemsCard
                            mealPicker
                        }

                        manualCard
                        saveButton
                    }
                    .padding(.horizontal, Metrics.page)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("记一餐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }.foregroundStyle(Palette.textDim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape").foregroundStyle(Palette.textDim)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { AISettingsView() }
            .onChange(of: pickerItem) { _, newValue in
                Task { await handle(newValue) }
            }
        }
    }

    // MARK: - 额度

    private var quotaBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.amber.opacity(0.14)).frame(width: 34, height: 34)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.amber)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI 热量识别")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(ai.isConfigured ? "今天还剩 \(remaining) 次" : "未配置 AI 服务，可手动记录")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textFaint)
            }
            Spacer()
            Text("\(usedToday)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.amber)
        }
        .padding(14)
        .card(radius: 18, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 拍照

    private var photoCard: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: 10) {
                if busy {
                    ProgressView()
                        .tint(Palette.green)
                    Text("正在识别…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textDim)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(Palette.text)
                    Text("拍一张 / 选一张")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text("拍盘子比拍单个食物更准")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textFaint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .card(radius: 24, fill: Palette.cardSoft, stroke: Palette.stroke)
        }
        .disabled(busy)
    }

    private func errorCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Palette.amber)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 16, fill: Palette.amber.opacity(0.08), stroke: Palette.amber.opacity(0.25))
    }

    // MARK: - 结果

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.text)
                if recognizedByAI {
                    Pill(text: "AI", fg: Palette.greenText, bg: Palette.greenDeep, size: 10)
                }
                Spacer()
                Text("\(Int(totalKcal)) kcal")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.amber)
            }

            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    Text(items[i].name)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("0", value: Binding(
                        get: { items[i].grams },
                        set: { newValue in
                            let old = items[i].grams
                            items[i].grams = newValue
                            if old > 0 { scale(index: i, factor: newValue / old) }
                        }
                    ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.text)
                        .frame(width: 58)

                    Text("g")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textFaint)

                    Text("\(Int(items[i].kcal))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textDim)
                        .frame(width: 46, alignment: .trailing)

                    Button {
                        items.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.textFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 14) {
                macro("蛋白", items.reduce(0) { $0 + $1.protein }, Palette.green)
                macro("碳水", items.reduce(0) { $0 + $1.carbs }, Palette.blue)
                macro("脂肪", items.reduce(0) { $0 + $1.fat }, Palette.amber)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    private func macro(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.textFaint)
            Text("\(Int(value)) g")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mealPicker: some View {
        HStack(spacing: 6) {
            ForEach(Meal.allCases) { m in
                Button {
                    meal = m
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(meal == m ? Color.black : Palette.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(meal == m ? Color.white : Palette.card))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 手动

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("或者手动加")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)

            TextField("搜食物，比如「鸡胸」", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cardSoft))

            let results = FoodDatabase.search(query).prefix(6)
            ForEach(Array(results)) { template in
                Button {
                    items.append(template.item(grams: template.defaultGrams))
                    query = ""
                } label: {
                    HStack {
                        Text(template.name)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Text("\(Int(template.kcal100)) kcal/100g")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Palette.textFaint)
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.green)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .card(radius: 22, fill: Palette.card, stroke: Palette.stroke)
    }

    // MARK: - 保存

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(items.isEmpty ? "还没有食物" : "保存 \(Int(totalKcal)) kcal")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(items.isEmpty ? Palette.textDim : Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(items.isEmpty ? Palette.cardHigh : Color.white)
                )
        }
        .buttonStyle(.plain)
        .disabled(items.isEmpty)
    }

    // MARK: - 行为

    private func handle(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorText = nil
        guard ai.isConfigured else {
            errorText = "还没配置 AI 服务。可以先手动添加食物，或者到「我的 → AI 服务」填 Key 后回来拍照识别。"
            return
        }
        guard Gate.canUseFoodAI(used: usedToday) else {
            errorText = "今天的识别次数用完了。可以手动记录。"
            return
        }

        busy = true
        defer { busy = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorText = "读不到这张图"
                return
            }
            let result = try await FoodRecognition.estimate(image: image, config: ai.config)
            items = result
            recognizedByAI = true
            store.state.quotas.bump("food")
            store.saveNow()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func scale(index i: Int, factor: Double) {
        guard factor.isFinite, factor > 0 else { return }
        items[i].kcal *= factor
        items[i].protein *= factor
        items[i].carbs *= factor
        items[i].fat *= factor
    }

    private func save() {
        let entry = FoodEntry(date: Date(), meal: meal, items: items, recognizedByAI: recognizedByAI)
        store.addFood(entry)
        dismiss()
    }
}
