import Foundation
import SwiftData

// MARK: - Goal Model

@Model
final class Goal: CloudKitSyncable, Timestampable, Gamifiable, Categorizable, Prioritizable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var priority: Priority
    var type: GoalType
    
    // Временные параметры
    var targetDate: Date?
    var startDate: Date
    var completedDate: Date?
    var isCompleted: Bool
    
    // Прогресс и измерения
    var targetValue: Double? // Целевое значение (например, сумма денег, количество книг)
    var currentValue: Double // Текущее значение
    var unit: String? // Единица измерения ("₽", "книг", "кг")
    var progressType: ProgressType
    
    // Визуализация
    var icon: String // SF Symbol name
    var color: String // Hex color
    var motivationalQuote: String?
    
    // Уведомления и напоминания
    var reminderEnabled: Bool
    var reminderFrequency: ReminderFrequency?
    var lastReminderDate: Date?
    
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
    
    // Связанные задачи
    @Relationship(deleteRule: .nullify, inverse: \Task.parentGoal) 
    var tasks: [Task]
    
    // Вехи (milestones)
    @Relationship(deleteRule: .cascade) 
    var milestones: [GoalMilestone]
    
    // Записи прогресса
    @Relationship(deleteRule: .cascade) 
    var progressEntries: [GoalProgress]
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        priority: Priority = .medium,
        type: GoalType = .personal,
        targetDate: Date? = nil,
        targetValue: Double? = nil,
        unit: String? = nil,
        progressType: ProgressType = .percentage,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.priority = priority
        self.type = type
        self.targetDate = targetDate
        self.targetValue = targetValue
        self.currentValue = 0.0
        self.unit = unit
        self.progressType = progressType
        self.category = category
        
        // Статус
        self.isCompleted = false
        self.startDate = Date()
        
        // Визуализация
        self.icon = type.defaultIcon
        self.color = type.defaultColor
        
        // Уведомления
        self.reminderEnabled = false
        
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
        self.milestones = []
        self.progressEntries = []
    }
}

// MARK: - Goal Extensions

extension Goal: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let target = targetDate, target <= startDate {
            throw ModelValidationError.invalidDate
        }
        
        if let targetVal = targetValue, targetVal <= 0 {
            throw ModelValidationError.missingRequiredField("Целевое значение должно быть больше 0")
        }
        
        if currentValue < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

extension Goal {
    
    // MARK: - Computed Properties
    
    /// Очки за эту цель
    var points: Int {
        calculatePoints()
    }
    
    /// Прогресс выполнения цели (0.0 - 1.0)
    var progress: Double {
        switch progressType {
        case .percentage:
            return min(currentValue / 100.0, 1.0)
        case .numeric:
            guard let target = targetValue, target > 0 else { return 0.0 }
            return min(currentValue / target, 1.0)
        case .binary:
            return isCompleted ? 1.0 : 0.0
        case .taskBased:
            let completedTasks = tasks.filter { $0.status.isCompleted }.count
            return tasks.isEmpty ? 0.0 : Double(completedTasks) / Double(tasks.count)
        }
    }
    
    /// Прогресс в процентах
    var progressPercentage: Int {
        return Int(progress * 100)
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
    
    /// Среднее время до завершения (на основе текущего прогресса)
    var estimatedCompletionDate: Date? {
        guard let targetDate = targetDate, progress > 0 else { return targetDate }
        
        let elapsed = Date().timeIntervalSince(startDate)
        let estimatedTotal = elapsed / progress
        let remaining = estimatedTotal - elapsed
        
        return Date().addingTimeInterval(remaining)
    }
    
    /// Активные задачи цели
    var activeTasks: [Task] {
        return tasks.filter { !$0.isArchived && $0.status != .completed && $0.status != .cancelled }
    }
    
    /// Выполненные задачи цели
    var completedTasks: [Task] {
        return tasks.filter { $0.status.isCompleted }
    }
    
    /// Достигнутые вехи
    var achievedMilestones: [GoalMilestone] {
        return milestones.filter { $0.isAchieved }
    }
    
    /// Следующая веха
    var nextMilestone: GoalMilestone? {
        return milestones
            .filter { !$0.isAchieved }
            .sorted { $0.targetProgress < $1.targetProgress }
            .first
    }
    
    /// Форматированный текущий прогресс
    var formattedCurrentValue: String {
        switch progressType {
        case .percentage:
            return "\(Int(currentValue))%"
        case .numeric:
            if let unit = unit {
                return "\(formatNumber(currentValue)) \(unit)"
            } else {
                return formatNumber(currentValue)
            }
        case .binary:
            return isCompleted ? "Выполнено" : "В работе"
        case .taskBased:
            return "\(completedTasks.count) из \(tasks.count) задач"
        }
    }
    
    /// Форматированное целевое значение
    var formattedTargetValue: String? {
        guard let target = targetValue else { return nil }
        
        switch progressType {
        case .percentage:
            return "100%"
        case .numeric:
            if let unit = unit {
                return "\(formatNumber(target)) \(unit)"
            } else {
                return formatNumber(target)
            }
        case .binary:
            return "Выполнить"
        case .taskBased:
            return "\(tasks.count) задач"
        }
    }
    
    // MARK: - Goal Management
    
    /// Отмечает цель как выполненную
    func markCompleted() {
        isCompleted = true
        completedDate = Date()
        currentValue = targetValue ?? 100.0
        updateTimestamp()
        markForSync()
        
        // Отмечаем все вехи как достигнутые
        for milestone in milestones where !milestone.isAchieved {
            milestone.markAchieved()
        }
    }
    
    /// Обновляет прогресс цели
    func updateProgress(_ newValue: Double, note: String? = nil) {
        let oldValue = currentValue
        currentValue = max(0, newValue)
        
        // Создаем запись прогресса
        let progressEntry = GoalProgress(
            goal: self,
            previousValue: oldValue,
            newValue: currentValue,
            note: note
        )
        progressEntries.append(progressEntry)
        
        // Проверяем вехи
        checkMilestones()
        
        // Проверяем завершение цели
        if progressType != .binary && progress >= 1.0 && !isCompleted {
            markCompleted()
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Увеличивает прогресс на значение
    func incrementProgress(by value: Double, note: String? = nil) {
        updateProgress(currentValue + value, note: note)
    }
    
    /// Сбрасывает прогресс
    func resetProgress() {
        updateProgress(0, note: "Прогресс сброшен")
        isCompleted = false
        completedDate = nil
        
        // Сбрасываем все вехи
        for milestone in milestones {
            milestone.reset()
        }
    }
    
    // MARK: - Milestone Management
    
    /// Добавляет веху
    func addMilestone(_ milestone: GoalMilestone) {
        milestone.goal = self
        milestones.append(milestone)
        milestones.sort { $0.targetProgress < $1.targetProgress }
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет веху
    func removeMilestone(_ milestone: GoalMilestone) {
        milestones.removeAll { $0.id == milestone.id }
        updateTimestamp()
        markForSync()
    }
    
    /// Проверяет и обновляет статус вех
    private func checkMilestones() {
        for milestone in milestones where !milestone.isAchieved {
            if progress >= milestone.targetProgress {
                milestone.markAchieved()
            }
        }
    }
    
    // MARK: - Task Management
    
    /// Добавляет задачу к цели
    func addTask(_ task: Task) {
        task.parentGoal = self
        tasks.append(task)
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет задачу из цели
    func removeTask(_ task: Task) {
        task.parentGoal = nil
        tasks.removeAll { $0.id == task.id }
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Reminder Management
    
    /// Включает напоминания
    func enableReminders(frequency: ReminderFrequency) {
        reminderEnabled = true
        reminderFrequency = frequency
        updateTimestamp()
        markForSync()
    }
    
    /// Отключает напоминания
    func disableReminders() {
        reminderEnabled = false
        reminderFrequency = nil
        updateTimestamp()
        markForSync()
    }
    
    /// Нужно ли отправить напоминание
    var shouldSendReminder: Bool {
        guard reminderEnabled, let frequency = reminderFrequency else { return false }
        
        let lastReminder = lastReminderDate ?? startDate
        let nextReminderDate = frequency.nextDate(from: lastReminder)
        
        return Date() >= nextReminderDate
    }
    
    // MARK: - Utility Methods
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    func calculatePoints() -> Int {
        let basePoints = priority.points * 2 // Цели дают больше очков
        let progressBonus = Int(progress * 100)
        let completionBonus = isCompleted ? 50 : 0
        let milestoneBonus = achievedMilestones.count * 10
        let urgencyBonus = isOverdue ? -10 : (daysUntilTarget ?? 0 < 7 ? 15 : 0)
        
        return max(0, basePoints + progressBonus + completionBonus + milestoneBonus + urgencyBonus)
    }
}

// MARK: - GoalMilestone Model

@Model
final class GoalMilestone: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var targetProgress: Double // 0.0 - 1.0
    var isAchieved: Bool
    var achievedDate: Date?
    var reward: String? // Описание награды за достижение вехи
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var goal: Goal?
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String? = nil,
        targetProgress: Double,
        reward: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.targetProgress = max(0.0, min(1.0, targetProgress))
        self.isAchieved = false
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
    
    func markAchieved() {
        isAchieved = true
        achievedDate = Date()
        updateTimestamp()
        markForSync()
    }
    
    func reset() {
        isAchieved = false
        achievedDate = nil
        updateTimestamp()
        markForSync()
    }
}

// MARK: - GoalProgress Model

@Model
final class GoalProgress: CloudKitSyncable, Timestampable {
    
    @Attribute(.unique) var id: UUID
    var previousValue: Double
    var newValue: Double
    var note: String?
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var goal: Goal?
    
    // MARK: - Initializers
    
    init(
        goal: Goal,
        previousValue: Double,
        newValue: Double,
        note: String? = nil
    ) {
        self.id = UUID()
        self.goal = goal
        self.previousValue = previousValue
        self.newValue = newValue
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
    
    var delta: Double {
        return newValue - previousValue
    }
    
    var formattedDelta: String {
        let value = abs(delta)
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.1f", value))"
    }
}

// MARK: - Supporting Enums

enum GoalType: String, Codable, CaseIterable {
    case personal = "personal"
    case health = "health"
    case career = "career"
    case financial = "financial"
    case education = "education"
    case relationships = "relationships"
    case travel = "travel"
    case hobby = "hobby"
    
    var displayName: String {
        switch self {
        case .personal: return "Личное"
        case .health: return "Здоровье"
        case .career: return "Карьера"
        case .financial: return "Финансы"
        case .education: return "Образование"
        case .relationships: return "Отношения"
        case .travel: return "Путешествия"
        case .hobby: return "Хобби"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .personal: return "person.circle"
        case .health: return "heart.circle"
        case .career: return "briefcase.circle"
        case .financial: return "dollarsign.circle"
        case .education: return "graduationcap.circle"
        case .relationships: return "person.2.circle"
        case .travel: return "airplane.circle"
        case .hobby: return "gamecontroller.circle"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .personal: return "#5856D6"
        case .health: return "#FF3B30"
        case .career: return "#007AFF"
        case .financial: return "#34C759"
        case .education: return "#FF9500"
        case .relationships: return "#FF2D92"
        case .travel: return "#32D74B"
        case .hobby: return "#BF5AF2"
        }
    }
}

enum ProgressType: String, Codable, CaseIterable {
    case percentage = "percentage" // 0-100%
    case numeric = "numeric" // Числовое значение с целью
    case binary = "binary" // Выполнено/не выполнено
    case taskBased = "task_based" // На основе выполненных задач
    
    var displayName: String {
        switch self {
        case .percentage: return "Проценты"
        case .numeric: return "Числовое значение"
        case .binary: return "Выполнено/Не выполнено"
        case .taskBased: return "На основе задач"
        }
    }
}

enum ReminderFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневно"
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        }
    }
    
    func nextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
} 