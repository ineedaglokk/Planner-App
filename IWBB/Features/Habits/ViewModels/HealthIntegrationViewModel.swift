import Foundation
import SwiftUI
import HealthKit

// MARK: - HealthIntegrationViewModel

@Observable
final class HealthIntegrationViewModel {
    
    // MARK: - State
    
    struct State {
        var isHealthKitAvailable: Bool = false
        var hasPermissions: Bool = false
        var isLoading: Bool = false
        var isSyncing: Bool = false
        var error: AppError?
        
        // Health Data
        var todayHealthData: [HealthData] = []
        var healthCorrelations: [HabitHealthCorrelation] = []
        var healthInsights: [HealthInsight] = []
        
        // Selected Data
        var selectedHabit: Habit?
        var selectedHealthTypes: Set<HealthDataType> = [.steps, .sleepDuration, .heartRate]
        var selectedDateRange: DateInterval = {
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            return DateInterval(start: startDate, end: endDate)
        }()
        
        // View State
        var showingPermissionSheet: Bool = false
        var showingHealthTypesPicker: Bool = false
        var showingDateRangePicker: Bool = false
        var selectedTab: HealthTab = .overview
    }
    
    // MARK: - Input
    
    enum Input {
        case checkHealthKitAvailability
        case requestPermissions
        case syncTodayData
        case loadHealthData
        case loadCorrelations(Habit?)
        case healthTypeSelectionChanged(Set<HealthDataType>)
        case dateRangeChanged(DateInterval)
        case habitSelected(Habit?)
        case tabChanged(HealthTab)
        case showPermissionSheet
        case hidePermissionSheet
        case showHealthTypesPicker
        case hideHealthTypesPicker
        case showDateRangePicker
        case hideDateRangePicker
        case enableBackgroundSync
        case dismissError
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let healthKitService: AdvancedHealthKitServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    init(
        healthKitService: AdvancedHealthKitServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol
    ) {
        self.healthKitService = healthKitService
        self.errorHandlingService = errorHandlingService
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .checkHealthKitAvailability:
                await checkHealthKitAvailability()
            case .requestPermissions:
                await requestPermissions()
            case .syncTodayData:
                await syncTodayData()
            case .loadHealthData:
                await loadHealthData()
            case .loadCorrelations(let habit):
                state.selectedHabit = habit
                await loadCorrelations()
            case .healthTypeSelectionChanged(let types):
                state.selectedHealthTypes = types
                state.showingHealthTypesPicker = false
                await loadHealthData()
            case .dateRangeChanged(let range):
                state.selectedDateRange = range
                state.showingDateRangePicker = false
                await loadHealthData()
            case .habitSelected(let habit):
                state.selectedHabit = habit
                await loadCorrelations()
            case .tabChanged(let tab):
                state.selectedTab = tab
            case .showPermissionSheet:
                state.showingPermissionSheet = true
            case .hidePermissionSheet:
                state.showingPermissionSheet = false
            case .showHealthTypesPicker:
                state.showingHealthTypesPicker = true
            case .hideHealthTypesPicker:
                state.showingHealthTypesPicker = false
            case .showDateRangePicker:
                state.showingDateRangePicker = true
            case .hideDateRangePicker:
                state.showingDateRangePicker = false
            case .enableBackgroundSync:
                await enableBackgroundSync()
            case .dismissError:
                state.error = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func checkHealthKitAvailability() async {
        state.isHealthKitAvailable = healthKitService.isHealthDataAvailable()
        
        if state.isHealthKitAvailable {
            // Проверяем разрешения (это можно сделать проверкой авторизации для конкретного типа)
            await checkPermissions()
        }
    }
    
    @MainActor
    private func checkPermissions() async {
        // Простая проверка - попробуем загрузить данные
        do {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let dateRange = DateInterval(start: yesterday, end: Date())
            
            _ = try await healthKitService.fetchStepsData(for: dateRange)
            state.hasPermissions = true
        } catch {
            state.hasPermissions = false
        }
    }
    
    @MainActor
    private func requestPermissions() async {
        state.isLoading = true
        
        do {
            try await healthKitService.requestPermissions()
            state.hasPermissions = true
            state.showingPermissionSheet = false
            
            // Автоматически загружаем данные после получения разрешений
            await loadHealthData()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .permission("HealthKit permissions"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func syncTodayData() async {
        guard state.hasPermissions else { return }
        
        state.isSyncing = true
        
        do {
            try await healthKitService.syncTodayData()
            await loadTodayHealthData()
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .sync("HealthKit sync"))
        }
        
        state.isSyncing = false
    }
    
    @MainActor
    private func loadHealthData() async {
        guard state.hasPermissions else { return }
        
        state.isLoading = true
        
        do {
            await loadTodayHealthData()
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading health data"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func loadTodayHealthData() async {
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        let dateRange = DateInterval(start: startOfDay, end: endOfDay)
        
        var healthData: [HealthData] = []
        
        do {
            for healthType in state.selectedHealthTypes {
                switch healthType {
                case .steps:
                    let steps = try await healthKitService.fetchStepsData(for: dateRange)
                    healthData.append(contentsOf: steps)
                case .sleepDuration:
                    let sleep = try await healthKitService.fetchSleepData(for: dateRange)
                    healthData.append(contentsOf: sleep)
                case .heartRate:
                    let heartRate = try await healthKitService.fetchHeartRateData(for: dateRange)
                    healthData.append(contentsOf: heartRate)
                case .activeEnergyBurned:
                    let energy = try await healthKitService.fetchActiveEnergyData(for: dateRange)
                    healthData.append(contentsOf: energy)
                case .exerciseTime:
                    let exercise = try await healthKitService.fetchExerciseTimeData(for: dateRange)
                    healthData.append(contentsOf: exercise)
                case .mindfulMinutes:
                    let mindfulness = try await healthKitService.fetchMindfulnessData(for: dateRange)
                    healthData.append(contentsOf: mindfulness)
                case .weight:
                    let weight = try await healthKitService.fetchWeightData(for: dateRange)
                    healthData.append(contentsOf: weight)
                case .waterIntake:
                    let water = try await healthKitService.fetchWaterIntakeData(for: dateRange)
                    healthData.append(contentsOf: water)
                case .mood, .screenTime:
                    // Эти типы требуют специальной обработки или не поддерживаются HealthKit
                    break
                }
            }
            
            state.todayHealthData = healthData.sorted { $0.date > $1.date }
            
        } catch {
            throw error
        }
    }
    
    @MainActor
    private func loadCorrelations() async {
        guard let habit = state.selectedHabit, state.hasPermissions else {
            state.healthCorrelations = []
            state.healthInsights = []
            return
        }
        
        state.isLoading = true
        
        do {
            async let correlations = healthKitService.calculateHabitHealthCorrelations(habit)
            async let insights = healthKitService.getHealthInsights(for: habit)
            
            state.healthCorrelations = try await correlations
            state.healthInsights = try await insights
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading health correlations"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func enableBackgroundSync() async {
        guard state.hasPermissions else { return }
        
        do {
            let typesToSync = Array(state.selectedHealthTypes)
            try await healthKitService.enableBackgroundDelivery(for: typesToSync)
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .system("Background sync setup"))
        }
    }
}

// MARK: - Extensions

extension HealthIntegrationViewModel {
    
    /// Проверяет, настроена ли интеграция
    var isHealthIntegrationSetup: Bool {
        return state.isHealthKitAvailable && state.hasPermissions
    }
    
    /// Проверяет, есть ли данные для отображения
    var hasHealthData: Bool {
        return !state.todayHealthData.isEmpty || !state.healthCorrelations.isEmpty
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        return !state.isLoading && !hasHealthData && isHealthIntegrationSetup
    }
    
    /// Получает сегодняшние метрики для отображения
    var todayMetrics: [HealthMetric] {
        return state.todayHealthData.map { healthData in
            HealthMetric(
                type: healthData.type,
                value: healthData.value,
                unit: healthData.unit,
                isNormal: healthData.isWithinNormalRange,
                source: healthData.source
            )
        }
    }
    
    /// Получает сильные корреляции для отображения
    var significantCorrelations: [HabitHealthCorrelation] {
        return state.healthCorrelations.filter { correlation in
            correlation.correlationStrength != .negligible && correlation.confidenceLevel > 0.6
        }.sorted { abs($0.correlationScore) > abs($1.correlationScore) }
    }
    
    /// Получает высокоуверенные инсайты
    var highConfidenceInsights: [HealthInsight] {
        return state.healthInsights.filter { $0.confidence > 0.7 }
    }
    
    /// Получает процент настройки интеграции
    var setupProgress: Double {
        var progress = 0.0
        
        if state.isHealthKitAvailable { progress += 0.25 }
        if state.hasPermissions { progress += 0.5 }
        if !state.selectedHealthTypes.isEmpty { progress += 0.25 }
        
        return progress
    }
    
    /// Получает статус интеграции в виде текста
    var integrationStatus: String {
        if !state.isHealthKitAvailable {
            return "HealthKit недоступен"
        } else if !state.hasPermissions {
            return "Нужны разрешения"
        } else if state.selectedHealthTypes.isEmpty {
            return "Выберите типы данных"
        } else {
            return "Настроено"
        }
    }
    
    /// Получает цвет статуса интеграции
    var integrationStatusColor: Color {
        if setupProgress >= 1.0 {
            return .green
        } else if setupProgress >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// Получает доступные типы данных для выбора
    var availableHealthTypes: [HealthDataType] {
        return HealthDataType.allCases.filter { $0.healthKitIdentifier != nil }
    }
    
    /// Получает форматированный диапазон дат
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        return "\(formatter.string(from: state.selectedDateRange.start)) - \(formatter.string(from: state.selectedDateRange.end))"
    }
    
    /// Получает краткую статистику по корреляциям
    var correlationSummary: CorrelationSummary? {
        guard !state.healthCorrelations.isEmpty else { return nil }
        
        let strongCorrelations = state.healthCorrelations.filter { $0.correlationStrength == .strong || $0.correlationStrength == .veryStrong }
        let positiveCorrelations = state.healthCorrelations.filter { $0.correlationDirection == .positive }
        let averageConfidence = state.healthCorrelations.reduce(0.0) { $0 + $1.confidenceLevel } / Double(state.healthCorrelations.count)
        
        return CorrelationSummary(
            totalCorrelations: state.healthCorrelations.count,
            strongCorrelations: strongCorrelations.count,
            positiveCorrelations: positiveCorrelations.count,
            averageConfidence: averageConfidence
        )
    }
}

// MARK: - Supporting Types

enum HealthTab: CaseIterable, Hashable {
    case overview
    case metrics
    case correlations
    case insights
    case settings
    
    var title: String {
        switch self {
        case .overview:
            return "Обзор"
        case .metrics:
            return "Метрики"
        case .correlations:
            return "Корреляции"
        case .insights:
            return "Инсайты"
        case .settings:
            return "Настройки"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "heart.fill"
        case .metrics:
            return "chart.bar.fill"
        case .correlations:
            return "link"
        case .insights:
            return "lightbulb.fill"
        case .settings:
            return "gear"
        }
    }
}

struct HealthMetric {
    let type: HealthDataType
    let value: Double
    let unit: String
    let isNormal: Bool
    let source: String?
    
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = type == .weight ? 1 : 0
        
        guard let formattedNumber = formatter.string(from: NSNumber(value: value)) else {
            return "\(value) \(unit)"
        }
        
        return "\(formattedNumber) \(unit)"
    }
    
    var color: Color {
        return isNormal ? .green : .orange
    }
}

struct CorrelationSummary {
    let totalCorrelations: Int
    let strongCorrelations: Int
    let positiveCorrelations: Int
    let averageConfidence: Double
    
    var formattedAverageConfidence: String {
        return "\(Int(averageConfidence * 100))%"
    }
    
    var strongCorrelationRate: Double {
        return totalCorrelations > 0 ? Double(strongCorrelations) / Double(totalCorrelations) : 0.0
    }
    
    var positiveCorrelationRate: Double {
        return totalCorrelations > 0 ? Double(positiveCorrelations) / Double(totalCorrelations) : 0.0
    }
} 