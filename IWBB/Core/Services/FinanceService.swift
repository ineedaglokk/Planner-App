import Foundation
import SwiftData

// MARK: - Finance Service Protocol

protocol FinanceServiceProtocol {
    // MARK: - Balance & Analytics
    func calculateBalance(for period: DateInterval) async throws -> FinanceBalance
    func generateFinancialReport(for period: DateInterval) async throws -> FinancialReport
    func predictFutureBalance(days: Int) async throws -> [BalancePrediction]
    func getSpendingTrend(for period: DateInterval) async throws -> SpendingTrend
    
    // MARK: - Budget Management
    func createBudget(_ budget: Budget) async throws
    func updateBudget(_ budget: Budget) async throws
    func checkBudgetStatus(_ budget: Budget) async throws -> BudgetStatus
    func getBudgetProgress(_ budget: Budget) async throws -> BudgetProgress
    func sendBudgetNotificationIfNeeded(_ budget: Budget) async throws
    
    // MARK: - Currency Operations
    func getCurrencyRates() async throws -> [String: Decimal]
    func convertAmount(_ amount: Decimal, from: String, to: String) async throws -> Decimal
    func updateExchangeRates() async throws
    func getBaseCurrency() async throws -> Currency
    
    // MARK: - Transaction Processing
    func processTransaction(_ transaction: Transaction) async throws
    func bulkImportTransactions(_ transactions: [Transaction]) async throws
    func categorizeTransaction(_ transaction: Transaction) async throws -> Category?
    func detectDuplicateTransactions(_ transactions: [Transaction]) async throws -> [Transaction]
    
    // MARK: - Insights & Recommendations
    func getSpendingInsights(for period: DateInterval) async throws -> [FinanceInsight]
    func getBudgetRecommendations() async throws -> [BudgetRecommendation]
    func getRecurringTransactionSuggestions() async throws -> [RecurringTransactionSuggestion]
}

// MARK: - Supporting Data Structures

struct FinancialReport {
    let period: DateInterval
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netIncome: Decimal
    let topExpenseCategories: [CategorySummary]
    let topIncomeCategories: [CategorySummary]
    let budgetPerformance: [BudgetProgress]
    let savingsRate: Double
    let expenseGrowth: Double
    let insights: [FinanceInsight]
    let generatedAt: Date
    
    var isPositive: Bool { netIncome >= 0 }
    var expenseToIncomeRatio: Double {
        totalIncome > 0 ? Double(totalExpenses / totalIncome) : 0
    }
}

struct BalancePrediction {
    let date: Date
    let predictedBalance: Decimal
    let confidence: Double
    let factors: [PredictionFactor]
    
    enum PredictionFactor {
        case recurringIncome(Decimal)
        case recurringExpense(Decimal)
        case historicalTrend(Decimal)
        case seasonalPattern(Decimal)
    }
}

struct SpendingTrend {
    let period: DateInterval
    let dailyAverages: [Date: Decimal]
    let weeklyTotals: [Date: Decimal]
    let monthlyTotals: [Date: Decimal]
    let trendDirection: TrendDirection
    let changePercentage: Double
    
    enum TrendDirection {
        case increasing
        case decreasing
        case stable
    }
}

struct BudgetProgress {
    let budget: Budget
    let spent: Decimal
    let remaining: Decimal
    let progress: Double
    let daysRemaining: Int
    let recommendedDailySpending: Decimal
    let isOnTrack: Bool
    let projectedOverrun: Decimal?
}

struct FinanceInsight {
    let type: InsightType
    let title: String
    let description: String
    let impact: ImpactLevel
    let actionable: Bool
    let suggestedActions: [String]
    let relatedCategory: Category?
    
    enum InsightType {
        case overspending
        case unusualExpense
        case savingsOpportunity
        case budgetOptimization
        case incomeVariation
        case expensePattern
    }
    
    enum ImpactLevel {
        case low
        case medium
        case high
        case critical
    }
}

struct BudgetRecommendation {
    let category: Category?
    let recommendedAmount: Decimal
    let currentSpending: Decimal
    let reasoning: String
    let priority: RecommendationPriority
    
    enum RecommendationPriority {
        case low
        case medium
        case high
        case urgent
    }
}

struct RecurringTransactionSuggestion {
    let transaction: Transaction
    let pattern: TransactionRecurringPattern
    let confidence: Double
    let nextOccurrence: Date
    let estimatedSavings: Decimal?
}

// MARK: - Finance Service Implementation

final class FinanceService: FinanceServiceProtocol {
    
    // MARK: - Properties
    
    private let transactionRepository: TransactionRepositoryProtocol
    private let categoryService: CategoryServiceProtocol
    private let currencyService: CurrencyServiceProtocol
    private let dataService: DataServiceProtocol
    private let notificationService: NotificationServiceProtocol
    
    // MARK: - Initialization
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        categoryService: CategoryServiceProtocol,
        currencyService: CurrencyServiceProtocol,
        dataService: DataServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.categoryService = categoryService
        self.currencyService = currencyService
        self.dataService = dataService
        self.notificationService = notificationService
    }
    
    // MARK: - Balance & Analytics
    
    func calculateBalance(for period: DateInterval) async throws -> FinanceBalance {
        let transactions = try await transactionRepository.fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        let income = transactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        let expenses = transactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        // Calculate change from previous period
        let previousPeriod = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -Int(period.duration / 86400), to: period.start) ?? period.start,
            duration: period.duration
        )
        
        let previousBalance = try? await calculateBalanceForPeriod(previousPeriod)
        let changeFromPrevious = previousBalance.map { income - expenses - $0.balance }
        
        return FinanceBalance(
            income: income,
            expenses: expenses,
            period: period,
            transactionCount: transactions.count,
            changeFromPreviousPeriod: changeFromPrevious
        )
    }
    
    private func calculateBalanceForPeriod(_ period: DateInterval) async throws -> FinanceBalance {
        let transactions = try await transactionRepository.fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        let income = transactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        let expenses = transactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        return FinanceBalance(
            income: income,
            expenses: expenses,
            period: period,
            transactionCount: transactions.count
        )
    }
    
    func generateFinancialReport(for period: DateInterval) async throws -> FinancialReport {
        async let balance = calculateBalance(for: period)
        async let topExpenseCategories = transactionRepository.getTopCategories(for: period, type: .expense)
        async let topIncomeCategories = transactionRepository.getTopCategories(for: period, type: .income)
        async let budgets = fetchBudgetsForPeriod(period)
        async let insights = getSpendingInsights(for: period)
        
        let balanceResult = try await balance
        let expenseCategories = try await topExpenseCategories
        let incomeCategories = try await topIncomeCategories
        let budgetList = try await budgets
        let reportInsights = try await insights
        
        // Calculate budget performance
        var budgetPerformance: [BudgetProgress] = []
        for budget in budgetList {
            let progress = try await getBudgetProgress(budget)
            budgetPerformance.append(progress)
        }
        
        // Calculate savings rate
        let savingsRate = balanceResult.income > 0 ? 
            Double((balanceResult.income - balanceResult.expenses) / balanceResult.income) * 100 : 0
        
        // Calculate expense growth (compared to previous period)
        let previousPeriodExpenses = try? await calculateExpensesForPreviousPeriod(period)
        let expenseGrowth = calculateGrowthRate(
            current: balanceResult.expenses,
            previous: previousPeriodExpenses ?? 0
        )
        
        return FinancialReport(
            period: period,
            totalIncome: balanceResult.income,
            totalExpenses: balanceResult.expenses,
            netIncome: balanceResult.balance,
            topExpenseCategories: expenseCategories,
            topIncomeCategories: incomeCategories,
            budgetPerformance: budgetPerformance,
            savingsRate: savingsRate,
            expenseGrowth: expenseGrowth,
            insights: reportInsights,
            generatedAt: Date()
        )
    }
    
    func predictFutureBalance(days: Int) async throws -> [BalancePrediction] {
        let currentBalance = try await transactionRepository.getTotalBalance()
        let recurringTransactions = try await transactionRepository.getRecurringTransactions()
        let historicalData = try await getHistoricalSpendingPattern(days: 90)
        
        var predictions: [BalancePrediction] = []
        var runningBalance = currentBalance
        
        let calendar = Calendar.current
        
        for day in 1...days {
            guard let futureDate = calendar.date(byAdding: .day, value: day, to: Date()) else { continue }
            
            var dayPrediction: Decimal = 0
            var factors: [BalancePrediction.PredictionFactor] = []
            
            // Check for recurring transactions on this day
            for transaction in recurringTransactions {
                if let nextOccurrence = transaction.recurringPattern?.nextDate(from: transaction.date),
                   calendar.isDate(nextOccurrence, inSameDayAs: futureDate) {
                    let impact = transaction.type == .income ? transaction.amount : -transaction.amount
                    dayPrediction += impact
                    
                    if transaction.type == .income {
                        factors.append(.recurringIncome(transaction.amount))
                    } else {
                        factors.append(.recurringExpense(transaction.amount))
                    }
                }
            }
            
            // Apply historical trend
            let weekday = calendar.component(.weekday, from: futureDate)
            let historicalAverage = historicalData[weekday] ?? 0
            dayPrediction += historicalAverage
            factors.append(.historicalTrend(historicalAverage))
            
            runningBalance += dayPrediction
            
            let prediction = BalancePrediction(
                date: futureDate,
                predictedBalance: runningBalance,
                confidence: calculatePredictionConfidence(for: day),
                factors: factors
            )
            
            predictions.append(prediction)
        }
        
        return predictions
    }
    
    func getSpendingTrend(for period: DateInterval) async throws -> SpendingTrend {
        let trendData = try await transactionRepository.getTrendData(for: period)
        
        // Calculate daily averages
        let dailyAverages = Dictionary(uniqueKeysWithValues: trendData.map { ($0.date, $0.expenses) })
        
        // Calculate weekly totals
        let calendar = Calendar.current
        let weeklyGrouped = Dictionary(grouping: trendData) { point in
            calendar.dateInterval(of: .weekOfYear, for: point.date)?.start ?? point.date
        }
        
        let weeklyTotals = weeklyGrouped.mapValues { points in
            points.reduce(Decimal.zero) { $0 + $1.expenses }
        }
        
        // Calculate monthly totals
        let monthlyGrouped = Dictionary(grouping: trendData) { point in
            calendar.dateInterval(of: .month, for: point.date)?.start ?? point.date
        }
        
        let monthlyTotals = monthlyGrouped.mapValues { points in
            points.reduce(Decimal.zero) { $0 + $1.expenses }
        }
        
        // Determine trend direction
        let (trendDirection, changePercentage) = calculateTrendDirection(from: trendData)
        
        return SpendingTrend(
            period: period,
            dailyAverages: dailyAverages,
            weeklyTotals: weeklyTotals,
            monthlyTotals: monthlyTotals,
            trendDirection: trendDirection,
            changePercentage: changePercentage
        )
    }
    
    // MARK: - Budget Management
    
    func createBudget(_ budget: Budget) async throws {
        try budget.validate()
        try await dataService.save(budget)
    }
    
    func updateBudget(_ budget: Budget) async throws {
        try budget.validate()
        budget.updateTimestamp()
        budget.markForSync()
        try await dataService.save(budget)
    }
    
    func checkBudgetStatus(_ budget: Budget) async throws -> BudgetStatus {
        return budget.status
    }
    
    func getBudgetProgress(_ budget: Budget) async throws -> BudgetProgress {
        let calendar = Calendar.current
        let now = Date()
        
        let daysRemaining = max(0, calendar.dateComponents([.day], from: now, to: budget.endDate).day ?? 0)
        let recommendedDailySpending = daysRemaining > 0 ? budget.remaining / Decimal(daysRemaining) : 0
        
        let isOnTrack = budget.progress <= 1.0 && (daysRemaining == 0 || recommendedDailySpending >= 0)
        
        let projectedOverrun: Decimal? = {
            if budget.averageDailySpending > 0 && daysRemaining > 0 {
                let projectedTotal = budget.spent + (budget.averageDailySpending * Decimal(daysRemaining))
                return projectedTotal > budget.limit ? projectedTotal - budget.limit : nil
            }
            return nil
        }()
        
        return BudgetProgress(
            budget: budget,
            spent: budget.spent,
            remaining: budget.remaining,
            progress: budget.progress,
            daysRemaining: daysRemaining,
            recommendedDailySpending: recommendedDailySpending,
            isOnTrack: isOnTrack,
            projectedOverrun: projectedOverrun
        )
    }
    
    func sendBudgetNotificationIfNeeded(_ budget: Budget) async throws {
        guard budget.shouldSendWarning else { return }
        
        let progress = try await getBudgetProgress(budget)
        
        let title = "Предупреждение о бюджете"
        let message: String
        
        if budget.isOverBudget {
            message = "Бюджет '\(budget.name)' превышен на \(budget.formattedSpent)"
        } else {
            let percentage = Int(progress.progress * 100)
            message = "Бюджет '\(budget.name)' использован на \(percentage)%"
        }
        
        await notificationService.scheduleNotification(
            title: title,
            body: message,
            identifier: "budget_warning_\(budget.id.uuidString)",
            category: "BUDGET_WARNING"
        )
        
        budget.markNotificationSent()
        try await dataService.save(budget)
    }
    
    // MARK: - Currency Operations
    
    func getCurrencyRates() async throws -> [String: Decimal] {
        return try await currencyService.getAllExchangeRates()
    }
    
    func convertAmount(_ amount: Decimal, from fromCurrency: String, to toCurrency: String) async throws -> Decimal {
        return try await currencyService.convertAmount(amount, from: fromCurrency, to: toCurrency)
    }
    
    func updateExchangeRates() async throws {
        try await currencyService.updateExchangeRates()
    }
    
    func getBaseCurrency() async throws -> Currency {
        return try await currencyService.getBaseCurrency()
    }
    
    // MARK: - Transaction Processing
    
    func processTransaction(_ transaction: Transaction) async throws {
        // Validate transaction
        try transaction.validate()
        
        // Auto-categorize if no category set
        if transaction.category == nil {
            transaction.category = try await categorizeTransaction(transaction)
        }
        
        // Save transaction
        try await transactionRepository.save(transaction)
        
        // Check if this affects any budgets
        if let category = transaction.category,
           transaction.type == .expense {
            let budgets = try await getBudgetsForCategory(category)
            for budget in budgets {
                try await sendBudgetNotificationIfNeeded(budget)
            }
        }
        
        // Create next recurring transaction if needed
        if transaction.isRecurring,
           let nextTransaction = transaction.createNextRecurringTransaction() {
            try await transactionRepository.save(nextTransaction)
        }
    }
    
    func bulkImportTransactions(_ transactions: [Transaction]) async throws {
        // Detect and filter duplicates
        let duplicates = try await detectDuplicateTransactions(transactions)
        let uniqueTransactions = transactions.filter { transaction in
            !duplicates.contains { $0.id == transaction.id }
        }
        
        // Auto-categorize transactions
        for transaction in uniqueTransactions {
            if transaction.category == nil {
                transaction.category = try await categorizeTransaction(transaction)
            }
        }
        
        // Batch save
        try await transactionRepository.batchSave(uniqueTransactions)
    }
    
    func categorizeTransaction(_ transaction: Transaction) async throws -> Category? {
        return await categoryService.suggestCategory(
            for: transaction.title,
            amount: transaction.amount
        )
    }
    
    func detectDuplicateTransactions(_ transactions: [Transaction]) async throws -> [Transaction] {
        var duplicates: [Transaction] = []
        
        for transaction in transactions {
            // Check for existing transactions with same amount, date, and description
            let existingTransactions = try await transactionRepository.fetchTransactions(
                from: Calendar.current.date(byAdding: .day, value: -1, to: transaction.date),
                to: Calendar.current.date(byAdding: .day, value: 1, to: transaction.date)
            )
            
            let isDuplicate = existingTransactions.contains { existing in
                existing.amount == transaction.amount &&
                existing.type == transaction.type &&
                existing.title == transaction.title &&
                Calendar.current.isDate(existing.date, inSameDayAs: transaction.date)
            }
            
            if isDuplicate {
                duplicates.append(transaction)
            }
        }
        
        return duplicates
    }
    
    // MARK: - Insights & Recommendations
    
    func getSpendingInsights(for period: DateInterval) async throws -> [FinanceInsight] {
        var insights: [FinanceInsight] = []
        
        // Get spending data
        let currentBalance = try await calculateBalance(for: period)
        let previousPeriod = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -Int(period.duration / 86400), to: period.start) ?? period.start,
            duration: period.duration
        )
        let previousBalance = try? await calculateBalance(for: previousPeriod)
        
        // Overspending insight
        if currentBalance.expenses > currentBalance.income {
            insights.append(FinanceInsight(
                type: .overspending,
                title: "Превышение расходов",
                description: "Ваши расходы превышают доходы на \((currentBalance.expenses - currentBalance.income).formatted(.currency(code: "RUB")))",
                impact: .high,
                actionable: true,
                suggestedActions: [
                    "Проанализируйте крупные траты",
                    "Создайте бюджет для контроля расходов",
                    "Найдите возможности для экономии"
                ],
                relatedCategory: nil
            ))
        }
        
        // Expense increase insight
        if let previousBalance = previousBalance {
            let expenseIncrease = currentBalance.expenses - previousBalance.expenses
            let increasePercentage = previousBalance.expenses > 0 ? 
                Double(expenseIncrease / previousBalance.expenses) * 100 : 0
            
            if increasePercentage > 20 {
                insights.append(FinanceInsight(
                    type: .expensePattern,
                    title: "Значительный рост расходов",
                    description: "Расходы выросли на \(Int(increasePercentage))% по сравнению с предыдущим периодом",
                    impact: .medium,
                    actionable: true,
                    suggestedActions: [
                        "Проверьте категории с наибольшим ростом",
                        "Установите бюджетные лимиты",
                        "Отслеживайте необычные траты"
                    ],
                    relatedCategory: nil
                ))
            }
        }
        
        // Category-specific insights
        let topCategories = try await transactionRepository.getTopCategories(for: period, type: .expense)
        
        for categoryStats in topCategories.prefix(3) {
            let categoryPercentage = categoryStats.percentage
            
            if categoryPercentage > 40 {
                insights.append(FinanceInsight(
                    type: .budgetOptimization,
                    title: "Высокие траты в категории",
                    description: "Категория '\(categoryStats.category.name)' составляет \(Int(categoryPercentage))% от всех расходов",
                    impact: .medium,
                    actionable: true,
                    suggestedActions: [
                        "Создайте бюджет для этой категории",
                        "Найдите способы экономии",
                        "Сравните с рекомендованными нормами"
                    ],
                    relatedCategory: categoryStats.category
                ))
            }
        }
        
        return insights
    }
    
    func getBudgetRecommendations() async throws -> [BudgetRecommendation] {
        var recommendations: [BudgetRecommendation] = []
        
        // Get spending data for last 3 months
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        let period = DateInterval(start: startDate, end: endDate)
        
        let topCategories = try await transactionRepository.getTopCategories(for: period, type: .expense)
        
        for categoryStats in topCategories {
            let averageMonthlySpending = categoryStats.totalAmount / 3 // 3 months average
            let recommendedBudget = averageMonthlySpending * 1.1 // Add 10% buffer
            
            let recommendation = BudgetRecommendation(
                category: categoryStats.category,
                recommendedAmount: recommendedBudget,
                currentSpending: averageMonthlySpending,
                reasoning: "На основе среднего расхода за последние 3 месяца с буфером 10%",
                priority: categoryStats.percentage > 20 ? .high : .medium
            )
            
            recommendations.append(recommendation)
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func getRecurringTransactionSuggestions() async throws -> [RecurringTransactionSuggestion] {
        let allTransactions = try await transactionRepository.fetchTransactions()
        var suggestions: [RecurringTransactionSuggestion] = []
        
        // Group transactions by title and amount
        let grouped = Dictionary(grouping: allTransactions) { transaction in
            "\(transaction.title)_\(transaction.amount)"
        }
        
        for (_, transactions) in grouped {
            guard transactions.count >= 3 else { continue }
            
            // Check if transactions occur at regular intervals
            let sortedTransactions = transactions.sorted { $0.date < $1.date }
            
            if let pattern = detectRecurringPattern(in: sortedTransactions) {
                let confidence = calculatePatternConfidence(transactions: sortedTransactions, pattern: pattern)
                
                if confidence > 0.7 {
                    let nextOccurrence = pattern.nextDate(from: sortedTransactions.last?.date ?? Date()) ?? Date()
                    
                    let suggestion = RecurringTransactionSuggestion(
                        transaction: sortedTransactions.first!,
                        pattern: pattern,
                        confidence: confidence,
                        nextOccurrence: nextOccurrence,
                        estimatedSavings: nil
                    )
                    
                    suggestions.append(suggestion)
                }
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Private Helper Methods

private extension FinanceService {
    
    func fetchBudgetsForPeriod(_ period: DateInterval) async throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { budget in
                budget.isActive &&
                budget.startDate <= period.end &&
                budget.endDate >= period.start
            }
        )
        
        return try dataService.fetch(Budget.self, predicate: descriptor.predicate).get()
    }
    
    func getBudgetsForCategory(_ category: Category) async throws -> [Budget] {
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { budget in
                budget.isActive && budget.category?.id == category.id
            }
        )
        
        return try dataService.fetch(Budget.self, predicate: descriptor.predicate).get()
    }
    
    func calculateExpensesForPreviousPeriod(_ period: DateInterval) async throws -> Decimal {
        let previousPeriod = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -Int(period.duration / 86400), to: period.start) ?? period.start,
            duration: period.duration
        )
        
        let balance = try await calculateBalance(for: previousPeriod)
        return balance.expenses
    }
    
    func calculateGrowthRate(current: Decimal, previous: Decimal) -> Double {
        guard previous > 0 else { return 0 }
        return Double((current - previous) / previous) * 100
    }
    
    func getHistoricalSpendingPattern(days: Int) async throws -> [Int: Decimal] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let transactions = try await transactionRepository.fetchTransactions(
            from: startDate,
            to: endDate,
            type: .expense
        )
        
        // Group by weekday
        let groupedByWeekday = Dictionary(grouping: transactions) { transaction in
            calendar.component(.weekday, from: transaction.date)
        }
        
        var averages: [Int: Decimal] = [:]
        
        for (weekday, transactions) in groupedByWeekday {
            let total = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
            let weeksCount = days / 7
            averages[weekday] = weeksCount > 0 ? total / Decimal(weeksCount) : 0
        }
        
        return averages
    }
    
    func calculatePredictionConfidence(for dayOffset: Int) -> Double {
        // Confidence decreases over time
        let baseConfidence = 0.95
        let decayRate = 0.02
        return max(0.3, baseConfidence - (Double(dayOffset) * decayRate))
    }
    
    func calculateTrendDirection(from trendData: [BalancePoint]) -> (SpendingTrend.TrendDirection, Double) {
        guard trendData.count >= 2 else { return (.stable, 0) }
        
        let first = trendData.first!.expenses
        let last = trendData.last!.expenses
        
        let changePercentage = first > 0 ? Double((last - first) / first) * 100 : 0
        
        let direction: SpendingTrend.TrendDirection
        if abs(changePercentage) < 5 {
            direction = .stable
        } else if changePercentage > 0 {
            direction = .increasing
        } else {
            direction = .decreasing
        }
        
        return (direction, changePercentage)
    }
    
    func detectRecurringPattern(in transactions: [Transaction]) -> TransactionRecurringPattern? {
        guard transactions.count >= 3 else { return nil }
        
        let calendar = Calendar.current
        
        // Check for monthly pattern
        var monthlyIntervals: [Int] = []
        for i in 1..<transactions.count {
            let interval = calendar.dateComponents([.month], from: transactions[i-1].date, to: transactions[i].date).month ?? 0
            monthlyIntervals.append(interval)
        }
        
        if monthlyIntervals.allSatisfy({ $0 == 1 }) {
            return TransactionRecurringPattern(frequency: .monthly, interval: 1, endDate: nil, maxOccurrences: nil)
        }
        
        // Check for weekly pattern
        var weeklyIntervals: [Int] = []
        for i in 1..<transactions.count {
            let interval = calendar.dateComponents([.weekOfYear], from: transactions[i-1].date, to: transactions[i].date).weekOfYear ?? 0
            weeklyIntervals.append(interval)
        }
        
        if weeklyIntervals.allSatisfy({ $0 == 1 }) {
            return TransactionRecurringPattern(frequency: .weekly, interval: 1, endDate: nil, maxOccurrences: nil)
        }
        
        return nil
    }
    
    func calculatePatternConfidence(transactions: [Transaction], pattern: TransactionRecurringPattern) -> Double {
        let expectedIntervals = transactions.count - 1
        var matchingIntervals = 0
        
        let calendar = Calendar.current
        
        for i in 1..<transactions.count {
            let actualInterval: Int
            
            switch pattern.frequency {
            case .monthly:
                actualInterval = calendar.dateComponents([.month], from: transactions[i-1].date, to: transactions[i].date).month ?? 0
            case .weekly:
                actualInterval = calendar.dateComponents([.weekOfYear], from: transactions[i-1].date, to: transactions[i].date).weekOfYear ?? 0
            case .daily:
                actualInterval = calendar.dateComponents([.day], from: transactions[i-1].date, to: transactions[i].date).day ?? 0
            case .yearly:
                actualInterval = calendar.dateComponents([.year], from: transactions[i-1].date, to: transactions[i].date).year ?? 0
            }
            
            if actualInterval == pattern.interval {
                matchingIntervals += 1
            }
        }
        
        return expectedIntervals > 0 ? Double(matchingIntervals) / Double(expectedIntervals) : 0
    }
}

// MARK: - Data Service Extension

extension DataServiceProtocol {
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) -> Result<[T], Error> {
        do {
            let results = try await fetch(type, predicate: predicate)
            return .success(results)
        } catch {
            return .failure(error)
        }
    }
} 