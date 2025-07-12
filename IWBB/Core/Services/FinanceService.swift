import Foundation
import SwiftData

// MARK: - FinanceService Protocol

protocol FinanceServiceProtocol: ServiceProtocol {
    // Основные операции с записями
    func addExpenseEntry(name: String, amount: Decimal, notes: String?) async throws -> ExpenseEntry
    func addIncomeEntry(name: String, amount: Decimal, notes: String?) async throws -> IncomeEntry
    func updateExpenseEntry(_ entry: ExpenseEntry) async throws
    func updateIncomeEntry(_ entry: IncomeEntry) async throws
    func deleteExpenseEntry(_ entry: ExpenseEntry) async throws
    func deleteIncomeEntry(_ entry: IncomeEntry) async throws
    
    // Получение данных для UI
    func getExpenseEntries() async throws -> [ExpenseEntry]
    func getIncomeEntries() async throws -> [IncomeEntry]
    func getMonthlySummaries() async throws -> [MonthlySummary]
    func getCurrentMonthSummary() async throws -> MonthlySummary
    
    // Состояние пустого экрана
    func hasAnyFinancialData() async throws -> Bool
    func initializeEmptyState() async throws
    
    // Автоматический пересчет
    func recalculateCurrentMonth() async throws -> MonthlySummary
    func recalculateAllData() async throws -> [MonthlySummary]
    
    // Статистика
    func getTotalBalance() async throws -> Decimal
    func getBalanceForMonth(_ month: String) async throws -> Decimal
    func getExpensesByCategory(for month: String) async throws -> [CategoryStatistic]
    func getIncomesByCategory(for month: String) async throws -> [CategoryStatistic]
    
    // Валидация
    func validateAmount(_ amount: String) -> (isValid: Bool, decimal: Decimal?)
    func validateEntryName(_ name: String) -> Bool
}

// MARK: - FinanceService Implementation

final class FinanceService: FinanceServiceProtocol {
    
    // MARK: - Properties
    
    private let transactionRepository: TransactionRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    
    var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("Initializing FinanceService...")
        #endif
        
        // Проверяем, нужно ли создать пустое состояние
        let hasData = try await hasAnyFinancialData()
        if !hasData {
            try await initializeEmptyState()
        }
        
        isInitialized = true
        
        #if DEBUG
        print("FinanceService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("Cleaning up FinanceService...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("FinanceService cleaned up")
        #endif
    }
    
    // MARK: - Expense Entry Operations
    
    func addExpenseEntry(name: String, amount: Decimal, notes: String? = nil) async throws -> ExpenseEntry {
        guard validateEntryName(name) else {
            throw AppError.validationFailed("Название траты не может быть пустым")
        }
        
        guard amount > 0 else {
            throw AppError.validationFailed("Сумма должна быть больше нуля")
        }
        
        let entry = ExpenseEntry(
            name: name,
            amount: amount,
            notes: notes
        )
        
        try await transactionRepository.saveExpenseEntry(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateCurrentMonth()
        
        #if DEBUG
        print("Added expense entry: \(name) - \(amount)")
        #endif
        
        return entry
    }
    
    func updateExpenseEntry(_ entry: ExpenseEntry) async throws {
        guard validateEntryName(entry.name) else {
            throw AppError.validationFailed("Название траты не может быть пустым")
        }
        
        guard entry.amount > 0 else {
            throw AppError.validationFailed("Сумма должна быть больше нуля")
        }
        
        try await transactionRepository.updateExpenseEntry(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateCurrentMonth()
        
        #if DEBUG
        print("Updated expense entry: \(entry.name) - \(entry.amount)")
        #endif
    }
    
    func deleteExpenseEntry(_ entry: ExpenseEntry) async throws {
        try await transactionRepository.deleteExpenseEntry(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateCurrentMonth()
        
        #if DEBUG
        print("Deleted expense entry: \(entry.name)")
        #endif
    }
    
    // MARK: - Income Entry Operations
    
    func addIncomeEntry(name: String, amount: Decimal, notes: String? = nil) async throws -> IncomeEntry {
        guard validateEntryName(name) else {
            throw AppError.validationFailed("Название поступления не может быть пустым")
        }
        
        guard amount > 0 else {
            throw AppError.validationFailed("Сумма должна быть больше нуля")
        }
        
        let entry = IncomeEntry(
            name: name,
            amount: amount,
            notes: notes
        )
        
        try await transactionRepository.saveIncomeEntry(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateCurrentMonth()
        
        #if DEBUG
        print("Added income entry: \(name) - \(amount)")
        #endif
        
        return entry
    }
    
    func updateIncomeEntry(_ entry: IncomeEntry) async throws {
        guard validateEntryName(entry.name) else {
            throw AppError.validationFailed("Название поступления не может быть пустым")
        }
        
        guard entry.amount > 0 else {
            throw AppError.validationFailed("Сумма должна быть больше нуля")
        }
        
        try await transactionRepository.updateIncomeEntry(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateCurrentMonth()
        
        #if DEBUG
        print("Updated income entry: \(entry.name) - \(entry.amount)")
        #endif
    }
    
    func deleteIncomeEntry(_ entry: IncomeEntry) async throws {
        try await transactionRepository.deleteIncomeEntry(entry)
        
        // Автоматически обновляем месячную сводку
        _ = try await recalculateCurrentMonth()
        
        #if DEBUG
        print("Deleted income entry: \(entry.name)")
        #endif
    }
    
    // MARK: - Data Retrieval
    
    func getExpenseEntries() async throws -> [ExpenseEntry] {
        return try await transactionRepository.fetchExpenseEntries()
    }
    
    func getIncomeEntries() async throws -> [IncomeEntry] {
        return try await transactionRepository.fetchIncomeEntries()
    }
    
    func getMonthlySummaries() async throws -> [MonthlySummary] {
        let existingSummaries = try await transactionRepository.fetchMonthlySummaries()
        
        // Создаем сводки для всех месяцев от начала года до следующего года
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        
        var allSummaries: [MonthlySummary] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        // Создаем сводки для текущего и следующего года (24 месяца)
        for year in [currentYear, currentYear + 1] {
            for month in 1...12 {
                let monthString = String(format: "%04d-%02d", year, month)
                
                // Проверяем есть ли уже сводка для этого месяца
                if let existingSummary = existingSummaries.first(where: { $0.month == monthString }) {
                    allSummaries.append(existingSummary)
                } else {
                    // Создаем новую сводку с нулевыми значениями
                    let newSummary = MonthlySummary(month: monthString)
                    try await transactionRepository.saveMonthlySummary(newSummary)
                    allSummaries.append(newSummary)
                }
            }
        }
        
        // Сортируем по дате (новые сначала)
        return allSummaries.sorted { $0.month > $1.month }
    }
    
    func getCurrentMonthSummary() async throws -> MonthlySummary {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        
        if let summary = try await transactionRepository.fetchMonthlySummary(for: currentMonth) {
            return summary
        } else {
            // Создаем новую сводку для текущего месяца
            let newSummary = MonthlySummary.createCurrentMonth()
            try await transactionRepository.saveMonthlySummary(newSummary)
            return newSummary
        }
    }
    
    // MARK: - Empty State Management
    
    func hasAnyFinancialData() async throws -> Bool {
        let expenseEntries = try await getExpenseEntries()
        let incomeEntries = try await getIncomeEntries()
        let summaries = try await getMonthlySummaries()
        
        return !expenseEntries.isEmpty || !incomeEntries.isEmpty || !summaries.isEmpty
    }
    
    func initializeEmptyState() async throws {
        // Создаем сводку для текущего месяца с нулевыми значениями
        let currentSummary = MonthlySummary.createCurrentMonth()
        try await transactionRepository.saveMonthlySummary(currentSummary)
        
        #if DEBUG
        print("Initialized empty finance state")
        #endif
    }
    
    // MARK: - Recalculation
    
    func recalculateCurrentMonth() async throws -> MonthlySummary {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        
        return try await transactionRepository.recalculateMonthlySummary(for: currentMonth)
    }
    
    func recalculateAllData() async throws -> [MonthlySummary] {
        return try await transactionRepository.recalculateAllMonthlySummaries()
    }
    
    // MARK: - Statistics
    
    func getTotalBalance() async throws -> Decimal {
        let summaries = try await getMonthlySummaries()
        return summaries.reduce(0) { $0 + $1.totalSavings }
    }
    
    func getBalanceForMonth(_ month: String) async throws -> Decimal {
        return try await transactionRepository.getBalanceForMonth(month)
    }
    
    func getExpensesByCategory(for month: String) async throws -> [CategoryStatistic] {
        let expenses = try await transactionRepository.fetchExpenseEntriesForMonth(month)
        
        var categoryStats: [UUID: CategoryStatistic] = [:]
        
        for expense in expenses {
            if let category = expense.category {
                if var stat = categoryStats[category.id] {
                    stat.amount += expense.amount
                    stat.count += 1
                    categoryStats[category.id] = stat
                } else {
                    categoryStats[category.id] = CategoryStatistic(
                        category: category,
                        amount: expense.amount,
                        count: 1
                    )
                }
            }
        }
        
        return Array(categoryStats.values).sorted { $0.amount > $1.amount }
    }
    
    func getIncomesByCategory(for month: String) async throws -> [CategoryStatistic] {
        let incomes = try await transactionRepository.fetchIncomeEntriesForMonth(month)
        
        var categoryStats: [UUID: CategoryStatistic] = [:]
        
        for income in incomes {
            if let category = income.category {
                if var stat = categoryStats[category.id] {
                    stat.amount += income.amount
                    stat.count += 1
                    categoryStats[category.id] = stat
                } else {
                    categoryStats[category.id] = CategoryStatistic(
                        category: category,
                        amount: income.amount,
                        count: 1
                    )
                }
            }
        }
        
        return Array(categoryStats.values).sorted { $0.amount > $1.amount }
    }
    
    // MARK: - Validation
    
    func validateAmount(_ amount: String) -> (isValid: Bool, decimal: Decimal?) {
        // Убираем пробелы
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (false, nil)
        }
        
        // Заменяем запятую на точку для десятичных чисел
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        
        // Проверяем, что строка содержит только цифры, точку и максимум одну точку
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        guard normalized.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, nil)
        }
        
        // Проверяем количество точек
        let dotCount = normalized.components(separatedBy: ".").count - 1
        guard dotCount <= 1 else {
            return (false, nil)
        }
        
        // Проверяем количество знаков после запятой
        if let dotRange = normalized.range(of: ".") {
            let afterDot = String(normalized[dotRange.upperBound...])
            guard afterDot.count <= 2 else {
                return (false, nil)
            }
        }
        
        // Пробуем преобразовать в Decimal
        guard let decimal = Decimal(string: normalized), decimal > 0 else {
            return (false, nil)
        }
        
        return (true, decimal)
    }
    
    func validateEntryName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Finance Service Extensions

extension FinanceService {
    
    /// Создает демонстрационные данные для тестирования
    func createSampleData() async throws {
        // Создаем несколько записей расходов
        let expenseNames = [
            "Продукты в магазине",
            "Проезд в метро",
            "Обед в кафе",
            "Покупка книги",
            "Оплата интернета"
        ]
        
        let expenseAmounts: [Decimal] = [2500, 120, 650, 800, 900]
        
        for (name, amount) in zip(expenseNames, expenseAmounts) {
            _ = try await addExpenseEntry(name: name, amount: amount)
        }
        
        // Создаем несколько записей доходов
        let incomeNames = [
            "Зарплата",
            "Фриланс проект",
            "Возврат долга"
        ]
        
        let incomeAmounts: [Decimal] = [85000, 15000, 5000]
        
        for (name, amount) in zip(incomeNames, incomeAmounts) {
            _ = try await addIncomeEntry(name: name, amount: amount)
        }
        
        // Пересчитываем все данные
        _ = try await recalculateAllData()
        
        #if DEBUG
        print("Created sample finance data")
        #endif
    }
    
    /// Очищает все финансовые данные
    func clearAllData() async throws {
        let expenseEntries = try await getExpenseEntries()
        for entry in expenseEntries {
            try await deleteExpenseEntry(entry)
        }
        
        let incomeEntries = try await getIncomeEntries()
        for entry in incomeEntries {
            try await deleteIncomeEntry(entry)
        }
        
        let summaries = try await getMonthlySummaries()
        for summary in summaries {
            try await transactionRepository.deleteMonthlySummary(summary)
        }
        
        // Заново инициализируем пустое состояние
        try await initializeEmptyState()
        
        #if DEBUG
        print("Cleared all finance data")
        #endif
    }
    
    /// Экспортирует данные в CSV формат
    func exportToCSV() async throws -> String {
        let expenses = try await getExpenseEntries()
        let incomes = try await getIncomeEntries()
        
        var csv = "Тип,Название,Сумма,Дата,Месяц,Заметки\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for expense in expenses {
            let date = dateFormatter.string(from: expense.date)
            let notes = expense.notes ?? ""
            csv += "Расход,\(expense.name),\(expense.amount),\(date),\(expense.monthDisplayName),\(notes)\n"
        }
        
        for income in incomes {
            let date = dateFormatter.string(from: income.date)
            let notes = income.notes ?? ""
            csv += "Поступление,\(income.name),\(income.amount),\(date),\(income.monthDisplayName),\(notes)\n"
        }
        
        return csv
    }
    
    /// Получает статистику за период
    func getStatisticsForPeriod(months: Int = 6) async throws -> FinancePeriodStatistics {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -months, to: endDate) ?? endDate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        var monthlyData: [String: (income: Decimal, expenses: Decimal)] = [:]
        
        var currentDate = startDate
        while currentDate <= endDate {
            let monthKey = formatter.string(from: currentDate)
            let income = try await transactionRepository.getTotalIncomeForMonth(monthKey)
            let expenses = try await transactionRepository.getTotalExpensesForMonth(monthKey)
            
            monthlyData[monthKey] = (income, expenses)
            
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return FinancePeriodStatistics(
            period: "\(months) месяцев",
            monthlyData: monthlyData,
            totalIncome: monthlyData.values.reduce(0) { $0 + $1.income },
            totalExpenses: monthlyData.values.reduce(0) { $0 + $1.expenses }
        )
    }
}

// MARK: - Supporting Types

struct FinancePeriodStatistics {
    let period: String
    let monthlyData: [String: (income: Decimal, expenses: Decimal)]
    let totalIncome: Decimal
    let totalExpenses: Decimal
    
    var totalSavings: Decimal {
        return totalIncome - totalExpenses
    }
    
    var averageMonthlyIncome: Decimal {
        guard !monthlyData.isEmpty else { return 0 }
        return totalIncome / Decimal(monthlyData.count)
    }
    
    var averageMonthlyExpenses: Decimal {
        guard !monthlyData.isEmpty else { return 0 }
        return totalExpenses / Decimal(monthlyData.count)
    }
    
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(totalSavings / totalIncome) * 100
    }
} 