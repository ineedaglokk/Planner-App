import Foundation
import SwiftData

// MARK: - ProjectTemplate Model

@Model
final class ProjectTemplate: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var category: TemplateCategory
    var isPublic: Bool // Доступен другим пользователям
    var usageCount: Int // Количество использований
    var rating: Double // Средняя оценка (0.0 - 5.0)
    var ratingCount: Int // Количество оценок
    
    // Template properties
    var estimatedDuration: TimeInterval? // Общее расчетное время
    var difficultyLevel: DifficultyLevel
    var tags: [String] // Теги для поиска
    
    // Visual
    var icon: String // SF Symbol name
    var color: String // Hex color
    
    // Template structure metadata
    var phaseCount: Int // Количество фаз
    var taskCount: Int // Количество задач
    var milestoneCount: Int // Количество вех
    
    // Community features
    var authorId: UUID? // ID автора (для публичных шаблонов)
    var authorName: String? // Имя автора
    var downloadCount: Int // Количество скачиваний
    var lastUpdatedVersion: String? // Версия последнего обновления
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User? // Создатель шаблона
    
    // Template structure
    @Relationship(deleteRule: .cascade) 
    var phases: [ProjectPhaseTemplate]
    
    @Relationship(deleteRule: .cascade) 
    var defaultTasks: [TaskTemplate]
    
    @Relationship(deleteRule: .cascade) 
    var milestones: [MilestoneTemplate]
    
    @Relationship(deleteRule: .cascade) 
    var suggestedTimeBlocks: [TimeBlockTemplate]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        category: TemplateCategory,
        isPublic: Bool = false,
        difficultyLevel: DifficultyLevel = .medium
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.isPublic = isPublic
        self.difficultyLevel = difficultyLevel
        
        // Stats
        self.usageCount = 0
        self.rating = 0.0
        self.ratingCount = 0
        self.downloadCount = 0
        
        // Metadata
        self.phaseCount = 0
        self.taskCount = 0
        self.milestoneCount = 0
        
        // Visual
        self.icon = category.defaultIcon
        self.color = category.defaultColor
        self.tags = []
        
        // Metadata
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        // Relationships
        self.phases = []
        self.defaultTasks = []
        self.milestones = []
        self.suggestedTimeBlocks = []
    }
}

// MARK: - ProjectTemplate Extensions

extension ProjectTemplate: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let duration = estimatedDuration, duration < 0 {
            throw ModelValidationError.missingRequiredField("Расчетное время не может быть отрицательным")
        }
        
        if rating < 0 || rating > 5 {
            throw ModelValidationError.missingRequiredField("Рейтинг должен быть от 0 до 5")
        }
    }
}

extension ProjectTemplate {
    
    // MARK: - Computed Properties
    
    /// Средний рейтинг в виде строки
    var formattedRating: String {
        if ratingCount == 0 {
            return "Нет оценок"
        }
        return String(format: "%.1f ⭐ (%d)", rating, ratingCount)
    }
    
    /// Форматированная сложность
    var formattedDifficulty: String {
        return "\(difficultyLevel.emoji) \(difficultyLevel.displayName)"
    }
    
    /// Популярность шаблона
    var popularityScore: Double {
        let usageWeight = Double(usageCount) * 2.0
        let ratingWeight = rating * Double(ratingCount) * 1.5
        let downloadWeight = Double(downloadCount) * 1.0
        
        return usageWeight + ratingWeight + downloadWeight
    }
    
    /// Рекомендуется ли шаблон
    var isRecommended: Bool {
        return rating >= 4.0 && ratingCount >= 5 && usageCount >= 10
    }
    
    /// Общее расчетное время в читаемом формате
    var formattedEstimatedDuration: String? {
        guard let duration = estimatedDuration else { return nil }
        return formatDuration(duration)
    }
    
    // MARK: - Template Management
    
    /// Увеличивает счетчик использований
    func incrementUsageCount() {
        usageCount += 1
        updateTimestamp()
        markForSync()
    }
    
    /// Увеличивает счетчик скачиваний
    func incrementDownloadCount() {
        downloadCount += 1
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет рейтинг
    func updateRating(newRating: Double) {
        guard newRating >= 0 && newRating <= 5 else { return }
        
        let totalRating = rating * Double(ratingCount) + newRating
        ratingCount += 1
        rating = totalRating / Double(ratingCount)
        
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет метаданные структуры
    func updateStructureMetadata() {
        phaseCount = phases.count
        taskCount = defaultTasks.count
        milestoneCount = milestones.count
        
        // Обновляем общее расчетное время
        let totalTaskDuration = defaultTasks.compactMap { $0.estimatedDuration }.reduce(0, +)
        if estimatedDuration == nil && totalTaskDuration > 0 {
            estimatedDuration = totalTaskDuration
        }
        
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Template Structure
    
    /// Добавляет фазу к шаблону
    func addPhase(_ phase: ProjectPhaseTemplate) {
        phase.template = self
        phase.order = phases.count
        phases.append(phase)
        updateStructureMetadata()
    }
    
    /// Добавляет задачу к шаблону
    func addTask(_ task: TaskTemplate) {
        task.template = self
        defaultTasks.append(task)
        updateStructureMetadata()
    }
    
    /// Добавляет веху к шаблону
    func addMilestone(_ milestone: MilestoneTemplate) {
        milestone.template = self
        milestones.append(milestone)
        updateStructureMetadata()
    }
    
    /// Добавляет time block к шаблону
    func addTimeBlock(_ timeBlock: TimeBlockTemplate) {
        timeBlock.template = self
        suggestedTimeBlocks.append(timeBlock)
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Tag Management
    
    /// Добавляет тег
    func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanTag.isEmpty && !tags.contains(cleanTag) {
            tags.append(cleanTag)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет тег
    func removeTag(_ tag: String) {
        tags.removeAll { $0.lowercased() == tag.lowercased() }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Export/Import
    
    /// Экспортирует шаблон в словарь для совместного использования
    func exportToDictionary() -> [String: Any] {
        var export: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "category": category.rawValue,
            "difficultyLevel": difficultyLevel.rawValue,
            "tags": tags,
            "icon": icon,
            "color": color
        ]
        
        if let description = description {
            export["description"] = description
        }
        
        if let duration = estimatedDuration {
            export["estimatedDuration"] = duration
        }
        
        // Экспортируем структуру
        export["phases"] = phases.map { $0.exportToDictionary() }
        export["tasks"] = defaultTasks.map { $0.exportToDictionary() }
        export["milestones"] = milestones.map { $0.exportToDictionary() }
        export["timeBlocks"] = suggestedTimeBlocks.map { $0.exportToDictionary() }
        
        return export
    }
    
    // MARK: - Utility
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let days = Int(duration) / (24 * 3600)
        let hours = (Int(duration) % (24 * 3600)) / 3600
        
        if days > 0 {
            return "\(days)д \(hours)ч"
        } else if hours > 0 {
            return "\(hours)ч"
        } else {
            let minutes = (Int(duration) % 3600) / 60
            return "\(minutes)м"
        }
    }
}

// MARK: - ProjectPhaseTemplate Model

@Model
final class ProjectPhaseTemplate: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var order: Int
    var estimatedDuration: TimeInterval?
    var isOptional: Bool // Можно ли пропустить эту фазу
    
    // Template context
    var templatePhaseId: UUID // Для связи с фазами в проекте
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var template: ProjectTemplate?
    @Relationship(inverse: \TaskTemplate.phase) var tasks: [TaskTemplate]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        order: Int = 0,
        estimatedDuration: TimeInterval? = nil,
        isOptional: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.order = order
        self.estimatedDuration = estimatedDuration
        self.isOptional = isOptional
        self.templatePhaseId = UUID()
        
        // Metadata
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
    
    func exportToDictionary() -> [String: Any] {
        var export: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "order": order,
            "isOptional": isOptional,
            "templatePhaseId": templatePhaseId.uuidString
        ]
        
        if let description = description {
            export["description"] = description
        }
        
        if let duration = estimatedDuration {
            export["estimatedDuration"] = duration
        }
        
        return export
    }
}

// MARK: - TaskTemplate Model

@Model
final class TaskTemplate: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var priority: Priority
    var estimatedDuration: TimeInterval?
    var tags: [String]
    
    // Template context
    var phaseId: UUID? // ID фазы в шаблоне
    var order: Int // Порядок в фазе/шаблоне
    var isOptional: Bool // Можно ли пропустить эту задачу
    
    // Dependencies
    var dependencyIds: [UUID] // IDs других задач в шаблоне, от которых зависит эта
    
    // Context hints
    var suggestedEnergyLevel: EnergyLevel?
    var suggestedTimeOfDay: TimeOfDay?
    var suggestedFocusMode: String?
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var template: ProjectTemplate?
    var phase: ProjectPhaseTemplate?
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        priority: Priority = .medium,
        estimatedDuration: TimeInterval? = nil,
        order: Int = 0,
        isOptional: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedDuration = estimatedDuration
        self.order = order
        self.isOptional = isOptional
        
        self.tags = []
        self.dependencyIds = []
        
        // Metadata
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
    
    func exportToDictionary() -> [String: Any] {
        var export: [String: Any] = [
            "id": id.uuidString,
            "title": title,
            "priority": priority.rawValue,
            "order": order,
            "isOptional": isOptional,
            "tags": tags,
            "dependencyIds": dependencyIds.map { $0.uuidString }
        ]
        
        if let description = description {
            export["description"] = description
        }
        
        if let duration = estimatedDuration {
            export["estimatedDuration"] = duration
        }
        
        if let phaseId = phaseId {
            export["phaseId"] = phaseId.uuidString
        }
        
        if let energyLevel = suggestedEnergyLevel {
            export["suggestedEnergyLevel"] = energyLevel.rawValue
        }
        
        if let timeOfDay = suggestedTimeOfDay {
            export["suggestedTimeOfDay"] = timeOfDay.rawValue
        }
        
        if let focusMode = suggestedFocusMode {
            export["suggestedFocusMode"] = focusMode
        }
        
        return export
    }
}

// MARK: - MilestoneTemplate Model

@Model
final class MilestoneTemplate: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var progressThreshold: Double // 0.0 - 1.0
    var reward: String?
    var order: Int
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var template: ProjectTemplate?
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        progressThreshold: Double,
        reward: String? = nil,
        order: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.progressThreshold = max(0.0, min(1.0, progressThreshold))
        self.reward = reward
        self.order = order
        
        // Metadata
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
    
    func exportToDictionary() -> [String: Any] {
        var export: [String: Any] = [
            "id": id.uuidString,
            "title": title,
            "progressThreshold": progressThreshold,
            "order": order
        ]
        
        if let description = description {
            export["description"] = description
        }
        
        if let reward = reward {
            export["reward"] = reward
        }
        
        return export
    }
}

// MARK: - TimeBlockTemplate Model

@Model
final class TimeBlockTemplate: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var title: String
    var duration: TimeInterval
    var suggestedTime: TimeOfDay?
    var isFlexible: Bool
    var taskId: UUID? // ID связанной задачи в шаблоне
    
    // Context
    var suggestedFocusMode: String?
    var notes: String?
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var template: ProjectTemplate?
    
    // MARK: - Initializers
    
    init(
        title: String,
        duration: TimeInterval,
        suggestedTime: TimeOfDay? = nil,
        isFlexible: Bool = true,
        taskId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.suggestedTime = suggestedTime
        self.isFlexible = isFlexible
        self.taskId = taskId
        
        // Metadata
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
    
    func exportToDictionary() -> [String: Any] {
        var export: [String: Any] = [
            "id": id.uuidString,
            "title": title,
            "duration": duration,
            "isFlexible": isFlexible
        ]
        
        if let suggestedTime = suggestedTime {
            export["suggestedTime"] = suggestedTime.rawValue
        }
        
        if let taskId = taskId {
            export["taskId"] = taskId.uuidString
        }
        
        if let focusMode = suggestedFocusMode {
            export["suggestedFocusMode"] = focusMode
        }
        
        if let notes = notes {
            export["notes"] = notes
        }
        
        return export
    }
}

// MARK: - Supporting Enums

enum TemplateCategory: String, Codable, CaseIterable {
    case software = "software"
    case marketing = "marketing"
    case design = "design"
    case research = "research"
    case planning = "planning"
    case personal = "personal"
    case education = "education"
    case business = "business"
    case creative = "creative"
    case health = "health"
    
    var displayName: String {
        switch self {
        case .software: return "Разработка ПО"
        case .marketing: return "Маркетинг"
        case .design: return "Дизайн"
        case .research: return "Исследования"
        case .planning: return "Планирование"
        case .personal: return "Личное"
        case .education: return "Образование"
        case .business: return "Бизнес"
        case .creative: return "Творчество"
        case .health: return "Здоровье"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .software: return "laptopcomputer"
        case .marketing: return "megaphone"
        case .design: return "paintbrush"
        case .research: return "magnifyingglass"
        case .planning: return "calendar"
        case .personal: return "person.circle"
        case .education: return "graduationcap"
        case .business: return "briefcase"
        case .creative: return "paintpalette"
        case .health: return "heart.circle"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .software: return "#007AFF"
        case .marketing: return "#FF3B30"
        case .design: return "#AF52DE"
        case .research: return "#5856D6"
        case .planning: return "#34C759"
        case .personal: return "#FF9500"
        case .education: return "#FF2D92"
        case .business: return "#8E8E93"
        case .creative: return "#BF5AF2"
        case .health: return "#FF3B30"
        }
    }
}

enum DifficultyLevel: Int, Codable, CaseIterable {
    case beginner = 1
    case easy = 2
    case medium = 3
    case hard = 4
    case expert = 5
    
    var displayName: String {
        switch self {
        case .beginner: return "Новичок"
        case .easy: return "Легко"
        case .medium: return "Средне"
        case .hard: return "Сложно"
        case .expert: return "Эксперт"
        }
    }
    
    var emoji: String {
        switch self {
        case .beginner: return "🌱"
        case .easy: return "🟢"
        case .medium: return "🟡"
        case .hard: return "🟠"
        case .expert: return "🔴"
        }
    }
    
    var color: String {
        switch self {
        case .beginner: return "#34C759"
        case .easy: return "#30D158"
        case .medium: return "#FFCC00"
        case .hard: return "#FF9500"
        case .expert: return "#FF3B30"
        }
    }
} 