import Foundation
import SwiftData

// MARK: - ProjectTask Model

@Model
final class ProjectTask: CloudKitSyncable, Timestampable, Gamifiable, Prioritizable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var priority: Priority
    var status: TaskStatus
    
    // Временные параметры
    var dueDate: Date?
    var startDate: Date?
    var completedDate: Date?
    var estimatedDuration: TimeInterval? // В секундах
    var actualDuration: TimeInterval? // Фактическое время выполнения
    
    // Project context
    var kanbanColumn: String? // Для Kanban view
    var sortOrder: Int // Порядок в списке/колонке
    
    // Дополнительные свойства
    var tags: [String]
    var isRecurring: Bool
    var recurringPattern: RecurringPattern?
    var reminderDate: Date?
    var location: String?
    var url: String? // Ссылка на документ/сайт
    var notes: String? // Дополнительные заметки
    
    // Progress tracking
    var effortSpent: TimeInterval? // Потраченное время
    var completionProgress: Double // 0.0 - 1.0 для частично выполненных задач
    
    // Context awareness
    var focusModeContext: String? // Подходящий focus mode
    var energyLevel: EnergyLevel? // Требуемый уровень энергии
    var timeOfDay: TimeOfDay? // Предпочтительное время выполнения
    
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
    var project: Project
    var phase: ProjectPhase? // Фаза проекта
    
    // Иерархия задач
    var parentTask: ProjectTask?
    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.parentTask) 
    var subtasks: [ProjectTask]
    
    // Зависимости между задачами
    @Relationship(inverse: \ProjectTask.dependentTasks) var prerequisiteTasks: [ProjectTask]
    @Relationship(inverse: \ProjectTask.prerequisiteTasks) var dependentTasks: [ProjectTask]
    
    // Time blocks
    @Relationship(deleteRule: .cascade, inverse: \TimeBlock.task) 
    var assignedTimeBlocks: [TimeBlock]
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        project: Project,
        phase: ProjectPhase? = nil,
        parentTask: ProjectTask? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.status = .pending
        self.dueDate = dueDate
        self.estimatedDuration = estimatedDuration
        self.project = project
        self.phase = phase
        self.parentTask = parentTask
        
        // Project context
        self.kanbanColumn = "todo" // Default column
        self.sortOrder = 0
        
        // Дополнительные свойства
        self.tags = []
        self.isRecurring = false
        self.recurringPattern = nil
        self.completionProgress = 0.0
        
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
        self.subtasks = []
        self.prerequisiteTasks = []
        self.dependentTasks = []
        self.assignedTimeBlocks = []
    }
}

// MARK: - ProjectTask Extensions

extension ProjectTask: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let due = dueDate, let start = startDate, due < start {
            throw ModelValidationError.invalidDate
        }
        
        if let estimated = estimatedDuration, estimated < 0 {
            throw ModelValidationError.missingRequiredField("Расчетное время не может быть отрицательным")
        }
        
        if completionProgress < 0 || completionProgress > 1 {
            throw ModelValidationError.missingRequiredField("Прогресс должен быть между 0 и 1")
        }
    }
}

extension ProjectTask {
    
    // MARK: - Computed Properties
    
    /// Очки за эту задачу
    var points: Int {
        calculatePoints()
    }
    
    /// Прогресс выполнения задачи (включая подзадачи)
    var totalProgress: Double {
        if subtasks.isEmpty {
            return status.isCompleted ? 1.0 : completionProgress
        }
        
        let subtaskProgress = subtasks.map { $0.totalProgress }.reduce(0, +) / Double(subtasks.count)
        let ownProgress = status.isCompleted ? 1.0 : completionProgress
        
        // Собственный прогресс весит 70%, подзадачи 30%
        return ownProgress * 0.7 + subtaskProgress * 0.3
    }
    
    /// Просрочена ли задача
    var isOverdue: Bool {
        guard let dueDate = dueDate, status != .completed else { return false }
        return Date() > dueDate
    }
    
    /// До дедлайна осталось дней
    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
    
    /// Время выполнения (фактическое или расчетное)
    var duration: TimeInterval? {
        return actualDuration ?? estimatedDuration
    }
    
    /// Все подзадачи (включая вложенные)
    var allSubtasks: [ProjectTask] {
        var result: [ProjectTask] = []
        for subtask in subtasks where !subtask.isArchived {
            result.append(subtask)
            result.append(contentsOf: subtask.allSubtasks)
        }
        return result
    }
    
    /// Активные подзадачи
    var activeSubtasks: [ProjectTask] {
        return subtasks.filter { !$0.isArchived && $0.status != .completed && $0.status != .cancelled }
    }
    
    /// Может ли задача быть начата (все prerequisites выполнены)
    var canStart: Bool {
        return prerequisiteTasks.allSatisfy { $0.status.isCompleted }
    }
    
    /// Заблокированные задачи (зависящие от этой)
    var blockedTasks: [ProjectTask] {
        return dependentTasks.filter { !$0.canStart }
    }
    
    /// Общее запланированное время в time blocks
    var scheduledTime: TimeInterval {
        return assignedTimeBlocks.map { $0.duration }.reduce(0, +)
    }
    
    /// Следующий time block для этой задачи
    var nextTimeBlock: TimeBlock? {
        return assignedTimeBlocks
            .filter { $0.startDate > Date() && !$0.isCompleted }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
    
    /// Готовность к выполнению на основе контекста
    var contextReadiness: Double {
        var readiness: Double = 1.0
        
        // Проверяем energy level
        if let requiredEnergy = energyLevel {
            let currentHour = Calendar.current.component(.hour, from: Date())
            let currentEnergyScore = EnergyLevel.currentEnergyLevel(at: currentHour).rawValue
            if currentEnergyScore < requiredEnergy.rawValue {
                readiness -= 0.3
            }
        }
        
        // Проверяем time of day
        if let preferredTime = timeOfDay {
            let currentHour = Calendar.current.component(.hour, from: Date())
            if !preferredTime.contains(hour: currentHour) {
                readiness -= 0.2
            }
        }
        
        // Проверяем зависимости
        if !canStart {
            readiness -= 0.5
        }
        
        return max(0.0, readiness)
    }
    
    // MARK: - Task Management
    
    /// Отмечает задачу как выполненную
    func markCompleted() {
        status = .completed
        completedDate = Date()
        completionProgress = 1.0
        
        // Если есть фактическое время выполнения
        if let start = startDate {
            actualDuration = Date().timeIntervalSince(start)
        }
        
        updateTimestamp()
        markForSync()
        
        // Обновляем прогресс проекта
        project.updateProgress()
        
        // Создаем повторяющуюся задачу если нужно
        if isRecurring, let pattern = recurringPattern {
            createNextRecurringTask(with: pattern)
        }
        
        // Отмечаем связанные time blocks как выполненные
        for timeBlock in assignedTimeBlocks where !timeBlock.isCompleted {
            timeBlock.markCompleted()
        }
    }
    
    /// Начинает выполнение задачи
    func start() {
        guard canStart else { return }
        
        status = .inProgress
        startDate = Date()
        project.lastWorkedDate = Date()
        updateTimestamp()
        markForSync()
    }
    
    /// Приостанавливает задачу
    func pause() {
        if status == .inProgress {
            status = .pending
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Отменяет задачу
    func cancel() {
        status = .cancelled
        updateTimestamp()
        markForSync()
        
        // Отменяем все time blocks
        for timeBlock in assignedTimeBlocks where !timeBlock.isCompleted {
            timeBlock.cancel()
        }
        
        // Обновляем прогресс проекта
        project.updateProgress()
    }
    
    /// Обновляет прогресс выполнения
    func updateProgress(_ progress: Double) {
        completionProgress = max(0.0, min(1.0, progress))
        
        if completionProgress >= 1.0 && status != .completed {
            markCompleted()
        }
        
        updateTimestamp()
        markForSync()
        
        // Обновляем прогресс проекта
        project.updateProgress()
    }
    
    /// Создает следующую повторяющуюся задачу
    private func createNextRecurringTask(with pattern: RecurringPattern) {
        guard let nextDate = pattern.nextDate(from: dueDate ?? Date()) else { return }
        
        let nextTask = ProjectTask(
            title: title,
            description: description,
            priority: priority,
            dueDate: nextDate,
            estimatedDuration: estimatedDuration,
            project: project,
            phase: phase,
            parentTask: parentTask
        )
        
        nextTask.isRecurring = true
        nextTask.recurringPattern = pattern
        nextTask.tags = tags
        nextTask.location = location
        nextTask.url = url
        nextTask.notes = notes
        nextTask.focusModeContext = focusModeContext
        nextTask.energyLevel = energyLevel
        nextTask.timeOfDay = timeOfDay
        nextTask.kanbanColumn = kanbanColumn
        
        project.addTask(nextTask)
    }
    
    // MARK: - Subtask Management
    
    /// Добавляет подзадачу
    func addSubtask(_ subtask: ProjectTask) {
        subtask.parentTask = self
        subtask.project = self.project
        subtasks.append(subtask)
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет подзадачу
    func removeSubtask(_ subtask: ProjectTask) {
        subtask.parentTask = nil
        subtasks.removeAll { $0.id == subtask.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Dependency Management
    
    /// Добавляет зависимость (эта задача зависит от другой)
    func addPrerequisite(_ task: ProjectTask) {
        guard task.id != self.id else { return } // Предотвращаем зависимость от самой себя
        
        if !prerequisiteTasks.contains(where: { $0.id == task.id }) {
            prerequisiteTasks.append(task)
            task.dependentTasks.append(self)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет зависимость
    func removePrerequisite(_ task: ProjectTask) {
        prerequisiteTasks.removeAll { $0.id == task.id }
        task.dependentTasks.removeAll { $0.id == self.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Tag Management
    
    /// Добавляет тег
    func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty && !tags.contains(cleanTag) {
            tags.append(cleanTag)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет тег
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Kanban Management
    
    /// Перемещает задачу в другую колонку Kanban
    func moveToKanbanColumn(_ column: String) {
        kanbanColumn = column
        
        // Автоматически обновляем статус на основе колонки
        switch column.lowercased() {
        case "todo", "backlog":
            if status != .pending {
                status = .pending
            }
        case "in-progress", "doing", "active":
            if status != .inProgress {
                start()
            }
        case "done", "completed":
            if status != .completed {
                markCompleted()
            }
        case "blocked", "waiting":
            status = .onHold
        default:
            break
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет порядок сортировки
    func updateSortOrder(_ order: Int) {
        sortOrder = order
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Time Block Management
    
    /// Добавляет time block к задаче
    func addTimeBlock(_ timeBlock: TimeBlock) {
        timeBlock.task = self
        assignedTimeBlocks.append(timeBlock)
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет time block
    func removeTimeBlock(_ timeBlock: TimeBlock) {
        assignedTimeBlocks.removeAll { $0.id == timeBlock.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Time Estimation
    
    /// Обновляет расчетное время выполнения
    func updateEstimatedDuration(_ duration: TimeInterval) {
        estimatedDuration = duration
        updateTimestamp()
        markForSync()
    }
    
    /// Форматированное расчетное время
    var formattedEstimatedDuration: String? {
        guard let duration = estimatedDuration else { return nil }
        return formatDuration(duration)
    }
    
    /// Форматированное фактическое время
    var formattedActualDuration: String? {
        guard let duration = actualDuration else { return nil }
        return formatDuration(duration)
    }
    
    /// Форматированное потраченное время
    var formattedEffortSpent: String? {
        guard let effort = effortSpent else { return nil }
        return formatDuration(effort)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else {
            return "\(minutes)м"
        }
    }
    
    func calculatePoints() -> Int {
        let basePoints = priority.points
        let urgencyBonus = isOverdue ? -5 : (daysUntilDue ?? 0 < 3 ? 5 : 0)
        let completionBonus = status.isCompleted ? 10 : Int(completionProgress * 10)
        let subtaskBonus = subtasks.filter { $0.status.isCompleted }.count * 2
        let complexityBonus = subtasks.count * 1 // Бонус за сложность
        let phaseBonus = phase != nil ? 3 : 0 // Бонус за структурированность
        
        return max(0, basePoints + urgencyBonus + completionBonus + subtaskBonus + complexityBonus + phaseBonus)
    }
}

// MARK: - Supporting Enums

enum EnergyLevel: Int, Codable, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        }
    }
    
    /// Определяет текущий уровень энергии на основе времени дня
    static func currentEnergyLevel(at hour: Int) -> EnergyLevel {
        switch hour {
        case 6...9, 14...16: return .high // Утро и после обеда
        case 10...13, 17...19: return .medium // День и вечер
        default: return .low // Ночь и поздний вечер
        }
    }
}

enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "morning" // 6-12
    case afternoon = "afternoon" // 12-18
    case evening = "evening" // 18-22
    case night = "night" // 22-6
    
    var displayName: String {
        switch self {
        case .morning: return "Утро"
        case .afternoon: return "День"
        case .evening: return "Вечер"
        case .night: return "Ночь"
        }
    }
    
    var hourRange: ClosedRange<Int> {
        switch self {
        case .morning: return 6...11
        case .afternoon: return 12...17
        case .evening: return 18...21
        case .night: return 22...5
        }
    }
    
    func contains(hour: Int) -> Bool {
        if self == .night {
            return hour >= 22 || hour <= 5
        } else {
            return hourRange.contains(hour)
        }
    }
    
    /// Определяет текущее время дня
    static func current() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        
        for timeOfDay in TimeOfDay.allCases {
            if timeOfDay.contains(hour: hour) {
                return timeOfDay
            }
        }
        
        return .morning // Fallback
    }
} 