import Foundation
import HealthKit
import SwiftData

// MARK: - AdvancedHealthKitService Protocol

protocol AdvancedHealthKitServiceProtocol: ServiceProtocol {
    func requestPermissions() async throws
    func isHealthDataAvailable() -> Bool
    func fetchStepsData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchSleepData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchActiveEnergyData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchExerciseTimeData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchMindfulnessData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchWeightData(for dateRange: DateInterval) async throws -> [HealthData]
    func fetchWaterIntakeData(for dateRange: DateInterval) async throws -> [HealthData]
    func syncTodayData() async throws
    func calculateHabitHealthCorrelations(_ habit: Habit) async throws -> [HabitHealthCorrelation]
    func getHealthInsights(for habit: Habit) async throws -> [HealthInsight]
    func enableBackgroundDelivery(for types: [HealthDataType]) async throws
}

// MARK: - AdvancedHealthKitService Implementation

final class AdvancedHealthKitService: AdvancedHealthKitServiceProtocol {
    
    // MARK: - Properties
    
    private let healthStore = HKHealthStore()
    private let modelContext: ModelContext
    
    var isInitialized: Bool = false
    
    // Типы данных для чтения
    private let readTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        
        // Количественные показатели
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyType)
        }
        if let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTimeType)
        }
        if let mindfulnessType = HKQuantityType.quantityType(forIdentifier: .mindfulSession) {
            types.insert(mindfulnessType)
        }
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weightType)
        }
        if let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(waterType)
        }
        
        // Категориальные показатели
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        
        return types
    }()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("Initializing AdvancedHealthKitService...")
        #endif
        
        guard isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        isInitialized = true
        
        #if DEBUG
        print("AdvancedHealthKitService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("Cleaning up AdvancedHealthKitService...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("AdvancedHealthKitService cleaned up")
        #endif
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async throws {
        guard isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitError.permissionDenied)
                }
            }
        }
    }
    
    func isHealthDataAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Data Fetching
    
    func fetchStepsData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: stepsType,
            in: dateRange,
            unit: HKUnit.count()
        )
        
        return samples.map { sample in
            HealthData(
                date: sample.startDate,
                type: .steps,
                value: sample.quantity.doubleValue(for: HKUnit.count()),
                unit: "шагов",
                source: sample.sourceRevision.source.name
            )
        }
    }
    
    func fetchSleepData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchCategorySamples(for: sleepType, in: dateRange)
        
        // Группируем по дням и суммируем продолжительность сна
        let groupedSleep = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        
        return groupedSleep.compactMap { (date, samples) in
            let totalSleepDuration = samples
                .filter { $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue }
                .reduce(0.0) { result, sample in
                    result + sample.endDate.timeIntervalSince(sample.startDate)
                }
            
            guard totalSleepDuration > 0 else { return nil }
            
            return HealthData(
                date: date,
                type: .sleepDuration,
                value: totalSleepDuration / 3600, // Конвертируем в часы
                unit: "часов",
                source: samples.first?.sourceRevision.source.name
            )
        }
    }
    
    func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: heartRateType,
            in: dateRange,
            unit: HKUnit(from: "count/min")
        )
        
        // Группируем по дням и берем среднее значение
        let groupedHeartRate = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        
        return groupedHeartRate.map { (date, samples) in
            let averageHeartRate = samples.reduce(0.0) { result, sample in
                result + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            } / Double(samples.count)
            
            return HealthData(
                date: date,
                type: .heartRate,
                value: averageHeartRate,
                unit: "уд/мин",
                source: samples.first?.sourceRevision.source.name
            )
        }
    }
    
    func fetchActiveEnergyData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: energyType,
            in: dateRange,
            unit: HKUnit.kilocalorie()
        )
        
        // Группируем по дням и суммируем
        let groupedEnergy = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        
        return groupedEnergy.map { (date, samples) in
            let totalEnergy = samples.reduce(0.0) { result, sample in
                result + sample.quantity.doubleValue(for: HKUnit.kilocalorie())
            }
            
            return HealthData(
                date: date,
                type: .activeEnergyBurned,
                value: totalEnergy,
                unit: "ккал",
                source: samples.first?.sourceRevision.source.name
            )
        }
    }
    
    func fetchExerciseTimeData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: exerciseType,
            in: dateRange,
            unit: HKUnit.minute()
        )
        
        // Группируем по дням и суммируем
        let groupedExercise = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        
        return groupedExercise.map { (date, samples) in
            let totalExercise = samples.reduce(0.0) { result, sample in
                result + sample.quantity.doubleValue(for: HKUnit.minute())
            }
            
            return HealthData(
                date: date,
                type: .exerciseTime,
                value: totalExercise,
                unit: "минут",
                source: samples.first?.sourceRevision.source.name
            )
        }
    }
    
    func fetchMindfulnessData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let mindfulnessType = HKQuantityType.quantityType(forIdentifier: .mindfulSession) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: mindfulnessType,
            in: dateRange,
            unit: HKUnit.minute()
        )
        
        // Группируем по дням и суммируем
        let groupedMindfulness = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        
        return groupedMindfulness.map { (date, samples) in
            let totalMindfulness = samples.reduce(0.0) { result, sample in
                result + sample.quantity.doubleValue(for: HKUnit.minute())
            }
            
            return HealthData(
                date: date,
                type: .mindfulMinutes,
                value: totalMindfulness,
                unit: "минут",
                source: samples.first?.sourceRevision.source.name
            )
        }
    }
    
    func fetchWeightData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: weightType,
            in: dateRange,
            unit: HKUnit.gramUnit(with: .kilo)
        )
        
        return samples.map { sample in
            HealthData(
                date: sample.startDate,
                type: .weight,
                value: sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo)),
                unit: "кг",
                source: sample.sourceRevision.source.name
            )
        }
    }
    
    func fetchWaterIntakeData(for dateRange: DateInterval) async throws -> [HealthData] {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            throw HealthKitError.invalidType
        }
        
        let samples = try await fetchQuantitySamples(
            for: waterType,
            in: dateRange,
            unit: HKUnit.literUnit(with: .milli)
        )
        
        // Группируем по дням и суммируем
        let groupedWater = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }
        
        return groupedWater.map { (date, samples) in
            let totalWater = samples.reduce(0.0) { result, sample in
                result + sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli))
            }
            
            return HealthData(
                date: date,
                type: .waterIntake,
                value: totalWater,
                unit: "мл",
                source: samples.first?.sourceRevision.source.name
            )
        }
    }
    
    // MARK: - Data Synchronization
    
    func syncTodayData() async throws {
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        let dateRange = DateInterval(start: startOfDay, end: endOfDay)
        
        async let steps = fetchStepsData(for: dateRange)
        async let sleep = fetchSleepData(for: dateRange)
        async let heartRate = fetchHeartRateData(for: dateRange)
        async let activeEnergy = fetchActiveEnergyData(for: dateRange)
        async let exerciseTime = fetchExerciseTimeData(for: dateRange)
        async let mindfulness = fetchMindfulnessData(for: dateRange)
        async let weight = fetchWeightData(for: dateRange)
        async let water = fetchWaterIntakeData(for: dateRange)
        
        let allHealthData = try await [
            steps, sleep, heartRate, activeEnergy,
            exerciseTime, mindfulness, weight, water
        ].flatMap { $0 }
        
        // Сохраняем данные в базу
        for healthData in allHealthData {
            // Проверяем, есть ли уже такие данные
            let existingData = try await fetchExistingHealthData(
                type: healthData.type,
                date: healthData.date
            )
            
            if existingData == nil {
                modelContext.insert(healthData)
            }
        }
        
        try modelContext.save()
    }
    
    // MARK: - Correlation Analysis
    
    func calculateHabitHealthCorrelations(_ habit: Habit) async throws -> [HabitHealthCorrelation] {
        let dateRange = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date(),
            end: Date()
        )
        
        var correlations: [HabitHealthCorrelation] = []
        
        for healthType in HealthDataType.allCases {
            let correlation = try await calculateCorrelation(
                habit: habit,
                healthType: healthType,
                dateRange: dateRange
            )
            
            if let correlation = correlation {
                correlations.append(correlation)
            }
        }
        
        return correlations
    }
    
    func getHealthInsights(for habit: Habit) async throws -> [HealthInsight] {
        let correlations = try await calculateHabitHealthCorrelations(habit)
        var insights: [HealthInsight] = []
        
        for correlation in correlations {
            if correlation.correlationStrength != .negligible && correlation.confidenceLevel > 0.7 {
                let insight = generateInsight(from: correlation)
                insights.append(insight)
            }
        }
        
        return insights
    }
    
    // MARK: - Background Delivery
    
    func enableBackgroundDelivery(for types: [HealthDataType]) async throws {
        for type in types {
            guard let hkType = getHKQuantityType(for: type) else { continue }
            
            try await withCheckedThrowingContinuation { continuation in
                healthStore.enableBackgroundDelivery(for: hkType, frequency: .daily) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchQuantitySamples(
        for type: HKQuantityType,
        in dateRange: DateInterval,
        unit: HKUnit
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: dateRange.start,
            end: dateRange.end,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchCategorySamples(
        for type: HKCategoryType,
        in dateRange: DateInterval
    ) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: dateRange.start,
            end: dateRange.end,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchExistingHealthData(type: HealthDataType, date: Date) async throws -> HealthData? {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date
        
        let descriptor = FetchDescriptor<HealthData>(
            predicate: #Predicate<HealthData> { healthData in
                healthData.type == type &&
                healthData.date >= dayStart &&
                healthData.date < dayEnd
            }
        )
        
        let results = try modelContext.fetch(descriptor)
        return results.first
    }
    
    private func calculateCorrelation(
        habit: Habit,
        healthType: HealthDataType,
        dateRange: DateInterval
    ) async throws -> HabitHealthCorrelation? {
        // Получаем данные о привычке
        let habitEntries = habit.entries.filter { entry in
            dateRange.contains(entry.date)
        }
        
        guard habitEntries.count >= 14 else { return nil } // Минимум 2 недели данных
        
        // Получаем данные о здоровье
        let healthDataDescriptor = FetchDescriptor<HealthData>(
            predicate: #Predicate<HealthData> { healthData in
                healthData.type == healthType &&
                healthData.date >= dateRange.start &&
                healthData.date <= dateRange.end
            }
        )
        
        let healthData = try modelContext.fetch(healthDataDescriptor)
        guard healthData.count >= 14 else { return nil }
        
        // Подготавливаем данные для корреляционного анализа
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let habitDataByDate = Dictionary(
            habitEntries.map { (dateFormatter.string(from: $0.date), Double($0.value)) },
            uniquingKeysWith: { first, _ in first }
        )
        
        let healthDataByDate = Dictionary(
            healthData.map { (dateFormatter.string(from: $0.date), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        
        // Находим общие даты
        let commonDates = Set(habitDataByDate.keys).intersection(Set(healthDataByDate.keys))
        guard commonDates.count >= 14 else { return nil }
        
        let habitValues = commonDates.compactMap { habitDataByDate[$0] }
        let healthValues = commonDates.compactMap { healthDataByDate[$0] }
        
        // Рассчитываем корреляцию Пирсона
        let correlationScore = calculatePearsonCorrelation(habitValues, healthValues)
        let confidenceLevel = calculateConfidenceLevel(dataPoints: commonDates.count)
        
        return HabitHealthCorrelation(
            habit: habit,
            healthDataType: healthType,
            correlationScore: correlationScore,
            confidenceLevel: confidenceLevel,
            dataPoints: commonDates.count
        )
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
    
    private func calculateConfidenceLevel(dataPoints: Int) -> Double {
        // Простая оценка достоверности на основе количества точек данных
        switch dataPoints {
        case 0..<7:
            return 0.0
        case 7..<14:
            return 0.3
        case 14..<30:
            return 0.6
        case 30..<60:
            return 0.8
        default:
            return 0.9
        }
    }
    
    private func generateInsight(from correlation: HabitHealthCorrelation) -> HealthInsight {
        let direction = correlation.correlationDirection
        let strength = correlation.correlationStrength
        
        var message = ""
        var recommendation = ""
        
        switch (correlation.healthDataType, direction) {
        case (.steps, .positive):
            message = "Выполнение этой привычки \(strength.displayName.lowercased()) связано с увеличением активности."
            recommendation = "Продолжайте! Эта привычка положительно влияет на вашу физическую активность."
            
        case (.sleepDuration, .positive):
            message = "Эта привычка \(strength.displayName.lowercased()) улучшает качество сна."
            recommendation = "Старайтесь выполнять эту привычку регулярно для лучшего сна."
            
        case (.heartRate, .negative):
            message = "Выполнение этой привычки связано со снижением пульса в покое."
            recommendation = "Отличная привычка для здоровья сердца!"
            
        default:
            message = "Обнаружена \(correlation.correlationDescription) между привычкой и показателем \(correlation.healthDataType.displayName.lowercased())."
            recommendation = "Продолжайте отслеживать эту связь."
        }
        
        return HealthInsight(
            type: .correlation,
            title: "Связь с \(correlation.healthDataType.displayName.lowercased())",
            message: message,
            recommendation: recommendation,
            confidence: correlation.confidenceLevel,
            dataPoints: correlation.dataPoints
        )
    }
    
    private func getHKQuantityType(for healthType: HealthDataType) -> HKQuantityType? {
        guard let identifier = healthType.healthKitIdentifier else { return nil }
        return HKQuantityType.quantityType(forIdentifier: identifier)
    }
}

// MARK: - Supporting Types

enum HealthKitError: LocalizedError {
    case notAvailable
    case permissionDenied
    case invalidType
    case dataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit недоступен на этом устройстве"
        case .permissionDenied:
            return "Доступ к данным HealthKit запрещен"
        case .invalidType:
            return "Недопустимый тип данных HealthKit"
        case .dataUnavailable:
            return "Данные HealthKit недоступны"
        }
    }
}

struct HealthInsight {
    let type: InsightType
    let title: String
    let message: String
    let recommendation: String
    let confidence: Double
    let dataPoints: Int
    
    enum InsightType {
        case correlation
        case trend
        case recommendation
        case warning
    }
} 