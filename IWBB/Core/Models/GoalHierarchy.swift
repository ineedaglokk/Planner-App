import Foundation
import SwiftData

// MARK: - GoalHierarchy Model

@Model
final class GoalHierarchy: CloudKitSyncable, Timestampable, Gamifiable, Categorizable, Prioritizable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var priority: Priority
    var timeframe: GoalTimeframe
    
    // Временные параметры
    var startDate: Date
    var targetDate: Date?
    var completedDate: Date?
    var isCompleted: Bool
    
    // Progress tracking
    var manualProgress: Double? // Ручной прогресс (0.0 - 1.0)
    var calculatedProgress: Double // Автоматически рассчитанный прогресс
    var progressType: HierarchyProgressType
    
    // Hierarchy level
    var level: Int // 0 = root, 1 = child, 2 = grandchild, etc.
    var maxDepth: Int // Максимальная глубина в иерархии
    
    // Visual representation
    var icon: String // SF Symbol name
    var color: String // Hex color
    var theme: GoalTheme? // Тема для визуализации
    
    // OKRs (Objectives and Key Results) support
    var isOKR: Bool // Является ли OKR
    var okrType: OKRType? // Тип OKR (Objective или Key Result)
    var keyResults: [String] // Ключевые результаты (для Objectives)
    var measurableTarget: String? // Измеримая цель
    
    // Motivation and tracking
    var motivationalQuote: String?
    var successCriteria: [String] // Критерии успеха
    var reviewFrequency: ReviewFrequency? // Частота пересмотра
    var lastReviewDate: Date?
    var nextReviewDate: Date?
    
    // Dependencies and blocking
    var isDependentOnParent: Bool // Зависит ли от родительской цели
    var blocksChildren: Bool // Блокирует ли дочерние цели
    
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
    
    // Иерархия целей
    var parentGoal: GoalHierarchy?
    @Relationship(deleteRule: .cascade, inverse: \GoalHierarchy.parentGoal) 
    var childGoals: [GoalHierarchy]
    
    // Связанные проекты и задачи
    @Relationship(deleteRule: .nullify, inverse: \Project.parentGoal) 
    var projects: [Project]
    
    // Вехи иерархии
    @Relationship(deleteRule: .cascade) 
    var milestones: [HierarchyMilestone]
    
    // Записи прогресса
    @Relationship(deleteRule: .cascade) 
    var progressEntries: [HierarchyProgressEntry]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        priority: Priority = .medium,
        timeframe: GoalTimeframe,
        targetDate: Date? = nil,
        parentGoal: GoalHierarchy? = nil,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.priority = priority
        self.timeframe = timeframe
        self.targetDate = targetDate
        self.parentGoal = parentGoal
        self.category = category
        
        // Устанавливаем уровень иерархии
        self.level = (parentGoal?.level ?? -1) + 1
        self.maxDepth = level
        
        // Статус
        self.isCompleted = false
        self.startDate = Date()
        
        // Progress
        self.calculatedProgress = 0.0
        self.progressType = .automatic
        
        // OKR
        self.isOKR = false
        self.keyResults = []
        self.successCriteria = []
        
        // Dependencies
        self.isDependentOnParent = parentGoal != nil
        self.blocksChildren = false
        
        // Visual
        self.icon = timeframe.defaultIcon
        self.color = timeframe.defaultColor
        
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
        self.childGoals = []
        self.projects = []
        self.milestones = []
        self.progressEntries = []
    }
}

// MARK: - GoalHierarchy Extensions

extension GoalHierarchy: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let target = targetDate, target <= startDate {
            throw ModelValidationError.invalidDate
        }
        
        if let manual = manualProgress, (manual < 0 || manual > 1) {
            throw ModelValidationError.missingRequiredField("Прогресс должен быть между 0 и 1")
        }
        
        if calculatedProgress < 0 || calculatedProgress > 1 {
            throw ModelValidationError.missingRequiredField("Рассчитанный прогресс должен быть между 0 и 1")
        }
        
        // Проверяем циклические зависимости
        if let parent = parentGoal {
            var current: GoalHierarchy? = parent
            while current != nil {
                if current?.id == self.id {
                    throw ModelValidationError.missingRequiredField("Обнаружена циклическая зависимость в иерархии целей")
                }
                current = current?.parentGoal
            }
        }
    }
}

extension GoalHierarchy {
    
    // MARK: - Computed Properties
    
    /// Очки за эту цель
    var points: Int {
        calculatePoints()
    }
    
    /// Финальный прогресс (ручной или автоматический)
    var finalProgress: Double {
        switch progressType {
        case .manual:
            return manualProgress ?? calculatedProgress
        case .automatic:
            return calculatedProgress
        case .hybrid:
            // Комбинируем ручной и автоматический
            let manual = manualProgress ?? 0.0
            return (manual + calculatedProgress) / 2.0
        }
    }
    
    /// Прогресс в процентах
    var progressPercentage: Int {
        return Int(finalProgress * 100)
    }
    
    /// Просрочена ли цель
    var isOverdue: Bool {
        guard let targetDate = targetDate, !isCompleted else { return false }
        return Date() > targetDate
    }
    
    /// До целевой даты осталось дней
    var daysUntilTarget: Int? {
        guard let targetDate = targetDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day
    }
    
    /// Все потомки в иерархии
    var allDescendants: [GoalHierarchy] {
        var descendants: [GoalHierarchy] = []
        for child in childGoals where !child.isArchived {
            descendants.append(child)
            descendants.append(contentsOf: child.allDescendants)
        }
        return descendants
    }
    
    /// Все предки в иерархии
    var allAncestors: [GoalHierarchy] {
        var ancestors: [GoalHierarchy] = []
        var current = parentGoal
        while let parent = current {
            ancestors.append(parent)
            current = parent.parentGoal
        }
        return ancestors
    }
    
    /// Корневая цель в иерархии
    var rootGoal: GoalHierarchy {
        var current = self
        while let parent = current.parentGoal {
            current = parent
        }
        return current
    }
    
    /// Активные дочерние цели
    var activeChildGoals: [GoalHierarchy] {
        return childGoals.filter { !$0.isArchived && !$0.isCompleted }
    }
    
    /// Завершенные дочерние цели
    var completedChildGoals: [GoalHierarchy] {
        return childGoals.filter { $0.isCompleted }
    }
    
    /// Активные проекты
    var activeProjects: [Project] {
        return projects.filter { !$0.isArchived && $0.status != .completed }
    }
    
    /// Следующая веха
    var nextMilestone: HierarchyMilestone? {
        return milestones
            .filter { !$0.isCompleted }
            .sorted { $0.targetDate < $1.targetDate }
            .first
    }
    
    /// Полный путь в иерархии
    var hierarchyPath: String {
        let ancestors = allAncestors.reversed()
        let pathComponents = ancestors.map { $0.name } + [name]
        return pathComponents.joined(separator: " → ")
    }
    
    /// Может ли быть начата (зависимости выполнены)
    var canStart: Bool {
        if !isDependentOnParent {
            return true
        }
        
        guard let parent = parentGoal else { return true }
        return parent.finalProgress >= 0.1 // Родитель должен иметь хотя бы 10% прогресса
    }
    
    /// Заблокированные дочерние цели
    var blockedChildGoals: [GoalHierarchy] {
        guard blocksChildren else { return [] }
        return childGoals.filter { !$0.canStart }
    }
    
    /// Время на достижение цели (оценка)
    var estimatedTimeToCompletion: TimeInterval? {
        guard let targetDate = targetDate, finalProgress > 0 else { return nil }
        
        let elapsed = Date().timeIntervalSince(startDate)
        let estimatedTotal = elapsed / finalProgress
        let remaining = estimatedTotal - elapsed
        
        return max(0, remaining)
    }
    
    // MARK: - Hierarchy Management
    
    /// Добавляет дочернюю цель
    func addChildGoal(_ childGoal: GoalHierarchy) {
        childGoal.parentGoal = self
        childGoal.level = level + 1
        childGoal.user = user
        childGoals.append(childGoal)
        updateMaxDepth()
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет дочернюю цель
    func removeChildGoal(_ childGoal: GoalHierarchy) {
        childGoal.parentGoal = nil
        childGoals.removeAll { $0.id == childGoal.id }
        updateMaxDepth()
        updateTimestamp()
        markForSync()
    }
    
    /// Перемещает цель в другое место иерархии
    func moveTo(newParent: GoalHierarchy?) {
        // Удаляем из текущего родителя
        parentGoal?.removeChildGoal(self)
        
        // Добавляем к новому родителю
        if let newParent = newParent {
            newParent.addChildGoal(self)
        } else {
            parentGoal = nil
            level = 0
        }
        
        // Обновляем уровни всех потомков
        updateDescendantLevels()
    }
    
    /// Обновляет уровни всех потомков
    private func updateDescendantLevels() {
        for child in childGoals {
            child.level = level + 1
            child.updateDescendantLevels()
        }
    }
    
    /// Обновляет максимальную глубину
    private func updateMaxDepth() {
        let childMaxDepth = childGoals.map { $0.maxDepth }.max() ?? level
        maxDepth = max(level, childMaxDepth)
        
        // Обновляем родительские уровни
        parentGoal?.updateMaxDepth()
    }
    
    // MARK: - Progress Management
    
    /// Обновляет прогресс цели
    func updateProgress(_ newProgress: Double, isManual: Bool = false) {
        let clampedProgress = max(0.0, min(1.0, newProgress))
        
        if isManual {
            manualProgress = clampedProgress
            progressType = .manual
        } else {
            calculatedProgress = clampedProgress
            if progressType == .automatic {
                // Автоматически созданная запись прогресса
            }
        }
        
        // Создаем запись прогресса
        let progressEntry = HierarchyProgressEntry(
            goal: self,
            previousProgress: finalProgress,
            newProgress: clampedProgress,
            isManual: isManual
        )
        progressEntries.append(progressEntry)
        
        // Проверяем завершение
        if finalProgress >= 1.0 && !isCompleted {
            markCompleted()
        }
        
        // Обновляем прогресс родительской цели
        updateParentProgress()
        
        updateTimestamp()
        markForSync()
    }
    
    /// Пересчитывает автоматический прогресс
    func recalculateProgress() {
        var totalProgress: Double = 0.0
        var totalWeight: Double = 0.0
        
        // Прогресс от дочерних целей
        for child in childGoals where !child.isArchived {
            let weight = child.priority.weight
            totalProgress += child.finalProgress * weight
            totalWeight += weight
        }
        
        // Прогресс от проектов
        for project in projects where !project.isArchived {
            let weight = project.priority.weight
            totalProgress += project.finalProgress * weight
            totalWeight += weight
        }
        
        if totalWeight > 0 {
            calculatedProgress = totalProgress / totalWeight
        } else {
            calculatedProgress = 0.0
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет прогресс родительской цели
    private func updateParentProgress() {
        parentGoal?.recalculateProgress()
    }
    
    /// Отмечает цель как завершенную
    func markCompleted() {
        isCompleted = true
        completedDate = Date()
        
        if progressType == .automatic {
            calculatedProgress = 1.0
        } else {
            manualProgress = 1.0
        }
        
        // Отмечаем все вехи как достигнутые
        for milestone in milestones where !milestone.isCompleted {
            milestone.markCompleted()
        }
        
        updateTimestamp()
        markForSync()
        
        // Обновляем родительскую цель
        updateParentProgress()
    }
    
    /// Сбрасывает прогресс цели
    func resetProgress() {
        isCompleted = false
        completedDate = nil
        calculatedProgress = 0.0
        manualProgress = nil
        progressType = .automatic
        
        // Сбрасываем все вехи
        for milestone in milestones {
            milestone.reset()
        }
        
        updateTimestamp()
        markForSync()
        
        // Обновляем родительскую цель
        updateParentProgress()
    }
    
    // MARK: - Milestone Management
    
    /// Добавляет веху
    func addMilestone(_ milestone: HierarchyMilestone) {
        milestone.goal = self
        milestones.append(milestone)
        milestones.sort { $0.targetDate < $1.targetDate }
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет веху
    func removeMilestone(_ milestone: HierarchyMilestone) {
        milestones.removeAll { $0.id == milestone.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Project Management
    
    /// Добавляет проект к цели
    func addProject(_ project: Project) {
        project.parentGoal = Goal() // Нужно будет адаптировать существующую модель Goal
        projects.append(project)
        recalculateProgress()
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет проект из цели
    func removeProject(_ project: Project) {
        project.parentGoal = nil
        projects.removeAll { $0.id == project.id }
        recalculateProgress()
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - OKR Management
    
    /// Конвертирует в OKR
    func convertToOKR(type: OKRType) {
        isOKR = true
        okrType = type
        
        if type == .objective {
            progressType = .automatic // Objectives рассчитываются автоматически
        } else {
            progressType = .manual // Key Results вводятся вручную
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Добавляет ключевой результат (для Objectives)
    func addKeyResult(_ keyResult: String) {
        guard okrType == .objective else { return }
        
        if !keyResults.contains(keyResult) {
            keyResults.append(keyResult)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет ключевой результат
    func removeKeyResult(_ keyResult: String) {
        keyResults.removeAll { $0 == keyResult }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Review Management
    
    /// Планирует следующий пересмотр
    func scheduleNextReview() {
        guard let frequency = reviewFrequency else { return }
        
        lastReviewDate = Date()
        nextReviewDate = frequency.nextDate(from: Date())
        updateTimestamp()
        markForSync()
    }
    
    /// Нужен ли пересмотр
    var needsReview: Bool {
        guard let nextReview = nextReviewDate else { return false }
        return Date() >= nextReview
    }
    
    // MARK: - Utility Methods
    
    func calculatePoints() -> Int {
        let basePoints = priority.points * timeframe.pointsMultiplier
        let progressBonus = Int(finalProgress * 500) // Больше очков за прогресс
        let completionBonus = isCompleted ? 200 : 0
        let hierarchyBonus = level * 50 // Бонус за уровень в иерархии
        let childrenBonus = completedChildGoals.count * 100
        let projectBonus = projects.filter { $0.status.isCompleted }.count * 50
        let okrBonus = isOKR ? 100 : 0
        let urgencyBonus = isOverdue ? -50 : (daysUntilTarget ?? 0 < 30 ? 50 : 0)
        
        return max(0, basePoints + progressBonus + completionBonus + hierarchyBonus + childrenBonus + projectBonus + okrBonus + urgencyBonus)
    }
}

// MARK: - HierarchyMilestone Model

@Model
final class HierarchyMilestone: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var targetDate: Date
    var progressThreshold: Double // 0.0 - 1.0
    var isCompleted: Bool
    var completedDate: Date?
    var reward: String?
    var importance: MilestoneImportance
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var goal: GoalHierarchy?
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        targetDate: Date,
        progressThreshold: Double,
        importance: MilestoneImportance = .medium,
        reward: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.progressThreshold = max(0.0, min(1.0, progressThreshold))
        self.importance = importance
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

// MARK: - HierarchyProgressEntry Model

@Model
final class HierarchyProgressEntry: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var previousProgress: Double
    var newProgress: Double
    var delta: Double
    var isManual: Bool
    var note: String?
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var goal: GoalHierarchy?
    
    // MARK: - Initializers
    
    init(
        goal: GoalHierarchy,
        previousProgress: Double,
        newProgress: Double,
        isManual: Bool = false,
        note: String? = nil
    ) {
        self.id = UUID()
        self.goal = goal
        self.previousProgress = previousProgress
        self.newProgress = newProgress
        self.delta = newProgress - previousProgress
        self.isManual = isManual
        self.note = note
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
    
    var formattedDelta: String {
        let value = abs(delta * 100)
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.1f", value))%"
    }
}

// MARK: - Supporting Enums

enum GoalTimeframe: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case lifetime = "lifetime"
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневная"
        case .weekly: return "Еженедельная"
        case .monthly: return "Месячная"
        case .quarterly: return "Квартальная"
        case .yearly: return "Годовая"
        case .lifetime: return "Жизненная"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar.day.timeline.left"
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.plus"
        case .yearly: return "clock.badge"
        case .lifetime: return "infinity"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .daily: return "#FFCC00"
        case .weekly: return "#30D158"
        case .monthly: return "#007AFF"
        case .quarterly: return "#AF52DE"
        case .yearly: return "#FF3B30"
        case .lifetime: return "#5856D6"
        }
    }
    
    var pointsMultiplier: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 3
        case .monthly: return 10
        case .quarterly: return 30
        case .yearly: return 100
        case .lifetime: return 500
        }
    }
}

enum HierarchyProgressType: String, Codable, CaseIterable {
    case manual = "manual"
    case automatic = "automatic"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .manual: return "Ручной"
        case .automatic: return "Автоматический"
        case .hybrid: return "Гибридный"
        }
    }
}

enum OKRType: String, Codable, CaseIterable {
    case objective = "objective"
    case keyResult = "key_result"
    
    var displayName: String {
        switch self {
        case .objective: return "Цель (Objective)"
        case .keyResult: return "Ключевой результат"
        }
    }
}

enum GoalTheme: String, Codable, CaseIterable {
    case minimal = "minimal"
    case colorful = "colorful"
    case dark = "dark"
    case gradient = "gradient"
    
    var displayName: String {
        switch self {
        case .minimal: return "Минималистичная"
        case .colorful: return "Яркая"
        case .dark: return "Темная"
        case .gradient: return "Градиентная"
        }
    }
}

enum ReviewFrequency: String, Codable, CaseIterable {
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .quarterly: return "Ежеквартально"
        case .yearly: return "Ежегодно"
        }
    }
    
    func nextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

enum MilestoneImportance: Int, Codable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .low: return "Низкая"
        case .medium: return "Средняя"
        case .high: return "Высокая"
        case .critical: return "Критическая"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#8E8E93"
        case .medium: return "#FFCC00"
        case .high: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }
}

// MARK: - Extensions

extension Priority {
    var weight: Double {
        switch self {
        case .low: return 1.0
        case .medium: return 2.0
        case .high: return 3.0
        case .urgent: return 4.0
        }
    }
} 