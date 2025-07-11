import Foundation
import SwiftData

// MARK: - Financial Goal Model

@Model
final class FinancialGoal: CloudKitSyncable, Timestampable, Categorizable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var type: FinancialGoalType
    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date
    var isCompleted: Bool
    var priority: GoalPriority
    
    // Progress tracking
    var milestones: [GoalMilestone]
    var autoSaveAmount: Decimal? // Автоматическое отложение
    var autoSaveFrequency: GoalAutoSaveFrequency?
    var lastAutoSave: Date?
    
    // Visual customization
    var icon: String // SF Symbol
    var color: String // Hex color
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var category: Category?
    @Relationship(deleteRule: .nullify) var linkedTransactions: [Transaction]
    @Relationship(deleteRule: .nullify) var linkedBudgets: [Budget]
    
    // MARK: - Initializer
    
    init(
        name: String,
        description: String? = nil,
        type: FinancialGoalType,
        targetAmount: Decimal,
        targetDate: Date,
        priority: GoalPriority = .medium,
        icon: String = "target",
        color: String = "#007AFF"
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.type = type
        self.targetAmount = targetAmount
        self.currentAmount = 0
        self.targetDate = targetDate
        self.isCompleted = false
        self.priority = priority
        self.milestones = []
        self.icon = icon
        self.color = color
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        self.linkedTransactions = []
        self.linkedBudgets = []
    }
}

// MARK: - Financial Goal Extensions

extension FinancialGoal: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if targetAmount <= 0 {
            throw ModelValidationError.negativeAmount
        }
        
        if targetDate <= Date() {
            throw ModelValidationError.invalidDate
        }
    }
}

extension FinancialGoal {
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1.0, Double(currentAmount / targetAmount))
    }
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var remainingAmount: Decimal {
        return max(0, targetAmount - currentAmount)
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        return max(0, calendar.dateComponents([.day], from: Date(), to: targetDate).day ?? 0)
    }
    
    var recommendedMonthlySaving: Decimal {
        let monthsRemaining = max(1, daysRemaining / 30)
        return remainingAmount / Decimal(monthsRemaining)
    }
    
    var isOnTrack: Bool {
        let timeProgress = 1.0 - (Double(daysRemaining) / Double(Calendar.current.dateComponents([.day], from: createdAt, to: targetDate).day ?? 1))
        return progress >= timeProgress
    }
    
    var status: GoalStatus {
        if isCompleted {
            return .completed
        }
        
        if Date() > targetDate {
            return progress >= 1.0 ? .completed : .overdue
        }
        
        if isOnTrack {
            return .onTrack
        } else {
            return .behindSchedule
        }
    }
    
    var formattedTargetAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: targetAmount)) ?? "\(targetAmount) ₽"
    }
    
    var formattedCurrentAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: currentAmount)) ?? "\(currentAmount) ₽"
    }
    
    var formattedRemainingAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: remainingAmount)) ?? "\(remainingAmount) ₽"
    }
    
    // MARK: - Goal Management
    
    func addProgress(_ amount: Decimal) {
        currentAmount += amount
        
        if currentAmount >= targetAmount && !isCompleted {
            isCompleted = true
        }
        
        updateTimestamp()
        markForSync()
    }
    
    func addMilestone(_ milestone: GoalMilestone) {
        milestones.append(milestone)
        updateTimestamp()
        markForSync()
    }
    
    func setupAutoSave(amount: Decimal, frequency: GoalAutoSaveFrequency) {
        autoSaveAmount = amount
        autoSaveFrequency = frequency
        updateTimestamp()
        markForSync()
    }
    
    func processAutoSave() -> Bool {
        guard let amount = autoSaveAmount,
              let frequency = autoSaveFrequency else { return false }
        
        let shouldAutoSave: Bool
        
        if let lastSave = lastAutoSave {
            shouldAutoSave = frequency.shouldExecute(since: lastSave)
        } else {
            shouldAutoSave = true
        }
        
        if shouldAutoSave {
            addProgress(amount)
            lastAutoSave = Date()
            return true
        }
        
        return false
    }
}

// MARK: - Bill Reminder Model

@Model
final class BillReminder: CloudKitSyncable, Timestampable, Categorizable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var amount: Decimal?
    var dueDate: Date
    var frequency: BillFrequency
    var isActive: Bool
    var isPaid: Bool
    
    // Notification settings
    var reminderDays: [Int] // Дни до даты для напоминаний
    var lastNotificationSent: Date?
    
    // Payment tracking
    var lastPaidDate: Date?
    var paymentHistory: [BillPayment]
    
    // Visual
    var icon: String
    var color: String
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var category: Category?
    var linkedTransactions: [Transaction]
    
    // MARK: - Initializer
    
    init(
        name: String,
        description: String? = nil,
        amount: Decimal? = nil,
        dueDate: Date,
        frequency: BillFrequency,
        reminderDays: [Int] = [7, 3, 1],
        icon: String = "doc.text",
        color: String = "#FF9500"
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.amount = amount
        self.dueDate = dueDate
        self.frequency = frequency
        self.isActive = true
        self.isPaid = false
        self.reminderDays = reminderDays
        self.paymentHistory = []
        self.icon = icon
        self.color = color
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        self.linkedTransactions = []
    }
}

// MARK: - Bill Reminder Extensions

extension BillReminder: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let amount = amount, amount < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

extension BillReminder {
    
    // MARK: - Computed Properties
    
    var daysUntilDue: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    var isOverdue: Bool {
        return !isPaid && Date() > dueDate
    }
    
    var shouldSendReminder: Bool {
        guard isActive && !isPaid else { return false }
        
        let daysToDue = daysUntilDue
        let shouldRemind = reminderDays.contains(daysToDue)
        
        // Проверяем, не отправляли ли уже уведомление сегодня
        if let lastNotification = lastNotificationSent {
            let calendar = Calendar.current
            return shouldRemind && !calendar.isDate(lastNotification, inSameDayAs: Date())
        }
        
        return shouldRemind
    }
    
    var nextDueDate: Date {
        return frequency.nextDate(from: dueDate)
    }
    
    var averageAmount: Decimal {
        guard !paymentHistory.isEmpty else { return amount ?? 0 }
        
        let total = paymentHistory.reduce(Decimal.zero) { $0 + $1.amount }
        return total / Decimal(paymentHistory.count)
    }
    
    var formattedAmount: String? {
        guard let amount = amount else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }
    
    // MARK: - Bill Management
    
    func markAsPaid(amount: Decimal? = nil, date: Date = Date()) {
        isPaid = true
        lastPaidDate = date
        
        let payment = BillPayment(
            amount: amount ?? self.amount ?? 0,
            date: date
        )
        paymentHistory.append(payment)
        
        updateTimestamp()
        markForSync()
    }
    
    func scheduleNext() {
        dueDate = nextDueDate
        isPaid = false
        lastNotificationSent = nil
        updateTimestamp()
        markForSync()
    }
    
    func markNotificationSent() {
        lastNotificationSent = Date()
        updateTimestamp()
        markForSync()
    }
}

// MARK: - Financial Insight Model

@Model
final class FinancialInsight: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var type: InsightType
    var title: String
    var description: String
    var impact: ImpactLevel
    var confidence: Double // 0.0 - 1.0
    var isActionable: Bool
    var suggestedActions: [String]
    var isRead: Bool
    var isArchived: Bool
    
    // Data context
    var relatedAmount: Decimal?
    var relatedPeriod: DateInterval?
    var metadata: [String: String] // Дополнительные данные
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var relatedCategory: Category?
    var relatedTransactions: [Transaction]
    var relatedBudget: Budget?
    var relatedGoal: FinancialGoal?
    
    // MARK: - Initializer
    
    init(
        type: InsightType,
        title: String,
        description: String,
        impact: ImpactLevel,
        confidence: Double = 1.0,
        isActionable: Bool = true,
        suggestedActions: [String] = []
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.impact = impact
        self.confidence = confidence
        self.isActionable = isActionable
        self.suggestedActions = suggestedActions
        self.isRead = false
        self.isArchived = false
        self.metadata = [:]
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        self.relatedTransactions = []
    }
}

// MARK: - Financial Insight Extensions

extension FinancialInsight: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if confidence < 0 || confidence > 1 {
            throw ModelValidationError.missingRequiredField("Уверенность должна быть от 0 до 1")
        }
    }
}

extension FinancialInsight {
    
    // MARK: - Computed Properties
    
    var priorityScore: Int {
        var score = 0
        
        switch impact {
        case .low: score += 1
        case .medium: score += 2
        case .high: score += 3
        case .critical: score += 4
        }
        
        score += Int(confidence * 2)
        
        if isActionable {
            score += 1
        }
        
        return score
    }
    
    var isRecentlyCreated: Bool {
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return daysSinceCreation <= 7
    }
    
    var formattedRelatedAmount: String? {
        guard let amount = relatedAmount else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }
    
    // MARK: - Insight Management
    
    func markAsRead() {
        isRead = true
        updateTimestamp()
        markForSync()
    }
    
    func archive() {
        isArchived = true
        updateTimestamp()
        markForSync()
    }
    
    func addMetadata(_ key: String, value: String) {
        metadata[key] = value
        updateTimestamp()
        markForSync()
    }
}

// MARK: - Budget Category Model

@Model
final class BudgetCategory: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var budgetAllocation: Decimal // Процент от общего бюджета
    var currentSpending: Decimal
    var isEssential: Bool // Обязательная категория
    var icon: String
    var color: String
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var parentCategory: Category?
    @Relationship(deleteRule: .nullify) var budgets: [Budget]
    @Relationship(deleteRule: .nullify) var transactions: [Transaction]
    
    // MARK: - Initializer
    
    init(
        name: String,
        description: String? = nil,
        budgetAllocation: Decimal,
        isEssential: Bool = false,
        icon: String = "folder",
        color: String = "#007AFF"
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.budgetAllocation = budgetAllocation
        self.currentSpending = 0
        self.isEssential = isEssential
        self.icon = icon
        self.color = color
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        self.budgets = []
        self.transactions = []
    }
}

// MARK: - Supporting Enums and Structs

enum FinancialGoalType: String, Codable, CaseIterable {
    case emergency = "emergency"
    case vacation = "vacation"
    case purchase = "purchase"
    case investment = "investment"
    case education = "education"
    case debt = "debt"
    case retirement = "retirement"
    case house = "house"
    case car = "car"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .emergency: return "Резервный фонд"
        case .vacation: return "Отпуск"
        case .purchase: return "Покупка"
        case .investment: return "Инвестиции"
        case .education: return "Образование"
        case .debt: return "Погашение долга"
        case .retirement: return "Пенсия"
        case .house: return "Жилье"
        case .car: return "Автомобиль"
        case .other: return "Другое"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .emergency: return "shield.fill"
        case .vacation: return "airplane"
        case .purchase: return "bag.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .education: return "graduationcap.fill"
        case .debt: return "creditcard"
        case .retirement: return "figure.seated.side"
        case .house: return "house.fill"
        case .car: return "car.fill"
        case .other: return "target"
        }
    }
}

enum GoalPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        case .urgent: return "Срочный"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#8E8E93"
        case .medium: return "#007AFF"
        case .high: return "#FF9500"
        case .urgent: return "#FF3B30"
        }
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case onTrack = "on_track"
    case behindSchedule = "behind_schedule"
    case completed = "completed"
    case overdue = "overdue"
    
    var displayName: String {
        switch self {
        case .onTrack: return "По плану"
        case .behindSchedule: return "Отстает от плана"
        case .completed: return "Завершена"
        case .overdue: return "Просрочена"
        }
    }
    
    var color: String {
        switch self {
        case .onTrack: return "#34C759"
        case .behindSchedule: return "#FF9500"
        case .completed: return "#34C759"
        case .overdue: return "#FF3B30"
        }
    }
}

struct GoalMilestone: Codable, Hashable {
    let amount: Decimal
    let date: Date
    let description: String?
    let isCompleted: Bool
    
    init(amount: Decimal, date: Date, description: String? = nil) {
        self.amount = amount
        self.date = date
        self.description = description
        self.isCompleted = false
    }
}

enum GoalAutoSaveFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case biweekly = "biweekly"
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневно"
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .biweekly: return "Каждые 2 недели"
        }
    }
    
    func shouldExecute(since lastExecution: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .daily:
            return !calendar.isDate(lastExecution, inSameDayAs: now)
        case .weekly:
            let weeksSince = calendar.dateComponents([.weekOfYear], from: lastExecution, to: now).weekOfYear ?? 0
            return weeksSince >= 1
        case .monthly:
            let monthsSince = calendar.dateComponents([.month], from: lastExecution, to: now).month ?? 0
            return monthsSince >= 1
        case .biweekly:
            let weeksSince = calendar.dateComponents([.weekOfYear], from: lastExecution, to: now).weekOfYear ?? 0
            return weeksSince >= 2
        }
    }
}

enum BillFrequency: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case oneTime = "one_time"
    
    var displayName: String {
        switch self {
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .quarterly: return "Ежеквартально"
        case .yearly: return "Ежегодно"
        case .oneTime: return "Одноразово"
        }
    }
    
    func nextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .oneTime:
            return date
        }
    }
}

struct BillPayment: Codable, Hashable {
    let amount: Decimal
    let date: Date
    
    init(amount: Decimal, date: Date) {
        self.amount = amount
        self.date = date
    }
}

enum InsightType: String, Codable, CaseIterable {
    case overspending = "overspending"
    case unusualExpense = "unusual_expense"
    case savingsOpportunity = "savings_opportunity"
    case budgetOptimization = "budget_optimization"
    case incomeVariation = "income_variation"
    case expensePattern = "expense_pattern"
    case goalProgress = "goal_progress"
    case billReminder = "bill_reminder"
    case categoryAnalysis = "category_analysis"
    case forecastWarning = "forecast_warning"
    
    var displayName: String {
        switch self {
        case .overspending: return "Превышение бюджета"
        case .unusualExpense: return "Необычная трата"
        case .savingsOpportunity: return "Возможность экономии"
        case .budgetOptimization: return "Оптимизация бюджета"
        case .incomeVariation: return "Изменение доходов"
        case .expensePattern: return "Паттерн трат"
        case .goalProgress: return "Прогресс цели"
        case .billReminder: return "Напоминание о счете"
        case .categoryAnalysis: return "Анализ категории"
        case .forecastWarning: return "Прогнозное предупреждение"
        }
    }
    
    var icon: String {
        switch self {
        case .overspending: return "exclamationmark.triangle.fill"
        case .unusualExpense: return "questionmark.circle.fill"
        case .savingsOpportunity: return "lightbulb.fill"
        case .budgetOptimization: return "slider.horizontal.3"
        case .incomeVariation: return "arrow.up.arrow.down.circle.fill"
        case .expensePattern: return "chart.bar.fill"
        case .goalProgress: return "target"
        case .billReminder: return "bell.fill"
        case .categoryAnalysis: return "chart.pie.fill"
        case .forecastWarning: return "exclamationmark.circle.fill"
        }
    }
}

enum ImpactLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Низкое"
        case .medium: return "Среднее"
        case .high: return "Высокое"
        case .critical: return "Критическое"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#8E8E93"
        case .medium: return "#007AFF"
        case .high: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }
}

// MARK: - Supporting Data Structures

struct CategorySummary {
    let category: Category
    let totalAmount: Decimal
    let transactionCount: Int
    let percentage: Double
    let averageAmount: Decimal
    let trend: TrendDirection
    
    enum TrendDirection {
        case increasing
        case decreasing
        case stable
    }
}

struct FinanceBalance {
    let income: Decimal
    let expenses: Decimal
    let period: DateInterval
    let transactionCount: Int
    let changeFromPreviousPeriod: Decimal?
    
    var balance: Decimal {
        return income - expenses
    }
    
    var isPositive: Bool {
        return balance >= 0
    }
    
    var savingsRate: Double {
        guard income > 0 else { return 0 }
        return Double(balance / income) * 100
    }
}

struct BalancePoint: Codable {
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