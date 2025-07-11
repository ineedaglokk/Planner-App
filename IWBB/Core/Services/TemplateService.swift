import Foundation
import SwiftData

// MARK: - TemplateService Protocol

protocol TemplateServiceProtocol: ServiceProtocol {
    // Template CRUD
    func getAllTemplates() async throws -> [ProjectTemplate]
    func getTemplate(by id: UUID) async throws -> ProjectTemplate?
    func getTemplatesForCategory(_ category: TemplateCategory) async throws -> [ProjectTemplate]
    func getUserTemplates() async throws -> [ProjectTemplate]
    func getPublicTemplates() async throws -> [ProjectTemplate]
    func saveTemplate(_ template: ProjectTemplate) async throws
    func updateTemplate(_ template: ProjectTemplate) async throws
    func deleteTemplate(_ template: ProjectTemplate) async throws
    
    // Template Application
    func instantiateTemplate(_ template: ProjectTemplate) async throws -> Project
    func previewTemplate(_ template: ProjectTemplate) async throws -> TemplatePreview
    func validateTemplate(_ template: ProjectTemplate) async throws -> [TemplateValidationError]
    
    // Template Recommendations
    func getRecommendedTemplates(for category: TemplateCategory?) async throws -> [ProjectTemplate]
    func suggestTemplatesForGoal(_ goal: GoalHierarchy) async throws -> [ProjectTemplate]
    func getSimilarTemplates(to template: ProjectTemplate) async throws -> [ProjectTemplate]
    func getTrendingTemplates() async throws -> [ProjectTemplate]
    
    // Template Rating and Reviews
    func rateTemplate(_ template: ProjectTemplate, rating: Double) async throws
    func getTemplateReviews(_ template: ProjectTemplate) async throws -> [TemplateReview]
    func addReview(to template: ProjectTemplate, review: TemplateReview) async throws
    
    // Template Sharing and Community
    func publishTemplate(_ template: ProjectTemplate) async throws
    func shareTemplate(_ template: ProjectTemplate) async throws -> String // Share URL
    func importTemplate(from data: TemplateData) async throws -> ProjectTemplate
    func exportTemplate(_ template: ProjectTemplate) async throws -> TemplateData
    
    // Template Analytics
    func getTemplateAnalytics(_ template: ProjectTemplate) async throws -> TemplateAnalytics
    func getTemplateUsageStatistics() async throws -> TemplateUsageStatistics
    func generateTemplateInsights() async throws -> [TemplateInsight]
}

// MARK: - TemplateService Implementation

@Observable
final class TemplateService: TemplateServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let cloudService: CloudServiceProtocol?
    private let analyticsService: AnalyticsServiceProtocol
    
    private(set) var isInitialized: Bool = false
    
    // Template recommendation engine
    private let recommendationEngine = TemplateRecommendationEngine()
    private let templateValidator = TemplateValidator()
    private let similarityCalculator = TemplateSimilarityCalculator()
    
    // Caching
    private var templateCache: [UUID: ProjectTemplate] = [:]
    private var categoryCache: [TemplateCategory: [ProjectTemplate]] = [:]
    private var recommendationCache: [String: [ProjectTemplate]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.plannerapp.template.cache", qos: .utility)
    
    // Analytics
    private var usageStatistics: TemplateUsageStatistics?
    private var lastAnalyticsUpdate: Date?
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        cloudService: CloudServiceProtocol? = nil,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.dataService = dataService
        self.cloudService = cloudService
        self.analyticsService = analyticsService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        do {
            // Инициализируем движок рекомендаций
            try await recommendationEngine.initialize()
            
            // Загружаем базовые шаблоны
            try await loadDefaultTemplates()
            
            // Обновляем кэш категорий
            try await updateCategoryCache()
            
            // Синхронизируем с облаком
            try await syncWithCloud()
            
            isInitialized = true
            
            #if DEBUG
            print("TemplateService initialized successfully")
            #endif
            
        } catch {
            throw AppError.from(error)
        }
    }
    
    func cleanup() async {
        // Очищаем кэши
        templateCache.removeAll()
        categoryCache.removeAll()
        recommendationCache.removeAll()
        
        // Очищаем движок рекомендаций
        await recommendationEngine.cleanup()
        
        isInitialized = false
        
        #if DEBUG
        print("TemplateService cleaned up")
        #endif
    }
    
    // MARK: - Template CRUD
    
    func getAllTemplates() async throws -> [ProjectTemplate] {
        return try await dataService.fetch(ProjectTemplate.self, predicate: nil)
    }
    
    func getTemplate(by id: UUID) async throws -> ProjectTemplate? {
        // Проверяем кэш
        if let cachedTemplate = templateCache[id] {
            return cachedTemplate
        }
        
        let predicate = #Predicate<ProjectTemplate> { template in
            template.id == id
        }
        
        let templates = try await dataService.fetch(ProjectTemplate.self, predicate: predicate)
        let template = templates.first
        
        // Кэшируем результат
        if let template = template {
            templateCache[id] = template
        }
        
        return template
    }
    
    func getTemplatesForCategory(_ category: TemplateCategory) async throws -> [ProjectTemplate] {
        // Проверяем кэш
        if let cachedTemplates = categoryCache[category] {
            return cachedTemplates
        }
        
        let predicate = #Predicate<ProjectTemplate> { template in
            template.category == category
        }
        
        let templates = try await dataService.fetch(ProjectTemplate.self, predicate: predicate)
        
        // Кэшируем результат
        categoryCache[category] = templates
        
        return templates
    }
    
    func getUserTemplates() async throws -> [ProjectTemplate] {
        // Получаем шаблоны текущего пользователя
        let predicate = #Predicate<ProjectTemplate> { template in
            template.user != nil && !template.isPublic
        }
        
        return try await dataService.fetch(ProjectTemplate.self, predicate: predicate)
    }
    
    func getPublicTemplates() async throws -> [ProjectTemplate] {
        let predicate = #Predicate<ProjectTemplate> { template in
            template.isPublic
        }
        
        return try await dataService.fetch(ProjectTemplate.self, predicate: predicate)
    }
    
    func saveTemplate(_ template: ProjectTemplate) async throws {
        try template.validate()
        
        try await dataService.save(template)
        
        // Обновляем кэши
        templateCache[template.id] = template
        await invalidateCategoryCache(template.category)
        
        // Обновляем аналитику
        await updateTemplateAnalytics(template)
    }
    
    func updateTemplate(_ template: ProjectTemplate) async throws {
        try template.validate()
        template.updateTimestamp()
        template.markForSync()
        
        try await dataService.update(template)
        
        // Обновляем кэши
        templateCache[template.id] = template
        await invalidateCategoryCache(template.category)
    }
    
    func deleteTemplate(_ template: ProjectTemplate) async throws {
        try await dataService.delete(template)
        
        // Очищаем кэши
        templateCache.removeValue(forKey: template.id)
        await invalidateCategoryCache(template.category)
    }
    
    // MARK: - Template Application
    
    func instantiateTemplate(_ template: ProjectTemplate) async throws -> Project {
        // Увеличиваем счетчик использований
        template.incrementUsageCount()
        try await updateTemplate(template)
        
        // Создаем проект из шаблона
        let project = Project(
            name: template.name,
            description: template.description,
            priority: .medium,
            targetEndDate: template.estimatedDuration.map { Date().addingTimeInterval($0) }
        )
        
        project.templateId = template.id
        project.templateName = template.name
        project.icon = template.icon
        project.color = template.color
        
        // Применяем шаблон
        project.applyTemplate(template)
        
        try await dataService.save(project)
        
        // Записываем использование в аналитику
        await analyticsService.trackTemplateUsage(template.id)
        
        return project
    }
    
    func previewTemplate(_ template: ProjectTemplate) async throws -> TemplatePreview {
        let estimatedTasks = template.defaultTasks.count
        let estimatedPhases = template.phases.count
        let estimatedMilestones = template.milestones.count
        let estimatedDuration = template.estimatedDuration
        
        let complexity = calculateTemplateComplexity(template)
        let requiredSkills = extractRequiredSkills(template)
        let timelinePreview = generateTimelinePreview(template)
        
        return TemplatePreview(
            template: template,
            estimatedTasks: estimatedTasks,
            estimatedPhases: estimatedPhases,
            estimatedMilestones: estimatedMilestones,
            estimatedDuration: estimatedDuration,
            complexity: complexity,
            requiredSkills: requiredSkills,
            timelinePreview: timelinePreview
        )
    }
    
    func validateTemplate(_ template: ProjectTemplate) async throws -> [TemplateValidationError] {
        return await templateValidator.validate(template)
    }
    
    // MARK: - Template Recommendations
    
    func getRecommendedTemplates(for category: TemplateCategory? = nil) async throws -> [ProjectTemplate] {
        let cacheKey = category?.rawValue ?? "all"
        
        // Проверяем кэш
        if let cachedRecommendations = recommendationCache[cacheKey] {
            return cachedRecommendations
        }
        
        let recommendations = await recommendationEngine.getRecommendations(
            category: category,
            userPreferences: await getUserPreferences(),
            usageHistory: await getUserTemplateUsage()
        )
        
        // Кэшируем результат
        recommendationCache[cacheKey] = recommendations
        
        return recommendations
    }
    
    func suggestTemplatesForGoal(_ goal: GoalHierarchy) async throws -> [ProjectTemplate] {
        let goalContext = TemplateRecommendationContext(
            category: goal.category?.templateCategory,
            timeframe: goal.timeframe,
            complexity: estimateGoalComplexity(goal),
            keywords: extractGoalKeywords(goal)
        )
        
        return await recommendationEngine.suggestTemplatesForContext(goalContext)
    }
    
    func getSimilarTemplates(to template: ProjectTemplate) async throws -> [ProjectTemplate] {
        let allTemplates = try await getAllTemplates()
        
        return await similarityCalculator.findSimilarTemplates(
            to: template,
            in: allTemplates,
            limit: 5
        )
    }
    
    func getTrendingTemplates() async throws -> [ProjectTemplate] {
        let allTemplates = try await getPublicTemplates()
        
        // Сортируем по популярности (рейтинг + использования + скачивания)
        return allTemplates.sorted { template1, template2 in
            template1.popularityScore > template2.popularityScore
        }.prefix(10).map { $0 }
    }
    
    // MARK: - Template Rating and Reviews
    
    func rateTemplate(_ template: ProjectTemplate, rating: Double) async throws {
        guard rating >= 0 && rating <= 5 else {
            throw AppError.from(TemplateError.invalidRating)
        }
        
        template.updateRating(newRating: rating)
        try await updateTemplate(template)
        
        await analyticsService.trackTemplateRating(template.id, rating: rating)
    }
    
    func getTemplateReviews(_ template: ProjectTemplate) async throws -> [TemplateReview] {
        // Заглушка для будущей реализации системы отзывов
        return []
    }
    
    func addReview(to template: ProjectTemplate, review: TemplateReview) async throws {
        // Заглушка для будущей реализации системы отзывов
        await analyticsService.trackTemplateReview(template.id)
    }
    
    // MARK: - Template Sharing and Community
    
    func publishTemplate(_ template: ProjectTemplate) async throws {
        guard template.user != nil else {
            throw AppError.from(TemplateError.unauthorized)
        }
        
        // Валидируем шаблон перед публикацией
        let validationErrors = try await validateTemplate(template)
        if !validationErrors.isEmpty {
            throw AppError.from(TemplateError.validationFailed(validationErrors))
        }
        
        template.isPublic = true
        template.authorName = template.user?.name
        try await updateTemplate(template)
        
        // Синхронизируем с облаком
        try await syncTemplateToCloud(template)
        
        await analyticsService.trackTemplatePublication(template.id)
    }
    
    func shareTemplate(_ template: ProjectTemplate) async throws -> String {
        let shareData = try await exportTemplate(template)
        
        // Создаем ссылку для расшаривания (заглушка)
        let shareURL = "plannerapp://template/\(template.id.uuidString)"
        
        await analyticsService.trackTemplateShare(template.id)
        
        return shareURL
    }
    
    func importTemplate(from data: TemplateData) async throws -> ProjectTemplate {
        let template = try await parseTemplateData(data)
        
        // Генерируем новый ID для импортированного шаблона
        template.id = UUID()
        template.isPublic = false // Импортированные шаблоны изначально приватные
        template.downloadCount = 0
        template.usageCount = 0
        
        try await saveTemplate(template)
        
        await analyticsService.trackTemplateImport(template.id)
        
        return template
    }
    
    func exportTemplate(_ template: ProjectTemplate) async throws -> TemplateData {
        let exportDict = template.exportToDictionary()
        
        return TemplateData(
            metadata: TemplateMetadata(
                version: "1.0",
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            ),
            templateData: exportDict
        )
    }
    
    // MARK: - Template Analytics
    
    func getTemplateAnalytics(_ template: ProjectTemplate) async throws -> TemplateAnalytics {
        let usageCount = template.usageCount
        let rating = template.rating
        let downloadCount = template.downloadCount
        
        let usageOverTime = await analyticsService.getTemplateUsageOverTime(template.id)
        let conversionRate = await calculateConversionRate(template)
        let successRate = await calculateSuccessRate(template)
        
        return TemplateAnalytics(
            template: template,
            totalUsage: usageCount,
            averageRating: rating,
            downloadCount: downloadCount,
            usageOverTime: usageOverTime,
            conversionRate: conversionRate,
            successRate: successRate,
            topCategories: await getTopCategories(),
            userFeedback: await getUserFeedback(template)
        )
    }
    
    func getTemplateUsageStatistics() async throws -> TemplateUsageStatistics {
        // Проверяем кэш
        if let cached = usageStatistics,
           let lastUpdate = lastAnalyticsUpdate,
           Date().timeIntervalSince(lastUpdate) < 3600 { // 1 час
            return cached
        }
        
        let allTemplates = try await getAllTemplates()
        
        let statistics = TemplateUsageStatistics(
            totalTemplates: allTemplates.count,
            publicTemplates: allTemplates.filter { $0.isPublic }.count,
            totalUsage: allTemplates.reduce(0) { $0 + $1.usageCount },
            averageRating: calculateAverageRating(allTemplates),
            mostPopularCategory: findMostPopularCategory(allTemplates),
            topRatedTemplates: allTemplates.sorted { $0.rating > $1.rating }.prefix(5).map { $0 },
            mostUsedTemplates: allTemplates.sorted { $0.usageCount > $1.usageCount }.prefix(5).map { $0 }
        )
        
        // Кэшируем результат
        usageStatistics = statistics
        lastAnalyticsUpdate = Date()
        
        return statistics
    }
    
    func generateTemplateInsights() async throws -> [TemplateInsight] {
        let statistics = try await getTemplateUsageStatistics()
        let allTemplates = try await getAllTemplates()
        
        var insights: [TemplateInsight] = []
        
        // Анализ популярности категорий
        let categoryUsage = Dictionary(grouping: allTemplates) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.usageCount } }
        
        if let mostPopular = categoryUsage.max(by: { $0.value < $1.value }) {
            insights.append(TemplateInsight(
                type: .categoryTrend,
                title: "Популярная категория",
                description: "Категория '\(mostPopular.key.displayName)' наиболее популярна",
                actionRecommendation: "Рассмотрите создание дополнительных шаблонов в этой категории"
            ))
        }
        
        // Анализ качества шаблонов
        let lowRatedTemplates = allTemplates.filter { $0.rating < 3.0 && $0.ratingCount > 5 }
        if !lowRatedTemplates.isEmpty {
            insights.append(TemplateInsight(
                type: .qualityIssue,
                title: "Шаблоны с низким рейтингом",
                description: "\(lowRatedTemplates.count) шаблонов имеют рейтинг ниже 3.0",
                actionRecommendation: "Пересмотрите и улучшите эти шаблоны"
            ))
        }
        
        // Анализ недоиспользуемых шаблонов
        let underusedTemplates = allTemplates.filter { $0.usageCount == 0 && $0.createdAt < Calendar.current.date(byAdding: .month, value: -1, to: Date())! }
        if !underusedTemplates.isEmpty {
            insights.append(TemplateInsight(
                type: .usage,
                title: "Неиспользуемые шаблоны",
                description: "\(underusedTemplates.count) шаблонов не используются более месяца",
                actionRecommendation: "Улучшите описания или переработайте шаблоны"
            ))
        }
        
        return insights
    }
    
    // MARK: - Private Methods
    
    private func loadDefaultTemplates() async throws {
        // Проверяем, загружены ли уже базовые шаблоны
        let existingTemplates = try await getAllTemplates()
        if existingTemplates.isEmpty {
            try await createDefaultTemplates()
        }
    }
    
    private func createDefaultTemplates() async throws {
        let defaultTemplates = [
            createSoftwareProjectTemplate(),
            createMarketingCampaignTemplate(),
            createPersonalGoalTemplate(),
            createEventPlanningTemplate(),
            createLearningProjectTemplate()
        ]
        
        for template in defaultTemplates {
            try await saveTemplate(template)
        }
    }
    
    private func createSoftwareProjectTemplate() -> ProjectTemplate {
        let template = ProjectTemplate(
            name: "Разработка программного обеспечения",
            description: "Полный цикл разработки программного проекта",
            category: .software,
            isPublic: true,
            difficultyLevel: .medium
        )
        
        template.estimatedDuration = 90 * 24 * 3600 // 90 дней
        template.addTag("разработка")
        template.addTag("программирование")
        template.addTag("agile")
        
        // Добавляем фазы
        let phases = [
            ProjectPhaseTemplate(name: "Планирование", order: 0, estimatedDuration: 7 * 24 * 3600),
            ProjectPhaseTemplate(name: "Разработка", order: 1, estimatedDuration: 60 * 24 * 3600),
            ProjectPhaseTemplate(name: "Тестирование", order: 2, estimatedDuration: 14 * 24 * 3600),
            ProjectPhaseTemplate(name: "Развертывание", order: 3, estimatedDuration: 7 * 24 * 3600)
        ]
        
        for phase in phases {
            template.addPhase(phase)
        }
        
        // Добавляем задачи
        let tasks = [
            TaskTemplate(title: "Анализ требований", priority: .high, estimatedDuration: 8 * 3600),
            TaskTemplate(title: "Архитектурное планирование", priority: .high, estimatedDuration: 6 * 3600),
            TaskTemplate(title: "Настройка среды разработки", priority: .medium, estimatedDuration: 4 * 3600),
            TaskTemplate(title: "Разработка MVP", priority: .high, estimatedDuration: 40 * 3600),
            TaskTemplate(title: "Unit тестирование", priority: .medium, estimatedDuration: 16 * 3600),
            TaskTemplate(title: "Интеграционное тестирование", priority: .medium, estimatedDuration: 12 * 3600),
            TaskTemplate(title: "Развертывание в production", priority: .high, estimatedDuration: 6 * 3600)
        ]
        
        for task in tasks {
            template.addTask(task)
        }
        
        // Добавляем вехи
        let milestones = [
            MilestoneTemplate(title: "Завершение планирования", progressThreshold: 0.1),
            MilestoneTemplate(title: "MVP готов", progressThreshold: 0.5),
            MilestoneTemplate(title: "Тестирование завершено", progressThreshold: 0.8),
            MilestoneTemplate(title: "Проект запущен", progressThreshold: 1.0)
        ]
        
        for milestone in milestones {
            template.addMilestone(milestone)
        }
        
        template.updateStructureMetadata()
        
        return template
    }
    
    private func createMarketingCampaignTemplate() -> ProjectTemplate {
        let template = ProjectTemplate(
            name: "Маркетинговая кампания",
            description: "Запуск комплексной маркетинговой кампании",
            category: .marketing,
            isPublic: true,
            difficultyLevel: .easy
        )
        
        template.estimatedDuration = 30 * 24 * 3600 // 30 дней
        template.addTag("маркетинг")
        template.addTag("реклама")
        template.addTag("продвижение")
        
        return template
    }
    
    private func createPersonalGoalTemplate() -> ProjectTemplate {
        let template = ProjectTemplate(
            name: "Личная цель",
            description: "Достижение личной цели с пошаговым планом",
            category: .personal,
            isPublic: true,
            difficultyLevel: .beginner
        )
        
        template.estimatedDuration = 60 * 24 * 3600 // 60 дней
        template.addTag("личное развитие")
        template.addTag("цели")
        template.addTag("планирование")
        
        return template
    }
    
    private func createEventPlanningTemplate() -> ProjectTemplate {
        let template = ProjectTemplate(
            name: "Планирование мероприятия",
            description: "Организация и проведение мероприятия",
            category: .planning,
            isPublic: true,
            difficultyLevel: .medium
        )
        
        template.estimatedDuration = 45 * 24 * 3600 // 45 дней
        template.addTag("события")
        template.addTag("планирование")
        template.addTag("организация")
        
        return template
    }
    
    private func createLearningProjectTemplate() -> ProjectTemplate {
        let template = ProjectTemplate(
            name: "Обучающий проект",
            description: "Изучение новой области знаний или навыка",
            category: .education,
            isPublic: true,
            difficultyLevel: .easy
        )
        
        template.estimatedDuration = 90 * 24 * 3600 // 90 дней
        template.addTag("обучение")
        template.addTag("навыки")
        template.addTag("развитие")
        
        return template
    }
    
    private func updateCategoryCache() async throws {
        for category in TemplateCategory.allCases {
            let templates = try await getTemplatesForCategory(category)
            categoryCache[category] = templates
        }
    }
    
    private func syncWithCloud() async throws {
        guard let cloudService = cloudService else { return }
        
        // Синхронизируем публичные шаблоны
        try await cloudService.syncTemplates()
    }
    
    private func syncTemplateToCloud(_ template: ProjectTemplate) async throws {
        guard let cloudService = cloudService else { return }
        
        try await cloudService.uploadTemplate(template)
    }
    
    private func parseTemplateData(_ data: TemplateData) async throws -> ProjectTemplate {
        // Парсим данные шаблона из экспортированного формата
        guard let templateDict = data.templateData as? [String: Any],
              let name = templateDict["name"] as? String,
              let categoryString = templateDict["category"] as? String,
              let category = TemplateCategory(rawValue: categoryString) else {
            throw AppError.from(TemplateError.invalidFormat)
        }
        
        let template = ProjectTemplate(
            name: name,
            description: templateDict["description"] as? String,
            category: category
        )
        
        // Восстанавливаем другие свойства
        if let difficultyString = templateDict["difficultyLevel"] as? String,
           let difficultyRaw = DifficultyLevel.allCases.first(where: { $0.rawValue.description == difficultyString }) {
            template.difficultyLevel = difficultyRaw
        }
        
        template.icon = templateDict["icon"] as? String ?? category.defaultIcon
        template.color = templateDict["color"] as? String ?? category.defaultColor
        
        if let tags = templateDict["tags"] as? [String] {
            template.tags = tags
        }
        
        // Восстанавливаем структуру (фазы, задачи, вехи)
        // Это требует более сложной логики парсинга
        
        return template
    }
    
    private func calculateTemplateComplexity(_ template: ProjectTemplate) -> TemplateComplexity {
        let taskCount = template.taskCount
        let phaseCount = template.phaseCount
        let dependencies = template.defaultTasks.reduce(0) { $0 + $1.dependencyIds.count }
        
        let complexityScore = taskCount + phaseCount * 2 + dependencies
        
        switch complexityScore {
        case 0...5: return .simple
        case 6...15: return .moderate
        case 16...30: return .complex
        default: return .expert
        }
    }
    
    private func extractRequiredSkills(_ template: ProjectTemplate) -> [String] {
        var skills: Set<String> = []
        
        // Извлекаем навыки из тегов
        for tag in template.tags {
            skills.insert(tag)
        }
        
        // Добавляем навыки на основе категории
        switch template.category {
        case .software:
            skills.formUnion(["программирование", "тестирование", "архитектура"])
        case .marketing:
            skills.formUnion(["анализ", "креативность", "коммуникации"])
        case .design:
            skills.formUnion(["дизайн", "креативность", "визуализация"])
        default:
            break
        }
        
        return Array(skills)
    }
    
    private func generateTimelinePreview(_ template: ProjectTemplate) -> [TimelineItem] {
        var timeline: [TimelineItem] = []
        let startDate = Date()
        var currentDate = startDate
        
        for phase in template.phases.sorted(by: { $0.order < $1.order }) {
            timeline.append(TimelineItem(
                title: phase.name,
                date: currentDate,
                type: .phase,
                duration: phase.estimatedDuration
            ))
            
            if let duration = phase.estimatedDuration {
                currentDate = currentDate.addingTimeInterval(duration)
            }
        }
        
        for milestone in template.milestones {
            let milestoneDate = startDate.addingTimeInterval((template.estimatedDuration ?? 0) * milestone.progressThreshold)
            timeline.append(TimelineItem(
                title: milestone.title,
                date: milestoneDate,
                type: .milestone,
                duration: nil
            ))
        }
        
        return timeline.sorted { $0.date < $1.date }
    }
    
    private func getUserPreferences() async -> UserTemplatePreferences {
        // Заглушка для пользовательских предпочтений
        return UserTemplatePreferences(
            preferredCategories: [.software, .personal],
            preferredDifficulty: .medium,
            preferredDuration: .medium
        )
    }
    
    private func getUserTemplateUsage() async -> [TemplateUsageRecord] {
        // Заглушка для истории использования шаблонов
        return []
    }
    
    private func estimateGoalComplexity(_ goal: GoalHierarchy) -> TemplateComplexity {
        let projectCount = goal.projects.count
        let childGoalCount = goal.childGoals.count
        
        let complexityScore = projectCount + childGoalCount * 2
        
        switch complexityScore {
        case 0...2: return .simple
        case 3...6: return .moderate
        case 7...12: return .complex
        default: return .expert
        }
    }
    
    private func extractGoalKeywords(_ goal: GoalHierarchy) -> [String] {
        var keywords: [String] = []
        
        // Извлекаем ключевые слова из названия и описания
        keywords.append(contentsOf: goal.name.components(separatedBy: .whitespaces))
        
        if let description = goal.description {
            keywords.append(contentsOf: description.components(separatedBy: .whitespaces))
        }
        
        // Фильтруем и очищаем
        return keywords
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }
            .map { $0.lowercased() }
    }
    
    private func updateTemplateAnalytics(_ template: ProjectTemplate) async {
        await analyticsService.trackTemplateCreation(template.id)
    }
    
    private func invalidateCategoryCache(_ category: TemplateCategory) async {
        await cacheQueue.run {
            self.categoryCache.removeValue(forKey: category)
        }
    }
    
    private func calculateConversionRate(_ template: ProjectTemplate) async -> Double {
        // Заглушка для расчета конверсии (просмотры -> использования)
        return 0.15 // 15%
    }
    
    private func calculateSuccessRate(_ template: ProjectTemplate) async -> Double {
        // Заглушка для расчета успешности (завершенные проекты / общее использование)
        return 0.75 // 75%
    }
    
    private func getTopCategories() async -> [TemplateCategory] {
        // Заглушка для получения топ категорий
        return [.software, .personal, .business]
    }
    
    private func getUserFeedback(_ template: ProjectTemplate) async -> [String] {
        // Заглушка для отзывов пользователей
        return []
    }
    
    private func calculateAverageRating(_ templates: [ProjectTemplate]) -> Double {
        let ratedTemplates = templates.filter { $0.ratingCount > 0 }
        guard !ratedTemplates.isEmpty else { return 0.0 }
        
        let totalRating = ratedTemplates.reduce(0.0) { $0 + $1.rating }
        return totalRating / Double(ratedTemplates.count)
    }
    
    private func findMostPopularCategory(_ templates: [ProjectTemplate]) -> TemplateCategory? {
        let categoryUsage = Dictionary(grouping: templates) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.usageCount } }
        
        return categoryUsage.max { $0.value < $1.value }?.key
    }
}

// MARK: - Supporting Classes

class TemplateRecommendationEngine {
    func initialize() async throws {
        // Инициализация алгоритмов рекомендаций
    }
    
    func cleanup() async {
        // Очистка ресурсов
    }
    
    func getRecommendations(category: TemplateCategory?, userPreferences: UserTemplatePreferences, usageHistory: [TemplateUsageRecord]) async -> [ProjectTemplate] {
        // Алгоритм рекомендаций на основе предпочтений и истории
        return []
    }
    
    func suggestTemplatesForContext(_ context: TemplateRecommendationContext) async -> [ProjectTemplate] {
        // Рекомендации на основе контекста цели
        return []
    }
}

class TemplateValidator {
    func validate(_ template: ProjectTemplate) async -> [TemplateValidationError] {
        var errors: [TemplateValidationError] = []
        
        // Проверяем базовые поля
        if template.name.isEmpty {
            errors.append(TemplateValidationError(
                type: .missingRequiredField,
                field: "name",
                message: "Название шаблона обязательно"
            ))
        }
        
        if template.taskCount == 0 {
            errors.append(TemplateValidationError(
                type: .structureIssue,
                field: "tasks",
                message: "Шаблон должен содержать хотя бы одну задачу"
            ))
        }
        
        // Проверяем зависимости задач
        let taskIds = Set(template.defaultTasks.map { $0.id })
        for task in template.defaultTasks {
            for dependencyId in task.dependencyIds {
                if !taskIds.contains(dependencyId) {
                    errors.append(TemplateValidationError(
                        type: .invalidDependency,
                        field: "task_dependencies",
                        message: "Задача '\(task.title)' ссылается на несуществующую зависимость"
                    ))
                }
            }
        }
        
        return errors
    }
}

class TemplateSimilarityCalculator {
    func findSimilarTemplates(to template: ProjectTemplate, in templates: [ProjectTemplate], limit: Int) async -> [ProjectTemplate] {
        var similarities: [(ProjectTemplate, Double)] = []
        
        for candidateTemplate in templates {
            if candidateTemplate.id == template.id { continue }
            
            let similarity = calculateSimilarity(template, candidateTemplate)
            similarities.append((candidateTemplate, similarity))
        }
        
        return similarities
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    private func calculateSimilarity(_ template1: ProjectTemplate, _ template2: ProjectTemplate) -> Double {
        var similarity: Double = 0.0
        
        // Сходство по категории
        if template1.category == template2.category {
            similarity += 0.3
        }
        
        // Сходство по тегам
        let commonTags = Set(template1.tags).intersection(Set(template2.tags))
        let allTags = Set(template1.tags).union(Set(template2.tags))
        if !allTags.isEmpty {
            similarity += 0.2 * Double(commonTags.count) / Double(allTags.count)
        }
        
        // Сходство по сложности
        if template1.difficultyLevel == template2.difficultyLevel {
            similarity += 0.2
        }
        
        // Сходство по количеству задач
        let taskDifference = abs(template1.taskCount - template2.taskCount)
        let maxTasks = max(template1.taskCount, template2.taskCount)
        if maxTasks > 0 {
            similarity += 0.3 * (1.0 - Double(taskDifference) / Double(maxTasks))
        }
        
        return similarity
    }
}

// MARK: - Supporting Types

struct TemplateData {
    let metadata: TemplateMetadata
    let templateData: [String: Any]
}

struct TemplateMetadata {
    let version: String
    let exportDate: Date
    let appVersion: String
}

struct TemplatePreview {
    let template: ProjectTemplate
    let estimatedTasks: Int
    let estimatedPhases: Int
    let estimatedMilestones: Int
    let estimatedDuration: TimeInterval?
    let complexity: TemplateComplexity
    let requiredSkills: [String]
    let timelinePreview: [TimelineItem]
}

enum TemplateComplexity: String, CaseIterable {
    case simple = "simple"
    case moderate = "moderate"
    case complex = "complex"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .simple: return "Простой"
        case .moderate: return "Умеренный"
        case .complex: return "Сложный"
        case .expert: return "Экспертный"
        }
    }
}

struct TimelineItem {
    let title: String
    let date: Date
    let type: TimelineItemType
    let duration: TimeInterval?
}

enum TimelineItemType {
    case phase
    case milestone
    case task
}

struct TemplateValidationError {
    enum ErrorType {
        case missingRequiredField
        case invalidFormat
        case structureIssue
        case invalidDependency
    }
    
    let type: ErrorType
    let field: String
    let message: String
}

struct TemplateRecommendationContext {
    let category: TemplateCategory?
    let timeframe: GoalTimeframe
    let complexity: TemplateComplexity
    let keywords: [String]
}

struct UserTemplatePreferences {
    let preferredCategories: [TemplateCategory]
    let preferredDifficulty: DifficultyLevel
    let preferredDuration: DurationPreference
}

enum DurationPreference {
    case short // До 2 недель
    case medium // 2-8 недель
    case long // Более 8 недель
}

struct TemplateUsageRecord {
    let templateId: UUID
    let usedAt: Date
    let completed: Bool
    let rating: Double?
}

struct TemplateReview {
    let id: UUID
    let templateId: UUID
    let userId: UUID
    let rating: Double
    let comment: String?
    let createdAt: Date
}

struct TemplateAnalytics {
    let template: ProjectTemplate
    let totalUsage: Int
    let averageRating: Double
    let downloadCount: Int
    let usageOverTime: [UsageDataPoint]
    let conversionRate: Double
    let successRate: Double
    let topCategories: [TemplateCategory]
    let userFeedback: [String]
}

struct UsageDataPoint {
    let date: Date
    let usage: Int
}

struct TemplateUsageStatistics {
    let totalTemplates: Int
    let publicTemplates: Int
    let totalUsage: Int
    let averageRating: Double
    let mostPopularCategory: TemplateCategory?
    let topRatedTemplates: [ProjectTemplate]
    let mostUsedTemplates: [ProjectTemplate]
}

struct TemplateInsight {
    enum InsightType {
        case categoryTrend
        case qualityIssue
        case usage
        case performance
    }
    
    let type: InsightType
    let title: String
    let description: String
    let actionRecommendation: String
}

// MARK: - Protocol Extensions

extension Category {
    var templateCategory: TemplateCategory? {
        // Маппинг существующих категорий на категории шаблонов
        switch name.lowercased() {
        case "работа", "проект": return .business
        case "здоровье": return .health
        case "обучение", "образование": return .education
        case "личное": return .personal
        case "творчество": return .creative
        default: return nil
        }
    }
}

// MARK: - Errors

enum TemplateError: Error {
    case invalidRating
    case unauthorized
    case validationFailed([TemplateValidationError])
    case invalidFormat
    case templateNotFound
}

// MARK: - Protocols

protocol CloudServiceProtocol {
    func syncTemplates() async throws
    func uploadTemplate(_ template: ProjectTemplate) async throws
}

protocol AnalyticsServiceProtocol {
    func trackTemplateUsage(_ templateId: UUID) async
    func trackTemplateRating(_ templateId: UUID, rating: Double) async
    func trackTemplateReview(_ templateId: UUID) async
    func trackTemplatePublication(_ templateId: UUID) async
    func trackTemplateShare(_ templateId: UUID) async
    func trackTemplateImport(_ templateId: UUID) async
    func trackTemplateCreation(_ templateId: UUID) async
    func getTemplateUsageOverTime(_ templateId: UUID) async -> [UsageDataPoint]
} 