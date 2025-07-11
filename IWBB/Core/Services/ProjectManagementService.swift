import Foundation
import SwiftData

// MARK: - ProjectManagementService Protocol

protocol ProjectManagementServiceProtocol: ServiceProtocol {
    // Project CRUD
    func createProject(from template: ProjectTemplate?) async throws -> Project
    func getProject(by id: UUID) async throws -> Project?
    func getAllProjects() async throws -> [Project]
    func getActiveProjects() async throws -> [Project]
    func updateProject(_ project: Project) async throws
    func deleteProject(_ project: Project) async throws
    func archiveProject(_ project: Project) async throws
    
    // Project Progress Management
    func updateProjectProgress(_ project: Project) async throws
    func calculateProjectCompletion(_ project: Project) async -> Double
    func calculateProjectEffort(_ project: Project) async -> (estimated: TimeInterval?, actual: TimeInterval?)
    
    // Dependencies Management
    func addDependency(from: Project, to: Project) async throws
    func removeDependency(from: Project, to: Project) async throws
    func validateDependencies(_ project: Project) async throws -> [DependencyConflict]
    func getProjectSchedule(_ project: Project) async throws -> [ScheduleItem]
    func resolveScheduleConflicts(_ conflicts: [ScheduleConflict]) async throws -> [ScheduleResolution]
    
    // Templates Management
    func applyTemplate(_ template: ProjectTemplate, to project: Project) async throws
    func createTemplateFromProject(_ project: Project, name: String, isPublic: Bool) async throws -> ProjectTemplate
    func getAllTemplates() async throws -> [ProjectTemplate]
    func getRecommendedTemplates(for category: TemplateCategory?) async throws -> [ProjectTemplate]
    
    // Analytics and Insights
    func getProjectMetrics(_ project: Project) async throws -> ProjectMetrics
    func getProjectInsights(_ project: Project) async throws -> [ProjectInsight]
    func predictProjectCompletion(_ project: Project) async throws -> ProjectPrediction
    
    // Bulk Operations
    func bulkUpdateProjects(_ projects: [Project], operation: ProjectBulkOperation) async throws
    func exportProject(_ project: Project) async throws -> ProjectExportData
    func importProject(from data: ProjectExportData) async throws -> Project
}

// MARK: - ProjectManagementService Implementation

@Observable
final class ProjectManagementService: ProjectManagementServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let templateService: TemplateServiceProtocol
    
    private(set) var isInitialized: Bool = false
    
    // Analytics and caching
    private var projectMetricsCache: [UUID: ProjectMetrics] = [:]
    private var dependencyGraph: [UUID: Set<UUID>] = [:]
    private let analyticsQueue = DispatchQueue(label: "com.plannerapp.projectmanagement.analytics", qos: .utility)
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        notificationService: NotificationServiceProtocol,
        templateService: TemplateServiceProtocol
    ) {
        self.dataService = dataService
        self.notificationService = notificationService
        self.templateService = templateService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        do {
            // Инициализируем граф зависимостей
            try await buildDependencyGraph()
            
            // Проверяем и исправляем несогласованности
            try await validateAllProjectData()
            
            isInitialized = true
            
            #if DEBUG
            print("ProjectManagementService initialized successfully")
            #endif
            
        } catch {
            throw AppError.from(error)
        }
    }
    
    func cleanup() async {
        // Очищаем кэши
        projectMetricsCache.removeAll()
        dependencyGraph.removeAll()
        
        isInitialized = false
        
        #if DEBUG
        print("ProjectManagementService cleaned up")
        #endif
    }
    
    // MARK: - Project CRUD
    
    func createProject(from template: ProjectTemplate? = nil) async throws -> Project {
        let project = Project(
            name: template?.name ?? "Новый проект",
            description: template?.description,
            targetEndDate: template?.estimatedDuration.map { Date().addingTimeInterval($0) }
        )
        
        // Применяем шаблон если есть
        if let template = template {
            try await applyTemplate(template, to: project)
            template.incrementUsageCount()
        }
        
        try await dataService.save(project)
        
        // Обновляем граф зависимостей
        await updateDependencyGraph(for: project)
        
        return project
    }
    
    func getProject(by id: UUID) async throws -> Project? {
        let predicate = #Predicate<Project> { project in
            project.id == id
        }
        let projects = try await dataService.fetch(Project.self, predicate: predicate)
        return projects.first
    }
    
    func getAllProjects() async throws -> [Project] {
        return try await dataService.fetch(Project.self, predicate: nil)
    }
    
    func getActiveProjects() async throws -> [Project] {
        let predicate = #Predicate<Project> { project in
            !project.isArchived && project.status != .completed && project.status != .cancelled
        }
        return try await dataService.fetch(Project.self, predicate: predicate)
    }
    
    func updateProject(_ project: Project) async throws {
        try project.validate()
        project.updateTimestamp()
        project.markForSync()
        
        try await dataService.update(project)
        
        // Обновляем метрики
        await invalidateProjectMetrics(project.id)
        
        // Обновляем граф зависимостей
        await updateDependencyGraph(for: project)
    }
    
    func deleteProject(_ project: Project) async throws {
        // Удаляем все зависимости
        for dependency in project.dependentProjects {
            try await removeDependency(from: project, to: dependency)
        }
        
        for prerequisite in project.prerequisiteProjects {
            try await removeDependency(from: prerequisite, to: project)
        }
        
        try await dataService.delete(project)
        
        // Очищаем кэши
        await invalidateProjectMetrics(project.id)
        dependencyGraph.removeValue(forKey: project.id)
    }
    
    func archiveProject(_ project: Project) async throws {
        project.archive()
        try await updateProject(project)
    }
    
    // MARK: - Progress Management
    
    func updateProjectProgress(_ project: Project) async throws {
        let oldProgress = project.progress
        project.updateProgress()
        
        // Если прогресс значительно изменился, уведомляем
        if abs(project.progress - oldProgress) > 0.1 {
            await notifyProgressUpdate(project, oldProgress: oldProgress)
        }
        
        try await updateProject(project)
        
        // Обновляем прогресс зависимых проектов
        for dependentProject in project.dependentProjects {
            if dependentProject.canStart && dependentProject.status == .planning {
                dependentProject.start()
                try await updateProject(dependentProject)
            }
        }
    }
    
    func calculateProjectCompletion(_ project: Project) async -> Double {
        // Используем более сложную логику расчета
        let tasksProgress = project.finalProgress
        let timeProgress = project.timeProgress
        let milestonesProgress = project.milestones.isEmpty ? 1.0 : 
            Double(project.milestones.filter { $0.isCompleted }.count) / Double(project.milestones.count)
        
        // Взвешенное среднее
        return tasksProgress * 0.6 + timeProgress * 0.2 + milestonesProgress * 0.2
    }
    
    func calculateProjectEffort(_ project: Project) async -> (estimated: TimeInterval?, actual: TimeInterval?) {
        project.updateEstimatedEffort()
        project.updateActualEffort()
        
        return (estimated: project.estimatedEffort, actual: project.actualEffort)
    }
    
    // MARK: - Dependencies Management
    
    func addDependency(from sourceProject: Project, to targetProject: Project) async throws {
        // Проверяем циклические зависимости
        if await hasCyclicDependency(from: sourceProject, to: targetProject) {
            throw AppError.from(DependencyError.cyclicDependency)
        }
        
        sourceProject.addPrerequisite(targetProject)
        try await updateProject(sourceProject)
        
        // Обновляем граф зависимостей
        await updateDependencyGraph(for: sourceProject)
    }
    
    func removeDependency(from sourceProject: Project, to targetProject: Project) async throws {
        sourceProject.removePrerequisite(targetProject)
        try await updateProject(sourceProject)
        
        // Обновляем граф зависимостей
        await updateDependencyGraph(for: sourceProject)
    }
    
    func validateDependencies(_ project: Project) async throws -> [DependencyConflict] {
        var conflicts: [DependencyConflict] = []
        
        // Проверяем циклические зависимости
        for prerequisite in project.prerequisiteProjects {
            if await hasCyclicDependency(from: project, to: prerequisite) {
                conflicts.append(DependencyConflict(
                    type: .cyclicDependency,
                    sourceProject: project,
                    targetProject: prerequisite,
                    description: "Обнаружена циклическая зависимость"
                ))
            }
        }
        
        // Проверяем временные конфликты
        for prerequisite in project.prerequisiteProjects {
            if let projectStart = project.startDate,
               let prerequisiteEnd = prerequisite.actualEndDate ?? prerequisite.targetEndDate,
               projectStart < prerequisiteEnd {
                conflicts.append(DependencyConflict(
                    type: .timeConflict,
                    sourceProject: project,
                    targetProject: prerequisite,
                    description: "Проект начинается раньше завершения зависимости"
                ))
            }
        }
        
        return conflicts
    }
    
    func getProjectSchedule(_ project: Project) async throws -> [ScheduleItem] {
        var scheduleItems: [ScheduleItem] = []
        
        // Добавляем основные события проекта
        scheduleItems.append(ScheduleItem(
            id: UUID(),
            title: "Начало проекта: \(project.name)",
            date: project.startDate,
            type: .projectStart,
            project: project
        ))
        
        if let endDate = project.targetEndDate {
            scheduleItems.append(ScheduleItem(
                id: UUID(),
                title: "Планируемое завершение: \(project.name)",
                date: endDate,
                type: .projectEnd,
                project: project
            ))
        }
        
        // Добавляем вехи
        for milestone in project.milestones {
            scheduleItems.append(ScheduleItem(
                id: milestone.id,
                title: "Веха: \(milestone.title)",
                date: milestone.targetDate,
                type: .milestone,
                project: project
            ))
        }
        
        // Добавляем важные задачи с дедлайнами
        for task in project.tasks {
            if let dueDate = task.dueDate, task.priority.rawValue >= Priority.high.rawValue {
                scheduleItems.append(ScheduleItem(
                    id: task.id,
                    title: "Задача: \(task.title)",
                    date: dueDate,
                    type: .taskDeadline,
                    project: project
                ))
            }
        }
        
        return scheduleItems.sorted { $0.date < $1.date }
    }
    
    func resolveScheduleConflicts(_ conflicts: [ScheduleConflict]) async throws -> [ScheduleResolution] {
        var resolutions: [ScheduleResolution] = []
        
        for conflict in conflicts {
            switch conflict.type {
            case .overlappingDeadlines:
                // Предлагаем изменить приоритеты или сдвинуть даты
                resolutions.append(ScheduleResolution(
                    conflict: conflict,
                    strategy: .adjustPriorities,
                    description: "Изменить приоритеты задач для разрешения конфликта",
                    estimatedImpact: .low
                ))
                
            case .resourceOverallocation:
                // Предлагаем перераспределить ресурсы
                resolutions.append(ScheduleResolution(
                    conflict: conflict,
                    strategy: .redistributeResources,
                    description: "Перераспределить ресурсы между проектами",
                    estimatedImpact: .medium
                ))
                
            case .dependencyViolation:
                // Предлагаем пересмотреть зависимости
                resolutions.append(ScheduleResolution(
                    conflict: conflict,
                    strategy: .adjustDependencies,
                    description: "Пересмотреть зависимости проекта",
                    estimatedImpact: .high
                ))
            }
        }
        
        return resolutions
    }
    
    // MARK: - Templates Management
    
    func applyTemplate(_ template: ProjectTemplate, to project: Project) async throws {
        try await analyticsQueue.run {
            project.applyTemplate(template)
        }
        
        template.incrementUsageCount()
        try await templateService.updateTemplate(template)
    }
    
    func createTemplateFromProject(_ project: Project, name: String, isPublic: Bool) async throws -> ProjectTemplate {
        let template = ProjectTemplate(
            name: name,
            description: project.description,
            category: .planning, // Можно определить автоматически на основе данных
            isPublic: isPublic
        )
        
        template.estimatedDuration = project.estimatedEffort
        template.icon = project.icon
        template.color = project.color
        
        // Создаем фазы из проекта
        for phase in project.phases {
            let phaseTemplate = ProjectPhaseTemplate(
                name: phase.name,
                description: phase.description,
                order: phase.order,
                estimatedDuration: phase.estimatedDuration
            )
            template.addPhase(phaseTemplate)
        }
        
        // Создаем задачи из проекта
        for task in project.tasks {
            let taskTemplate = TaskTemplate(
                title: task.title,
                description: task.description,
                priority: task.priority,
                estimatedDuration: task.estimatedDuration
            )
            
            if let phase = task.phase {
                taskTemplate.phaseId = phase.templatePhaseId
            }
            
            template.addTask(taskTemplate)
        }
        
        // Создаем вехи
        for milestone in project.milestones {
            let milestoneTemplate = MilestoneTemplate(
                title: milestone.title,
                description: milestone.description,
                progressThreshold: milestone.progressThreshold,
                reward: milestone.reward
            )
            template.addMilestone(milestoneTemplate)
        }
        
        template.updateStructureMetadata()
        try await templateService.saveTemplate(template)
        
        return template
    }
    
    func getAllTemplates() async throws -> [ProjectTemplate] {
        return try await templateService.getAllTemplates()
    }
    
    func getRecommendedTemplates(for category: TemplateCategory?) async throws -> [ProjectTemplate] {
        return try await templateService.getRecommendedTemplates(for: category)
    }
    
    // MARK: - Analytics and Insights
    
    func getProjectMetrics(_ project: Project) async throws -> ProjectMetrics {
        // Проверяем кэш
        if let cachedMetrics = projectMetricsCache[project.id] {
            return cachedMetrics
        }
        
        let metrics = await analyticsQueue.run {
            return ProjectMetrics(
                project: project,
                completionRate: project.finalProgress,
                timeUtilization: calculateTimeUtilization(project),
                taskVelocity: calculateTaskVelocity(project),
                qualityScore: calculateQualityScore(project),
                riskScore: calculateRiskScore(project),
                teamProductivity: calculateTeamProductivity(project),
                budgetUtilization: calculateBudgetUtilization(project),
                stakeholderSatisfaction: calculateStakeholderSatisfaction(project)
            )
        }
        
        // Кэшируем результат
        projectMetricsCache[project.id] = metrics
        
        return metrics
    }
    
    func getProjectInsights(_ project: Project) async throws -> [ProjectInsight] {
        let metrics = try await getProjectMetrics(project)
        var insights: [ProjectInsight] = []
        
        // Анализируем прогресс
        if metrics.completionRate < 0.5 && project.daysUntilTarget ?? 0 < 30 {
            insights.append(ProjectInsight(
                type: .warning,
                title: "Проект может не уложиться в срок",
                description: "Текущий прогресс отстает от планового",
                actionRecommendation: "Рассмотрите возможность увеличения ресурсов или пересмотра сроков",
                priority: .high
            ))
        }
        
        // Анализируем загрузку
        if metrics.timeUtilization > 1.2 {
            insights.append(ProjectInsight(
                type: .warning,
                title: "Превышение планируемого времени",
                description: "Фактическое время превышает запланированное на 20%",
                actionRecommendation: "Проанализируйте причины и скорректируйте планы",
                priority: .medium
            ))
        }
        
        // Анализируем качество
        if metrics.qualityScore < 0.7 {
            insights.append(ProjectInsight(
                type: .improvement,
                title: "Возможности для улучшения качества",
                description: "Показатели качества ниже целевых",
                actionRecommendation: "Внедрите дополнительные проверки качества",
                priority: .medium
            ))
        }
        
        return insights
    }
    
    func predictProjectCompletion(_ project: Project) async throws -> ProjectPrediction {
        let currentProgress = project.finalProgress
        let elapsedTime = Date().timeIntervalSince(project.startDate)
        
        // Простая линейная экстраполяция (можно улучшить с ML)
        let estimatedTotalTime = currentProgress > 0 ? elapsedTime / currentProgress : elapsedTime * 2
        let remainingTime = estimatedTotalTime - elapsedTime
        let predictedCompletionDate = Date().addingTimeInterval(remainingTime)
        
        let confidence = calculatePredictionConfidence(project)
        let riskFactors = await identifyRiskFactors(project)
        
        return ProjectPrediction(
            project: project,
            predictedCompletionDate: predictedCompletionDate,
            confidence: confidence,
            riskFactors: riskFactors,
            assumptions: [
                "Текущая скорость работы сохранится",
                "Не возникнет дополнительных блокеров",
                "Ресурсы останутся доступными"
            ]
        )
    }
    
    // MARK: - Bulk Operations
    
    func bulkUpdateProjects(_ projects: [Project], operation: ProjectBulkOperation) async throws {
        switch operation {
        case .updateStatus(let status):
            for project in projects {
                project.status = status
                try await updateProject(project)
            }
            
        case .updatePriority(let priority):
            for project in projects {
                project.priority = priority
                try await updateProject(project)
            }
            
        case .assignCategory(let category):
            for project in projects {
                project.category = category
                try await updateProject(project)
            }
            
        case .archive:
            for project in projects {
                try await archiveProject(project)
            }
            
        case .delete:
            for project in projects {
                try await deleteProject(project)
            }
        }
    }
    
    func exportProject(_ project: Project) async throws -> ProjectExportData {
        return ProjectExportData(
            project: project,
            tasks: project.tasks,
            milestones: project.milestones,
            phases: project.phases,
            timeBlocks: project.timeBlocks,
            metadata: ProjectExportMetadata(
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                formatVersion: "1.0"
            )
        )
    }
    
    func importProject(from data: ProjectExportData) async throws -> Project {
        // Создаем новый проект
        let project = Project(
            name: data.project.name,
            description: data.project.description,
            priority: data.project.priority,
            targetEndDate: data.project.targetEndDate
        )
        
        project.estimatedEffort = data.project.estimatedEffort
        project.icon = data.project.icon
        project.color = data.project.color
        
        try await dataService.save(project)
        
        // Импортируем фазы
        for phaseData in data.phases {
            let phase = ProjectPhase(
                name: phaseData.name,
                description: phaseData.description,
                order: phaseData.order,
                estimatedDuration: phaseData.estimatedDuration
            )
            project.addPhase(phase)
        }
        
        // Импортируем задачи
        for taskData in data.tasks {
            let task = ProjectTask(
                title: taskData.title,
                description: taskData.description,
                priority: taskData.priority,
                estimatedDuration: taskData.estimatedDuration,
                project: project
            )
            project.addTask(task)
        }
        
        // Импортируем вехи
        for milestoneData in data.milestones {
            let milestone = ProjectMilestone(
                title: milestoneData.title,
                description: milestoneData.description,
                targetDate: milestoneData.targetDate,
                progressThreshold: milestoneData.progressThreshold,
                reward: milestoneData.reward
            )
            project.addMilestone(milestone)
        }
        
        try await updateProject(project)
        
        return project
    }
    
    // MARK: - Private Methods
    
    private func buildDependencyGraph() async throws {
        let projects = try await getAllProjects()
        
        for project in projects {
            var dependencies = Set<UUID>()
            for prerequisite in project.prerequisiteProjects {
                dependencies.insert(prerequisite.id)
            }
            dependencyGraph[project.id] = dependencies
        }
    }
    
    private func updateDependencyGraph(for project: Project) async {
        var dependencies = Set<UUID>()
        for prerequisite in project.prerequisiteProjects {
            dependencies.insert(prerequisite.id)
        }
        dependencyGraph[project.id] = dependencies
    }
    
    private func hasCyclicDependency(from sourceProject: Project, to targetProject: Project) async -> Bool {
        // Используем DFS для поиска циклов
        var visited = Set<UUID>()
        var recursionStack = Set<UUID>()
        
        func hasCycle(_ projectId: UUID) -> Bool {
            if recursionStack.contains(projectId) {
                return true
            }
            
            if visited.contains(projectId) {
                return false
            }
            
            visited.insert(projectId)
            recursionStack.insert(projectId)
            
            if let dependencies = dependencyGraph[projectId] {
                for dependencyId in dependencies {
                    if hasCycle(dependencyId) {
                        return true
                    }
                }
            }
            
            recursionStack.remove(projectId)
            return false
        }
        
        // Симулируем добавление зависимости
        var tempGraph = dependencyGraph
        if tempGraph[sourceProject.id] == nil {
            tempGraph[sourceProject.id] = Set<UUID>()
        }
        tempGraph[sourceProject.id]?.insert(targetProject.id)
        
        // Временно обновляем граф для проверки
        let originalDependencies = dependencyGraph[sourceProject.id]
        dependencyGraph[sourceProject.id] = tempGraph[sourceProject.id]
        
        let hasCycle = hasCycle(sourceProject.id)
        
        // Восстанавливаем граф
        dependencyGraph[sourceProject.id] = originalDependencies
        
        return hasCycle
    }
    
    private func validateAllProjectData() async throws {
        let projects = try await getAllProjects()
        
        for project in projects {
            // Проверяем целостность данных
            try project.validate()
            
            // Проверяем зависимости
            let conflicts = try await validateDependencies(project)
            if !conflicts.isEmpty {
                #if DEBUG
                print("Found dependency conflicts in project \(project.name): \(conflicts)")
                #endif
            }
        }
    }
    
    private func invalidateProjectMetrics(_ projectId: UUID) async {
        projectMetricsCache.removeValue(forKey: projectId)
    }
    
    private func notifyProgressUpdate(_ project: Project, oldProgress: Double) async {
        // Отправляем уведомление о значительном изменении прогресса
        let progressChange = Int((project.progress - oldProgress) * 100)
        let message = "Прогресс проекта '\(project.name)' изменился на \(progressChange)%"
        
        // Здесь можно добавить логику уведомлений
        #if DEBUG
        print(message)
        #endif
    }
    
    // Analytics helper methods
    private func calculateTimeUtilization(_ project: Project) -> Double {
        guard let estimated = project.estimatedEffort, let actual = project.actualEffort else { return 1.0 }
        return actual / estimated
    }
    
    private func calculateTaskVelocity(_ project: Project) -> Double {
        let completedTasks = project.completedTasks.count
        let elapsedDays = max(1, Calendar.current.dateComponents([.day], from: project.startDate, to: Date()).day ?? 1)
        return Double(completedTasks) / Double(elapsedDays)
    }
    
    private func calculateQualityScore(_ project: Project) -> Double {
        // Простая метрика качества на основе выполненных задач без переделок
        let totalTasks = project.tasks.count
        guard totalTasks > 0 else { return 1.0 }
        
        let qualityTasks = project.tasks.filter { task in
            // Считаем задачу качественной если она выполнена в срок и без переделок
            task.status.isCompleted && !task.isOverdue
        }.count
        
        return Double(qualityTasks) / Double(totalTasks)
    }
    
    private func calculateRiskScore(_ project: Project) -> Double {
        var riskFactors: Double = 0
        
        // Фактор времени
        if project.isOverdue { riskFactors += 0.3 }
        else if (project.daysUntilTarget ?? 0) < 7 { riskFactors += 0.2 }
        
        // Фактор прогресса
        if project.finalProgress < 0.5 && (project.daysUntilTarget ?? 0) < 30 { riskFactors += 0.3 }
        
        // Фактор зависимостей
        let blockedTasks = project.tasks.filter { !$0.canStart }.count
        if blockedTasks > 0 { riskFactors += 0.2 }
        
        // Фактор ресурсов
        if let utilization = projectMetricsCache[project.id]?.timeUtilization, utilization > 1.5 {
            riskFactors += 0.2
        }
        
        return min(1.0, riskFactors)
    }
    
    private func calculateTeamProductivity(_ project: Project) -> Double {
        // Простая метрика производительности
        let velocity = calculateTaskVelocity(project)
        let baseline = 1.0 // Базовая скорость 1 задача в день
        return velocity / baseline
    }
    
    private func calculateBudgetUtilization(_ project: Project) -> Double {
        // Заглушка для будущей реализации бюджетного учета
        return 1.0
    }
    
    private func calculateStakeholderSatisfaction(_ project: Project) -> Double {
        // Заглушка для будущей реализации оценки удовлетворенности
        return 0.8
    }
    
    private func calculatePredictionConfidence(_ project: Project) -> Double {
        var confidence: Double = 0.5 // Базовый уровень
        
        // Увеличиваем уверенность на основе данных
        if project.finalProgress > 0.3 { confidence += 0.2 }
        if project.tasks.count > 10 { confidence += 0.1 }
        if !project.isOverdue { confidence += 0.1 }
        
        // Уменьшаем уверенность для рискованных проектов
        let riskScore = calculateRiskScore(project)
        confidence -= riskScore * 0.3
        
        return max(0.1, min(1.0, confidence))
    }
    
    private func identifyRiskFactors(_ project: Project) async -> [RiskFactor] {
        var risks: [RiskFactor] = []
        
        if project.isOverdue {
            risks.append(RiskFactor(
                type: .schedule,
                severity: .high,
                description: "Проект просрочен",
                impact: "Возможны дополнительные задержки"
            ))
        }
        
        if project.overdueTasks.count > 0 {
            risks.append(RiskFactor(
                type: .task,
                severity: .medium,
                description: "\(project.overdueTasks.count) просроченных задач",
                impact: "Может повлиять на общий график"
            ))
        }
        
        let blockedTasks = project.tasks.filter { !$0.canStart }.count
        if blockedTasks > 0 {
            risks.append(RiskFactor(
                type: .dependency,
                severity: .medium,
                description: "\(blockedTasks) заблокированных задач",
                impact: "Снижает скорость выполнения"
            ))
        }
        
        return risks
    }
}

// MARK: - Supporting Types

struct DependencyConflict {
    enum ConflictType {
        case cyclicDependency
        case timeConflict
        case resourceConflict
    }
    
    let type: ConflictType
    let sourceProject: Project
    let targetProject: Project
    let description: String
}

struct ScheduleItem {
    let id: UUID
    let title: String
    let date: Date
    let type: ScheduleItemType
    let project: Project
}

enum ScheduleItemType {
    case projectStart
    case projectEnd
    case milestone
    case taskDeadline
    case phaseTransition
}

struct ScheduleConflict {
    enum ConflictType {
        case overlappingDeadlines
        case resourceOverallocation
        case dependencyViolation
    }
    
    let type: ConflictType
    let description: String
    let affectedProjects: [Project]
}

struct ScheduleResolution {
    enum ResolutionStrategy {
        case adjustPriorities
        case redistributeResources
        case adjustDependencies
        case extendDeadlines
    }
    
    enum Impact {
        case low
        case medium
        case high
    }
    
    let conflict: ScheduleConflict
    let strategy: ResolutionStrategy
    let description: String
    let estimatedImpact: Impact
}

enum ProjectBulkOperation {
    case updateStatus(ProjectStatus)
    case updatePriority(Priority)
    case assignCategory(Category)
    case archive
    case delete
}

struct ProjectExportData {
    let project: Project
    let tasks: [ProjectTask]
    let milestones: [ProjectMilestone]
    let phases: [ProjectPhase]
    let timeBlocks: [TimeBlock]
    let metadata: ProjectExportMetadata
}

struct ProjectExportMetadata {
    let exportDate: Date
    let appVersion: String
    let formatVersion: String
}

struct ProjectMetrics {
    let project: Project
    let completionRate: Double
    let timeUtilization: Double
    let taskVelocity: Double
    let qualityScore: Double
    let riskScore: Double
    let teamProductivity: Double
    let budgetUtilization: Double
    let stakeholderSatisfaction: Double
}

struct ProjectInsight {
    enum InsightType {
        case warning
        case improvement
        case success
        case information
    }
    
    enum InsightPriority {
        case low
        case medium
        case high
        case critical
    }
    
    let type: InsightType
    let title: String
    let description: String
    let actionRecommendation: String
    let priority: InsightPriority
}

struct ProjectPrediction {
    let project: Project
    let predictedCompletionDate: Date
    let confidence: Double // 0.0 - 1.0
    let riskFactors: [RiskFactor]
    let assumptions: [String]
}

struct RiskFactor {
    enum RiskType {
        case schedule
        case resource
        case quality
        case dependency
        case external
        case task
    }
    
    enum RiskSeverity {
        case low
        case medium
        case high
        case critical
    }
    
    let type: RiskType
    let severity: RiskSeverity
    let description: String
    let impact: String
}

enum DependencyError: Error {
    case cyclicDependency
    case invalidDependency
    case dependencyNotFound
} 