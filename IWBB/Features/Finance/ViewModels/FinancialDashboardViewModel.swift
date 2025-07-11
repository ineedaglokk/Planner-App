import Foundation
import SwiftUI
import Combine

@Observable
final class FinancialDashboardViewModel {
    
    // MARK: - Services
    private let financeService: FinanceServiceProtocol
    private let budgetingService: BudgetingServiceProtocol
    private let insightsGenerationService: InsightsGenerationServiceProtocol
    private let forecastingService: ForecastingServiceProtocol
    private let billReminderService: BillReminderServiceProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    
    // MARK: - Published Properties
    var overviewStats: FinancialOverviewStats?
    var quickInsights: [QuickInsight] = []
    var goalProgress: [GoalProgressItem] = []
    var cashFlowTrends: [CashFlowTrendPoint] = []
    var budgetAlerts: [BudgetAlert] = []
    var billReminders: [UpcomingBillReminder] = []
    var financialHealthScore: FinancialHealthScore?
    var recentTransactions: [Transaction] = []
    var monthlySnapshot: MonthlyFinancialSnapshot?
    var recommendations: [FinancialRecommendation] = []
    
    // MARK: - UI State
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var showError = false
    var selectedPeriod: DashboardPeriod = .month
    var showQuickActions = false
    var showInsightDetail: QuickInsight?
    var showGoalDetail: GoalProgressItem?
    var showBudgetDetail: BudgetAlert?
    
    // MARK: - Quick Actions State
    var showAddTransaction = false
    var showCreateBudget = false
    var showCreateGoal = false
    var showPayBill = false
    
    // MARK: - Configuration
    private let refreshInterval: TimeInterval = 120 // 2 minutes
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        financeService: FinanceServiceProtocol,
        budgetingService: BudgetingServiceProtocol,
        insightsGenerationService: InsightsGenerationServiceProtocol,
        forecastingService: ForecastingServiceProtocol,
        billReminderService: BillReminderServiceProtocol,
        transactionRepository: TransactionRepositoryProtocol
    ) {
        self.financeService = financeService
        self.budgetingService = budgetingService
        self.insightsGenerationService = insightsGenerationService
        self.forecastingService = forecastingService
        self.billReminderService = billReminderService
        self.transactionRepository = transactionRepository
        
        setupAutoRefresh()
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadOverviewStats() }
                group.addTask { await self.loadQuickInsights() }
                group.addTask { await self.loadGoalProgress() }
                group.addTask { await self.loadCashFlowTrends() }
                group.addTask { await self.loadBudgetAlerts() }
                group.addTask { await self.loadBillReminders() }
                group.addTask { await self.loadFinancialHealthScore() }
                group.addTask { await self.loadRecentTransactions() }
                group.addTask { await self.loadMonthlySnapshot() }
                group.addTask { await self.loadRecommendations() }
            }
            
        } catch {
            await handleError(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func refresh() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }
    
    @MainActor
    func changePeriod(_ period: DashboardPeriod) async {
        selectedPeriod = period
        await loadData()
    }
    
    @MainActor
    func dismissInsight(_ insight: QuickInsight) async {
        quickInsights.removeAll { $0.id == insight.id }
        
        // TODO: Отметить инсайт как просмотренный в сервисе
    }
    
    @MainActor
    func completeGoal(_ goal: GoalProgressItem) async {
        do {
            // TODO: Реализовать завершение цели через сервис
            goalProgress.removeAll { $0.id == goal.id }
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func payBill(_ bill: UpcomingBillReminder) async {
        do {
            // TODO: Реализовать оплату счета
            billReminders.removeAll { $0.id == bill.id }
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func applyRecommendation(_ recommendation: FinancialRecommendation) async {
        do {
            // TODO: Реализовать применение рекомендации
            recommendations.removeAll { $0.id == recommendation.id }
            await refresh()
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func addQuickTransaction(amount: Decimal, category: Category, description: String) async {
        do {
            let transaction = Transaction(
                amount: amount,
                type: .expense,
                title: description,
                date: Date(),
                category: category
            )
            
            try await financeService.addTransaction(transaction)
            await refresh()
            
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Computed Properties
    
    var totalIncome: Decimal {
        overviewStats?.totalIncome ?? 0
    }
    
    var totalExpenses: Decimal {
        overviewStats?.totalExpenses ?? 0
    }
    
    var netCashFlow: Decimal {
        totalIncome - totalExpenses
    }
    
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(netCashFlow / totalIncome) * 100
    }
    
    var hasPositiveCashFlow: Bool {
        netCashFlow > 0
    }
    
    var budgetUtilization: Double {
        overviewStats?.budgetUtilization ?? 0
    }
    
    var goalsOnTrack: Int {
        goalProgress.filter { $0.isOnTrack }.count
    }
    
    var urgentReminders: [UpcomingBillReminder] {
        billReminders.filter { $0.urgency == .urgent || $0.urgency == .high }
    }
    
    var financialHealthStatus: HealthStatus {
        financialHealthScore?.status ?? .unknown
    }
    
    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: Date()).capitalized
    }
    
    var hasData: Bool {
        overviewStats != nil
    }
    
    var dashboardHealthColor: Color {
        switch financialHealthStatus {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    // MARK: - Private Methods
    
    private func loadOverviewStats() async {
        do {
            let dateInterval = selectedPeriod.dateInterval
            let stats = try await generateOverviewStats(for: dateInterval)
            
            await MainActor.run {
                self.overviewStats = stats
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadQuickInsights() async {
        do {
            let insights = try await insightsGenerationService.generatePersonalizedInsights(for: User())
            
            // Конвертируем в QuickInsight и берем топ-5
            let quickInsights = insights.prefix(5).map { insight in
                QuickInsight(
                    id: insight.id,
                    type: mapInsightType(insight.type),
                    title: insight.title,
                    message: insight.description,
                    impact: insight.impact,
                    confidence: insight.confidence,
                    actionButton: generateActionButton(for: insight),
                    icon: generateInsightIcon(for: insight.type),
                    color: generateInsightColor(for: insight.impact)
                )
            }
            
            await MainActor.run {
                self.quickInsights = Array(quickInsights)
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadGoalProgress() async {
        do {
            // TODO: Получить финансовые цели от соответствующего сервиса
            let mockGoals = generateMockGoalProgress()
            
            await MainActor.run {
                self.goalProgress = mockGoals
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadCashFlowTrends() async {
        do {
            let forecast = try await forecastingService.forecastCashFlow(
                for: User(),
                horizon: .month
            )
            
            let trendPoints = forecast.cashFlowPredictions.map { prediction in
                CashFlowTrendPoint(
                    date: prediction.date,
                    income: prediction.predictedIncome,
                    expenses: prediction.predictedExpenses,
                    netFlow: prediction.netCashFlow,
                    confidence: prediction.confidence
                )
            }
            
            await MainActor.run {
                self.cashFlowTrends = trendPoints
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadBudgetAlerts() async {
        do {
            let budgets = try await budgetingService.getBudgets()
            var alerts: [BudgetAlert] = []
            
            for budget in budgets {
                let budgetAlerts = try await budgetingService.checkAlerts(budget)
                alerts.append(contentsOf: budgetAlerts)
            }
            
            await MainActor.run {
                self.budgetAlerts = alerts.sorted { $0.severity.rawValue > $1.severity.rawValue }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadBillReminders() async {
        do {
            let bills = try await billReminderService.getBillReminders()
            
            let upcomingBills = bills.compactMap { bill -> UpcomingBillReminder? in
                guard bill.isActive && bill.daysUntilDue <= 7 else { return nil }
                
                return UpcomingBillReminder(
                    id: bill.id,
                    name: bill.name,
                    amount: bill.amount ?? 0,
                    dueDate: bill.dueDate,
                    daysUntil: bill.daysUntilDue,
                    urgency: determineUrgency(daysUntil: bill.daysUntilDue),
                    category: bill.category?.name ?? "Другое",
                    isRecurring: bill.frequency != .oneTime
                )
            }
            
            await MainActor.run {
                self.billReminders = upcomingBills.sorted { $0.daysUntil < $1.daysUntil }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadFinancialHealthScore() async {
        do {
            let healthScore = try await insightsGenerationService.generateHealthScore(for: User())
            
            await MainActor.run {
                self.financialHealthScore = healthScore
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadRecentTransactions() async {
        do {
            let transactions = try await transactionRepository.fetchRecentTransactions(limit: 10)
            
            await MainActor.run {
                self.recentTransactions = transactions
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadMonthlySnapshot() async {
        do {
            let snapshot = try await generateMonthlySnapshot()
            
            await MainActor.run {
                self.monthlySnapshot = snapshot
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadRecommendations() async {
        do {
            let userRecommendations = try await insightsGenerationService.generateActionableRecommendations(for: User())
            
            let financialRecommendations = userRecommendations.prefix(3).map { recommendation in
                FinancialRecommendation(
                    id: recommendation.id,
                    type: mapRecommendationType(recommendation.type),
                    title: recommendation.title,
                    description: recommendation.description,
                    priority: mapRecommendationPriority(recommendation.priority),
                    expectedImpact: recommendation.impact.financialImpact.monthlySavings?.description ?? "Неопределено",
                    effort: mapRecommendationEffort(recommendation.implementation.difficulty),
                    category: recommendation.category.displayName
                )
            }
            
            await MainActor.run {
                self.recommendations = Array(financialRecommendations)
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateOverviewStats(for period: DateInterval) async throws -> FinancialOverviewStats {
        let transactions = try await transactionRepository.fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        let income = transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        let expenses = transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        
        let budgets = try await budgetingService.getBudgets(period: period)
        let totalBudget = budgets.reduce(0) { $0 + $1.limit }
        let budgetUtilization = totalBudget > 0 ? Double(expenses / totalBudget) : 0
        
        let savingsGoals = try await getFinancialGoals()
        let savingsProgress = calculateSavingsProgress(goals: savingsGoals)
        
        return FinancialOverviewStats(
            period: period,
            totalIncome: income,
            totalExpenses: expenses,
            netCashFlow: income - expenses,
            budgetUtilization: budgetUtilization,
            savingsProgress: savingsProgress,
            transactionCount: transactions.count,
            averageTransactionAmount: transactions.isEmpty ? 0 : expenses / Decimal(transactions.count),
            topCategory: findTopSpendingCategory(from: transactions)
        )
    }
    
    private func generateMonthlySnapshot() async throws -> MonthlyFinancialSnapshot {
        let currentMonth = Calendar.current.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), duration: 2592000)
        
        let transactions = try await transactionRepository.fetchTransactions(
            from: currentMonth.start,
            to: currentMonth.end
        )
        
        let monthlyIncome = transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
        
        let monthlyExpenses = transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        
        let budgets = try await budgetingService.getBudgets(period: currentMonth)
        let budgetCompliance = calculateBudgetCompliance(budgets: budgets, expenses: monthlyExpenses)
        
        let goals = try await getFinancialGoals()
        let goalAchievements = calculateGoalAchievements(goals: goals)
        
        return MonthlyFinancialSnapshot(
            month: currentMonth,
            income: monthlyIncome,
            expenses: monthlyExpenses,
            savings: monthlyIncome - monthlyExpenses,
            budgetCompliance: budgetCompliance,
            goalAchievements: goalAchievements,
            transactionCount: transactions.count,
            averageDailySpending: monthlyExpenses / Decimal(Calendar.current.component(.day, from: Date())),
            biggestExpense: transactions.filter { $0.type == .expense }.max { $0.amount < $1.amount },
            categoriesCount: Set(transactions.compactMap { $0.category?.id }).count
        )
    }
    
    private func generateMockGoalProgress() -> [GoalProgressItem] {
        return [
            GoalProgressItem(
                id: UUID(),
                name: "Экстренный фонд",
                currentAmount: 85000,
                targetAmount: 150000,
                progress: 0.57,
                daysRemaining: 120,
                isOnTrack: true,
                category: "Сбережения",
                priority: .high
            ),
            GoalProgressItem(
                id: UUID(),
                name: "Отпуск в Японии",
                currentAmount: 32000,
                targetAmount: 200000,
                progress: 0.16,
                daysRemaining: 300,
                isOnTrack: false,
                category: "Путешествия",
                priority: .medium
            ),
            GoalProgressItem(
                id: UUID(),
                name: "Новый MacBook",
                currentAmount: 120000,
                targetAmount: 150000,
                progress: 0.8,
                daysRemaining: 30,
                isOnTrack: true,
                category: "Техника",
                priority: .low
            )
        ]
    }
    
    private func findTopSpendingCategory(from transactions: [Transaction]) -> String? {
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let categoryGroups = Dictionary(grouping: expenseTransactions) { $0.category?.name ?? "Без категории" }
        
        return categoryGroups.max { group1, group2 in
            let sum1 = group1.value.reduce(0) { $0 + $1.amount }
            let sum2 = group2.value.reduce(0) { $0 + $1.amount }
            return sum1 < sum2
        }?.key
    }
    
    private func getFinancialGoals() async throws -> [FinancialGoal] {
        // TODO: Реализовать получение финансовых целей
        return []
    }
    
    private func calculateSavingsProgress(goals: [FinancialGoal]) -> Double {
        guard !goals.isEmpty else { return 0 }
        
        let totalProgress = goals.reduce(0) { $0 + $1.progress }
        return totalProgress / Double(goals.count)
    }
    
    private func calculateBudgetCompliance(budgets: [Budget], expenses: Decimal) -> Double {
        let totalBudget = budgets.reduce(0) { $0 + $1.limit }
        return totalBudget > 0 ? Double(expenses / totalBudget) : 0
    }
    
    private func calculateGoalAchievements(goals: [FinancialGoal]) -> Int {
        return goals.filter { $0.isCompleted }.count
    }
    
    private func determineUrgency(daysUntil: Int) -> ReminderUrgency {
        switch daysUntil {
        case 0: return .urgent
        case 1: return .high
        case 2...3: return .medium
        default: return .low
        }
    }
    
    private func mapInsightType(_ type: PersonalizedInsight.InsightType) -> QuickInsightType {
        switch type {
        case .spendingOptimization: return .spending
        case .savingsOpportunity: return .savings
        case .budgetAlignment: return .budget
        case .goalAcceleration: return .goal
        case .riskWarning: return .warning
        default: return .general
        }
    }
    
    private func generateActionButton(for insight: PersonalizedInsight) -> String {
        switch insight.type {
        case .spendingOptimization: return "Оптимизировать"
        case .savingsOpportunity: return "Сэкономить"
        case .budgetAlignment: return "Настроить"
        case .goalAcceleration: return "Ускорить"
        case .riskWarning: return "Устранить"
        default: return "Подробнее"
        }
    }
    
    private func generateInsightIcon(for type: PersonalizedInsight.InsightType) -> String {
        switch type {
        case .spendingOptimization: return "arrow.down.circle"
        case .savingsOpportunity: return "dollarsign.circle"
        case .budgetAlignment: return "chart.pie"
        case .goalAcceleration: return "target"
        case .riskWarning: return "exclamationmark.triangle"
        default: return "lightbulb"
        }
    }
    
    private func generateInsightColor(for impact: ImpactLevel) -> Color {
        switch impact {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private func mapRecommendationType(_ type: ActionableRecommendation.RecommendationType) -> FinancialRecommendationType {
        switch type {
        case .budgetAdjustment: return .budget
        case .savingsIncrease: return .savings
        case .expenseReduction: return .spending
        case .goalModification: return .goal
        case .automationSetup: return .automation
        case .behaviorChange: return .behavior
        case .investmentOpportunity: return .investment
        case .debtManagement: return .debt
        }
    }
    
    private func mapRecommendationPriority(_ priority: ActionableRecommendation.Priority) -> FinancialRecommendationPriority {
        switch priority {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .urgent
        }
    }
    
    private func mapRecommendationEffort(_ effort: ActionableRecommendation.ImplementationGuide.DifficultyLevel) -> FinancialRecommendationEffort {
        switch effort {
        case .beginner: return .low
        case .intermediate: return .medium
        case .advanced: return .high
        }
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await self.refresh()
            }
        }
    }
    
    @MainActor
    private func handleError(_ error: Error) async {
        let dashboardError = error as? FinancialDashboardError ?? FinancialDashboardError.unknown(error.localizedDescription)
        errorMessage = dashboardError.localizedDescription
        showError = true
    }
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum DashboardPeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    
    var displayName: String {
        switch self {
        case .week: return "Неделя"
        case .month: return "Месяц"
        case .quarter: return "Квартал"
        case .year: return "Год"
        }
    }
    
    var dateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, duration: 604800)
        case .month:
            return calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 2592000)
        case .quarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let startMonth = quarter * 3 + 1
            let startDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: startMonth,
                day: 1
            )) ?? now
            return DateInterval(start: startDate, duration: 7776000)
        case .year:
            return calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: now, duration: 31536000)
        }
    }
}

// MARK: - Data Structures

struct FinancialOverviewStats {
    let period: DateInterval
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let netCashFlow: Decimal
    let budgetUtilization: Double
    let savingsProgress: Double
    let transactionCount: Int
    let averageTransactionAmount: Decimal
    let topCategory: String?
    
    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(netCashFlow / totalIncome) * 100
    }
    
    var isHealthy: Bool {
        netCashFlow > 0 && budgetUtilization <= 0.9
    }
}

struct QuickInsight: Identifiable {
    let id: UUID
    let type: QuickInsightType
    let title: String
    let message: String
    let impact: ImpactLevel
    let confidence: Double
    let actionButton: String
    let icon: String
    let color: Color
}

enum QuickInsightType {
    case spending, savings, budget, goal, warning, general
    
    var displayName: String {
        switch self {
        case .spending: return "Расходы"
        case .savings: return "Сбережения"
        case .budget: return "Бюджет"
        case .goal: return "Цели"
        case .warning: return "Предупреждение"
        case .general: return "Общее"
        }
    }
}

struct GoalProgressItem: Identifiable {
    let id: UUID
    let name: String
    let currentAmount: Decimal
    let targetAmount: Decimal
    let progress: Double
    let daysRemaining: Int
    let isOnTrack: Bool
    let category: String
    let priority: GoalPriority
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var amountRemaining: Decimal {
        targetAmount - currentAmount
    }
}

enum GoalPriority {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        }
    }
}

struct CashFlowTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let income: Decimal
    let expenses: Decimal
    let netFlow: Decimal
    let confidence: Double
}

struct UpcomingBillReminder: Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDate: Date
    let daysUntil: Int
    let urgency: ReminderUrgency
    let category: String
    let isRecurring: Bool
}

enum ReminderUrgency {
    case low, medium, high, urgent
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Низкая"
        case .medium: return "Средняя"
        case .high: return "Высокая"
        case .urgent: return "Срочная"
        }
    }
}

struct MonthlyFinancialSnapshot {
    let month: DateInterval
    let income: Decimal
    let expenses: Decimal
    let savings: Decimal
    let budgetCompliance: Double
    let goalAchievements: Int
    let transactionCount: Int
    let averageDailySpending: Decimal
    let biggestExpense: Transaction?
    let categoriesCount: Int
    
    var savingsRate: Double {
        guard income > 0 else { return 0 }
        return Double(savings / income) * 100
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: month.start).capitalized
    }
}

struct FinancialRecommendation: Identifiable {
    let id: UUID
    let type: FinancialRecommendationType
    let title: String
    let description: String
    let priority: FinancialRecommendationPriority
    let expectedImpact: String
    let effort: FinancialRecommendationEffort
    let category: String
}

enum FinancialRecommendationType {
    case budget, savings, spending, goal, automation, behavior, investment, debt
    
    var icon: String {
        switch self {
        case .budget: return "chart.pie"
        case .savings: return "dollarsign.circle"
        case .spending: return "arrow.down.circle"
        case .goal: return "target"
        case .automation: return "gear"
        case .behavior: return "brain.head.profile"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .debt: return "creditcard"
        }
    }
    
    var displayName: String {
        switch self {
        case .budget: return "Бюджет"
        case .savings: return "Сбережения"
        case .spending: return "Расходы"
        case .goal: return "Цели"
        case .automation: return "Автоматизация"
        case .behavior: return "Поведение"
        case .investment: return "Инвестиции"
        case .debt: return "Долги"
        }
    }
}

enum FinancialRecommendationPriority {
    case low, medium, high, urgent
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

enum FinancialRecommendationEffort {
    case low, medium, high
    
    var displayName: String {
        switch self {
        case .low: return "Низкие усилия"
        case .medium: return "Средние усилия"
        case .high: return "Высокие усилия"
        }
    }
}

enum HealthStatus {
    case excellent, good, fair, poor, unknown
    
    var displayName: String {
        switch self {
        case .excellent: return "Отличное"
        case .good: return "Хорошее"
        case .fair: return "Удовлетворительное"
        case .poor: return "Требует внимания"
        case .unknown: return "Неизвестно"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.circle"
        case .poor: return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Error Types

enum FinancialDashboardError: LocalizedError {
    case noData
    case serviceUnavailable
    case loadingError
    case calculationError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "Нет данных для отображения"
        case .serviceUnavailable:
            return "Сервис временно недоступен"
        case .loadingError:
            return "Ошибка загрузки данных"
        case .calculationError:
            return "Ошибка вычислений"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Extensions

extension PersonalizedInsight.InsightSupportingData.ComparisonData.ChangeType {
    var displayName: String {
        switch self {
        case .improvement: return "Улучшение"
        case .deterioration: return "Ухудшение"
        case .neutral: return "Без изменений"
        }
    }
}

extension ActionableRecommendation.RecommendationCategory {
    var displayName: String {
        switch self {
        case .immediate: return "Немедленно"
        case .shortTerm: return "Краткосрочно"
        case .longTerm: return "Долгосрочно"
        case .strategic: return "Стратегически"
        }
    }
} 