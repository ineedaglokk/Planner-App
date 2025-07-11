import Foundation
import SwiftData

// MARK: - HabitAnalyticsService Protocol

protocol HabitAnalyticsServiceProtocol: ServiceProtocol {
    func getHabitTrends(_ habit: Habit, period: AnalyticsPeriod) async throws -> HabitTrends
    func getHabitHeatmapData(_ habit: Habit, year: Int?) async throws -> HabitHeatmapData
    func getWeeklyPatterns(_ habit: Habit) async throws -> WeeklyPatterns
    func getSuccessRateAnalysis(_ habit: Habit) async throws -> SuccessRateAnalysis
    func getStreakAnalytics(_ habit: Habit) async throws -> StreakAnalytics
    func getOptimalTimingRecommendations(_ habit: Habit) async throws -> [TimingRecommendation]
    func getHabitCorrelationMatrix(_ habits: [Habit]) async throws -> CorrelationMatrix
    func getPredictiveInsights(_ habit: Habit) async throws -> [PredictiveInsight]
    func getOverallAnalytics(_ habits: [Habit]) async throws -> OverallAnalytics
    func getPerformanceMetrics(_ habit: Habit, period: AnalyticsPeriod) async throws -> PerformanceMetrics
}

// MARK: - HabitAnalyticsService Implementation

final class HabitAnalyticsService: HabitAnalyticsServiceProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("Initializing HabitAnalyticsService...")
        #endif
        
        isInitialized = true
        
        #if DEBUG
        print("HabitAnalyticsService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("Cleaning up HabitAnalyticsService...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("HabitAnalyticsService cleaned up")
        #endif
    }
    
    // MARK: - Trends Analysis
    
    func getHabitTrends(_ habit: Habit, period: AnalyticsPeriod) async throws -> HabitTrends {
        let dateRange = period.dateRange
        let entries = habit.entries.filter { entry in
            dateRange.contains(entry.date)
        }.sorted { $0.date < $1.date }
        
        guard !entries.isEmpty else {
            return HabitTrends(
                direction: .stable,
                strength: 0.0,
                dataPoints: [],
                growthRate: 0.0,
                confidenceLevel: 0.0
            )
        }
        
        // Создаем точки данных по дням
        let dataPoints = createDataPoints(from: entries, for: dateRange)
        
        // Вычисляем тренд
        let trend = calculateTrend(dataPoints: dataPoints)
        
        return HabitTrends(
            direction: trend.direction,
            strength: trend.strength,
            dataPoints: dataPoints,
            growthRate: trend.growthRate,
            confidenceLevel: trend.confidenceLevel
        )
    }
    
    // MARK: - Heatmap Data
    
    func getHabitHeatmapData(_ habit: Habit, year: Int?) async throws -> HabitHeatmapData {
        let targetYear = year ?? Calendar.current.component(.year, from: Date())
        let calendar = Calendar.current
        
        guard let startOfYear = calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: targetYear + 1, month: 1, day: 1)) else {
            throw AnalyticsError.invalidDateRange
        }
        
        let entries = habit.entries.filter { entry in
            entry.date >= startOfYear && entry.date < endOfYear
        }
        
        var heatmapData: [Date: HeatmapValue] = [:]
        
        // Проходим по всем дням года
        var currentDate = startOfYear
        while currentDate < endOfYear {
            let dayEntry = entries.first { calendar.isDate($0.date, inSameDayAs: currentDate) }
            
            let value: HeatmapValue
            if let entry = dayEntry {
                let completion = Double(entry.value) / Double(habit.targetValue)
                value = HeatmapValue(
                    completion: min(completion, 1.0),
                    value: entry.value,
                    isCompleted: entry.isTargetMet
                )
            } else if habit.shouldTrackForDate(currentDate) {
                value = HeatmapValue(completion: 0.0, value: 0, isCompleted: false)
            } else {
                value = HeatmapValue(completion: -1.0, value: 0, isCompleted: false) // Не отслеживаемый день
            }
            
            heatmapData[currentDate] = value
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return HabitHeatmapData(
            year: targetYear,
            data: heatmapData,
            totalDays: heatmapData.count,
            completedDays: heatmapData.values.filter { $0.isCompleted }.count,
            trackedDays: heatmapData.values.filter { $0.completion >= 0 }.count
        )
    }
    
    // MARK: - Weekly Patterns
    
    func getWeeklyPatterns(_ habit: Habit) async throws -> WeeklyPatterns {
        let last12Weeks = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: Date()) ?? Date()
        let recentEntries = habit.entries.filter { $0.date >= last12Weeks }
        
        var weekdayCompletions: [Int: [Bool]] = [:]
        
        for entry in recentEntries {
            let weekday = Calendar.current.component(.weekday, from: entry.date)
            if weekdayCompletions[weekday] == nil {
                weekdayCompletions[weekday] = []
            }
            weekdayCompletions[weekday]?.append(entry.isTargetMet)
        }
        
        var patterns: [WeekdayPattern] = []
        
        for weekday in 1...7 {
            let completions = weekdayCompletions[weekday] ?? []
            let successRate = completions.isEmpty ? 0.0 : Double(completions.filter { $0 }.count) / Double(completions.count)
            
            patterns.append(WeekdayPattern(
                weekday: weekday,
                successRate: successRate,
                totalAttempts: completions.count,
                averageValue: calculateAverageValue(for: weekday, in: recentEntries)
            ))
        }
        
        return WeeklyPatterns(
            patterns: patterns,
            bestDay: patterns.max { $0.successRate < $1.successRate },
            worstDay: patterns.min { $0.successRate < $1.successRate }
        )
    }
    
    // MARK: - Success Rate Analysis
    
    func getSuccessRateAnalysis(_ habit: Habit) async throws -> SuccessRateAnalysis {
        let allEntries = habit.entries.sorted { $0.date < $1.date }
        
        let last7Days = calculateSuccessRate(entries: allEntries, days: 7)
        let last30Days = calculateSuccessRate(entries: allEntries, days: 30)
        let last90Days = calculateSuccessRate(entries: allEntries, days: 90)
        let allTime = calculateSuccessRate(entries: allEntries, days: nil)
        
        let trend = calculateSuccessRateTrend(entries: allEntries)
        
        return SuccessRateAnalysis(
            last7Days: last7Days,
            last30Days: last30Days,
            last90Days: last90Days,
            allTime: allTime,
            trend: trend,
            consistency: calculateConsistency(entries: allEntries)
        )
    }
    
    // MARK: - Streak Analytics
    
    func getStreakAnalytics(_ habit: Habit) async throws -> StreakAnalytics {
        let allEntries = habit.entries.sorted { $0.date < $1.date }
        let streaks = calculateAllStreaks(entries: allEntries, habit: habit)
        
        let currentStreak = habit.currentStreak
        let longestStreak = streaks.max() ?? 0
        let averageStreak = streaks.isEmpty ? 0.0 : Double(streaks.reduce(0, +)) / Double(streaks.count)
        
        return StreakAnalytics(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            averageStreak: averageStreak,
            totalStreaks: streaks.count,
            streakDistribution: calculateStreakDistribution(streaks: streaks),
            streakTrend: calculateStreakTrend(streaks: streaks)
        )
    }
    
    // MARK: - Timing Recommendations
    
    func getOptimalTimingRecommendations(_ habit: Habit) async throws -> [TimingRecommendation] {
        var recommendations: [TimingRecommendation] = []
        
        // Анализ времени выполнения (если есть данные)
        let weeklyPatterns = try await getWeeklyPatterns(habit)
        
        if let bestDay = weeklyPatterns.bestDay, let worstDay = weeklyPatterns.worstDay {
            if bestDay.successRate - worstDay.successRate > 0.2 {
                recommendations.append(TimingRecommendation(
                    type: .weekday,
                    suggestion: "Лучший день для этой привычки - \(getDayName(bestDay.weekday))",
                    confidence: 0.8,
                    reason: "На основе анализа последних 12 недель"
                ))
            }
        }
        
        // Анализ последовательности
        let consistency = calculateConsistency(entries: habit.entries)
        if consistency < 0.5 {
            recommendations.append(TimingRecommendation(
                type: .consistency,
                suggestion: "Попробуйте выполнять привычку в одно и то же время каждый день",
                confidence: 0.7,
                reason: "Низкая последовательность выполнения"
            ))
        }
        
        // Анализ streak паттернов
        let streakAnalytics = try await getStreakAnalytics(habit)
        if streakAnalytics.averageStreak < 3 {
            recommendations.append(TimingRecommendation(
                type: .streak,
                suggestion: "Сосредоточьтесь на выполнении привычки 3 дня подряд",
                confidence: 0.9,
                reason: "Короткие серии указывают на необходимость улучшения последовательности"
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Correlation Matrix
    
    func getHabitCorrelationMatrix(_ habits: [Habit]) async throws -> CorrelationMatrix {
        var correlations: [HabitCorrelation] = []
        
        for i in 0..<habits.count {
            for j in (i+1)..<habits.count {
                let correlation = calculateHabitCorrelation(habits[i], habits[j])
                if abs(correlation.score) > 0.1 {
                    correlations.append(correlation)
                }
            }
        }
        
        return CorrelationMatrix(
            habits: habits,
            correlations: correlations.sorted { abs($0.score) > abs($1.score) }
        )
    }
    
    // MARK: - Predictive Insights
    
    func getPredictiveInsights(_ habit: Habit) async throws -> [PredictiveInsight] {
        var insights: [PredictiveInsight] = []
        
        let trends = try await getHabitTrends(habit, period: .month)
        let weeklyPatterns = try await getWeeklyPatterns(habit)
        let streakAnalytics = try await getStreakAnalytics(habit)
        
        // Предсказание на основе тренда
        if trends.direction == .improving && trends.confidenceLevel > 0.7 {
            insights.append(PredictiveInsight(
                type: .positive,
                prediction: "Вероятность достижения цели на следующей неделе: \(Int(trends.confidenceLevel * 100))%",
                confidence: trends.confidenceLevel,
                timeframe: .week
            ))
        } else if trends.direction == .declining && trends.confidenceLevel > 0.7 {
            insights.append(PredictiveInsight(
                type: .warning,
                prediction: "Риск пропуска привычки повышен на \(Int(trends.confidenceLevel * 100))%",
                confidence: trends.confidenceLevel,
                timeframe: .week
            ))
        }
        
        // Предсказание streak
        if streakAnalytics.currentStreak > 0 && streakAnalytics.currentStreak >= streakAnalytics.averageStreak {
            let streakProbability = min(0.9, Double(streakAnalytics.currentStreak) / Double(streakAnalytics.longestStreak))
            insights.append(PredictiveInsight(
                type: .streak,
                prediction: "Вероятность продолжения серии: \(Int(streakProbability * 100))%",
                confidence: streakProbability,
                timeframe: .day
            ))
        }
        
        return insights
    }
    
    // MARK: - Overall Analytics
    
    func getOverallAnalytics(_ habits: [Habit]) async throws -> OverallAnalytics {
        let activeHabits = habits.filter { $0.isActive }
        let totalHabits = activeHabits.count
        
        guard totalHabits > 0 else {
            return OverallAnalytics(
                totalHabits: 0,
                averageSuccessRate: 0.0,
                totalStreaks: 0,
                averageStreak: 0.0,
                topPerformingHabits: [],
                improvementAreas: []
            )
        }
        
        var totalSuccessRate = 0.0
        var totalCurrentStreaks = 0
        var habitPerformances: [(Habit, Double)] = []
        
        for habit in activeHabits {
            let successRate = habit.completionRate
            totalSuccessRate += successRate
            totalCurrentStreaks += habit.currentStreak
            habitPerformances.append((habit, successRate))
        }
        
        let averageSuccessRate = totalSuccessRate / Double(totalHabits)
        let averageStreak = Double(totalCurrentStreaks) / Double(totalHabits)
        
        // Топ-3 лучших привычки
        let topPerforming = habitPerformances
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }
        
        // Области для улучшения (привычки с низким показателем)
        let improvementAreas = habitPerformances
            .filter { $0.1 < 0.5 }
            .sorted { $0.1 < $1.1 }
            .prefix(3)
            .map { $0.0 }
        
        return OverallAnalytics(
            totalHabits: totalHabits,
            averageSuccessRate: averageSuccessRate,
            totalStreaks: totalCurrentStreaks,
            averageStreak: averageStreak,
            topPerformingHabits: Array(topPerforming),
            improvementAreas: Array(improvementAreas)
        )
    }
    
    // MARK: - Performance Metrics
    
    func getPerformanceMetrics(_ habit: Habit, period: AnalyticsPeriod) async throws -> PerformanceMetrics {
        let dateRange = period.dateRange
        let entries = habit.entries.filter { dateRange.contains($0.date) }
        
        let totalDays = Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0
        let trackedDays = entries.count
        let completedDays = entries.filter { $0.isTargetMet }.count
        
        let efficiency = trackedDays > 0 ? Double(completedDays) / Double(trackedDays) : 0.0
        let engagement = totalDays > 0 ? Double(trackedDays) / Double(totalDays) : 0.0
        
        let averageValue = entries.isEmpty ? 0.0 : Double(entries.reduce(0) { $0 + $1.value }) / Double(entries.count)
        let targetValue = Double(habit.targetValue)
        let performance = targetValue > 0 ? averageValue / targetValue : 0.0
        
        return PerformanceMetrics(
            period: period,
            efficiency: efficiency,
            engagement: engagement,
            performance: performance,
            consistency: calculateConsistency(entries: entries),
            totalEntries: trackedDays,
            averageValue: averageValue
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func createDataPoints(from entries: [HabitEntry], for dateRange: DateInterval) -> [TrendDataPoint] {
        let calendar = Calendar.current
        var dataPoints: [TrendDataPoint] = []
        
        let days = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 0
        let interval = max(1, days / 50) // Максимум 50 точек данных
        
        for i in stride(from: 0, to: days, by: interval) {
            guard let date = calendar.date(byAdding: .day, value: i, to: dateRange.start) else { continue }
            
            let endDate = calendar.date(byAdding: .day, value: interval, to: date) ?? date
            let periodEntries = entries.filter { $0.date >= date && $0.date < endDate }
            
            let avgValue = periodEntries.isEmpty ? 0.0 : Double(periodEntries.reduce(0) { $0 + $1.value }) / Double(periodEntries.count)
            
            dataPoints.append(TrendDataPoint(date: date, value: avgValue))
        }
        
        return dataPoints
    }
    
    private func calculateTrend(dataPoints: [TrendDataPoint]) -> (direction: TrendDirection, strength: Double, growthRate: Double, confidenceLevel: Double) {
        guard dataPoints.count >= 2 else {
            return (.stable, 0.0, 0.0, 0.0)
        }
        
        let xValues = dataPoints.enumerated().map { Double($0.offset) }
        let yValues = dataPoints.map { $0.value }
        
        let correlation = calculatePearsonCorrelation(xValues, yValues)
        let slope = calculateLinearRegressionSlope(xValues, yValues)
        
        let direction: TrendDirection
        if correlation > 0.1 {
            direction = .improving
        } else if correlation < -0.1 {
            direction = .declining
        } else {
            direction = .stable
        }
        
        let strength = abs(correlation)
        let growthRate = slope
        let confidenceLevel = min(0.9, strength + 0.1)
        
        return (direction, strength, growthRate, confidenceLevel)
    }
    
    private func calculatePearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0.0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)
        let sumYY = y.map { $0 * $0 }.reduce(0, +)
        
        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY))
        
        guard denominator != 0 else { return 0.0 }
        
        return numerator / denominator
    }
    
    private func calculateLinearRegressionSlope(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count && x.count > 1 else { return 0.0 }
        
        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)
        
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return 0.0 }
        
        return (n * sumXY - sumX * sumY) / denominator
    }
    
    private func calculateAverageValue(for weekday: Int, in entries: [HabitEntry]) -> Double {
        let weekdayEntries = entries.filter { Calendar.current.component(.weekday, from: $0.date) == weekday }
        guard !weekdayEntries.isEmpty else { return 0.0 }
        
        return Double(weekdayEntries.reduce(0) { $0 + $1.value }) / Double(weekdayEntries.count)
    }
    
    private func calculateSuccessRate(entries: [HabitEntry], days: Int?) -> Double {
        let targetDate = days.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date() } ?? Date.distantPast
        let relevantEntries = entries.filter { $0.date >= targetDate }
        
        guard !relevantEntries.isEmpty else { return 0.0 }
        
        let completedEntries = relevantEntries.filter { $0.isTargetMet }
        return Double(completedEntries.count) / Double(relevantEntries.count)
    }
    
    private func calculateSuccessRateTrend(entries: [HabitEntry]) -> TrendDirection {
        let recent = calculateSuccessRate(entries: entries, days: 7)
        let previous = calculateSuccessRate(entries: entries.filter { $0.date < Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() }, days: 7)
        
        if recent > previous + 0.1 {
            return .improving
        } else if recent < previous - 0.1 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateConsistency(entries: [HabitEntry]) -> Double {
        guard entries.count >= 7 else { return 0.0 }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let intervals = zip(sortedEntries.dropFirst(), sortedEntries).map { next, current in
            Calendar.current.dateComponents([.day], from: current.date, to: next.date).day ?? 1
        }
        
        guard !intervals.isEmpty else { return 0.0 }
        
        let averageInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let variance = intervals.map { pow(Double($0) - averageInterval, 2) }.reduce(0, +) / Double(intervals.count)
        
        return max(0.0, 1.0 - variance / 10.0) // Нормализуем к [0, 1]
    }
    
    private func calculateAllStreaks(entries: [HabitEntry], habit: Habit) -> [Int] {
        let calendar = Calendar.current
        let sortedEntries = entries.filter { $0.isTargetMet }.sorted { $0.date < $1.date }
        
        var streaks: [Int] = []
        var currentStreak = 0
        var lastDate: Date?
        
        for entry in sortedEntries {
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: entry.date).day ?? 0
                
                if daysBetween == 1 {
                    currentStreak += 1
                } else {
                    if currentStreak > 0 {
                        streaks.append(currentStreak)
                    }
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = entry.date
        }
        
        if currentStreak > 0 {
            streaks.append(currentStreak)
        }
        
        return streaks
    }
    
    private func calculateStreakDistribution(streaks: [Int]) -> [Int: Int] {
        var distribution: [Int: Int] = [:]
        
        for streak in streaks {
            let bucket = min(streak, 30) // Группируем длинные серии
            distribution[bucket, default: 0] += 1
        }
        
        return distribution
    }
    
    private func calculateStreakTrend(streaks: [Int]) -> TrendDirection {
        guard streaks.count >= 3 else { return .stable }
        
        let recent = Array(streaks.suffix(3))
        let previous = Array(streaks.prefix(streaks.count - 3).suffix(3))
        
        let recentAvg = Double(recent.reduce(0, +)) / Double(recent.count)
        let previousAvg = Double(previous.reduce(0, +)) / Double(previous.count)
        
        if recentAvg > previousAvg + 1 {
            return .improving
        } else if recentAvg < previousAvg - 1 {
            return .declining
        } else {
            return .stable
        }
    }
    
    private func calculateHabitCorrelation(_ habit1: Habit, _ habit2: Habit) -> HabitCorrelation {
        let dateRange = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date(),
            end: Date()
        )
        
        let entries1 = habit1.entries.filter { dateRange.contains($0.date) }
        let entries2 = habit2.entries.filter { dateRange.contains($0.date) }
        
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let data1 = Dictionary(entries1.map { (dateFormatter.string(from: $0.date), $0.isTargetMet ? 1.0 : 0.0) }, uniquingKeysWith: { first, _ in first })
        let data2 = Dictionary(entries2.map { (dateFormatter.string(from: $0.date), $0.isTargetMet ? 1.0 : 0.0) }, uniquingKeysWith: { first, _ in first })
        
        let commonDates = Set(data1.keys).intersection(Set(data2.keys))
        guard commonDates.count >= 7 else {
            return HabitCorrelation(habit1: habit1, habit2: habit2, score: 0.0, confidence: 0.0, dataPoints: 0)
        }
        
        let values1 = commonDates.compactMap { data1[$0] }
        let values2 = commonDates.compactMap { data2[$0] }
        
        let correlation = calculatePearsonCorrelation(values1, values2)
        let confidence = min(0.9, Double(commonDates.count) / 30.0)
        
        return HabitCorrelation(
            habit1: habit1,
            habit2: habit2,
            score: correlation,
            confidence: confidence,
            dataPoints: commonDates.count
        )
    }
    
    private func getDayName(_ weekday: Int) -> String {
        let days = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]
        return days[safe: weekday - 1] ?? "неизвестный день"
    }
}

// MARK: - Supporting Types

enum AnalyticsPeriod: CaseIterable {
    case week
    case month
    case quarter
    case year
    case custom(DateInterval)
    
    var dateRange: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? now
            return DateInterval(start: startOfWeek, end: endOfWeek)
            
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
            return DateInterval(start: startOfMonth, end: endOfMonth)
            
        case .quarter:
            let startOfQuarter = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return DateInterval(start: startOfQuarter, end: now)
            
        case .year:
            let startOfYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return DateInterval(start: startOfYear, end: now)
            
        case .custom(let interval):
            return interval
        }
    }
    
    var displayName: String {
        switch self {
        case .week:
            return "Неделя"
        case .month:
            return "Месяц"
        case .quarter:
            return "Квартал"
        case .year:
            return "Год"
        case .custom:
            return "Период"
        }
    }
}

enum TrendDirection: CaseIterable {
    case improving
    case declining
    case stable
    
    var displayName: String {
        switch self {
        case .improving:
            return "Улучшение"
        case .declining:
            return "Снижение"
        case .stable:
            return "Стабильно"
        }
    }
    
    var icon: String {
        switch self {
        case .improving:
            return "arrow.up.right"
        case .declining:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }
    
    var color: String {
        switch self {
        case .improving:
            return "#34C759"
        case .declining:
            return "#FF3B30"
        case .stable:
            return "#8E8E93"
        }
    }
}

enum AnalyticsError: LocalizedError {
    case invalidDateRange
    case insufficientData
    case calculationError
    
    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "Недопустимый диапазон дат"
        case .insufficientData:
            return "Недостаточно данных для анализа"
        case .calculationError:
            return "Ошибка при выполнении расчетов"
        }
    }
}

// MARK: - Data Structures

struct HabitTrends {
    let direction: TrendDirection
    let strength: Double // 0.0 - 1.0
    let dataPoints: [TrendDataPoint]
    let growthRate: Double
    let confidenceLevel: Double // 0.0 - 1.0
}

struct TrendDataPoint {
    let date: Date
    let value: Double
}

struct HabitHeatmapData {
    let year: Int
    let data: [Date: HeatmapValue]
    let totalDays: Int
    let completedDays: Int
    let trackedDays: Int
    
    var completionRate: Double {
        return trackedDays > 0 ? Double(completedDays) / Double(trackedDays) : 0.0
    }
}

struct HeatmapValue {
    let completion: Double // -1.0 = не отслеживается, 0.0-1.0 = процент выполнения
    let value: Int
    let isCompleted: Bool
}

struct WeeklyPatterns {
    let patterns: [WeekdayPattern]
    let bestDay: WeekdayPattern?
    let worstDay: WeekdayPattern?
}

struct WeekdayPattern {
    let weekday: Int // 1 = воскресенье
    let successRate: Double
    let totalAttempts: Int
    let averageValue: Double
}

struct SuccessRateAnalysis {
    let last7Days: Double
    let last30Days: Double
    let last90Days: Double
    let allTime: Double
    let trend: TrendDirection
    let consistency: Double
}

struct StreakAnalytics {
    let currentStreak: Int
    let longestStreak: Int
    let averageStreak: Double
    let totalStreaks: Int
    let streakDistribution: [Int: Int]
    let streakTrend: TrendDirection
}

struct TimingRecommendation {
    let type: RecommendationType
    let suggestion: String
    let confidence: Double
    let reason: String
    
    enum RecommendationType {
        case weekday
        case timeOfDay
        case consistency
        case streak
        case frequency
    }
}

struct CorrelationMatrix {
    let habits: [Habit]
    let correlations: [HabitCorrelation]
}

struct HabitCorrelation {
    let habit1: Habit
    let habit2: Habit
    let score: Double // -1.0 to 1.0
    let confidence: Double
    let dataPoints: Int
}

struct PredictiveInsight {
    let type: InsightType
    let prediction: String
    let confidence: Double
    let timeframe: Timeframe
    
    enum InsightType {
        case positive
        case warning
        case streak
        case goal
    }
    
    enum Timeframe {
        case day
        case week
        case month
    }
}

struct OverallAnalytics {
    let totalHabits: Int
    let averageSuccessRate: Double
    let totalStreaks: Int
    let averageStreak: Double
    let topPerformingHabits: [Habit]
    let improvementAreas: [Habit]
}

struct PerformanceMetrics {
    let period: AnalyticsPeriod
    let efficiency: Double // Процент выполненных из отслеженных
    let engagement: Double // Процент отслеженных дней от общего количества
    let performance: Double // Среднее значение / целевое значение
    let consistency: Double // Постоянство выполнения
    let totalEntries: Int
    let averageValue: Double
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 