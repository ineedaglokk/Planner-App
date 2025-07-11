import Foundation
import SwiftUI

// MARK: - Finance Overview ViewModel

@Observable
final class FinanceOverviewViewModel {
    
    // MARK: - State
    
    struct State {
        var currentBalance: FinanceBalance?
        var previousBalance: FinanceBalance?
        var monthlyTransactions: [Transaction] = []
        var topExpenseCategories: [CategorySummary] = []
        var topIncomeCategories: [CategorySummary] = []
        var balanceTrend: [BalancePoint] = []
        var budgets: [Budget] = []
        var budgetProgress: [BudgetProgress] = []
        var insights: [FinanceInsight] = []
        
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var error: AppError?
        
        var selectedPeriod: TimePeriod = .currentMonth
        var selectedCurrency: String = "RUB"
        var showingCharts: Bool = false
        var selectedChartType: ChartType = .balance
        
        // Quick Stats
        var todaySpending: Decimal = 0
        var weekSpending: Decimal = 0
        var monthlyBudgetUsage: Double = 0
        var savingsRate: Double = 0
    }
    
    // MARK: - Input
    
    enum Input {
        case loadData
        case refresh
        case periodChanged(TimePeriod)
        case currencyChanged(String)
        case chartTypeChanged(ChartType)
        case toggleCharts
        case retryLoadData
        case markTransactionComplete(Transaction)
        case deleteTransaction(Transaction)
        case showTransactionDetail(Transaction)
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Services
    private let financeService: FinanceServiceProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let currencyService: CurrencyServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    init(
        financeService: FinanceServiceProtocol,
        transactionRepository: TransactionRepositoryProtocol,
        currencyService: CurrencyServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol
    ) {
        self.financeService = financeService
        self.transactionRepository = transactionRepository
        self.currencyService = currencyService
        self.errorHandlingService = errorHandlingService
        
        Task {
            await initializeAsync()
        }
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadData:
                await loadFinanceData()
                
            case .refresh:
                await refreshData()
                
            case .periodChanged(let period):
                state.selectedPeriod = period
                await loadFinanceData()
                
            case .currencyChanged(let currency):
                state.selectedCurrency = currency
                await loadFinanceData()
                
            case .chartTypeChanged(let chartType):
                state.selectedChartType = chartType
                await loadChartData(for: chartType)
                
            case .toggleCharts:
                state.showingCharts.toggle()
                if state.showingCharts {
                    await loadChartData(for: state.selectedChartType)
                }
                
            case .retryLoadData:
                state.error = nil
                await loadFinanceData()
                
            case .markTransactionComplete(let transaction):
                await markTransactionComplete(transaction)
                
            case .deleteTransaction(let transaction):
                await deleteTransaction(transaction)
                
            case .showTransactionDetail(let transaction):
                await showTransactionDetail(transaction)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeAsync() async {
        await MainActor.run {
            state.isLoading = true
        }
        
        do {
            // Load base currency
            let baseCurrency = try await currencyService.getBaseCurrency()
            await MainActor.run {
                state.selectedCurrency = baseCurrency.code
            }
            
            await loadFinanceData()
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadFinanceData() async {
        await MainActor.run {
            state.isLoading = true
            state.error = nil
        }
        
        do {
            let period = state.selectedPeriod.dateInterval
            
            // Load data in parallel
            async let currentBalance = financeService.calculateBalance(for: period)
            async let previousBalance = loadPreviousPeriodBalance(period)
            async let transactions = transactionRepository.fetchTransactions(
                from: period.start,
                to: period.end
            )
            async let topExpenseCategories = transactionRepository.getTopCategories(
                for: period,
                type: .expense
            )
            async let topIncomeCategories = transactionRepository.getTopCategories(
                for: period,
                type: .income
            )
            async let budgets = loadBudgetsForPeriod(period)
            async let insights = financeService.getSpendingInsights(for: period)
            
            // Await all results
            let currentBalanceResult = try await currentBalance
            let previousBalanceResult = try await previousBalance
            let transactionsResult = try await transactions
            let expenseCategoriesResult = try await topExpenseCategories
            let incomeCategoriesResult = try await topIncomeCategories
            let budgetsResult = try await budgets
            let insightsResult = try await insights
            
            // Load budget progress
            var budgetProgressList: [BudgetProgress] = []
            for budget in budgetsResult {
                let progress = try await financeService.getBudgetProgress(budget)
                budgetProgressList.append(progress)
            }
            
            // Calculate quick stats
            let quickStats = try await calculateQuickStats()
            
            await MainActor.run {
                state.currentBalance = currentBalanceResult
                state.previousBalance = previousBalanceResult
                state.monthlyTransactions = transactionsResult
                state.topExpenseCategories = expenseCategoriesResult
                state.topIncomeCategories = incomeCategoriesResult
                state.budgets = budgetsResult
                state.budgetProgress = budgetProgressList
                state.insights = insightsResult
                
                state.todaySpending = quickStats.todaySpending
                state.weekSpending = quickStats.weekSpending
                state.monthlyBudgetUsage = quickStats.monthlyBudgetUsage
                state.savingsRate = quickStats.savingsRate
                
                state.isLoading = false
                state.isRefreshing = false
            }
            
        } catch {
            await handleError(error)
            await MainActor.run {
                state.isLoading = false
                state.isRefreshing = false
            }
        }
    }
    
    private func refreshData() async {
        await MainActor.run {
            state.isRefreshing = true
        }
        
        // Update exchange rates
        do {
            try await currencyService.updateExchangeRates()
        } catch {
            // Exchange rate update failure shouldn't block the refresh
            print("Failed to update exchange rates: \(error)")
        }
        
        await loadFinanceData()
    }
    
    private func loadPreviousPeriodBalance(_ currentPeriod: DateInterval) async throws -> FinanceBalance {
        let calendar = Calendar.current
        let duration = currentPeriod.duration
        let previousStart = calendar.date(byAdding: .second, value: -Int(duration), to: currentPeriod.start) ?? currentPeriod.start
        let previousPeriod = DateInterval(start: previousStart, duration: duration)
        
        return try await financeService.calculateBalance(for: previousPeriod)
    }
    
    private func loadBudgetsForPeriod(_ period: DateInterval) async throws -> [Budget] {
        // This would be implemented with a proper budget repository
        // For now, return empty array
        return []
    }
    
    private func calculateQuickStats() async throws -> QuickStats {
        let calendar = Calendar.current
        let now = Date()
        
        // Today spending
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let todayTransactions = try await transactionRepository.fetchTransactions(
            from: todayStart,
            to: todayEnd,
            type: .expense
        )
        let todaySpending = todayTransactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        // Week spending
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? todayStart
        let weekTransactions = try await transactionRepository.fetchTransactions(
            from: weekStart,
            to: now,
            type: .expense
        )
        let weekSpending = weekTransactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        // Monthly budget usage
        let monthlyBudgetUsage = calculateMonthlyBudgetUsage()
        
        // Savings rate
        let savingsRate = state.currentBalance?.income ?? 0 > 0 ?
            Double((state.currentBalance?.balance ?? 0) / (state.currentBalance?.income ?? 1)) * 100 : 0
        
        return QuickStats(
            todaySpending: todaySpending,
            weekSpending: weekSpending,
            monthlyBudgetUsage: monthlyBudgetUsage,
            savingsRate: savingsRate
        )
    }
    
    private func calculateMonthlyBudgetUsage() -> Double {
        guard !state.budgetProgress.isEmpty else { return 0 }
        
        let totalProgress = state.budgetProgress.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(state.budgetProgress.count)
    }
    
    private func loadChartData(for chartType: ChartType) async {
        let period = state.selectedPeriod.dateInterval
        
        do {
            switch chartType {
            case .balance:
                let trendData = try await transactionRepository.getTrendData(for: period)
                await MainActor.run {
                    state.balanceTrend = trendData
                }
                
            case .expenses:
                // Load expense trend data
                break
                
            case .categories:
                // Already loaded in topExpenseCategories
                break
                
            case .budget:
                // Already loaded in budgetProgress
                break
            }
        } catch {
            await handleError(error)
        }
    }
    
    private func markTransactionComplete(_ transaction: Transaction) async {
        do {
            // If this was a pending transaction, mark it as complete
            transaction.updateTimestamp()
            try await transactionRepository.save(transaction)
            
            // Refresh data
            await loadFinanceData()
            
        } catch {
            await handleError(error)
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) async {
        do {
            try await transactionRepository.delete(transaction)
            
            // Refresh data
            await loadFinanceData()
            
        } catch {
            await handleError(error)
        }
    }
    
    private func showTransactionDetail(_ transaction: Transaction) async {
        // This would trigger navigation to transaction detail
        // Implementation depends on navigation system
    }
    
    private func handleError(_ error: Error) async {
        let appError = AppError.from(error)
        
        await MainActor.run {
            state.error = appError
        }
        
        await errorHandlingService.handle(appError)
    }
}

// MARK: - Supporting Types

enum TimePeriod: String, CaseIterable {
    case currentWeek = "current_week"
    case currentMonth = "current_month"
    case currentQuarter = "current_quarter"
    case currentYear = "current_year"
    case last30Days = "last_30_days"
    case last3Months = "last_3_months"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .currentWeek: return "Эта неделя"
        case .currentMonth: return "Этот месяц"
        case .currentQuarter: return "Этот квартал"
        case .currentYear: return "Этот год"
        case .last30Days: return "Последние 30 дней"
        case .last3Months: return "Последние 3 месяца"
        case .custom: return "Произвольный"
        }
    }
    
    var dateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .currentWeek:
            return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 0)
            
        case .currentMonth:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
            
        case .currentQuarter:
            let month = calendar.component(.month, for: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            let startDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: quarterStartMonth,
                day: 1
            )) ?? now
            let endDate = calendar.date(byAdding: .month, value: 3, to: startDate) ?? now
            return DateInterval(start: startDate, end: endDate)
            
        case .currentYear:
            return calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: now, duration: 0)
            
        case .last30Days:
            let startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return DateInterval(start: startDate, end: now)
            
        case .last3Months:
            let startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return DateInterval(start: startDate, end: now)
            
        case .custom:
            return DateInterval(start: now, duration: 0)
        }
    }
}

enum ChartType: String, CaseIterable {
    case balance = "balance"
    case expenses = "expenses"
    case categories = "categories"
    case budget = "budget"
    
    var displayName: String {
        switch self {
        case .balance: return "Баланс"
        case .expenses: return "Расходы"
        case .categories: return "Категории"
        case .budget: return "Бюджеты"
        }
    }
    
    var icon: String {
        switch self {
        case .balance: return "chart.line.uptrend.xyaxis"
        case .expenses: return "chart.bar.fill"
        case .categories: return "chart.pie.fill"
        case .budget: return "gauge"
        }
    }
}

struct QuickStats {
    let todaySpending: Decimal
    let weekSpending: Decimal
    let monthlyBudgetUsage: Double
    let savingsRate: Double
}

// MARK: - Computed Properties

extension FinanceOverviewViewModel.State {
    
    var hasData: Bool {
        return currentBalance != nil || !monthlyTransactions.isEmpty
    }
    
    var isEmpty: Bool {
        return !hasData && !isLoading
    }
    
    var balanceChangePercentage: Double? {
        guard let current = currentBalance,
              let previous = previousBalance,
              previous.balance != 0 else { return nil }
        
        let change = current.balance - previous.balance
        return Double(change / previous.balance) * 100
    }
    
    var isBalanceIncreasing: Bool {
        return (balanceChangePercentage ?? 0) > 0
    }
    
    var totalBudgetUsage: Double {
        guard !budgetProgress.isEmpty else { return 0 }
        
        let totalProgress = budgetProgress.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(budgetProgress.count)
    }
    
    var overBudgetCount: Int {
        return budgetProgress.filter { $0.progress > 1.0 }.count
    }
    
    var hasInsights: Bool {
        return !insights.isEmpty
    }
    
    var criticalInsights: [FinanceInsight] {
        return insights.filter { $0.impact == .critical || $0.impact == .high }
    }
    
    var formattedCurrentBalance: String {
        guard let balance = currentBalance else { return "0" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        formatter.locale = selectedCurrency == "RUB" ? Locale(identifier: "ru_RU") : Locale.current
        
        return formatter.string(from: NSDecimalNumber(decimal: balance.balance)) ?? "\(balance.balance)"
    }
}

// MARK: - View Model Factory

extension FinanceOverviewViewModel {
    
    static func create(with services: ServiceContainerProtocol) -> FinanceOverviewViewModel {
        return FinanceOverviewViewModel(
            financeService: services.financeService,
            transactionRepository: services.transactionRepository,
            currencyService: services.currencyService,
            errorHandlingService: services.errorHandlingService
        )
    }
} 