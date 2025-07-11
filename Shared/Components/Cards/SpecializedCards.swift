//
//  SpecializedCards.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Специализированные карточки с различными стилями
//

import SwiftUI

// MARK: - Habit Card
struct HabitCard: View {
    let habit: HabitCardData
    let style: HabitCardStyle
    let onTap: (() -> Void)?
    let onComplete: (() -> Void)?
    
    enum HabitCardStyle {
        case compact
        case detailed
        case streak
    }
    
    struct HabitCardData {
        let name: String
        let category: String
        let streak: Int
        let isCompleted: Bool
        let progress: Double
        let color: Color
        let icon: String
        
        init(
            name: String,
            category: String,
            streak: Int = 0,
            isCompleted: Bool = false,
            progress: Double = 0.0,
            color: Color = ColorPalette.Habits.health,
            icon: String = "repeat.circle"
        ) {
            self.name = name
            self.category = category
            self.streak = streak
            self.isCompleted = isCompleted
            self.progress = progress
            self.color = color
            self.icon = icon
        }
    }
    
    var body: some View {
        CardView(
            style: .standard,
            state: habit.isCompleted ? .selected : .normal,
            onTap: onTap
        ) {
            switch style {
            case .compact:
                compactLayout
            case .detailed:
                detailedLayout
            case .streak:
                streakLayout
            }
        }
    }
    
    @ViewBuilder
    private var compactLayout: some View {
        HStack(spacing: AdaptiveSpacing.padding(12)) {
            // Icon and completion indicator
            ZStack {
                Circle()
                    .fill(habit.color.opacity(habit.isCompleted ? 1.0 : 0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: habit.isCompleted ? "checkmark" : habit.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(habit.isCompleted ? ColorPalette.Text.onColor : habit.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(size: AdaptiveTypography.body(), weight: .medium))
                    .foregroundColor(ColorPalette.Text.primary)
                    .lineLimit(1)
                
                Text(habit.category)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Text.secondary)
            }
            
            Spacer()
            
            // Complete button
            if let onComplete = onComplete {
                Button(action: onComplete) {
                    Image(systemName: habit.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(habit.isCompleted ? ColorPalette.Semantic.success : ColorPalette.Text.tertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var detailedLayout: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(12)) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.system(size: AdaptiveTypography.headline(), weight: .semibold))
                        .foregroundColor(ColorPalette.Text.primary)
                        .lineLimit(2)
                    
                    Text(habit.category)
                        .font(.system(size: AdaptiveTypography.body(12)))
                        .foregroundColor(habit.color)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(habit.color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: habit.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(habit.color)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                Text("Прогресс")
                    .font(.system(size: AdaptiveTypography.body(12), weight: .medium))
                    .foregroundColor(ColorPalette.Text.secondary)
                
                PlannerProgressBar(
                    progress: habit.progress,
                    height: 6,
                    foregroundColor: habit.color,
                    showPercentage: false
                )
            }
            
            // Bottom row
            HStack {
                // Streak info
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.system(size: 14))
                        .foregroundColor(ColorPalette.Semantic.warning)
                    
                    Text("\(habit.streak) дней")
                        .font(.system(size: AdaptiveTypography.body(12), weight: .medium))
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                // Complete button
                if let onComplete = onComplete {
                    Button(action: onComplete) {
                        HStack(spacing: 6) {
                            Image(systemName: habit.isCompleted ? "checkmark" : "circle")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(habit.isCompleted ? "Выполнено" : "Отметить")
                                .font(.system(size: AdaptiveTypography.body(12), weight: .medium))
                        }
                        .foregroundColor(habit.isCompleted ? ColorPalette.Semantic.success : habit.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(habit.isCompleted ? ColorPalette.Semantic.success.opacity(0.1) : habit.color.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    @ViewBuilder
    private var streakLayout: some View {
        VStack(spacing: AdaptiveSpacing.padding(16)) {
            // Streak visualization
            ZStack {
                Circle()
                    .stroke(habit.color.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: min(habit.progress, 1.0))
                    .stroke(habit.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(habit.streak)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("дней")
                        .font(.system(size: 10))
                        .foregroundColor(ColorPalette.Text.secondary)
                }
            }
            
            // Content
            VStack(spacing: 4) {
                Text(habit.name)
                    .font(.system(size: AdaptiveTypography.body(), weight: .semibold))
                    .foregroundColor(ColorPalette.Text.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(habit.category)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(habit.color)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Task Card
struct TaskCard: View {
    let task: TaskCardData
    let style: TaskCardStyle
    let onTap: (() -> Void)?
    let onComplete: (() -> Void)?
    
    enum TaskCardStyle {
        case list
        case kanban
        case calendar
    }
    
    struct TaskCardData {
        let title: String
        let description: String?
        let priority: Priority
        let dueDate: Date?
        let isCompleted: Bool
        let tags: [String]
        let progress: Double?
        
        enum Priority: CaseIterable {
            case low
            case medium
            case high
            case urgent
            
            var color: Color {
                switch self {
                case .low: return ColorPalette.Priority.low
                case .medium: return ColorPalette.Priority.medium
                case .high: return ColorPalette.Priority.high
                case .urgent: return ColorPalette.Priority.urgent
                }
            }
            
            var title: String {
                switch self {
                case .low: return "Низкий"
                case .medium: return "Средний"
                case .high: return "Высокий"
                case .urgent: return "Срочный"
                }
            }
        }
    }
    
    var body: some View {
        CardView(
            style: .standard,
            state: task.isCompleted ? .selected : .normal,
            onTap: onTap
        ) {
            switch style {
            case .list:
                listLayout
            case .kanban:
                kanbanLayout
            case .calendar:
                calendarLayout
            }
        }
    }
    
    @ViewBuilder
    private var listLayout: some View {
        HStack(spacing: AdaptiveSpacing.padding(12)) {
            // Complete checkbox
            Button(action: { onComplete?() }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(task.isCompleted ? ColorPalette.Semantic.success : ColorPalette.Text.tertiary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: AdaptiveTypography.body(), weight: .medium))
                    .foregroundColor(task.isCompleted ? ColorPalette.Text.secondary : ColorPalette.Text.primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                
                if let description = task.description {
                    Text(description)
                        .font(.system(size: AdaptiveTypography.body(12)))
                        .foregroundColor(ColorPalette.Text.secondary)
                        .lineLimit(1)
                }
                
                // Tags
                if !task.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(ColorPalette.Primary.main)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ColorPalette.Primary.main.opacity(0.1))
                                )
                        }
                        
                        if task.tags.count > 2 {
                            Text("+\(task.tags.count - 2)")
                                .font(.system(size: 10))
                                .foregroundColor(ColorPalette.Text.tertiary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Priority and due date
            VStack(alignment: .trailing, spacing: 4) {
                // Priority indicator
                Circle()
                    .fill(task.priority.color)
                    .frame(width: 8, height: 8)
                
                // Due date
                if let dueDate = task.dueDate {
                    Text(formatDate(dueDate))
                        .font(.system(size: AdaptiveTypography.body(10)))
                        .foregroundColor(isOverdue(dueDate) ? ColorPalette.Semantic.error : ColorPalette.Text.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var kanbanLayout: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(12)) {
            // Header with priority
            HStack {
                Text(task.title)
                    .font(.system(size: AdaptiveTypography.body(), weight: .semibold))
                    .foregroundColor(ColorPalette.Text.primary)
                    .lineLimit(2)
                
                Spacer()
                
                // Priority badge
                Text(task.priority.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(task.priority.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(task.priority.color.opacity(0.15))
                    )
            }
            
            // Description
            if let description = task.description {
                Text(description)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Text.secondary)
                    .lineLimit(3)
            }
            
            // Progress if available
            if let progress = task.progress {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Прогресс: \(Int(progress * 100))%")
                        .font(.system(size: AdaptiveTypography.body(10)))
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    PlannerProgressBar(
                        progress: progress,
                        height: 4,
                        showPercentage: false
                    )
                }
            }
            
            // Footer
            HStack {
                // Tags
                if !task.tags.isEmpty {
                    ForEach(task.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(ColorPalette.Secondary.main)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ColorPalette.Secondary.main.opacity(0.1))
                            )
                    }
                }
                
                Spacer()
                
                // Due date
                if let dueDate = task.dueDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8))
                        
                        Text(formatDate(dueDate))
                            .font(.system(size: AdaptiveTypography.body(9)))
                    }
                    .foregroundColor(isOverdue(dueDate) ? ColorPalette.Semantic.error : ColorPalette.Text.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var calendarLayout: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            // Time indicator
            if let dueDate = task.dueDate {
                Text(formatTime(dueDate))
                    .font(.system(size: AdaptiveTypography.body(12), weight: .semibold))
                    .foregroundColor(task.priority.color)
            }
            
            // Title
            Text(task.title)
                .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                .foregroundColor(ColorPalette.Text.primary)
                .lineLimit(2)
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(task.isCompleted ? ColorPalette.Semantic.success : task.priority.color)
                    .frame(width: 6, height: 6)
                
                Text(task.isCompleted ? "Выполнено" : task.priority.title)
                    .font(.system(size: 10))
                    .foregroundColor(ColorPalette.Text.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !task.isCompleted
    }
}

// MARK: - Statistic Card
struct StatisticCard: View {
    let data: StatisticData
    let style: StatisticStyle
    let onTap: (() -> Void)?
    
    enum StatisticStyle {
        case compact
        case detailed
        case trend
    }
    
    struct StatisticData {
        let title: String
        let value: String
        let change: String?
        let changeType: ChangeType
        let icon: String
        let color: Color
        let chartData: [Double]?
        
        enum ChangeType {
            case positive
            case negative
            case neutral
            
            var color: Color {
                switch self {
                case .positive: return ColorPalette.Semantic.success
                case .negative: return ColorPalette.Semantic.error
                case .neutral: return ColorPalette.Text.secondary
                }
            }
            
            var icon: String {
                switch self {
                case .positive: return "arrow.up.right"
                case .negative: return "arrow.down.right"
                case .neutral: return "minus"
                }
            }
        }
    }
    
    var body: some View {
        CardView(style: .standard, onTap: onTap) {
            switch style {
            case .compact:
                compactStatistic
            case .detailed:
                detailedStatistic
            case .trend:
                trendStatistic
            }
        }
    }
    
    @ViewBuilder
    private var compactStatistic: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            HStack {
                Image(systemName: data.icon)
                    .font(.system(size: 16))
                    .foregroundColor(data.color)
                
                Spacer()
                
                if let change = data.change {
                    HStack(spacing: 2) {
                        Image(systemName: data.changeType.icon)
                            .font(.system(size: 10))
                        
                        Text(change)
                            .font(.system(size: AdaptiveTypography.body(10)))
                    }
                    .foregroundColor(data.changeType.color)
                }
            }
            
            Text(data.value)
                .font(.system(size: AdaptiveTypography.title(20), weight: .bold))
                .foregroundColor(ColorPalette.Text.primary)
            
            Text(data.title)
                .font(.system(size: AdaptiveTypography.body(12)))
                .foregroundColor(ColorPalette.Text.secondary)
                .lineLimit(2)
        }
    }
    
    @ViewBuilder
    private var detailedStatistic: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(12)) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.system(size: AdaptiveTypography.body(), weight: .medium))
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text(data.value)
                        .font(.system(size: AdaptiveTypography.title(24), weight: .bold))
                        .foregroundColor(data.color)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(data.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: data.icon)
                        .font(.system(size: 18))
                        .foregroundColor(data.color)
                }
            }
            
            // Change indicator
            if let change = data.change {
                HStack(spacing: 6) {
                    Image(systemName: data.changeType.icon)
                        .font(.system(size: 12))
                    
                    Text("\(change) за период")
                        .font(.system(size: AdaptiveTypography.body(12)))
                    
                    Spacer()
                }
                .foregroundColor(data.changeType.color)
            }
        }
    }
    
    @ViewBuilder
    private var trendStatistic: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(12)) {
            // Header
            HStack {
                Text(data.title)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Text.secondary)
                
                Spacer()
                
                if let change = data.change {
                    HStack(spacing: 2) {
                        Image(systemName: data.changeType.icon)
                            .font(.system(size: 10))
                        
                        Text(change)
                            .font(.system(size: AdaptiveTypography.body(10)))
                    }
                    .foregroundColor(data.changeType.color)
                }
            }
            
            // Value
            Text(data.value)
                .font(.system(size: AdaptiveTypography.title(20), weight: .bold))
                .foregroundColor(ColorPalette.Text.primary)
            
            // Mini chart
            if let chartData = data.chartData, !chartData.isEmpty {
                miniTrendChart(data: chartData)
                    .frame(height: 30)
            }
        }
    }
    
    @ViewBuilder
    private func miniTrendChart(data: [Double]) -> some View {
        GeometryReader { geometry in
            let maxValue = data.max() ?? 1
            let minValue = data.min() ?? 0
            let range = maxValue - minValue
            
            Path { path in
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * (geometry.size.width / CGFloat(data.count - 1))
                    let y = geometry.size.height - (CGFloat((value - minValue) / range) * geometry.size.height)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(self.data.color, lineWidth: 2)
        }
    }
}

// MARK: - Action Card
struct ActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let style: ActionCardStyle
    let action: () -> Void
    
    enum ActionCardStyle {
        case filled
        case outline
        case minimal
    }
    
    var body: some View {
        Button(action: action) {
            CardView(style: style == .filled ? .filled : .standard) {
                HStack(spacing: AdaptiveSpacing.padding(16)) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: AdaptiveTypography.body(), weight: .semibold))
                            .foregroundColor(ColorPalette.Text.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(description)
                            .font(.system(size: AdaptiveTypography.body(12)))
                            .foregroundColor(ColorPalette.Text.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Arrow
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ColorPalette.Text.tertiary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconBackgroundColor: Color {
        switch style {
        case .filled:
            return color.opacity(0.2)
        case .outline, .minimal:
            return color.opacity(0.1)
        }
    }
    
    private var iconColor: Color {
        return color
    }
}

// MARK: - Preview
#Preview("Specialized Cards") {
    ScrollView {
        VStack(spacing: 20) {
            // Habit Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Habit Cards")
                    .font(.headline)
                    .padding(.horizontal)
                
                HabitCard(
                    habit: HabitCard.HabitCardData(
                        name: "Утренняя зарядка",
                        category: "Здоровье",
                        streak: 15,
                        isCompleted: true,
                        progress: 0.75
                    ),
                    style: .compact,
                    onTap: {},
                    onComplete: {}
                )
                .padding(.horizontal)
                
                HabitCard(
                    habit: HabitCard.HabitCardData(
                        name: "Чтение книг",
                        category: "Обучение",
                        streak: 7,
                        progress: 0.4
                    ),
                    style: .detailed,
                    onTap: {},
                    onComplete: {}
                )
                .padding(.horizontal)
            }
            
            // Task Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Cards")
                    .font(.headline)
                    .padding(.horizontal)
                
                TaskCard(
                    task: TaskCard.TaskCardData(
                        title: "Подготовить презентацию",
                        description: "Для встречи с клиентом",
                        priority: .high,
                        dueDate: Date().addingTimeInterval(86400),
                        isCompleted: false,
                        tags: ["Работа", "Срочно"]
                    ),
                    style: .list,
                    onTap: {},
                    onComplete: {}
                )
                .padding(.horizontal)
            }
            
            // Statistic Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Statistic Cards")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack {
                    StatisticCard(
                        data: StatisticCard.StatisticData(
                            title: "Выполнено привычек",
                            value: "24",
                            change: "+12%",
                            changeType: .positive,
                            icon: "chart.bar",
                            color: ColorPalette.Semantic.success
                        ),
                        style: .compact
                    )
                    
                    StatisticCard(
                        data: StatisticCard.StatisticData(
                            title: "Активные задачи",
                            value: "8",
                            change: "-3",
                            changeType: .negative,
                            icon: "list.bullet",
                            color: ColorPalette.Primary.main
                        ),
                        style: .compact
                    )
                }
                .padding(.horizontal)
            }
            
            // Action Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Action Cards")
                    .font(.headline)
                    .padding(.horizontal)
                
                ActionCard(
                    title: "Создать привычку",
                    description: "Добавьте новую полезную привычку",
                    icon: "plus.circle",
                    color: ColorPalette.Habits.health,
                    style: .filled
                ) {}
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .adaptivePreviews()
} 