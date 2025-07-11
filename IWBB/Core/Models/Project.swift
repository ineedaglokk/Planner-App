import Foundation
import SwiftData

// MARK: - Project Model

@Model
final class Project: CloudKitSyncable, Timestampable, Gamifiable, Categorizable, Prioritizable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var priority: Priority
    var status: ProjectStatus
    
    // Временные параметры
    var startDate: Date
    var targetEndDate: Date?
    var actualEndDate: Date?
    var lastWorkedDate: Date?
    
    // Effort tracking
    var estimatedEffort: TimeInterval? // Общее расчетное время в секундах
    var actualEffort: TimeInterval? // Фактическое время
    var remainingEffort: TimeInterval? // Оставшееся время
    
    // Прогресс
    var progress: Double // 0.0 - 1.0, автоматически рассчитывается
    var manualProgress: Double? // Ручной прогресс, переопределяет автоматический
    
    // Template association
    var templateId: UUID? // ID шаблона, из которого создан проект
    var templateName: String? // Название шаблона для истории
    
    // Визуализация
    var icon: String // SF Symbol name
    var color: String // Hex color
    
    // Архивация
    var isArchived: Bool
    var archivedAt: Date?
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var category: Category?
    var parentGoal: Goal? // Связь с целью
    
    // Задачи проекта
    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project) 
    var tasks: [ProjectTask]
    
    // Time blocks
    @Relationship(deleteRule: .cascade, inverse: \TimeBlock.project) 
    var timeBlocks: [TimeBlock]
    
    // Вехи проекта
    @Relationship(deleteRule: .cascade) 
    var milestones: [ProjectMilestone]
    
    // Зависимости между проектами
    @Relationship(inverse: \Project.dependentProjects) var prerequisiteProjects: [Project]
    @Relationship(inverse: \Project.prerequisiteProjects) var dependentProjects: [Project]
    
    // Фазы проекта
    @Relationship(deleteRule: .cascade) 
    var phases: [ProjectPhase]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        priority: Priority = .medium,
        targetEndDate: Date? = nil,
        parentGoal: Goal? = nil,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.priority = priority
        self.status = .planning
        self.startDate = Date()
        self.targetEndDate = targetEndDate
        self.parentGoal = parentGoal
        self.category = category
        
        // Progress
        self.progress = 0.0
        
        // Visual
        self.icon = "folder.circle"
        self.color = "#007AFF"
        
        // Архивация
        self.isArchived = false
        self.archivedAt = nil
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        // Relationships
        self.tasks = []
        self.timeBlocks = []
        self.milestones = []
        self.prerequisiteProjects = []
        self.dependentProjects = []
        self.phases = []
    }
}

// MARK: - Project Extensions

extension Project: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let target = targetEndDate, target <= startDate {
            throw ModelValidationError.invalidDate
        }
        
        if let estimated = estimatedEffort, estimated < 0 {
            throw ModelValidationError.missingRequiredField("Расчетное время не может быть отрицательным")
        }
    }
}

extension Project {
    
    // MARK: - Computed Properties
    
    /// Очки за этот проект
    var points: Int {
        calculatePoints()
    }
    
    /// Автоматически рассчитанный прогресс на основе задач
    var calculatedProgress: Double {
        guard !tasks.isEmpty else { return 0.0 }
        
        let completedTasks = tasks.filter { $0.status.isCompleted }.count
        return Double(completedTasks) / Double(tasks.count)
    }
    
    /// Финальный прогресс (ручной или автоматический)
    var finalProgress: Double {
        return manualProgress ?? calculatedProgress
    }
    
    /// Просрочен ли проект
    var isOverdue: Bool {
        guard let targetDate = targetEndDate, !status.isCompleted else { return false }
        return Date() > targetDate
    }
    
    /// До целевой даты осталось дней
    var daysUntilTarget: Int? {
        guard let targetDate = targetEndDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day
    }
    
    /// Активные задачи проекта
    var activeTasks: [ProjectTask] {
        return tasks.filter { !$0.isArchived && $0.status != .completed && $0.status != .cancelled }
    }
    
    /// Выполненные задачи проекта
    var completedTasks: [ProjectTask] {
        return tasks.filter { $0.status.isCompleted }
    }
    
    /// Просроченные задачи проекта
    var overdueTasks: [ProjectTask] {
        return tasks.filter { $0.isOverdue }
    }
    
    /// Ближайшие дедлайны (в следующие 7 дней)
    var upcomingDeadlines: [ProjectTask] {
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= weekFromNow && dueDate >= Date() && !task.status.isCompleted
        }.sorted { $0.dueDate! < $1.dueDate! }
    }
    
    /// Следующая веха
    var nextMilestone: ProjectMilestone? {
        return milestones
            .filter { !$0.isCompleted }
            .sorted { $0.targetDate < $1.targetDate }
            .first
    }
    
    /// Текущая фаза проекта
    var currentPhase: ProjectPhase? {
        return phases
            .filter { $0.status == .active }
            .first
    }
    
    /// Можно ли начать проект (все dependencies выполнены)
    var canStart: Bool {
        return prerequisiteProjects.allSatisfy { $0.status.isCompleted }
    }
    
    /// Заблокированные проекты (зависящие от этого)
    var blockedProjects: [Project] {
        return dependentProjects.filter { !$0.canStart }
    }
    
    /// Общая продолжительность проекта
    var totalDuration: TimeInterval? {
        guard let endDate = actualEndDate ?? targetEndDate else { return nil }
        return endDate.timeIntervalSince(startDate)
    }
    
    /// Прогресс по времени (как долго проект выполняется)
    var timeProgress: Double {
        guard let targetEndDate = targetEndDate else { return 0.0 }
        
        let totalDuration = targetEndDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        
        return min(elapsed / totalDuration, 1.0)
    }
    
    // MARK: - Project Management
    
    /// Начинает проект
    func start() {
        guard canStart else { return }
        
        status = .active
        lastWorkedDate = Date()
        updateTimestamp()
        markForSync()
        
        // Активируем первую фазу если есть
        if let firstPhase = phases.sorted(by: { $0.order < $1.order }).first {
            firstPhase.activate()
        }
    }
    
    /// Завершает проект
    func complete() {
        status = .completed
        actualEndDate = Date()
        progress = 1.0
        updateTimestamp()
        markForSync()
        
        // Завершаем все незавершенные задачи
        for task in activeTasks {
            task.markCompleted()
        }
        
        // Завершаем все фазы
        for phase in phases {
            if phase.status != .completed {
                phase.complete()
            }
        }
    }
    
    /// Приостанавливает проект
    func pause() {
        status = .onHold
        updateTimestamp()
        markForSync()
    }
    
    /// Отменяет проект
    func cancel() {
        status = .cancelled
        updateTimestamp()
        markForSync()
        
        // Отменяем все активные задачи
        for task in activeTasks {
            task.cancel()
        }
    }
    
    /// Перезапускает проект
    func restart() {
        status = .active
        actualEndDate = nil
        lastWorkedDate = Date()
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Task Management
    
    /// Добавляет задачу к проекту
    func addTask(_ task: ProjectTask) {
        task.project = self
        tasks.append(task)
        updateProgress()
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет задачу из проекта
    func removeTask(_ task: ProjectTask) {
        tasks.removeAll { $0.id == task.id }
        updateProgress()
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет прогресс проекта
    func updateProgress() {
        let newProgress = calculatedProgress
        if abs(progress - newProgress) > 0.01 {
            progress = newProgress
            updateTimestamp()
            markForSync()
            
            // Проверяем вехи
            checkMilestones()
            
            // Если проект завершен
            if progress >= 1.0 && status != .completed {
                complete()
            }
        }
    }
    
    // MARK: - Milestone Management
    
    /// Добавляет веху
    func addMilestone(_ milestone: ProjectMilestone) {
        milestone.project = self
        milestones.append(milestone)
        milestones.sort { $0.targetDate < $1.targetDate }
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет веху
    func removeMilestone(_ milestone: ProjectMilestone) {
        milestones.removeAll { $0.id == milestone.id }
        updateTimestamp()
        markForSync()
    }
    
    /// Проверяет и обновляет статус вех
    private func checkMilestones() {
        for milestone in milestones where !milestone.isCompleted {
            if finalProgress >= milestone.progressThreshold {
                milestone.markCompleted()
            }
        }
    }
    
    // MARK: - Phase Management
    
    /// Добавляет фазу
    func addPhase(_ phase: ProjectPhase) {
        phase.project = self
        phases.append(phase)
        phases.sort { $0.order < $1.order }
        updateTimestamp()
        markForSync()
    }
    
    /// Переходит к следующей фазе
    func moveToNextPhase() {
        guard let currentPhase = currentPhase else { return }
        
        currentPhase.complete()
        
        // Активируем следующую фазу
        if let nextPhase = phases.first(where: { $0.order > currentPhase.order && $0.status == .pending }) {
            nextPhase.activate()
        }
    }
    
    // MARK: - Dependency Management
    
    /// Добавляет зависимость (этот проект зависит от другого)
    func addPrerequisite(_ project: Project) {
        guard project.id != self.id else { return } // Предотвращаем зависимость от самого себя
        
        if !prerequisiteProjects.contains(where: { $0.id == project.id }) {
            prerequisiteProjects.append(project)
            project.dependentProjects.append(self)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет зависимость
    func removePrerequisite(_ project: Project) {
        prerequisiteProjects.removeAll { $0.id == project.id }
        project.dependentProjects.removeAll { $0.id == self.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Time Tracking
    
    /// Обновляет фактическое время выполнения
    func updateActualEffort() {
        actualEffort = tasks.compactMap { $0.actualDuration }.reduce(0, +)
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет оставшееся время
    func updateRemainingEffort() {
        guard let estimated = estimatedEffort else {
            remainingEffort = nil
            return
        }
        
        let actual = actualEffort ?? 0
        remainingEffort = max(0, estimated - actual)
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет расчетное время на основе задач
    func updateEstimatedEffort() {
        estimatedEffort = tasks.compactMap { $0.estimatedDuration }.reduce(0, +)
        updateRemainingEffort()
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Template Methods
    
    /// Применяет шаблон к проекту
    func applyTemplate(_ template: ProjectTemplate) {
        templateId = template.id
        templateName = template.name
        
        // Применяем базовые свойства
        if description?.isEmpty != false {
            description = template.description
        }
        
        if estimatedEffort == nil {
            estimatedEffort = template.estimatedDuration
        }
        
        // Создаем фазы из шаблона
        for phaseTemplate in template.phases {
            let phase = ProjectPhase(
                name: phaseTemplate.name,
                description: phaseTemplate.description,
                order: phaseTemplate.order,
                estimatedDuration: phaseTemplate.estimatedDuration
            )
            addPhase(phase)
        }
        
        // Создаем задачи из шаблона
        for taskTemplate in template.defaultTasks {
            let task = ProjectTask(
                title: taskTemplate.title,
                description: taskTemplate.description,
                priority: taskTemplate.priority,
                estimatedDuration: taskTemplate.estimatedDuration,
                project: self
            )
            
            if let phaseId = taskTemplate.phaseId {
                task.phase = phases.first { $0.templatePhaseId == phaseId }
            }
            
            addTask(task)
        }
        
        updateTimestamp()
        markForSync()
    }
    
    func calculatePoints() -> Int {
        let basePoints = priority.points * 5 // Проекты дают больше очков
        let progressBonus = Int(finalProgress * 200)
        let completionBonus = status.isCompleted ? 100 : 0
        let milestoneBonus = milestones.filter { $0.isCompleted }.count * 20
        let sizeBonus = tasks.count * 2
        let urgencyBonus = isOverdue ? -20 : (daysUntilTarget ?? 0 < 7 ? 25 : 0)
        
        return max(0, basePoints + progressBonus + completionBonus + milestoneBonus + sizeBonus + urgencyBonus)
    }
}

// MARK: - ProjectStatus

enum ProjectStatus: String, Codable, CaseIterable {
    case planning = "planning"
    case active = "active"
    case onHold = "on_hold"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .planning: return "Планирование"
        case .active: return "Активный"
        case .onHold: return "Приостановлен"
        case .completed: return "Завершен"
        case .cancelled: return "Отменен"
        }
    }
    
    var isCompleted: Bool {
        return self == .completed
    }
    
    var canTransitionTo: [ProjectStatus] {
        switch self {
        case .planning:
            return [.active, .cancelled]
        case .active:
            return [.onHold, .completed, .cancelled]
        case .onHold:
            return [.active, .cancelled]
        case .completed:
            return [.active] // Можно переоткрыть
        case .cancelled:
            return [.planning, .active]
        }
    }
    
    var systemImageName: String {
        switch self {
        case .planning: return "pencil.circle"
        case .active: return "play.circle.fill"
        case .onHold: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

// MARK: - ProjectMilestone Model

@Model
final class ProjectMilestone: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var targetDate: Date
    var progressThreshold: Double // 0.0 - 1.0, при каком прогрессе считается достигнутой
    var isCompleted: Bool
    var completedDate: Date?
    var reward: String? // Описание награды за достижение вехи
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var project: Project?
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        targetDate: Date,
        progressThreshold: Double,
        reward: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.progressThreshold = max(0.0, min(1.0, progressThreshold))
        self.isCompleted = false
        self.reward = reward
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
    
    func markCompleted() {
        isCompleted = true
        completedDate = Date()
        updateTimestamp()
        markForSync()
    }
    
    func reset() {
        isCompleted = false
        completedDate = nil
        updateTimestamp()
        markForSync()
    }
}

// MARK: - ProjectPhase Model

@Model
final class ProjectPhase: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var order: Int // Порядок фазы в проекте
    var status: PhaseStatus
    var startDate: Date?
    var endDate: Date?
    var estimatedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var templatePhaseId: UUID? // ID фазы в шаблоне
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var project: Project?
    @Relationship(inverse: \ProjectTask.phase) var tasks: [ProjectTask]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        order: Int,
        estimatedDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.order = order
        self.status = .pending
        self.estimatedDuration = estimatedDuration
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        // Relationships
        self.tasks = []
    }
    
    var progress: Double {
        guard !tasks.isEmpty else { return 0.0 }
        let completedTasks = tasks.filter { $0.status.isCompleted }.count
        return Double(completedTasks) / Double(tasks.count)
    }
    
    func activate() {
        status = .active
        startDate = Date()
        updateTimestamp()
        markForSync()
    }
    
    func complete() {
        status = .completed
        endDate = Date()
        if let start = startDate {
            actualDuration = Date().timeIntervalSince(start)
        }
        updateTimestamp()
        markForSync()
    }
}

enum PhaseStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидает"
        case .active: return "Активная"
        case .completed: return "Завершена"
        case .cancelled: return "Отменена"
        }
    }
} 