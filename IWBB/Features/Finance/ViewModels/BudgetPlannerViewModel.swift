import Foundation
import SwiftUI
import Combine

@Observable
final class BudgetPlannerViewModel {
    
    // MARK: - Services
    
    private let financeService: FinanceServiceProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let dataService: DataServiceProtocol
    
    // MARK: - Published Properties
    
    // Текущий план
    var currentBudgetPlan: BudgetPlan?
    var selectedYear: Int = Calendar.current.component(.year, from: Date())
    var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    var selectedCurrency: String = "RUB"
    
    // Данные для отображения
    var planFactData: [BudgetPlanItem] = []
    var dailyExpenses: [DailyTransaction] = []
    var dailyIncome: [DailyTransaction] = []
    
    // Статистика
    var totalPlannedIncome: Decimal = 0
    var totalActualIncome: Decimal = 0
    var totalPlannedExpenses: Decimal = 0
    var totalActualExpenses: Decimal = 0
    var totalPlannedSavings: Decimal = 0
    var totalActualSavings: Decimal = 0
    var remainingBalance: Decimal = 0
    var capitalAndSavings: Decimal = 0
    
    // Графики и аналитика
    var expensesByCategory: [CategorySummary] = []
    var incomeByCategory: [CategorySummary] = []
    var planVsActualChartData: [(String, Decimal, Decimal)] = []
    
    // Годовой обзор
    var yearlyOverview: YearlyFinancialOverview?
    var monthlyBreakdown: [MonthlyFinancialSummary] = []
    
    // UI состояние
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var showError = false
    
    // MARK: - Initialization
    
    init(
        financeService: FinanceServiceProtocol,
        transactionRepository: TransactionRepositoryProtocol,
        dataService: DataServiceProtocol
    ) {
        self.financeService = financeService
        self.transactionRepository = transactionRepository
        self.dataService = dataService
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Загружаем или создаем бюджетный план
            await loadBudgetPlan()
            
            // Загружаем данные параллельно
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadPlanFactData() }
                group.addTask { await self.loadDailyTransactions() }
                group.addTask { await self.loadCategoryAnalytics() }
                group.addTask { await self.loadYearlyOverview() }
                group.addTask { await self.calculateTotals() }
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
    func changeSelectedPeriod(year: Int, month: Int) async {
        selectedYear = year
        selectedMonth = month
        await loadData()
    }
    
    @MainActor
    func updateBudgetPlanItem(_ item: BudgetPlanItem, plannedAmount: Decimal, actualAmount: Decimal) async {
        item.plannedAmount = plannedAmount
        item.actualAmount = actualAmount
        item.updateTimestamp()
        item.markForSync()
        
        do {
            try await dataService.save(item)
            await calculateTotals()
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func addDailyTransaction(
        date: Date,
        category: String,
        amount: Decimal,
        description: String?,
        type: TransactionType
    ) async {
        let transaction = DailyTransaction(
            date: date,
            category: category,
            amount: amount,
            description: description,
            type: type
        )
        
        transaction.budgetPlan = currentBudgetPlan
        
        do {
            try await dataService.save(transaction)
            await loadDailyTransactions()
            await loadCategoryAnalytics()
            await calculateTotals()
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func createNewBudgetPlan() async {
        let newPlan = BudgetPlan(
            year: selectedYear,
            month: selectedMonth,
            currency: selectedCurrency
        )
        
        // Добавляем базовые статьи
        newPlan.incomeItems = createDefaultIncomeItems()
        newPlan.expenseItems = createDefaultExpenseItems()
        newPlan.debtItems = createDefaultDebtItems()
        newPlan.savingsItems = createDefaultSavingsItems()
        
        do {
            try await dataService.save(newPlan)
            currentBudgetPlan = newPlan
            await loadData()
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func deleteBudgetPlan(_ plan: BudgetPlan) async {
        do {
            try await dataService.delete(plan)
            if currentBudgetPlan?.id == plan.id {
                currentBudgetPlan = nil
            }
            await loadData()
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Computed Properties
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        
        let date = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth)) ?? Date()
        return formatter.string(from: date).capitalized
    }
    
    var formattedSelectedPeriod: String {
        return "\(monthName) \(selectedYear)"
    }
    
    var totalPlannedBalance: Decimal {
        return totalPlannedIncome - totalPlannedExpenses
    }
    
    var totalActualBalance: Decimal {
        return totalActualIncome - totalActualExpenses
    }
    
    var budgetVariance: Decimal {
        return totalActualBalance - totalPlannedBalance
    }
    
    var isOverBudget: Bool {
        return totalActualExpenses > totalPlannedExpenses
    }
    
    var savingsRate: Double {
        guard totalActualIncome > 0 else { return 0 }
        return Double(totalActualSavings / totalActualIncome) * 100
    }
    
    var expenseToIncomeRatio: Double {
        guard totalActualIncome > 0 else { return 0 }
        return Double(totalActualExpenses / totalActualIncome) * 100
    }
    
    var topExpenseCategory: String {
        return expensesByCategory.first?.categoryName ?? "Нет данных"
    }
    
    var quickFinancialSummary: String {
        if totalActualBalance > 0 {
            return "Профицит: \(formatCurrency(totalActualBalance))"
        } else {
            return "Дефицит: \(formatCurrency(abs(totalActualBalance)))"
        }
    }
    
    // MARK: - Private Methods
    
    private func loadBudgetPlan() async {
        do {
            let plans = try await dataService.fetch(BudgetPlan.self, predicate: #Predicate<BudgetPlan> { plan in
                plan.year == selectedYear && plan.month == selectedMonth
            })
            
            await MainActor.run {
                self.currentBudgetPlan = plans.first
            }
            
            // Если план не найден, создаем новый
            if currentBudgetPlan == nil {
                await createNewBudgetPlan()
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadPlanFactData() async {
        guard let plan = currentBudgetPlan else { return }
        
        await MainActor.run {
            // Собираем все элементы плана
            var allItems: [BudgetPlanItem] = []
            
            // Основные категории
            allItems.append(plan.income)
            allItems.append(plan.expenses)
            allItems.append(plan.debts)
            allItems.append(plan.savings)
            
            // Детализация
            allItems.append(contentsOf: plan.incomeItems)
            allItems.append(contentsOf: plan.expenseItems)
            allItems.append(contentsOf: plan.debtItems)
            allItems.append(contentsOf: plan.savingsItems)
            
            self.planFactData = allItems.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
    
    private func loadDailyTransactions() async {
        guard let plan = currentBudgetPlan else { return }
        
        do {
            let expenses = try await dataService.fetch(DailyTransaction.self, predicate: #Predicate<DailyTransaction> { transaction in
                transaction.budgetPlan?.id == plan.id && transaction.type == .expense
            })
            
            let income = try await dataService.fetch(DailyTransaction.self, predicate: #Predicate<DailyTransaction> { transaction in
                transaction.budgetPlan?.id == plan.id && transaction.type == .income
            })
            
            await MainActor.run {
                self.dailyExpenses = expenses.sorted { $0.date > $1.date }
                self.dailyIncome = income.sorted { $0.date > $1.date }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadCategoryAnalytics() async {
        guard let plan = currentBudgetPlan else { return }
        
        await MainActor.run {
            self.expensesByCategory = plan.expensesByCategory
            self.incomeByCategory = plan.incomeByCategory
            
            // Подготавливаем данные для диаграммы план/факт
            self.planVsActualChartData = [
                ("Поступления", plan.totalPlannedIncome, plan.totalActualIncome),
                ("Расходы", plan.totalPlannedExpenses, plan.totalActualExpenses),
                ("Долги", plan.totalPlannedSavings, plan.totalActualSavings)
            ]
        }
    }
    
    private func loadYearlyOverview() async {
        do {
            let overview = try await dataService.fetch(YearlyFinancialOverview.self, predicate: #Predicate<YearlyFinancialOverview> { overview in
                overview.year == selectedYear
            })
            
            await MainActor.run {
                self.yearlyOverview = overview.first
            }
            
            // Загружаем помесячную разбивку
            await loadMonthlyBreakdown()
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadMonthlyBreakdown() async {
        do {
            let summaries = try await dataService.fetch(MonthlyFinancialSummary.self, predicate: #Predicate<MonthlyFinancialSummary> { summary in
                summary.year == selectedYear
            })
            
            await MainActor.run {
                self.monthlyBreakdown = summaries.sorted { $0.month < $1.month }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func calculateTotals() async {
        guard let plan = currentBudgetPlan else { return }
        
        await MainActor.run {
            // Поступления
            self.totalPlannedIncome = plan.income.plannedAmount + plan.incomeItems.reduce(0) { $0 + $1.plannedAmount }
            self.totalActualIncome = plan.income.actualAmount + plan.incomeItems.reduce(0) { $0 + $1.actualAmount }
            
            // Расходы
            self.totalPlannedExpenses = plan.expenses.plannedAmount + plan.expenseItems.reduce(0) { $0 + $1.plannedAmount }
            self.totalActualExpenses = plan.expenses.actualAmount + plan.expenseItems.reduce(0) { $0 + $1.actualAmount }
            
            // Накопления
            self.totalPlannedSavings = plan.savings.plannedAmount + plan.savingsItems.reduce(0) { $0 + $1.plannedAmount }
            self.totalActualSavings = plan.savings.actualAmount + plan.savingsItems.reduce(0) { $0 + $1.actualAmount }
            
            // Остаток
            self.remainingBalance = self.totalActualIncome - self.totalActualExpenses
            
            // Капитал и накопления
            self.capitalAndSavings = self.totalActualSavings
        }
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
    
    // MARK: - Default Data Creation
    
    private func createDefaultIncomeItems() -> [BudgetPlanItem] {
        return [
            BudgetPlanItem(name: "Зарплата", type: .income, sortOrder: 1),
            BudgetPlanItem(name: "Фриланс", type: .income, sortOrder: 2),
            BudgetPlanItem(name: "Бизнес / Дивиденды", type: .income, sortOrder: 3),
            BudgetPlanItem(name: "Пассивный доход", type: .income, sortOrder: 4),
            BudgetPlanItem(name: "Подарки и переводы", type: .income, sortOrder: 5),
            BudgetPlanItem(name: "Продажа вещей", type: .income, sortOrder: 6),
            BudgetPlanItem(name: "Стипендия / Грант", type: .income, sortOrder: 7),
            BudgetPlanItem(name: "Социальные выплаты", type: .income, sortOrder: 8),
            BudgetPlanItem(name: "Прочие поступления", type: .income, sortOrder: 9)
        ]
    }
    
    private func createDefaultExpenseItems() -> [BudgetPlanItem] {
        return [
            BudgetPlanItem(name: "Жилье", type: .expense, sortOrder: 1),
            BudgetPlanItem(name: "Связь и интернет", type: .expense, sortOrder: 2),
            BudgetPlanItem(name: "Страхование", type: .expense, sortOrder: 3),
            BudgetPlanItem(name: "Абонементы", type: .expense, sortOrder: 4),
            BudgetPlanItem(name: "Подписки", type: .expense, sortOrder: 5),
            BudgetPlanItem(name: "Семейные расходы", type: .expense, sortOrder: 6),
            BudgetPlanItem(name: "Еда и напитки", type: .expense, sortOrder: 7),
            BudgetPlanItem(name: "Личные расходы", type: .expense, sortOrder: 8),
            BudgetPlanItem(name: "Транспорт", type: .expense, sortOrder: 9),
            BudgetPlanItem(name: "Кредиты", type: .expense, sortOrder: 10),
            BudgetPlanItem(name: "Автомобиль", type: .expense, sortOrder: 11),
            BudgetPlanItem(name: "Образование и развитие", type: .expense, sortOrder: 12),
            BudgetPlanItem(name: "Здоровье", type: .expense, sortOrder: 13),
            BudgetPlanItem(name: "Развлечения и отдых", type: .expense, sortOrder: 14),
            BudgetPlanItem(name: "Покупки и шопинг", type: .expense, sortOrder: 15)
        ]
    }
    
    private func createDefaultDebtItems() -> [BudgetPlanItem] {
        return [
            BudgetPlanItem(name: "Поступления расходы", type: .debt, sortOrder: 1),
            BudgetPlanItem(name: "Накопления предыдущий месяц", type: .debt, sortOrder: 2),
            BudgetPlanItem(name: "Накопления текущий месяц", type: .debt, sortOrder: 3),
            BudgetPlanItem(name: "Подушка безопасности", type: .debt, sortOrder: 4),
            BudgetPlanItem(name: "Вклады", type: .debt, sortOrder: 5),
            BudgetPlanItem(name: "Дивиденды", type: .debt, sortOrder: 6),
            BudgetPlanItem(name: "Криптовалюта", type: .debt, sortOrder: 7)
        ]
    }
    
    private func createDefaultSavingsItems() -> [BudgetPlanItem] {
        return [
            BudgetPlanItem(name: "Резервный фонд", type: .savings, sortOrder: 1),
            BudgetPlanItem(name: "Инвестиции", type: .savings, sortOrder: 2),
            BudgetPlanItem(name: "Крупная покупка", type: .savings, sortOrder: 3),
            BudgetPlanItem(name: "Отпуск", type: .savings, sortOrder: 4),
            BudgetPlanItem(name: "Образование", type: .savings, sortOrder: 5)
        ]
    }
}

// MARK: - Helper Extensions

extension BudgetPlannerViewModel {
    
    /// Получает все доступные годы
    func getAvailableYears() -> [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...(currentYear + 5))
    }
    
    /// Получает все месяцы
    func getAvailableMonths() -> [(Int, String)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        formatter.locale = Locale(identifier: "ru_RU")
        
        return (1...12).map { month in
            let date = Calendar.current.date(from: DateComponents(month: month)) ?? Date()
            return (month, formatter.string(from: date).capitalized)
        }
    }
    
    /// Получает цвет для типа бюджетной статьи
    func getColorForItemType(_ type: BudgetItemType) -> Color {
        return Color(hex: type.color)
    }
    
    /// Проверяет есть ли данные для отображения
    func hasData() -> Bool {
        return currentBudgetPlan != nil
    }
    
    /// Получает процент выполнения плана
    func getCompletionPercentage(for item: BudgetPlanItem) -> Double {
        guard item.plannedAmount > 0 else { return 0 }
        return Double(item.actualAmount / item.plannedAmount) * 100
    }
    
    /// Получает статус выполнения плана
    func getCompletionStatus(for item: BudgetPlanItem) -> String {
        let percentage = getCompletionPercentage(for: item)
        
        if percentage >= 100 {
            return "Выполнено"
        } else if percentage >= 80 {
            return "Почти выполнено"
        } else if percentage >= 50 {
            return "В процессе"
        } else {
            return "Начато"
        }
    }
    
    /// Получает цвет для статуса выполнения
    func getStatusColor(for item: BudgetPlanItem) -> Color {
        let percentage = getCompletionPercentage(for: item)
        
        if percentage >= 100 {
            return .green
        } else if percentage >= 80 {
            return .blue
        } else if percentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }
} 