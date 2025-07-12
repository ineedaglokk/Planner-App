import Foundation
import SwiftData

// MARK: - Budget Planner Models

@Model
final class BudgetPlan: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var year: Int
    var month: Int
    var currency: String
    var startDate: Date
    
    // Основные категории
    var income: BudgetPlanItem
    var expenses: BudgetPlanItem
    var debts: BudgetPlanItem
    var savings: BudgetPlanItem
    
    // Детализация
    var incomeItems: [BudgetPlanItem]
    var expenseItems: [BudgetPlanItem]
    var debtItems: [BudgetPlanItem]
    var savingsItems: [BudgetPlanItem]
    
    // Ежедневные операции
    var dailyExpenses: [DailyTransaction]
    var dailyIncome: [DailyTransaction]
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    
    // MARK: - Initializer
    
    init(
        year: Int,
        month: Int,
        currency: String = "RUB"
    ) {
        self.id = UUID()
        self.year = year
        self.month = month
        self.currency = currency
        
        // Создаем дату начала месяца
        self.startDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        
        // Инициализируем основные категории
        self.income = BudgetPlanItem(name: "Поступления", type: .income)
        self.expenses = BudgetPlanItem(name: "Расходы", type: .expense)
        self.debts = BudgetPlanItem(name: "Долги", type: .debt)
        self.savings = BudgetPlanItem(name: "Капитал и накопления", type: .savings)
        
        // Инициализируем массивы
        self.incomeItems = []
        self.expenseItems = []
        self.debtItems = []
        self.savingsItems = []
        self.dailyExpenses = []
        self.dailyIncome = []
        
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

// MARK: - Budget Plan Item

@Model
final class BudgetPlanItem: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var type: BudgetItemType
    var plannedAmount: Decimal
    var actualAmount: Decimal
    var category: String?
    var description: String?
    var icon: String?
    var color: String?
    var sortOrder: Int
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var budgetPlan: BudgetPlan?
    
    // MARK: - Initializer
    
    init(
        name: String,
        type: BudgetItemType,
        plannedAmount: Decimal = 0,
        actualAmount: Decimal = 0,
        category: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.plannedAmount = plannedAmount
        self.actualAmount = actualAmount
        self.category = category
        self.sortOrder = sortOrder
        
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

// MARK: - Daily Transaction

@Model
final class DailyTransaction: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var date: Date
    var category: String
    var amount: Decimal
    var description: String?
    var type: TransactionType
    var paymentMethod: String?
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var budgetPlan: BudgetPlan?
    
    // MARK: - Initializer
    
    init(
        date: Date,
        category: String,
        amount: Decimal,
        description: String? = nil,
        type: TransactionType
    ) {
        self.id = UUID()
        self.date = date
        self.category = category
        self.amount = amount
        self.description = description
        self.type = type
        
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

// MARK: - Monthly Financial Summary

@Model
final class MonthlyFinancialSummary: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var year: Int
    var month: Int
    var totalIncome: Decimal
    var totalExpenses: Decimal
    var totalSavings: Decimal
    var totalDebts: Decimal
    var netBalance: Decimal
    
    // Статистика
    var transactionCount: Int
    var averageDailySpending: Decimal
    var biggestExpense: Decimal
    var biggestIncome: Decimal
    
    // Категории
    var topExpenseCategories: [CategorySummary]
    var topIncomeCategories: [CategorySummary]
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    
    // MARK: - Initializer
    
    init(
        year: Int,
        month: Int,
        totalIncome: Decimal = 0,
        totalExpenses: Decimal = 0,
        totalSavings: Decimal = 0,
        totalDebts: Decimal = 0
    ) {
        self.id = UUID()
        self.year = year
        self.month = month
        self.totalIncome = totalIncome
        self.totalExpenses = totalExpenses
        self.totalSavings = totalSavings
        self.totalDebts = totalDebts
        self.netBalance = totalIncome - totalExpenses
        
        // Статистика
        self.transactionCount = 0
        self.averageDailySpending = 0
        self.biggestExpense = 0
        self.biggestIncome = 0
        
        // Категории
        self.topExpenseCategories = []
        self.topIncomeCategories = []
        
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

// MARK: - Yearly Financial Overview

@Model
final class YearlyFinancialOverview: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var year: Int
    var totalIncome: Decimal
    var totalExpenses: Decimal
    var totalSavings: Decimal
    var totalDebts: Decimal
    var netBalance: Decimal
    
    // Помесячная разбивка
    var monthlyIncome: [MonthlyAmount]
    var monthlyExpenses: [MonthlyAmount]
    var monthlySavings: [MonthlyAmount]
    var monthlyDebts: [MonthlyAmount]
    
    // Годовая статистика
    var transactionCount: Int
    var averageMonthlyIncome: Decimal
    var averageMonthlyExpenses: Decimal
    var savingsRate: Double
    var bestMonth: Int
    var worstMonth: Int
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    
    // MARK: - Initializer
    
    init(year: Int) {
        self.id = UUID()
        self.year = year
        self.totalIncome = 0
        self.totalExpenses = 0
        self.totalSavings = 0
        self.totalDebts = 0
        self.netBalance = 0
        
        // Инициализируем помесячные данные
        self.monthlyIncome = []
        self.monthlyExpenses = []
        self.monthlySavings = []
        self.monthlyDebts = []
        
        // Статистика
        self.transactionCount = 0
        self.averageMonthlyIncome = 0
        self.averageMonthlyExpenses = 0
        self.savingsRate = 0
        self.bestMonth = 1
        self.worstMonth = 1
        
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

// MARK: - Supporting Enums and Structs

enum BudgetItemType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case debt = "debt"
    case savings = "savings"
    
    var displayName: String {
        switch self {
        case .income: return "Поступления"
        case .expense: return "Расходы"
        case .debt: return "Долги"
        case .savings: return "Накопления"
        }
    }
    
    var color: String {
        switch self {
        case .income: return "#34C759"
        case .expense: return "#FF3B30"
        case .debt: return "#FF9500"
        case .savings: return "#007AFF"
        }
    }
}

struct MonthlyAmount: Codable, Hashable {
    let month: Int
    let amount: Decimal
    let monthName: String
    
    init(month: Int, amount: Decimal) {
        self.month = month
        self.amount = amount
        
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        
        let date = Calendar.current.date(from: DateComponents(month: month)) ?? Date()
        self.monthName = formatter.string(from: date).capitalized
    }
}

struct CategorySummary: Codable, Hashable {
    let categoryName: String
    let amount: Decimal
    let percentage: Double
    let transactionCount: Int
    let color: String
    
    init(categoryName: String, amount: Decimal, percentage: Double, transactionCount: Int, color: String = "#007AFF") {
        self.categoryName = categoryName
        self.amount = amount
        self.percentage = percentage
        self.transactionCount = transactionCount
        self.color = color
    }
}

// MARK: - Extensions

extension BudgetPlan: Validatable {
    func validate() throws {
        if year < 2020 || year > 2050 {
            throw ModelValidationError.invalidDate
        }
        
        if month < 1 || month > 12 {
            throw ModelValidationError.invalidDate
        }
        
        if currency.isEmpty {
            throw ModelValidationError.missingRequiredField("Валюта обязательна")
        }
    }
}

extension BudgetPlanItem: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if plannedAmount < 0 {
            throw ModelValidationError.negativeAmount
        }
        
        if actualAmount < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

extension DailyTransaction: Validatable {
    func validate() throws {
        if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.missingRequiredField("Категория обязательна")
        }
        
        if amount < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

// MARK: - Computed Properties

extension BudgetPlan {
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: startDate).capitalized
    }
    
    var totalPlannedIncome: Decimal {
        return income.plannedAmount + incomeItems.reduce(0) { $0 + $1.plannedAmount }
    }
    
    var totalActualIncome: Decimal {
        return income.actualAmount + incomeItems.reduce(0) { $0 + $1.actualAmount }
    }
    
    var totalPlannedExpenses: Decimal {
        return expenses.plannedAmount + expenseItems.reduce(0) { $0 + $1.plannedAmount }
    }
    
    var totalActualExpenses: Decimal {
        return expenses.actualAmount + expenseItems.reduce(0) { $0 + $1.actualAmount }
    }
    
    var totalPlannedSavings: Decimal {
        return savings.plannedAmount + savingsItems.reduce(0) { $0 + $1.plannedAmount }
    }
    
    var totalActualSavings: Decimal {
        return savings.actualAmount + savingsItems.reduce(0) { $0 + $1.actualAmount }
    }
    
    var plannedBalance: Decimal {
        return totalPlannedIncome - totalPlannedExpenses
    }
    
    var actualBalance: Decimal {
        return totalActualIncome - totalActualExpenses
    }
    
    var budgetVariance: Decimal {
        return actualBalance - plannedBalance
    }
    
    var expensesByCategory: [CategorySummary] {
        let groupedExpenses = Dictionary(grouping: dailyExpenses) { $0.category }
        let totalExpenses = dailyExpenses.reduce(0) { $0 + $1.amount }
        
        return groupedExpenses.compactMap { (category, transactions) in
            let amount = transactions.reduce(0) { $0 + $1.amount }
            let percentage = totalExpenses > 0 ? Double(amount / totalExpenses) * 100 : 0
            
            return CategorySummary(
                categoryName: category,
                amount: amount,
                percentage: percentage,
                transactionCount: transactions.count
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    var incomeByCategory: [CategorySummary] {
        let groupedIncome = Dictionary(grouping: dailyIncome) { $0.category }
        let totalIncome = dailyIncome.reduce(0) { $0 + $1.amount }
        
        return groupedIncome.compactMap { (category, transactions) in
            let amount = transactions.reduce(0) { $0 + $1.amount }
            let percentage = totalIncome > 0 ? Double(amount / totalIncome) * 100 : 0
            
            return CategorySummary(
                categoryName: category,
                amount: amount,
                percentage: percentage,
                transactionCount: transactions.count
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    func getExpensesForMonth(_ month: Int) -> [DailyTransaction] {
        return dailyExpenses.filter { Calendar.current.component(.month, from: $0.date) == month }
    }
    
    func getIncomeForMonth(_ month: Int) -> [DailyTransaction] {
        return dailyIncome.filter { Calendar.current.component(.month, from: $0.date) == month }
    }
}

extension BudgetPlanItem {
    
    var variance: Decimal {
        return actualAmount - plannedAmount
    }
    
    var variancePercentage: Double {
        guard plannedAmount > 0 else { return 0 }
        return Double(variance / plannedAmount) * 100
    }
    
    var isOverBudget: Bool {
        return actualAmount > plannedAmount
    }
    
    var isUnderBudget: Bool {
        return actualAmount < plannedAmount
    }
    
    var completionPercentage: Double {
        guard plannedAmount > 0 else { return 0 }
        return Double(actualAmount / plannedAmount) * 100
    }
    
    var formattedPlannedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: plannedAmount)) ?? "0 ₽"
    }
    
    var formattedActualAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: actualAmount)) ?? "0 ₽"
    }
    
    var formattedVariance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        let formattedAmount = formatter.string(from: NSDecimalNumber(decimal: abs(variance))) ?? "0 ₽"
        return variance >= 0 ? "+\(formattedAmount)" : "-\(formattedAmount)"
    }
}

extension MonthlyFinancialSummary {
    
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(totalSavings / totalIncome) * 100
    }
    
    var expenseToIncomeRatio: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(totalExpenses / totalIncome) * 100
    }
    
    var isPositiveBalance: Bool {
        return netBalance > 0
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return formatter.string(from: date).capitalized
    }
    
    var formattedNetBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: netBalance)) ?? "0 ₽"
    }
}

extension YearlyFinancialOverview {
    
    var overallSavingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(totalSavings / totalIncome) * 100
    }
    
    var bestMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        
        let date = Calendar.current.date(from: DateComponents(month: bestMonth)) ?? Date()
        return formatter.string(from: date).capitalized
    }
    
    var worstMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        
        let date = Calendar.current.date(from: DateComponents(month: worstMonth)) ?? Date()
        return formatter.string(from: date).capitalized
    }
    
    var formattedTotalIncome: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: totalIncome)) ?? "0 ₽"
    }
    
    var formattedTotalExpenses: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: totalExpenses)) ?? "0 ₽"
    }
    
    var formattedNetBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: netBalance)) ?? "0 ₽"
    }
} 