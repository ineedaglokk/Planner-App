//
//  ChartComponents.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Обертки над Swift Charts
//

import SwiftUI
import Charts

// MARK: - Chart Data Models
struct ChartDataPoint: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: Double
    let date: Date?
    let category: String?
    let color: Color?
    
    init(label: String, value: Double, date: Date? = nil, category: String? = nil, color: Color? = nil) {
        self.label = label
        self.value = value
        self.date = date
        self.category = category
        self.color = color
    }
}

struct TrendDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Double
    let category: String?
    
    init(date: Date, value: Double, category: String? = nil) {
        self.date = date
        self.value = value
        self.category = category
    }
}

// MARK: - Progress Ring Chart
struct ProgressRingChart: View {
    let progress: Double // 0.0 to 1.0
    let total: Double?
    let title: String
    let subtitle: String?
    let size: CGFloat
    let lineWidth: CGFloat
    let colors: [Color]
    let showValueInCenter: Bool
    
    init(
        progress: Double,
        total: Double? = nil,
        title: String,
        subtitle: String? = nil,
        size: CGFloat = 120,
        lineWidth: CGFloat? = nil,
        colors: [Color] = [ColorPalette.Primary.main],
        showValueInCenter: Bool = true
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.total = total
        self.title = title
        self.subtitle = subtitle
        self.size = size
        self.lineWidth = lineWidth ?? size * 0.1
        self.colors = colors
        self.showValueInCenter = showValueInCenter
    }
    
    var body: some View {
        VStack(spacing: AdaptiveSpacing.padding(8)) {
            ZStack {
                // Background Ring
                Circle()
                    .stroke(ColorPalette.Border.separator, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                
                // Progress Ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: progress)
                
                // Center Content
                if showValueInCenter {
                    VStack(spacing: 2) {
                        if let total = total {
                            Text("\(Int(progress * total))")
                                .font(.system(size: size * 0.15, weight: .bold))
                                .foregroundColor(ColorPalette.Text.primary)
                            Text("из \(Int(total))")
                                .font(.system(size: size * 0.08))
                                .foregroundColor(ColorPalette.Text.secondary)
                        } else {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: size * 0.12, weight: .bold))
                                .foregroundColor(ColorPalette.Text.primary)
                        }
                    }
                }
            }
            
            // Labels
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                    .foregroundColor(ColorPalette.Text.primary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: AdaptiveTypography.body(12)))
                        .foregroundColor(ColorPalette.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Int(progress * 100)) процентов")
        .accessibilityHint(subtitle ?? "")
    }
}

// MARK: - Bar Chart
struct PlannerBarChart: View {
    let data: [ChartDataPoint]
    let title: String
    let subtitle: String?
    let showLabels: Bool
    let showValues: Bool
    let isHorizontal: Bool
    let colors: [Color]
    
    init(
        data: [ChartDataPoint],
        title: String,
        subtitle: String? = nil,
        showLabels: Bool = true,
        showValues: Bool = false,
        isHorizontal: Bool = false,
        colors: [Color] = [ColorPalette.Primary.main, ColorPalette.Secondary.main]
    ) {
        self.data = data
        self.title = title
        self.subtitle = subtitle
        self.showLabels = showLabels
        self.showValues = showValues
        self.isHorizontal = isHorizontal
        self.colors = colors
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(16)) {
            // Header
            chartHeader
            
            // Chart
            Chart(data) { dataPoint in
                if isHorizontal {
                    BarMark(
                        x: .value("Value", dataPoint.value),
                        y: .value("Category", dataPoint.label)
                    )
                    .foregroundStyle(colorForDataPoint(dataPoint))
                    .annotation(position: .trailing) {
                        if showValues {
                            Text("\(Int(dataPoint.value))")
                                .font(.system(size: AdaptiveTypography.body(12)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                } else {
                    BarMark(
                        x: .value("Category", dataPoint.label),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(colorForDataPoint(dataPoint))
                    .annotation(position: .top) {
                        if showValues {
                            Text("\(Int(dataPoint.value))")
                                .font(.system(size: AdaptiveTypography.body(12)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                }
            }
            .frame(height: isHorizontal ? CGFloat(data.count * 40 + 60) : 200)
            .chartXAxis(showLabels ? .automatic : .hidden)
            .chartYAxis(showLabels ? .automatic : .hidden)
            .animation(.easeInOut(duration: 0.8), value: data)
        }
        .adaptivePadding()
        .background(ColorPalette.Background.surface)
        .adaptiveCornerRadius()
        .cardShadow()
    }
    
    @ViewBuilder
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: AdaptiveTypography.headline(), weight: .semibold))
                .foregroundColor(ColorPalette.Text.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: AdaptiveTypography.body(14)))
                    .foregroundColor(ColorPalette.Text.secondary)
            }
        }
    }
    
    private func colorForDataPoint(_ dataPoint: ChartDataPoint) -> Color {
        if let color = dataPoint.color {
            return color
        }
        
        guard let index = data.firstIndex(where: { $0.id == dataPoint.id }) else {
            return colors.first ?? ColorPalette.Primary.main
        }
        
        return colors[index % colors.count]
    }
}

// MARK: - Line Chart
struct PlannerLineChart: View {
    let data: [TrendDataPoint]
    let title: String
    let subtitle: String?
    let showPoints: Bool
    let showArea: Bool
    let colors: [Color]
    let dateFormatter: DateFormatter
    
    init(
        data: [TrendDataPoint],
        title: String,
        subtitle: String? = nil,
        showPoints: Bool = true,
        showArea: Bool = false,
        colors: [Color] = [ColorPalette.Primary.main],
        dateFormat: String = "dd.MM"
    ) {
        self.data = data.sorted { $0.date < $1.date }
        self.title = title
        self.subtitle = subtitle
        self.showPoints = showPoints
        self.showArea = showArea
        self.colors = colors
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = dateFormat
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(16)) {
            // Header
            chartHeader
            
            // Chart
            Chart(data) { dataPoint in
                if showArea {
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colors.first?.opacity(0.3) ?? ColorPalette.Primary.main.opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Value", dataPoint.value)
                )
                .foregroundStyle(colors.first ?? ColorPalette.Primary.main)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                
                if showPoints {
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(colors.first ?? ColorPalette.Primary.main)
                    .symbolSize(60)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                    AxisValueLabel() {
                        if let date = value.as(Date.self) {
                            Text(dateFormatter.string(from: date))
                                .font(.system(size: AdaptiveTypography.body(10)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel() {
                        if let intValue = value.as(Double.self) {
                            Text("\(Int(intValue))")
                                .font(.system(size: AdaptiveTypography.body(10)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(ColorPalette.Border.separator)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: data)
        }
        .adaptivePadding()
        .background(ColorPalette.Background.surface)
        .adaptiveCornerRadius()
        .cardShadow()
    }
    
    @ViewBuilder
    private var chartHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: AdaptiveTypography.headline(), weight: .semibold))
                    .foregroundColor(ColorPalette.Text.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: AdaptiveTypography.body(14)))
                        .foregroundColor(ColorPalette.Text.secondary)
                }
            }
            
            Spacer()
            
            // Trend indicator
            if data.count >= 2 {
                let trend = data.last!.value - data.first!.value
                HStack(spacing: 4) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: AdaptiveIcons.small))
                        .foregroundColor(trend >= 0 ? ColorPalette.Semantic.success : ColorPalette.Semantic.error)
                    
                    Text(String(format: "%.1f", abs(trend)))
                        .font(.system(size: AdaptiveTypography.body(12), weight: .medium))
                        .foregroundColor(trend >= 0 ? ColorPalette.Semantic.success : ColorPalette.Semantic.error)
                }
            }
        }
    }
}

// MARK: - Pie Chart
struct PlannerPieChart: View {
    let data: [ChartDataPoint]
    let title: String
    let subtitle: String?
    let showLegend: Bool
    let colors: [Color]
    
    init(
        data: [ChartDataPoint],
        title: String,
        subtitle: String? = nil,
        showLegend: Bool = true,
        colors: [Color] = [
            ColorPalette.Primary.main,
            ColorPalette.Secondary.main,
            ColorPalette.Semantic.success,
            ColorPalette.Semantic.warning,
            ColorPalette.Semantic.info
        ]
    ) {
        self.data = data
        self.title = title
        self.subtitle = subtitle
        self.showLegend = showLegend
        self.colors = colors
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(16)) {
            // Header
            chartHeader
            
            HStack(spacing: AdaptiveSpacing.padding(20)) {
                // Chart
                Chart(data) { dataPoint in
                    SectorMark(
                        angle: .value("Value", dataPoint.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(colorForDataPoint(dataPoint))
                    .annotation(position: .overlay) {
                        Text("\(Int(dataPoint.value))")
                            .font(.system(size: AdaptiveTypography.body(10), weight: .semibold))
                            .foregroundColor(ColorPalette.Text.onColor)
                    }
                }
                .frame(width: 160, height: 160)
                .animation(.easeInOut(duration: 0.8), value: data)
                
                // Legend
                if showLegend {
                    VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
                        ForEach(data) { dataPoint in
                            HStack(spacing: AdaptiveSpacing.padding(8)) {
                                Circle()
                                    .fill(colorForDataPoint(dataPoint))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dataPoint.label)
                                        .font(.system(size: AdaptiveTypography.body(12), weight: .medium))
                                        .foregroundColor(ColorPalette.Text.primary)
                                    
                                    Text("\(Int(dataPoint.value))")
                                        .font(.system(size: AdaptiveTypography.body(10)))
                                        .foregroundColor(ColorPalette.Text.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .adaptivePadding()
        .background(ColorPalette.Background.surface)
        .adaptiveCornerRadius()
        .cardShadow()
    }
    
    @ViewBuilder
    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: AdaptiveTypography.headline(), weight: .semibold))
                .foregroundColor(ColorPalette.Text.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: AdaptiveTypography.body(14)))
                    .foregroundColor(ColorPalette.Text.secondary)
            }
        }
    }
    
    private func colorForDataPoint(_ dataPoint: ChartDataPoint) -> Color {
        if let color = dataPoint.color {
            return color
        }
        
        guard let index = data.firstIndex(where: { $0.id == dataPoint.id }) else {
            return colors.first ?? ColorPalette.Primary.main
        }
        
        return colors[index % colors.count]
    }
}

// MARK: - Habit Streak Chart
struct HabitStreakChart: View {
    let streakData: [Date: Bool] // Date -> completed
    let title: String
    let currentStreak: Int
    let bestStreak: Int
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(16)) {
            // Header with stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: AdaptiveTypography.headline(), weight: .semibold))
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("Отслеживание за последние 30 дней")
                        .font(.system(size: AdaptiveTypography.body(12)))
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 16) {
                        VStack(alignment: .center, spacing: 2) {
                            Text("\(currentStreak)")
                                .font(.system(size: AdaptiveTypography.headline(18), weight: .bold))
                                .foregroundColor(ColorPalette.Primary.main)
                            Text("Текущая")
                                .font(.system(size: AdaptiveTypography.body(10)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                        
                        VStack(alignment: .center, spacing: 2) {
                            Text("\(bestStreak)")
                                .font(.system(size: AdaptiveTypography.headline(18), weight: .bold))
                                .foregroundColor(ColorPalette.Semantic.success)
                            Text("Лучшая")
                                .font(.system(size: AdaptiveTypography.body(10)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                }
            }
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Day headers
                ForEach(["П", "В", "С", "Ч", "П", "С", "В"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: AdaptiveTypography.body(10), weight: .medium))
                        .foregroundColor(ColorPalette.Text.secondary)
                        .frame(height: 20)
                }
                
                // Calendar days
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .adaptivePadding()
        .background(ColorPalette.Background.surface)
        .adaptiveCornerRadius()
        .cardShadow()
    }
    
    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isCompleted = streakData[calendar.startOfDay(for: date)] ?? false
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()
        
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cellBackgroundColor(isCompleted: isCompleted, isToday: isToday, isFuture: isFuture))
                .frame(width: 28, height: 28)
            
            if isToday {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ColorPalette.Primary.main, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
            
            Text(dateFormatter.string(from: date))
                .font(.system(size: AdaptiveTypography.body(10), weight: isToday ? .bold : .medium))
                .foregroundColor(textColor(isCompleted: isCompleted, isToday: isToday, isFuture: isFuture))
        }
        .accessibilityLabel("\(dateFormatter.string(from: date)) число, \(isCompleted ? "выполнено" : "не выполнено")")
    }
    
    private func cellBackgroundColor(isCompleted: Bool, isToday: Bool, isFuture: Bool) -> Color {
        if isFuture {
            return ColorPalette.Background.grouped
        } else if isCompleted {
            return ColorPalette.Semantic.success
        } else {
            return ColorPalette.Background.grouped
        }
    }
    
    private func textColor(isCompleted: Bool, isToday: Bool, isFuture: Bool) -> Color {
        if isFuture {
            return ColorPalette.Text.tertiary
        } else if isCompleted {
            return ColorPalette.Text.onColor
        } else {
            return ColorPalette.Text.secondary
        }
    }
    
    private var calendarDays: [Date?] {
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today)!
        let startOfMonth = calendar.dateInterval(of: .month, for: thirtyDaysAgo)!.start
        let startWeekday = calendar.component(.weekday, from: startOfMonth)
        let adjustedStartWeekday = (startWeekday + 5) % 7 // Convert to Monday = 0
        
        var days: [Date?] = []
        
        // Add empty cells for days before the start of the period
        for _ in 0..<adjustedStartWeekday {
            days.append(nil)
        }
        
        // Add the last 30 days
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: i, to: thirtyDaysAgo) {
                days.append(date)
            }
        }
        
        return days
    }
}

// MARK: - Preview
#Preview("Charts") {
    ScrollView {
        VStack(spacing: 20) {
            // Progress Ring
            HStack {
                ProgressRingChart(
                    progress: 0.75,
                    total: 8,
                    title: "Привычки сегодня",
                    subtitle: "Выполнено"
                )
                
                ProgressRingChart(
                    progress: 0.6,
                    title: "Месячная цель",
                    colors: [ColorPalette.Secondary.main]
                )
            }
            
            // Bar Chart
            PlannerBarChart(
                data: [
                    ChartDataPoint(label: "Пн", value: 5),
                    ChartDataPoint(label: "Вт", value: 3),
                    ChartDataPoint(label: "Ср", value: 7),
                    ChartDataPoint(label: "Чт", value: 4),
                    ChartDataPoint(label: "Пт", value: 6)
                ],
                title: "Привычки по дням",
                subtitle: "На этой неделе"
            )
            
            // Line Chart
            PlannerLineChart(
                data: Array(0..<7).map { i in
                    TrendDataPoint(
                        date: Calendar.current.date(byAdding: .day, value: i, to: Date())!,
                        value: Double.random(in: 1...10)
                    )
                },
                title: "Прогресс за неделю",
                showArea: true
            )
            
            // Pie Chart
            PlannerPieChart(
                data: [
                    ChartDataPoint(label: "Здоровье", value: 40),
                    ChartDataPoint(label: "Работа", value: 30),
                    ChartDataPoint(label: "Обучение", value: 20),
                    ChartDataPoint(label: "Досуг", value: 10)
                ],
                title: "Категории привычек"
            )
        }
        .adaptivePadding()
    }
    .adaptivePreviews()
} 