import Foundation
import SwiftData

// MARK: - Transaction Repository Protocol

protocol TransactionRepositoryProtocol {
    // MARK: - Basic CRUD Operations
    func fetchTransactions(
        from startDate: Date?,
        to endDate: Date?,
        type: TransactionType?,
        category: Category?
    ) async throws -> [Transaction]
    
    func fetchTransaction(by id: UUID) async throws -> Transaction?
    func save(_ transaction: Transaction) async throws
    func delete(_ transaction: Transaction) async throws
    func batchSave(_ transactions: [Transaction]) async throws
    
    // MARK: - Analytics & Aggregations
    func getMonthlyBalance(for date: Date) async throws -> FinanceBalance
    func getWeeklyBalance(for date: Date) async throws -> FinanceBalance
    func getYearlyBalance(for date: Date) async throws -> FinanceBalance
    func getTopCategories(for period: DateInterval, type: TransactionType) async throws -> [CategorySummary]
    func getTrendData(for period: DateInterval) async throws -> [BalancePoint]
    
    // MARK: - Search & Filtering
    func searchTransactions(query: String) async throws -> [Transaction]
    func getRecentTransactions(limit: Int) async throws -> [Transaction]
    func getTransactionsByAccount(_ account: String) async throws -> [Transaction]
    func getRecurringTransactions() async throws -> [Transaction]
    
    // MARK: - Statistics
    func getTotalBalance() async throws -> Decimal
    func getMonthlySpending(for date: Date) async throws -> Decimal
    func getMonthlyIncome(for date: Date) async throws -> Decimal
    func getAverageTransactionAmount(for type: TransactionType) async throws -> Decimal
    
    // MARK: - Currency Operations
    func getTransactionsInCurrency(_ currency: String) async throws -> [Transaction]
    func convertTransactionsToBaseCurrency(_ transactions: [Transaction]) async throws -> [Transaction]
}

// MARK: - Supporting Data Structures

struct FinanceBalance {
    let income: Decimal
    let expenses: Decimal
    let balance: Decimal
    let period: DateInterval
    let transactionCount: Int
    let currency: String
    
    var isPositive: Bool { balance >= 0 }
    var changeFromPreviousPeriod: Decimal?
    
    init(
        income: Decimal,
        expenses: Decimal,
        period: DateInterval,
        transactionCount: Int,
        currency: String = "RUB",
        changeFromPreviousPeriod: Decimal? = nil
    ) {
        self.income = income
        self.expenses = expenses
        self.balance = income - expenses
        self.period = period
        self.transactionCount = transactionCount
        self.currency = currency
        self.changeFromPreviousPeriod = changeFromPreviousPeriod
    }
}

struct CategorySummary {
    let category: Category
    let totalAmount: Decimal
    let transactionCount: Int
    let percentage: Double
    let averageAmount: Decimal
    
    init(category: Category, totalAmount: Decimal, transactionCount: Int, totalSum: Decimal) {
        self.category = category
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
        self.percentage = totalSum > 0 ? Double(totalAmount / totalSum) * 100 : 0
        self.averageAmount = transactionCount > 0 ? totalAmount / Decimal(transactionCount) : 0
    }
}

struct BalancePoint {
    let date: Date
    let income: Decimal
    let expenses: Decimal
    let balance: Decimal
    
    init(date: Date, income: Decimal, expenses: Decimal) {
        self.date = date
        self.income = income
        self.expenses = expenses
        self.balance = income - expenses
    }
}

// MARK: - Transaction Repository Implementation

final class TransactionRepository: TransactionRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let syncService: SyncServiceProtocol
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, syncService: SyncServiceProtocol) {
        self.modelContext = modelContext
        self.syncService = syncService
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchTransactions(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        type: TransactionType? = nil,
        category: Category? = nil
    ) async throws -> [Transaction] {
        var predicates: [Predicate<Transaction>] = []
        
        // Date range filtering
        if let startDate = startDate {
            predicates.append(#Predicate { $0.date >= startDate })
        }
        
        if let endDate = endDate {
            predicates.append(#Predicate { $0.date <= endDate })
        }
        
        // Type filtering
        if let type = type {
            predicates.append(#Predicate { $0.type == type })
        }
        
        // Category filtering
        if let category = category {
            predicates.append(#Predicate { $0.category?.id == category.id })
        }
        
        // Combine predicates
        let compound = predicates.reduce(nil) { result, predicate in
            if let result = result {
                return #Predicate<Transaction> { transaction in
                    result.evaluate(transaction) && predicate.evaluate(transaction)
                }
            } else {
                return predicate
            }
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: compound,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func fetchTransaction(by id: UUID) async throws -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func save(_ transaction: Transaction) async throws {
        transaction.needsSync = true
        transaction.updatedAt = Date()
        
        modelContext.insert(transaction)
        try modelContext.save()
        
        // Trigger sync
        await syncService.scheduleSync()
    }
    
    func delete(_ transaction: Transaction) async throws {
        modelContext.delete(transaction)
        try modelContext.save()
        
        // Trigger sync
        await syncService.scheduleSync()
    }
    
    func batchSave(_ transactions: [Transaction]) async throws {
        for transaction in transactions {
            transaction.needsSync = true
            transaction.updatedAt = Date()
            modelContext.insert(transaction)
        }
        
        try modelContext.save()
        
        // Trigger sync
        await syncService.scheduleSync()
    }
    
    // MARK: - Analytics & Aggregations
    
    func getMonthlyBalance(for date: Date) async throws -> FinanceBalance {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
            throw AppError.invalidDate
        }
        
        return try await calculateBalance(for: monthInterval)
    }
    
    func getWeeklyBalance(for date: Date) async throws -> FinanceBalance {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            throw AppError.invalidDate
        }
        
        return try await calculateBalance(for: weekInterval)
    }
    
    func getYearlyBalance(for date: Date) async throws -> FinanceBalance {
        let calendar = Calendar.current
        guard let yearInterval = calendar.dateInterval(of: .year, for: date) else {
            throw AppError.invalidDate
        }
        
        return try await calculateBalance(for: yearInterval)
    }
    
    private func calculateBalance(for period: DateInterval) async throws -> FinanceBalance {
        let transactions = try await fetchTransactions(
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
    
    func getTopCategories(for period: DateInterval, type: TransactionType) async throws -> [CategorySummary] {
        let transactions = try await fetchTransactions(
            from: period.start,
            to: period.end,
            type: type
        )
        
        // Group by category
        let grouped = Dictionary(grouping: transactions) { $0.category }
        
        // Calculate totals
        var summaries: [CategorySummary] = []
        let totalSum = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        for (category, transactions) in grouped {
            guard let category = category else { continue }
            
            let categoryTotal = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
            let summary = CategorySummary(
                category: category,
                totalAmount: categoryTotal,
                transactionCount: transactions.count,
                totalSum: totalSum
            )
            summaries.append(summary)
        }
        
        // Sort by amount descending
        return summaries.sorted { $0.totalAmount > $1.totalAmount }
    }
    
    func getTrendData(for period: DateInterval) async throws -> [BalancePoint] {
        let calendar = Calendar.current
        let transactions = try await fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        // Group transactions by day
        let groupedByDay = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        
        var trendData: [BalancePoint] = []
        
        // Generate data points for each day in period
        var currentDate = calendar.startOfDay(for: period.start)
        let endDate = calendar.startOfDay(for: period.end)
        
        while currentDate <= endDate {
            let dayTransactions = groupedByDay[currentDate] ?? []
            
            let income = dayTransactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.convertedAmount }
            
            let expenses = dayTransactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.convertedAmount }
            
            let balancePoint = BalancePoint(
                date: currentDate,
                income: income,
                expenses: expenses
            )
            trendData.append(balancePoint)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return trendData
    }
    
    // MARK: - Search & Filtering
    
    func searchTransactions(query: String) async throws -> [Transaction] {
        let lowercaseQuery = query.lowercased()
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.title.localizedStandardContains(lowercaseQuery) ||
                (transaction.description?.localizedStandardContains(lowercaseQuery) ?? false) ||
                transaction.tags.contains { $0.localizedStandardContains(lowercaseQuery) }
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getRecentTransactions(limit: Int = 10) async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    func getTransactionsByAccount(_ account: String) async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.account == account },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getRecurringTransactions() async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.isRecurring == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Statistics
    
    func getTotalBalance() async throws -> Decimal {
        let allTransactions = try await fetchTransactions()
        
        return allTransactions.reduce(Decimal.zero) { total, transaction in
            switch transaction.type {
            case .income:
                return total + transaction.convertedAmount
            case .expense:
                return total - transaction.convertedAmount
            case .transfer:
                return total // Transfers don't affect total balance
            }
        }
    }
    
    func getMonthlySpending(for date: Date) async throws -> Decimal {
        let monthlyBalance = try await getMonthlyBalance(for: date)
        return monthlyBalance.expenses
    }
    
    func getMonthlyIncome(for date: Date) async throws -> Decimal {
        let monthlyBalance = try await getMonthlyBalance(for: date)
        return monthlyBalance.income
    }
    
    func getAverageTransactionAmount(for type: TransactionType) async throws -> Decimal {
        let transactions = try await fetchTransactions(type: type)
        
        guard !transactions.isEmpty else { return 0 }
        
        let total = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        return total / Decimal(transactions.count)
    }
    
    // MARK: - Currency Operations
    
    func getTransactionsInCurrency(_ currency: String) async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.currency == currency },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func convertTransactionsToBaseCurrency(_ transactions: [Transaction]) async throws -> [Transaction] {
        // This method would use a currency service to convert transactions
        // For now, we'll return the transactions as-is since they already have convertedAmount
        return transactions
    }
}

// MARK: - Transaction Repository Extensions

extension TransactionRepository {
    
    /// Получает статистику по периодам
    func getPeriodicStats(for periods: [DateInterval]) async throws -> [FinanceBalance] {
        var stats: [FinanceBalance] = []
        
        for period in periods {
            let balance = try await calculateBalance(for: period)
            stats.append(balance)
        }
        
        return stats
    }
    
    /// Получает транзакции с группировкой по дням
    func getTransactionsGroupedByDay(for period: DateInterval) async throws -> [Date: [Transaction]] {
        let transactions = try await fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        let calendar = Calendar.current
        return Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
    }
    
    /// Проверяет есть ли транзакции в указанном периоде
    func hasTransactions(in period: DateInterval) async throws -> Bool {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.date >= period.start && transaction.date <= period.end
            }
        )
        descriptor.fetchLimit = 1
        
        let transactions = try modelContext.fetch(descriptor)
        return !transactions.isEmpty
    }
    
    /// Получает следующие повторяющиеся транзакции
    func getUpcomingRecurringTransactions(limit: Int = 10) async throws -> [Transaction] {
        let recurringTransactions = try await getRecurringTransactions()
        var upcomingTransactions: [Transaction] = []
        
        for transaction in recurringTransactions {
            if let nextTransaction = transaction.createNextRecurringTransaction() {
                upcomingTransactions.append(nextTransaction)
            }
        }
        
        // Sort by date and limit
        upcomingTransactions.sort { $0.date < $1.date }
        return Array(upcomingTransactions.prefix(limit))
    }
    
    /// Экспортирует транзакции в CSV формат
    func exportTransactionsToCSV(for period: DateInterval) async throws -> String {
        let transactions = try await fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        var csv = "Date,Type,Amount,Currency,Title,Description,Category,Account\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for transaction in transactions {
            let date = dateFormatter.string(from: transaction.date)
            let type = transaction.type.displayName
            let amount = transaction.amount.description
            let currency = transaction.currency
            let title = transaction.title.replacingOccurrences(of: ",", with: ";")
            let description = (transaction.description ?? "").replacingOccurrences(of: ",", with: ";")
            let category = transaction.category?.name ?? ""
            let account = transaction.account ?? ""
            
            csv += "\(date),\(type),\(amount),\(currency),\(title),\(description),\(category),\(account)\n"
        }
        
        return csv
    }
} 