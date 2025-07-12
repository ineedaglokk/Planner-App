import Foundation
import SwiftData

// MARK: - MonthlySummary Model

@Model
final class MonthlySummary: CloudKitSyncable, Timestampable, Identifiable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var month: String // Месяц в формате "YYYY-MM"
    var monthDisplayName: String // Название месяца для отображения
    var totalExpenses: Decimal // Общие расходы
    var totalIncome: Decimal // Общие поступления
    var totalSavings: Decimal // Накопления (доходы - расходы)
    var currency: String // Валюта
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    
    // MARK: - Initializers
    
    init(
        month: String,
        currency: String = "RUB"
    ) {
        self.id = UUID()
        self.month = month
        self.currency = currency
        
        // Инициализируем суммы нулевыми значениями
        self.totalExpenses = 0
        self.totalIncome = 0
        self.totalSavings = 0
        
        // Создаем отображаемое название месяца
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        if let date = formatter.date(from: month) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "LLLL yyyy"
            displayFormatter.locale = Locale(identifier: "ru_RU")
            self.monthDisplayName = displayFormatter.string(from: date).capitalized
        } else {
            self.monthDisplayName = month
        }
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
}

// MARK: - MonthlySummary Extensions

extension MonthlySummary: Validatable {
    func validate() throws {
        if month.isEmpty {
            throw ModelValidationError.missingRequiredField("Месяц обязателен")
        }
        
        if currency.isEmpty {
            throw ModelValidationError.missingRequiredField("Валюта обязательна")
        }
    }
}

extension MonthlySummary {
    
    // MARK: - Computed Properties
    
    /// Форматированная общая сумма расходов
    var formattedTotalExpenses: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: totalExpenses)) ?? "\(totalExpenses) \(currency)"
    }
    
    /// Форматированная общая сумма поступлений
    var formattedTotalIncome: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: totalIncome)) ?? "\(totalIncome) \(currency)"
    }
    
    /// Форматированная сумма накоплений
    var formattedTotalSavings: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: totalSavings)) ?? "\(totalSavings) \(currency)"
    }
    
    /// Цвет для накоплений (зеленый для положительных, красный для отрицательных)
    var savingsColor: String {
        return totalSavings >= 0 ? "#32D74B" : "#FF3B30"
    }
    
    /// Является ли месяц прибыльным
    var isProfitable: Bool {
        return totalSavings > 0
    }
    
    /// Процент сбережений от дохода
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(totalSavings / totalIncome) * 100
    }
    
    /// Форматированный процент сбережений
    var formattedSavingsRate: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSNumber(value: savingsRate / 100)) ?? "\(savingsRate)%"
    }
    
    // MARK: - Helper Methods
    
    /// Обновляет итоговые суммы
    func updateTotals(expenses: Decimal, income: Decimal) {
        totalExpenses = expenses
        totalIncome = income
        totalSavings = income - expenses
        updateTimestamp()
        markForSync()
    }
    
    /// Добавляет расход
    func addExpense(_ amount: Decimal) {
        totalExpenses += amount
        totalSavings = totalIncome - totalExpenses
        updateTimestamp()
        markForSync()
    }
    
    /// Добавляет поступление
    func addIncome(_ amount: Decimal) {
        totalIncome += amount
        totalSavings = totalIncome - totalExpenses
        updateTimestamp()
        markForSync()
    }
    
    /// Убирает расход
    func removeExpense(_ amount: Decimal) {
        totalExpenses = max(0, totalExpenses - amount)
        totalSavings = totalIncome - totalExpenses
        updateTimestamp()
        markForSync()
    }
    
    /// Убирает поступление
    func removeIncome(_ amount: Decimal) {
        totalIncome = max(0, totalIncome - amount)
        totalSavings = totalIncome - totalExpenses
        updateTimestamp()
        markForSync()
    }
    
    /// Пересчитывает данные месяца
    func recalculate(expenseEntries: [ExpenseEntry], incomeEntries: [IncomeEntry]) {
        let monthExpenses = expenseEntries
            .filter { $0.month == month }
            .reduce(0) { $0 + $1.amount }
        
        let monthIncome = incomeEntries
            .filter { $0.month == month }
            .reduce(0) { $0 + $1.amount }
        
        updateTotals(expenses: monthExpenses, income: monthIncome)
    }
    
    /// Создает сводку для текущего месяца
    static func createCurrentMonth(currency: String = "RUB") -> MonthlySummary {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())
        
        return MonthlySummary(month: currentMonth, currency: currency)
    }
    
    /// Создает сводку для указанной даты
    static func createForDate(_ date: Date, currency: String = "RUB") -> MonthlySummary {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let month = formatter.string(from: date)
        
        return MonthlySummary(month: month, currency: currency)
    }
} 