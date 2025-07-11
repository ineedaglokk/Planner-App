import Foundation
import SwiftData
import UserNotifications

// MARK: - Bill Reminder Service Protocol

protocol BillReminderServiceProtocol {
    // MARK: - Core Bill Management
    func createBillReminder(_ bill: BillReminder) async throws
    func updateBillReminder(_ bill: BillReminder) async throws
    func deleteBillReminder(_ billId: UUID) async throws
    func getBillReminders() async throws -> [BillReminder]
    func getBillReminder(id: UUID) async throws -> BillReminder?
    
    // MARK: - Smart Detection
    func detectBillsFromTransactions() async throws -> [DetectedBill]
    func suggestBillFromTransaction(_ transaction: Transaction) async throws -> BillSuggestion?
    func analyzeBillPatterns() async throws -> [BillPattern]
    func identifyRecurringPayments() async throws -> [RecurringPayment]
    
    // MARK: - Intelligent Notifications
    func scheduleSmartNotifications() async throws
    func generatePersonalizedReminders(for bill: BillReminder) async throws -> [PersonalizedReminder]
    func optimizeNotificationTiming(for user: User) async throws -> OptimalNotificationTiming
    func sendProactiveAlerts() async throws
    
    // MARK: - Payment Optimization
    func suggestOptimalPaymentTiming(for bill: BillReminder) async throws -> PaymentTimingSuggestion
    func analyzePaymentHistory(for bill: BillReminder) async throws -> PaymentHistoryAnalysis
    func predictBillAmounts() async throws -> [BillAmountPrediction]
    func generatePaymentSchedule(for bills: [BillReminder]) async throws -> PaymentSchedule
    
    // MARK: - ML Analytics
    func trainBillDetectionModel(with transactions: [Transaction]) async throws
    func updatePatternRecognition(with newData: [Transaction]) async throws
    func analyzeBillCategories() async throws -> [BillCategoryAnalysis]
    func predictUpcomingBills(horizon: TimeInterval) async throws -> [BillPrediction]
    
    // MARK: - Automation & Integration
    func setupAutomaticBillTracking(for category: Category) async throws
    func integrateBankData(bankData: [BankTransaction]) async throws
    func syncWithCalendar() async throws
    func generateBillReports(period: DateInterval) async throws -> BillReport
    
    // MARK: - Risk Management
    func identifyMissedPayments() async throws -> [MissedPayment]
    func analyzeBillRisks() async throws -> [BillRisk]
    func suggestPaymentBuffering() async throws -> [BufferingSuggestion]
    func monitorBillChanges() async throws -> [BillChange]
    
    // MARK: - Initialization
    func initialize() async throws
}

// MARK: - Supporting Data Structures

struct DetectedBill {
    let id: UUID
    let merchantName: String
    let normalizedName: String
    let detectedCategory: Category?
    let averageAmount: Decimal
    let amountVariance: Decimal
    let frequency: DetectedFrequency
    let confidence: Double
    let lastSeen: Date
    let detectionMethod: DetectionMethod
    let relatedTransactions: [Transaction]
    let suggestedReminder: BillReminderSuggestion
    
    enum DetectedFrequency {
        case weekly(dayOfWeek: Int)
        case biweekly
        case monthly(dayOfMonth: Int?)
        case quarterly
        case annual
        case irregular
        
        var displayName: String {
            switch self {
            case .weekly(let day): return "Еженедельно (\(dayName(day)))"
            case .biweekly: return "Раз в две недели"
            case .monthly(let day): 
                if let day = day {
                    return "Ежемесячно (\(day) числа)"
                } else {
                    return "Ежемесячно"
                }
            case .quarterly: return "Ежеквартально"
            case .annual: return "Ежегодно"
            case .irregular: return "Нерегулярно"
            }
        }
        
        private func dayName(_ dayNumber: Int) -> String {
            let days = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
            return days[safe: dayNumber - 1] ?? "День \(dayNumber)"
        }
    }
    
    enum DetectionMethod {
        case merchantPattern
        case amountPattern
        case frequencyPattern
        case combinedPattern
        case userRule
        case machinelearning
        
        var displayName: String {
            switch self {
            case .merchantPattern: return "По мерчанту"
            case .amountPattern: return "По сумме"
            case .frequencyPattern: return "По частоте"
            case .combinedPattern: return "Комбинированный"
            case .userRule: return "Пользовательское правило"
            case .machinelearning: return "Машинное обучение"
            }
        }
    }
    
    struct BillReminderSuggestion {
        let suggestedName: String
        let suggestedAmount: Decimal?
        let suggestedDueDate: Date
        let suggestedFrequency: BillFrequency
        let suggestedReminderDays: [Int]
        let confidence: Double
    }
}

struct BillSuggestion {
    let transaction: Transaction
    let confidence: Double
    let reasoning: String
    let suggestedBillReminder: BillReminder
    let similarBills: [BillReminder]
    let actionRecommendation: ActionRecommendation
    
    enum ActionRecommendation {
        case createNew
        case addToExisting(BillReminder)
        case ignore
        case needsMoreData
    }
}

struct BillPattern {
    let id: UUID
    let patternType: PatternType
    let description: String
    let merchantNames: [String]
    let amountRange: AmountRange
    let frequency: FrequencyPattern
    let confidence: Double
    let examples: [Transaction]
    let suggestedCategory: Category?
    
    enum PatternType {
        case utility
        case subscription
        case loan
        case insurance
        case rent
        case telecom
        case streaming
        case gym
        case custom(String)
        
        var displayName: String {
            switch self {
            case .utility: return "Коммунальные услуги"
            case .subscription: return "Подписки"
            case .loan: return "Кредиты"
            case .insurance: return "Страхование"
            case .rent: return "Аренда"
            case .telecom: return "Связь"
            case .streaming: return "Стриминг"
            case .gym: return "Фитнес"
            case .custom(let name): return name
            }
        }
        
        var defaultCategory: String {
            switch self {
            case .utility: return "Коммунальные услуги"
            case .subscription: return "Подписки"
            case .loan: return "Кредиты и займы"
            case .insurance: return "Страхование"
            case .rent: return "Жилье"
            case .telecom: return "Связь"
            case .streaming: return "Развлечения"
            case .gym: return "Здоровье и фитнес"
            case .custom: return "Другое"
            }
        }
    }
    
    struct AmountRange {
        let minimum: Decimal
        let maximum: Decimal
        let average: Decimal
        let variance: Double
        
        var isFixed: Bool {
            return variance < 0.05 // Менее 5% отклонения
        }
    }
    
    struct FrequencyPattern {
        let frequency: DetectedBill.DetectedFrequency
        let consistency: Double // 0.0 - 1.0
        let lastOccurrence: Date
        let nextExpected: Date
    }
}

struct RecurringPayment {
    let id: UUID
    let merchantName: String
    let normalizedName: String
    let pattern: RecurringPattern
    let reliability: Double
    let riskLevel: RiskLevel
    let recommendations: [RecurringRecommendation]
    
    struct RecurringPattern {
        let frequency: DetectedBill.DetectedFrequency
        let averageAmount: Decimal
        let amountVariability: Double
        let timingConsistency: Double
        let lastPayment: Date
        let nextPredicted: Date
        let confidence: Double
    }
    
    enum RiskLevel {
        case low      // Стабильные платежи
        case medium   // Некоторая вариативность
        case high     // Нестабильные суммы/сроки
        case critical // Пропущенные платежи
        
        var color: String {
            switch self {
            case .low: return "#34C759"
            case .medium: return "#FF9500"
            case .high: return "#FF6B35"
            case .critical: return "#FF3B30"
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return "Низкий риск"
            case .medium: return "Средний риск"
            case .high: return "Высокий риск"
            case .critical: return "Критический риск"
            }
        }
    }
    
    struct RecurringRecommendation {
        let type: RecommendationType
        let description: String
        let priority: Priority
        let expectedBenefit: String
        
        enum RecommendationType {
            case createReminder
            case adjustAmount
            case changeFrequency
            case setupAutopay
            case negotiate
            case monitor
        }
        
        enum Priority {
            case low, medium, high, urgent
        }
    }
}

struct PersonalizedReminder {
    let billReminder: BillReminder
    let reminderType: ReminderType
    let optimalTiming: ReminderTiming
    let personalizedMessage: String
    let deliveryMethod: DeliveryMethod
    let urgency: UrgencyLevel
    let actionableSteps: [ActionableStep]
    
    enum ReminderType {
        case standard
        case earlyWarning
        case lastChance
        case overdue
        case proactive
        case seasonal
        
        var displayName: String {
            switch self {
            case .standard: return "Стандартное напоминание"
            case .earlyWarning: return "Раннее предупреждение"
            case .lastChance: return "Последний шанс"
            case .overdue: return "Просрочка"
            case .proactive: return "Проактивное"
            case .seasonal: return "Сезонное"
            }
        }
    }
    
    struct ReminderTiming {
        let scheduledDate: Date
        let preferredTime: Date
        let timezone: TimeZone
        let dayOfWeek: Int?
        let reasoning: String
    }
    
    enum DeliveryMethod {
        case push
        case email
        case sms
        case inApp
        case calendar
        
        var displayName: String {
            switch self {
            case .push: return "Push-уведомление"
            case .email: return "Email"
            case .sms: return "SMS"
            case .inApp: return "В приложении"
            case .calendar: return "Календарь"
            }
        }
    }
    
    enum UrgencyLevel {
        case low, medium, high, critical
        
        var color: String {
            switch self {
            case .low: return "#8E8E93"
            case .medium: return "#007AFF"
            case .high: return "#FF9500"
            case .critical: return "#FF3B30"
            }
        }
    }
    
    struct ActionableStep {
        let step: String
        let isRequired: Bool
        let estimatedTime: String
        let helpText: String?
    }
}

struct OptimalNotificationTiming {
    let user: User
    let optimalTimes: [OptimalTime]
    let avoidanceTimes: [AvoidanceTime]
    let personalizedSchedule: PersonalizedSchedule
    let effectiveness: TimingEffectiveness
    
    struct OptimalTime {
        let timeOfDay: Date
        let dayOfWeek: Int?
        let effectiveness: Double
        let reasoning: String
        let context: NotificationContext
        
        enum NotificationContext {
            case morning
            case workHours
            case evening
            case weekend
            case payday
            case billDue
        }
    }
    
    struct AvoidanceTime {
        let timeRange: DateInterval
        let reason: String
        let severity: AvoidanceSeverity
        
        enum AvoidanceSeverity {
            case mild, moderate, strong
        }
    }
    
    struct PersonalizedSchedule {
        let primarySlots: [TimeSlot]
        let backupSlots: [TimeSlot]
        let emergencySlots: [TimeSlot]
        
        struct TimeSlot {
            let time: Date
            let dayOfWeek: Int?
            let effectiveness: Double
            let priority: SlotPriority
            
            enum SlotPriority {
                case primary, secondary, fallback
            }
        }
    }
    
    struct TimingEffectiveness {
        let responseRate: Double
        let actionCompletionRate: Double
        let userSatisfaction: Double
        let overallScore: Double
    }
}

struct PaymentTimingSuggestion {
    let billReminder: BillReminder
    let suggestedPaymentDate: Date
    let reasoning: String
    let benefits: [TimingBenefit]
    let alternatives: [AlternativeOption]
    let cashFlowImpact: CashFlowImpact
    let riskAssessment: RiskAssessment
    
    struct TimingBenefit {
        let benefit: String
        let impact: ImpactLevel
        let quantification: String?
    }
    
    struct AlternativeOption {
        let paymentDate: Date
        let pros: [String]
        let cons: [String]
        let recommendationScore: Double
    }
    
    struct CashFlowImpact {
        let immediateImpact: Decimal
        let weeklyProjection: Decimal
        let monthlyProjection: Decimal
        let bufferRecommendation: Decimal
    }
    
    struct RiskAssessment {
        let lateFeeRisk: Double
        let creditScoreImpact: CreditImpact
        let cashFlowRisk: Double
        
        enum CreditImpact {
            case none, minimal, moderate, significant
        }
    }
}

struct PaymentHistoryAnalysis {
    let billReminder: BillReminder
    let paymentPatterns: [PaymentPattern]
    let timeliness: TimelinessAnalysis
    let amountConsistency: AmountConsistency
    let seasonalTrends: [SeasonalTrend]
    let predictiveInsights: [PredictiveInsight]
    
    struct PaymentPattern {
        let pattern: PatternType
        let frequency: Double
        let examples: [BillPayment]
        let reliability: Double
        
        enum PatternType {
            case alwaysOnTime
            case earlyPayer
            case lastMinute
            case frequent_late
            case inconsistent
        }
    }
    
    struct TimelinessAnalysis {
        let averageDaysEarly: Double
        let averageDaysLate: Double
        let onTimePercentage: Double
        let latePaymentTrend: TrendDirection
        
        enum TrendDirection {
            case improving, stable, deteriorating
        }
    }
    
    struct AmountConsistency {
        let isAmountConsistent: Bool
        let averageVariation: Decimal
        let overpaymentFrequency: Double
        let underpaymentFrequency: Double
    }
    
    struct SeasonalTrend {
        let season: Season
        let paymentBehavior: PaymentBehavior
        let amountVariation: Double
        
        enum Season {
            case spring, summer, fall, winter, holiday
        }
        
        enum PaymentBehavior {
            case earlier, later, moreVariable, moreConsistent
        }
    }
    
    struct PredictiveInsight {
        let insight: String
        let confidence: Double
        let timeframe: String
        let actionRecommendation: String
    }
}

struct BillAmountPrediction {
    let billReminder: BillReminder
    let predictedAmount: Decimal
    let confidence: Double
    let predictionRange: PredictionRange
    let methodology: PredictionMethodology
    let factors: [PredictionFactor]
    let nextDueDate: Date
    
    struct PredictionRange {
        let minimum: Decimal
        let maximum: Decimal
        let mostLikely: Decimal
        let standardDeviation: Double
    }
    
    enum PredictionMethodology {
        case historical_average
        case trending_analysis
        case seasonal_adjustment
        case machinelearning
        case composite
    }
    
    struct PredictionFactor {
        let factor: String
        let weight: Double
        let impact: FactorImpact
        
        enum FactorImpact {
            case increase, decrease, neutral
        }
    }
}

struct PaymentSchedule {
    let period: DateInterval
    let scheduledPayments: [ScheduledPayment]
    let totalAmount: Decimal
    let cashFlowProjection: [CashFlowPoint]
    let optimizationSuggestions: [OptimizationSuggestion]
    let riskAssessment: ScheduleRiskAssessment
    
    struct ScheduledPayment {
        let billReminder: BillReminder
        let scheduledDate: Date
        let amount: Decimal
        let priority: PaymentPriority
        let flexibility: DateFlexibility
        
        enum PaymentPriority {
            case critical, high, medium, low
        }
        
        struct DateFlexibility {
            let canMoveEarlier: Int // дни
            let canMoveLater: Int // дни
            let penaltyForLateness: Decimal?
        }
    }
    
    struct CashFlowPoint {
        let date: Date
        let projectedBalance: Decimal
        let billPayments: Decimal
        let riskLevel: RiskLevel
        
        enum RiskLevel {
            case safe, caution, risky, critical
        }
    }
    
    struct OptimizationSuggestion {
        let type: OptimizationType
        let description: String
        let expectedBenefit: Decimal
        let effort: EffortLevel
        
        enum OptimizationType {
            case reschedule, consolidate, negotiate, automate
        }
        
        enum EffortLevel {
            case low, medium, high
        }
    }
    
    struct ScheduleRiskAssessment {
        let overallRisk: RiskLevel
        let criticalDates: [Date]
        let recommendedBuffer: Decimal
        let contingencyPlan: String
        
        enum RiskLevel {
            case low, medium, high, critical
        }
    }
}

struct BillCategoryAnalysis {
    let category: Category
    let billCount: Int
    let totalMonthlyAmount: Decimal
    let averageBillAmount: Decimal
    let paymentReliability: Double
    let optimizationPotential: OptimizationPotential
    let recommendations: [CategoryRecommendation]
    
    struct OptimizationPotential {
        let savingsOpportunity: Decimal
        let consolidationPossible: Bool
        let negotiationPotential: Double
        let automationBenefit: Double
    }
    
    struct CategoryRecommendation {
        let type: RecommendationType
        let description: String
        let potentialSavings: Decimal?
        let effort: EffortLevel
        
        enum RecommendationType {
            case consolidate, negotiate, automate, review, cancel
        }
        
        enum EffortLevel {
            case low, medium, high
        }
    }
}

struct BillPrediction {
    let billReminder: BillReminder?
    let predictedDate: Date
    let predictedAmount: Decimal
    let confidence: Double
    let predictionType: PredictionType
    let triggers: [PredictionTrigger]
    
    enum PredictionType {
        case regular_occurrence
        case seasonal_variation
        case emergency_bill
        case new_service
        case rate_change
    }
    
    struct PredictionTrigger {
        let trigger: String
        let probability: Double
        let impact: ImpactLevel
    }
}

struct BillReport {
    let period: DateInterval
    let summary: BillSummary
    let categoryBreakdown: [CategoryBreakdown]
    let paymentAnalysis: PaymentAnalysis
    let trends: [BillTrend]
    let recommendations: [BillRecommendation]
    
    struct BillSummary {
        let totalBills: Int
        let totalAmount: Decimal
        let paidOnTime: Int
        let paidLate: Int
        let missed: Int
        let averagePaymentDelay: Double
    }
    
    struct CategoryBreakdown {
        let category: Category
        let billCount: Int
        let totalAmount: Decimal
        let percentageOfTotal: Double
        let changeFromPrevious: Double
    }
    
    struct PaymentAnalysis {
        let onTimePercentage: Double
        let averageLateDays: Double
        let lateFeesPaid: Decimal
        let improvementOpportunities: [String]
    }
    
    struct BillTrend {
        let metric: String
        let direction: TrendDirection
        let magnitude: Double
        let significance: TrendSignificance
        
        enum TrendDirection {
            case increasing, decreasing, stable
        }
        
        enum TrendSignificance {
            case insignificant, minor, moderate, significant
        }
    }
    
    struct BillRecommendation {
        let recommendation: String
        let category: Category?
        let priority: Priority
        let expectedImpact: String
        
        enum Priority {
            case low, medium, high, urgent
        }
    }
}

struct MissedPayment {
    let billReminder: BillReminder
    let dueDate: Date
    let daysOverdue: Int
    let predictedAmount: Decimal
    let lateFee: Decimal?
    let creditImpact: CreditImpact
    let urgency: UrgencyLevel
    let actionPlan: ActionPlan
    
    enum CreditImpact {
        case none, minimal, moderate, significant, severe
        
        var displayName: String {
            switch self {
            case .none: return "Без влияния"
            case .minimal: return "Минимальное влияние"
            case .moderate: return "Умеренное влияние"
            case .significant: return "Значительное влияние"
            case .severe: return "Серьезное влияние"
            }
        }
    }
    
    enum UrgencyLevel {
        case low, medium, high, critical
    }
    
    struct ActionPlan {
        let immediateActions: [String]
        let preventionMeasures: [String]
        let deadlines: [ActionDeadline]
        
        struct ActionDeadline {
            let action: String
            let deadline: Date
            let consequence: String
        }
    }
}

struct BillRisk {
    let billReminder: BillReminder
    let riskType: RiskType
    let probability: Double
    let impact: ImpactLevel
    let mitigationStrategies: [MitigationStrategy]
    let monitoringRequired: Bool
    
    enum RiskType {
        case late_payment
        case amount_increase
        case service_termination
        case billing_error
        case forgotten_payment
        case cash_flow_issue
        
        var displayName: String {
            switch self {
            case .late_payment: return "Просрочка платежа"
            case .amount_increase: return "Увеличение суммы"
            case .service_termination: return "Прекращение услуги"
            case .billing_error: return "Ошибка в счете"
            case .forgotten_payment: return "Забытый платеж"
            case .cash_flow_issue: return "Проблема с денежным потоком"
            }
        }
    }
    
    struct MitigationStrategy {
        let strategy: String
        let effectiveness: Double
        let implementation: String
        let cost: ImplementationCost
        
        enum ImplementationCost {
            case free, low, medium, high
        }
    }
}

struct BufferingSuggestion {
    let billReminder: BillReminder
    let recommendedBuffer: Decimal
    let bufferType: BufferType
    let reasoning: String
    let implementation: BufferImplementation
    
    enum BufferType {
        case time_buffer    // Платить раньше
        case amount_buffer  // Откладывать больше
        case emergency_fund // Экстренный фонд
        case automatic_top_up // Автодоплата
    }
    
    struct BufferImplementation {
        let method: String
        let automation: AutomationLevel
        let effort: EffortLevel
        
        enum AutomationLevel {
            case manual, semi_automatic, fully_automatic
        }
        
        enum EffortLevel {
            case minimal, low, medium, high
        }
    }
}

struct BillChange {
    let billReminder: BillReminder
    let changeType: ChangeType
    let oldValue: String
    let newValue: String
    let detectedAt: Date
    let confidence: Double
    let actionRequired: Bool
    let suggestions: [ChangeSuggestion]
    
    enum ChangeType {
        case amount_increase
        case amount_decrease
        case due_date_change
        case frequency_change
        case merchant_change
        case service_added
        case service_removed
        
        var displayName: String {
            switch self {
            case .amount_increase: return "Увеличение суммы"
            case .amount_decrease: return "Уменьшение суммы"
            case .due_date_change: return "Изменение даты"
            case .frequency_change: return "Изменение частоты"
            case .merchant_change: return "Изменение поставщика"
            case .service_added: return "Добавлена услуга"
            case .service_removed: return "Удалена услуга"
            }
        }
    }
    
    struct ChangeSuggestion {
        let suggestion: String
        let action: SuggestedAction
        let priority: Priority
        
        enum SuggestedAction {
            case update_reminder
            case verify_change
            case investigate
            case negotiate
            case cancel_service
        }
        
        enum Priority {
            case low, medium, high, urgent
        }
    }
}

// MARK: - External Data Structures

struct BankTransaction {
    let id: String
    let amount: Decimal
    let description: String
    let date: Date
    let merchant: String?
    let category: String?
    let account: String
    let type: TransactionType
    let metadata: [String: Any]
    
    enum TransactionType {
        case debit, credit, transfer
    }
}

// MARK: - Bill Reminder Service Implementation

final class BillReminderService: BillReminderServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    private let categorizationService: CategorizationServiceProtocol
    
    // ML & Analytics Engines
    private let billDetectionEngine: BillDetectionEngine
    private let patternAnalysisEngine: BillPatternAnalysisEngine
    private let notificationOptimizer: NotificationOptimizer
    private let paymentAnalyzer: PaymentAnalyzer
    private let riskAssessmentEngine: BillRiskAssessmentEngine
    
    // State Management
    private var isInitialized = false
    private var billReminders: [BillReminder] = []
    private var detectionRules: [DetectionRule] = []
    private var userPreferences: NotificationPreferences?
    
    // Configuration
    private let serviceConfig: BillReminderConfiguration
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        transactionRepository: TransactionRepositoryProtocol,
        notificationService: NotificationServiceProtocol,
        categorizationService: CategorizationServiceProtocol
    ) {
        self.dataService = dataService
        self.transactionRepository = transactionRepository
        self.notificationService = notificationService
        self.categorizationService = categorizationService
        
        // Инициализируем движки
        self.billDetectionEngine = BillDetectionEngine()
        self.patternAnalysisEngine = BillPatternAnalysisEngine()
        self.notificationOptimizer = NotificationOptimizer()
        self.paymentAnalyzer = PaymentAnalyzer()
        self.riskAssessmentEngine = BillRiskAssessmentEngine()
        
        // Конфигурация
        self.serviceConfig = BillReminderConfiguration()
    }
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Инициализируем все движки
        await billDetectionEngine.initialize()
        await patternAnalysisEngine.initialize()
        await notificationOptimizer.initialize()
        await paymentAnalyzer.initialize()
        await riskAssessmentEngine.initialize()
        
        // Загружаем данные
        try await loadBillReminders()
        try await loadDetectionRules()
        try await loadUserPreferences()
        
        // Обучаем модели на существующих данных
        try await trainInitialModels()
        
        isInitialized = true
    }
    
    // MARK: - Core Bill Management
    
    func createBillReminder(_ bill: BillReminder) async throws {
        try bill.validate()
        
        try await dataService.save(bill)
        billReminders.append(bill)
        
        // Планируем уведомления
        let reminders = try await generatePersonalizedReminders(for: bill)
        for reminder in reminders {
            await scheduleNotification(for: reminder)
        }
        
        // Обновляем модели с новыми данными
        await updateDetectionModels(with: bill)
    }
    
    func updateBillReminder(_ bill: BillReminder) async throws {
        try bill.validate()
        
        bill.updateTimestamp()
        bill.markForSync()
        
        try await dataService.save(bill)
        
        // Обновляем локальный массив
        if let index = billReminders.firstIndex(where: { $0.id == bill.id }) {
            billReminders[index] = bill
        }
        
        // Перепланируем уведомления
        await rescheduleNotifications(for: bill)
    }
    
    func deleteBillReminder(_ billId: UUID) async throws {
        guard let bill = try await getBillReminder(id: billId) else {
            throw BillReminderError.billNotFound
        }
        
        try await dataService.delete(bill)
        billReminders.removeAll { $0.id == billId }
        
        // Отменяем уведомления
        await cancelNotifications(for: bill)
    }
    
    func getBillReminders() async throws -> [BillReminder] {
        return billReminders
    }
    
    func getBillReminder(id: UUID) async throws -> BillReminder? {
        return billReminders.first { $0.id == id }
    }
    
    // MARK: - Smart Detection
    
    func detectBillsFromTransactions() async throws -> [DetectedBill] {
        let transactions = try await transactionRepository.fetchTransactions()
        
        return await billDetectionEngine.detectBills(from: transactions)
    }
    
    func suggestBillFromTransaction(_ transaction: Transaction) async throws -> BillSuggestion? {
        // Анализируем транзакцию на предмет счетов
        let detectionResult = await billDetectionEngine.analyzeSingleTransaction(transaction)
        
        guard detectionResult.confidence > serviceConfig.suggestionThreshold else {
            return nil
        }
        
        // Ищем похожие существующие счета
        let similarBills = findSimilarBills(to: transaction)
        
        // Определяем рекомендуемое действие
        let actionRecommendation = determineActionRecommendation(
            transaction: transaction,
            detectionResult: detectionResult,
            similarBills: similarBills
        )
        
        return BillSuggestion(
            transaction: transaction,
            confidence: detectionResult.confidence,
            reasoning: detectionResult.reasoning,
            suggestedBillReminder: detectionResult.suggestedBill,
            similarBills: similarBills,
            actionRecommendation: actionRecommendation
        )
    }
    
    func analyzeBillPatterns() async throws -> [BillPattern] {
        let transactions = try await transactionRepository.fetchTransactions()
        
        return await patternAnalysisEngine.analyzePatterns(in: transactions)
    }
    
    func identifyRecurringPayments() async throws -> [RecurringPayment] {
        let transactions = try await transactionRepository.fetchTransactions()
        
        return await patternAnalysisEngine.identifyRecurringPayments(in: transactions)
    }
    
    // MARK: - Intelligent Notifications
    
    func scheduleSmartNotifications() async throws {
        // Получаем оптимальное время уведомлений для пользователя
        guard let user = await getCurrentUser() else { return }
        
        let optimalTiming = try await optimizeNotificationTiming(for: user)
        
        // Планируем уведомления для всех активных счетов
        for bill in billReminders.filter({ $0.isActive }) {
            let personalizedReminders = try await generatePersonalizedReminders(for: bill)
            
            for reminder in personalizedReminders {
                await scheduleOptimizedNotification(reminder: reminder, timing: optimalTiming)
            }
        }
    }
    
    func generatePersonalizedReminders(for bill: BillReminder) async throws -> [PersonalizedReminder] {
        var reminders: [PersonalizedReminder] = []
        
        // Анализируем историю платежей
        let paymentHistory = try await analyzePaymentHistory(for: bill)
        
        // Определяем оптимальные времена напоминаний
        let optimalTimes = await calculateOptimalReminderTimes(for: bill, history: paymentHistory)
        
        // Создаем персонализированные напоминания
        for (index, reminderDay) in bill.reminderDays.enumerated() {
            let reminderType = determineReminderType(daysBeforeDue: reminderDay, history: paymentHistory)
            let timing = optimalTimes[safe: index] ?? defaultReminderTiming(daysBeforeDue: reminderDay)
            let message = generatePersonalizedMessage(for: bill, type: reminderType, history: paymentHistory)
            
            let reminder = PersonalizedReminder(
                billReminder: bill,
                reminderType: reminderType,
                optimalTiming: timing,
                personalizedMessage: message,
                deliveryMethod: preferredDeliveryMethod(for: reminderType),
                urgency: calculateUrgency(for: reminderType, bill: bill),
                actionableSteps: generateActionableSteps(for: bill, reminderType: reminderType)
            )
            
            reminders.append(reminder)
        }
        
        return reminders
    }
    
    func optimizeNotificationTiming(for user: User) async throws -> OptimalNotificationTiming {
        return await notificationOptimizer.optimizeForUser(user)
    }
    
    func sendProactiveAlerts() async throws {
        // Проверяем риски пропущенных платежей
        let missedPayments = try await identifyMissedPayments()
        
        for missedPayment in missedPayments {
            await sendMissedPaymentAlert(missedPayment)
        }
        
        // Проверяем изменения в счетах
        let billChanges = try await monitorBillChanges()
        
        for change in billChanges where change.actionRequired {
            await sendBillChangeAlert(change)
        }
        
        // Проверяем приближающиеся большие платежи
        let upcomingLargeBills = await identifyUpcomingLargeBills()
        
        for largeBill in upcomingLargeBills {
            await sendLargeBillAlert(largeBill)
        }
    }
    
    // MARK: - Payment Optimization
    
    func suggestOptimalPaymentTiming(for bill: BillReminder) async throws -> PaymentTimingSuggestion {
        return await paymentAnalyzer.suggestOptimalTiming(for: bill)
    }
    
    func analyzePaymentHistory(for bill: BillReminder) async throws -> PaymentHistoryAnalysis {
        return await paymentAnalyzer.analyzeHistory(for: bill)
    }
    
    func predictBillAmounts() async throws -> [BillAmountPrediction] {
        var predictions: [BillAmountPrediction] = []
        
        for bill in billReminders.filter({ $0.isActive }) {
            let prediction = await paymentAnalyzer.predictAmount(for: bill)
            predictions.append(prediction)
        }
        
        return predictions
    }
    
    func generatePaymentSchedule(for bills: [BillReminder]) async throws -> PaymentSchedule {
        return await paymentAnalyzer.generatePaymentSchedule(for: bills)
    }
    
    // MARK: - ML Analytics
    
    func trainBillDetectionModel(with transactions: [Transaction]) async throws {
        await billDetectionEngine.trainModel(with: transactions)
    }
    
    func updatePatternRecognition(with newData: [Transaction]) async throws {
        await patternAnalysisEngine.updatePatterns(with: newData)
    }
    
    func analyzeBillCategories() async throws -> [BillCategoryAnalysis] {
        return await patternAnalysisEngine.analyzeBillCategories(bills: billReminders)
    }
    
    func predictUpcomingBills(horizon: TimeInterval) async throws -> [BillPrediction] {
        return await billDetectionEngine.predictUpcomingBills(horizon: horizon)
    }
    
    // MARK: - Automation & Integration
    
    func setupAutomaticBillTracking(for category: Category) async throws {
        // Создаем правило автоматического отслеживания
        let rule = DetectionRule(
            category: category,
            autoCreateReminders: true,
            confidence_threshold: serviceConfig.autoTrackingThreshold
        )
        
        detectionRules.append(rule)
        try await saveDetectionRules()
    }
    
    func integrateBankData(bankData: [BankTransaction]) async throws {
        // Конвертируем банковские транзакции в формат приложения
        let convertedTransactions = bankData.map { convertBankTransaction($0) }
        
        // Анализируем на предмет новых счетов
        for transaction in convertedTransactions {
            if let suggestion = try await suggestBillFromTransaction(transaction) {
                if suggestion.actionRecommendation == .createNew && suggestion.confidence > serviceConfig.autoCreationThreshold {
                    try await createBillReminder(suggestion.suggestedBillReminder)
                }
            }
        }
    }
    
    func syncWithCalendar() async throws {
        // Синхронизация с календарем пользователя
        for bill in billReminders.filter({ $0.isActive }) {
            await createCalendarEvent(for: bill)
        }
    }
    
    func generateBillReports(period: DateInterval) async throws -> BillReport {
        return await paymentAnalyzer.generateReport(for: period, bills: billReminders)
    }
    
    // MARK: - Risk Management
    
    func identifyMissedPayments() async throws -> [MissedPayment] {
        return await riskAssessmentEngine.identifyMissedPayments(bills: billReminders)
    }
    
    func analyzeBillRisks() async throws -> [BillRisk] {
        return await riskAssessmentEngine.analyzeRisks(bills: billReminders)
    }
    
    func suggestPaymentBuffering() async throws -> [BufferingSuggestion] {
        return await riskAssessmentEngine.suggestBuffering(bills: billReminders)
    }
    
    func monitorBillChanges() async throws -> [BillChange] {
        return await riskAssessmentEngine.monitorChanges(bills: billReminders)
    }
}

// MARK: - Supporting Classes

class BillDetectionEngine {
    private var detectionModel: BillDetectionModel?
    private var merchantDatabase: [String: MerchantInfo] = [:]
    
    func initialize() async {
        detectionModel = BillDetectionModel()
        await loadMerchantDatabase()
    }
    
    func detectBills(from transactions: [Transaction]) async -> [DetectedBill] {
        var detectedBills: [DetectedBill] = []
        
        // Группируем транзакции по мерчантам
        let merchantGroups = Dictionary(grouping: transactions) { 
            normalizeMerchantName($0.title) 
        }
        
        for (merchantName, merchantTransactions) in merchantGroups {
            if let detectedBill = await analyzeTransactionGroup(merchantName: merchantName, transactions: merchantTransactions) {
                detectedBills.append(detectedBill)
            }
        }
        
        return detectedBills.sorted { $0.confidence > $1.confidence }
    }
    
    func analyzeSingleTransaction(_ transaction: Transaction) async -> (confidence: Double, reasoning: String, suggestedBill: BillReminder) {
        // Анализ одной транзакции
        let confidence = await calculateBillProbability(for: transaction)
        let reasoning = generateReasoning(for: transaction, confidence: confidence)
        let suggestedBill = createSuggestedBill(from: transaction)
        
        return (confidence, reasoning, suggestedBill)
    }
    
    func predictUpcomingBills(horizon: TimeInterval) async -> [BillPrediction] {
        // Предсказание предстоящих счетов
        return []
    }
    
    func trainModel(with transactions: [Transaction]) async {
        // Обучение модели обнаружения счетов
        guard let model = detectionModel else { return }
        
        let trainingData = prepareTrainingData(from: transactions)
        await model.train(with: trainingData)
    }
    
    private func analyzeTransactionGroup(merchantName: String, transactions: [Transaction]) async -> DetectedBill? {
        guard transactions.count >= 2 else { return nil }
        
        // Анализируем частоту
        let frequency = detectFrequency(in: transactions)
        
        // Анализируем суммы
        let amounts = transactions.map { $0.amount }
        let averageAmount = amounts.reduce(0, +) / Decimal(amounts.count)
        let amountVariance = calculateVariance(amounts)
        
        // Определяем уверенность
        let confidence = calculateDetectionConfidence(
            frequency: frequency,
            amountVariance: amountVariance,
            transactionCount: transactions.count
        )
        
        guard confidence > 0.6 else { return nil }
        
        // Создаем детектированный счет
        return DetectedBill(
            id: UUID(),
            merchantName: merchantName,
            normalizedName: normalizeMerchantName(merchantName),
            detectedCategory: nil, // TODO: определить категорию
            averageAmount: averageAmount,
            amountVariance: amountVariance,
            frequency: frequency,
            confidence: confidence,
            lastSeen: transactions.max { $0.date < $1.date }?.date ?? Date(),
            detectionMethod: .merchantPattern,
            relatedTransactions: transactions,
            suggestedReminder: createBillReminderSuggestion(
                merchantName: merchantName,
                averageAmount: averageAmount,
                frequency: frequency
            )
        )
    }
    
    private func detectFrequency(in transactions: [Transaction]) -> DetectedBill.DetectedFrequency {
        let sortedTransactions = transactions.sorted { $0.date < $1.date }
        guard sortedTransactions.count >= 2 else { return .irregular }
        
        var intervals: [TimeInterval] = []
        for i in 1..<sortedTransactions.count {
            let interval = sortedTransactions[i].date.timeIntervalSince(sortedTransactions[i-1].date)
            intervals.append(interval)
        }
        
        let averageInterval = intervals.reduce(0, +) / Double(intervals.count)
        let dayInterval = averageInterval / (24 * 3600)
        
        switch dayInterval {
        case 6...8: return .weekly(dayOfWeek: Calendar.current.component(.weekday, from: sortedTransactions.last!.date))
        case 13...15: return .biweekly
        case 28...32: return .monthly(dayOfMonth: Calendar.current.component(.day, from: sortedTransactions.last!.date))
        case 88...95: return .quarterly
        case 360...370: return .annual
        default: return .irregular
        }
    }
    
    private func calculateVariance(_ amounts: [Decimal]) -> Decimal {
        guard amounts.count > 1 else { return 0 }
        
        let average = amounts.reduce(0, +) / Decimal(amounts.count)
        let squaredDifferences = amounts.map { pow(Double(($0 - average) as NSDecimalNumber), 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(amounts.count - 1)
        
        return Decimal(sqrt(variance))
    }
    
    private func calculateDetectionConfidence(frequency: DetectedBill.DetectedFrequency, amountVariance: Decimal, transactionCount: Int) -> Double {
        var confidence = 0.0
        
        // Бонус за регулярность
        switch frequency {
        case .weekly, .monthly: confidence += 0.4
        case .biweekly, .quarterly: confidence += 0.3
        case .annual: confidence += 0.2
        case .irregular: confidence += 0.1
        }
        
        // Бонус за консистентность сумм
        let amountConsistency = 1.0 - min(1.0, Double(amountVariance) / 1000.0)
        confidence += amountConsistency * 0.3
        
        // Бонус за количество транзакций
        let countBonus = min(0.3, Double(transactionCount) * 0.05)
        confidence += countBonus
        
        return min(1.0, confidence)
    }
    
    private func calculateBillProbability(for transaction: Transaction) async -> Double {
        var probability = 0.0
        
        // Проверяем по базе мерчантов
        if let merchantInfo = merchantDatabase[normalizeMerchantName(transaction.title)] {
            probability += 0.6
        }
        
        // Проверяем по ключевым словам
        let billKeywords = ["счет", "оплата", "платеж", "services", "bill", "payment", "subscription"]
        for keyword in billKeywords {
            if transaction.title.lowercased().contains(keyword) {
                probability += 0.2
                break
            }
        }
        
        // Проверяем регулярность сумм
        if await isAmountRegular(transaction.amount, merchant: transaction.title) {
            probability += 0.2
        }
        
        return min(1.0, probability)
    }
    
    private func generateReasoning(for transaction: Transaction, confidence: Double) -> String {
        if confidence > 0.8 {
            return "Высокая вероятность счета на основе анализа мерчанта и суммы"
        } else if confidence > 0.6 {
            return "Средняя вероятность счета, рекомендуется проверка"
        } else {
            return "Низкая вероятность счета"
        }
    }
    
    private func createSuggestedBill(from transaction: Transaction) -> BillReminder {
        return BillReminder(
            name: transaction.title,
            description: "Автоматически предложенный счет",
            amount: transaction.amount,
            dueDate: Calendar.current.date(byAdding: .month, value: 1, to: transaction.date) ?? Date(),
            frequency: .monthly
        )
    }
    
    private func createBillReminderSuggestion(merchantName: String, averageAmount: Decimal, frequency: DetectedBill.DetectedFrequency) -> DetectedBill.BillReminderSuggestion {
        return DetectedBill.BillReminderSuggestion(
            suggestedName: merchantName,
            suggestedAmount: averageAmount,
            suggestedDueDate: Date(),
            suggestedFrequency: convertToReminderFrequency(frequency),
            suggestedReminderDays: [7, 3, 1],
            confidence: 0.8
        )
    }
    
    private func convertToReminderFrequency(_ detectedFrequency: DetectedBill.DetectedFrequency) -> BillFrequency {
        switch detectedFrequency {
        case .weekly: return .weekly
        case .biweekly: return .weekly // Closest match
        case .monthly: return .monthly
        case .quarterly: return .quarterly
        case .annual: return .yearly
        case .irregular: return .monthly // Default
        }
    }
    
    private func normalizeMerchantName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func loadMerchantDatabase() async {
        // Загрузка базы данных мерчантов
        // В реальной реализации здесь будет загрузка из файла или API
    }
    
    private func isAmountRegular(_ amount: Decimal, merchant: String) async -> Bool {
        // Проверка регулярности сумм для данного мерчанта
        return false // Заглушка
    }
    
    private func prepareTrainingData(from transactions: [Transaction]) -> [TrainingExample] {
        // Подготовка данных для обучения
        return []
    }
}

class BillDetectionModel {
    func train(with data: [TrainingExample]) async {
        // Обучение модели
    }
}

struct TrainingExample {
    // Пример для обучения
}

struct MerchantInfo {
    let name: String
    let category: String
    let billProbability: Double
}

// MARK: - Placeholder Classes

class BillPatternAnalysisEngine {
    func initialize() async {}
    
    func analyzePatterns(in transactions: [Transaction]) async -> [BillPattern] {
        return []
    }
    
    func identifyRecurringPayments(in transactions: [Transaction]) async -> [RecurringPayment] {
        return []
    }
    
    func analyzeBillCategories(bills: [BillReminder]) async -> [BillCategoryAnalysis] {
        return []
    }
    
    func updatePatterns(with newData: [Transaction]) async {}
}

class NotificationOptimizer {
    func initialize() async {}
    
    func optimizeForUser(_ user: User) async -> OptimalNotificationTiming {
        return OptimalNotificationTiming(
            user: user,
            optimalTimes: [],
            avoidanceTimes: [],
            personalizedSchedule: OptimalNotificationTiming.PersonalizedSchedule(
                primarySlots: [],
                backupSlots: [],
                emergencySlots: []
            ),
            effectiveness: OptimalNotificationTiming.TimingEffectiveness(
                responseRate: 0.8,
                actionCompletionRate: 0.75,
                userSatisfaction: 0.85,
                overallScore: 0.8
            )
        )
    }
}

class PaymentAnalyzer {
    func initialize() async {}
    
    func suggestOptimalTiming(for bill: BillReminder) async -> PaymentTimingSuggestion {
        return PaymentTimingSuggestion(
            billReminder: bill,
            suggestedPaymentDate: Calendar.current.date(byAdding: .day, value: -3, to: bill.dueDate) ?? bill.dueDate,
            reasoning: "Оптимальное время для предотвращения просрочки",
            benefits: [],
            alternatives: [],
            cashFlowImpact: PaymentTimingSuggestion.CashFlowImpact(
                immediateImpact: bill.amount ?? 0,
                weeklyProjection: 0,
                monthlyProjection: 0,
                bufferRecommendation: 0
            ),
            riskAssessment: PaymentTimingSuggestion.RiskAssessment(
                lateFeeRisk: 0.1,
                creditScoreImpact: .none,
                cashFlowRisk: 0.2
            )
        )
    }
    
    func analyzeHistory(for bill: BillReminder) async -> PaymentHistoryAnalysis {
        return PaymentHistoryAnalysis(
            billReminder: bill,
            paymentPatterns: [],
            timeliness: PaymentHistoryAnalysis.TimelinessAnalysis(
                averageDaysEarly: 2.0,
                averageDaysLate: 0.5,
                onTimePercentage: 0.85,
                latePaymentTrend: .stable
            ),
            amountConsistency: PaymentHistoryAnalysis.AmountConsistency(
                isAmountConsistent: true,
                averageVariation: 0,
                overpaymentFrequency: 0.1,
                underpaymentFrequency: 0.05
            ),
            seasonalTrends: [],
            predictiveInsights: []
        )
    }
    
    func predictAmount(for bill: BillReminder) async -> BillAmountPrediction {
        return BillAmountPrediction(
            billReminder: bill,
            predictedAmount: bill.amount ?? 0,
            confidence: 0.85,
            predictionRange: BillAmountPrediction.PredictionRange(
                minimum: bill.amount ?? 0,
                maximum: bill.amount ?? 0,
                mostLikely: bill.amount ?? 0,
                standardDeviation: 0.05
            ),
            methodology: .historical_average,
            factors: [],
            nextDueDate: bill.nextDueDate
        )
    }
    
    func generatePaymentSchedule(for bills: [BillReminder]) async -> PaymentSchedule {
        return PaymentSchedule(
            period: DateInterval(start: Date(), duration: 30 * 24 * 3600),
            scheduledPayments: [],
            totalAmount: 0,
            cashFlowProjection: [],
            optimizationSuggestions: [],
            riskAssessment: PaymentSchedule.ScheduleRiskAssessment(
                overallRisk: .low,
                criticalDates: [],
                recommendedBuffer: 0,
                contingencyPlan: ""
            )
        )
    }
    
    func generateReport(for period: DateInterval, bills: [BillReminder]) async -> BillReport {
        return BillReport(
            period: period,
            summary: BillReport.BillSummary(
                totalBills: bills.count,
                totalAmount: 0,
                paidOnTime: 0,
                paidLate: 0,
                missed: 0,
                averagePaymentDelay: 0
            ),
            categoryBreakdown: [],
            paymentAnalysis: BillReport.PaymentAnalysis(
                onTimePercentage: 0.85,
                averageLateDays: 1.2,
                lateFeesPaid: 0,
                improvementOpportunities: []
            ),
            trends: [],
            recommendations: []
        )
    }
}

class BillRiskAssessmentEngine {
    func initialize() async {}
    
    func identifyMissedPayments(bills: [BillReminder]) async -> [MissedPayment] {
        return []
    }
    
    func analyzeRisks(bills: [BillReminder]) async -> [BillRisk] {
        return []
    }
    
    func suggestBuffering(bills: [BillReminder]) async -> [BufferingSuggestion] {
        return []
    }
    
    func monitorChanges(bills: [BillReminder]) async -> [BillChange] {
        return []
    }
}

// MARK: - Supporting Structures

struct DetectionRule {
    let category: Category
    let autoCreateReminders: Bool
    let confidence_threshold: Double
}

struct NotificationPreferences {
    let preferredTimes: [Date]
    let preferredMethods: [PersonalizedReminder.DeliveryMethod]
    let quietHours: DateInterval?
}

struct BillReminderConfiguration {
    let suggestionThreshold: Double = 0.6
    let autoTrackingThreshold: Double = 0.8
    let autoCreationThreshold: Double = 0.9
    let maxRemindersPerBill: Int = 5
    let defaultReminderDays: [Int] = [7, 3, 1]
}

// MARK: - Error Types

enum BillReminderError: Error {
    case billNotFound
    case invalidConfiguration
    case notificationError
    case dataError
}

// MARK: - Private Extensions

private extension BillReminderService {
    
    func loadBillReminders() async throws {
        let predicate = #Predicate<BillReminder> { reminder in
            reminder.isActive
        }
        billReminders = try await dataService.fetch(BillReminder.self, predicate: predicate)
    }
    
    func loadDetectionRules() async throws {
        // Загрузка правил обнаружения
        detectionRules = []
    }
    
    func loadUserPreferences() async throws {
        // Загрузка предпочтений пользователя
        userPreferences = NotificationPreferences(
            preferredTimes: [],
            preferredMethods: [.push, .inApp],
            quietHours: nil
        )
    }
    
    func trainInitialModels() async throws {
        let transactions = try await transactionRepository.fetchTransactions()
        try await trainBillDetectionModel(with: transactions)
    }
    
    func updateDetectionModels(with bill: BillReminder) async {
        // Обновляем модели с новым счетом
    }
    
    func scheduleNotification(for reminder: PersonalizedReminder) async {
        // Планируем уведомление
    }
    
    func rescheduleNotifications(for bill: BillReminder) async {
        // Перепланируем уведомления
    }
    
    func cancelNotifications(for bill: BillReminder) async {
        // Отменяем уведомления
    }
    
    func getCurrentUser() async -> User? {
        // Получаем текущего пользователя
        return nil
    }
    
    func scheduleOptimizedNotification(reminder: PersonalizedReminder, timing: OptimalNotificationTiming) async {
        // Планируем оптимизированное уведомление
    }
    
    func findSimilarBills(to transaction: Transaction) -> [BillReminder] {
        // Ищем похожие счета
        return billReminders.filter { bill in
            bill.name.lowercased().contains(transaction.title.lowercased().prefix(10))
        }
    }
    
    func determineActionRecommendation(transaction: Transaction, detectionResult: (confidence: Double, reasoning: String, suggestedBill: BillReminder), similarBills: [BillReminder]) -> BillSuggestion.ActionRecommendation {
        if !similarBills.isEmpty {
            return .addToExisting(similarBills.first!)
        } else if detectionResult.confidence > 0.8 {
            return .createNew
        } else if detectionResult.confidence > 0.6 {
            return .needsMoreData
        } else {
            return .ignore
        }
    }
    
    func calculateOptimalReminderTimes(for bill: BillReminder, history: PaymentHistoryAnalysis) async -> [PersonalizedReminder.ReminderTiming] {
        // Вычисляем оптимальные времена напоминаний
        return []
    }
    
    func determineReminderType(daysBeforeDue: Int, history: PaymentHistoryAnalysis) -> PersonalizedReminder.ReminderType {
        switch daysBeforeDue {
        case 7...: return .earlyWarning
        case 3...6: return .standard
        case 1...2: return .lastChance
        case 0: return .overdue
        default: return .standard
        }
    }
    
    func defaultReminderTiming(daysBeforeDue: Int) -> PersonalizedReminder.ReminderTiming {
        let scheduleDate = Calendar.current.date(byAdding: .day, value: -daysBeforeDue, to: Date()) ?? Date()
        
        return PersonalizedReminder.ReminderTiming(
            scheduledDate: scheduleDate,
            preferredTime: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: scheduleDate) ?? scheduleDate,
            timezone: TimeZone.current,
            dayOfWeek: Calendar.current.component(.weekday, from: scheduleDate),
            reasoning: "Стандартное время напоминания"
        )
    }
    
    func generatePersonalizedMessage(for bill: BillReminder, type: PersonalizedReminder.ReminderType, history: PaymentHistoryAnalysis) -> String {
        switch type {
        case .standard:
            return "Напоминание: через \(bill.daysUntilDue) дней нужно оплатить \(bill.name)"
        case .earlyWarning:
            return "Раннее напоминание: приближается срок оплаты \(bill.name)"
        case .lastChance:
            return "Последний шанс: завтра срок оплаты \(bill.name)"
        case .overdue:
            return "Внимание: просрочен платеж по \(bill.name)"
        case .proactive:
            return "Проактивное напоминание: рекомендуем подготовиться к оплате \(bill.name)"
        case .seasonal:
            return "Сезонное напоминание: в это время года обычно изменяется сумма по \(bill.name)"
        }
    }
    
    func preferredDeliveryMethod(for reminderType: PersonalizedReminder.ReminderType) -> PersonalizedReminder.DeliveryMethod {
        switch reminderType {
        case .overdue, .lastChance: return .push
        case .earlyWarning, .proactive: return .inApp
        default: return .push
        }
    }
    
    func calculateUrgency(for reminderType: PersonalizedReminder.ReminderType, bill: BillReminder) -> PersonalizedReminder.UrgencyLevel {
        switch reminderType {
        case .overdue: return .critical
        case .lastChance: return .high
        case .standard: return .medium
        case .earlyWarning, .proactive, .seasonal: return .low
        }
    }
    
    func generateActionableSteps(for bill: BillReminder, reminderType: PersonalizedReminder.ReminderType) -> [PersonalizedReminder.ActionableStep] {
        var steps: [PersonalizedReminder.ActionableStep] = []
        
        steps.append(PersonalizedReminder.ActionableStep(
            step: "Проверить сумму к оплате",
            isRequired: true,
            estimatedTime: "1 минута",
            helpText: "Убедитесь в корректности суммы платежа"
        ))
        
        if bill.amount != nil {
            steps.append(PersonalizedReminder.ActionableStep(
                step: "Оплатить счет",
                isRequired: true,
                estimatedTime: "5 минут",
                helpText: "Произведите оплату удобным способом"
            ))
        }
        
        steps.append(PersonalizedReminder.ActionableStep(
            step: "Отметить как оплаченный",
            isRequired: false,
            estimatedTime: "30 секунд",
            helpText: "Отметьте в приложении для отслеживания"
        ))
        
        return steps
    }
    
    func sendMissedPaymentAlert(_ missedPayment: MissedPayment) async {
        // Отправляем уведомление о пропущенном платеже
    }
    
    func sendBillChangeAlert(_ change: BillChange) async {
        // Отправляем уведомление об изменении счета
    }
    
    func identifyUpcomingLargeBills() async -> [BillReminder] {
        // Идентифицируем предстоящие крупные счета
        return billReminders.filter { bill in
            if let amount = bill.amount {
                return amount > 10000 && bill.daysUntilDue <= 7
            }
            return false
        }
    }
    
    func sendLargeBillAlert(_ bill: BillReminder) async {
        // Отправляем уведомление о крупном счете
    }
    
    func convertBankTransaction(_ bankTransaction: BankTransaction) -> Transaction {
        return Transaction(
            amount: bankTransaction.amount,
            type: bankTransaction.type == .debit ? .expense : .income,
            title: bankTransaction.description,
            date: bankTransaction.date
        )
    }
    
    func createCalendarEvent(for bill: BillReminder) async {
        // Создаем событие в календаре
    }
    
    func saveDetectionRules() async throws {
        // Сохраняем правила обнаружения
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 