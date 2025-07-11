import Foundation
import SwiftData

// MARK: - Category Service Protocol

protocol CategoryServiceProtocol {
    // MARK: - Category Management
    func getDefaultCategories() async throws -> [Category]
    func createCustomCategory(_ category: Category) async throws
    func updateCategory(_ category: Category) async throws
    func deleteCategory(_ category: Category) async throws
    func getCategoriesForType(_ type: CategoryType) async throws -> [Category]
    
    // MARK: - Category Analytics
    func getCategoryStats(for period: DateInterval) async throws -> [CategoryStats]
    func getCategoryTrends(for category: Category, period: DateInterval) async throws -> CategoryTrend
    func getTopCategories(limit: Int, type: TransactionType) async throws -> [Category]
    
    // MARK: - Category Suggestions
    func suggestCategory(for description: String, amount: Decimal) async -> Category?
    func getCategorySuggestions(based on: [Transaction]) async throws -> [CategorySuggestion]
    func learnFromCategorization(_ transaction: Transaction, category: Category) async throws
    
    // MARK: - Category Hierarchy
    func createSubcategory(_ subcategory: Category, parent: Category) async throws
    func getCategoryHierarchy() async throws -> [CategoryNode]
    func getSubcategories(for parent: Category) async throws -> [Category]
    
    // MARK: - Import/Export
    func exportCategories() async throws -> [CategoryExport]
    func importCategories(_ categories: [CategoryImport]) async throws
}

// MARK: - Supporting Data Structures

struct CategoryStats {
    let category: Category
    let totalAmount: Decimal
    let transactionCount: Int
    let averageAmount: Decimal
    let percentage: Double
    let period: DateInterval
    let trend: TrendIndicator
    
    enum TrendIndicator {
        case increasing(Double)
        case decreasing(Double)
        case stable
    }
}

struct CategoryTrend {
    let category: Category
    let period: DateInterval
    let dailyAverages: [Date: Decimal]
    let weeklyTotals: [Date: Decimal]
    let monthlyTotals: [Date: Decimal]
    let trendDirection: TrendDirection
    let changePercentage: Double
    let projectedNextMonth: Decimal
    
    enum TrendDirection {
        case increasing
        case decreasing
        case stable
    }
}

struct CategorySuggestion {
    let transaction: Transaction
    let suggestedCategory: Category
    let confidence: Double
    let reason: SuggestionReason
    
    enum SuggestionReason {
        case similarTransactions
        case amountPattern
        case descriptionMatch
        case historicalPattern
        case merchantPattern
    }
}

struct CategoryNode {
    let category: Category
    let subcategories: [CategoryNode]
    let totalAmount: Decimal
    let transactionCount: Int
}

struct CategoryExport {
    let id: String
    let name: String
    let icon: String
    let color: String
    let type: String
    let parentId: String?
    let isSystem: Bool
    let createdAt: Date
}

struct CategoryImport {
    let name: String
    let icon: String
    let color: String
    let type: CategoryType
    let parentName: String?
    let isCustom: Bool
}

// MARK: - Predefined Finance Categories

struct FinanceCategory {
    let id = UUID()
    let name: String
    let icon: String
    let color: String
    let type: TransactionType
    let isSystem: Bool
    let keywords: [String]
    
    // Expense Categories
    static let predefinedExpenseCategories = [
        FinanceCategory(
            name: "Еда и продукты",
            icon: "fork.knife",
            color: "#FF6B6B",
            type: .expense,
            isSystem: true,
            keywords: ["продукты", "еда", "ресторан", "кафе", "обед", "завтрак", "ужин", "пятерочка", "магнит", "перекресток", "азбука вкуса"]
        ),
        FinanceCategory(
            name: "Транспорт",
            icon: "car",
            color: "#4ECDC4",
            type: .expense,
            isSystem: true,
            keywords: ["метро", "автобус", "такси", "бензин", "парковка", "яндекс такси", "uber", "каршеринг", "транспорт"]
        ),
        FinanceCategory(
            name: "Развлечения",
            icon: "gamecontroller",
            color: "#45B7D1",
            type: .expense,
            isSystem: true,
            keywords: ["кино", "театр", "концерт", "игры", "развлечения", "клуб", "бар", "отдых"]
        ),
        FinanceCategory(
            name: "Покупки и одежда",
            icon: "bag",
            color: "#F39C12",
            type: .expense,
            isSystem: true,
            keywords: ["одежда", "обувь", "покупки", "шопинг", "магазин", "h&m", "zara", "uniqlo", "wildberries", "озон"]
        ),
        FinanceCategory(
            name: "Здоровье и медицина",
            icon: "heart",
            color: "#E74C3C",
            type: .expense,
            isSystem: true,
            keywords: ["врач", "аптека", "лекарства", "медицина", "больница", "стоматолог", "анализы", "здоровье"]
        ),
        FinanceCategory(
            name: "Образование",
            icon: "book",
            color: "#9B59B6",
            type: .expense,
            isSystem: true,
            keywords: ["курсы", "обучение", "книги", "университет", "школа", "образование", "семинар", "тренинг"]
        ),
        FinanceCategory(
            name: "Коммунальные услуги",
            icon: "house",
            color: "#34495E",
            type: .expense,
            isSystem: true,
            keywords: ["электричество", "газ", "вода", "интернет", "телефон", "жкх", "коммуналка", "квартплата"]
        ),
        FinanceCategory(
            name: "Красота и уход",
            icon: "sparkles",
            color: "#E91E63",
            type: .expense,
            isSystem: true,
            keywords: ["салон", "парикмахерская", "маникюр", "косметика", "красота", "уход", "спа"]
        ),
        FinanceCategory(
            name: "Спорт и фитнес",
            icon: "figure.run",
            color: "#4CAF50",
            type: .expense,
            isSystem: true,
            keywords: ["спортзал", "фитнес", "тренировка", "спорт", "абонемент", "йога", "бассейн"]
        ),
        FinanceCategory(
            name: "Путешествия",
            icon: "airplane",
            color: "#FF9800",
            type: .expense,
            isSystem: true,
            keywords: ["отель", "авиабилеты", "путешествие", "отпуск", "туризм", "виза", "booking"]
        ),
        FinanceCategory(
            name: "Подарки",
            icon: "gift",
            color: "#F1C40F",
            type: .expense,
            isSystem: true,
            keywords: ["подарок", "день рождения", "праздник", "сувенир", "цветы"]
        ),
        FinanceCategory(
            name: "Прочие расходы",
            icon: "ellipsis.circle",
            color: "#95A5A6",
            type: .expense,
            isSystem: true,
            keywords: ["прочее", "разное", "другое"]
        )
    ]
    
    // Income Categories
    static let predefinedIncomeCategories = [
        FinanceCategory(
            name: "Зарплата",
            icon: "banknote",
            color: "#27AE60",
            type: .income,
            isSystem: true,
            keywords: ["зарплата", "оклад", "заработная плата", "salary"]
        ),
        FinanceCategory(
            name: "Фриланс",
            icon: "laptop",
            color: "#2ECC71",
            type: .income,
            isSystem: true,
            keywords: ["фриланс", "подработка", "freelance", "заказ", "проект"]
        ),
        FinanceCategory(
            name: "Инвестиции и дивиденды",
            icon: "chart.line.uptrend.xyaxis",
            color: "#16A085",
            type: .income,
            isSystem: true,
            keywords: ["дивиденды", "инвестиции", "акции", "облигации", "прибыль", "доходность"]
        ),
        FinanceCategory(
            name: "Подарки и призы",
            icon: "gift",
            color: "#F39C12",
            type: .income,
            isSystem: true,
            keywords: ["подарок", "приз", "выигрыш", "бонус", "премия"]
        ),
        FinanceCategory(
            name: "Продажи",
            icon: "cart",
            color: "#E67E22",
            type: .income,
            isSystem: true,
            keywords: ["продажа", "продал", "реализация", "авито", "юла"]
        ),
        FinanceCategory(
            name: "Возврат средств",
            icon: "arrow.counterclockwise",
            color: "#3498DB",
            type: .income,
            isSystem: true,
            keywords: ["возврат", "возмещение", "компенсация", "refund"]
        ),
        FinanceCategory(
            name: "Прочие доходы",
            icon: "plus.circle",
            color: "#1ABC9C",
            type: .income,
            isSystem: true,
            keywords: ["прочий доход", "разное", "другое"]
        )
    ]
}

// MARK: - Category Service Implementation

final class CategoryService: CategoryServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let mlService: MachineLearningServiceProtocol?
    
    // Machine learning models for category prediction
    private var categoryPredictionModel: CategoryPredictionModel?
    private let keywordMatcher = KeywordMatcher()
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        mlService: MachineLearningServiceProtocol? = nil
    ) {
        self.dataService = dataService
        self.mlService = mlService
        
        Task {
            await initializeCategoryPrediction()
        }
    }
    
    // MARK: - Category Management
    
    func getDefaultCategories() async throws -> [Category] {
        // Check if categories already exist
        let existingCategories = try await dataService.fetch(Category.self, predicate: #Predicate { $0.isSystem })
        
        if !existingCategories.isEmpty {
            return existingCategories
        }
        
        // Create default finance categories
        var categories: [Category] = []
        
        // Create expense categories
        for financeCategory in FinanceCategory.predefinedExpenseCategories {
            let category = Category(
                id: financeCategory.id,
                name: financeCategory.name,
                icon: financeCategory.icon,
                color: financeCategory.color,
                type: .finance,
                isSystem: financeCategory.isSystem,
                parentCategory: nil
            )
            categories.append(category)
        }
        
        // Create income categories
        for financeCategory in FinanceCategory.predefinedIncomeCategories {
            let category = Category(
                id: financeCategory.id,
                name: financeCategory.name,
                icon: financeCategory.icon,
                color: financeCategory.color,
                type: .finance,
                isSystem: financeCategory.isSystem,
                parentCategory: nil
            )
            categories.append(category)
        }
        
        // Save to database
        try await dataService.batchSave(categories)
        
        return categories
    }
    
    func createCustomCategory(_ category: Category) async throws {
        try category.validate()
        category.isSystem = false
        try await dataService.save(category)
    }
    
    func updateCategory(_ category: Category) async throws {
        try category.validate()
        category.updateTimestamp()
        category.markForSync()
        try await dataService.save(category)
    }
    
    func deleteCategory(_ category: Category) async throws {
        // Cannot delete system categories
        guard !category.isSystem else {
            throw AppError.cannotDeleteSystemCategory
        }
        
        // Check if category has transactions
        let transactionsWithCategory = try await dataService.fetch(Transaction.self, predicate: #Predicate { $0.category?.id == category.id })
        
        if !transactionsWithCategory.isEmpty {
            throw AppError.categoryHasTransactions
        }
        
        try await dataService.delete(category)
    }
    
    func getCategoriesForType(_ type: CategoryType) async throws -> [Category] {
        return try await dataService.fetch(Category.self, predicate: #Predicate { $0.type == type })
    }
    
    // MARK: - Category Analytics
    
    func getCategoryStats(for period: DateInterval) async throws -> [CategoryStats] {
        let transactions = try await dataService.fetch(Transaction.self, predicate: #Predicate { transaction in
            transaction.date >= period.start && transaction.date <= period.end
        })
        
        // Group by category
        let grouped = Dictionary(grouping: transactions) { $0.category }
        
        var stats: [CategoryStats] = []
        let totalAmount = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        for (category, categoryTransactions) in grouped {
            guard let category = category else { continue }
            
            let categoryTotal = categoryTransactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
            let averageAmount = categoryTransactions.count > 0 ? 
                categoryTotal / Decimal(categoryTransactions.count) : 0
            let percentage = totalAmount > 0 ? Double(categoryTotal / totalAmount) * 100 : 0
            
            // Calculate trend
            let trend = try await calculateCategoryTrend(category: category, transactions: categoryTransactions, period: period)
            
            let categoryStats = CategoryStats(
                category: category,
                totalAmount: categoryTotal,
                transactionCount: categoryTransactions.count,
                averageAmount: averageAmount,
                percentage: percentage,
                period: period,
                trend: trend
            )
            
            stats.append(categoryStats)
        }
        
        return stats.sorted { $0.totalAmount > $1.totalAmount }
    }
    
    func getCategoryTrends(for category: Category, period: DateInterval) async throws -> CategoryTrend {
        let transactions = try await dataService.fetch(Transaction.self, predicate: #Predicate { transaction in
            transaction.category?.id == category.id &&
            transaction.date >= period.start &&
            transaction.date <= period.end
        })
        
        let calendar = Calendar.current
        
        // Calculate daily averages
        let dailyGrouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        
        let dailyAverages = dailyGrouped.mapValues { transactions in
            transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        }
        
        // Calculate weekly totals
        let weeklyGrouped = Dictionary(grouping: transactions) { transaction in
            calendar.dateInterval(of: .weekOfYear, for: transaction.date)?.start ?? transaction.date
        }
        
        let weeklyTotals = weeklyGrouped.mapValues { transactions in
            transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        }
        
        // Calculate monthly totals
        let monthlyGrouped = Dictionary(grouping: transactions) { transaction in
            calendar.dateInterval(of: .month, for: transaction.date)?.start ?? transaction.date
        }
        
        let monthlyTotals = monthlyGrouped.mapValues { transactions in
            transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        }
        
        // Determine trend direction
        let (trendDirection, changePercentage) = calculateTrendDirection(from: Array(dailyAverages.values))
        
        // Project next month
        let projectedNextMonth = calculateProjectedNextMonth(from: monthlyTotals)
        
        return CategoryTrend(
            category: category,
            period: period,
            dailyAverages: dailyAverages,
            weeklyTotals: weeklyTotals,
            monthlyTotals: monthlyTotals,
            trendDirection: trendDirection,
            changePercentage: changePercentage,
            projectedNextMonth: projectedNextMonth
        )
    }
    
    func getTopCategories(limit: Int, type: TransactionType) async throws -> [Category] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let period = DateInterval(start: thirtyDaysAgo, end: Date())
        
        let transactions = try await dataService.fetch(Transaction.self, predicate: #Predicate { transaction in
            transaction.type == type &&
            transaction.date >= period.start &&
            transaction.date <= period.end
        })
        
        let grouped = Dictionary(grouping: transactions) { $0.category }
        
        let categoryTotals = grouped.compactMapValues { transactions -> (Category, Decimal)? in
            guard let category = transactions.first?.category else { return nil }
            let total = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
            return (category, total)
        }
        
        return categoryTotals.values
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    // MARK: - Category Suggestions
    
    func suggestCategory(for description: String, amount: Decimal) async -> Category? {
        // Try ML-based prediction first
        if let mlService = mlService,
           let category = await mlService.predictCategory(description: description, amount: amount) {
            return category
        }
        
        // Fallback to keyword matching
        return await keywordMatcher.findBestMatch(for: description, amount: amount)
    }
    
    func getCategorySuggestions(based on: [Transaction]) async throws -> [CategorySuggestion] {
        var suggestions: [CategorySuggestion] = []
        
        for transaction in on {
            guard transaction.category == nil else { continue }
            
            // Get historical transactions with similar characteristics
            let similarTransactions = try await findSimilarTransactions(to: transaction)
            
            if let suggestedCategory = await suggestCategoryFromSimilarTransactions(similarTransactions) {
                let confidence = calculateSuggestionConfidence(
                    transaction: transaction,
                    category: suggestedCategory,
                    similarTransactions: similarTransactions
                )
                
                let suggestion = CategorySuggestion(
                    transaction: transaction,
                    suggestedCategory: suggestedCategory,
                    confidence: confidence,
                    reason: .similarTransactions
                )
                
                suggestions.append(suggestion)
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    func learnFromCategorization(_ transaction: Transaction, category: Category) async throws {
        // Store the categorization for ML learning
        if let mlService = mlService {
            await mlService.learnCategorization(
                description: transaction.title,
                amount: transaction.amount,
                category: category
            )
        }
        
        // Update keyword matching
        await keywordMatcher.learnFromCategorization(
            description: transaction.title,
            category: category
        )
    }
    
    // MARK: - Category Hierarchy
    
    func createSubcategory(_ subcategory: Category, parent: Category) async throws {
        subcategory.parentCategory = parent
        try await createCustomCategory(subcategory)
    }
    
    func getCategoryHierarchy() async throws -> [CategoryNode] {
        let allCategories = try await dataService.fetch(Category.self, predicate: nil)
        let rootCategories = allCategories.filter { $0.parentCategory == nil }
        
        var nodes: [CategoryNode] = []
        
        for rootCategory in rootCategories {
            let node = try await buildCategoryNode(for: rootCategory, allCategories: allCategories)
            nodes.append(node)
        }
        
        return nodes.sorted { $0.category.name < $1.category.name }
    }
    
    func getSubcategories(for parent: Category) async throws -> [Category] {
        return try await dataService.fetch(Category.self, predicate: #Predicate { $0.parentCategory?.id == parent.id })
    }
    
    // MARK: - Import/Export
    
    func exportCategories() async throws -> [CategoryExport] {
        let categories = try await dataService.fetch(Category.self, predicate: nil)
        
        return categories.map { category in
            CategoryExport(
                id: category.id.uuidString,
                name: category.name,
                icon: category.icon,
                color: category.color,
                type: category.type.rawValue,
                parentId: category.parentCategory?.id.uuidString,
                isSystem: category.isSystem,
                createdAt: category.createdAt
            )
        }
    }
    
    func importCategories(_ categories: [CategoryImport]) async throws {
        var createdCategories: [String: Category] = [:]
        
        // First pass: create categories without parent relationships
        for categoryImport in categories {
            let category = Category(
                name: categoryImport.name,
                icon: categoryImport.icon,
                color: categoryImport.color,
                type: categoryImport.type,
                isSystem: false,
                parentCategory: nil
            )
            
            try await dataService.save(category)
            createdCategories[categoryImport.name] = category
        }
        
        // Second pass: establish parent relationships
        for categoryImport in categories {
            guard let parentName = categoryImport.parentName,
                  let parentCategory = createdCategories[parentName],
                  let childCategory = createdCategories[categoryImport.name] else { continue }
            
            childCategory.parentCategory = parentCategory
            try await dataService.save(childCategory)
        }
    }
}

// MARK: - Private Helper Methods

private extension CategoryService {
    
    func initializeCategoryPrediction() async {
        // Initialize ML model if available
        if let mlService = mlService {
            categoryPredictionModel = await mlService.loadCategoryPredictionModel()
        }
        
        // Initialize keyword matcher with predefined categories
        await keywordMatcher.initializeWithPredefinedCategories()
    }
    
    func calculateCategoryTrend(
        category: Category,
        transactions: [Transaction],
        period: DateInterval
    ) async throws -> CategoryStats.TrendIndicator {
        // Compare with previous period
        let previousPeriod = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -Int(period.duration / 86400), to: period.start) ?? period.start,
            duration: period.duration
        )
        
        let previousTransactions = try await dataService.fetch(Transaction.self, predicate: #Predicate { transaction in
            transaction.category?.id == category.id &&
            transaction.date >= previousPeriod.start &&
            transaction.date <= previousPeriod.end
        })
        
        let currentTotal = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        let previousTotal = previousTransactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        guard previousTotal > 0 else { return .stable }
        
        let changePercentage = Double((currentTotal - previousTotal) / previousTotal) * 100
        
        if abs(changePercentage) < 5 {
            return .stable
        } else if changePercentage > 0 {
            return .increasing(changePercentage)
        } else {
            return .decreasing(abs(changePercentage))
        }
    }
    
    func calculateTrendDirection(from values: [Decimal]) -> (CategoryTrend.TrendDirection, Double) {
        guard values.count >= 2 else { return (.stable, 0) }
        
        let first = values.first!
        let last = values.last!
        
        let changePercentage = first > 0 ? Double((last - first) / first) * 100 : 0
        
        let direction: CategoryTrend.TrendDirection
        if abs(changePercentage) < 5 {
            direction = .stable
        } else if changePercentage > 0 {
            direction = .increasing
        } else {
            direction = .decreasing
        }
        
        return (direction, changePercentage)
    }
    
    func calculateProjectedNextMonth(from monthlyTotals: [Date: Decimal]) -> Decimal {
        let values = Array(monthlyTotals.values)
        guard !values.isEmpty else { return 0 }
        
        // Simple average-based projection
        let average = values.reduce(Decimal.zero, +) / Decimal(values.count)
        
        // Apply trend if there's enough data
        if values.count >= 3 {
            let recent = Array(values.suffix(3))
            let recentAverage = recent.reduce(Decimal.zero, +) / Decimal(recent.count)
            
            // Weight recent data more heavily
            return (average + recentAverage * 2) / 3
        }
        
        return average
    }
    
    func findSimilarTransactions(to transaction: Transaction) async throws -> [Transaction] {
        // Look for transactions with similar amounts and descriptions
        let similarTransactions = try await dataService.fetch(Transaction.self, predicate: #Predicate { t in
            t.id != transaction.id &&
            abs(t.amount - transaction.amount) < 100 &&
            t.title.localizedStandardContains(transaction.title)
        })
        
        return similarTransactions.filter { $0.category != nil }
    }
    
    func suggestCategoryFromSimilarTransactions(_ transactions: [Transaction]) async -> Category? {
        guard !transactions.isEmpty else { return nil }
        
        // Find the most common category among similar transactions
        let categoryFrequency = transactions.compactMap { $0.category }
            .reduce(into: [UUID: Int]()) { counts, category in
                counts[category.id, default: 0] += 1
            }
        
        let mostCommonCategoryId = categoryFrequency.max(by: { $0.value < $1.value })?.key
        
        return transactions.first { $0.category?.id == mostCommonCategoryId }?.category
    }
    
    func calculateSuggestionConfidence(
        transaction: Transaction,
        category: Category,
        similarTransactions: [Transaction]
    ) -> Double {
        let baseConfidence = 0.5
        
        // Increase confidence based on number of similar transactions
        let countBonus = min(0.3, Double(similarTransactions.count) * 0.05)
        
        // Increase confidence if descriptions are very similar
        let descriptionSimilarity = calculateStringSimilarity(
            transaction.title,
            category.name
        )
        let descriptionBonus = descriptionSimilarity * 0.2
        
        return min(1.0, baseConfidence + countBonus + descriptionBonus)
    }
    
    func calculateStringSimilarity(_ str1: String, _ str2: String) -> Double {
        let longer = str1.count > str2.count ? str1 : str2
        let shorter = str1.count > str2.count ? str2 : str1
        
        if longer.isEmpty { return 1.0 }
        
        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let str1Array = Array(str1)
        let str2Array = Array(str2)
        
        let str1Count = str1Array.count
        let str2Count = str2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: str2Count + 1), count: str1Count + 1)
        
        for i in 0...str1Count {
            matrix[i][0] = i
        }
        
        for j in 0...str2Count {
            matrix[0][j] = j
        }
        
        for i in 1...str1Count {
            for j in 1...str2Count {
                let cost = str1Array[i - 1] == str2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }
        
        return matrix[str1Count][str2Count]
    }
    
    func buildCategoryNode(for category: Category, allCategories: [Category]) async throws -> CategoryNode {
        let subcategories = allCategories.filter { $0.parentCategory?.id == category.id }
        
        var subcategoryNodes: [CategoryNode] = []
        for subcategory in subcategories {
            let node = try await buildCategoryNode(for: subcategory, allCategories: allCategories)
            subcategoryNodes.append(node)
        }
        
        // Calculate statistics for this category
        let transactions = try await dataService.fetch(Transaction.self, predicate: #Predicate { $0.category?.id == category.id })
        let totalAmount = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmount }
        
        return CategoryNode(
            category: category,
            subcategories: subcategoryNodes,
            totalAmount: totalAmount,
            transactionCount: transactions.count
        )
    }
}

// MARK: - Keyword Matcher

final class KeywordMatcher {
    private var categoryKeywords: [UUID: [String]] = [:]
    
    func initializeWithPredefinedCategories() async {
        // Initialize with predefined keywords
        for category in FinanceCategory.predefinedExpenseCategories + FinanceCategory.predefinedIncomeCategories {
            categoryKeywords[category.id] = category.keywords
        }
    }
    
    func findBestMatch(for description: String, amount: Decimal) async -> Category? {
        let lowercaseDescription = description.lowercased()
        var bestMatch: (categoryId: UUID, score: Int) = (UUID(), 0)
        
        for (categoryId, keywords) in categoryKeywords {
            let score = keywords.reduce(0) { score, keyword in
                if lowercaseDescription.contains(keyword.lowercased()) {
                    return score + keyword.count
                }
                return score
            }
            
            if score > bestMatch.score {
                bestMatch = (categoryId, score)
            }
        }
        
        // Try to find category with matching ID (this is a simplified approach)
        // In real implementation, you'd need to fetch the category from the database
        return nil
    }
    
    func learnFromCategorization(description: String, category: Category) async {
        // Extract keywords from the description and associate with category
        let words = description.lowercased()
            .components(separatedBy: .whitespacesAndPunctuation)
            .filter { $0.count > 2 }
        
        if categoryKeywords[category.id] == nil {
            categoryKeywords[category.id] = []
        }
        
        for word in words {
            if !categoryKeywords[category.id]!.contains(word) {
                categoryKeywords[category.id]!.append(word)
            }
        }
    }
}

// MARK: - Machine Learning Service Protocol

protocol MachineLearningServiceProtocol {
    func predictCategory(description: String, amount: Decimal) async -> Category?
    func learnCategorization(description: String, amount: Decimal, category: Category) async
    func loadCategoryPredictionModel() async -> CategoryPredictionModel?
}

// MARK: - Category Prediction Model

final class CategoryPredictionModel {
    // Placeholder for ML model implementation
    // In real app, this would use CreateML or external ML service
    
    func predict(description: String, amount: Decimal) async -> Category? {
        // Implement ML prediction logic
        return nil
    }
    
    func train(data: [(description: String, amount: Decimal, category: Category)]) async {
        // Implement model training
    }
} 