import XCTest
import SwiftData
@testable import IWBB

// MARK: - HabitAnalyticsServiceTests

final class HabitAnalyticsServiceTests: XCTestCase {
    
    var analyticsService: HabitAnalyticsService!
    var mockModelContext: ModelContext!
    var testHabit: Habit!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Создаем in-memory ModelContext для тестов
        let schema = Schema([Habit.self, HabitEntry.self, User.self, Category.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        mockModelContext = ModelContext(container)
        
        analyticsService = HabitAnalyticsService(modelContext: mockModelContext)
        
        // Создаем тестовую привычку
        testHabit = Habit(
            name: "Тестовая привычка",
            frequency: .daily,
            targetValue: 1
        )
        mockModelContext.insert(testHabit)
    }
    
    override func tearDownWithError() throws {
        analyticsService = nil
        mockModelContext = nil
        testHabit = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Trends Analysis Tests
    
    func testGetHabitTrends_WithImprovingData_ReturnsImprovingTrend() async throws {
        // Given
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        // Создаем данные с улучшающимся трендом
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let value = min(3, 1 + i / 10) // Постепенное улучшение
            
            let entry = HabitEntry(habit: testHabit, date: date, value: value)
            testHabit.entries.append(entry)
        }
        
        try await analyticsService.initialize()
        
        // When
        let trends = try await analyticsService.getHabitTrends(testHabit, period: .month)
        
        // Then
        XCTAssertEqual(trends.direction, .improving)
        XCTAssertGreaterThan(trends.strength, 0.3)
        XCTAssertFalse(trends.dataPoints.isEmpty)
        XCTAssertGreaterThan(trends.confidenceLevel, 0.5)
    }
    
    func testGetHabitTrends_WithDecliningData_ReturnsDecliningTrend() async throws {
        // Given
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        // Создаем данные со снижающимся трендом
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let value = max(0, 3 - i / 10) // Постепенное ухудшение
            
            let entry = HabitEntry(habit: testHabit, date: date, value: value)
            testHabit.entries.append(entry)
        }
        
        try await analyticsService.initialize()
        
        // When
        let trends = try await analyticsService.getHabitTrends(testHabit, period: .month)
        
        // Then
        XCTAssertEqual(trends.direction, .declining)
        XCTAssertGreaterThan(trends.strength, 0.3)
    }
    
    func testGetHabitTrends_WithNoData_ReturnsStableTrend() async throws {
        // Given
        try await analyticsService.initialize()
        
        // When
        let trends = try await analyticsService.getHabitTrends(testHabit, period: .month)
        
        // Then
        XCTAssertEqual(trends.direction, .stable)
        XCTAssertEqual(trends.strength, 0.0)
        XCTAssertTrue(trends.dataPoints.isEmpty)
    }
    
    // MARK: - Weekly Patterns Tests
    
    func testGetWeeklyPatterns_ReturnsCorrectPatterns() async throws {
        // Given
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -84, to: Date())! // 12 недель назад
        
        // Создаем данные с различной успешностью по дням недели
        for i in 0..<84 {
            let date = calendar.date(byAdding: .day, value: i, to: startDate)!
            let weekday = calendar.component(.weekday, from: date)
            
            // Понедельник (2) - высокая успешность, пятница (6) - низкая
            let shouldComplete = weekday == 2 ? true : weekday == 6 ? (i % 3 == 0) : (i % 2 == 0)
            
            if shouldComplete {
                let entry = HabitEntry(habit: testHabit, date: date, value: 1)
                testHabit.entries.append(entry)
            }
        }
        
        try await analyticsService.initialize()
        
        // When
        let patterns = try await analyticsService.getWeeklyPatterns(testHabit)
        
        // Then
        XCTAssertEqual(patterns.patterns.count, 7)
        
        let mondayPattern = patterns.patterns.first { $0.weekday == 2 }
        let fridayPattern = patterns.patterns.first { $0.weekday == 6 }
        
        XCTAssertNotNil(mondayPattern)
        XCTAssertNotNil(fridayPattern)
        
        if let monday = mondayPattern, let friday = fridayPattern {
            XCTAssertGreaterThan(monday.successRate, friday.successRate)
        }
        
        XCTAssertEqual(patterns.bestDay?.weekday, 2) // Понедельник
    }
    
    // MARK: - Heatmap Data Tests
    
    func testGetHabitHeatmapData_ReturnsCorrectData() async throws {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        
        // Создаем данные для первых 30 дней года
        for day in 1...30 {
            if let date = calendar.date(from: DateComponents(year: currentYear, month: 1, day: day)) {
                let value = day % 3 == 0 ? 0 : 1 // Каждый третий день пропускаем
                if value > 0 {
                    let entry = HabitEntry(habit: testHabit, date: date, value: value)
                    testHabit.entries.append(entry)
                }
            }
        }
        
        try await analyticsService.initialize()
        
        // When
        let heatmapData = try await analyticsService.getHabitHeatmapData(testHabit, year: currentYear)
        
        // Then
        XCTAssertEqual(heatmapData.year, currentYear)
        XCTAssertEqual(heatmapData.completedDays, 20) // 30 дней - 10 пропущенных
        XCTAssertGreaterThan(heatmapData.totalDays, 360) // Проверяем, что есть данные на весь год
        XCTAssertGreaterThan(heatmapData.completionRate, 0.0)
    }
    
    // MARK: - Success Rate Analysis Tests
    
    func testGetSuccessRateAnalysis_ReturnsCorrectRates() async throws {
        // Given
        let calendar = Calendar.current
        
        // Создаем данные за последние 90 дней с различной успешностью
        for i in 0..<90 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            
            // Первые 7 дней - высокая успешность (6/7)
            // Следующие 23 дня - средняя успешность (15/23)
            // Остальные дни - низкая успешность
            let shouldComplete: Bool
            if i < 7 {
                shouldComplete = i != 0 // 6 из 7
            } else if i < 30 {
                shouldComplete = i % 3 != 0 // ~2/3
            } else {
                shouldComplete = i % 4 == 0 // ~1/4
            }
            
            if shouldComplete {
                let entry = HabitEntry(habit: testHabit, date: date, value: 1)
                testHabit.entries.append(entry)
            }
        }
        
        try await analyticsService.initialize()
        
        // When
        let analysis = try await analyticsService.getSuccessRateAnalysis(testHabit)
        
        // Then
        XCTAssertGreaterThan(analysis.last7Days, analysis.last30Days)
        XCTAssertGreaterThan(analysis.last30Days, analysis.last90Days)
        XCTAssertGreaterThan(analysis.consistency, 0.0)
        XCTAssertLessThanOrEqual(analysis.consistency, 1.0)
    }
    
    // MARK: - Streak Analytics Tests
    
    func testGetStreakAnalytics_CalculatesCorrectStreaks() async throws {
        // Given
        let calendar = Calendar.current
        
        // Создаем данные с несколькими streak'ами
        let streakDates = [
            // Streak 1: 5 дней
            -20, -19, -18, -17, -16,
            // Пропуск
            // Streak 2: 3 дня
            -10, -9, -8,
            // Пропуск
            // Текущий streak: 2 дня
            -1, 0
        ]
        
        for dayOffset in streakDates {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: Date())!
            let entry = HabitEntry(habit: testHabit, date: date, value: 1)
            testHabit.entries.append(entry)
        }
        
        try await analyticsService.initialize()
        
        // When
        let streakAnalytics = try await analyticsService.getStreakAnalytics(testHabit)
        
        // Then
        XCTAssertEqual(streakAnalytics.currentStreak, 2)
        XCTAssertEqual(streakAnalytics.longestStreak, 5)
        XCTAssertGreaterThan(streakAnalytics.averageStreak, 3.0)
        XCTAssertEqual(streakAnalytics.totalStreaks, 3)
    }
    
    // MARK: - Performance Metrics Tests
    
    func testGetPerformanceMetrics_CalculatesCorrectMetrics() async throws {
        // Given
        let calendar = Calendar.current
        let period = AnalyticsPeriod.month
        let dateRange = period.dateRange
        
        // Создаем данные в пределах периода
        let totalDays = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day!
        let trackedDays = Int(Double(totalDays) * 0.8) // 80% дней отслеживали
        let completedDays = Int(Double(trackedDays) * 0.7) // 70% из отслеженных выполнили
        
        for i in 0..<trackedDays {
            let date = calendar.date(byAdding: .day, value: i, to: dateRange.start)!
            let value = i < completedDays ? testHabit.targetValue : 0
            
            let entry = HabitEntry(habit: testHabit, date: date, value: value)
            testHabit.entries.append(entry)
        }
        
        try await analyticsService.initialize()
        
        // When
        let metrics = try await analyticsService.getPerformanceMetrics(testHabit, period: period)
        
        // Then
        XCTAssertEqual(metrics.period.displayName, period.displayName)
        XCTAssertEqual(metrics.efficiency, 0.7, accuracy: 0.1) // 70% эффективность
        XCTAssertEqual(metrics.engagement, 0.8, accuracy: 0.1) // 80% вовлеченность
        XCTAssertGreaterThan(metrics.performance, 0.0)
        XCTAssertLessThanOrEqual(metrics.performance, 1.0)
    }
    
    // MARK: - Correlation Matrix Tests
    
    func testGetHabitCorrelationMatrix_FindsCorrelations() async throws {
        // Given
        let habit2 = Habit(name: "Вторая привычка", frequency: .daily, targetValue: 1)
        mockModelContext.insert(habit2)
        
        let calendar = Calendar.current
        
        // Создаем коррелированные данные (выполняются в одни дни)
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let shouldComplete = i % 2 == 0 // Каждый второй день
            
            if shouldComplete {
                let entry1 = HabitEntry(habit: testHabit, date: date, value: 1)
                let entry2 = HabitEntry(habit: habit2, date: date, value: 1)
                
                testHabit.entries.append(entry1)
                habit2.entries.append(entry2)
            }
        }
        
        try await analyticsService.initialize()
        
        // When
        let matrix = try await analyticsService.getHabitCorrelationMatrix([testHabit, habit2])
        
        // Then
        XCTAssertEqual(matrix.habits.count, 2)
        XCTAssertGreaterThan(matrix.correlations.count, 0)
        
        if let correlation = matrix.correlations.first {
            XCTAssertGreaterThan(correlation.score, 0.5) // Сильная положительная корреляция
            XCTAssertGreaterThan(correlation.confidence, 0.5)
            XCTAssertGreaterThanOrEqual(correlation.dataPoints, 14)
        }
    }
    
    // MARK: - Predictive Insights Tests
    
    func testGetPredictiveInsights_GeneratesInsights() async throws {
        // Given
        let calendar = Calendar.current
        
        // Создаем данные с положительным трендом
        for i in 0..<21 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let value = min(3, 1 + i / 7) // Постепенное улучшение
            
            let entry = HabitEntry(habit: testHabit, date: date, value: value)
            testHabit.entries.append(entry)
        }
        
        try await analyticsService.initialize()
        
        // When
        let insights = try await analyticsService.getPredictiveInsights(testHabit)
        
        // Then
        XCTAssertGreaterThan(insights.count, 0)
        
        let positiveInsights = insights.filter { $0.type == .positive }
        XCTAssertGreaterThan(positiveInsights.count, 0)
        
        if let insight = positiveInsights.first {
            XCTAssertGreaterThan(insight.confidence, 0.6)
            XCTAssertFalse(insight.prediction.isEmpty)
        }
    }
    
    // MARK: - Optimal Timing Recommendations Tests
    
    func testGetOptimalTimingRecommendations_GeneratesRecommendations() async throws {
        // Given
        try await analyticsService.initialize()
        
        // When
        let recommendations = try await analyticsService.getOptimalTimingRecommendations(testHabit)
        
        // Then
        XCTAssertGreaterThan(recommendations.count, 0)
        
        for recommendation in recommendations {
            XCTAssertFalse(recommendation.suggestion.isEmpty)
            XCTAssertGreaterThan(recommendation.confidence, 0.0)
            XCTAssertLessThanOrEqual(recommendation.confidence, 1.0)
            XCTAssertFalse(recommendation.reason.isEmpty)
        }
    }
}

// MARK: - AdvancedHealthKitServiceTests

final class AdvancedHealthKitServiceTests: XCTestCase {
    
    var healthKitService: MockAdvancedHealthKitService!
    var mockModelContext: ModelContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let schema = Schema([HealthData.self, Habit.self, HabitHealthCorrelation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        mockModelContext = ModelContext(container)
        
        healthKitService = MockAdvancedHealthKitService()
    }
    
    override func tearDownWithError() throws {
        healthKitService = nil
        mockModelContext = nil
        try super.tearDownWithError()
    }
    
    func testIsHealthDataAvailable_ReturnsFalseForMock() {
        // When
        let isAvailable = healthKitService.isHealthDataAvailable()
        
        // Then
        XCTAssertFalse(isAvailable)
    }
    
    func testFetchStepsData_ReturnsEmptyArray() async throws {
        // Given
        let dateRange = DateInterval(start: Date(), end: Date())
        
        // When
        let stepsData = try await healthKitService.fetchStepsData(for: dateRange)
        
        // Then
        XCTAssertTrue(stepsData.isEmpty)
    }
    
    func testCalculateHabitHealthCorrelations_ReturnsEmptyArray() async throws {
        // Given
        let habit = Habit(name: "Test", frequency: .daily, targetValue: 1)
        
        // When
        let correlations = try await healthKitService.calculateHabitHealthCorrelations(habit)
        
        // Then
        XCTAssertTrue(correlations.isEmpty)
    }
}

// MARK: - SmartFeaturesServiceTests

final class SmartFeaturesServiceTests: XCTestCase {
    
    var smartFeaturesService: SmartFeaturesService!
    var mockAnalyticsService: MockHabitAnalyticsService!
    var mockNotificationService: MockNotificationService!
    var testHabit: Habit!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockAnalyticsService = MockHabitAnalyticsService()
        mockNotificationService = MockNotificationService()
        
        smartFeaturesService = SmartFeaturesService(
            analyticsService: mockAnalyticsService,
            healthKitService: nil,
            notificationService: mockNotificationService
        )
        
        testHabit = Habit(name: "Тестовая привычка", frequency: .daily, targetValue: 1)
    }
    
    override func tearDownWithError() throws {
        smartFeaturesService = nil
        mockAnalyticsService = nil
        mockNotificationService = nil
        testHabit = nil
        try super.tearDownWithError()
    }
    
    func testGenerateIntelligentReminders_ReturnsReminders() async throws {
        // Given
        try await smartFeaturesService.initialize()
        
        // When
        let reminders = try await smartFeaturesService.generateIntelligentReminders(for: testHabit)
        
        // Then
        XCTAssertGreaterThan(reminders.count, 0)
        
        for reminder in reminders {
            XCTAssertFalse(reminder.title.isEmpty)
            XCTAssertFalse(reminder.message.isEmpty)
            XCTAssertNotNil(reminder.scheduledTime)
        }
    }
    
    func testSuggestOptimalTiming_ReturnsSuggestions() async throws {
        // Given
        try await smartFeaturesService.initialize()
        
        // When
        let suggestions = try await smartFeaturesService.suggestOptimalTiming(for: testHabit)
        
        // Then
        XCTAssertGreaterThan(suggestions.count, 0)
        
        for suggestion in suggestions {
            XCTAssertFalse(suggestion.suggestion.isEmpty)
            XCTAssertGreaterThan(suggestion.confidence, 0.0)
            XCTAssertLessThanOrEqual(suggestion.confidence, 1.0)
            XCTAssertGreaterThanOrEqual(suggestion.estimatedImprovement, 0.0)
        }
    }
    
    func testGenerateHabitSuggestions_ReturnsSuggestions() async throws {
        // Given
        try await smartFeaturesService.initialize()
        
        // When
        let suggestions = try await smartFeaturesService.generateHabitSuggestions(based: [testHabit])
        
        // Then
        XCTAssertGreaterThan(suggestions.count, 0)
        
        for suggestion in suggestions {
            XCTAssertFalse(suggestion.title.isEmpty)
            XCTAssertFalse(suggestion.description.isEmpty)
            XCTAssertFalse(suggestion.category.isEmpty)
            XCTAssertGreaterThan(suggestion.confidence, 0.0)
        }
    }
    
    func testPredictHabitSuccess_ReturnsValidPrediction() async throws {
        // Given
        let targetDate = Date()
        try await smartFeaturesService.initialize()
        
        // When
        let prediction = try await smartFeaturesService.predictHabitSuccess(for: testHabit, date: targetDate)
        
        // Then
        XCTAssertEqual(prediction.habitId, testHabit.id)
        XCTAssertEqual(prediction.date, targetDate)
        XCTAssertGreaterThanOrEqual(prediction.successProbability, 0.0)
        XCTAssertLessThanOrEqual(prediction.successProbability, 1.0)
        XCTAssertGreaterThan(prediction.factors.count, 0)
        XCTAssertGreaterThan(prediction.recommendations.count, 0)
    }
    
    func testAnalyzeUserPatterns_ReturnsValidAnalysis() async throws {
        // Given
        try await smartFeaturesService.initialize()
        
        // When
        let analysis = try await smartFeaturesService.analyzeUserPatterns([testHabit])
        
        // Then
        XCTAssertGreaterThanOrEqual(analysis.preferredTimeOfDay, 0)
        XCTAssertLessThan(analysis.preferredTimeOfDay, 24)
        XCTAssertGreaterThanOrEqual(analysis.overallCompletionRate, 0.0)
        XCTAssertLessThanOrEqual(analysis.overallCompletionRate, 1.0)
        XCTAssertGreaterThanOrEqual(analysis.consistencyScore, 0.0)
        XCTAssertLessThanOrEqual(analysis.consistencyScore, 1.0)
    }
    
    func testDetectRiskOfFailure_ReturnsValidAssessment() async throws {
        // Given
        try await smartFeaturesService.initialize()
        
        // When
        let assessment = try await smartFeaturesService.detectRiskOfFailure(for: testHabit)
        
        // Then
        XCTAssertEqual(assessment.habitId, testHabit.id)
        XCTAssertGreaterThanOrEqual(assessment.riskScore, 0.0)
        XCTAssertLessThanOrEqual(assessment.riskScore, 1.0)
        XCTAssertNotNil(assessment.riskLevel)
    }
}

// MARK: - Mock Services

class MockAdvancedHealthKitService: AdvancedHealthKitServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        isInitialized = false
    }
    
    func requestPermissions() async throws {}
    func isHealthDataAvailable() -> Bool { return false }
    func fetchStepsData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchSleepData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchActiveEnergyData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchExerciseTimeData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchMindfulnessData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchWeightData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchWaterIntakeData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func syncTodayData() async throws {}
    func calculateHabitHealthCorrelations(_ habit: Habit) async throws -> [HabitHealthCorrelation] { return [] }
    func getHealthInsights(for habit: Habit) async throws -> [HealthInsight] { return [] }
    func enableBackgroundDelivery(for types: [HealthDataType]) async throws {}
}

class MockHabitAnalyticsService: HabitAnalyticsServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        isInitialized = false
    }
    
    func getHabitTrends(_ habit: Habit, period: AnalyticsPeriod) async throws -> HabitTrends {
        return HabitTrends(
            direction: .stable,
            strength: 0.5,
            dataPoints: [],
            growthRate: 0.0,
            confidenceLevel: 0.7
        )
    }
    
    func getHabitHeatmapData(_ habit: Habit, year: Int?) async throws -> HabitHeatmapData {
        return HabitHeatmapData(
            year: year ?? Calendar.current.component(.year, from: Date()),
            data: [:],
            totalDays: 365,
            completedDays: 200,
            trackedDays: 300
        )
    }
    
    func getWeeklyPatterns(_ habit: Habit) async throws -> WeeklyPatterns {
        let patterns = (1...7).map { weekday in
            WeekdayPattern(
                weekday: weekday,
                successRate: 0.7,
                totalAttempts: 10,
                averageValue: 1.0
            )
        }
        
        return WeeklyPatterns(
            patterns: patterns,
            bestDay: patterns.first,
            worstDay: patterns.last
        )
    }
    
    func getSuccessRateAnalysis(_ habit: Habit) async throws -> SuccessRateAnalysis {
        return SuccessRateAnalysis(
            last7Days: 0.8,
            last30Days: 0.7,
            last90Days: 0.6,
            allTime: 0.65,
            trend: .stable,
            consistency: 0.75
        )
    }
    
    func getStreakAnalytics(_ habit: Habit) async throws -> StreakAnalytics {
        return StreakAnalytics(
            currentStreak: 5,
            longestStreak: 15,
            averageStreak: 7.5,
            totalStreaks: 8,
            streakDistribution: [5: 2, 10: 3, 15: 1],
            streakTrend: .stable
        )
    }
    
    func getOptimalTimingRecommendations(_ habit: Habit) async throws -> [TimingRecommendation] {
        return [
            TimingRecommendation(
                type: .timeOfDay,
                suggestion: "Выполняйте привычку утром",
                confidence: 0.8,
                reason: "Утром выше мотивация"
            )
        ]
    }
    
    func getHabitCorrelationMatrix(_ habits: [Habit]) async throws -> CorrelationMatrix {
        return CorrelationMatrix(habits: habits, correlations: [])
    }
    
    func getPredictiveInsights(_ habit: Habit) async throws -> [PredictiveInsight] {
        return [
            PredictiveInsight(
                type: .positive,
                prediction: "Высокая вероятность успеха",
                confidence: 0.8,
                timeframe: .day
            )
        ]
    }
    
    func getOverallAnalytics(_ habits: [Habit]) async throws -> OverallAnalytics {
        return OverallAnalytics(
            totalHabits: habits.count,
            averageSuccessRate: 0.7,
            totalStreaks: 25,
            averageStreak: 7.5,
            topPerformingHabits: Array(habits.prefix(3)),
            improvementAreas: []
        )
    }
    
    func getPerformanceMetrics(_ habit: Habit, period: AnalyticsPeriod) async throws -> PerformanceMetrics {
        return PerformanceMetrics(
            period: period,
            efficiency: 0.8,
            engagement: 0.7,
            performance: 0.75,
            consistency: 0.8,
            totalEntries: 20,
            averageValue: 1.2
        )
    }
}

class MockNotificationService: NotificationServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        isInitialized = false
    }
    
    func requestPermissions() async throws {}
    func scheduleHabitReminder(_ habitId: UUID, name: String, time: Date) async throws {}
    func cancelNotification(for identifier: String) async {}
    func cancelAllNotifications() async {}
    func getPendingNotifications() async -> [String] { return [] }
}

// MARK: - Performance Tests

final class HabitAnalyticsPerformanceTests: XCTestCase {
    
    var analyticsService: HabitAnalyticsService!
    var mockModelContext: ModelContext!
    var testHabits: [Habit] = []
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let schema = Schema([Habit.self, HabitEntry.self, User.self, Category.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        mockModelContext = ModelContext(container)
        
        analyticsService = HabitAnalyticsService(modelContext: mockModelContext)
        
        // Создаем множество тестовых привычек с данными
        createLargeDataset()
    }
    
    override func tearDownWithError() throws {
        analyticsService = nil
        mockModelContext = nil
        testHabits = []
        try super.tearDownWithError()
    }
    
    func testPerformanceWithLargeDataset() {
        measure {
            Task {
                do {
                    for habit in testHabits {
                        _ = try await analyticsService.getHabitTrends(habit, period: .month)
                    }
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
        }
    }
    
    func testCorrelationMatrixPerformance() {
        measure {
            Task {
                do {
                    _ = try await analyticsService.getHabitCorrelationMatrix(testHabits)
                } catch {
                    XCTFail("Correlation matrix performance test failed: \(error)")
                }
            }
        }
    }
    
    private func createLargeDataset() {
        let calendar = Calendar.current
        
        // Создаем 20 привычек
        for i in 0..<20 {
            let habit = Habit(
                name: "Привычка \(i)",
                frequency: .daily,
                targetValue: Int.random(in: 1...3)
            )
            
            // Создаем данные за год
            for day in 0..<365 {
                if Int.random(in: 0...100) < 70 { // 70% вероятность выполнения
                    let date = calendar.date(byAdding: .day, value: -day, to: Date())!
                    let value = Int.random(in: 1...habit.targetValue)
                    
                    let entry = HabitEntry(habit: habit, date: date, value: value)
                    habit.entries.append(entry)
                }
            }
            
            testHabits.append(habit)
            mockModelContext.insert(habit)
        }
    }
} 