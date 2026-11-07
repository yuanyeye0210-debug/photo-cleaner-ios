import SwiftUI

// MARK: - 会员方案页

struct MembershipView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var purchase = PurchaseService()

    @State private var selectedTier: Tier = .max
    @State private var selectedPlanID: String = "max.monthly"
    @State private var proExpanded = true
    @State private var toast: String?

    private var current: MembershipState { store.state.membership }

    private var plans: [MembershipPlan] {
        selectedTier == .max ? MembershipCatalog.maxPlans : MembershipCatalog.proPlans
    }

    private var selectedPlan: MembershipPlan? {
        MembershipCatalog.plan(id: selectedPlanID)
    }

    private var isCurrentSelection: Bool {
        selectedPlanID == current.planID
    }

    private var ctaTitle: String {
        if isCurrentSelection { return "当前方案" }
        guard let plan = selectedPlan else { return "继续" }
        return "以 \(plan.priceText) 订阅"
    }

    private var renewLine: String {
        guard let plan = MembershipCatalog.plan(id: current.planID) else { return "" }
        let suffix = plan.months == 1 ? "月" : (plan.months == 6 ? "半年" : "年")
        let price = plan.priceText.components(separatedBy: " /").first ?? plan.priceText
        return "你的方案按 \(price) / \(suffix) 自动续订，可随时在系统设置中取消。"
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        maxCard
                        proCard
                        freeCard
                        usageCard
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                footer
            }
        }
        .toast($toast)
        .onAppear {
            selectedTier = current.tier
            selectedPlanID = current.planID
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Palette.cardHigh))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")

                Spacer()

                Button {
                    Task {
                        let ok = await purchase.restore(into: store)
                        toast = ok ? "已恢复：\(Brand.tierMax)" : "没有可恢复的购买"
                    }
                } label: {
                    Text("恢复购买")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Palette.cardHigh))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)

            Text("会员方案")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Palette.text)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    // MARK: - Max 卡片

    private var maxCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Brand.tierMax)
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Palette.text)
                    Text("不限次数 · 全部解锁")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Palette.textDim)
                }
                Spacer()
                if current.tier == .max {
                    WhiteBadge(text: "当前方案")
                        .padding(.top, 4)
                }
            }

            VStack(spacing: 10) {
                ForEach(MembershipCatalog.maxPlans) { plan in
                    PlanRow(
                        plan: plan,
                        selected: selectedTier == .max && selectedPlanID == plan.id,
                        isCurrent: current.planID == plan.id,
                        accent: .white
                    ) {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedTier = .max
                            selectedPlanID = plan.id
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 11) {
                ForEach(MembershipCatalog.maxBenefits, id: \.self) { benefit in
                    CheckRow(text: benefit, size: 16)
                }
            }
            .padding(.top, 6)
        }
        .padding(18)
        .card(radius: 30, fill: Palette.card.opacity(0.55), stroke: selectedTier == .max ? .white : Palette.stroke, lineWidth: selectedTier == .max ? 2 : 1)
    }

    // MARK: - Pro 卡片

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    proExpanded.toggle()
                    if proExpanded {
                        selectedTier = .pro
                        selectedPlanID = "pro.monthly"
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    RadioDot(on: selectedTier == .pro)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Brand.tierPro)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Palette.text)
                        Text("为自律者而生")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.textDim)
                    }
                    Spacer()
                    Text("1,99 € / 月")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.text)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if proExpanded {
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(MembershipCatalog.proBenefits, id: \.self) { benefit in
                        CheckRow(text: benefit, size: 15)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .card(radius: 26, fill: Palette.card.opacity(0.55), stroke: selectedTier == .pro ? .white : Palette.stroke, lineWidth: selectedTier == .pro ? 2 : 1)
    }

    // MARK: - 免费版已包含

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("免费版已包含")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Text("不订阅也能用")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textFaint)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(MembershipCatalog.freePerks) { perk in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: perk.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textDim)
                            .frame(width: 18, alignment: .leading)
                            .padding(.top, 2)
                        Text(perk.text)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .card(radius: 26, fill: Palette.card.opacity(0.55))
    }

    // MARK: - 本期用量

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本期用量")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.text)

            usageRow(
                title: "AI 热量识别",
                detail: "每天",
                used: store.state.quotas.used("food"),
                limit: current.tier.foodLimitPerDay
            )
            usageRow(
                title: "AI 教练对话",
                detail: "本期",
                used: store.state.chats.filter { $0.role == .user }.count,
                limit: current.tier.coachLimit
            )
        }
        .padding(18)
        .card(radius: 22, fill: Palette.cardSoft)
    }

    private func usageRow(title: String, detail: String, used: Int, limit: Int) -> some View {
        let unlimited = limit == Int.max
        let ratio = unlimited ? 0.0 : min(1, Double(used) / Double(max(1, limit)))
        return VStack(spacing: 7) {
            HStack {
                Text(title).font(.system(size: 14)).foregroundStyle(Palette.text)
                Spacer()
                Text(unlimited ? "不限" : "\(used) / \(limit)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(unlimited ? Palette.greenText : Palette.textDim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cardHigh)
                    Capsule()
                        .fill(unlimited ? Palette.green.opacity(0.5) : Palette.green)
                        .frame(width: unlimited ? geo.size.width : max(4, geo.size.width * ratio))
                }
            }
            .frame(height: 5)
        }
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                guard let plan = selectedPlan else { return }
                Task {
                    let ok = await purchase.purchase(plan: plan, into: store)
                    if ok {
                        selectedTier = plan.tier
                        selectedPlanID = plan.id
                        toast = "已切换到 \(plan.title)"
                    }
                }
            } label: {
                Text(ctaTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isCurrentSelection ? Palette.text : Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(isCurrentSelection ? Color(hex: 0x58585C) : Color.white)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isCurrentSelection || purchase.isBusy)

            Text(renewLine)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textDim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Palette.bg
                .overlay(Rectangle().fill(Palette.stroke).frame(height: 0.5), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - 套餐行

struct PlanRow: View {
    let plan: MembershipPlan
    let selected: Bool
    let isCurrent: Bool
    var accent: Color = .white
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RadioDot(on: selected)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.text)
                        if let badge = plan.badge {
                            WhiteBadge(text: badge)
                        }
                        if isCurrent {
                            DarkBadge(text: "当前方案")
                        }
                    }
                    if let perMonth = plan.perMonthText {
                        Text(perMonth)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textDim)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(plan.priceText)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.text)
                    if let strike = plan.strikeText {
                        Text(strike)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textFaint)
                            .strikethrough(true, color: Palette.textFaint)
                    }
                    if let saving = plan.savingText {
                        Pill(text: saving)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selected ? Palette.cardHigh : Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? accent : .clear, lineWidth: selected ? 2 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 从任意位置弹出

struct MembershipPresenter: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            MembershipView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(34)
                .presentationBackground(Palette.bg)
        }
    }
}

extension View {
    func membershipSheet(_ isPresented: Binding<Bool>) -> some View {
        modifier(MembershipPresenter(isPresented: isPresented))
    }
}
