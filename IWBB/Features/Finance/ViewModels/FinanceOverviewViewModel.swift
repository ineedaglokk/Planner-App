import Foundation
import SwiftUI

// MARK: - FinanceOverviewViewModel

@Observable
final class FinanceOverviewViewModel {
    
    // MARK: - Services
    
    private let financeService: FinanceServiceProtocol
    
    // MARK: - State Properties
    
    var expenseEntries: [ExpenseEntry] = []
    var incomeEntries: [IncomeEntry] = []
    var monthlySummaries: [MonthlySummary] = []
    var currentMonthSummary: MonthlySummary?
    
    // MARK: - UI State
    
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var showError = false
    
    // MARK: - Add Entry State
    
    var showAddExpenseSheet = false
    var showAddIncomeSheet = false
    var showEditExpenseSheet = false
    var showEditIncomeSheet = false
    
    var expenseEntryName = ""
    var expenseEntryAmount = ""
    var expenseEntryNotes = ""
    var isExpenseAmountValid = false
    var expenseAmountDecimal: Decimal?
    
    var incomeEntryName = ""
    var incomeEntryAmount = ""
    var incomeEntryNotes = ""
    var isIncomeAmountValid = false
    var incomeAmountDecimal: Decimal?
    
    var editingExpenseEntry: ExpenseEntry?
    var editingIncomeEntry: IncomeEntry?
    
    // MARK: - Computed Properties
    

    
    var totalExpenses: Decimal {
        return currentMonthSummary?.totalExpenses ?? 0
    }
    
    var totalIncome: Decimal {
        return currentMonthSummary?.totalIncome ?? 0
    }
    
    var totalSavings: Decimal {
        return currentMonthSummary?.totalSavings ?? 0
    }
    
    var formattedTotalExpenses: String {
        return currentMonthSummary?.formattedTotalExpenses ?? "0 ₽"
    }
    
    var formattedTotalIncome: String {
        return currentMonthSummary?.formattedTotalIncome ?? "0 ₽"
    }
    
    var formattedTotalSavings: String {
        return currentMonthSummary?.formattedTotalSavings ?? "0 ₽"
    }
    
    var canAddExpense: Bool {
        return !expenseEntryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               isExpenseAmountValid
    }
    
    var canAddIncome: Bool {
        return !incomeEntryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               isIncomeAmountValid
    }
    
    // MARK: - Initialization
    
    init(financeService: FinanceServiceProtocol) {
        self.financeService = financeService
    }
    
    convenience init() {
        // Для Preview и тестирования
        let mockService = MockFinanceService()
        self.init(financeService: mockService)
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let expenses = financeService.getExpenseEntries()
            async let incomes = financeService.getIncomeEntries()
            async let summaries = financeService.getMonthlySummaries()
            async let currentSummary = financeService.getCurrentMonthSummary()
            
            self.expenseEntries = try await expenses
            self.incomeEntries = try await incomes
            self.monthlySummaries = try await summaries
            self.currentMonthSummary = try await currentSummary
            
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
    
    // MARK: - Expense Entry Methods
    
    @MainActor
    func addExpenseEntry() async {
        guard canAddExpense, let amount = expenseAmountDecimal else { return }
        
        do {
            let notes = expenseEntryNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            let notesValue = notes.isEmpty ? nil : notes
            
            _ = try await financeService.addExpenseEntry(
                name: expenseEntryName,
                amount: amount,
                notes: notesValue
            )
            
            // Очищаем форму
            clearExpenseForm()
            
            // Обновляем данные
            await refresh()
            
            // Закрываем лист
            showAddExpenseSheet = false
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func updateExpenseEntry() async {
        guard let entry = editingExpenseEntry,
              canAddExpense,
              let amount = expenseAmountDecimal else { return }
        
        do {
            entry.updateName(expenseEntryName)
            entry.updateAmount(amount)
            
            let notes = expenseEntryNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.notes = notes.isEmpty ? nil : notes
            
            try await financeService.updateExpenseEntry(entry)
            
            // Очищаем форму
            clearExpenseForm()
            editingExpenseEntry = nil
            
            // Обновляем данные
            await refresh()
            
            // Закрываем лист
            showEditExpenseSheet = false
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func deleteExpenseEntry(_ entry: ExpenseEntry) async {
        do {
            try await financeService.deleteExpenseEntry(entry)
            await refresh()
        } catch {
            await handleError(error)
        }
    }
    
    func startEditingExpenseEntry(_ entry: ExpenseEntry) {
        editingExpenseEntry = entry
        expenseEntryName = entry.name
        expenseEntryAmount = entry.amount.description
        expenseEntryNotes = entry.notes ?? ""
        
        // Валидируем введенные данные
        let validation = financeService.validateAmount(expenseEntryAmount)
        isExpenseAmountValid = validation.isValid
        expenseAmountDecimal = validation.decimal
        
        showEditExpenseSheet = true
    }
    
    func clearExpenseForm() {
        expenseEntryName = ""
        expenseEntryAmount = ""
        expenseEntryNotes = ""
        isExpenseAmountValid = false
        expenseAmountDecimal = nil
    }
    
    // MARK: - Income Entry Methods
    
    @MainActor
    func addIncomeEntry() async {
        guard canAddIncome, let amount = incomeAmountDecimal else { return }
        
        do {
            let notes = incomeEntryNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            let notesValue = notes.isEmpty ? nil : notes
            
            _ = try await financeService.addIncomeEntry(
                name: incomeEntryName,
                amount: amount,
                notes: notesValue
            )
            
            // Очищаем форму
            clearIncomeForm()
            
            // Обновляем данные
            await refresh()
            
            // Закрываем лист
            showAddIncomeSheet = false
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func updateIncomeEntry() async {
        guard let entry = editingIncomeEntry,
              canAddIncome,
              let amount = incomeAmountDecimal else { return }
        
        do {
            entry.updateName(incomeEntryName)
            entry.updateAmount(amount)
            
            let notes = incomeEntryNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.notes = notes.isEmpty ? nil : notes
            
            try await financeService.updateIncomeEntry(entry)
            
            // Очищаем форму
            clearIncomeForm()
            editingIncomeEntry = nil
            
            // Обновляем данные
            await refresh()
            
            // Закрываем лист
            showEditIncomeSheet = false
            
        } catch {
            await handleError(error)
        }
    }
    
    @MainActor
    func deleteIncomeEntry(_ entry: IncomeEntry) async {
        do {
            try await financeService.deleteIncomeEntry(entry)
            await refresh()
        } catch {
            await handleError(error)
        }
    }
    
    func startEditingIncomeEntry(_ entry: IncomeEntry) {
        editingIncomeEntry = entry
        incomeEntryName = entry.name
        incomeEntryAmount = entry.amount.description
        incomeEntryNotes = entry.notes ?? ""
        
        // Валидируем введенные данные
        let validation = financeService.validateAmount(incomeEntryAmount)
        isIncomeAmountValid = validation.isValid
        incomeAmountDecimal = validation.decimal
        
        showEditIncomeSheet = true
    }
    
    func clearIncomeForm() {
        incomeEntryName = ""
        incomeEntryAmount = ""
        incomeEntryNotes = ""
        isIncomeAmountValid = false
        incomeAmountDecimal = nil
    }
    
    // MARK: - Validation Handlers
    
    func onExpenseAmountValidationChange(isValid: Bool, decimal: Decimal?) {
        isExpenseAmountValid = isValid
        expenseAmountDecimal = decimal
    }
    
    func onIncomeAmountValidationChange(isValid: Bool, decimal: Decimal?) {
        isIncomeAmountValid = isValid
        incomeAmountDecimal = decimal
    }
    
    // MARK: - Utility Methods
    
    #if DEBUG
    @MainActor
    func clearAllData() async {
        do {
            if let service = financeService as? FinanceService {
                try await service.clearAllData()
                await refresh()
            }
        } catch {
            await handleError(error)
        }
    }
    #endif
    
    @MainActor
    private func handleError(_ error: Error) {
        let appError = AppError.from(error)
        errorMessage = appError.localizedDescription
        showError = true
        
        #if DEBUG
        print("FinanceOverviewViewModel Error: \(error)")
        #endif
    }
}

// MARK: - Mock Service for Preview

class MockFinanceService: FinanceServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws {}
    func cleanup() async {}
    
    func addExpenseEntry(name: String, amount: Decimal, notes: String?) async throws -> ExpenseEntry {
        return ExpenseEntry(name: name, amount: amount, notes: notes)
    }
    
    func addIncomeEntry(name: String, amount: Decimal, notes: String?) async throws -> IncomeEntry {
        return IncomeEntry(name: name, amount: amount, notes: notes)
    }
    
    func updateExpenseEntry(_ entry: ExpenseEntry) async throws {}
    func updateIncomeEntry(_ entry: IncomeEntry) async throws {}
    func deleteExpenseEntry(_ entry: ExpenseEntry) async throws {}
    func deleteIncomeEntry(_ entry: IncomeEntry) async throws {}
    
    func getExpenseEntries() async throws -> [ExpenseEntry] {
        return []
    }
    
    func getIncomeEntries() async throws -> [IncomeEntry] {
        return []
    }
    
    func getMonthlySummaries() async throws -> [MonthlySummary] {
        return []
    }
    
    func getCurrentMonthSummary() async throws -> MonthlySummary {
        return MonthlySummary.createCurrentMonth()
    }
    
    func hasAnyFinancialData() async throws -> Bool {
        return false
    }
    
    func initializeEmptyState() async throws {}
    
    func recalculateCurrentMonth() async throws -> MonthlySummary {
        return MonthlySummary.createCurrentMonth()
    }
    
    func recalculateAllData() async throws -> [MonthlySummary] {
        return []
    }
    
    func getTotalBalance() async throws -> Decimal {
        return 0
    }
    
    func getBalanceForMonth(_ month: String) async throws -> Decimal {
        return 0
    }
    
    func getExpensesByCategory(for month: String) async throws -> [CategoryStatistic] {
        return []
    }
    
    func getIncomesByCategory(for month: String) async throws -> [CategoryStatistic] {
        return []
    }
    
    func validateAmount(_ amount: String) -> (isValid: Bool, decimal: Decimal?) {
        return FinanceService.validateAmount(amount)
    }
    
    func validateEntryName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
} 