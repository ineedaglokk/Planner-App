import Foundation
import SwiftData
import NaturalLanguage

// MARK: - Categorization Service Protocol

protocol CategorizationServiceProtocol {
    // MARK: - Core Categorization
    func categorizeTransaction(_ transaction: Transaction) async throws -> CategorySuggestion
    func batchCategorizeTransactions(_ transactions: [Transaction]) async throws -> [TransactionCategorization]
    func updateTransactionCategory(_ transaction: Transaction, category: Category) async throws
    func suggestCategories(for description: String, amount: Decimal?) async throws -> [CategorySuggestion]
    
    // MARK: - Machine Learning
    func trainModel(with transactions: [Transaction]) async throws
    func updateModel(with newTransactions: [Transaction]) async throws
    func getModelAccuracy() async throws -> ModelAccuracy
    func resetModel() async throws
    
    // MARK: - Pattern Analysis
    func analyzeTransactionPatterns(_ transactions: [Transaction]) async throws -> [TransactionPattern]
    func identifyMerchantPatterns() async throws -> [MerchantPattern]
    func detectRecurringTransactions() async throws -> [RecurringTransactionPattern]
    func analyzeCategoryTrends(period: DateInterval) async throws -> [CategoryTrend]
    
    // MARK: - Rules Management
    func createCategorizationRule(_ rule: CategorizationRule) async throws
    func updateCategorizationRule(_ rule: CategorizationRule) async throws
    func deleteCategorizationRule(_ ruleId: UUID) async throws
    func getCategorizationRules() async throws -> [CategorizationRule]
    func applyRules(to transaction: Transaction) async throws -> CategorySuggestion?
    
    // MARK: - Merchant Analysis
    func identifyMerchant(from description: String) async throws -> MerchantInfo?
    func addMerchantMapping(_ mapping: MerchantMapping) async throws
    func getMerchantMappings() async throws -> [MerchantMapping]
    func suggestMerchantCategory(_ merchantName: String) async throws -> Category?
    
    // MARK: - Analytics & Insights
    func generateCategorizationReport(period: DateInterval) async throws -> CategorizationReport
    func getUncategorizedTransactions() async throws -> [Transaction]
    func getCategoryConfidenceScores() async throws -> [UUID: Double]
    func analyzeCategorizationAccuracy() async throws -> CategorizationAccuracy
    
    // MARK: - Initialization
    func initialize() async throws
}

// MARK: - Supporting Data Structures

struct CategorySuggestion {
    let category: Category
    let confidence: Double // 0.0 - 1.0
    let reasoning: String
    let sources: [SuggestionSource]
    let alternatives: [AlternativeSuggestion]
    
    struct AlternativeSuggestion {
        let category: Category
        let confidence: Double
        let reasoning: String
    }
}

enum SuggestionSource {
    case machinelearning(model: String)
    case rule(ruleId: UUID)
    case merchant(merchantId: UUID)
    case pattern(patternType: PatternType)
    case manual(userId: UUID)
    case historicalData
    
    enum PatternType {
        case amount
        case frequency
        case timing
        case description
    }
}

struct TransactionCategorization {
    let transaction: Transaction
    let suggestion: CategorySuggestion
    let isAutomaticallyApplied: Bool
    let needsUserReview: Bool
    let processingTime: TimeInterval
    let confidence: Double
}

struct ModelAccuracy {
    let overallAccuracy: Double // 0.0 - 1.0
    let categoryAccuracies: [UUID: Double]
    let lastTrainingDate: Date
    let trainingDataSize: Int
    let testDataSize: Int
    let confusionMatrix: ConfusionMatrix
    let performanceMetrics: PerformanceMetrics
    
    struct PerformanceMetrics {
        let precision: Double
        let recall: Double
        let f1Score: Double
        let averageConfidence: Double
    }
}

struct ConfusionMatrix {
    let categories: [Category]
    let matrix: [[Int]] // Матрица категорий
    let totalSamples: Int
}

struct TransactionPattern {
    let type: PatternType
    let description: String
    let frequency: Double
    let examples: [Transaction]
    let suggestedCategory: Category
    let confidence: Double
    let applicableRule: CategorizationRule?
    
    enum PatternType {
        case amountRange(min: Decimal, max: Decimal)
        case keywordBased(keywords: [String])
        case merchantBased(merchants: [String])
        case timingBased(timing: TimingPattern)
        case frequencyBased(frequency: FrequencyPattern)
        case combinedPattern(patterns: [PatternType])
    }
    
    struct TimingPattern {
        let dayOfWeek: Int?
        let dayOfMonth: Int?
        let timeOfDay: TimeRange?
        
        struct TimeRange {
            let start: Date
            let end: Date
        }
    }
    
    struct FrequencyPattern {
        let interval: TimeInterval
        let tolerance: TimeInterval
        let occurrences: Int
    }
}

struct MerchantPattern {
    let merchantName: String
    let normalizedName: String
    let category: Category
    let confidence: Double
    let transactionCount: Int
    let averageAmount: Decimal
    let frequency: MerchantFrequency
    let locations: [MerchantLocation]
    let aliases: [String]
    
    enum MerchantFrequency {
        case daily
        case weekly
        case monthly
        case irregular
        case oneTime
    }
    
    struct MerchantLocation {
        let city: String?
        let country: String?
        let coordinates: (latitude: Double, longitude: Double)?
    }
}

struct RecurringTransactionPattern {
    let id: UUID
    let description: String
    let amount: Decimal
    let variance: Decimal // Допустимое отклонение
    let frequency: RecurringFrequency
    let category: Category
    let merchant: String?
    let nextExpectedDate: Date
    let confidence: Double
    let missedOccurrences: Int
    
    enum RecurringFrequency {
        case daily
        case weekly(dayOfWeek: Int)
        case biweekly
        case monthly(dayOfMonth: Int?)
        case quarterly
        case annual
        case custom(interval: TimeInterval)
    }
}

struct CategoryTrend {
    let category: Category
    let period: DateInterval
    let trendDirection: TrendDirection
    let growthRate: Double
    let transactionCount: Int
    let totalAmount: Decimal
    let averageAmount: Decimal
    let volatility: Double
    let predictions: [TrendPrediction]
    
    enum TrendDirection {
        case increasing
        case decreasing
        case stable
        case volatile
    }
    
    struct TrendPrediction {
        let date: Date
        let predictedAmount: Decimal
        let confidence: Double
    }
}

struct CategorizationRule {
    let id: UUID
    let name: String
    let description: String
    let conditions: [RuleCondition]
    let action: RuleAction
    let priority: Int // Приоритет применения правила
    let isActive: Bool
    let createdBy: RuleCreator
    let createdAt: Date
    let lastModified: Date
    let appliedCount: Int
    let successRate: Double
    
    enum RuleCreator {
        case user(UUID)
        case system
        case machinelearning
    }
    
    struct RuleCondition {
        let type: ConditionType
        let operator: ConditionOperator
        let value: String
        let caseSensitive: Bool
        
        enum ConditionType {
            case description
            case amount
            case merchant
            case dayOfWeek
            case timeOfDay
            case account
            case note
            case tag
        }
        
        enum ConditionOperator {
            case contains
            case equals
            case startsWith
            case endsWith
            case greaterThan
            case lessThan
            case between
            case regex
        }
    }
    
    struct RuleAction {
        let type: ActionType
        let categoryId: UUID
        let confidence: Double
        let autoApply: Bool
        
        enum ActionType {
            case assign
            case suggest
            case exclude
        }
    }
}

struct MerchantInfo {
    let id: UUID
    let name: String
    let normalizedName: String
    let aliases: [String]
    let category: Category
    let confidence: Double
    let website: String?
    let phoneNumber: String?
    let address: String?
    let businessType: BusinessType
    let lastUpdated: Date
    
    enum BusinessType {
        case restaurant
        case retail
        case grocery
        case gas
        case pharmacy
        case bank
        case entertainment
        case transport
        case utilities
        case healthcare
        case education
        case other(String)
    }
}

struct MerchantMapping {
    let id: UUID
    let originalName: String
    let merchantInfo: MerchantInfo
    let confidence: Double
    let source: MappingSource
    let isVerified: Bool
    let createdAt: Date
    
    enum MappingSource {
        case user
        case automatic
        case database
        case api
    }
}

struct CategorizationReport {
    let period: DateInterval
    let totalTransactions: Int
    let categorizedTransactions: Int
    let uncategorizedTransactions: Int
    let automaticallyCategorized: Int
    let manuallyCategorized: Int
    let averageConfidence: Double
    let categoryBreakdown: [CategoryBreakdown]
    let modelPerformance: ModelPerformanceReport
    let recommendations: [CategorizationRecommendation]
    
    struct CategoryBreakdown {
        let category: Category
        let transactionCount: Int
        let totalAmount: Decimal
        let averageConfidence: Double
        let accuracyRate: Double
    }
    
    struct ModelPerformanceReport {
        let accuracy: Double
        let precision: Double
        let recall: Double
        let f1Score: Double
        let processingSpeed: Double // транзакций в секунду
        let errorRate: Double
    }
    
    struct CategorizationRecommendation {
        let type: RecommendationType
        let description: String
        let expectedImprovement: String
        let actionItems: [String]
        
        enum RecommendationType {
            case addRule
            case trainModel
            case reviewMerchants
            case updateCategories
            case improvePatterns
        }
    }
}

struct CategorizationAccuracy {
    let overallAccuracy: Double
    let userCorrectionRate: Double // Процент исправлений пользователем
    let categoryAccuracies: [CategoryAccuracyDetail]
    let commonMisclassifications: [Misclassification]
    let improvementSuggestions: [AccuracyImprovement]
    
    struct CategoryAccuracyDetail {
        let category: Category
        let accuracy: Double
        let totalPredictions: Int
        let correctPredictions: Int
        let falsePositives: Int
        let falseNegatives: Int
    }
    
    struct Misclassification {
        let predictedCategory: Category
        let actualCategory: Category
        let frequency: Int
        let examples: [Transaction]
    }
    
    struct AccuracyImprovement {
        let suggestion: String
        let expectedImpact: Double
        let effort: ImprovementEffort
        
        enum ImprovementEffort {
            case low
            case medium
            case high
        }
    }
}

// MARK: - Categorization Service Implementation

final class CategorizationService: CategorizationServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let categoryService: CategoryServiceProtocol
    
    // ML Components
    private let machineLearningEngine: MLCategorizationEngine
    private let naturalLanguageProcessor: NLProcessor
    private let patternRecognitionEngine: PatternRecognitionEngine
    private let merchantIdentifier: MerchantIdentifier
    
    // Data & Cache
    private var categorizationRules: [CategorizationRule] = []
    private var merchantMappings: [MerchantMapping] = []
    private var categoryCache: [String: CategorySuggestion] = [:]
    private var isInitialized = false
    
    // Configuration
    private let confidenceThreshold: Double = 0.7
    private let autoApplyThreshold: Double = 0.9
    private let maxAlternativeSuggestions = 3
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        transactionRepository: TransactionRepositoryProtocol,
        categoryService: CategoryServiceProtocol
    ) {
        self.dataService = dataService
        self.transactionRepository = transactionRepository
        self.categoryService = categoryService
        
        // Инициализируем ML компоненты
        self.machineLearningEngine = MLCategorizationEngine()
        self.naturalLanguageProcessor = NLProcessor()
        self.patternRecognitionEngine = PatternRecognitionEngine()
        self.merchantIdentifier = MerchantIdentifier()
    }
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Инициализируем ML движки
        await machineLearningEngine.initialize()
        await naturalLanguageProcessor.initialize()
        await patternRecognitionEngine.initialize()
        await merchantIdentifier.initialize()
        
        // Загружаем правила и маппинги
        categorizationRules = try await loadCategorizationRules()
        merchantMappings = try await loadMerchantMappings()
        
        // Обучаем модель на существующих данных
        try await trainModelWithExistingData()
        
        isInitialized = true
    }
    
    // MARK: - Core Categorization
    
    func categorizeTransaction(_ transaction: Transaction) async throws -> CategorySuggestion {
        // Проверяем кэш
        let cacheKey = generateCacheKey(for: transaction)
        if let cachedSuggestion = categoryCache[cacheKey] {
            return cachedSuggestion
        }
        
        var suggestions: [CategorySuggestion] = []
        var sources: [SuggestionSource] = []
        
        // 1. Применяем правила пользователя (высший приоритет)
        if let ruleSuggestion = try await applyRules(to: transaction) {
            suggestions.append(ruleSuggestion)
            sources.append(.rule(ruleId: UUID())) // TODO: правильный ID
        }
        
        // 2. Проверяем мерчанта
        if let merchantSuggestion = try await categorizeBerchant(transaction) {
            suggestions.append(merchantSuggestion)
            sources.append(.merchant(merchantId: UUID())) // TODO: правильный ID
        }
        
        // 3. Используем ML модель
        if let mlSuggestion = await machineLearningEngine.categorize(transaction) {
            suggestions.append(mlSuggestion)
            sources.append(.machinelearning(model: "primary"))
        }
        
        // 4. Анализ паттернов
        if let patternSuggestion = try await analyzePatterns(for: transaction) {
            suggestions.append(patternSuggestion)
            sources.append(.pattern(patternType: .description))
        }
        
        // 5. Используем NLP для анализа описания
        if let nlpSuggestion = await naturalLanguageProcessor.categorize(transaction.title) {
            suggestions.append(nlpSuggestion)
            sources.append(.machinelearning(model: "nlp"))
        }
        
        // Выбираем лучшее предложение
        let bestSuggestion = selectBestSuggestion(from: suggestions, sources: sources)
        
        // Кэшируем результат
        categoryCache[cacheKey] = bestSuggestion
        
        return bestSuggestion
    }
    
    func batchCategorizeTransactions(_ transactions: [Transaction]) async throws -> [TransactionCategorization] {
        var results: [TransactionCategorization] = []
        
        // Обрабатываем транзакции пакетами для лучшей производительности
        let batchSize = 50
        let batches = transactions.chunked(into: batchSize)
        
        for batch in batches {
            let batchResults = await withTaskGroup(of: TransactionCategorization?.self) { group in
                var categorizations: [TransactionCategorization] = []
                
                for transaction in batch {
                    group.addTask {
                        let startTime = Date()
                        do {
                            let suggestion = try await self.categorizeTransaction(transaction)
                            let endTime = Date()
                            
                            let shouldAutoApply = suggestion.confidence >= self.autoApplyThreshold
                            let needsReview = suggestion.confidence < self.confidenceThreshold
                            
                            return TransactionCategorization(
                                transaction: transaction,
                                suggestion: suggestion,
                                isAutomaticallyApplied: shouldAutoApply,
                                needsUserReview: needsReview,
                                processingTime: endTime.timeIntervalSince(startTime),
                                confidence: suggestion.confidence
                            )
                        } catch {
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let categorization = result {
                        categorizations.append(categorization)
                    }
                }
                
                return categorizations
            }
            
            results.append(contentsOf: batchResults)
        }
        
        return results
    }
    
    func updateTransactionCategory(_ transaction: Transaction, category: Category) async throws {
        // Обновляем категорию транзакции
        transaction.category = category
        transaction.updateTimestamp()
        transaction.markForSync()
        
        try await dataService.save(transaction)
        
        // Используем это как данные для обучения
        await machineLearningEngine.addTrainingExample(transaction: transaction, category: category)
        
        // Обновляем паттерны
        try await patternRecognitionEngine.updatePatterns(with: transaction)
        
        // Очищаем кэш для связанных транзакций
        clearRelevantCache(for: transaction)
    }
    
    func suggestCategories(for description: String, amount: Decimal?) async throws -> [CategorySuggestion] {
        var suggestions: [CategorySuggestion] = []
        
        // NLP анализ описания
        if let nlpSuggestions = await naturalLanguageProcessor.suggestCategories(for: description) {
            suggestions.append(contentsOf: nlpSuggestions)
        }
        
        // Анализ мерчанта
        if let merchantInfo = try await identifyMerchant(from: description) {
            let merchantSuggestion = CategorySuggestion(
                category: merchantInfo.category,
                confidence: merchantInfo.confidence,
                reasoning: "Определено на основе мерчанта: \(merchantInfo.name)",
                sources: [.merchant(merchantId: merchantInfo.id)],
                alternatives: []
            )
            suggestions.append(merchantSuggestion)
        }
        
        // Анализ суммы (если предоставлена)
        if let amount = amount {
            let amountSuggestions = await analyzeAmountPatterns(amount)
            suggestions.append(contentsOf: amountSuggestions)
        }
        
        // Сортируем по уверенности
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Machine Learning
    
    func trainModel(with transactions: [Transaction]) async throws {
        // Фильтруем транзакции с категориями
        let categorizedTransactions = transactions.filter { $0.category != nil }
        
        guard categorizedTransactions.count >= 50 else {
            throw CategorizationError.insufficientTrainingData
        }
        
        // Подготавливаем данные для обучения
        let trainingData = prepareTrainingData(from: categorizedTransactions)
        
        // Обучаем ML модель
        await machineLearningEngine.train(with: trainingData)
        
        // Обновляем паттерны
        try await patternRecognitionEngine.updatePatterns(with: categorizedTransactions)
        
        // Очищаем кэш
        categoryCache.removeAll()
    }
    
    func updateModel(with newTransactions: [Transaction]) async throws {
        let categorizedTransactions = newTransactions.filter { $0.category != nil }
        
        guard !categorizedTransactions.isEmpty else { return }
        
        // Инкрементальное обучение
        await machineLearningEngine.incrementalTrain(with: categorizedTransactions)
        
        // Обновляем паттерны
        for transaction in categorizedTransactions {
            try await patternRecognitionEngine.updatePatterns(with: transaction)
        }
        
        // Частично очищаем кэш
        categoryCache.removeAll()
    }
    
    func getModelAccuracy() async throws -> ModelAccuracy {
        return await machineLearningEngine.getAccuracy()
    }
    
    func resetModel() async throws {
        await machineLearningEngine.reset()
        await patternRecognitionEngine.reset()
        categoryCache.removeAll()
        
        // Переобучаем на существующих данных
        try await trainModelWithExistingData()
    }
    
    // MARK: - Pattern Analysis
    
    func analyzeTransactionPatterns(_ transactions: [Transaction]) async throws -> [TransactionPattern] {
        return await patternRecognitionEngine.analyzePatterns(in: transactions)
    }
    
    func identifyMerchantPatterns() async throws -> [MerchantPattern] {
        let transactions = try await transactionRepository.fetchTransactions()
        return await merchantIdentifier.identifyPatterns(from: transactions)
    }
    
    func detectRecurringTransactions() async throws -> [RecurringTransactionPattern] {
        let transactions = try await transactionRepository.fetchTransactions()
        return await patternRecognitionEngine.detectRecurring(in: transactions)
    }
    
    func analyzeCategoryTrends(period: DateInterval) async throws -> [CategoryTrend] {
        let transactions = try await transactionRepository.fetchTransactions(
            from: period.start,
            to: period.end
        )
        
        return await patternRecognitionEngine.analyzeCategoryTrends(in: transactions, period: period)
    }
    
    // MARK: - Rules Management
    
    func createCategorizationRule(_ rule: CategorizationRule) async throws {
        // Валидация правила
        try validateRule(rule)
        
        // Сохраняем правило
        categorizationRules.append(rule)
        try await saveCategorizationRules()
        
        // Применяем правило к существующим транзакциям
        try await applyNewRule(rule)
    }
    
    func updateCategorizationRule(_ rule: CategorizationRule) async throws {
        guard let index = categorizationRules.firstIndex(where: { $0.id == rule.id }) else {
            throw CategorizationError.ruleNotFound
        }
        
        try validateRule(rule)
        categorizationRules[index] = rule
        try await saveCategorizationRules()
        
        // Очищаем кэш
        categoryCache.removeAll()
    }
    
    func deleteCategorizationRule(_ ruleId: UUID) async throws {
        categorizationRules.removeAll { $0.id == ruleId }
        try await saveCategorizationRules()
        categoryCache.removeAll()
    }
    
    func getCategorizationRules() async throws -> [CategorizationRule] {
        return categorizationRules
    }
    
    func applyRules(to transaction: Transaction) async throws -> CategorySuggestion? {
        // Сортируем правила по приоритету
        let sortedRules = categorizationRules
            .filter { $0.isActive }
            .sorted { $0.priority > $1.priority }
        
        for rule in sortedRules {
            if await evaluateRule(rule, for: transaction) {
                guard let category = try await categoryService.getCategory(id: rule.action.categoryId) else {
                    continue
                }
                
                return CategorySuggestion(
                    category: category,
                    confidence: rule.action.confidence,
                    reasoning: "Применено правило: \(rule.name)",
                    sources: [.rule(ruleId: rule.id)],
                    alternatives: []
                )
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Classes

class MLCategorizationEngine {
    private var model: MLCategorizationModel?
    private var trainingHistory: [TrainingSession] = []
    
    func initialize() async {
        // Инициализация ML модели
        model = MLCategorizationModel()
    }
    
    func categorize(_ transaction: Transaction) async -> CategorySuggestion? {
        guard let model = model else { return nil }
        
        let features = extractFeatures(from: transaction)
        let prediction = await model.predict(features: features)
        
        return CategorySuggestion(
            category: prediction.category,
            confidence: prediction.confidence,
            reasoning: "ML предсказание на основе \(features.count) признаков",
            sources: [.machinelearning(model: "primary")],
            alternatives: prediction.alternatives.map { alt in
                CategorySuggestion.AlternativeSuggestion(
                    category: alt.category,
                    confidence: alt.confidence,
                    reasoning: alt.reasoning
                )
            }
        )
    }
    
    func train(with data: [TrainingExample]) async {
        guard let model = model else { return }
        
        let session = TrainingSession(
            id: UUID(),
            startDate: Date(),
            trainingSize: data.count,
            accuracy: 0.0
        )
        
        await model.train(with: data)
        
        // Записываем сессию обучения
        trainingHistory.append(session)
    }
    
    func incrementalTrain(with transactions: [Transaction]) async {
        guard let model = model else { return }
        
        let trainingData = transactions.compactMap { transaction in
            guard let category = transaction.category else { return nil }
            return TrainingExample(
                transaction: transaction,
                category: category,
                features: extractFeatures(from: transaction)
            )
        }
        
        await model.incrementalTrain(with: trainingData)
    }
    
    func getAccuracy() async -> ModelAccuracy {
        guard let model = model else {
            return ModelAccuracy(
                overallAccuracy: 0.0,
                categoryAccuracies: [:],
                lastTrainingDate: Date(),
                trainingDataSize: 0,
                testDataSize: 0,
                confusionMatrix: ConfusionMatrix(categories: [], matrix: [], totalSamples: 0),
                performanceMetrics: ModelAccuracy.PerformanceMetrics(
                    precision: 0.0,
                    recall: 0.0,
                    f1Score: 0.0,
                    averageConfidence: 0.0
                )
            )
        }
        
        return await model.evaluateAccuracy()
    }
    
    func addTrainingExample(transaction: Transaction, category: Category) async {
        let features = extractFeatures(from: transaction)
        let example = TrainingExample(
            transaction: transaction,
            category: category,
            features: features
        )
        
        await model?.addTrainingExample(example)
    }
    
    func reset() async {
        model = MLCategorizationModel()
        trainingHistory.removeAll()
    }
    
    private func extractFeatures(from transaction: Transaction) -> [String: Any] {
        var features: [String: Any] = [:]
        
        // Текстовые признаки
        features["description"] = transaction.title.lowercased()
        features["description_length"] = transaction.title.count
        features["description_words"] = transaction.title.components(separatedBy: .whitespaces).count
        
        // Числовые признаки
        features["amount"] = Double(transaction.amount as NSDecimalNumber)
        features["amount_log"] = log(max(1.0, Double(transaction.amount as NSDecimalNumber)))
        
        // Временные признаки
        let calendar = Calendar.current
        features["day_of_week"] = calendar.component(.weekday, from: transaction.date)
        features["day_of_month"] = calendar.component(.day, from: transaction.date)
        features["month"] = calendar.component(.month, from: transaction.date)
        features["hour"] = calendar.component(.hour, from: transaction.date)
        
        // Тип транзакции
        features["transaction_type"] = transaction.type.rawValue
        
        // Аккаунт
        features["account"] = transaction.account ?? "unknown"
        
        // Теги
        features["tags"] = transaction.tags.joined(separator: " ")
        
        return features
    }
    
    struct TrainingExample {
        let transaction: Transaction
        let category: Category
        let features: [String: Any]
    }
    
    struct TrainingSession {
        let id: UUID
        let startDate: Date
        let trainingSize: Int
        let accuracy: Double
    }
}

class MLCategorizationModel {
    private var isTraining = false
    
    func predict(features: [String: Any]) async -> CategoryPrediction {
        // Заглушка для ML предсказания
        // В реальности здесь будет вызов Core ML модели
        return CategoryPrediction(
            category: Category(), // TODO: реальная категория
            confidence: 0.85,
            alternatives: []
        )
    }
    
    func train(with data: [MLCategorizationEngine.TrainingExample]) async {
        isTraining = true
        // Заглушка для обучения модели
        isTraining = false
    }
    
    func incrementalTrain(with data: [MLCategorizationEngine.TrainingExample]) async {
        // Заглушка для инкрементального обучения
    }
    
    func evaluateAccuracy() async -> ModelAccuracy {
        // Заглушка для оценки точности
        return ModelAccuracy(
            overallAccuracy: 0.87,
            categoryAccuracies: [:],
            lastTrainingDate: Date(),
            trainingDataSize: 1000,
            testDataSize: 200,
            confusionMatrix: ConfusionMatrix(categories: [], matrix: [], totalSamples: 200),
            performanceMetrics: ModelAccuracy.PerformanceMetrics(
                precision: 0.85,
                recall: 0.82,
                f1Score: 0.83,
                averageConfidence: 0.78
            )
        )
    }
    
    func addTrainingExample(_ example: MLCategorizationEngine.TrainingExample) async {
        // Добавление примера для онлайн обучения
    }
    
    struct CategoryPrediction {
        let category: Category
        let confidence: Double
        let alternatives: [AlternativePrediction]
        
        struct AlternativePrediction {
            let category: Category
            let confidence: Double
            let reasoning: String
        }
    }
}

class NLProcessor {
    private let tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass, .nameType])
    private var keywordMappings: [String: Category] = [:]
    
    func initialize() async {
        // Загружаем ключевые слова для категорий
        await loadKeywordMappings()
    }
    
    func categorize(_ text: String) async -> CategorySuggestion? {
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Анализ ключевых слов
        if let keywordMatch = findKeywordMatch(in: normalizedText) {
            return CategorySuggestion(
                category: keywordMatch.category,
                confidence: keywordMatch.confidence,
                reasoning: "Найдено ключевое слово: \(keywordMatch.keyword)",
                sources: [.machinelearning(model: "nlp")],
                alternatives: []
            )
        }
        
        // Семантический анализ
        if let semanticMatch = await performSemanticAnalysis(normalizedText) {
            return semanticMatch
        }
        
        return nil
    }
    
    func suggestCategories(for text: String) async -> [CategorySuggestion]? {
        var suggestions: [CategorySuggestion] = []
        
        let normalizedText = text.lowercased()
        
        // Поиск всех потенциальных совпадений
        for (keyword, category) in keywordMappings {
            if normalizedText.contains(keyword) {
                let confidence = calculateConfidence(for: keyword, in: normalizedText)
                let suggestion = CategorySuggestion(
                    category: category,
                    confidence: confidence,
                    reasoning: "Содержит ключевое слово: \(keyword)",
                    sources: [.machinelearning(model: "nlp")],
                    alternatives: []
                )
                suggestions.append(suggestion)
            }
        }
        
        return suggestions.isEmpty ? nil : suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    private func findKeywordMatch(in text: String) -> (keyword: String, category: Category, confidence: Double)? {
        for (keyword, category) in keywordMappings {
            if text.contains(keyword) {
                let confidence = calculateConfidence(for: keyword, in: text)
                return (keyword, category, confidence)
            }
        }
        return nil
    }
    
    private func calculateConfidence(for keyword: String, in text: String) -> Double {
        let keywordLength = Double(keyword.count)
        let textLength = Double(text.count)
        let baseConfidence = min(1.0, keywordLength / textLength * 5.0)
        
        // Бонус за точное совпадение
        if text == keyword {
            return min(1.0, baseConfidence * 1.5)
        }
        
        return baseConfidence
    }
    
    private func performSemanticAnalysis(_ text: String) async -> CategorySuggestion? {
        // Заглушка для семантического анализа
        // В реальности здесь будет анализ с помощью NLP модели
        return nil
    }
    
    private func loadKeywordMappings() async {
        // Заглушка для загрузки маппингов ключевых слов
        // В реальности здесь будет загрузка из базы данных или конфигурации
    }
}

class PatternRecognitionEngine {
    private var patterns: [TransactionPattern] = []
    private var recurringPatterns: [RecurringTransactionPattern] = []
    
    func initialize() async {
        // Инициализация движка распознавания паттернов
    }
    
    func analyzePatterns(in transactions: [Transaction]) async -> [TransactionPattern] {
        var discoveredPatterns: [TransactionPattern] = []
        
        // Анализ паттернов по суммам
        let amountPatterns = analyzeAmountPatterns(transactions)
        discoveredPatterns.append(contentsOf: amountPatterns)
        
        // Анализ паттернов по ключевым словам
        let keywordPatterns = analyzeKeywordPatterns(transactions)
        discoveredPatterns.append(contentsOf: keywordPatterns)
        
        // Анализ паттернов по мерчантам
        let merchantPatterns = analyzeMerchantPatterns(transactions)
        discoveredPatterns.append(contentsOf: merchantPatterns)
        
        // Анализ временных паттернов
        let timingPatterns = analyzeTimingPatterns(transactions)
        discoveredPatterns.append(contentsOf: timingPatterns)
        
        return discoveredPatterns
    }
    
    func detectRecurring(in transactions: [Transaction]) async -> [RecurringTransactionPattern] {
        // Группируем транзакции по схожести
        let groups = groupSimilarTransactions(transactions)
        var patterns: [RecurringTransactionPattern] = []
        
        for group in groups {
            if let pattern = analyzeRecurringPattern(in: group) {
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
    
    func updatePatterns(with transaction: Transaction) async throws {
        // Обновляем существующие паттерны с новой транзакцией
        await updateExistingPatterns(with: transaction)
        
        // Ищем новые паттерны
        await discoverNewPatterns(including: transaction)
    }
    
    func analyzeCategoryTrends(in transactions: [Transaction], period: DateInterval) async -> [CategoryTrend] {
        // Группируем транзакции по категориям
        let categoryGroups = Dictionary(grouping: transactions) { $0.category?.id ?? UUID() }
        var trends: [CategoryTrend] = []
        
        for (_, categoryTransactions) in categoryGroups {
            guard let category = categoryTransactions.first?.category else { continue }
            
            let trend = analyzeCategoryTrend(category: category, transactions: categoryTransactions, period: period)
            trends.append(trend)
        }
        
        return trends
    }
    
    func reset() async {
        patterns.removeAll()
        recurringPatterns.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func analyzeAmountPatterns(_ transactions: [Transaction]) -> [TransactionPattern] {
        // Анализ паттернов по суммам
        return []
    }
    
    private func analyzeKeywordPatterns(_ transactions: [Transaction]) -> [TransactionPattern] {
        // Анализ паттернов по ключевым словам
        return []
    }
    
    private func analyzeMerchantPatterns(_ transactions: [Transaction]) -> [TransactionPattern] {
        // Анализ паттернов по мерчантам
        return []
    }
    
    private func analyzeTimingPatterns(_ transactions: [Transaction]) -> [TransactionPattern] {
        // Анализ временных паттернов
        return []
    }
    
    private func groupSimilarTransactions(_ transactions: [Transaction]) -> [[Transaction]] {
        // Группировка похожих транзакций
        return []
    }
    
    private func analyzeRecurringPattern(in transactions: [Transaction]) -> RecurringTransactionPattern? {
        // Анализ повторяющихся паттернов
        return nil
    }
    
    private func updateExistingPatterns(with transaction: Transaction) async {
        // Обновление существующих паттернов
    }
    
    private func discoverNewPatterns(including transaction: Transaction) async {
        // Поиск новых паттернов
    }
    
    private func analyzeCategoryTrend(category: Category, transactions: [Transaction], period: DateInterval) -> CategoryTrend {
        // Анализ тренда категории
        return CategoryTrend(
            category: category,
            period: period,
            trendDirection: .stable,
            growthRate: 0.0,
            transactionCount: transactions.count,
            totalAmount: transactions.reduce(0) { $0 + $1.amount },
            averageAmount: 0,
            volatility: 0.0,
            predictions: []
        )
    }
}

class MerchantIdentifier {
    private var merchantDatabase: [String: MerchantInfo] = [:]
    private var merchantAliases: [String: String] = [:]
    
    func initialize() async {
        await loadMerchantDatabase()
        await buildAliasIndex()
    }
    
    func identifyMerchant(from description: String) async -> MerchantInfo? {
        let normalizedDescription = normalizeDescription(description)
        
        // Прямое совпадение
        if let merchant = merchantDatabase[normalizedDescription] {
            return merchant
        }
        
        // Поиск по алиасам
        if let canonicalName = merchantAliases[normalizedDescription],
           let merchant = merchantDatabase[canonicalName] {
            return merchant
        }
        
        // Поиск по частичному совпадению
        return findPartialMatch(for: normalizedDescription)
    }
    
    func identifyPatterns(from transactions: [Transaction]) async -> [MerchantPattern] {
        var patterns: [MerchantPattern] = []
        
        // Группируем транзакции по мерчантам
        let merchantGroups = Dictionary(grouping: transactions) { transaction in
            return extractMerchantName(from: transaction.title)
        }
        
        for (merchantName, merchantTransactions) in merchantGroups {
            let pattern = analyzeMerchantPattern(name: merchantName, transactions: merchantTransactions)
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    private func loadMerchantDatabase() async {
        // Загрузка базы данных мерчантов
    }
    
    private func buildAliasIndex() async {
        // Построение индекса алиасов
    }
    
    private func normalizeDescription(_ description: String) -> String {
        return description.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\d+"#, with: "", options: .regularExpression)
    }
    
    private func findPartialMatch(for description: String) -> MerchantInfo? {
        // Поиск частичного совпадения
        return nil
    }
    
    private func extractMerchantName(from description: String) -> String {
        // Извлечение имени мерчанта из описания
        return description
    }
    
    private func analyzeMerchantPattern(name: String, transactions: [Transaction]) -> MerchantPattern {
        // Анализ паттерна мерчанта
        return MerchantPattern(
            merchantName: name,
            normalizedName: normalizeDescription(name),
            category: Category(), // TODO: определить категорию
            confidence: 0.8,
            transactionCount: transactions.count,
            averageAmount: transactions.reduce(0) { $0 + $1.amount } / Decimal(transactions.count),
            frequency: .irregular,
            locations: [],
            aliases: []
        )
    }
}

// MARK: - Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Error Types

enum CategorizationError: Error {
    case insufficientTrainingData
    case modelNotInitialized
    case ruleNotFound
    case invalidRule
    case processingError
}

// MARK: - Private Extensions

private extension CategorizationService {
    
    func generateCacheKey(for transaction: Transaction) -> String {
        return "\(transaction.title.lowercased())_\(transaction.amount)_\(transaction.type.rawValue)"
    }
    
    func categorizeBerchant(_ transaction: Transaction) async throws -> CategorySuggestion? {
        guard let merchantInfo = try await identifyMerchant(from: transaction.title) else {
            return nil
        }
        
        return CategorySuggestion(
            category: merchantInfo.category,
            confidence: merchantInfo.confidence,
            reasoning: "Определено по мерчанту: \(merchantInfo.name)",
            sources: [.merchant(merchantId: merchantInfo.id)],
            alternatives: []
        )
    }
    
    func analyzePatterns(for transaction: Transaction) async throws -> CategorySuggestion? {
        let patterns = await patternRecognitionEngine.analyzePatterns(in: [transaction])
        
        guard let bestPattern = patterns.first else { return nil }
        
        return CategorySuggestion(
            category: bestPattern.suggestedCategory,
            confidence: bestPattern.confidence,
            reasoning: "Найден паттерн: \(bestPattern.description)",
            sources: [.pattern(patternType: .description)],
            alternatives: []
        )
    }
    
    func selectBestSuggestion(from suggestions: [CategorySuggestion], sources: [SuggestionSource]) -> CategorySuggestion {
        // Взвешиваем предложения по источникам
        var weightedSuggestions: [(suggestion: CategorySuggestion, weight: Double)] = []
        
        for (index, suggestion) in suggestions.enumerated() {
            let source = sources[safe: index]
            let weight = calculateSourceWeight(source)
            let finalConfidence = suggestion.confidence * weight
            
            var weightedSuggestion = suggestion
            weightedSuggestion = CategorySuggestion(
                category: suggestion.category,
                confidence: finalConfidence,
                reasoning: suggestion.reasoning,
                sources: suggestion.sources,
                alternatives: suggestion.alternatives
            )
            
            weightedSuggestions.append((weightedSuggestion, weight))
        }
        
        // Выбираем лучшее предложение
        let bestSuggestion = weightedSuggestions.max { $0.suggestion.confidence < $1.suggestion.confidence }?.suggestion
        
        return bestSuggestion ?? CategorySuggestion(
            category: Category(), // TODO: категория по умолчанию
            confidence: 0.1,
            reasoning: "Категория по умолчанию",
            sources: [],
            alternatives: []
        )
    }
    
    func calculateSourceWeight(_ source: SuggestionSource?) -> Double {
        guard let source = source else { return 0.5 }
        
        switch source {
        case .rule:
            return 1.0 // Правила пользователя имеют наивысший приоритет
        case .merchant:
            return 0.9 // Мерчанты очень надежны
        case .manual:
            return 0.95 // Ручная категоризация пользователя
        case .machinelearning(let model):
            return model == "primary" ? 0.8 : 0.7
        case .pattern:
            return 0.6
        case .historicalData:
            return 0.5
        }
    }
    
    func analyzeAmountPatterns(_ amount: Decimal) async -> [CategorySuggestion] {
        // Анализ паттернов по сумме
        return []
    }
    
    func clearRelevantCache(for transaction: Transaction) {
        let cacheKey = generateCacheKey(for: transaction)
        categoryCache.removeValue(forKey: cacheKey)
        
        // Очищаем кэш для схожих транзакций
        let relatedKeys = categoryCache.keys.filter { key in
            key.contains(transaction.title.lowercased().prefix(10))
        }
        
        for key in relatedKeys {
            categoryCache.removeValue(forKey: key)
        }
    }
    
    func trainModelWithExistingData() async throws {
        let existingTransactions = try await transactionRepository.fetchTransactions()
        let categorizedTransactions = existingTransactions.filter { $0.category != nil }
        
        if !categorizedTransactions.isEmpty {
            try await trainModel(with: categorizedTransactions)
        }
    }
    
    func prepareTrainingData(from transactions: [Transaction]) -> [MLCategorizationEngine.TrainingExample] {
        return transactions.compactMap { transaction in
            guard let category = transaction.category else { return nil }
            
            let features = extractFeaturesForTraining(from: transaction)
            return MLCategorizationEngine.TrainingExample(
                transaction: transaction,
                category: category,
                features: features
            )
        }
    }
    
    func extractFeaturesForTraining(from transaction: Transaction) -> [String: Any] {
        var features: [String: Any] = [:]
        
        // Базовые признаки
        features["description"] = transaction.title.lowercased()
        features["amount"] = Double(transaction.amount as NSDecimalNumber)
        features["type"] = transaction.type.rawValue
        
        // Временные признаки
        let calendar = Calendar.current
        features["day_of_week"] = calendar.component(.weekday, from: transaction.date)
        features["hour"] = calendar.component(.hour, from: transaction.date)
        
        return features
    }
    
    func loadCategorizationRules() async throws -> [CategorizationRule] {
        // Загрузка правил из базы данных
        return []
    }
    
    func loadMerchantMappings() async throws -> [MerchantMapping] {
        // Загрузка маппингов мерчантов
        return []
    }
    
    func validateRule(_ rule: CategorizationRule) throws {
        // Валидация правила категоризации
        if rule.name.isEmpty {
            throw CategorizationError.invalidRule
        }
        
        if rule.conditions.isEmpty {
            throw CategorizationError.invalidRule
        }
    }
    
    func saveCategorizationRules() async throws {
        // Сохранение правил в базу данных
    }
    
    func applyNewRule(_ rule: CategorizationRule) async throws {
        // Применение нового правила к существующим транзакциям
        let transactions = try await transactionRepository.fetchTransactions()
        
        for transaction in transactions {
            if await evaluateRule(rule, for: transaction) {
                if rule.action.autoApply {
                    // Автоматически применяем категорию
                    if let category = try await categoryService.getCategory(id: rule.action.categoryId) {
                        try await updateTransactionCategory(transaction, category: category)
                    }
                }
            }
        }
    }
    
    func evaluateRule(_ rule: CategorizationRule, for transaction: Transaction) async -> Bool {
        // Оценка применимости правила к транзакции
        for condition in rule.conditions {
            if !await evaluateCondition(condition, for: transaction) {
                return false // Все условия должны выполняться
            }
        }
        return true
    }
    
    func evaluateCondition(_ condition: CategorizationRule.RuleCondition, for transaction: Transaction) async -> Bool {
        let value = extractValueForCondition(condition.type, from: transaction)
        return evaluateConditionOperator(condition.operator, value: value, target: condition.value)
    }
    
    func extractValueForCondition(_ type: CategorizationRule.RuleCondition.ConditionType, from transaction: Transaction) -> String {
        switch type {
        case .description:
            return transaction.title
        case .amount:
            return String(describing: transaction.amount)
        case .merchant:
            return transaction.title // TODO: извлечь имя мерчанта
        case .account:
            return transaction.account ?? ""
        case .note:
            return transaction.notes ?? ""
        case .tag:
            return transaction.tags.joined(separator: " ")
        default:
            return ""
        }
    }
    
    func evaluateConditionOperator(_ operator: CategorizationRule.RuleCondition.ConditionOperator, value: String, target: String) -> Bool {
        switch `operator` {
        case .contains:
            return value.lowercased().contains(target.lowercased())
        case .equals:
            return value.lowercased() == target.lowercased()
        case .startsWith:
            return value.lowercased().hasPrefix(target.lowercased())
        case .endsWith:
            return value.lowercased().hasSuffix(target.lowercased())
        case .regex:
            do {
                let regex = try NSRegularExpression(pattern: target)
                let range = NSRange(location: 0, length: value.utf16.count)
                return regex.firstMatch(in: value, options: [], range: range) != nil
            } catch {
                return false
            }
        default:
            return false
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 