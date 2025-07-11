import SwiftUI
import Charts

// MARK: - AnalyticsTabView

struct AnalyticsTabView: View {
    
    // MARK: - Properties
    
    @State private var analyticsViewModel: HabitAnalyticsViewModel
    @State private var healthIntegrationViewModel: HealthIntegrationViewModel
    @State private var trendsViewModel: TrendsViewModel
    @State private var insightsViewModel: InsightsViewModel
    
    @State private var selectedHabit: Habit?
    @State private var showingHabitPicker = false
    
    // MARK: - Initialization
    
    init(
        analyticsService: HabitAnalyticsServiceProtocol,
        healthKitService: AdvancedHealthKitServiceProtocol?,
        notificationService: NotificationServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol
    ) {
        self._analyticsViewModel = State(initialValue: HabitAnalyticsViewModel(
            analyticsService: analyticsService,
            errorHandlingService: errorHandlingService
        ))
        
        self._healthIntegrationViewModel = State(initialValue: HealthIntegrationViewModel(
            healthKitService: healthKitService ?? MockAdvancedHealthKitService(),
            errorHandlingService: errorHandlingService
        ))
        
        self._trendsViewModel = State(initialValue: TrendsViewModel(
            analyticsService: analyticsService,
            errorHandlingService: errorHandlingService
        ))
        
        self._insightsViewModel = State(initialValue: InsightsViewModel(
            analyticsService: analyticsService,
            healthKitService: healthKitService,
            notificationService: notificationService,
            errorHandlingService: errorHandlingService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                if analyticsViewModel.hasData {
                    tabContentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Аналитика")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingHabitPicker) {
                habitPickerSheet
            }
            .onAppear {
                setupViewModels()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            habitSelectorView
            
            if let headerStats = analyticsViewModel.headerStats {
                statsCardsView(stats: headerStats)
            }
            
            analyticsTabsView
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Habit Selector View
    
    private var habitSelectorView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Анализируемая привычка")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: { showingHabitPicker = true }) {
                    HStack {
                        if let habit = selectedHabit {
                            Circle()
                                .fill(Color(hex: habit.color) ?? .blue)
                                .frame(width: 12, height: 12)
                            
                            Text(habit.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                        } else {
                            Text("Выберите привычку")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            
            Spacer()
            
            Button(action: refreshAnalytics) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
            }
            .disabled(analyticsViewModel.state.isLoading)
        }
    }
    
    // MARK: - Stats Cards View
    
    private func statsCardsView(stats: AnalyticsHeaderStats) -> some View {
        HStack(spacing: 12) {
            statCard(
                title: "Текущая серия",
                value: "\(stats.currentStreak)",
                subtitle: "дней",
                color: .orange,
                icon: "flame.fill"
            )
            
            statCard(
                title: "Процент выполнения",
                value: stats.formattedCompletionRate,
                subtitle: "всего",
                color: .green,
                icon: "percent"
            )
            
            statCard(
                title: "Очки",
                value: "\(stats.totalPoints)",
                subtitle: "заработано",
                color: .purple,
                icon: "star.fill"
            )
        }
    }
    
    // MARK: - Stat Card
    
    private func statCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Analytics Tabs View
    
    private var analyticsTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    analyticsTabButton(tab: tab)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Analytics Tab Button
    
    private func analyticsTabButton(tab: AnalyticsTab) -> some View {
        Button(action: { selectTab(tab) }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.caption)
                
                Text(tab.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                analyticsViewModel.state.selectedTab == tab ? Color.blue : Color(.systemGray5)
            )
            .foregroundColor(
                analyticsViewModel.state.selectedTab == tab ? .white : .primary
            )
            .cornerRadius(20)
        }
    }
    
    // MARK: - Tab Content View
    
    private var tabContentView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                switch analyticsViewModel.state.selectedTab {
                case .overview:
                    overviewTabContent
                case .trends:
                    trendsTabContent
                case .heatmap:
                    heatmapTabContent
                case .patterns:
                    patternsTabContent
                case .insights:
                    insightsTabContent
                case .performance:
                    performanceTabContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Overview Tab Content
    
    private var overviewTabContent: some View {
        VStack(spacing: 20) {
            if let trends = analyticsViewModel.state.trends {
                trendSummaryCard(trends: trends)
            }
            
            if let weeklyPatterns = analyticsViewModel.state.weeklyPatterns {
                weeklyPatternsCard(patterns: weeklyPatterns)
            }
            
            if let streakAnalytics = analyticsViewModel.state.streakAnalytics {
                streakAnalyticsCard(analytics: streakAnalytics)
            }
            
            quickInsightsCard
        }
    }
    
    // MARK: - Trend Summary Card
    
    private func trendSummaryCard(trends: HabitTrends) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Тренд")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(trends.direction.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: trends.direction.icon)
                        .foregroundColor(Color(hex: trends.direction.color))
                        .font(.title2)
                    
                    Text("\(Int(trends.confidenceLevel * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Мини-график тренда
            if !trends.dataPoints.isEmpty {
                Chart(trends.dataPoints, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(Color(hex: trends.direction.color) ?? .blue)
                }
                .frame(height: 80)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Weekly Patterns Card
    
    private func weeklyPatternsCard(patterns: WeeklyPatterns) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Недельные паттерны")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                ForEach(patterns.patterns, id: \.weekday) { pattern in
                    VStack(spacing: 4) {
                        Text(getDayShortName(pattern.weekday))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(Color.green.opacity(pattern.successRate))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("\(Int(pattern.successRate * 100))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(pattern.successRate > 0.5 ? .white : .primary)
                            )
                    }
                }
            }
            
            if let bestDay = patterns.bestDay, let worstDay = patterns.worstDay {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Лучший день")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getDayName(bestDay.weekday))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Худший день")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(getDayName(worstDay.weekday))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Streak Analytics Card
    
    private func streakAnalyticsCard(analytics: StreakAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Анализ серий")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Текущая")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(analytics.currentStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Рекорд")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(analytics.longestStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Средняя")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(analytics.averageStreak))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Quick Insights Card
    
    private var quickInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Быстрые инсайты")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Подробнее") {
                    selectTab(.insights)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if !analyticsViewModel.state.predictiveInsights.isEmpty {
                ForEach(Array(analyticsViewModel.state.predictiveInsights.prefix(2)), id: \.prediction) { insight in
                    insightRow(
                        title: insight.type.displayName,
                        description: insight.prediction,
                        confidence: insight.confidence
                    )
                }
            } else {
                Text("Пока недостаточно данных для инсайтов")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Insight Row
    
    private func insightRow(title: String, description: String, confidence: Double) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(confidence > 0.8 ? Color.green : confidence > 0.6 ? Color.orange : Color.red)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Trends Tab Content
    
    private var trendsTabContent: some View {
        VStack(spacing: 20) {
            Text("Детальная аналитика трендов")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Здесь будет детальный график трендов
            Text("График трендов в разработке")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Heatmap Tab Content
    
    private var heatmapTabContent: some View {
        VStack(spacing: 20) {
            if let heatmapData = analyticsViewModel.state.heatmapData {
                HabitHeatmapView(heatmapData: heatmapData) { date in
                    // Handle date selection
                    print("Selected date: \(date)")
                }
            } else {
                Text("Загрузка данных календаря...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(40)
            }
        }
    }
    
    // MARK: - Patterns Tab Content
    
    private var patternsTabContent: some View {
        VStack(spacing: 20) {
            Text("Анализ паттернов")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let patterns = analyticsViewModel.state.weeklyPatterns {
                weeklyPatternsCard(patterns: patterns)
            }
            
            // Дополнительные паттерны времени дня, сезонности и т.д.
        }
    }
    
    // MARK: - Insights Tab Content
    
    private var insightsTabContent: some View {
        VStack(spacing: 20) {
            Text("Персональные инсайты")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !analyticsViewModel.state.predictiveInsights.isEmpty {
                ForEach(analyticsViewModel.state.predictiveInsights, id: \.prediction) { insight in
                    insightCard(insight: insight)
                }
            }
            
            if !analyticsViewModel.state.timingRecommendations.isEmpty {
                ForEach(analyticsViewModel.state.timingRecommendations, id: \.suggestion) { recommendation in
                    recommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    // MARK: - Performance Tab Content
    
    private var performanceTabContent: some View {
        VStack(spacing: 20) {
            Text("Показатели эффективности")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let metrics = analyticsViewModel.state.performanceMetrics {
                performanceMetricsCard(metrics: metrics)
            }
        }
    }
    
    // MARK: - Insight Card
    
    private func insightCard(insight: PredictiveInsight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(insight.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(insight.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(insight.prediction)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Recommendation Card
    
    private func recommendationCard(recommendation: TimingRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text("Рекомендация")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(recommendation.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(recommendation.suggestion)
                .font(.body)
                .foregroundColor(.primary)
            
            if !recommendation.reason.isEmpty {
                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Performance Metrics Card
    
    private func performanceMetricsCard(metrics: PerformanceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Метрики за \(metrics.period.displayName.lowercased())")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                metricItem(title: "Эффективность", value: "\(Int(metrics.efficiency * 100))%", color: .green)
                metricItem(title: "Вовлеченность", value: "\(Int(metrics.engagement * 100))%", color: .blue)
                metricItem(title: "Производительность", value: "\(Int(metrics.performance * 100))%", color: .orange)
                metricItem(title: "Постоянство", value: "\(Int(metrics.consistency * 100))%", color: .purple)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Metric Item
    
    private func metricItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Выберите привычку для анализа")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Выберите привычку, чтобы увидеть детальную аналитику, тренды и персональные рекомендации")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Выбрать привычку") {
                showingHabitPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
    
    // MARK: - Habit Picker Sheet
    
    private var habitPickerSheet: some View {
        NavigationView {
            Text("Habit Picker - В разработке")
                .navigationTitle("Выберите привычку")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Отмена") {
                        showingHabitPicker = false
                    }
                )
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupViewModels() {
        // Настройка ViewModels при появлении экрана
    }
    
    private func selectTab(_ tab: AnalyticsTab) {
        analyticsViewModel.send(.tabChanged(tab))
    }
    
    private func refreshAnalytics() {
        analyticsViewModel.send(.refreshAnalytics)
    }
    
    private func getDayName(_ weekday: Int) -> String {
        let days = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
        return days[safe: weekday - 1] ?? "Неизвестный день"
    }
    
    private func getDayShortName(_ weekday: Int) -> String {
        let days = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        return days[safe: weekday - 1] ?? "?"
    }
}

// MARK: - Mock Service

private class MockAdvancedHealthKitService: AdvancedHealthKitServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {}
    func cleanup() async {}
    func requestPermissions() async throws {}
    func isHealthDataAvailable() -> Bool { return false }
    func fetchStepsData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchSleepData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchHeartRateData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchActiveEnergyData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchExerciseTimeData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchMindfulnessData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchWeightData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func fetchWaterIntakeData(for dateRange: DateInterval) async throws -> [HealthData] { return [] }
    func syncTodayData() async throws {}
    func calculateHabitHealthCorrelations(_ habit: Habit) async throws -> [HabitHealthCorrelation] { return [] }
    func getHealthInsights(for habit: Habit) async throws -> [HealthInsight] { return [] }
    func enableBackgroundDelivery(for types: [HealthDataType]) async throws {}
}

// MARK: - Extensions

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension PredictiveInsight.InsightType {
    var displayName: String {
        switch self {
        case .positive:
            return "Позитивный прогноз"
        case .warning:
            return "Предупреждение"
        case .streak:
            return "Прогноз серии"
        case .goal:
            return "Достижение цели"
        }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsTabView(
        analyticsService: MockHabitAnalyticsService(),
        healthKitService: nil,
        notificationService: MockNotificationService(),
        errorHandlingService: MockErrorHandlingService()
    )
}

// Mock services for preview
private class MockHabitAnalyticsService: HabitAnalyticsServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {}
    func cleanup() async {}
    func getHabitTrends(_ habit: Habit, period: AnalyticsPeriod) async throws -> HabitTrends { 
        return HabitTrends(direction: .improving, strength: 0.8, dataPoints: [], growthRate: 0.1, confidenceLevel: 0.8)
    }
    func getHabitHeatmapData(_ habit: Habit, year: Int?) async throws -> HabitHeatmapData {
        return HabitHeatmapData(year: 2024, data: [:], totalDays: 365, completedDays: 250, trackedDays: 300)
    }
    func getWeeklyPatterns(_ habit: Habit) async throws -> WeeklyPatterns {
        return WeeklyPatterns(patterns: [], bestDay: nil, worstDay: nil)
    }
    func getSuccessRateAnalysis(_ habit: Habit) async throws -> SuccessRateAnalysis {
        return SuccessRateAnalysis(last7Days: 0.8, last30Days: 0.7, last90Days: 0.75, allTime: 0.72, trend: .improving, consistency: 0.8)
    }
    func getStreakAnalytics(_ habit: Habit) async throws -> StreakAnalytics {
        return StreakAnalytics(currentStreak: 5, longestStreak: 15, averageStreak: 7.5, totalStreaks: 10, streakDistribution: [:], streakTrend: .improving)
    }
    func getOptimalTimingRecommendations(_ habit: Habit) async throws -> [TimingRecommendation] { return [] }
    func getHabitCorrelationMatrix(_ habits: [Habit]) async throws -> CorrelationMatrix {
        return CorrelationMatrix(habits: [], correlations: [])
    }
    func getPredictiveInsights(_ habit: Habit) async throws -> [PredictiveInsight] { return [] }
    func getOverallAnalytics(_ habits: [Habit]) async throws -> OverallAnalytics {
        return OverallAnalytics(totalHabits: 0, averageSuccessRate: 0, totalStreaks: 0, averageStreak: 0, topPerformingHabits: [], improvementAreas: [])
    }
    func getPerformanceMetrics(_ habit: Habit, period: AnalyticsPeriod) async throws -> PerformanceMetrics {
        return PerformanceMetrics(period: .month, efficiency: 0.8, engagement: 0.7, performance: 0.75, consistency: 0.8, totalEntries: 20, averageValue: 1.5)
    }
}

private class MockNotificationService: NotificationServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {}
    func cleanup() async {}
    func requestPermissions() async throws {}
    func scheduleHabitReminder(_ habitId: UUID, name: String, time: Date) async throws {}
    func cancelNotification(for identifier: String) async {}
    func cancelAllNotifications() async {}
    func getPendingNotifications() async -> [String] { return [] }
}

private class MockErrorHandlingService: ErrorHandlingServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {}
    func cleanup() async {}
    func handle(_ error: AppError, context: ErrorContext) async {}
    func logError(_ error: Error, context: String) {}
    func reportCrash(_ error: Error, userInfo: [String: Any]) {}
} 