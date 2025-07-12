import Foundation
import SwiftData

// MARK: - TransactionRepository Protocol

protocol TransactionRepositoryProtocol {
    // CRUD для транзакций
    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [Transaction]
    func fetchAllTransactions() async throws -> [Transaction]
    func fetchRecentTransactions(limit: Int) async throws -> [Transaction]
    func fetchTransaction(by id: UUID) async throws -> Transaction?
    func save(_ transaction: Transaction) async throws
    func update(_ transaction: Transaction) async throws
    func delete(_ transaction: Transaction) async throws
    
    // CRUD для записей расходов
    func fetchExpenseEntries() async throws -> [ExpenseEntry]
    func fetchExpenseEntriesForMonth(_ month: String) async throws -> [ExpenseEntry]
    func saveExpenseEntry(_ entry: ExpenseEntry) async throws
    func updateExpenseEntry(_ entry: ExpenseEntry) async throws
    func deleteExpenseEntry(_ entry: ExpenseEntry) async throws
    
    // CRUD для записей доходов
    func fetchIncomeEntries() async throws -> [IncomeEntry]
    func fetchIncomeEntriesForMonth(_ month: String) async throws -> [IncomeEntry]
    func saveIncomeEntry(_ entry: IncomeEntry) async throws
    func updateIncomeEntry(_ entry: IncomeEntry) async throws
    func deleteIncomeEntry(_ entry: IncomeEntry) async throws
    
    // CRUD для месячных сводок
    func fetchMonthlySummaries() async throws -> [MonthlySummary]
    func fetchMonthlySummary(for month: String) async throws -> MonthlySummary?
    func saveMonthlySummary(_ summary: MonthlySummary) async throws
    func updateMonthlySummary(_ summary: MonthlySummary) async throws
    func deleteMonthlySummary(_ summary: MonthlySummary) async throws
    
    // Автоматическое обновление сводок
    func recalculateMonthlySummary(for month: String) async throws -> MonthlySummary
    func recalculateAllMonthlySummaries() async throws -> [MonthlySummary]
}

// MARK: - TransactionRepository Implementation

final class TransactionRepository: TransactionRepositoryProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    
    // MARK: - Initialization
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }
    
    // MARK: - Transaction CRUD
    
    func fetchTransactions(from startDate: Date, to endDate: Date) async throws -> [Transaction] {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= startDate && transaction.date <= endDate
        }
        return try await dataService.fetch(Transaction.self, predicate: predicate)
    }
    
    func fetchAllTransactions() async throws -> [Transaction] {
        return try await dataService.fetch(Transaction.self, predicate: nil)
    }
    
    func fetchRecentTransactions(limit: Int = 10) async throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>()
        descriptor.sortBy = [SortDescriptor(\Transaction.date, order: .reverse)]
        descriptor.fetchLimit = limit
        
        return try await dataService.modelContext.fetch(descriptor)
    }
    
    func fetchTransaction(by id: UUID) async throws -> Transaction? {
        let predicate = #Predicate<Transaction> { transaction in
            transaction.id == id
        }
        return try await dataService.fetchOne(Transaction.self, predicate: predicate)
    }
    
    func save(_ transaction: Transaction) async throws {
        try transaction.validate()
        try await dataService.save(transaction)
    }
    
    func update(_ transaction: Transaction) async throws {
        try transaction.validate()
        try await dataService.update(transaction)
    }
    
    func delete(_ transaction: Transaction) async throws {
        try await dataService.delete(transaction)
    }
    
    // MARK: - ExpenseEntry CRUD
    
    func fetchExpenseEntries() async throws -> [ExpenseEntry] {
        var descriptor = FetchDescriptor<ExpenseEntry>()
        descriptor.sortBy = [SortDescriptor(\ExpenseEntry.date, order: .reverse)]
        return try await dataService.modelContext.fetch(descriptor)
    }
    
    func fetchExpenseEntriesForMonth(_ month: String) async throws -> [ExpenseEntry] {
        let predicate = #Predicate<ExpenseEntry> { entry in
            entry.month == month
        }
        var descriptor = FetchDescriptor<ExpenseEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\ExpenseEntry.date, order: .reverse)]
        return try await dataService.modelContext.fetch(descriptor)
    }
    
    func saveExpenseEntry(_ entry: ExpenseEntry) async throws {
        try entry.validate()
        try await dataService.save(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateMonthlySummary(for: entry.month)
    }
    
    func updateExpenseEntry(_ entry: ExpenseEntry) async throws {
        try entry.validate()
        try await dataService.update(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateMonthlySummary(for: entry.month)
    }
    
    func deleteExpenseEntry(_ entry: ExpenseEntry) async throws {
        let month = entry.month
        try await dataService.delete(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateMonthlySummary(for: month)
    }
    
    // MARK: - IncomeEntry CRUD
    
    func fetchIncomeEntries() async throws -> [IncomeEntry] {
        var descriptor = FetchDescriptor<IncomeEntry>()
        descriptor.sortBy = [SortDescriptor(\IncomeEntry.date, order: .reverse)]
        return try await dataService.modelContext.fetch(descriptor)
    }
    
    func fetchIncomeEntriesForMonth(_ month: String) async throws -> [IncomeEntry] {
        let predicate = #Predicate<IncomeEntry> { entry in
            entry.month == month
        }
        var descriptor = FetchDescriptor<IncomeEntry>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\IncomeEntry.date, order: .reverse)]
        return try await dataService.modelContext.fetch(descriptor)
    }
    
    func saveIncomeEntry(_ entry: IncomeEntry) async throws {
        try entry.validate()
        try await dataService.save(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateMonthlySummary(for: entry.month)
    }
    
    func updateIncomeEntry(_ entry: IncomeEntry) async throws {
        try entry.validate()
        try await dataService.update(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateMonthlySummary(for: entry.month)
    }
    
    func deleteIncomeEntry(_ entry: IncomeEntry) async throws {
        let month = entry.month
        try await dataService.delete(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateMonthlySummary(for: month)
    }
    
    // MARK: - MonthlySummary CRUD
    
    func fetchMonthlySummaries() async throws -> [MonthlySummary] {
        var descriptor = FetchDescriptor<MonthlySummary>()
        descriptor.sortBy = [SortDescriptor(\MonthlySummary.month, order: .reverse)]
        return try await dataService.modelContext.fetch(descriptor)
    }
    
    func fetchMonthlySummary(for month: String) async throws -> MonthlySummary? {
        let predicate = #Predicate<MonthlySummary> { summary in
            summary.month == month
        }
        return try await dataService.fetchOne(MonthlySummary.self, predicate: predicate)
    }
    
    func saveMonthlySummary(_ summary: MonthlySummary) async throws {
        try summary.validate()
        try await dataService.save(summary)
    }
    
    func updateMonthlySummary(_ summary: MonthlySummary) async throws {
        try summary.validate()
        try await dataService.update(summary)
    }
    
    func deleteMonthlySummary(_ summary: MonthlySummary) async throws {
        try await dataService.delete(summary)
    }
    
    // MARK: - Auto-calculation Methods
    
    func recalculateMonthlySummary(for month: String) async throws -> MonthlySummary {
        // Получаем существующую сводку или создаем новую
        var summary = try await fetchMonthlySummary(for: month)
        
        if summary == nil {
            summary = MonthlySummary(month: month)
        }
        
        guard let existingSummary = summary else {
            throw AppError.fetchFailed("Не удалось создать месячную сводку")
        }
        
        // Получаем записи для этого месяца
        let expenseEntries = try await fetchExpenseEntriesForMonth(month)
        let incomeEntries = try await fetchIncomeEntriesForMonth(month)
        
        // Пересчитываем сводку
        existingSummary.recalculate(expenseEntries: expenseEntries, incomeEntries: incomeEntries)
        
        // Сохраняем обновленную сводку
        if existingSummary.createdAt == Date.distantPast {
            try await saveMonthlySummary(existingSummary)
        } else {
            try await updateMonthlySummary(existingSummary)
        }
        
        return existingSummary
    }
    
    func recalculateAllMonthlySummaries() async throws -> [MonthlySummary] {
        // Получаем все уникальные месяцы из записей
        let expenseEntries = try await fetchExpenseEntries()
        let incomeEntries = try await fetchIncomeEntries()
        
        let allMonths = Set(expenseEntries.map { $0.month } + incomeEntries.map { $0.month })
        
        var summaries: [MonthlySummary] = []
        
        for month in allMonths {
            let summary = try await recalculateMonthlySummary(for: month)
            summaries.append(summary)
        }
        
        return summaries.sorted { $0.month > $1.month }
    }
}

// MARK: - Helper Extensions

extension TransactionRepository {
    
    /// Получает статистику по категориям для периода
    func getCategoryStats(from startDate: Date, to endDate: Date) async throws -> [CategoryStatistic] {
        let transactions = try await fetchTransactions(from: startDate, to: endDate)
        
        var stats: [UUID: CategoryStatistic] = [:]
        
        for transaction in transactions where transaction.type == .expense {
            guard let category = transaction.category else { continue }
            
            if var stat = stats[category.id] {
                stat.amount += transaction.amount
                stat.count += 1
                stats[category.id] = stat
            } else {
                stats[category.id] = CategoryStatistic(
                    category: category,
                    amount: transaction.amount,
                    count: 1
                )
            }
        }
        
        return Array(stats.values).sorted { $0.amount > $1.amount }
    }
    
    /// Получает общую сумму расходов за месяц
    func getTotalExpensesForMonth(_ month: String) async throws -> Decimal {
        let entries = try await fetchExpenseEntriesForMonth(month)
        return entries.reduce(0) { $0 + $1.amount }
    }
    
    /// Получает общую сумму доходов за месяц
    func getTotalIncomeForMonth(_ month: String) async throws -> Decimal {
        let entries = try await fetchIncomeEntriesForMonth(month)
        return entries.reduce(0) { $0 + $1.amount }
    }
    
    /// Получает баланс за месяц
    func getBalanceForMonth(_ month: String) async throws -> Decimal {
        let income = try await getTotalIncomeForMonth(month)
        let expenses = try await getTotalExpensesForMonth(month)
        return income - expenses
    }
}

// MARK: - Supporting Types

struct CategoryStatistic: Identifiable {
    let id = UUID()
    let category: Category
    var amount: Decimal
    var count: Int
    
    var percentage: Double = 0.0
    var averageAmount: Decimal {
        guard count > 0 else { return 0 }
        return amount / Decimal(count)
    }
} 