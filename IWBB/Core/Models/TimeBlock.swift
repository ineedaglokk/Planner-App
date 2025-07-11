import Foundation
import SwiftData
import EventKit

// MARK: - TimeBlock Model

@Model
final class TimeBlock: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    
    // Block properties
    var isFlexible: Bool // Может ли быть перемещен автоматически
    var isCompleted: Bool
    var isCancelled: Bool
    var actualStartDate: Date?
    var actualEndDate: Date?
    
    // Calendar integration
    var calendarEventID: String? // EventKit event ID
    var calendarIdentifier: String? // Calendar identifier
    var syncWithCalendar: Bool // Синхронизировать с календарем
    
    // Focus and context
    var focusMode: String? // iOS Focus mode identifier
    var location: String? // Локация
    var notes: String? // Заметки
    
    // Visualization
    var color: String // Hex color
    var isAllDay: Bool // Весь день
    
    // Recurrence
    var isRecurring: Bool
    var recurringPattern: TimeBlockRecurrencePattern?
    var originalTimeBlockId: UUID? // Для повторяющихся блоков
    
    // Performance tracking
    var productivity: ProductivityLevel? // Оценка продуктивности после завершения
    var energyBefore: EnergyLevel? // Энергия до начала
    var energyAfter: EnergyLevel? // Энергия после завершения
    var distractions: Int // Количество отвлечений
    
    // Auto-scheduling
    var isAutoScheduled: Bool // Создан автоматически
    var schedulingPriority: Int // Приоритет при автопланировании
    var canBeMoved: Bool // Может быть перемещен при конфликтах
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var task: ProjectTask? // Связанная задача
    var project: Project? // Связанный проект
    
    // MARK: - Initializers
    
    init(
        title: String,
        startDate: Date,
        endDate: Date,
        task: ProjectTask? = nil,
        project: Project? = nil,
        isFlexible: Bool = true,
        syncWithCalendar: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.task = task
        self.project = project
        self.isFlexible = isFlexible
        self.syncWithCalendar = syncWithCalendar
        
        // States
        self.isCompleted = false
        self.isCancelled = false
        
        // Visual
        self.color = project?.color ?? task?.project.color ?? "#007AFF"
        self.isAllDay = false
        
        // Recurrence
        self.isRecurring = false
        
        // Auto-scheduling
        self.isAutoScheduled = false
        self.schedulingPriority = task?.priority.rawValue ?? 2
        self.canBeMoved = isFlexible
        
        // Performance
        self.distractions = 0
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
}

// MARK: - TimeBlock Extensions

extension TimeBlock: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if endDate <= startDate {
            throw ModelValidationError.invalidDate
        }
        
        if let actual = actualEndDate, let actualStart = actualStartDate, actual <= actualStart {
            throw ModelValidationError.invalidDate
        }
    }
}

extension TimeBlock {
    
    // MARK: - Computed Properties
    
    /// Продолжительность time block
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    /// Фактическая продолжительность
    var actualDuration: TimeInterval? {
        guard let actualStart = actualStartDate, let actualEnd = actualEndDate else { return nil }
        return actualEnd.timeIntervalSince(actualStart)
    }
    
    /// Статус time block
    var status: TimeBlockStatus {
        if isCancelled {
            return .cancelled
        } else if isCompleted {
            return .completed
        } else if startDate > Date() {
            return .scheduled
        } else if endDate < Date() {
            return .missed
        } else {
            return .active
        }
    }
    
    /// Форматированная продолжительность
    var formattedDuration: String {
        return formatDuration(duration)
    }
    
    /// Форматированная фактическая продолжительность
    var formattedActualDuration: String? {
        guard let actualDuration = actualDuration else { return nil }
        return formatDuration(actualDuration)
    }
    
    /// Просрочен ли time block
    var isOverdue: Bool {
        return !isCompleted && !isCancelled && endDate < Date()
    }
    
    /// Активен ли сейчас
    var isCurrentlyActive: Bool {
        let now = Date()
        return !isCompleted && !isCancelled && startDate <= now && endDate >= now
    }
    
    /// Время до начала
    var timeUntilStart: TimeInterval? {
        guard startDate > Date() else { return nil }
        return startDate.timeIntervalSince(Date())
    }
    
    /// Время до окончания
    var timeUntilEnd: TimeInterval? {
        guard endDate > Date() else { return nil }
        return endDate.timeIntervalSince(Date())
    }
    
    /// Эффективность (фактическое время vs запланированное)
    var efficiency: Double? {
        guard let actualDuration = actualDuration else { return nil }
        return min(actualDuration / duration, 2.0) // Макс 200%
    }
    
    /// Может ли быть перемещен
    var canBeRescheduled: Bool {
        return canBeMoved && !isCompleted && !isCancelled && startDate > Date()
    }
    
    /// Описание для календаря
    var calendarDescription: String {
        var description = ""
        
        if let task = task {
            description += "Задача: \(task.title)\n"
            if let project = task.project {
                description += "Проект: \(project.name)\n"
            }
        } else if let project = project {
            description += "Проект: \(project.name)\n"
        }
        
        if let notes = notes, !notes.isEmpty {
            description += "\nЗаметки: \(notes)"
        }
        
        description += "\n\nСоздано в Planner App"
        
        return description
    }
    
    // MARK: - Time Block Management
    
    /// Начинает выполнение time block
    func start() {
        guard !isCompleted && !isCancelled else { return }
        
        actualStartDate = Date()
        
        // Начинаем связанную задачу если нужно
        if let task = task, task.status == .pending {
            task.start()
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Завершает time block
    func markCompleted() {
        isCompleted = true
        actualEndDate = Date()
        
        // Если не было фактического начала, используем запланированное
        if actualStartDate == nil {
            actualStartDate = startDate
        }
        
        updateTimestamp()
        markForSync()
        
        // Создаем следующий повторяющийся time block если нужно
        if isRecurring, let pattern = recurringPattern {
            createNextRecurringTimeBlock(with: pattern)
        }
    }
    
    /// Отменяет time block
    func cancel() {
        isCancelled = true
        updateTimestamp()
        markForSync()
    }
    
    /// Перемещает time block на новое время
    func reschedule(to newStartDate: Date) {
        guard canBeRescheduled else { return }
        
        let duration = self.duration
        self.startDate = newStartDate
        self.endDate = newStartDate.addingTimeInterval(duration)
        
        updateTimestamp()
        markForSync()
    }
    
    /// Изменяет продолжительность
    func updateDuration(_ newDuration: TimeInterval) {
        guard newDuration > 0 else { return }
        
        endDate = startDate.addingTimeInterval(newDuration)
        updateTimestamp()
        markForSync()
    }
    
    /// Создает следующий повторяющийся time block
    private func createNextRecurringTimeBlock(with pattern: TimeBlockRecurrencePattern) {
        guard let nextStartDate = pattern.nextDate(from: endDate) else { return }
        
        let nextTimeBlock = TimeBlock(
            title: title,
            startDate: nextStartDate,
            endDate: nextStartDate.addingTimeInterval(duration),
            task: task,
            project: project,
            isFlexible: isFlexible,
            syncWithCalendar: syncWithCalendar
        )
        
        nextTimeBlock.isRecurring = true
        nextTimeBlock.recurringPattern = pattern
        nextTimeBlock.originalTimeBlockId = originalTimeBlockId ?? id
        nextTimeBlock.focusMode = focusMode
        nextTimeBlock.location = location
        nextTimeBlock.notes = notes
        nextTimeBlock.color = color
        nextTimeBlock.isAutoScheduled = isAutoScheduled
        nextTimeBlock.schedulingPriority = schedulingPriority
        nextTimeBlock.canBeMoved = canBeMoved
        nextTimeBlock.user = user
        
        // Добавляем к проекту или задаче
        if let project = project {
            project.timeBlocks.append(nextTimeBlock)
        } else if let task = task {
            task.addTimeBlock(nextTimeBlock)
        }
    }
    
    // MARK: - Performance Tracking
    
    /// Обновляет оценку продуктивности
    func updateProductivity(_ productivity: ProductivityLevel) {
        self.productivity = productivity
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет энергию до и после
    func updateEnergyLevels(before: EnergyLevel?, after: EnergyLevel?) {
        self.energyBefore = before
        self.energyAfter = after
        updateTimestamp()
        markForSync()
    }
    
    /// Добавляет отвлечение
    func addDistraction() {
        distractions += 1
        updateTimestamp()
        markForSync()
    }
    
    // MARK: - Calendar Integration
    
    /// Создает событие календаря
    func createCalendarEvent(in calendar: EKCalendar) -> EKEvent? {
        guard syncWithCalendar else { return nil }
        
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        event.notes = calendarDescription
        event.isAllDay = isAllDay
        
        if let location = location {
            event.location = location
        }
        
        // Добавляем URL для deep linking
        event.url = URL(string: "plannerapp://timeblock/\(id)")
        
        return event
    }
    
    /// Обновляет существующее событие календаря
    func updateCalendarEvent(_ event: EKEvent) {
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = calendarDescription
        event.isAllDay = isAllDay
        
        if let location = location {
            event.location = location
        }
    }
    
    // MARK: - Conflict Detection
    
    /// Проверяет конфликт с другим time block
    func hasConflict(with other: TimeBlock) -> Bool {
        guard id != other.id else { return false }
        
        return !(endDate <= other.startDate || startDate >= other.endDate)
    }
    
    /// Проверяет конфликт с событием календаря
    func hasConflict(with event: EKEvent) -> Bool {
        return !(endDate <= event.startDate || startDate >= event.endDate)
    }
    
    // MARK: - Utility Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else {
            return "\(minutes)м"
        }
    }
}

// MARK: - TimeBlockStatus

enum TimeBlockStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case active = "active"
    case completed = "completed"
    case missed = "missed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Запланирован"
        case .active: return "Активен"
        case .completed: return "Завершен"
        case .missed: return "Пропущен"
        case .cancelled: return "Отменен"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .scheduled: return "calendar"
        case .active: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .missed: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .scheduled: return "#007AFF"
        case .active: return "#34C759"
        case .completed: return "#30D158"
        case .missed: return "#FF9500"
        case .cancelled: return "#FF3B30"
        }
    }
}

// MARK: - ProductivityLevel

enum ProductivityLevel: Int, Codable, CaseIterable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case high = 4
    case veryHigh = 5
    
    var displayName: String {
        switch self {
        case .veryLow: return "Очень низкая"
        case .low: return "Низкая"
        case .medium: return "Средняя"
        case .high: return "Высокая"
        case .veryHigh: return "Очень высокая"
        }
    }
    
    var emoji: String {
        switch self {
        case .veryLow: return "😴"
        case .low: return "😕"
        case .medium: return "😐"
        case .high: return "😊"
        case .veryHigh: return "🚀"
        }
    }
    
    var color: String {
        switch self {
        case .veryLow: return "#FF3B30"
        case .low: return "#FF9500"
        case .medium: return "#FFCC00"
        case .high: return "#30D158"
        case .veryHigh: return "#007AFF"
        }
    }
}

// MARK: - TimeBlockRecurrencePattern

struct TimeBlockRecurrencePattern: Codable, Hashable {
    var type: RecurrenceType
    var interval: Int // Каждые N дней/недель/месяцев
    var endDate: Date?
    var maxOccurrences: Int?
    var daysOfWeek: [Int]? // Для еженедельного повторения (1 = воскресенье)
    
    init(
        type: RecurrenceType,
        interval: Int = 1,
        endDate: Date? = nil,
        maxOccurrences: Int? = nil,
        daysOfWeek: [Int]? = nil
    ) {
        self.type = type
        self.interval = interval
        self.endDate = endDate
        self.maxOccurrences = maxOccurrences
        self.daysOfWeek = daysOfWeek
    }
    
    /// Вычисляет следующую дату повторения
    func nextDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        
        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                // Находим следующий день недели из списка
                return findNextWeekday(from: date, daysOfWeek: daysOfWeek)
            } else {
                return calendar.date(byAdding: .weekOfYear, value: interval, to: date)
            }
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date)
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
    
    private func findNextWeekday(from date: Date, daysOfWeek: [Int]) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        
        // Сортируем дни недели
        let sortedDays = daysOfWeek.sorted()
        
        // Находим следующий день в текущей неделе
        for day in sortedDays where day > currentWeekday {
            let daysToAdd = day - currentWeekday
            return calendar.date(byAdding: .day, value: daysToAdd, to: date)
        }
        
        // Если нет дней в текущей неделе, берем первый день следующей недели
        let firstDayNextWeek = sortedDays.first ?? 1
        let daysToAdd = 7 - currentWeekday + firstDayNextWeek
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
    
    var displayName: String {
        switch type {
        case .daily:
            return interval == 1 ? "Ежедневно" : "Каждые \(interval) дня"
        case .weekly:
            if let daysOfWeek = daysOfWeek, !daysOfWeek.isEmpty {
                let dayNames = daysOfWeek.compactMap { dayNumber in
                    Calendar.current.weekdaySymbols[dayNumber - 1]
                }
                return "По \(dayNames.joined(separator: ", "))"
            } else {
                return interval == 1 ? "Еженедельно" : "Каждые \(interval) недели"
            }
        case .monthly:
            return interval == 1 ? "Ежемесячно" : "Каждые \(interval) месяца"
        case .weekdays:
            return "По рабочим дням"
        }
    }
}

enum RecurrenceType: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case weekdays = "weekdays"
    
    var displayName: String {
        switch self {
        case .daily: return "Ежедневно"
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .weekdays: return "По рабочим дням"
        }
    }
} 