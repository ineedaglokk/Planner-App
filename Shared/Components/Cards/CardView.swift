//
//  CardView.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Универсальные карточки для контента
//

import SwiftUI

// MARK: - Card Style
enum CardStyle {
    case standard
    case elevated
    case outlined
    case filled
    case compact
}

// MARK: - Card State
enum CardState {
    case normal
    case selected
    case disabled
    case loading
}

// MARK: - Base Card View
struct CardView<Content: View>: View {
    
    // MARK: - Properties
    private let content: Content
    private let style: CardStyle
    private let state: CardState
    private let padding: EdgeInsets
    private let onTap: (() -> Void)?
    
    // MARK: - State
    @State private var isPressed = false
    
    // MARK: - Initialization
    init(
        style: CardStyle = .standard,
        state: CardState = .normal,
        padding: EdgeInsets = .card,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.style = style
        self.state = state
        self.padding = padding
        self.onTap = onTap
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    onTap()
                }) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
            } else {
                cardContent
            }
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .overlay(overlayView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .applyShadow(shadowStyle)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .opacity(state == .disabled ? 0.6 : 1.0)
            .overlay(loadingOverlay)
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch (style, state) {
        case (.standard, .normal):
            return ColorPalette.Background.surface
        case (.standard, .selected):
            return ColorPalette.Primary.light.opacity(0.1)
        case (.elevated, _):
            return ColorPalette.Background.elevated
        case (.outlined, .normal):
            return ColorPalette.Background.primary
        case (.outlined, .selected):
            return ColorPalette.Primary.light.opacity(0.05)
        case (.filled, _):
            return ColorPalette.Primary.light.opacity(0.1)
        case (.compact, _):
            return ColorPalette.Background.surface
        default:
            return ColorPalette.Background.surface
        }
    }
    
    @ViewBuilder
    private var overlayView: some View {
        switch style {
        case .outlined:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: borderWidth)
        default:
            EmptyView()
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .selected:
            return ColorPalette.Primary.main
        default:
            return ColorPalette.Border.main
        }
    }
    
    private var borderWidth: CGFloat {
        switch state {
        case .selected:
            return 2
        default:
            return 1
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .compact:
            return CornerRadius.sm
        default:
            return CornerRadius.card
        }
    }
    
    private var shadowStyle: ShadowStyle {
        switch style {
        case .elevated:
            return .elevated
        case .outlined:
            return .none
        default:
            return state == .selected ? .elevated : .card
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if state == .loading {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ColorPalette.Background.surface.opacity(0.8))
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.Primary.main))
                )
        }
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let value: String?
    let style: CardStyle
    let onTap: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        value: String? = nil,
        style: CardStyle = .standard,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.value = value
        self.style = style
        self.onTap = onTap
    }
    
    var body: some View {
        CardView(style: style, onTap: onTap) {
            HStack(spacing: Spacing.md) {
                // Icon
                if let icon = icon {
                    IconView(icon, style: .card)
                }
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .cardTitle()
                        .lineLimit(1)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .cardSubtitle()
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Value
                if let value = value {
                    Text(value)
                        .statisticNumber()
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Statistic Card
struct StatisticCard: View {
    let title: String
    let value: String
    let change: String?
    let changeType: ChangeType
    let icon: String?
    let color: Color?
    
    enum ChangeType {
        case positive
        case negative
        case neutral
        
        var color: Color {
            switch self {
            case .positive:
                return ColorPalette.Semantic.success
            case .negative:
                return ColorPalette.Semantic.error
            case .neutral:
                return ColorPalette.Text.secondary
            }
        }
        
        var icon: String {
            switch self {
            case .positive:
                return "arrow.up"
            case .negative:
                return "arrow.down"
            case .neutral:
                return "minus"
            }
        }
    }
    
    init(
        title: String,
        value: String,
        change: String? = nil,
        changeType: ChangeType = .neutral,
        icon: String? = nil,
        color: Color? = nil
    ) {
        self.title = title
        self.value = value
        self.change = change
        self.changeType = changeType
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    if let icon = icon {
                        IconView(icon, style: IconStyle(
                            size: IconSize.lg,
                            color: color ?? ColorPalette.Primary.main,
                            weight: .medium
                        ))
                    }
                    
                    Spacer()
                    
                    if let change = change {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: changeType.icon)
                                .font(.system(size: 12, weight: .bold))
                            
                            Text(change)
                                .font(Typography.Caption.regular)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(changeType.color)
                    }
                }
                
                // Value
                Text(value)
                    .font(Typography.Special.numberLarge)
                    .fontWeight(.bold)
                    .foregroundColor(color ?? ColorPalette.Primary.main)
                
                // Title
                Text(title)
                    .font(Typography.Body.medium)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Action Card
struct ActionCard: View {
    let title: String
    let description: String?
    let icon: String
    let color: Color
    let action: () -> Void
    
    init(
        title: String,
        description: String? = nil,
        icon: String,
        color: Color = ColorPalette.Primary.main,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        CardView(onTap: action) {
            HStack(spacing: Spacing.md) {
                // Icon
                IconView(icon, style: IconStyle(
                    size: IconSize.xl,
                    color: color,
                    weight: .medium
                ))
                
                // Content
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .cardTitle()
                    
                    if let description = description {
                        Text(description)
                            .cardSubtitle()
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorPalette.Text.tertiary)
            }
        }
    }
}

// MARK: - Progress Card
struct ProgressCard: View {
    let title: String
    let subtitle: String?
    let progress: Double
    let total: String?
    let color: Color
    
    init(
        title: String,
        subtitle: String? = nil,
        progress: Double,
        total: String? = nil,
        color: Color = ColorPalette.Primary.main
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.total = total
        self.color = color
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(title)
                            .cardTitle()
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .cardSubtitle()
                        }
                    }
                    
                    Spacer()
                    
                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(Typography.Title.large)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
                
                // Progress Bar
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                
                // Total
                if let total = total {
                    HStack {
                        Spacer()
                        Text(total)
                            .font(Typography.Caption.regular)
                            .foregroundColor(ColorPalette.Text.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - List Card
struct ListCard<Item: Identifiable, ItemView: View>: View {
    let title: String
    let items: [Item]
    let itemView: (Item) -> ItemView
    let showAll: (() -> Void)?
    
    init(
        title: String,
        items: [Item],
        showAll: (() -> Void)? = nil,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.title = title
        self.items = items
        self.showAll = showAll
        self.itemView = itemView
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    Text(title)
                        .cardTitle()
                    
                    Spacer()
                    
                    if let showAll = showAll {
                        Button("Все", action: showAll)
                            .font(Typography.Body.medium)
                            .foregroundColor(ColorPalette.Primary.main)
                    }
                }
                
                // Items
                VStack(spacing: Spacing.sm) {
                    ForEach(items.prefix(3)) { item in
                        itemView(item)
                    }
                }
                
                // Show more indicator
                if items.count > 3 {
                    HStack {
                        Spacer()
                        Text("+ \(items.count - 3) еще")
                            .font(Typography.Caption.regular)
                            .foregroundColor(ColorPalette.Text.tertiary)
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Empty State Card
struct EmptyStateCard: View {
    let title: String
    let description: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        description: String,
        icon: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        CardView(style: .outlined) {
            VStack(spacing: Spacing.lg) {
                // Icon
                IconView(icon, style: IconStyle(
                    size: IconSize.huge,
                    color: ColorPalette.Text.tertiary,
                    weight: .regular
                ))
                
                // Content
                VStack(spacing: Spacing.sm) {
                    Text(title)
                        .font(Typography.Headline.small)
                        .foregroundColor(ColorPalette.Text.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(Typography.Body.medium)
                        .foregroundColor(ColorPalette.Text.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                
                // Action
                if let actionTitle = actionTitle, let action = action {
                    PrimaryButton(actionTitle, size: .medium, action: action)
                }
            }
            .padding(.vertical, Spacing.xl)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct CardsPreview: View {
    @State private var progress: Double = 0.7
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sectionSpacing) {
                
                // Info Cards
                cardSection("Info Cards") {
                    VStack(spacing: Spacing.md) {
                        InfoCard(
                            title: "Привычки",
                            subtitle: "Выполнено сегодня",
                            icon: "repeat.circle",
                            value: "5/8"
                        )
                        
                        InfoCard(
                            title: "Задачи",
                            subtitle: "Осталось на сегодня",
                            icon: "checkmark.circle",
                            value: "3",
                            style: .elevated
                        ) {
                            print("Tasks tapped")
                        }
                    }
                }
                
                // Statistic Cards
                cardSection("Statistic Cards") {
                    HStack(spacing: Spacing.md) {
                        StatisticCard(
                            title: "Доходы",
                            value: "₽50,000",
                            change: "+12%",
                            changeType: .positive,
                            icon: "arrow.up.circle",
                            color: ColorPalette.Financial.income
                        )
                        
                        StatisticCard(
                            title: "Расходы",
                            value: "₽35,000",
                            change: "-5%",
                            changeType: .negative,
                            icon: "arrow.down.circle",
                            color: ColorPalette.Financial.expense
                        )
                    }
                }
                
                // Action Cards
                cardSection("Action Cards") {
                    VStack(spacing: Spacing.md) {
                        ActionCard(
                            title: "Создать привычку",
                            description: "Добавьте новую полезную привычку",
                            icon: "plus.circle",
                            color: ColorPalette.Habits.health
                        ) {
                            print("Create habit")
                        }
                        
                        ActionCard(
                            title: "Добавить задачу",
                            description: "Запланируйте новую задачу",
                            icon: "note.text.badge.plus",
                            color: ColorPalette.Primary.main
                        ) {
                            print("Add task")
                        }
                    }
                }
                
                // Progress Card
                cardSection("Progress Card") {
                    ProgressCard(
                        title: "Прогресс за месяц",
                        subtitle: "Выполнено привычек",
                        progress: progress,
                        total: "21 из 30 дней",
                        color: ColorPalette.Semantic.success
                    )
                }
                
                // Empty State
                cardSection("Empty State") {
                    EmptyStateCard(
                        title: "Нет данных",
                        description: "Здесь будут отображаться ваши записи, когда вы их создадите",
                        icon: "tray",
                        actionTitle: "Добавить первую запись"
                    ) {
                        print("Add first item")
                    }
                }
            }
            .screenPadding()
        }
        .background(ColorPalette.Background.primary)
        .navigationTitle("Cards")
    }
    
    @ViewBuilder
    private func cardSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.Headline.medium)
                .foregroundColor(ColorPalette.Text.primary)
            
            content()
        }
    }
}

#Preview {
    CardsPreview()
}
#endif 