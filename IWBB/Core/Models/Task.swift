import Foundation
import SwiftData

// MARK: - Task Model

@Model
final class Task: CloudKitSyncable, Timestampable, Gamifiable, Categorizable, Prioritizable, Archivable {
    
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
    
    // Дополнительные свойства
    var tags: [String]
    var isRecurring: Bool
    var recurringPattern: RecurringPattern?
    var reminderDate: Date?
    var location: String?
    var url: String? // Ссылка на документ/сайт
    
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
    
    // Иерархия задач
    var parentTask: Task?
    @Relationship(deleteRule: .cascade, inverse: \Task.parentTask) 
    var subtasks: [Task]
    
    // Зависимости между задачами
    @Relationship(inverse: \Task.dependentTasks) var prerequisiteTasks: [Task]
    @Relationship(inverse: \Task.prerequisiteTasks) var dependentTasks: [Task]
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        category: Category? = nil,
        parentTask: Task? = nil,
        parentGoal: Goal? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.status = .pending
        self.dueDate = dueDate
        self.category = category
        self.parentTask = parentTask
        self.parentGoal = parentGoal
        
        // Дополнительные свойства
        self.tags = []
        self.isRecurring = false
        self.recurringPattern = nil
        
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
    }
}

// MARK: - Task Extensions

extension Task: Validatable {
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
    }
}

extension Task {
    
    // MARK: - Computed Properties
    
    /// Очки за эту задачу
    var points: Int {
        calculatePoints()
    }
    
    /// Прогресс выполнения задачи (включая подзадачи)
    var progress: Double {
        if subtasks.isEmpty {
            return status.isCompleted ? 1.0 : 0.0
        }
        
        let completedSubtasks = subtasks.filter { $0.status.isCompleted }.count
        return Double(completedSubtasks) / Double(subtasks.count)
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
    var allSubtasks: [Task] {
        var result: [Task] = []
        for subtask in subtasks where !subtask.isArchived {
            result.append(subtask)
            result.append(contentsOf: subtask.allSubtasks)
        }
        return result
    }
    
    /// Активные подзадачи
    var activeSubtasks: [Task] {
        return subtasks.filter { !$0.isArchived && $0.status != .completed && $0.status != .cancelled }
    }
    
    /// Может ли задача быть начата (все prerequisites выполнены)
    var canStart: Bool {
        return prerequisiteTasks.allSatisfy { $0.status.isCompleted }
    }
    
    /// Заблокированные задачи (зависящие от этой)
    var blockedTasks: [Task] {
        return dependentTasks.filter { !$0.canStart }
    }
    
    // MARK: - Task Management
    
    /// Отмечает задачу как выполненную
    func markCompleted() {
        status = .completed
        completedDate = Date()
        
        // Если есть фактическое время выполнения
        if let start = startDate {
            actualDuration = Date().timeIntervalSince(start)
        }
        
        updateTimestamp()
        markForSync()
        
        // Создаем повторяющуюся задачу если нужно
        if isRecurring, let pattern = recurringPattern {
            createNextRecurringTask(with: pattern)
        }
    }
    
    /// Начинает выполнение задачи
    func start() {
        guard canStart else { return }
        
        status = .inProgress
        startDate = Date()
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
    }
    
    /// Создает следующую повторяющуюся задачу
    private func createNextRecurringTask(with pattern: RecurringPattern) {
        guard let nextDate = pattern.nextDate(from: dueDate ?? Date()) else { return }
        
        let nextTask = Task(
            title: title,
            description: description,
            priority: priority,
            dueDate: nextDate,
            category: category,
            parentTask: parentTask,
            parentGoal: parentGoal
        )
        
        nextTask.isRecurring = true
        nextTask.recurringPattern = pattern
        nextTask.tags = tags
        nextTask.estimatedDuration = estimatedDuration
        nextTask.location = location
        nextTask.url = url
        nextTask.user = user
        
        // Добавляем к родительской задаче или пользователю
        if let parent = parentTask {
            parent.subtasks.append(nextTask)
        } else {
            user?.tasks.append(nextTask)
        }
    }
    
    // MARK: - Subtask Management
    
    /// Добавляет подзадачу
    func addSubtask(_ subtask: Task) {
        subtask.parentTask = self
        subtask.user = self.user
        subtasks.append(subtask)
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет подзадачу
    func removeSubtask(_ subtask: Task) {
        subtask.parentTask = nil
        subtasks.removeAll { $0.id == subtask.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Dependency Management
    
    /// Добавляет зависимость (эта задача зависит от другой)
    func addPrerequisite(_ task: Task) {
        guard task.id != self.id else { return } // Предотвращаем зависимость от самой себя
        
        if !prerequisiteTasks.contains(where: { $0.id == task.id }) {
            prerequisiteTasks.append(task)
            task.dependentTasks.append(self)
            updateTimestamp()
            markForSync()
        }
    }
    
    /// Удаляет зависимость
    func removePrerequisite(_ task: Task) {
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
        let completionBonus = status.isCompleted ? 10 : 0
        let subtaskBonus = subtasks.filter { $0.status.isCompleted }.count * 2
        
        return max(0, basePoints + urgencyBonus + completionBonus + subtaskBonus)
    }
}

// MARK: - Task Status

enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case onHold = "on_hold"
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидает"
        case .inProgress: return "В работе"
        case .completed: return "Выполнено"
        case .cancelled: return "Отменено"
        case .onHold: return "Приостановлено"
        }
    }
    
    var isCompleted: Bool {
        return self == .completed
    }
    
    var canTransitionTo: [TaskStatus] {
        switch self {
        case .pending:
            return [.inProgress, .cancelled, .onHold]
        case .inProgress:
            return [.completed, .pending, .cancelled, .onHold]
        case .completed:
            return [.pending] // Можно снова активировать
        case .cancelled:
            return [.pending, .inProgress]
        case .onHold:
            return [.pending, .inProgress, .cancelled]
        }
    }
}

// MARK: - Recurring Pattern

struct RecurringPattern: Codable, Hashable {
    var type: RecurringType
    var interval: Int // Каждые N дней/недель/месяцев
    var endDate: Date?
    var maxOccurrences: Int?
    
    init(type: RecurringType, interval: Int = 1, endDate: Date? = nil, maxOccurrences: Int? = nil) {
        self.type = type
        self.interval = interval
        self.endDate = endDate
        self.maxOccurrences = maxOccurrences
    }
    
    /// Вычисляет следующую дату повторения
    func nextDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        
        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date)
        case .weekdays:
            // Следующий рабочий день
            var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            while calendar.component(.weekday, from: nextDate) == 1 || 
                  calendar.component(.weekday, from: nextDate) == 7 {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
            return nextDate
        }
    }
    
    var displayName: String {
        switch type {
        case .daily:
            return interval == 1 ? "Ежедневно" : "Каждые \(interval) дня"
        case .weekly:
            return interval == 1 ? "Еженедельно" : "Каждые \(interval) недели"
        case .monthly:
            return interval == 1 ? "Ежемесячно" : "Каждые \(interval) месяца"
        case .yearly:
            return interval == 1 ? "Ежегодно" : "Каждые \(interval) года"
        case .weekdays:
            return "По рабочим дням"
        }
    }
}

enum RecurringType: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case weekdays = "weekdays"
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневно"
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .yearly: return "Ежегодно"
        case .weekdays: return "По рабочим дням"
        }
    }
} 