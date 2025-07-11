import Foundation
import SwiftUI
import Combine

@Observable
final class SpendingAnalyticsViewModel {
    
    // MARK: - Services
    private let transactionRepository: TransactionRepositoryProtocol
    private let insightsGenerationService: InsightsGenerationServiceProtocol
    private let forecastingService: ForecastingServiceProtocol
    private let categorizationService: CategorizationServiceProtocol
    
    // MARK: - Published Properties
    var transactions: [Transaction] = []
    var spendingAnalysis: SpendingAnalysisData?
    var chartData: SpendingChartData = SpendingChartData()
    var insights: [SpendingInsight] = []
    var patterns: [SpendingPattern] = []
    var anomalies: [SpendingAnomaly] = []
    var predictions: [SpendingPrediction] = []
    var categoryAnalysis: [CategoryAnalysis] = []
    var periodicComparison: PeriodicComparison?
    
    // MARK: - UI State
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?
    var showError = false
    var selectedTimeframe: SpendingTimeframe = .month
    var selectedChart: ChartType = .timeline
    var selectedCategory: Category?
    var showCategoryFilter = false
    var showSettings = false
    var showInsightDetail: SpendingInsight?
    
    // MARK: - Filter State
    var activeFilters: SpendingFilters = SpendingFilters()
    var availableCategories: [Category] = []
    var dateRange: DateInterval?
    var amountRange: (min: Decimal, max: Decimal)?
    
    // MARK: - Chart Configuration
    var chartConfiguration: ChartConfiguration = ChartConfiguration()
    
    // MARK: - Configuration
    private let refreshInterval: TimeInterval = 180 // 3 minutes
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        transactionRepository: TransactionRepositoryProtocol,
        insightsGenerationService: InsightsGenerationServiceProtocol,
        forecastingService: ForecastingServiceProtocol,
        categorizationService: CategorizationServiceProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.insightsGenerationService = insightsGenerationService
        self.forecastingService = forecastingService
        self.categorizationService = categorizationService
        
        setupAutoRefresh()
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.loadTransactions() }
                group.addTask { await self.loadAvailableCategories() }
                group.addTask { await self.loadSpendingInsights() }
            }
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.analyzeSpendingData() }
                group.addTask { await self.detectPatterns() }
                group.addTask { await self.identifyAnomalies() }
                group.addTask { await self.generatePredictions() }
                group.addTask { await self.analyzeCategorySpending() }
                group.addTask { await self.generatePeriodicComparison() }
            }
            
            await generateChartData()
            
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
    func changeTimeframe(_ timeframe: SpendingTimeframe) async {
        selectedTimeframe = timeframe
        await loadData()
    }
    
    @MainActor
    func changeChartType(_ chartType: ChartType) async {
        selectedChart = chartType
        await generateChartData()
    }
    
    @MainActor
    func selectCategory(_ category: Category?) async {
        selectedCategory = category
        await loadData()
    }
    
    @MainActor
    func applyFilters(_ filters: SpendingFilters) async {
        activeFilters = filters
        await loadData()
    }
    
    @MainActor
    func resetFilters() async {
        activeFilters = SpendingFilters()
        selectedCategory = nil
        await loadData()
    }
    
    @MainActor
    func exportData(format: ExportFormat) async -> URL? {
        do {
            return try await generateExport(format: format)
        } catch {
            await handleError(error)
            return nil
        }
    }
    
    @MainActor
    func shareInsight(_ insight: SpendingInsight) async -> String {
        return generateInsightSummary(insight)
    }
    
    // MARK: - Computed Properties
    
    var totalSpending: Decimal {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var averageDailySpending: Decimal {
        guard !transactions.isEmpty else { return 0 }
        let days = selectedTimeframe.durationInDays
        return totalSpending / Decimal(days)
    }
    
    var averageTransactionAmount: Decimal {
        guard !transactions.isEmpty else { return 0 }
        return totalSpending / Decimal(transactions.count)
    }
    
    var transactionCount: Int {
        transactions.count
    }
    
    var topCategory: Category? {
        categoryAnalysis.max { $0.amount < $1.amount }?.category
    }
    
    var spendingTrend: TrendDirection {
        spendingAnalysis?.trend ?? .stable
    }
    
    var hasData: Bool {
        !transactions.isEmpty
    }
    
    var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            activeFilters.matches(transaction: transaction)
        }
    }
    
    var currentPeriodTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        
        switch selectedTimeframe {
        case .week:
            formatter.dateFormat = "'Неделя' w yyyy"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
        case .quarter:
            formatter.dateFormat = "'Q'q yyyy"
        case .year:
            formatter.dateFormat = "yyyy 'год'"
        case .custom:
            return "Произвольный период"
        }
        
        return formatter.string(from: Date()).capitalized
    }
    
    // MARK: - Private Methods
    
    private func loadTransactions() async {
        do {
            let dateInterval = selectedTimeframe.dateInterval ?? defaultDateInterval()
            let fetchedTransactions = try await transactionRepository.fetchTransactions(
                from: dateInterval.start,
                to: dateInterval.end
            )
            
            await MainActor.run {
                self.transactions = fetchedTransactions.filter { $0.type == .expense }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadAvailableCategories() async {
        do {
            // Получаем уникальные категории из транзакций
            let uniqueCategories = Set(transactions.compactMap { $0.category })
            
            await MainActor.run {
                self.availableCategories = Array(uniqueCategories).sorted { $0.name < $1.name }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadSpendingInsights() async {
        do {
            // Получаем инсайты от сервиса
            let generatedInsights = try await insightsGenerationService.generatePersonalizedInsights(for: User())
            
            // Фильтруем только связанные с тратами
            let spendingInsights = generatedInsights.compactMap { insight -> SpendingInsight? in
                switch insight.type {
                case .spendingOptimization, .behaviorPattern, .categoryInsight:
                    return SpendingInsight(
                        id: insight.id,
                        type: mapInsightType(insight.type),
                        title: insight.title,
                        description: insight.description,
                        impact: insight.impact,
                        confidence: insight.confidence,
                        actionableSteps: insight.actionableSteps.map { $0.step },
                        supportingData: insight.supportingData
                    )
                default:
                    return nil
                }
            }
            
            await MainActor.run {
                self.insights = spendingInsights
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func analyzeSpendingData() async {
        do {
            let analysis = await performSpendingAnalysis()
            
            await MainActor.run {
                self.spendingAnalysis = analysis
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func detectPatterns() async {
        do {
            let detectedPatterns = try await insightsGenerationService.analyzeSpendingPatterns(for: User())
            
            let spendingPatterns = detectedPatterns.patterns.map { pattern in
                SpendingPattern(
                    id: UUID(),
                    type: mapPatternType(pattern.type),
                    description: pattern.description,
                    frequency: pattern.frequency.displayName,
                    strength: pattern.strength,
                    examples: pattern.examples,
                    insight: generatePatternInsight(pattern)
                )
            }
            
            await MainActor.run {
                self.patterns = spendingPatterns
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func identifyAnomalies() async {
        do {
            let detectedAnomalies = try await insightsGenerationService.detectAnomalies(
                for: User(),
                period: selectedTimeframe.dateInterval
            )
            
            await MainActor.run {
                self.anomalies = detectedAnomalies
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func generatePredictions() async {
        do {
            let spendingForecast = try await forecastingService.forecastExpenses(
                for: User(),
                horizon: .month
            )
            
            let predictions = spendingForecast.categoryForecasts.map { forecast in
                SpendingPrediction(
                    category: forecast.category,
                    predictedAmount: forecast.predictedAmount,
                    confidence: forecast.confidence,
                    trend: forecast.trend.displayName,
                    period: "Следующий месяц",
                    factors: forecast.driverFactors.map { $0.factor }
                )
            }
            
            await MainActor.run {
                self.predictions = predictions
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func analyzeCategorySpending() async {
        do {
            // Группируем транзакции по категориям
            let categoryGroups = Dictionary(grouping: filteredTransactions) { $0.category?.id ?? UUID() }
            
            var analyses: [CategoryAnalysis] = []
            
            for (categoryId, categoryTransactions) in categoryGroups {
                guard let category = categoryTransactions.first?.category else { continue }
                
                let totalAmount = categoryTransactions.reduce(0) { $0 + $1.amount }
                let averageAmount = totalAmount / Decimal(categoryTransactions.count)
                let percentage = totalSpending > 0 ? Double(totalAmount / totalSpending) * 100 : 0
                
                let previousPeriodAmount = await calculatePreviousPeriodAmount(for: category)
                let change = previousPeriodAmount > 0 ? Double((totalAmount - previousPeriodAmount) / previousPeriodAmount) * 100 : 0
                
                let analysis = CategoryAnalysis(
                    category: category,
                    amount: totalAmount,
                    percentage: percentage,
                    transactionCount: categoryTransactions.count,
                    averageAmount: averageAmount,
                    changeFromPrevious: change,
                    trend: determineTrend(change),
                    topTransactions: Array(categoryTransactions.sorted { $0.amount > $1.amount }.prefix(3))
                )
                
                analyses.append(analysis)
            }
            
            await MainActor.run {
                self.categoryAnalysis = analyses.sorted { $0.amount > $1.amount }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func generatePeriodicComparison() async {
        do {
            let comparison = await createPeriodicComparison()
            
            await MainActor.run {
                self.periodicComparison = comparison
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func generateChartData() async {
        do {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.generateTimelineChartData() }
                group.addTask { await self.generateCategoryChartData() }
                group.addTask { await self.generateComparisonChartData() }
                group.addTask { await self.generateHeatmapChartData() }
                group.addTask { await self.generateTrendChartData() }
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    private func generateTimelineChartData() async {
        let calendar = Calendar.current
        let groupedData: [Date: Decimal]
        
        switch selectedTimeframe {
        case .week:
            groupedData = Dictionary(grouping: filteredTransactions) {
                calendar.startOfDay(for: $0.date)
            }.mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        case .month:
            groupedData = Dictionary(grouping: filteredTransactions) {
                calendar.startOfDay(for: $0.date)
            }.mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        case .quarter, .year:
            groupedData = Dictionary(grouping: filteredTransactions) {
                calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date
            }.mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        case .custom:
            groupedData = Dictionary(grouping: filteredTransactions) {
                calendar.startOfDay(for: $0.date)
            }.mapValues { transactions in
                transactions.reduce(0) { $0 + $1.amount }
            }
        }
        
        let timelineData = groupedData.map { date, amount in
            TimelineDataPoint(date: date, amount: amount)
        }.sorted { $0.date < $1.date }
        
        await MainActor.run {
            self.chartData.timelineData = timelineData
        }
    }
    
    private func generateCategoryChartData() async {
        let categoryData = categoryAnalysis.map { analysis in
            CategoryChartDataPoint(
                category: analysis.category,
                amount: analysis.amount,
                percentage: analysis.percentage,
                color: analysis.category.color
            )
        }
        
        await MainActor.run {
            self.chartData.categoryData = categoryData
        }
    }
    
    private func generateComparisonChartData() async {
        guard let comparison = periodicComparison else { return }
        
        let comparisonData = comparison.periods.map { period in
            ComparisonDataPoint(
                period: period.name,
                amount: period.totalAmount,
                change: period.changePercentage
            )
        }
        
        await MainActor.run {
            self.chartData.comparisonData = comparisonData
        }
    }
    
    private func generateHeatmapChartData() async {
        let calendar = Calendar.current
        var heatmapData: [HeatmapDataPoint] = []
        
        // Создаем тепловую карту по дням недели и часам
        for weekday in 1...7 {
            for hour in 0...23 {
                let amount = filteredTransactions
                    .filter { transaction in
                        calendar.component(.weekday, from: transaction.date) == weekday &&
                        calendar.component(.hour, from: transaction.date) == hour
                    }
                    .reduce(0) { $0 + $1.amount }
                
                heatmapData.append(HeatmapDataPoint(
                    weekday: weekday,
                    hour: hour,
                    amount: amount,
                    intensity: calculateIntensity(amount: amount)
                ))
            }
        }
        
        await MainActor.run {
            self.chartData.heatmapData = heatmapData
        }
    }
    
    private func generateTrendChartData() async {
        let trendData = spendingAnalysis?.historicalData?.map { dataPoint in
            TrendDataPoint(
                date: dataPoint.date,
                value: dataPoint.amount,
                type: .spending,
                direction: dataPoint.trend
            )
        } ?? []
        
        await MainActor.run {
            self.chartData.trendData = trendData
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSpendingAnalysis() async -> SpendingAnalysisData {
        let calendar = Calendar.current
        let now = Date()
        
        // Анализ трендов
        let trend = calculateSpendingTrend()
        let volatility = calculateVolatility()
        let seasonality = detectSeasonality()
        
        // Создаем исторические данные
        let historicalData = generateHistoricalData()
        
        // Анализ эффективности
        let efficiency = calculateSpendingEfficiency()
        
        return SpendingAnalysisData(
            totalAmount: totalSpending,
            averageTransaction: averageTransactionAmount,
            transactionCount: transactionCount,
            trend: trend,
            volatility: volatility,
            seasonality: seasonality,
            efficiency: efficiency,
            historicalData: historicalData,
            generatedAt: now
        )
    }
    
    private func calculateSpendingTrend() -> TrendDirection {
        // Упрощенный расчет тренда на основе сравнения с предыдущим периодом
        let currentAmount = totalSpending
        // TODO: Получить данные предыдущего периода и сравнить
        return .stable
    }
    
    private func calculateVolatility() -> Double {
        guard transactions.count > 1 else { return 0 }
        
        let amounts = transactions.map { Double($0.amount as NSDecimalNumber) }
        let mean = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.map { pow($0 - mean, 2) }.reduce(0, +) / Double(amounts.count - 1)
        
        return sqrt(variance) / mean
    }
    
    private func detectSeasonality() -> SeasonalityInfo {
        // Упрощенная детекция сезонности
        let calendar = Calendar.current
        let monthlySpending = Dictionary(grouping: transactions) {
            calendar.component(.month, from: $0.date)
        }.mapValues { transactions in
            transactions.reduce(0) { $0 + $1.amount }
        }
        
        let hasSeasonality = monthlySpending.values.max() ?? 0 > (monthlySpending.values.min() ?? 0) * Decimal(1.5)
        
        return SeasonalityInfo(
            hasSeasonality: hasSeasonality,
            peakMonth: monthlySpending.max { $0.value < $1.value }?.key,
            lowMonth: monthlySpending.min { $0.value < $1.value }?.key,
            seasonalityStrength: hasSeasonality ? 0.7 : 0.1
        )
    }
    
    private func calculateSpendingEfficiency() -> SpendingEfficiency {
        // Анализ эффективности трат
        let necessaryCategories = ["Продукты", "Транспорт", "Коммунальные услуги", "Жилье"]
        let necessarySpending = categoryAnalysis
            .filter { analysis in necessaryCategories.contains(analysis.category.name) }
            .reduce(0) { $0 + $1.amount }
        
        let discretionarySpending = totalSpending - necessarySpending
        let efficiencyScore = totalSpending > 0 ? Double(necessarySpending / totalSpending) : 0
        
        return SpendingEfficiency(
            necessarySpending: necessarySpending,
            discretionarySpending: discretionarySpending,
            efficiencyScore: efficiencyScore,
            optimizationPotential: calculateOptimizationPotential()
        )
    }
    
    private func calculateOptimizationPotential() -> Double {
        // Упрощенный расчет потенциала оптимизации
        let duplicateSpending = detectDuplicateSpending()
        let unusualSpending = detectUnusualSpending()
        
        return min(0.3, duplicateSpending + unusualSpending) // Максимум 30%
    }
    
    private func detectDuplicateSpending() -> Double {
        // Поиск потенциально дублирующихся трат
        let groupedByDescription = Dictionary(grouping: transactions) { $0.title.lowercased() }
        let duplicates = groupedByDescription.filter { $1.count > 1 }
        
        let duplicateAmount = duplicates.values.flatMap { $0 }.reduce(0) { $0 + $1.amount }
        return totalSpending > 0 ? Double(duplicateAmount / totalSpending) * 0.5 : 0
    }
    
    private func detectUnusualSpending() -> Double {
        // Поиск необычных трат (выбросов)
        let amounts = transactions.map { Double($0.amount as NSDecimalNumber) }
        guard amounts.count > 2 else { return 0 }
        
        let sortedAmounts = amounts.sorted()
        let q1 = sortedAmounts[amounts.count / 4]
        let q3 = sortedAmounts[3 * amounts.count / 4]
        let iqr = q3 - q1
        let upperBound = q3 + 1.5 * iqr
        
        let outliers = amounts.filter { $0 > upperBound }
        let outlierAmount = Decimal(outliers.reduce(0, +))
        
        return totalSpending > 0 ? Double(outlierAmount / totalSpending) * 0.3 : 0
    }
    
    private func generateHistoricalData() -> [HistoricalDataPoint] {
        let calendar = Calendar.current
        let groupedByWeek = Dictionary(grouping: transactions) {
            calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date
        }
        
        return groupedByWeek.map { date, transactions in
            let amount = transactions.reduce(0) { $0 + $1.amount }
            return HistoricalDataPoint(
                date: date,
                amount: amount,
                trend: .stable // TODO: Вычислить реальный тренд
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func calculatePreviousPeriodAmount(for category: Category) async -> Decimal {
        // TODO: Реализовать получение данных предыдущего периода
        return 0
    }
    
    private func determineTrend(_ change: Double) -> TrendDirection {
        switch change {
        case let x where x > 5: return .up
        case let x where x < -5: return .down
        default: return .stable
        }
    }
    
    private func createPeriodicComparison() async -> PeriodicComparison {
        // Создаем сравнение с предыдущими периодами
        let currentPeriod = ComparisonPeriod(
            name: "Текущий период",
            totalAmount: totalSpending,
            transactionCount: transactionCount,
            changePercentage: 0
        )
        
        // TODO: Добавить реальные данные предыдущих периодов
        
        return PeriodicComparison(
            timeframe: selectedTimeframe,
            periods: [currentPeriod],
            bestPeriod: currentPeriod,
            worstPeriod: currentPeriod,
            averageAmount: totalSpending,
            trendDirection: spendingTrend
        )
    }
    
    private func calculateIntensity(amount: Decimal) -> Double {
        let maxAmount = filteredTransactions.max { $0.amount < $1.amount }?.amount ?? 1
        return maxAmount > 0 ? Double(amount / maxAmount) : 0
    }
    
    private func mapInsightType(_ type: PersonalizedInsight.InsightType) -> SpendingInsightType {
        switch type {
        case .spendingOptimization: return .optimization
        case .behaviorPattern: return .behavior
        case .categoryInsight: return .category
        default: return .general
        }
    }
    
    private func mapPatternType(_ type: SpendingPatternsAnalysis.SpendingPattern.PatternType) -> SpendingPatternType {
        switch type {
        case .cyclical: return .cyclical
        case .seasonal: return .seasonal
        case .dayOfWeek: return .dayOfWeek
        case .timeOfDay: return .timeOfDay
        case .emotional: return .emotional
        case .habitual: return .habitual
        case .event_driven: return .eventDriven
        }
    }
    
    private func generatePatternInsight(_ pattern: SpendingPatternsAnalysis.SpendingPattern) -> String {
        return "Обнаружен паттерн: \(pattern.description). Частота: \(pattern.frequency.displayName). Влияние: \(pattern.strength * 100)%"
    }
    
    private func generateExport(format: ExportFormat) async throws -> URL {
        // TODO: Реализовать экспорт данных
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("spending_analytics.\(format.fileExtension)")
    }
    
    private func generateInsightSummary(_ insight: SpendingInsight) -> String {
        return """
        💡 \(insight.title)
        
        \(insight.description)
        
        Уверенность: \(Int(insight.confidence * 100))%
        Влияние: \(insight.impact.displayName)
        
        #SpendingAnalytics #FinanceInsights
        """
    }
    
    private func defaultDateInterval() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        return DateInterval(start: startOfMonth, end: now)
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
        let spendingError = error as? SpendingAnalyticsError ?? SpendingAnalyticsError.unknown(error.localizedDescription)
        errorMessage = spendingError.localizedDescription
        showError = true
    }
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum SpendingTimeframe: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .week: return "Неделя"
        case .month: return "Месяц"
        case .quarter: return "Квартал"
        case .year: return "Год"
        case .custom: return "Произвольный"
        }
    }
    
    var dateInterval: DateInterval? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .month:
            return calendar.dateInterval(of: .month, for: now)
        case .quarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let startMonth = quarter * 3 + 1
            let startDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: now),
                month: startMonth,
                day: 1
            )) ?? now
            return DateInterval(start: startDate, duration: 90 * 24 * 3600)
        case .year:
            return calendar.dateInterval(of: .year, for: now)
        case .custom:
            return nil
        }
    }
    
    var durationInDays: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        case .custom: return 30
        }
    }
}

enum ChartType: String, CaseIterable {
    case timeline = "timeline"
    case categories = "categories"
    case comparison = "comparison"
    case heatmap = "heatmap"
    case trends = "trends"
    
    var displayName: String {
        switch self {
        case .timeline: return "Временная шкала"
        case .categories: return "По категориям"
        case .comparison: return "Сравнение периодов"
        case .heatmap: return "Тепловая карта"
        case .trends: return "Тренды"
        }
    }
    
    var icon: String {
        switch self {
        case .timeline: return "chart.line.uptrend.xyaxis"
        case .categories: return "chart.pie"
        case .comparison: return "chart.bar"
        case .heatmap: return "grid"
        case .trends: return "arrow.triangle.2.circlepath"
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case pdf = "pdf"
    case json = "json"
    
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .pdf: return "PDF"
        case .json: return "JSON"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - Data Structures

struct SpendingFilters {
    var categories: Set<UUID> = []
    var minAmount: Decimal?
    var maxAmount: Decimal?
    var dateRange: DateInterval?
    var searchText: String = ""
    var transactionTypes: Set<TransactionType> = [.expense]
    
    func matches(transaction: Transaction) -> Bool {
        // Проверка категории
        if !categories.isEmpty {
            guard let categoryId = transaction.category?.id,
                  categories.contains(categoryId) else {
                return false
            }
        }
        
        // Проверка суммы
        if let minAmount = minAmount, transaction.amount < minAmount {
            return false
        }
        
        if let maxAmount = maxAmount, transaction.amount > maxAmount {
            return false
        }
        
        // Проверка даты
        if let dateRange = dateRange, !dateRange.contains(transaction.date) {
            return false
        }
        
        // Проверка текста
        if !searchText.isEmpty && !transaction.title.localizedCaseInsensitiveContains(searchText) {
            return false
        }
        
        // Проверка типа транзакции
        if !transactionTypes.contains(transaction.type) {
            return false
        }
        
        return true
    }
}

struct SpendingChartData {
    var timelineData: [TimelineDataPoint] = []
    var categoryData: [CategoryChartDataPoint] = []
    var comparisonData: [ComparisonDataPoint] = []
    var heatmapData: [HeatmapDataPoint] = []
    var trendData: [TrendDataPoint] = []
}

struct ChartConfiguration {
    var showGrid: Bool = true
    var showLegend: Bool = true
    var animationEnabled: Bool = true
    var colorScheme: ChartColorScheme = .automatic
    var granularity: ChartGranularity = .automatic
}

enum ChartColorScheme {
    case automatic
    case light
    case dark
    case custom([Color])
}

enum ChartGranularity {
    case automatic
    case daily
    case weekly
    case monthly
}

struct SpendingAnalysisData {
    let totalAmount: Decimal
    let averageTransaction: Decimal
    let transactionCount: Int
    let trend: TrendDirection
    let volatility: Double
    let seasonality: SeasonalityInfo
    let efficiency: SpendingEfficiency
    let historicalData: [HistoricalDataPoint]
    let generatedAt: Date
}

struct SeasonalityInfo {
    let hasSeasonality: Bool
    let peakMonth: Int?
    let lowMonth: Int?
    let seasonalityStrength: Double
}

struct SpendingEfficiency {
    let necessarySpending: Decimal
    let discretionarySpending: Decimal
    let efficiencyScore: Double
    let optimizationPotential: Double
    
    var efficiencyRating: EfficiencyRating {
        switch efficiencyScore {
        case 0.8...: return .excellent
        case 0.6...: return .good
        case 0.4...: return .fair
        default: return .poor
        }
    }
    
    enum EfficiencyRating {
        case excellent, good, fair, poor
        
        var displayName: String {
            switch self {
            case .excellent: return "Отличная"
            case .good: return "Хорошая"
            case .fair: return "Удовлетворительная"
            case .poor: return "Требует улучшения"
            }
        }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
    }
}

struct HistoricalDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
    let trend: TrendDirection
}

struct SpendingInsight: Identifiable {
    let id: UUID
    let type: SpendingInsightType
    let title: String
    let description: String
    let impact: ImpactLevel
    let confidence: Double
    let actionableSteps: [String]
    let supportingData: PersonalizedInsight.InsightSupportingData
}

enum SpendingInsightType {
    case optimization
    case behavior
    case category
    case trend
    case anomaly
    case general
    
    var icon: String {
        switch self {
        case .optimization: return "arrow.down.circle"
        case .behavior: return "brain.head.profile"
        case .category: return "tag"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .anomaly: return "exclamationmark.triangle"
        case .general: return "lightbulb"
        }
    }
}

struct SpendingPattern: Identifiable {
    let id: UUID
    let type: SpendingPatternType
    let description: String
    let frequency: String
    let strength: Double
    let examples: [Transaction]
    let insight: String
}

enum SpendingPatternType {
    case cyclical
    case seasonal
    case dayOfWeek
    case timeOfDay
    case emotional
    case habitual
    case eventDriven
    
    var displayName: String {
        switch self {
        case .cyclical: return "Циклический"
        case .seasonal: return "Сезонный"
        case .dayOfWeek: return "По дням недели"
        case .timeOfDay: return "По времени дня"
        case .emotional: return "Эмоциональный"
        case .habitual: return "Привычный"
        case .eventDriven: return "Событийный"
        }
    }
}

struct SpendingPrediction: Identifiable {
    let id = UUID()
    let category: Category
    let predictedAmount: Decimal
    let confidence: Double
    let trend: String
    let period: String
    let factors: [String]
}

struct CategoryAnalysis: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let percentage: Double
    let transactionCount: Int
    let averageAmount: Decimal
    let changeFromPrevious: Double
    let trend: TrendDirection
    let topTransactions: [Transaction]
}

struct PeriodicComparison {
    let timeframe: SpendingTimeframe
    let periods: [ComparisonPeriod]
    let bestPeriod: ComparisonPeriod
    let worstPeriod: ComparisonPeriod
    let averageAmount: Decimal
    let trendDirection: TrendDirection
}

struct ComparisonPeriod: Identifiable {
    let id = UUID()
    let name: String
    let totalAmount: Decimal
    let transactionCount: Int
    let changePercentage: Double
}

// MARK: - Chart Data Points

struct TimelineDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
}

struct CategoryChartDataPoint: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let percentage: Double
    let color: String
}

struct ComparisonDataPoint: Identifiable {
    let id = UUID()
    let period: String
    let amount: Decimal
    let change: Double
}

struct HeatmapDataPoint: Identifiable {
    let id = UUID()
    let weekday: Int
    let hour: Int
    let amount: Decimal
    let intensity: Double
}

// MARK: - Error Types

enum SpendingAnalyticsError: LocalizedError {
    case noData
    case invalidTimeframe
    case processingError
    case exportError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "Нет данных для анализа"
        case .invalidTimeframe:
            return "Неверный временной период"
        case .processingError:
            return "Ошибка обработки данных"
        case .exportError:
            return "Ошибка экспорта данных"
        case .unknown(let message):
            return message
        }
    }
} 