import Foundation
import SwiftUI

// MARK: - InsightsViewModel

@Observable
final class InsightsViewModel {
    
    // MARK: - State
    
    struct State {
        var selectedHabit: Habit?
        var isLoading: Bool = false
        var isGeneratingRecommendations: Bool = false
        var error: AppError?
        
        // Insights Data
        var predictiveInsights: [PredictiveInsight] = []
        var timingRecommendations: [TimingRecommendation] = []
        var healthInsights: [HealthInsight] = []
        var habitSuggestions: [HabitSuggestion] = []
        var smartNotifications: [SmartNotification] = []
        
        // Personalization
        var userPreferences: InsightPreferences = InsightPreferences()
        var insightHistory: [InsightHistory] = []
        var dismissedInsights: Set<String> = []
        
        // View State
        var selectedTab: InsightTab = .predictions
        var selectedInsightType: InsightType = .all
        var showingPreferences: Bool = false
        var expandedInsightID: String?
    }
    
    // MARK: - Input
    
    enum Input {
        case habitSelected(Habit?)
        case loadInsights
        case refreshInsights
        case generateSmartRecommendations
        case insightDismissed(String)
        case insightAccepted(String)
        case tabChanged(InsightTab)
        case insightTypeChanged(InsightType)
        case showPreferences
        case hidePreferences
        case preferencesUpdated(InsightPreferences)
        case expandInsight(String?)
        case scheduleSmartNotification(SmartNotification)
        case dismissError
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let analyticsService: HabitAnalyticsServiceProtocol
    private let healthKitService: AdvancedHealthKitServiceProtocol?
    private let notificationService: NotificationServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    init(
        analyticsService: HabitAnalyticsServiceProtocol,
        healthKitService: AdvancedHealthKitServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol
    ) {
        self.analyticsService = analyticsService
        self.healthKitService = healthKitService
        self.notificationService = notificationService
        self.errorHandlingService = errorHandlingService
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .habitSelected(let habit):
                state.selectedHabit = habit
                await loadInsights()
            case .loadInsights:
                await loadInsights()
            case .refreshInsights:
                await refreshInsights()
            case .generateSmartRecommendations:
                await generateSmartRecommendations()
            case .insightDismissed(let insightID):
                await dismissInsight(insightID)
            case .insightAccepted(let insightID):
                await acceptInsight(insightID)
            case .tabChanged(let tab):
                state.selectedTab = tab
            case .insightTypeChanged(let type):
                state.selectedInsightType = type
            case .showPreferences:
                state.showingPreferences = true
            case .hidePreferences:
                state.showingPreferences = false
            case .preferencesUpdated(let preferences):
                state.userPreferences = preferences
                state.showingPreferences = false
                await loadInsights()
            case .expandInsight(let insightID):
                state.expandedInsightID = insightID
            case .scheduleSmartNotification(let notification):
                await scheduleSmartNotification(notification)
            case .dismissError:
                state.error = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadInsights() async {
        state.isLoading = true
        state.error = nil
        
        do {
            if let habit = state.selectedHabit {
                // Загружаем инсайты для конкретной привычки
                await loadHabitSpecificInsights(habit)
            } else {
                // Загружаем общие инсайты
                await loadGeneralInsights()
            }
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading insights"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func loadHabitSpecificInsights(_ habit: Habit) async {
        async let predictiveInsights = analyticsService.getPredictiveInsights(habit)
        async let timingRecommendations = analyticsService.getOptimalTimingRecommendations(habit)
        
        do {
            state.predictiveInsights = try await predictiveInsights
            state.timingRecommendations = try await timingRecommendations
            
            // Загружаем health insights если доступен HealthKit
            if let healthService = healthKitService {
                state.healthInsights = try await healthService.getHealthInsights(for: habit)
            }
            
        } catch {
            throw error
        }
    }
    
    @MainActor
    private func loadGeneralInsights() async {
        // Загружаем общие рекомендации и предложения новых привычек
        state.habitSuggestions = generateHabitSuggestions()
        state.smartNotifications = generateSmartNotifications()
    }
    
    @MainActor
    private func refreshInsights() async {
        await loadInsights()
    }
    
    @MainActor
    private func generateSmartRecommendations() async {
        guard let habit = state.selectedHabit else { return }
        
        state.isGeneratingRecommendations = true
        
        do {
            // Анализируем паттерны пользователя
            let weeklyPatterns = try await analyticsService.getWeeklyPatterns(habit)
            let streakAnalytics = try await analyticsService.getStreakAnalytics(habit)
            let successRateAnalysis = try await analyticsService.getSuccessRateAnalysis(habit)
            
            // Генерируем персонализированные рекомендации
            let smartRecommendations = await generatePersonalizedRecommendations(
                habit: habit,
                weeklyPatterns: weeklyPatterns,
                streakAnalytics: streakAnalytics,
                successRateAnalysis: successRateAnalysis
            )
            
            state.timingRecommendations.append(contentsOf: smartRecommendations)
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .ai("Generating smart recommendations"))
        }
        
        state.isGeneratingRecommendations = false
    }
    
    @MainActor
    private func dismissInsight(_ insightID: String) async {
        state.dismissedInsights.insert(insightID)
        
        // Записываем в историю
        let historyEntry = InsightHistory(
            insightID: insightID,
            action: .dismissed,
            timestamp: Date()
        )
        state.insightHistory.append(historyEntry)
        
        // Удаляем из списков
        state.predictiveInsights.removeAll { "\($0.prediction.hashValue)" == insightID }
        state.timingRecommendations.removeAll { "\($0.suggestion.hashValue)" == insightID }
        state.healthInsights.removeAll { "\($0.title.hashValue)" == insightID }
        state.habitSuggestions.removeAll { "\($0.title.hashValue)" == insightID }
    }
    
    @MainActor
    private func acceptInsight(_ insightID: String) async {
        // Записываем в историю
        let historyEntry = InsightHistory(
            insightID: insightID,
            action: .accepted,
            timestamp: Date()
        )
        state.insightHistory.append(historyEntry)
        
        // Здесь можно добавить логику применения рекомендации
        // Например, автоматическое создание напоминания или изменение настроек привычки
    }
    
    @MainActor
    private func scheduleSmartNotification(_ notification: SmartNotification) async {
        do {
            // Планируем умное уведомление
            await notificationService.scheduleSmartNotification(
                id: notification.id,
                title: notification.title,
                body: notification.message,
                triggerTime: notification.scheduledTime,
                category: notification.category.rawValue
            )
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .notification("Scheduling smart notification"))
        }
    }
    
    // MARK: - Smart Recommendation Generation
    
    private func generatePersonalizedRecommendations(
        habit: Habit,
        weeklyPatterns: WeeklyPatterns,
        streakAnalytics: StreakAnalytics,
        successRateAnalysis: SuccessRateAnalysis
    ) async -> [TimingRecommendation] {
        
        var recommendations: [TimingRecommendation] = []
        
        // Анализ времени выполнения
        if let bestDay = weeklyPatterns.bestDay, let worstDay = weeklyPatterns.worstDay {
            let difference = bestDay.successRate - worstDay.successRate
            
            if difference > 0.3 {
                recommendations.append(TimingRecommendation(
                    type: .weekday,
                    suggestion: "Попробуйте переместить выполнение привычки на \(getDayName(bestDay.weekday)). В этот день у вас \(Int(bestDay.successRate * 100))% успешности против \(Int(worstDay.successRate * 100))% в \(getDayName(worstDay.weekday)).",
                    confidence: 0.85,
                    reason: "Анализ показывает значительную разницу в успешности по дням недели"
                ))
            }
        }
        
        // Анализ серий
        if streakAnalytics.averageStreak < 3 && streakAnalytics.currentStreak == 0 {
            recommendations.append(TimingRecommendation(
                type: .streak,
                suggestion: "Начните с малого: поставьте цель выполнить привычку всего 2 дня подряд. Это поможет восстановить мотивацию.",
                confidence: 0.9,
                reason: "Короткие цели помогают восстановить привычку после перерыва"
            ))
        }
        
        // Анализ последовательности
        if successRateAnalysis.consistency < 0.6 {
            recommendations.append(TimingRecommendation(
                type: .consistency,
                suggestion: "Установите конкретное время для выполнения привычки. Постоянство времени увеличивает вероятность выполнения на 40%.",
                confidence: 0.8,
                reason: "Низкая последовательность указывает на необходимость четкого расписания"
            ))
        }
        
        // Анализ трендов
        if successRateAnalysis.trend == .declining {
            recommendations.append(TimingRecommendation(
                type: .frequency,
                suggestion: "Рассмотрите временное снижение частоты или объема привычки. Лучше делать меньше, но регулярно.",
                confidence: 0.75,
                reason: "Снижающийся тренд может указывать на слишком амбициозные цели"
            ))
        }
        
        return recommendations
    }
    
    private func generateHabitSuggestions() -> [HabitSuggestion] {
        // Здесь должна быть логика анализа существующих привычек
        // и предложения новых на основе популярных комбинаций
        
        return [
            HabitSuggestion(
                title: "Утренняя медитация",
                description: "5 минут медитации после пробуждения",
                category: "Здоровье",
                difficulty: .easy,
                expectedBenefit: "Снижение стресса и улучшение концентрации",
                basedOn: "Пользователи с утренними привычками часто добавляют медитацию"
            ),
            HabitSuggestion(
                title: "Стакан воды перед едой",
                description: "Выпивать стакан воды за 30 минут до основных приемов пищи",
                category: "Здоровье",
                difficulty: .easy,
                expectedBenefit: "Улучшение пищеварения и контроль аппетита",
                basedOn: "Популярная привычка среди пользователей с похожими целями"
            )
        ]
    }
    
    private func generateSmartNotifications() -> [SmartNotification] {
        return [
            SmartNotification(
                id: UUID().uuidString,
                title: "Время для привычки!",
                message: "Сейчас оптимальное время для выполнения ваших привычек",
                category: .reminder,
                scheduledTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
                priority: .normal
            )
        ]
    }
    
    private func getDayName(_ weekday: Int) -> String {
        let days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        return days[safe: weekday - 1] ?? "неизвестный день"
    }
}

// MARK: - Extensions

extension InsightsViewModel {
    
    /// Получает отфильтрованные инсайты
    var filteredInsights: [AnyInsight] {
        var insights: [AnyInsight] = []
        
        // Преобразуем все типы инсайтов в общий тип
        state.predictiveInsights.forEach { insight in
            let id = "\(insight.prediction.hashValue)"
            if !state.dismissedInsights.contains(id) {
                insights.append(AnyInsight(
                    id: id,
                    type: .predictive,
                    title: insight.type.displayName,
                    message: insight.prediction,
                    confidence: insight.confidence,
                    timestamp: Date(),
                    priority: insight.confidence > 0.8 ? .high : .normal
                ))
            }
        }
        
        state.timingRecommendations.forEach { recommendation in
            let id = "\(recommendation.suggestion.hashValue)"
            if !state.dismissedInsights.contains(id) {
                insights.append(AnyInsight(
                    id: id,
                    type: .recommendation,
                    title: recommendation.type.displayName,
                    message: recommendation.suggestion,
                    confidence: recommendation.confidence,
                    timestamp: Date(),
                    priority: recommendation.confidence > 0.8 ? .high : .normal
                ))
            }
        }
        
        state.healthInsights.forEach { healthInsight in
            let id = "\(healthInsight.title.hashValue)"
            if !state.dismissedInsights.contains(id) {
                insights.append(AnyInsight(
                    id: id,
                    type: .health,
                    title: healthInsight.title,
                    message: healthInsight.message,
                    confidence: healthInsight.confidence,
                    timestamp: Date(),
                    priority: healthInsight.confidence > 0.7 ? .high : .normal
                ))
            }
        }
        
        state.habitSuggestions.forEach { suggestion in
            let id = "\(suggestion.title.hashValue)"
            if !state.dismissedInsights.contains(id) {
                insights.append(AnyInsight(
                    id: id,
                    type: .suggestion,
                    title: suggestion.title,
                    message: suggestion.description,
                    confidence: 0.7,
                    timestamp: Date(),
                    priority: .normal
                ))
            }
        }
        
        // Фильтруем по выбранному типу
        if state.selectedInsightType != .all {
            insights = insights.filter { $0.type == state.selectedInsightType }
        }
        
        // Сортируем по приоритету и уверенности
        return insights.sorted { first, second in
            if first.priority != second.priority {
                return first.priority.rawValue > second.priority.rawValue
            }
            return first.confidence > second.confidence
        }
    }
    
    /// Проверяет, есть ли инсайты для отображения
    var hasInsights: Bool {
        return !filteredInsights.isEmpty
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        return !state.isLoading && !hasInsights
    }
    
    /// Получает статистику инсайтов
    var insightsStats: InsightsStats {
        let totalInsights = filteredInsights.count
        let highPriorityInsights = filteredInsights.filter { $0.priority == .high }.count
        let averageConfidence = filteredInsights.isEmpty ? 0.0 : 
            filteredInsights.reduce(0.0) { $0 + $1.confidence } / Double(filteredInsights.count)
        
        return InsightsStats(
            totalInsights: totalInsights,
            highPriorityInsights: highPriorityInsights,
            averageConfidence: averageConfidence,
            acceptedInsights: state.insightHistory.filter { $0.action == .accepted }.count,
            dismissedInsights: state.dismissedInsights.count
        )
    }
    
    /// Получает рекомендуемые действия
    var recommendedActions: [RecommendedAction] {
        var actions: [RecommendedAction] = []
        
        // Анализируем высокоприоритетные инсайты
        let highPriorityInsights = filteredInsights.filter { $0.priority == .high }
        
        for insight in highPriorityInsights.prefix(3) {
            switch insight.type {
            case .predictive:
                actions.append(RecommendedAction(
                    title: "Проанализировать прогноз",
                    description: "Изучите детали прогноза и подготовьтесь к потенциальным изменениям",
                    priority: .high,
                    estimatedTime: "5 мин"
                ))
            case .recommendation:
                actions.append(RecommendedAction(
                    title: "Применить рекомендацию",
                    description: "Следуйте предложенной рекомендации для улучшения результатов",
                    priority: .medium,
                    estimatedTime: "2 мин"
                ))
            case .health:
                actions.append(RecommendedAction(
                    title: "Изучить связь со здоровьем",
                    description: "Рассмотрите влияние привычки на показатели здоровья",
                    priority: .medium,
                    estimatedTime: "3 мин"
                ))
            case .suggestion:
                actions.append(RecommendedAction(
                    title: "Рассмотреть новую привычку",
                    description: "Оцените возможность добавления предложенной привычки",
                    priority: .low,
                    estimatedTime: "10 мин"
                ))
            case .all:
                break
            }
        }
        
        return actions
    }
}

// MARK: - Supporting Types

enum InsightTab: CaseIterable, Hashable {
    case predictions
    case recommendations
    case health
    case suggestions
    
    var title: String {
        switch self {
        case .predictions:
            return "Прогнозы"
        case .recommendations:
            return "Рекомендации"
        case .health:
            return "Здоровье"
        case .suggestions:
            return "Предложения"
        }
    }
    
    var icon: String {
        switch self {
        case .predictions:
            return "crystal.ball"
        case .recommendations:
            return "lightbulb"
        case .health:
            return "heart"
        case .suggestions:
            return "plus.circle"
        }
    }
}

enum InsightType: CaseIterable, Hashable {
    case all
    case predictive
    case recommendation
    case health
    case suggestion
    
    var displayName: String {
        switch self {
        case .all:
            return "Все"
        case .predictive:
            return "Прогноз"
        case .recommendation:
            return "Рекомендация"
        case .health:
            return "Здоровье"
        case .suggestion:
            return "Предложение"
        }
    }
}

enum InsightPriority: Int, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .low:
            return "Низкий"
        case .normal:
            return "Обычный"
        case .high:
            return "Высокий"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .gray
        case .normal:
            return .blue
        case .high:
            return .red
        }
    }
}

struct InsightPreferences {
    var enablePredictiveInsights: Bool = true
    var enableHealthInsights: Bool = true
    var enableSmartNotifications: Bool = true
    var minimumConfidenceLevel: Double = 0.6
    var preferredNotificationTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var enableWeeklyReports: Bool = true
}

struct InsightHistory {
    let insightID: String
    let action: InsightAction
    let timestamp: Date
    
    enum InsightAction {
        case viewed
        case accepted
        case dismissed
        case applied
    }
}

struct AnyInsight: Identifiable {
    let id: String
    let type: InsightType
    let title: String
    let message: String
    let confidence: Double
    let timestamp: Date
    let priority: InsightPriority
    
    var formattedConfidence: String {
        return "\(Int(confidence * 100))%"
    }
}

struct HabitSuggestion {
    let title: String
    let description: String
    let category: String
    let difficulty: Difficulty
    let expectedBenefit: String
    let basedOn: String
    
    enum Difficulty {
        case easy
        case medium
        case hard
        
        var displayName: String {
            switch self {
            case .easy:
                return "Легко"
            case .medium:
                return "Средне"
            case .hard:
                return "Сложно"
            }
        }
        
        var color: Color {
            switch self {
            case .easy:
                return .green
            case .medium:
                return .orange
            case .hard:
                return .red
            }
        }
    }
}

struct SmartNotification {
    let id: String
    let title: String
    let message: String
    let category: NotificationCategory
    let scheduledTime: Date
    let priority: InsightPriority
    
    enum NotificationCategory: String, CaseIterable {
        case reminder = "reminder"
        case motivation = "motivation"
        case insight = "insight"
        case achievement = "achievement"
        
        var displayName: String {
            switch self {
            case .reminder:
                return "Напоминание"
            case .motivation:
                return "Мотивация"
            case .insight:
                return "Инсайт"
            case .achievement:
                return "Достижение"
            }
        }
    }
}

struct InsightsStats {
    let totalInsights: Int
    let highPriorityInsights: Int
    let averageConfidence: Double
    let acceptedInsights: Int
    let dismissedInsights: Int
    
    var formattedAverageConfidence: String {
        return "\(Int(averageConfidence * 100))%"
    }
    
    var acceptanceRate: Double {
        let totalActions = acceptedInsights + dismissedInsights
        return totalActions > 0 ? Double(acceptedInsights) / Double(totalActions) : 0.0
    }
}

struct RecommendedAction {
    let title: String
    let description: String
    let priority: InsightPriority
    let estimatedTime: String
}

// MARK: - Extensions

extension TimingRecommendation.RecommendationType {
    var displayName: String {
        switch self {
        case .weekday:
            return "День недели"
        case .timeOfDay:
            return "Время дня"
        case .consistency:
            return "Постоянство"
        case .streak:
            return "Серии"
        case .frequency:
            return "Частота"
        }
    }
}

extension PredictiveInsight.InsightType {
    var displayName: String {
        switch self {
        case .positive:
            return "Позитивный прогноз"
        case .warning:
            return "Предупреждение"
        case .streak:
            return "Прогноз серии"
        case .goal:
            return "Достижение цели"
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - NotificationService Extension

extension NotificationServiceProtocol {
    func scheduleSmartNotification(
        id: String,
        title: String,
        body: String,
        triggerTime: Date,
        category: String
    ) async {
        // Реализация умных уведомлений
        // Здесь должна быть логика планирования уведомления
    }
} 