import Foundation
import SwiftUI

// MARK: - HabitAnalyticsViewModel

@Observable
final class HabitAnalyticsViewModel {
    
    // MARK: - State
    
    struct State {
        var selectedHabit: Habit?
        var selectedPeriod: AnalyticsPeriod = .month
        var selectedYear: Int = Calendar.current.component(.year, from: Date())
        var isLoading: Bool = false
        var error: AppError?
        
        // Analytics Data
        var trends: HabitTrends?
        var heatmapData: HabitHeatmapData?
        var weeklyPatterns: WeeklyPatterns?
        var successRateAnalysis: SuccessRateAnalysis?
        var streakAnalytics: StreakAnalytics?
        var performanceMetrics: PerformanceMetrics?
        var timingRecommendations: [TimingRecommendation] = []
        var predictiveInsights: [PredictiveInsight] = []
        
        // View State
        var selectedTab: AnalyticsTab = .overview
        var showingYearPicker: Bool = false
        var showingPeriodPicker: Bool = false
    }
    
    // MARK: - Input
    
    enum Input {
        case habitSelected(Habit)
        case periodChanged(AnalyticsPeriod)
        case yearChanged(Int)
        case tabChanged(AnalyticsTab)
        case loadAnalytics
        case refreshAnalytics
        case dismissError
        case showYearPicker
        case showPeriodPicker
        case hideYearPicker
        case hidePeriodPicker
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
            case .habitSelected(let habit):
                state.selectedHabit = habit
                await loadAnalytics()
            case .periodChanged(let period):
                state.selectedPeriod = period
                await loadTrendsAndPerformance()
            case .yearChanged(let year):
                state.selectedYear = year
                state.showingYearPicker = false
                await loadHeatmapData()
            case .tabChanged(let tab):
                state.selectedTab = tab
            case .loadAnalytics:
                await loadAnalytics()
            case .refreshAnalytics:
                await refreshAnalytics()
            case .dismissError:
                state.error = nil
            case .showYearPicker:
                state.showingYearPicker = true
            case .showPeriodPicker:
                state.showingPeriodPicker = true
            case .hideYearPicker:
                state.showingYearPicker = false
            case .hidePeriodPicker:
                state.showingPeriodPicker = false
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadAnalytics() async {
        guard let habit = state.selectedHabit else { return }
        
        state.isLoading = true
        state.error = nil
        
        do {
            async let trends = analyticsService.getHabitTrends(habit, period: state.selectedPeriod)
            async let heatmapData = analyticsService.getHabitHeatmapData(habit, year: state.selectedYear)
            async let weeklyPatterns = analyticsService.getWeeklyPatterns(habit)
            async let successRateAnalysis = analyticsService.getSuccessRateAnalysis(habit)
            async let streakAnalytics = analyticsService.getStreakAnalytics(habit)
            async let performanceMetrics = analyticsService.getPerformanceMetrics(habit, period: state.selectedPeriod)
            async let timingRecommendations = analyticsService.getOptimalTimingRecommendations(habit)
            async let predictiveInsights = analyticsService.getPredictiveInsights(habit)
            
            state.trends = try await trends
            state.heatmapData = try await heatmapData
            state.weeklyPatterns = try await weeklyPatterns
            state.successRateAnalysis = try await successRateAnalysis
            state.streakAnalytics = try await streakAnalytics
            state.performanceMetrics = try await performanceMetrics
            state.timingRecommendations = try await timingRecommendations
            state.predictiveInsights = try await predictiveInsights
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading habit analytics"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshAnalytics() async {
        await loadAnalytics()
    }
    
    @MainActor
    private func loadTrendsAndPerformance() async {
        guard let habit = state.selectedHabit else { return }
        
        do {
            async let trends = analyticsService.getHabitTrends(habit, period: state.selectedPeriod)
            async let performanceMetrics = analyticsService.getPerformanceMetrics(habit, period: state.selectedPeriod)
            
            state.trends = try await trends
            state.performanceMetrics = try await performanceMetrics
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading trends"))
        }
    }
    
    @MainActor
    private func loadHeatmapData() async {
        guard let habit = state.selectedHabit else { return }
        
        do {
            state.heatmapData = try await analyticsService.getHabitHeatmapData(habit, year: state.selectedYear)
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading heatmap data"))
        }
    }
}

// MARK: - Extensions

extension HabitAnalyticsViewModel {
    
    /// Проверяет, есть ли данные для отображения
    var hasData: Bool {
        state.selectedHabit != nil && (
            state.trends != nil ||
            state.heatmapData != nil ||
            state.weeklyPatterns != nil
        )
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        !state.isLoading && !hasData
    }
    
    /// Получает доступные годы для выбора
    var availableYears: [Int] {
        guard let habit = state.selectedHabit else { return [] }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let creationYear = Calendar.current.component(.year, from: habit.createdAt)
        
        return Array(creationYear...currentYear).reversed()
    }
    
    /// Получает краткую статистику для заголовка
    var headerStats: AnalyticsHeaderStats? {
        guard let habit = state.selectedHabit else { return nil }
        
        return AnalyticsHeaderStats(
            habitName: habit.name,
            currentStreak: habit.currentStreak,
            completionRate: habit.completionRate,
            totalPoints: habit.points,
            lastActivity: habit.entries.max(by: { $0.date < $1.date })?.date
        )
    }
    
    /// Получает цветовую схему на основе тренда
    var trendColor: Color {
        guard let trends = state.trends else { return .gray }
        
        switch trends.direction {
        case .improving:
            return .green
        case .declining:
            return .red
        case .stable:
            return .orange
        }
    }
    
    /// Получает иконку тренда
    var trendIcon: String {
        guard let trends = state.trends else { return "minus" }
        return trends.direction.icon
    }
    
    /// Получает лучший день недели
    var bestDayOfWeek: String? {
        guard let patterns = state.weeklyPatterns,
              let bestDay = patterns.bestDay else { return nil }
        
        return getDayName(for: bestDay.weekday)
    }
    
    /// Получает худший день недели
    var worstDayOfWeek: String? {
        guard let patterns = state.weeklyPatterns,
              let worstDay = patterns.worstDay else { return nil }
        
        return getDayName(for: worstDay.weekday)
    }
    
    /// Получает процент выполнения для heatmap
    var heatmapCompletionRate: Double {
        return state.heatmapData?.completionRate ?? 0.0
    }
    
    /// Получает общее количество дней в heatmap
    var heatmapTotalDays: Int {
        return state.heatmapData?.totalDays ?? 0
    }
    
    /// Получает количество выполненных дней в heatmap
    var heatmapCompletedDays: Int {
        return state.heatmapData?.completedDays ?? 0
    }
    
    private func getDayName(for weekday: Int) -> String {
        let days = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
        return days[safe: weekday - 1] ?? "Неизвестный день"
    }
}

// MARK: - Supporting Types

enum AnalyticsTab: CaseIterable, Hashable {
    case overview
    case trends
    case heatmap
    case patterns
    case insights
    case performance
    
    var title: String {
        switch self {
        case .overview:
            return "Обзор"
        case .trends:
            return "Тренды"
        case .heatmap:
            return "Календарь"
        case .patterns:
            return "Паттерны"
        case .insights:
            return "Инсайты"
        case .performance:
            return "Показатели"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "chart.bar"
        case .trends:
            return "chart.line.uptrend.xyaxis"
        case .heatmap:
            return "calendar"
        case .patterns:
            return "waveform.path.ecg"
        case .insights:
            return "lightbulb"
        case .performance:
            return "speedometer"
        }
    }
}

struct AnalyticsHeaderStats {
    let habitName: String
    let currentStreak: Int
    let completionRate: Double
    let totalPoints: Int
    let lastActivity: Date?
    
    var formattedCompletionRate: String {
        return "\(Int(completionRate * 100))%"
    }
    
    var formattedLastActivity: String {
        guard let lastActivity = lastActivity else { return "Нет данных" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastActivity, relativeTo: Date())
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 