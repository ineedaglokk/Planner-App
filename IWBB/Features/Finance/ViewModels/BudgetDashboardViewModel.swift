import Foundation
import SwiftUI
import Combine

@Observable
final class BudgetDashboardViewModel {
    
    // MARK: - Services
    private let budgetingService: BudgetingServiceProtocol
    private let insightsGenerationService: InsightsGenerationServiceProtocol
    private let forecastingService: ForecastingServiceProtocol
    
    // MARK: - Published Properties
    var budgets: [Budget] = []
    var selectedBudget: Budget?
    var budgetPerformance: BudgetPerformanceAnalysis?
    var monthlyOverview: MonthlyBudgetOverview?
    var recommendations: [BudgetRecommendation] = []
    var optimizations: [BudgetOptimization] = []
    var trends: [BudgetTrend] = []
    var categoryBreakdown: [CategoryBreakdown] = []
    var alerts: [BudgetAlert] = []
    
    // MARK: - UI State
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var showError = false
    var selectedTimeframe: BudgetTimeframe = .current
    var showSettings = false
    var showRecommendationDetail: BudgetRecommendation?
    
    // MARK: - Chart Data
    var performanceChartData: [BudgetPerformanceDataPoint] = []
    var categoryChartData: [CategorySpendingDataPoint] = []
    var trendChartData: [TrendDataPoint] = []
    var forecastChartData: [ForecastDataPoint] = []
    
    // MARK: - Configuration
    private let refreshInterval: TimeInterval = 300 // 5 minutes
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        budgetingService: BudgetingServiceProtocol,
        insightsGenerationService: InsightsGenerationServiceProtocol,
        forecastingService: ForecastingServiceProtocol
    ) {
        self.budgetingService = budgetingService
        self.insightsGenerationService = insightsGenerationService
        self.forecastingService = forecastingService
        
        setupAutoRefresh()
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadBudgets() }
                group.addTask { await self.loadMonthlyOverview() }
                group.addTask { await self.loadRecommendations() }
                group.addTask { await self.loadAlerts() }
            }
            
            if let firstBudget = budgets.first {
                await selectBudget(firstBudget)
            }
            
        } catch {
            await handleError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }
    
    @MainActor
    func selectBudget(_ budget: Budget) async {
        selectedBudget = budget
        
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadBudgetPerformance(for: budget) }
                group.addTask { await self.loadOptimizations(for: budget) }
                group.addTask { await self.loadTrends(for: budget) }
                group.addTask { await self.loadCategoryBreakdown(for: budget) }
                group.addTask { await self.loadChartData(for: budget) }
            }
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func changeBudgetTimeframe(_ timeframe: BudgetTimeframe) async {
        selectedTimeframe = timeframe
        
        if let budget = selectedBudget {
            await selectBudget(budget)
        }
    }
    
    @MainActor
    func applyRecommendation(_ recommendation: BudgetRecommendation) async {
        do {
            switch recommendation.type {
            case .adjustLimit:
                try await adjustBudgetLimit(recommendation)
            case .reallocate:
                try await reallocatebudget(recommendation)
            case .optimize:
                try await optimizeBudget(recommendation)
            }
            
            // Перезагружаем данные после применения рекомендации
            await refresh()
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func createBudget(name: String, limit: Decimal, period: BudgetPeriod, category: Category?) async {
        do {
            let budget = Budget(
                name: name,
                limit: limit,
                period: period,
                category: category
            )
            
            try await budgetingService.createBudget(budget)
            await refresh()
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func updateBudget(_ budget: Budget) async {
        do {
            try await budgetingService.updateBudget(budget)
            await refresh()
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func deleteBudget(_ budget: Budget) async {
        do {
            try await budgetingService.deleteBudget(budget.id)
            await refresh()
            
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Computed Properties
    
    var totalBudgetAmount: Decimal {
        budgets.reduce(0) { $0 + $1.limit }
    }
    
    var totalSpentAmount: Decimal {
        budgets.reduce(0) { $0 + $1.spent }
    }
    
    var totalRemainingAmount: Decimal {
        budgets.reduce(0) { $0 + $1.remaining }
    }
    
    var overallUtilization: Double {
        guard totalBudgetAmount > 0 else { return 0 }
        return Double(totalSpentAmount / totalBudgetAmount)
    }
    
    var criticalBudgets: [Budget] {
        budgets.filter { $0.utilizationPercentage > 0.9 }
    }
    
    var performingBudgets: [Budget] {
        budgets.filter { $0.utilizationPercentage <= 0.8 }
    }
    
    var hasAnyBudgets: Bool {
        !budgets.isEmpty
    }
    
    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: Date())
    }
    
    // MARK: - Private Methods
    
    private func loadBudgets() async {
        do {
            let fetchedBudgets = try await budgetingService.getBudgets(
                period: selectedTimeframe.dateInterval
            )
            
            await MainActor.run {
                self.budgets = fetchedBudgets
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadBudgetPerformance(for budget: Budget) async {
        do {
            let performance = try await budgetingService.analyzeBudgetPerformance(
                budget,
                period: selectedTimeframe.dateInterval
            )
            
            await MainActor.run {
                self.budgetPerformance = performance
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadMonthlyOverview() async {
        do {
            let overview = try await generateMonthlyOverview()
            
            await MainActor.run {
                self.monthlyOverview = overview
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadRecommendations() async {
        do {
            var allRecommendations: [BudgetRecommendation] = []
            
            for budget in budgets {
                let budgetRecommendations = try await budgetingService.generateRecommendations(budget)
                allRecommendations.append(contentsOf: budgetRecommendations)
            }
            
            await MainActor.run {
                self.recommendations = allRecommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadOptimizations(for budget: Budget) async {
        do {
            let optimizations = try await budgetingService.identifyOptimizations(budget)
            
            await MainActor.run {
                self.optimizations = optimizations
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadTrends(for budget: Budget) async {
        do {
            let trends = try await budgetingService.analyzeTrends(
                budget,
                period: selectedTimeframe.dateInterval
            )
            
            await MainActor.run {
                self.trends = trends
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadCategoryBreakdown(for budget: Budget) async {
        do {
            let breakdown = try await budgetingService.getCategoryBreakdown(
                budget,
                period: selectedTimeframe.dateInterval
            )
            
            await MainActor.run {
                self.categoryBreakdown = breakdown
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadAlerts() async {
        do {
            var allAlerts: [BudgetAlert] = []
            
            for budget in budgets {
                let budgetAlerts = try await budgetingService.checkAlerts(budget)
                allAlerts.append(contentsOf: budgetAlerts)
            }
            
            await MainActor.run {
                self.alerts = allAlerts.sorted { $0.severity.rawValue > $1.severity.rawValue }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadChartData(for budget: Budget) async {
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadPerformanceChartData(for: budget) }
                group.addTask { await self.loadCategoryChartData(for: budget) }
                group.addTask { await self.loadTrendChartData(for: budget) }
                group.addTask { await self.loadForecastChartData(for: budget) }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadPerformanceChartData(for budget: Budget) async {
        do {
            let performanceData = try await budgetingService.getPerformanceHistory(
                budget,
                period: selectedTimeframe.dateInterval
            )
            
            let chartData = performanceData.map { performance in
                BudgetPerformanceDataPoint(
                    date: performance.date,
                    budgeted: performance.budgetedAmount,
                    actual: performance.actualAmount,
                    utilization: performance.utilization
                )
            }
            
            await MainActor.run {
                self.performanceChartData = chartData
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadCategoryChartData(for budget: Budget) async {
        do {
            let categoryData = categoryBreakdown.map { breakdown in
                CategorySpendingDataPoint(
                    category: breakdown.category,
                    amount: breakdown.amount,
                    percentage: breakdown.percentage,
                    color: breakdown.category.color
                )
            }
            
            await MainActor.run {
                self.categoryChartData = categoryData
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadTrendChartData(for budget: Budget) async {
        do {
            let trendData = trends.map { trend in
                TrendDataPoint(
                    date: trend.date,
                    value: trend.value,
                    type: trend.type,
                    direction: trend.direction
                )
            }
            
            await MainActor.run {
                self.trendChartData = trendData
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadForecastChartData(for budget: Budget) async {
        do {
            let forecast = try await forecastingService.forecastBudgetPerformance(
                budget,
                horizon: .month
            )
            
            let forecastData = forecast.categoryProjections.map { projection in
                ForecastDataPoint(
                    date: Date(),
                    predictedAmount: projection.projectedSpending,
                    confidence: projection.riskLevel == .low ? 0.9 : 0.7,
                    category: projection.category.name
                )
            }
            
            await MainActor.run {
                self.forecastChartData = forecastData
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func generateMonthlyOverview() async throws -> MonthlyBudgetOverview {
        let currentMonth = Calendar.current.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), duration: 2592000)
        
        let monthlyBudgets = budgets.filter { budget in
            budget.period == .monthly
        }
        
        let totalMonthlyBudget = monthlyBudgets.reduce(0) { $0 + $1.limit }
        let totalMonthlySpent = monthlyBudgets.reduce(0) { $0 + $1.spent }
        let totalMonthlyRemaining = totalMonthlyBudget - totalMonthlySpent
        
        let averageDailySpending = totalMonthlySpent / Decimal(Calendar.current.component(.day, from: Date()))
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: currentMonth.end).day ?? 0
        let projectedSpending = averageDailySpending * Decimal(daysRemaining)
        
        return MonthlyBudgetOverview(
            period: currentMonth,
            totalBudget: totalMonthlyBudget,
            totalSpent: totalMonthlySpent,
            totalRemaining: totalMonthlyRemaining,
            averageDailySpending: averageDailySpending,
            projectedEndOfMonthSpending: totalMonthlySpent + projectedSpending,
            projectedOverage: max(0, (totalMonthlySpent + projectedSpending) - totalMonthlyBudget),
            budgetUtilization: totalMonthlyBudget > 0 ? Double(totalMonthlySpent / totalMonthlyBudget) : 0,
            daysRemaining: daysRemaining,
            categoriesCount: monthlyBudgets.count,
            overdueCount: monthlyBudgets.filter { $0.spent > $1.limit }.count
        )
    }
    
    private func adjustBudgetLimit(_ recommendation: BudgetRecommendation) async throws {
        guard let budget = budgets.first(where: { $0.id == recommendation.budgetId }),
              let newLimit = recommendation.suggestedAmount else {
            throw BudgetError.invalidRecommendation
        }
        
        budget.limit = newLimit
        try await budgetingService.updateBudget(budget)
    }
    
    private func reallocatebudget(_ recommendation: BudgetRecommendation) async throws {
        // Реализация перераспределения бюджета
        // В зависимости от типа рекомендации
    }
    
    private func optimizeBudget(_ recommendation: BudgetRecommendation) async throws {
        // Реализация оптимизации бюджета
        // В зависимости от типа рекомендации
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await self.refresh()
            }
        }
    }
    
    @MainActor
    private func handleError(_ error: Error) async {
        let budgetError = error as? BudgetError ?? BudgetError.unknown(error.localizedDescription)
        errorMessage = budgetError.localizedDescription
        showError = true
    }
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum BudgetTimeframe: String, CaseIterable {
    case current = "current"
    case lastMonth = "lastMonth"
    case last3Months = "last3Months"
    case lastYear = "lastYear"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .current: return "Текущий период"
        case .lastMonth: return "Прошлый месяц"
        case .last3Months: return "Последние 3 месяца"
        case .lastYear: return "Последний год"
        case .custom: return "Произвольный период"
        }
    }
    
    var dateInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .current:
            return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return calendar.dateInterval(of: .month, for: lastMonth)
        case .last3Months:
            let startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return DateInterval(start: startDate, end: now)
        case .lastYear:
            let startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return DateInterval(start: startDate, end: now)
        case .custom:
            return nil
        }
    }
}

struct MonthlyBudgetOverview {
    let period: DateInterval
    let totalBudget: Decimal
    let totalSpent: Decimal
    let totalRemaining: Decimal
    let averageDailySpending: Decimal
    let projectedEndOfMonthSpending: Decimal
    let projectedOverage: Decimal
    let budgetUtilization: Double
    let daysRemaining: Int
    let categoriesCount: Int
    let overdueCount: Int
    
    var isOnTrack: Bool {
        projectedOverage <= 0
    }
    
    var healthStatus: BudgetHealthStatus {
        switch budgetUtilization {
        case 0...0.6: return .excellent
        case 0.6...0.8: return .good
        case 0.8...0.95: return .warning
        default: return .critical
        }
    }
}

enum BudgetHealthStatus {
    case excellent
    case good
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .excellent: return "Отличное"
        case .good: return "Хорошее"
        case .warning: return "Внимание"
        case .critical: return "Критическое"
        }
    }
}

// MARK: - Chart Data Structures

struct BudgetPerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let budgeted: Decimal
    let actual: Decimal
    let utilization: Double
}

struct CategorySpendingDataPoint: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let percentage: Double
    let color: String
}

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Decimal
    let type: TrendType
    let direction: TrendDirection
}

struct ForecastDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let predictedAmount: Decimal
    let confidence: Double
    let category: String
}

enum TrendType {
    case spending
    case utilization
    case efficiency
}

enum TrendDirection {
    case up
    case down
    case stable
}

// MARK: - Error Types

enum BudgetError: LocalizedError {
    case invalidRecommendation
    case budgetNotFound
    case insufficientData
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRecommendation:
            return "Неверная рекомендация по бюджету"
        case .budgetNotFound:
            return "Бюджет не найден"
        case .insufficientData:
            return "Недостаточно данных для анализа"
        case .networkError:
            return "Ошибка сети"
        case .unknown(let message):
            return message
        }
    }
} 
} 