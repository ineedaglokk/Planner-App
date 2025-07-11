import Foundation
import SwiftUI

// MARK: - TrendsViewModel

@Observable
final class TrendsViewModel {
    
    // MARK: - State
    
    struct State {
        var selectedHabits: Set<Habit> = []
        var selectedPeriod: AnalyticsPeriod = .month
        var selectedMetric: TrendMetric = .completionRate
        var comparisonMode: ComparisonMode = .individual
        var isLoading: Bool = false
        var error: AppError?
        
        // Trends Data
        var individualTrends: [Habit: HabitTrends] = [:]
        var overallAnalytics: OverallAnalytics?
        var habitCorrelationMatrix: CorrelationMatrix?
        var performanceMetrics: [Habit: PerformanceMetrics] = [:]
        
        // Chart Data
        var chartData: [TrendChartData] = []
        var selectedDataPoint: TrendDataPoint?
        
        // View State
        var showingHabitPicker: Bool = false
        var showingPeriodPicker: Bool = false
        var showingMetricPicker: Bool = false
        var selectedChartType: ChartType = .line
    }
    
    // MARK: - Input
    
    enum Input {
        case habitsSelected(Set<Habit>)
        case periodChanged(AnalyticsPeriod)
        case metricChanged(TrendMetric)
        case comparisonModeChanged(ComparisonMode)
        case chartTypeChanged(ChartType)
        case dataPointSelected(TrendDataPoint?)
        case loadTrends
        case refreshTrends
        case showHabitPicker
        case hideHabitPicker
        case showPeriodPicker
        case hidePeriodPicker
        case showMetricPicker
        case hideMetricPicker
        case dismissError
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let analyticsService: HabitAnalyticsServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    init(
        analyticsService: HabitAnalyticsServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol
    ) {
        self.analyticsService = analyticsService
        self.errorHandlingService = errorHandlingService
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .habitsSelected(let habits):
                state.selectedHabits = habits
                state.showingHabitPicker = false
                await loadTrends()
            case .periodChanged(let period):
                state.selectedPeriod = period
                state.showingPeriodPicker = false
                await loadTrends()
            case .metricChanged(let metric):
                state.selectedMetric = metric
                state.showingMetricPicker = false
                await updateChartData()
            case .comparisonModeChanged(let mode):
                state.comparisonMode = mode
                await updateChartData()
            case .chartTypeChanged(let type):
                state.selectedChartType = type
            case .dataPointSelected(let dataPoint):
                state.selectedDataPoint = dataPoint
            case .loadTrends:
                await loadTrends()
            case .refreshTrends:
                await refreshTrends()
            case .showHabitPicker:
                state.showingHabitPicker = true
            case .hideHabitPicker:
                state.showingHabitPicker = false
            case .showPeriodPicker:
                state.showingPeriodPicker = true
            case .hidePeriodPicker:
                state.showingPeriodPicker = false
            case .showMetricPicker:
                state.showingMetricPicker = true
            case .hideMetricPicker:
                state.showingMetricPicker = false
            case .dismissError:
                state.error = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadTrends() async {
        guard !state.selectedHabits.isEmpty else { return }
        
        state.isLoading = true
        state.error = nil
        
        do {
            // Загружаем тренды для каждой привычки
            for habit in state.selectedHabits {
                async let trends = analyticsService.getHabitTrends(habit, period: state.selectedPeriod)
                async let performance = analyticsService.getPerformanceMetrics(habit, period: state.selectedPeriod)
                
                state.individualTrends[habit] = try await trends
                state.performanceMetrics[habit] = try await performance
            }
            
            // Загружаем общую аналитику
            let habitsArray = Array(state.selectedHabits)
            async let overallAnalytics = analyticsService.getOverallAnalytics(habitsArray)
            async let correlationMatrix = analyticsService.getHabitCorrelationMatrix(habitsArray)
            
            state.overallAnalytics = try await overallAnalytics
            state.habitCorrelationMatrix = try await correlationMatrix
            
            await updateChartData()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading trends"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshTrends() async {
        await loadTrends()
    }
    
    @MainActor
    private func updateChartData() async {
        guard !state.selectedHabits.isEmpty else {
            state.chartData = []
            return
        }
        
        var chartData: [TrendChartData] = []
        
        switch state.comparisonMode {
        case .individual:
            // Показываем каждую привычку отдельно
            for habit in state.selectedHabits {
                if let trends = state.individualTrends[habit] {
                    let data = createChartData(for: habit, trends: trends, metric: state.selectedMetric)
                    chartData.append(data)
                }
            }
            
        case .combined:
            // Объединяем все привычки в один график
            let combinedData = createCombinedChartData(
                habits: Array(state.selectedHabits),
                metric: state.selectedMetric
            )
            chartData.append(combinedData)
            
        case .average:
            // Показываем средние значения
            let averageData = createAverageChartData(
                habits: Array(state.selectedHabits),
                metric: state.selectedMetric
            )
            chartData.append(averageData)
        }
        
        state.chartData = chartData
    }
    
    private func createChartData(for habit: Habit, trends: HabitTrends, metric: TrendMetric) -> TrendChartData {
        let dataPoints = trends.dataPoints.map { point in
            TrendDataPoint(
                date: point.date,
                value: transformValueForMetric(point.value, habit: habit, metric: metric)
            )
        }
        
        return TrendChartData(
            id: habit.id.uuidString,
            name: habit.name,
            color: Color(hex: habit.color) ?? .blue,
            dataPoints: dataPoints,
            trend: trends.direction,
            confidence: trends.confidenceLevel
        )
    }
    
    private func createCombinedChartData(habits: [Habit], metric: TrendMetric) -> TrendChartData {
        var combinedPoints: [Date: [Double]] = [:]
        
        // Собираем все точки данных
        for habit in habits {
            guard let trends = state.individualTrends[habit] else { continue }
            
            for point in trends.dataPoints {
                let transformedValue = transformValueForMetric(point.value, habit: habit, metric: metric)
                combinedPoints[point.date, default: []].append(transformedValue)
            }
        }
        
        // Создаем суммарные точки
        let dataPoints = combinedPoints.map { (date, values) in
            let totalValue = values.reduce(0, +)
            return TrendDataPoint(date: date, value: totalValue)
        }.sorted { $0.date < $1.date }
        
        return TrendChartData(
            id: "combined",
            name: "Общий тренд",
            color: .purple,
            dataPoints: dataPoints,
            trend: calculateOverallTrend(dataPoints),
            confidence: 0.8
        )
    }
    
    private func createAverageChartData(habits: [Habit], metric: TrendMetric) -> TrendChartData {
        var averagePoints: [Date: [Double]] = [:]
        
        // Собираем все точки данных
        for habit in habits {
            guard let trends = state.individualTrends[habit] else { continue }
            
            for point in trends.dataPoints {
                let transformedValue = transformValueForMetric(point.value, habit: habit, metric: metric)
                averagePoints[point.date, default: []].append(transformedValue)
            }
        }
        
        // Создаем средние точки
        let dataPoints = averagePoints.map { (date, values) in
            let averageValue = values.reduce(0, +) / Double(values.count)
            return TrendDataPoint(date: date, value: averageValue)
        }.sorted { $0.date < $1.date }
        
        return TrendChartData(
            id: "average",
            name: "Средний показатель",
            color: .orange,
            dataPoints: dataPoints,
            trend: calculateOverallTrend(dataPoints),
            confidence: 0.8
        )
    }
    
    private func transformValueForMetric(_ value: Double, habit: Habit, metric: TrendMetric) -> Double {
        switch metric {
        case .completionRate:
            return min(value / Double(habit.targetValue), 1.0) * 100
        case .rawValue:
            return value
        case .streak:
            // Для streak нужно использовать другие данные
            return Double(habit.currentStreak)
        case .consistency:
            // Для consistency нужно рассчитать отдельно
            return habit.completionRate * 100
        }
    }
    
    private func calculateOverallTrend(_ dataPoints: [TrendDataPoint]) -> TrendDirection {
        guard dataPoints.count >= 2 else { return .stable }
        
        let firstHalf = dataPoints.prefix(dataPoints.count / 2)
        let secondHalf = dataPoints.suffix(dataPoints.count / 2)
        
        let firstAverage = firstHalf.reduce(0.0) { $0 + $1.value } / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0.0) { $0 + $1.value } / Double(secondHalf.count)
        
        let change = (secondAverage - firstAverage) / firstAverage
        
        if change > 0.05 {
            return .improving
        } else if change < -0.05 {
            return .declining
        } else {
            return .stable
        }
    }
}

// MARK: - Extensions

extension TrendsViewModel {
    
    /// Проверяет, есть ли данные для отображения
    var hasData: Bool {
        return !state.chartData.isEmpty
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        return !state.isLoading && !hasData
    }
    
    /// Получает краткую статистику по трендам
    var trendsSummary: TrendsSummary? {
        guard let overall = state.overallAnalytics else { return nil }
        
        let improvingHabits = state.individualTrends.values.filter { $0.direction == .improving }.count
        let decliningHabits = state.individualTrends.values.filter { $0.direction == .declining }.count
        let stableHabits = state.individualTrends.values.filter { $0.direction == .stable }.count
        
        return TrendsSummary(
            totalHabits: state.selectedHabits.count,
            improvingHabits: improvingHabits,
            decliningHabits: decliningHabits,
            stableHabits: stableHabits,
            averageSuccessRate: overall.averageSuccessRate,
            averageStreak: overall.averageStreak
        )
    }
    
    /// Получает лучшие и худшие привычки по выбранной метрике
    var performanceRanking: [HabitRanking] {
        var rankings: [HabitRanking] = []
        
        for habit in state.selectedHabits {
            guard let performance = state.performanceMetrics[habit] else { continue }
            
            let score = getScoreForMetric(performance, metric: state.selectedMetric)
            rankings.append(HabitRanking(habit: habit, score: score, performance: performance))
        }
        
        return rankings.sorted { $0.score > $1.score }
    }
    
    /// Получает сильные корреляции между привычками
    var significantCorrelations: [HabitCorrelation] {
        return state.habitCorrelationMatrix?.correlations.filter { abs($0.score) > 0.3 } ?? []
    }
    
    /// Получает цвет для тренда
    func colorForTrend(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving:
            return .green
        case .declining:
            return .red
        case .stable:
            return .orange
        }
    }
    
    /// Получает информацию о выбранной точке данных
    var selectedPointInfo: String? {
        guard let point = state.selectedDataPoint else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let valueFormatter = NumberFormatter()
        valueFormatter.numberStyle = .decimal
        valueFormatter.maximumFractionDigits = 1
        
        guard let formattedValue = valueFormatter.string(from: NSNumber(value: point.value)) else {
            return nil
        }
        
        return "\(formatter.string(from: point.date)): \(formattedValue)\(state.selectedMetric.unit)"
    }
    
    private func getScoreForMetric(_ performance: PerformanceMetrics, metric: TrendMetric) -> Double {
        switch metric {
        case .completionRate, .consistency:
            return performance.efficiency
        case .rawValue:
            return performance.performance
        case .streak:
            return performance.consistency
        }
    }
}

// MARK: - Supporting Types

enum TrendMetric: CaseIterable, Hashable {
    case completionRate
    case rawValue
    case streak
    case consistency
    
    var title: String {
        switch self {
        case .completionRate:
            return "Процент выполнения"
        case .rawValue:
            return "Абсолютные значения"
        case .streak:
            return "Серии"
        case .consistency:
            return "Постоянство"
        }
    }
    
    var unit: String {
        switch self {
        case .completionRate, .consistency:
            return "%"
        case .rawValue:
            return ""
        case .streak:
            return " дней"
        }
    }
    
    var icon: String {
        switch self {
        case .completionRate:
            return "percent"
        case .rawValue:
            return "number"
        case .streak:
            return "flame"
        case .consistency:
            return "arrow.clockwise"
        }
    }
}

enum ComparisonMode: CaseIterable, Hashable {
    case individual
    case combined
    case average
    
    var title: String {
        switch self {
        case .individual:
            return "Раздельно"
        case .combined:
            return "Совместно"
        case .average:
            return "Среднее"
        }
    }
    
    var icon: String {
        switch self {
        case .individual:
            return "chart.line.uptrend.xyaxis"
        case .combined:
            return "chart.bar.fill"
        case .average:
            return "chart.bar.xaxis"
        }
    }
}

enum ChartType: CaseIterable, Hashable {
    case line
    case bar
    case area
    
    var title: String {
        switch self {
        case .line:
            return "Линейный"
        case .bar:
            return "Столбчатый"
        case .area:
            return "Областной"
        }
    }
    
    var icon: String {
        switch self {
        case .line:
            return "chart.xyaxis.line"
        case .bar:
            return "chart.bar"
        case .area:
            return "chart.bar.fill"
        }
    }
}

struct TrendChartData: Identifiable {
    let id: String
    let name: String
    let color: Color
    let dataPoints: [TrendDataPoint]
    let trend: TrendDirection
    let confidence: Double
}

struct TrendsSummary {
    let totalHabits: Int
    let improvingHabits: Int
    let decliningHabits: Int
    let stableHabits: Int
    let averageSuccessRate: Double
    let averageStreak: Double
    
    var improvingPercentage: Double {
        return totalHabits > 0 ? Double(improvingHabits) / Double(totalHabits) : 0.0
    }
    
    var decliningPercentage: Double {
        return totalHabits > 0 ? Double(decliningHabits) / Double(totalHabits) : 0.0
    }
    
    var stablePercentage: Double {
        return totalHabits > 0 ? Double(stableHabits) / Double(totalHabits) : 0.0
    }
}

struct HabitRanking {
    let habit: Habit
    let score: Double
    let performance: PerformanceMetrics
    
    var formattedScore: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: score)) ?? "0%"
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 