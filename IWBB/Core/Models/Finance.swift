import Foundation
import SwiftData

// MARK: - Transaction Model

@Model
final class Transaction: CloudKitSyncable, Timestampable, Categorizable, Identifiable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var type: TransactionType
    var title: String
    var description: String?
    var date: Date
    
    // Дополнительная информация
    var account: String? // Счет или карта
    var paymentMethod: PaymentMethod?
    var location: String? // Место совершения операции
    var receiptPhoto: String? // Путь к фото чека
    var notes: String? // Заметки пользователя
    var tags: [String]
    
    // Повторяющиеся операции
    var isRecurring: Bool
    var recurringPattern: TransactionRecurringPattern?
    var parentTransaction: Transaction? // Ссылка на родительскую операцию для повторяющихся
    
    // Валюта и курс
    var currency: String
    var exchangeRate: Decimal? // Курс к основной валюте
    var originalAmount: Decimal? // Сумма в оригинальной валюте
    var originalCurrency: String?
    
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
    var budget: Budget? // Связь с бюджетом
    
    // Связанные транзакции (например, перевод между счетами)
    var relatedTransaction: Transaction?
    
    // MARK: - Initializers
    
    init(
        amount: Decimal,
        type: TransactionType,
        title: String,
        description: String? = nil,
        date: Date = Date(),
        category: Category? = nil,
        account: String? = nil,
        currency: String = "RUB"
    ) {
        self.id = UUID()
        self.amount = amount
        self.type = type
        self.title = title
        self.description = description
        self.date = date
        self.category = category
        self.account = account
        self.currency = currency
        
        // Дополнительные свойства
        self.tags = []
        self.isRecurring = false
        
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

// MARK: - Transaction Extensions

extension Transaction: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if amount < 0 {
            throw ModelValidationError.negativeAmount
        }
        
        if currency.isEmpty {
            throw ModelValidationError.missingRequiredField("Валюта обязательна")
        }
    }
}

extension Transaction {
    
    // MARK: - Computed Properties
    
    /// Сумма в основной валюте пользователя
    var convertedAmount: Decimal {
        if let rate = exchangeRate, rate > 0 {
            return amount * rate
        }
        return amount
    }
    
    /// Форматированная сумма
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(currency)"
    }
    
    /// Форматированная сумма с учетом типа операции
    var signedFormattedAmount: String {
        let baseAmount = formattedAmount
        switch type {
        case .expense:
            return "-\(baseAmount)"
        case .income:
            return "+\(baseAmount)"
        case .transfer:
            return baseAmount
        }
    }
    
    /// Влияние на баланс (положительное или отрицательное)
    var balanceImpact: Decimal {
        switch type {
        case .income:
            return convertedAmount
        case .expense:
            return -convertedAmount
        case .transfer:
            return 0 // Перевод не влияет на общий баланс
        }
    }
    
    /// Является ли операция тратой
    var isExpense: Bool {
        return type == .expense
    }
    
    /// Является ли операция доходом
    var isIncome: Bool {
        return type == .income
    }
    
    // MARK: - Transaction Management
    
    /// Добавляет тег
    func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty && !tags.contains(cleanTag) {
            tags.append(cleanTag)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет тег
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет сумму
    func updateAmount(_ newAmount: Decimal) {
        amount = newAmount
        updateTimestamp()
        markForSync()
    }
    
    /// Создает связанную транзакцию (для переводов)
    func createTransferTransaction(
        toAccount: String,
        title: String? = nil
    ) -> Transaction {
        let transferTransaction = Transaction(
            amount: amount,
            type: .transfer,
            title: title ?? "Перевод на \(toAccount)",
            date: date,
            account: toAccount,
            currency: currency
        )
        
        transferTransaction.relatedTransaction = self
        transferTransaction.user = user
        self.relatedTransaction = transferTransaction
        
        return transferTransaction
    }
    
    /// Настраивает повторяющуюся операцию
    func setupRecurring(pattern: TransactionRecurringPattern) {
        isRecurring = true
        recurringPattern = pattern
        updateTimestamp()
        markForSync()
    }
    
    /// Создает следующую повторяющуюся транзакцию
    func createNextRecurringTransaction() -> Transaction? {
        guard isRecurring, let pattern = recurringPattern else { return nil }
        guard let nextDate = pattern.nextDate(from: date) else { return nil }
        
        let nextTransaction = Transaction(
            amount: amount,
            type: type,
            title: title,
            description: description,
            date: nextDate,
            category: category,
            account: account,
            currency: currency
        )
        
        nextTransaction.isRecurring = true
        nextTransaction.recurringPattern = pattern
        nextTransaction.parentTransaction = self
        nextTransaction.tags = tags
        nextTransaction.paymentMethod = paymentMethod
        nextTransaction.user = user
        
        return nextTransaction
    }
}

// MARK: - Budget Model

@Model
final class Budget: CloudKitSyncable, Timestampable, Categorizable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var limit: Decimal // Лимит бюджета
    var period: BudgetPeriod
    var currency: String
    
    // Временные параметры
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    
    // Настройки уведомлений
    var notificationsEnabled: Bool
    var warningThreshold: Double // Процент от лимита для предупреждения (0.0 - 1.0)
    var lastNotificationSent: Date?
    
    // Архивация
    var isArchived: Bool
    var archivedAt: Date?
    
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
    @Relationship(deleteRule: .nullify, inverse: \Transaction.budget) 
    var transactions: [Transaction]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        limit: Decimal,
        period: BudgetPeriod,
        currency: String = "RUB",
        category: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.limit = limit
        self.period = period
        self.currency = currency
        self.category = category
        
        // Временные параметры
        let now = Date()
        self.startDate = period.startDate(from: now)
        self.endDate = period.endDate(from: startDate)
        self.isActive = true
        
        // Уведомления
        self.notificationsEnabled = true
        self.warningThreshold = 0.8 // 80%
        
        // Архивация
        self.isArchived = false
        self.archivedAt = nil
        
        // Метаданные
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        // Relationships
        self.transactions = []
    }
}

// MARK: - Budget Extensions

extension Budget: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if limit <= 0 {
            throw ModelValidationError.missingRequiredField("Лимит должен быть больше 0")
        }
        
        if warningThreshold < 0 || warningThreshold > 1 {
            throw ModelValidationError.missingRequiredField("Порог предупреждения должен быть от 0 до 100%")
        }
        
        if endDate <= startDate {
            throw ModelValidationError.invalidDate
        }
    }
}

extension Budget {
    
    // MARK: - Computed Properties
    
    /// Потраченная сумма в текущем периоде
    var spent: Decimal {
        let now = Date()
        let currentPeriodTransactions = transactions.filter { transaction in
            transaction.type == .expense &&
            transaction.date >= startDate &&
            transaction.date <= endDate &&
            transaction.date <= now
        }
        
        return currentPeriodTransactions.reduce(0) { $0 + $1.convertedAmount }
    }
    
    /// Оставшаяся сумма
    var remaining: Decimal {
        return limit - spent
    }
    
    /// Прогресс использования бюджета (0.0 - 1.0+)
    var progress: Double {
        return Double(spent / limit)
    }
    
    /// Прогресс в процентах
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    /// Превышен ли бюджет
    var isOverBudget: Bool {
        return spent > limit
    }
    
    /// Нужно ли отправить предупреждение
    var shouldSendWarning: Bool {
        guard notificationsEnabled else { return false }
        
        let warningAmount = limit * Decimal(warningThreshold)
        let shouldWarn = spent >= warningAmount
        
        // Проверяем, не отправляли ли уже уведомление недавно
        if let lastNotification = lastNotificationSent {
            let hoursSinceLastNotification = Date().timeIntervalSince(lastNotification) / 3600
            return shouldWarn && hoursSinceLastNotification >= 24 // Не чаще раза в день
        }
        
        return shouldWarn
    }
    
    /// Средний расход в день
    var averageDailySpending: Decimal {
        let daysElapsed = max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 1)
        return spent / Decimal(daysElapsed)
    }
    
    /// Прогнозируемый расход на конец периода
    var projectedSpending: Decimal {
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        return averageDailySpending * Decimal(totalDays)
    }
    
    /// Рекомендуемый дневной лимит
    var recommendedDailyLimit: Decimal {
        let remainingDays = max(1, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 1)
        return remaining / Decimal(remainingDays)
    }
    
    /// Статус бюджета
    var status: BudgetStatus {
        if !isActive || isArchived {
            return .inactive
        }
        
        if Date() > endDate {
            return .expired
        }
        
        if isOverBudget {
            return .overBudget
        }
        
        if progress >= warningThreshold {
            return .nearLimit
        }
        
        return .onTrack
    }
    
    /// Форматированный лимит
    var formattedLimit: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: limit)) ?? "\(limit) \(currency)"
    }
    
    /// Форматированная потраченная сумма
    var formattedSpent: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: spent)) ?? "\(spent) \(currency)"
    }
    
    /// Форматированная оставшаяся сумма
    var formattedRemaining: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: remaining)) ?? "\(remaining) \(currency)"
    }
    
    // MARK: - Budget Management
    
    /// Обновляет лимит бюджета
    func updateLimit(_ newLimit: Decimal) {
        limit = newLimit
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет период бюджета
    func updatePeriod(_ newPeriod: BudgetPeriod) {
        period = newPeriod
        let now = Date()
        startDate = newPeriod.startDate(from: now)
        endDate = newPeriod.endDate(from: startDate)
        updateTimestamp()
        markForSync()
    }
    
    /// Активирует бюджет
    func activate() {
        isActive = true
        updateTimestamp()
        markForSync()
    }
    
    /// Деактивирует бюджет
    func deactivate() {
        isActive = false
        updateTimestamp()
        markForSync()
    }
    
    /// Отмечает отправку уведомления
    func markNotificationSent() {
        lastNotificationSent = Date()
        updateTimestamp()
        markForSync()
    }
    
    /// Сбрасывает бюджет на новый период
    func resetForNewPeriod() {
        let now = Date()
        startDate = period.startDate(from: now)
        endDate = period.endDate(from: startDate)
        lastNotificationSent = nil
        updateTimestamp()
        markForSync()
    }
}

// MARK: - Supporting Enums and Structs

enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
    
    var displayName: String {
        switch self {
        case .income: return "Доход"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
        }
    }
    
    var icon: String {
        switch self {
        case .income: return "arrow.up.circle.fill"
        case .expense: return "arrow.down.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .income: return "#34C759"
        case .expense: return "#FF3B30"
        case .transfer: return "#007AFF"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash = "cash"
    case card = "card"
    case bankTransfer = "bank_transfer"
    case digitalWallet = "digital_wallet"
    case check = "check"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .cash: return "Наличные"
        case .card: return "Карта"
        case .bankTransfer: return "Банковский перевод"
        case .digitalWallet: return "Электронный кошелек"
        case .check: return "Чек"
        case .other: return "Другое"
        }
    }
    
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .bankTransfer: return "building.columns"
        case .digitalWallet: return "iphone"
        case .check: return "doc.text"
        case .other: return "ellipsis.circle"
        }
    }
}

struct TransactionRecurringPattern: Codable, Hashable {
    var frequency: RecurringFrequency
    var interval: Int
    var endDate: Date?
    var maxOccurrences: Int?
    
    func nextDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
        }
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневно"
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .yearly: return "Ежегодно"
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .quarterly: return "Ежеквартально"
        case .yearly: return "Ежегодно"
        case .custom: return "Произвольный"
        }
    }
    
    func startDate(from date: Date) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)?.start ?? date
        case .quarterly:
            let month = calendar.component(.month, from: date)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            return calendar.date(from: DateComponents(
                year: calendar.component(.year, from: date),
                month: quarterStartMonth,
                day: 1
            )) ?? date
        case .yearly:
            return calendar.dateInterval(of: .year, for: date)?.start ?? date
        case .custom:
            return date
        }
    }
    
    func endDate(from startDate: Date) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        case .custom:
            return calendar.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        }
    }
}

enum BudgetStatus: String, Codable, CaseIterable {
    case onTrack = "on_track"
    case nearLimit = "near_limit"
    case overBudget = "over_budget"
    case expired = "expired"
    case inactive = "inactive"
    
    var displayName: String {
        switch self {
        case .onTrack: return "В рамках бюджета"
        case .nearLimit: return "Приближается к лимиту"
        case .overBudget: return "Превышен лимит"
        case .expired: return "Период истек"
        case .inactive: return "Неактивен"
        }
    }
    
    var color: String {
        switch self {
        case .onTrack: return "#34C759"
        case .nearLimit: return "#FF9500"
        case .overBudget: return "#FF3B30"
        case .expired: return "#8E8E93"
        case .inactive: return "#8E8E93"
        }
    }
}

// MARK: - Currency Model

@Model
final class Currency: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var code: String // ISO 4217 код валюты (USD, EUR, RUB)
    var name: String // Полное название валюты
    var symbol: String // Символ валюты ($, €, ₽)
    var exchangeRate: Decimal // Курс к базовой валюте
    var isBase: Bool // Является ли базовой валютой
    var isSupported: Bool // Поддерживается ли в приложении
    var lastUpdated: Date // Дата последнего обновления курса
    
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
        code: String,
        name: String,
        symbol: String,
        exchangeRate: Decimal = 1.0,
        isBase: Bool = false
    ) {
        self.code = code.uppercased()
        self.name = name
        self.symbol = symbol
        self.exchangeRate = exchangeRate
        self.isBase = isBase
        self.isSupported = true
        self.lastUpdated = Date()
        
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

// MARK: - Currency Extensions

extension Currency: Validatable {
    func validate() throws {
        if code.isEmpty || code.count != 3 {
            throw ModelValidationError.missingRequiredField("Код валюты должен состоять из 3 символов")
        }
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if symbol.isEmpty {
            throw ModelValidationError.missingRequiredField("Символ валюты обязателен")
        }
        
        if exchangeRate <= 0 {
            throw ModelValidationError.missingRequiredField("Курс валюты должен быть больше 0")
        }
    }
}

extension Currency {
    
    // MARK: - Computed Properties
    
    /// Форматированное отображение валюты
    var displayName: String {
        return "\(name) (\(code))"
    }
    
    /// Полное описание с курсом
    var fullDescription: String {
        if isBase {
            return "\(displayName) - Базовая валюта"
        } else {
            return "\(displayName) - \(exchangeRate) за 1 базовую единицу"
        }
    }
    
    /// Нужно ли обновить курс
    var needsRateUpdate: Bool {
        let hoursSinceUpdate = Date().timeIntervalSince(lastUpdated) / 3600
        return hoursSinceUpdate >= 24 // Обновляем раз в день
    }
    
    // MARK: - Currency Management
    
    /// Обновляет курс валюты
    func updateExchangeRate(_ newRate: Decimal) {
        exchangeRate = newRate
        lastUpdated = Date()
        updateTimestamp()
        markForSync()
    }
    
    /// Устанавливает валюту как базовую
    func setAsBase() {
        isBase = true
        exchangeRate = 1.0
        updateTimestamp()
        markForSync()
    }
    
    /// Убирает статус базовой валюты
    func removeBaseStatus() {
        isBase = false
        updateTimestamp()
        markForSync()
    }
    
    /// Конвертирует сумму в базовую валюту
    func convertToBase(_ amount: Decimal) -> Decimal {
        if isBase {
            return amount
        }
        return amount * exchangeRate
    }
    
    /// Конвертирует сумму из базовой валюты
    func convertFromBase(_ amount: Decimal) -> Decimal {
        if isBase {
            return amount
        }
        return amount / exchangeRate
    }
    
    /// Форматирует сумму в данной валюте
    func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.currencySymbol = symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        // Для российского рубля используем русскую локаль
        if code == "RUB" {
            formatter.locale = Locale(identifier: "ru_RU")
        }
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(symbol)"
    }
}

// MARK: - Predefined Currencies

extension Currency {
    
    /// Создает предустановленные валюты
    static func createDefaultCurrencies() -> [Currency] {
        return [
            Currency(
                code: "RUB",
                name: "Российский рубль",
                symbol: "₽",
                exchangeRate: 1.0,
                isBase: true
            ),
            Currency(
                code: "USD",
                name: "Доллар США",
                symbol: "$",
                exchangeRate: 0.011 // Примерный курс
            ),
            Currency(
                code: "EUR",
                name: "Евро",
                symbol: "€",
                exchangeRate: 0.010 // Примерный курс
            ),
            Currency(
                code: "GBP",
                name: "Британский фунт",
                symbol: "£",
                exchangeRate: 0.008 // Примерный курс
            ),
            Currency(
                code: "CNY",
                name: "Китайский юань",
                symbol: "¥",
                exchangeRate: 0.08 // Примерный курс
            ),
            Currency(
                code: "JPY",
                name: "Японская иена",
                symbol: "¥",
                exchangeRate: 1.6 // Примерный курс
            ),
            Currency(
                code: "KZT",
                name: "Казахстанский тенге",
                symbol: "₸",
                exchangeRate: 4.5 // Примерный курс
            ),
            Currency(
                code: "BYN",
                name: "Белорусский рубль",
                symbol: "Br",
                exchangeRate: 0.03 // Примерный курс
            )
        ]
    }
} 