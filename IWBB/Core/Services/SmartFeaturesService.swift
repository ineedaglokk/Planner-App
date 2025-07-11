import Foundation
import UserNotifications
import CoreML

// MARK: - SmartFeaturesService Protocol

protocol SmartFeaturesServiceProtocol: ServiceProtocol {
    func generateIntelligentReminders(for habit: Habit) async throws -> [IntelligentReminder]
    func suggestOptimalTiming(for habit: Habit) async throws -> [OptimalTimingSuggestion]
    func generateHabitSuggestions(based habits: [Habit]) async throws -> [HabitSuggestion]
    func predictHabitSuccess(for habit: Habit, date: Date) async throws -> SuccessPrediction
    func analyzeUserPatterns(_ habits: [Habit]) async throws -> UserPatternAnalysis
    func generatePersonalizedMotivation(for habit: Habit) async throws -> [MotivationalMessage]
    func detectRiskOfFailure(for habit: Habit) async throws -> FailureRiskAssessment
    func suggestHabitChaining(for habits: [Habit]) async throws -> [HabitChainSuggestion]
}

// MARK: - SmartFeaturesService Implementation

final class SmartFeaturesService: SmartFeaturesServiceProtocol {
    
    // MARK: - Properties
    
    private let analyticsService: HabitAnalyticsServiceProtocol
    private let healthKitService: AdvancedHealthKitServiceProtocol?
    private let notificationService: NotificationServiceProtocol
    
    var isInitialized: Bool = false
    
    // Machine Learning Models (будут загружены при инициализации)
    private var timingPredictionModel: MLModel?
    private var successPredictionModel: MLModel?
    
    // MARK: - Initialization
    
    init(
        analyticsService: HabitAnalyticsServiceProtocol,
        healthKitService: AdvancedHealthKitServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol
    ) {
        self.analyticsService = analyticsService
        self.healthKitService = healthKitService
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("Initializing SmartFeaturesService...")
        #endif
        
        // Загружаем ML модели (пока заглушки)
        await loadMLModels()
        
        isInitialized = true
        
        #if DEBUG
        print("SmartFeaturesService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("Cleaning up SmartFeaturesService...")
        #endif
        
        timingPredictionModel = nil
        successPredictionModel = nil
        isInitialized = false
        
        #if DEBUG
        print("SmartFeaturesService cleaned up")
        #endif
    }
    
    // MARK: - Intelligent Reminders
    
    func generateIntelligentReminders(for habit: Habit) async throws -> [IntelligentReminder] {
        let patterns = try await analyticsService.getWeeklyPatterns(habit)
        let streakAnalytics = try await analyticsService.getStreakAnalytics(habit)
        let userPatterns = try await analyzeUserPatterns([habit])
        
        var reminders: [IntelligentReminder] = []
        
        // Адаптивные напоминания на основе успешности
        if let bestDay = patterns.bestDay {
            let bestDayReminder = IntelligentReminder(
                id: UUID(),
                type: .adaptive,
                title: "Идеальное время для \(habit.name)",
                message: "Сегодня \(getDayName(bestDay.weekday)) - ваш самый успешный день для этой привычки!",
                scheduledTime: getOptimalTimeForDay(bestDay.weekday, based: userPatterns),
                priority: .high,
                adaptiveFactors: [
                    .weekdaySuccess(bestDay.successRate),
                    .historicalData(bestDay.totalAttempts)
                ]
            )
            reminders.append(bestDayReminder)
        }
        
        // Напоминания для восстановления streak
        if streakAnalytics.currentStreak == 0 && streakAnalytics.longestStreak > 3 {
            let streakRecoveryReminder = IntelligentReminder(
                id: UUID(),
                type: .streakRecovery,
                title: "Время восстановить серию!",
                message: "Ваш рекорд - \(streakAnalytics.longestStreak) дней. Начните новую серию прямо сейчас!",
                scheduledTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
                priority: .high,
                adaptiveFactors: [
                    .streakHistory(streakAnalytics.longestStreak),
                    .motivationalBoost(true)
                ]
            )
            reminders.append(streakRecoveryReminder)
        }
        
        // Напоминания на основе контекста времени
        let contextualReminders = await generateContextualReminders(for: habit, userPatterns: userPatterns)
        reminders.append(contentsOf: contextualReminders)
        
        return reminders
    }
    
    // MARK: - Optimal Timing Suggestions
    
    func suggestOptimalTiming(for habit: Habit) async throws -> [OptimalTimingSuggestion] {
        let patterns = try await analyticsService.getWeeklyPatterns(habit)
        let userAnalysis = try await analyzeUserPatterns([habit])
        
        var suggestions: [OptimalTimingSuggestion] = []
        
        // Анализ лучшего времени дня
        let optimalTimeOfDay = await predictOptimalTimeOfDay(for: habit, userPatterns: userAnalysis)
        suggestions.append(optimalTimeOfDay)
        
        // Анализ лучшего дня недели
        if let bestDay = patterns.bestDay, let worstDay = patterns.worstDay {
            let weekdaySuggestion = OptimalTimingSuggestion(
                type: .weekday,
                suggestion: "Переместите выполнение на \(getDayName(bestDay.weekday))",
                confidence: abs(bestDay.successRate - worstDay.successRate),
                reasoning: "В \(getDayName(bestDay.weekday)) у вас \(Int(bestDay.successRate * 100))% успешности против \(Int(worstDay.successRate * 100))% в \(getDayName(worstDay.weekday))",
                estimatedImprovement: (bestDay.successRate - worstDay.successRate) * 100,
                implementationSteps: [
                    "Измените напоминания на \(getDayName(bestDay.weekday))",
                    "Подготовьте всё необходимое заранее",
                    "Отслеживайте результаты в течение 2 недель"
                ]
            )
            suggestions.append(weekdaySuggestion)
        }
        
        // Анализ частоты выполнения
        let frequencySuggestion = await analyzeOptimalFrequency(for: habit)
        suggestions.append(frequencySuggestion)
        
        return suggestions
    }
    
    // MARK: - Habit Suggestions
    
    func generateHabitSuggestions(based habits: [Habit]) async throws -> [HabitSuggestion] {
        let userPatterns = try await analyzeUserPatterns(habits)
        var suggestions: [HabitSuggestion] = []
        
        // Анализ пробелов в существующих привычках
        let gapAnalysis = analyzeHabitGaps(habits)
        suggestions.append(contentsOf: gapAnalysis)
        
        // Предложения на основе успешных привычек
        let successBasedSuggestions = generateSuccessBasedSuggestions(habits, userPatterns: userPatterns)
        suggestions.append(contentsOf: successBasedSuggestions)
        
        // Сезонные предложения
        let seasonalSuggestions = generateSeasonalSuggestions(based: userPatterns)
        suggestions.append(contentsOf: seasonalSuggestions)
        
        // Предложения на основе health данных
        if let healthService = healthKitService {
            let healthBasedSuggestions = await generateHealthBasedSuggestions(
                habits: habits,
                healthService: healthService
            )
            suggestions.append(contentsOf: healthBasedSuggestions)
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Success Prediction
    
    func predictHabitSuccess(for habit: Habit, date: Date) async throws -> SuccessPrediction {
        let patterns = try await analyticsService.getWeeklyPatterns(habit)
        let trends = try await analyticsService.getHabitTrends(habit, period: .month)
        let streakAnalytics = try await analyticsService.getStreakAnalytics(habit)
        
        // Факторы предсказания
        var predictionFactors: [PredictionFactor] = []
        
        // Фактор дня недели
        let weekday = Calendar.current.component(.weekday, from: date)
        if let dayPattern = patterns.patterns.first(where: { $0.weekday == weekday }) {
            predictionFactors.append(.weekdaySuccess(dayPattern.successRate))
        }
        
        // Фактор тренда
        let trendFactor = trends.direction == .improving ? 0.8 : trends.direction == .declining ? 0.3 : 0.5
        predictionFactors.append(.overallTrend(trendFactor))
        
        // Фактор текущего streak
        let streakFactor = min(1.0, Double(streakAnalytics.currentStreak) / 10.0)
        predictionFactors.append(.currentStreak(streakFactor))
        
        // Фактор последней активности
        let daysSinceLastEntry = habit.entries.isEmpty ? 30 : 
            Calendar.current.dateComponents([.day], from: habit.entries.max(by: { $0.date < $1.date })!.date, to: date).day ?? 0
        let recencyFactor = max(0.0, 1.0 - Double(daysSinceLastEntry) / 7.0)
        predictionFactors.append(.recentActivity(recencyFactor))
        
        // Вычисляем общую вероятность
        let successProbability = calculateSuccessProbability(factors: predictionFactors)
        
        return SuccessPrediction(
            habitId: habit.id,
            date: date,
            successProbability: successProbability,
            confidence: trends.confidenceLevel,
            factors: predictionFactors,
            recommendations: generateRecommendationsForPrediction(
                probability: successProbability,
                factors: predictionFactors,
                habit: habit
            )
        )
    }
    
    // MARK: - User Pattern Analysis
    
    func analyzeUserPatterns(_ habits: [Habit]) async throws -> UserPatternAnalysis {
        var timeOfDayPreferences: [Int: Double] = [:]
        var weekdayPreferences: [Int: Double] = [:]
        var streakPatterns: [Int] = []
        var completionRates: [Double] = []
        
        for habit in habits {
            let patterns = try await analyticsService.getWeeklyPatterns(habit)
            let streakAnalytics = try await analyticsService.getStreakAnalytics(habit)
            
            // Анализ предпочтений по дням недели
            for pattern in patterns.patterns {
                weekdayPreferences[pattern.weekday, default: 0.0] += pattern.successRate
            }
            
            // Анализ паттернов streak
            streakPatterns.append(streakAnalytics.longestStreak)
            completionRates.append(habit.completionRate)
            
            // Анализ времени выполнения (если есть данные)
            if let reminderTime = habit.reminderTime {
                let hour = Calendar.current.component(.hour, from: reminderTime)
                timeOfDayPreferences[hour, default: 0.0] += habit.completionRate
            }
        }
        
        // Нормализуем данные
        let habitCount = Double(habits.count)
        for (key, value) in weekdayPreferences {
            weekdayPreferences[key] = value / habitCount
        }
        
        for (key, value) in timeOfDayPreferences {
            timeOfDayPreferences[key] = value / habitCount
        }
        
        return UserPatternAnalysis(
            preferredTimeOfDay: timeOfDayPreferences.max(by: { $0.value < $1.value })?.key ?? 9,
            preferredWeekdays: weekdayPreferences.sorted { $0.value > $1.value }.prefix(3).map { $0.key },
            averageStreakLength: streakPatterns.isEmpty ? 0.0 : Double(streakPatterns.reduce(0, +)) / Double(streakPatterns.count),
            overallCompletionRate: completionRates.isEmpty ? 0.0 : completionRates.reduce(0, +) / Double(completionRates.count),
            consistencyScore: calculateConsistencyScore(habits),
            motivationalFactors: identifyMotivationalFactors(habits)
        )
    }
    
    // MARK: - Personalized Motivation
    
    func generatePersonalizedMotivation(for habit: Habit) async throws -> [MotivationalMessage] {
        let streakAnalytics = try await analyticsService.getStreakAnalytics(habit)
        let trends = try await analyticsService.getHabitTrends(habit, period: .month)
        
        var messages: [MotivationalMessage] = []
        
        // Мотивация на основе streak
        if streakAnalytics.currentStreak > 0 {
            messages.append(MotivationalMessage(
                type: .streakMaintenance,
                title: "Отличная серия!",
                message: "Вы уже \(streakAnalytics.currentStreak) дней подряд выполняете \(habit.name). Продолжайте в том же духе!",
                icon: "flame.fill",
                priority: .medium,
                timing: .beforeHabitTime
            ))
        }
        
        // Мотивация при приближении к рекорду
        if streakAnalytics.currentStreak > 0 && streakAnalytics.currentStreak >= streakAnalytics.longestStreak - 2 {
            messages.append(MotivationalMessage(
                type: .recordBreaking,
                title: "Близко к рекорду!",
                message: "Ещё \(streakAnalytics.longestStreak - streakAnalytics.currentStreak + 1) дней до нового рекорда!",
                icon: "trophy.fill",
                priority: .high,
                timing: .beforeHabitTime
            ))
        }
        
        // Мотивация при положительном тренде
        if trends.direction == .improving {
            messages.append(MotivationalMessage(
                type: .progressCelebration,
                title: "Вы прогрессируете!",
                message: "Ваши результаты по \(habit.name) улучшаются. Так держать!",
                icon: "chart.line.uptrend.xyaxis",
                priority: .medium,
                timing: .afterHabitCompletion
            ))
        }
        
        // Мотивация при падении мотивации
        if streakAnalytics.currentStreak == 0 && streakAnalytics.longestStreak > 3 {
            messages.append(MotivationalMessage(
                type: .encouragement,
                title: "Не сдавайтесь!",
                message: "Вы уже доказали, что можете выполнять \(habit.name) \(streakAnalytics.longestStreak) дней подряд. Начните заново!",
                icon: "heart.fill",
                priority: .high,
                timing: .motivationalMoment
            ))
        }
        
        return messages
    }
    
    // MARK: - Failure Risk Detection
    
    func detectRiskOfFailure(for habit: Habit) async throws -> FailureRiskAssessment {
        let trends = try await analyticsService.getHabitTrends(habit, period: .month)
        let streakAnalytics = try await analyticsService.getStreakAnalytics(habit)
        let successRate = try await analyticsService.getSuccessRateAnalysis(habit)
        
        var riskFactors: [RiskFactor] = []
        var riskLevel: RiskLevel = .low
        
        // Анализ тренда
        if trends.direction == .declining {
            riskFactors.append(.decliningTrend(trends.strength))
            riskLevel = .medium
        }
        
        // Анализ streak
        if streakAnalytics.currentStreak == 0 {
            riskFactors.append(.brokenStreak(streakAnalytics.longestStreak))
            riskLevel = max(riskLevel, .medium)
        }
        
        // Анализ успешности
        if successRate.last7Days < 0.5 {
            riskFactors.append(.lowRecentSuccess(successRate.last7Days))
            riskLevel = max(riskLevel, .high)
        }
        
        // Анализ консистентности
        if successRate.consistency < 0.6 {
            riskFactors.append(.lowConsistency(successRate.consistency))
            riskLevel = max(riskLevel, .medium)
        }
        
        // Анализ времени с последнего выполнения
        if let lastEntry = habit.entries.max(by: { $0.date < $1.date }) {
            let daysSinceLastEntry = Calendar.current.dateComponents([.day], from: lastEntry.date, to: Date()).day ?? 0
            if daysSinceLastEntry > 3 {
                riskFactors.append(.inactivityPeriod(daysSinceLastEntry))
                riskLevel = max(riskLevel, .high)
            }
        }
        
        return FailureRiskAssessment(
            habitId: habit.id,
            riskLevel: riskLevel,
            riskScore: calculateRiskScore(factors: riskFactors),
            riskFactors: riskFactors,
            interventionSuggestions: generateInterventionSuggestions(for: riskFactors, habit: habit),
            timeframe: .week
        )
    }
    
    // MARK: - Habit Chaining Suggestions
    
    func suggestHabitChaining(for habits: [Habit]) async throws -> [HabitChainSuggestion] {
        let correlationMatrix = try await analyticsService.getHabitCorrelationMatrix(habits)
        var chainSuggestions: [HabitChainSuggestion] = []
        
        // Ищем сильные положительные корреляции
        let strongCorrelations = correlationMatrix.correlations.filter { 
            $0.score > 0.5 && $0.confidence > 0.7 
        }
        
        for correlation in strongCorrelations {
            let suggestion = HabitChainSuggestion(
                id: UUID(),
                primaryHabit: correlation.habit1,
                secondaryHabit: correlation.habit2,
                chainType: .sequential,
                strength: correlation.score,
                confidence: correlation.confidence,
                reasoning: "Эти привычки часто выполняются вместе. Создание цепочки может увеличить успешность на \(Int(correlation.score * 30))%",
                implementation: HabitChainImplementation(
                    triggerEvent: .habitCompletion(correlation.habit1.id),
                    action: .startHabit(correlation.habit2.id),
                    delay: .immediate,
                    conditions: []
                )
            )
            chainSuggestions.append(suggestion)
        }
        
        // Предлагаем цепочки на основе времени выполнения
        let timeBasedChains = generateTimeBasedChains(habits)
        chainSuggestions.append(contentsOf: timeBasedChains)
        
        return chainSuggestions.sorted { $0.strength > $1.strength }
    }
    
    // MARK: - Private Helper Methods
    
    private func loadMLModels() async {
        // Здесь будет загрузка предварительно обученных CoreML моделей
        // Пока используем заглушки
        
        #if DEBUG
        print("Loading ML models...")
        #endif
        
        // В реальном приложении здесь будет:
        // timingPredictionModel = try? MLModel(contentsOf: timingModelURL)
        // successPredictionModel = try? MLModel(contentsOf: successModelURL)
    }
    
    private func generateContextualReminders(
        for habit: Habit,
        userPatterns: UserPatternAnalysis
    ) async -> [IntelligentReminder] {
        var reminders: [IntelligentReminder] = []
        
        // Напоминания на основе погоды (для outdoor привычек)
        if habit.name.lowercased().contains("пробежка") || habit.name.lowercased().contains("прогулка") {
            let weatherReminder = IntelligentReminder(
                id: UUID(),
                type: .contextual,
                title: "Отличная погода для \(habit.name)!",
                message: "Сегодня идеальные условия для выполнения привычки",
                scheduledTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                priority: .medium,
                adaptiveFactors: [.weatherConditions(true)]
            )
            reminders.append(weatherReminder)
        }
        
        // Напоминания на основе локации
        let locationReminder = IntelligentReminder(
            id: UUID(),
            type: .locationBased,
            title: "Вы дома - время для \(habit.name)",
            message: "Идеальное время для выполнения домашних привычек",
            scheduledTime: Date(),
            priority: .medium,
            adaptiveFactors: [.locationContext("home")]
        )
        reminders.append(locationReminder)
        
        return reminders
    }
    
    private func predictOptimalTimeOfDay(
        for habit: Habit,
        userPatterns: UserPatternAnalysis
    ) async -> OptimalTimingSuggestion {
        // Анализируем время выполнения и успешность
        let optimalHour = userPatterns.preferredTimeOfDay
        
        return OptimalTimingSuggestion(
            type: .timeOfDay,
            suggestion: "Выполняйте \(habit.name) в \(optimalHour):00",
            confidence: 0.75,
            reasoning: "Анализ показывает, что в это время у вас самая высокая успешность",
            estimatedImprovement: 15.0,
            implementationSteps: [
                "Установите напоминание на \(optimalHour):00",
                "Подготовьте всё необходимое заранее",
                "Следите за результатами 2 недели"
            ]
        )
    }
    
    private func analyzeOptimalFrequency(for habit: Habit) async -> OptimalTimingSuggestion {
        let currentFrequency = habit.frequency
        let completionRate = habit.completionRate
        
        var suggestion = "Сохраните текущую частоту"
        var reasoning = "Текущая частота оптимальна"
        var improvement = 0.0
        
        if completionRate < 0.6 {
            switch currentFrequency {
            case .daily:
                suggestion = "Попробуйте выполнять через день"
                reasoning = "Снижение частоты может увеличить последовательность"
                improvement = 20.0
            case .weekly:
                suggestion = "Сохраните еженедельную частоту, но выберите конкретный день"
                reasoning = "Конкретный день недели увеличивает последовательность"
                improvement = 10.0
            case .custom:
                suggestion = "Упростите расписание до 3 дней в неделю"
                reasoning = "Простое расписание легче поддерживать"
                improvement = 15.0
            }
        }
        
        return OptimalTimingSuggestion(
            type: .frequency,
            suggestion: suggestion,
            confidence: 0.7,
            reasoning: reasoning,
            estimatedImprovement: improvement,
            implementationSteps: [
                "Измените частоту выполнения",
                "Отслеживайте результаты 3 недели",
                "При необходимости скорректируйте"
            ]
        )
    }
    
    private func analyzeHabitGaps(_ habits: [Habit]) -> [HabitSuggestion] {
        var suggestions: [HabitSuggestion] = []
        
        let categories = Set(habits.compactMap { $0.category?.name })
        let commonCategories = ["Здоровье", "Обучение", "Продуктивность", "Отношения", "Финансы"]
        
        for category in commonCategories {
            if !categories.contains(category) {
                let suggestion = createCategorySuggestion(for: category)
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
    
    private func generateSuccessBasedSuggestions(
        _ habits: [Habit],
        userPatterns: UserPatternAnalysis
    ) -> [HabitSuggestion] {
        var suggestions: [HabitSuggestion] = []
        
        // Находим самые успешные привычки
        let successfulHabits = habits.filter { $0.completionRate > 0.8 }
        
        for habit in successfulHabits {
            if habit.name.lowercased().contains("чтение") {
                suggestions.append(HabitSuggestion(
                    title: "Ведение дневника",
                    description: "Записывайте свои мысли после чтения",
                    category: "Развитие",
                    difficulty: .easy,
                    expectedBenefit: "Улучшение рефлексии и закрепление знаний",
                    basedOn: "Успешная привычка чтения",
                    confidence: 0.8
                ))
            }
        }
        
        return suggestions
    }
    
    private func generateSeasonalSuggestions(based userPatterns: UserPatternAnalysis) -> [HabitSuggestion] {
        let currentMonth = Calendar.current.component(.month, from: Date())
        var suggestions: [HabitSuggestion] = []
        
        switch currentMonth {
        case 1, 2, 12: // Зима
            suggestions.append(HabitSuggestion(
                title: "Домашняя тренировка",
                description: "15-минутные упражнения дома",
                category: "Здоровье",
                difficulty: .medium,
                expectedBenefit: "Поддержание формы в холодное время года",
                basedOn: "Зимний сезон",
                confidence: 0.7
            ))
        case 3, 4, 5: // Весна
            suggestions.append(HabitSuggestion(
                title: "Утренняя прогулка",
                description: "20-минутная прогулка на свежем воздухе",
                category: "Здоровье",
                difficulty: .easy,
                expectedBenefit: "Энергия и витамин D",
                basedOn: "Весенняя активность",
                confidence: 0.8
            ))
        case 6, 7, 8: // Лето
            suggestions.append(HabitSuggestion(
                title: "Плавание",
                description: "Плавание 2 раза в неделю",
                category: "Здоровье",
                difficulty: .medium,
                expectedBenefit: "Отличная кардио нагрузка",
                basedOn: "Летняя активность",
                confidence: 0.7
            ))
        case 9, 10, 11: // Осень
            suggestions.append(HabitSuggestion(
                title: "Изучение нового",
                description: "30 минут обучения новому навыку",
                category: "Развитие",
                difficulty: .medium,
                expectedBenefit: "Личностный рост и развитие",
                basedOn: "Осенняя мотивация к обучению",
                confidence: 0.75
            ))
        default:
            break
        }
        
        return suggestions
    }
    
    private func generateHealthBasedSuggestions(
        habits: [Habit],
        healthService: AdvancedHealthKitServiceProtocol
    ) async -> [HabitSuggestion] {
        var suggestions: [HabitSuggestion] = []
        
        // Анализируем health данные для предложений
        do {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let dateRange = DateInterval(start: yesterday, end: Date())
            
            let stepsData = try await healthService.fetchStepsData(for: dateRange)
            let sleepData = try await healthService.fetchSleepData(for: dateRange)
            
            // Предложения на основе данных о шагах
            if let steps = stepsData.first, steps.value < 8000 {
                suggestions.append(HabitSuggestion(
                    title: "Больше движения",
                    description: "Добавьте 10-минутную прогулку",
                    category: "Здоровье",
                    difficulty: .easy,
                    expectedBenefit: "Достижение дневной нормы шагов",
                    basedOn: "Данные о физической активности",
                    confidence: 0.85
                ))
            }
            
            // Предложения на основе данных о сне
            if let sleep = sleepData.first, sleep.value < 7 {
                suggestions.append(HabitSuggestion(
                    title: "Лучший сон",
                    description: "Ложитесь спать на 30 минут раньше",
                    category: "Здоровье",
                    difficulty: .medium,
                    expectedBenefit: "Улучшение качества сна и восстановления",
                    basedOn: "Данные о продолжительности сна",
                    confidence: 0.9
                ))
            }
        } catch {
            // Если не удалось получить данные, предлагаем общие здоровые привычки
        }
        
        return suggestions
    }
    
    private func calculateSuccessProbability(factors: [PredictionFactor]) -> Double {
        var totalWeight = 0.0
        var weightedSum = 0.0
        
        for factor in factors {
            let (value, weight) = factor.valueAndWeight
            totalWeight += weight
            weightedSum += value * weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0.5
    }
    
    private func generateRecommendationsForPrediction(
        probability: Double,
        factors: [PredictionFactor],
        habit: Habit
    ) -> [String] {
        var recommendations: [String] = []
        
        if probability < 0.3 {
            recommendations.append("Рассмотрите изменение времени выполнения")
            recommendations.append("Подготовьте всё необходимое заранее")
            recommendations.append("Найдите партнёра для поддержки")
        } else if probability < 0.7 {
            recommendations.append("Создайте дополнительное напоминание")
            recommendations.append("Уменьшите сложность задачи")
        } else {
            recommendations.append("Отличная вероятность успеха!")
            recommendations.append("Сосредоточьтесь на качестве выполнения")
        }
        
        return recommendations
    }
    
    private func calculateConsistencyScore(_ habits: [Habit]) -> Double {
        let consistencyScores = habits.map { habit in
            let entries = habit.entries.sorted { $0.date < $1.date }
            guard entries.count > 1 else { return 0.0 }
            
            let intervals = zip(entries.dropFirst(), entries).map { next, current in
                Calendar.current.dateComponents([.day], from: current.date, to: next.date).day ?? 0
            }
            
            let averageInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
            let variance = intervals.map { pow(Double($0) - averageInterval, 2) }.reduce(0, +) / Double(intervals.count)
            
            return max(0.0, 1.0 - variance / 10.0)
        }
        
        return consistencyScores.isEmpty ? 0.0 : consistencyScores.reduce(0, +) / Double(consistencyScores.count)
    }
    
    private func identifyMotivationalFactors(_ habits: [Habit]) -> [MotivationalFactor] {
        var factors: [MotivationalFactor] = []
        
        // Анализ streak паттернов
        let streaks = habits.map { $0.currentStreak }
        if streaks.max() ?? 0 > 7 {
            factors.append(.streakMotivation)
        }
        
        // Анализ прогресса
        let improvingHabits = habits.filter { habit in
            // Простой анализ: сравниваем последние 7 дней с предыдущими 7 днями
            let recent = habit.entries.filter { 
                $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() 
            }.count
            let previous = habit.entries.filter { 
                let startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
                let endDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                return $0.date >= startDate && $0.date < endDate
            }.count
            
            return recent > previous
        }
        
        if Double(improvingHabits.count) / Double(habits.count) > 0.5 {
            factors.append(.progressMotivation)
        }
        
        return factors
    }
    
    private func calculateRiskScore(factors: [RiskFactor]) -> Double {
        var riskScore = 0.0
        
        for factor in factors {
            switch factor {
            case .decliningTrend(let strength):
                riskScore += strength * 0.3
            case .brokenStreak(let longestStreak):
                riskScore += min(0.4, Double(longestStreak) / 30.0)
            case .lowRecentSuccess(let rate):
                riskScore += (1.0 - rate) * 0.4
            case .lowConsistency(let consistency):
                riskScore += (1.0 - consistency) * 0.2
            case .inactivityPeriod(let days):
                riskScore += min(0.5, Double(days) / 7.0)
            }
        }
        
        return min(1.0, riskScore)
    }
    
    private func generateInterventionSuggestions(for riskFactors: [RiskFactor], habit: Habit) -> [InterventionSuggestion] {
        var suggestions: [InterventionSuggestion] = []
        
        for factor in riskFactors {
            switch factor {
            case .decliningTrend:
                suggestions.append(InterventionSuggestion(
                    type: .adjustGoals,
                    title: "Упростите цель",
                    description: "Временно снизьте планку для восстановления мотивации",
                    urgency: .medium
                ))
            case .brokenStreak:
                suggestions.append(InterventionSuggestion(
                    type: .motivationalBoost,
                    title: "Начните новую серию",
                    description: "Сосредоточьтесь на выполнении привычки 3 дня подряд",
                    urgency: .high
                ))
            case .lowRecentSuccess:
                suggestions.append(InterventionSuggestion(
                    type: .environmentalChange,
                    title: "Измените условия",
                    description: "Попробуйте выполнять привычку в другое время или месте",
                    urgency: .high
                ))
            case .lowConsistency:
                suggestions.append(InterventionSuggestion(
                    type: .scheduleOptimization,
                    title: "Зафиксируйте время",
                    description: "Установите четкое время для выполнения привычки",
                    urgency: .medium
                ))
            case .inactivityPeriod:
                suggestions.append(InterventionSuggestion(
                    type: .reengagement,
                    title: "Возобновите активность",
                    description: "Начните с минимальной версии привычки сегодня же",
                    urgency: .critical
                ))
            }
        }
        
        return suggestions
    }
    
    private func generateTimeBasedChains(_ habits: [Habit]) -> [HabitChainSuggestion] {
        var suggestions: [HabitChainSuggestion] = []
        
        // Группируем привычки по времени напоминаний
        let habitsByTime = Dictionary(grouping: habits.filter { $0.reminderTime != nil }) { habit in
            Calendar.current.component(.hour, from: habit.reminderTime!)
        }
        
        for (hour, habitsAtTime) in habitsByTime {
            if habitsAtTime.count >= 2 {
                for i in 0..<habitsAtTime.count - 1 {
                    let suggestion = HabitChainSuggestion(
                        id: UUID(),
                        primaryHabit: habitsAtTime[i],
                        secondaryHabit: habitsAtTime[i + 1],
                        chainType: .timeBasedSequence,
                        strength: 0.7,
                        confidence: 0.6,
                        reasoning: "Эти привычки выполняются в одно время. Создание последовательности поможет не забыть.",
                        implementation: HabitChainImplementation(
                            triggerEvent: .habitCompletion(habitsAtTime[i].id),
                            action: .startHabit(habitsAtTime[i + 1].id),
                            delay: .minutes(5),
                            conditions: [.sameTimeOfDay]
                        )
                    )
                    suggestions.append(suggestion)
                }
            }
        }
        
        return suggestions
    }
    
    private func createCategorySuggestion(for category: String) -> HabitSuggestion {
        switch category {
        case "Здоровье":
            return HabitSuggestion(
                title: "Ежедневная зарядка",
                description: "10 минут утренних упражнений",
                category: category,
                difficulty: .easy,
                expectedBenefit: "Энергия и здоровье на весь день",
                basedOn: "Отсутствие привычек здоровья",
                confidence: 0.8
            )
        case "Обучение":
            return HabitSuggestion(
                title: "Чтение книг",
                description: "20 минут чтения каждый день",
                category: category,
                difficulty: .easy,
                expectedBenefit: "Расширение кругозора и знаний",
                basedOn: "Отсутствие образовательных привычек",
                confidence: 0.75
            )
        case "Продуктивность":
            return HabitSuggestion(
                title: "Планирование дня",
                description: "5 минут на составление плана с утра",
                category: category,
                difficulty: .easy,
                expectedBenefit: "Более организованный и эффективный день",
                basedOn: "Отсутствие привычек продуктивности",
                confidence: 0.8
            )
        default:
            return HabitSuggestion(
                title: "Новая привычка",
                description: "Рекомендуемая привычка для категории \(category)",
                category: category,
                difficulty: .medium,
                expectedBenefit: "Улучшение жизни",
                basedOn: "Анализ пробелов",
                confidence: 0.6
            )
        }
    }
    
    private func getDayName(_ weekday: Int) -> String {
        let days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        return days[safe: weekday - 1] ?? "день"
    }
    
    private func getOptimalTimeForDay(_ weekday: Int, based userPatterns: UserPatternAnalysis) -> Date {
        let hour = userPatterns.preferredTimeOfDay
        let components = DateComponents(hour: hour, minute: 0)
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Supporting Types

struct IntelligentReminder: Identifiable {
    let id: UUID
    let type: ReminderType
    let title: String
    let message: String
    let scheduledTime: Date
    let priority: Priority
    let adaptiveFactors: [AdaptiveFactor]
    
    enum ReminderType {
        case adaptive
        case contextual
        case streakRecovery
        case locationBased
        case weatherBased
    }
    
    enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        
        var displayName: String {
            switch self {
            case .low: return "Низкий"
            case .medium: return "Средний"
            case .high: return "Высокий"
            }
        }
    }
}

enum AdaptiveFactor {
    case weekdaySuccess(Double)
    case historicalData(Int)
    case streakHistory(Int)
    case motivationalBoost(Bool)
    case weatherConditions(Bool)
    case locationContext(String)
}

struct OptimalTimingSuggestion {
    let type: SuggestionType
    let suggestion: String
    let confidence: Double
    let reasoning: String
    let estimatedImprovement: Double
    let implementationSteps: [String]
    
    enum SuggestionType {
        case timeOfDay
        case weekday
        case frequency
        case duration
        case environment
    }
}

extension HabitSuggestion {
    init(title: String, description: String, category: String, difficulty: Difficulty, expectedBenefit: String, basedOn: String, confidence: Double) {
        self.title = title
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.expectedBenefit = expectedBenefit
        self.basedOn = basedOn
    }
    
    var confidence: Double {
        switch difficulty {
        case .easy: return 0.8
        case .medium: return 0.7
        case .hard: return 0.6
        }
    }
}

struct SuccessPrediction {
    let habitId: UUID
    let date: Date
    let successProbability: Double
    let confidence: Double
    let factors: [PredictionFactor]
    let recommendations: [String]
}

enum PredictionFactor {
    case weekdaySuccess(Double)
    case overallTrend(Double)
    case currentStreak(Double)
    case recentActivity(Double)
    case weatherConditions(Double)
    case motivationalState(Double)
    
    var valueAndWeight: (value: Double, weight: Double) {
        switch self {
        case .weekdaySuccess(let value):
            return (value, 0.3)
        case .overallTrend(let value):
            return (value, 0.25)
        case .currentStreak(let value):
            return (value, 0.2)
        case .recentActivity(let value):
            return (value, 0.15)
        case .weatherConditions(let value):
            return (value, 0.05)
        case .motivationalState(let value):
            return (value, 0.05)
        }
    }
}

struct UserPatternAnalysis {
    let preferredTimeOfDay: Int
    let preferredWeekdays: [Int]
    let averageStreakLength: Double
    let overallCompletionRate: Double
    let consistencyScore: Double
    let motivationalFactors: [MotivationalFactor]
}

enum MotivationalFactor {
    case streakMotivation
    case progressMotivation
    case socialMotivation
    case achievementMotivation
}

struct MotivationalMessage {
    let type: MessageType
    let title: String
    let message: String
    let icon: String
    let priority: Priority
    let timing: MessageTiming
    
    enum MessageType {
        case streakMaintenance
        case recordBreaking
        case progressCelebration
        case encouragement
        case achievement
    }
    
    enum Priority: Int {
        case low = 1
        case medium = 2
        case high = 3
    }
    
    enum MessageTiming {
        case beforeHabitTime
        case afterHabitCompletion
        case motivationalMoment
        case weeklyReview
    }
}

struct FailureRiskAssessment {
    let habitId: UUID
    let riskLevel: RiskLevel
    let riskScore: Double
    let riskFactors: [RiskFactor]
    let interventionSuggestions: [InterventionSuggestion]
    let timeframe: Timeframe
    
    enum Timeframe {
        case day
        case week
        case month
    }
}

enum RiskLevel: Int, CaseIterable, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        case .critical: return "Критический"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#34C759"
        case .medium: return "#FFCC00"
        case .high: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }
}

enum RiskFactor {
    case decliningTrend(Double)
    case brokenStreak(Int)
    case lowRecentSuccess(Double)
    case lowConsistency(Double)
    case inactivityPeriod(Int)
}

struct InterventionSuggestion {
    let type: InterventionType
    let title: String
    let description: String
    let urgency: Urgency
    
    enum InterventionType {
        case adjustGoals
        case motivationalBoost
        case environmentalChange
        case scheduleOptimization
        case reengagement
    }
    
    enum Urgency: Int {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        var displayName: String {
            switch self {
            case .low: return "Низкая"
            case .medium: return "Средняя"
            case .high: return "Высокая"
            case .critical: return "Критическая"
            }
        }
    }
}

struct HabitChainSuggestion: Identifiable {
    let id: UUID
    let primaryHabit: Habit
    let secondaryHabit: Habit
    let chainType: ChainType
    let strength: Double
    let confidence: Double
    let reasoning: String
    let implementation: HabitChainImplementation
    
    enum ChainType {
        case sequential
        case timeBasedSequence
        case conditional
        case locationBased
    }
}

struct HabitChainImplementation {
    let triggerEvent: TriggerEvent
    let action: ChainAction
    let delay: ChainDelay
    let conditions: [ChainCondition]
    
    enum TriggerEvent {
        case habitCompletion(UUID)
        case timeOfDay(Date)
        case location(String)
        case contextualCue(String)
    }
    
    enum ChainAction {
        case startHabit(UUID)
        case remindHabit(UUID)
        case suggestHabit(UUID)
    }
    
    enum ChainDelay {
        case immediate
        case minutes(Int)
        case hours(Int)
        case nextDay
    }
    
    enum ChainCondition {
        case sameTimeOfDay
        case sameLocation
        case weatherCondition(String)
        case dayOfWeek([Int])
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 