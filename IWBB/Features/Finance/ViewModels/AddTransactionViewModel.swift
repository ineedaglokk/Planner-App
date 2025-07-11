import Foundation
import SwiftUI

// MARK: - Add Transaction ViewModel

@Observable
final class AddTransactionViewModel {
    
    // MARK: - State
    
    struct State {
        // Transaction Data
        var amount: Decimal = 0
        var type: TransactionType = .expense
        var title: String = ""
        var description: String = ""
        var date: Date = Date()
        var selectedCategory: Category?
        var account: String = ""
        var paymentMethod: PaymentMethod = .card
        var currency: String = "RUB"
        var tags: [String] = []
        
        // Recurring Transaction
        var isRecurring: Bool = false
        var recurringPattern: TransactionRecurringPattern?
        
        // UI State
        var availableCategories: [Category] = []
        var suggestedCategories: [Category] = []
        var quickAmounts: [Decimal] = [100, 500, 1000, 2000, 5000]
        var recentTransactions: [Transaction] = []
        var currencies: [Currency] = []
        
        var isLoading: Bool = false
        var isSaving: Bool = false
        var error: AppError?
        var validationErrors: [ValidationError] = []
        
        // Form State
        var isFormValid: Bool = false
        var showingCategoryPicker: Bool = false
        var showingCurrencyPicker: Bool = false
        var showingRecurringOptions: Bool = false
        var showingAdvancedOptions: Bool = false
        
        // Camera/Photo
        var receiptPhoto: UIImage?
        var showingImagePicker: Bool = false
        var imagePickerSourceType: UIImagePickerController.SourceType = .camera
        
        // Quick Entry
        var isQuickEntry: Bool = false
        var duplicateCheckEnabled: Bool = true
    }
    
    // MARK: - Input
    
    enum Input {
        case loadInitialData
        case amountChanged(Decimal)
        case typeChanged(TransactionType)
        case titleChanged(String)
        case descriptionChanged(String)
        case dateChanged(Date)
        case categorySelected(Category)
        case accountChanged(String)
        case paymentMethodChanged(PaymentMethod)
        case currencyChanged(String)
        case quickAmountSelected(Decimal)
        case tagAdded(String)
        case tagRemoved(String)
        case recurringToggled(Bool)
        case recurringPatternChanged(TransactionRecurringPattern)
        case photoAdded(UIImage)
        case photoRemoved
        case toggleCategoryPicker
        case toggleCurrencyPicker
        case toggleRecurringOptions
        case toggleAdvancedOptions
        case toggleImagePicker(UIImagePickerController.SourceType)
        case save
        case saveAndCreateAnother
        case cancel
        case reset
        case validateForm
        case useSimilarTransaction(Transaction)
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Services
    private let transactionRepository: TransactionRepositoryProtocol
    private let categoryService: CategoryServiceProtocol
    private let currencyService: CurrencyServiceProtocol
    private let financeService: FinanceServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // Callbacks
    var onTransactionSaved: ((Transaction) -> Void)?
    var onCancel: (() -> Void)?
    
    // MARK: - Initialization
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        categoryService: CategoryServiceProtocol,
        currencyService: CurrencyServiceProtocol,
        financeService: FinanceServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol,
        initialType: TransactionType = .expense
    ) {
        self.transactionRepository = transactionRepository
        self.categoryService = categoryService
        self.currencyService = currencyService
        self.financeService = financeService
        self.errorHandlingService = errorHandlingService
        
        state.type = initialType
        
        Task {
            await initializeAsync()
        }
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadInitialData:
                await loadInitialData()
                
            case .amountChanged(let amount):
                state.amount = amount
                await updateSuggestedCategories()
                validateForm()
                
            case .typeChanged(let type):
                state.type = type
                await loadCategoriesForType(type)
                validateForm()
                
            case .titleChanged(let title):
                state.title = title
                await updateSuggestedCategories()
                validateForm()
                
            case .descriptionChanged(let description):
                state.description = description
                validateForm()
                
            case .dateChanged(let date):
                state.date = date
                validateForm()
                
            case .categorySelected(let category):
                state.selectedCategory = category
                state.showingCategoryPicker = false
                validateForm()
                
            case .accountChanged(let account):
                state.account = account
                
            case .paymentMethodChanged(let method):
                state.paymentMethod = method
                
            case .currencyChanged(let currency):
                state.currency = currency
                state.showingCurrencyPicker = false
                validateForm()
                
            case .quickAmountSelected(let amount):
                state.amount = amount
                await updateSuggestedCategories()
                validateForm()
                
            case .tagAdded(let tag):
                addTag(tag)
                
            case .tagRemoved(let tag):
                removeTag(tag)
                
            case .recurringToggled(let isRecurring):
                state.isRecurring = isRecurring
                if !isRecurring {
                    state.recurringPattern = nil
                }
                
            case .recurringPatternChanged(let pattern):
                state.recurringPattern = pattern
                
            case .photoAdded(let photo):
                state.receiptPhoto = photo
                state.showingImagePicker = false
                
            case .photoRemoved:
                state.receiptPhoto = nil
                
            case .toggleCategoryPicker:
                state.showingCategoryPicker.toggle()
                
            case .toggleCurrencyPicker:
                state.showingCurrencyPicker.toggle()
                
            case .toggleRecurringOptions:
                state.showingRecurringOptions.toggle()
                
            case .toggleAdvancedOptions:
                state.showingAdvancedOptions.toggle()
                
            case .toggleImagePicker(let sourceType):
                state.imagePickerSourceType = sourceType
                state.showingImagePicker.toggle()
                
            case .save:
                await saveTransaction()
                
            case .saveAndCreateAnother:
                await saveTransaction(createAnother: true)
                
            case .cancel:
                cancel()
                
            case .reset:
                resetForm()
                
            case .validateForm:
                validateForm()
                
            case .useSimilarTransaction(let transaction):
                await useSimilarTransaction(transaction)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeAsync() async {
        await MainActor.run {
            state.isLoading = true
        }
        
        await loadInitialData()
        
        await MainActor.run {
            state.isLoading = false
        }
    }
    
    private func loadInitialData() async {
        do {
            // Load in parallel
            async let categories = categoryService.getCategoriesForType(.finance)
            async let currencies = currencyService.getAllCurrencies()
            async let baseCurrency = currencyService.getBaseCurrency()
            async let recentTransactions = transactionRepository.getRecentTransactions(limit: 10)
            
            let categoriesResult = try await categories
            let currenciesResult = try await currencies
            let baseCurrencyResult = try await baseCurrency
            let recentTransactionsResult = try await recentTransactions
            
            await MainActor.run {
                state.availableCategories = categoriesResult
                state.currencies = currenciesResult
                state.currency = baseCurrencyResult.code
                state.recentTransactions = recentTransactionsResult
            }
            
            await loadCategoriesForType(state.type)
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadCategoriesForType(_ type: TransactionType) async {
        // Filter categories based on transaction type
        // In a real app, categories would have associated transaction types
        let filteredCategories = state.availableCategories
        
        await MainActor.run {
            state.availableCategories = filteredCategories
            
            // Clear selected category if it doesn't match new type
            if let selectedCategory = state.selectedCategory,
               !filteredCategories.contains(selectedCategory) {
                state.selectedCategory = nil
            }
        }
    }
    
    private func updateSuggestedCategories() async {
        guard !state.title.isEmpty || state.amount > 0 else {
            await MainActor.run {
                state.suggestedCategories = []
            }
            return
        }
        
        do {
            // Get category suggestion from service
            if let suggestedCategory = await categoryService.suggestCategory(
                for: state.title,
                amount: state.amount
            ) {
                await MainActor.run {
                    state.suggestedCategories = [suggestedCategory]
                }
            } else {
                await MainActor.run {
                    state.suggestedCategories = []
                }
            }
        }
    }
    
    private func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty && !state.tags.contains(cleanTag) {
            state.tags.append(cleanTag)
        }
    }
    
    private func removeTag(_ tag: String) {
        state.tags.removeAll { $0 == tag }
    }
    
    private func validateForm() {
        var errors: [ValidationError] = []
        
        // Amount validation
        if state.amount <= 0 {
            errors.append(.invalidAmount("Сумма должна быть больше 0"))
        }
        
        // Title validation
        if state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle("Название обязательно"))
        }
        
        // Category validation
        if state.selectedCategory == nil {
            errors.append(.noCategory("Выберите категорию"))
        }
        
        // Currency validation
        if state.currency.isEmpty {
            errors.append(.invalidCurrency("Валюта обязательна"))
        }
        
        // Date validation
        let calendar = Calendar.current
        if state.date > calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date() {
            errors.append(.futureDate("Дата не может быть в будущем"))
        }
        
        state.validationErrors = errors
        state.isFormValid = errors.isEmpty
    }
    
    private func saveTransaction(createAnother: Bool = false) async {
        guard state.isFormValid else {
            validateForm()
            return
        }
        
        await MainActor.run {
            state.isSaving = true
            state.error = nil
        }
        
        do {
            // Create transaction
            let transaction = Transaction(
                amount: state.amount,
                type: state.type,
                title: state.title,
                description: state.description.isEmpty ? nil : state.description,
                date: state.date,
                category: state.selectedCategory,
                account: state.account.isEmpty ? nil : state.account,
                currency: state.currency
            )
            
            // Set additional properties
            transaction.paymentMethod = state.paymentMethod
            transaction.tags = state.tags
            transaction.isRecurring = state.isRecurring
            transaction.recurringPattern = state.recurringPattern
            
            // Handle receipt photo
            if let photo = state.receiptPhoto {
                let photoPath = await saveReceiptPhoto(photo)
                transaction.receiptPhoto = photoPath
            }
            
            // Process transaction through finance service
            try await financeService.processTransaction(transaction)
            
            await MainActor.run {
                state.isSaving = false
            }
            
            // Notify about success
            onTransactionSaved?(transaction)
            
            if createAnother {
                resetForm(keepDefaults: true)
            } else {
                onCancel?()
            }
            
        } catch {
            await handleError(error)
            await MainActor.run {
                state.isSaving = false
            }
        }
    }
    
    private func saveReceiptPhoto(_ photo: UIImage) async -> String? {
        // In a real app, this would save the photo to local storage or cloud
        // For now, return a placeholder path
        return "receipt_\(UUID().uuidString).jpg"
    }
    
    private func cancel() {
        onCancel?()
    }
    
    private func resetForm(keepDefaults: Bool = false) {
        if keepDefaults {
            // Keep some settings for quick re-entry
            let savedType = state.type
            let savedCurrency = state.currency
            let savedPaymentMethod = state.paymentMethod
            
            state = State()
            
            state.type = savedType
            state.currency = savedCurrency
            state.paymentMethod = savedPaymentMethod
            state.date = Date()
        } else {
            state = State()
        }
        
        Task {
            await loadInitialData()
        }
    }
    
    private func useSimilarTransaction(_ transaction: Transaction) async {
        await MainActor.run {
            state.amount = transaction.amount
            state.type = transaction.type
            state.title = transaction.title
            state.description = transaction.description ?? ""
            state.selectedCategory = transaction.category
            state.account = transaction.account ?? ""
            state.paymentMethod = transaction.paymentMethod ?? .card
            state.currency = transaction.currency
            state.tags = transaction.tags
        }
        
        validateForm()
    }
    
    private func handleError(_ error: Error) async {
        let appError = AppError.from(error)
        
        await MainActor.run {
            state.error = appError
        }
        
        await errorHandlingService.handle(appError)
    }
}

// MARK: - Supporting Types

enum ValidationError: LocalizedError {
    case invalidAmount(String)
    case emptyTitle(String)
    case noCategory(String)
    case invalidCurrency(String)
    case futureDate(String)
    case duplicateTransaction(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount(let message),
             .emptyTitle(let message),
             .noCategory(let message),
             .invalidCurrency(let message),
             .futureDate(let message),
             .duplicateTransaction(let message):
            return message
        }
    }
}

// MARK: - Computed Properties

extension AddTransactionViewModel.State {
    
    var hasReceiptPhoto: Bool {
        return receiptPhoto != nil
    }
    
    var formattedAmount: String {
        guard amount > 0 else { return "" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
    }
    
    var canSave: Bool {
        return isFormValid && !isSaving
    }
    
    var primaryValidationError: ValidationError? {
        return validationErrors.first
    }
    
    var hasAdvancedOptions: Bool {
        return !account.isEmpty || paymentMethod != .card || !tags.isEmpty || isRecurring
    }
    
    var suggestedCategoriesForType: [Category] {
        return suggestedCategories.filter { category in
            // Filter based on transaction type if categories have type association
            return true // Placeholder
        }
    }
    
    var recentTransactionsForType: [Transaction] {
        return recentTransactions.filter { $0.type == type }.prefix(3).map { $0 }
    }
    
    var duplicateWarning: Transaction? {
        // Check for potential duplicates
        return recentTransactions.first { transaction in
            transaction.amount == amount &&
            transaction.title.lowercased() == title.lowercased() &&
            Calendar.current.isDate(transaction.date, inSameDayAs: date)
        }
    }
}

// MARK: - View Model Factory

extension AddTransactionViewModel {
    
    static func create(
        with services: ServiceContainerProtocol,
        initialType: TransactionType = .expense
    ) -> AddTransactionViewModel {
        return AddTransactionViewModel(
            transactionRepository: services.transactionRepository,
            categoryService: services.categoryService,
            currencyService: services.currencyService,
            financeService: services.financeService,
            errorHandlingService: services.errorHandlingService,
            initialType: initialType
        )
    }
}

// MARK: - Quick Entry Extensions

extension AddTransactionViewModel {
    
    /// Создает ViewModel для быстрого добавления с предустановленными значениями
    static func quickEntry(
        with services: ServiceContainerProtocol,
        amount: Decimal,
        title: String,
        type: TransactionType = .expense
    ) -> AddTransactionViewModel {
        let viewModel = create(with: services, initialType: type)
        
        Task { @MainActor in
            viewModel.state.amount = amount
            viewModel.state.title = title
            viewModel.state.isQuickEntry = true
            viewModel.validateForm()
        }
        
        return viewModel
    }
    
    /// Создает ViewModel на основе существующей транзакции
    static func duplicate(
        with services: ServiceContainerProtocol,
        basedOn transaction: Transaction
    ) -> AddTransactionViewModel {
        let viewModel = create(with: services, initialType: transaction.type)
        
        Task {
            await viewModel.useSimilarTransaction(transaction)
        }
        
        return viewModel
    }
} 