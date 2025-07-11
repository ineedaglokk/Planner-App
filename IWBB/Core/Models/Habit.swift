import Foundation
import SwiftData

// MARK: - Habit Model

@Model
final class Habit: CloudKitSyncable, Timestampable, Gamifiable, Categorizable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var icon: String // SF Symbol name
    var color: String // Hex color
    
    // Конфигурация привычки
    var frequency: HabitFrequency
    var targetValue: Int // Целевое значение (например, стаканы воды, минуты медитации)
    var unit: String? // Единица измерения ("стаканы", "минуты", "раз")
    var isActive: Bool
    
    // Напоминания
    var reminderEnabled: Bool
    var reminderTime: Date?
    var reminderDays: [Int] // Дни недели для напоминаний (0 = воскресенье)
    
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
    @Relationship(deleteRule: .cascade) var entries: [HabitEntry]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        icon: String = "checkmark.circle",
        color: String = "#32D74B",
        frequency: HabitFrequency = .daily,
        targetValue: Int = 1,
        unit: String? = nil,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.frequency = frequency
        self.targetValue = targetValue
        self.unit = unit
        self.category = category
        
        // Статус
        self.isActive = true
        
        // Напоминания
        self.reminderEnabled = false
        self.reminderTime = nil
        self.reminderDays = []
        
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
        self.entries = []
    }
}

// MARK: - Habit Extensions

extension Habit: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if targetValue <= 0 {
            throw ModelValidationError.missingRequiredField("Целевое значение должно быть больше 0")
        }
        
        if reminderEnabled && reminderTime == nil {
            throw ModelValidationError.missingRequiredField("Время напоминания обязательно при включенных уведомлениях")
        }
    }
}

extension Habit {
    
    // MARK: - Computed Properties
    
    /// Текущий стрик (количество дней подряд)
    var currentStreak: Int {
        calculateCurrentStreak()
    }
    
    /// Самый длинный стрик
    var longestStreak: Int {
        calculateLongestStreak()
    }
    
    /// Процент выполнения за последние 30 дней
    var completionRate: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = entries.filter { $0.date >= thirtyDaysAgo }
        
        let calendar = Calendar.current
        let today = Date()
        var totalDays = 0
        var completedDays = 0
        
        for i in 0..<30 {
            guard let checkDate = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            if shouldTrackForDate(checkDate) {
                totalDays += 1
                if hasEntryForDate(checkDate) {
                    completedDays += 1
                }
            }
        }
        
        return totalDays > 0 ? Double(completedDays) / Double(totalDays) : 0.0
    }
    
    /// Общее количество выполнений
    var totalCompletions: Int {
        entries.reduce(0) { $0 + $1.value }
    }
    
    /// Лучший результат за день
    var bestDayResult: Int {
        entries.max(by: { $0.value < $1.value })?.value ?? 0
    }
    
    /// Очки за эту привычку
    var points: Int {
        calculatePoints()
    }
    
    /// Выполнена ли привычка сегодня
    var isCompletedToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    /// Прогресс на сегодня (0.0 - 1.0)
    var todayProgress: Double {
        guard let todayEntry = getTodayEntry() else { return 0.0 }
        return Double(todayEntry.value) / Double(targetValue)
    }
    
    // MARK: - Habit Management
    
    /// Отмечает привычку как выполненную на определенную дату
    func markCompleted(on date: Date = Date(), value: Int? = nil) -> HabitEntry {
        let completionValue = value ?? targetValue
        
        // Проверяем, есть ли уже запись на эту дату
        if let existingEntry = getEntryForDate(date) {
            existingEntry.value = completionValue
            existingEntry.updatedAt = Date()
            existingEntry.markForSync()
            return existingEntry
        } else {
            // Создаем новую запись
            let entry = HabitEntry(
                habit: self,
                date: date,
                value: completionValue
            )
            entries.append(entry)
            updateTimestamp()
            markForSync()
            return entry
        }
    }
    
    /// Увеличивает значение привычки на дату
    func incrementValue(on date: Date = Date(), by amount: Int = 1) -> HabitEntry {
        if let existingEntry = getEntryForDate(date) {
            existingEntry.value += amount
            existingEntry.updatedAt = Date()
            existingEntry.markForSync()
            return existingEntry
        } else {
            return markCompleted(on: date, value: amount)
        }
    }
    
    /// Получает запись за сегодня
    func getTodayEntry() -> HabitEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    /// Получает запись за конкретную дату
    func getEntryForDate(_ date: Date) -> HabitEntry? {
        let targetDate = Calendar.current.startOfDay(for: date)
        return entries.first { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
    }
    
    /// Проверяет, есть ли запись за дату
    func hasEntryForDate(_ date: Date) -> Bool {
        return getEntryForDate(date) != nil
    }
    
    /// Проверяет, нужно ли отслеживать привычку в конкретную дату
    func shouldTrackForDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1 // 0 = воскресенье
        
        switch frequency {
        case .daily:
            return true
        case .weekly:
            return reminderDays.contains(weekday)
        case .custom(let days):
            return days.contains(weekday)
        }
    }
    
    // MARK: - Statistics Calculation
    
    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = Date()
        
        while shouldTrackForDate(currentDate) {
            if hasEntryForDate(currentDate) {
                streak += 1
            } else {
                break
            }
            
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        let calendar = Calendar.current
        let sortedEntries = entries.sorted { $0.date < $1.date }
        
        var longestStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        for entry in sortedEntries {
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: entry.date).day ?? 0
                
                if daysBetween == 1 {
                    currentStreak += 1
                } else {
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = entry.date
        }
        
        return max(longestStreak, currentStreak)
    }
    
    func calculatePoints() -> Int {
        let basePoints = 10
        let streakBonus = currentStreak * 2
        let completionBonus = Int(completionRate * 50)
        
        return basePoints + streakBonus + completionBonus
    }
    
    // MARK: - Reminder Management
    
    /// Включает напоминания
    func enableReminders(at time: Date, on days: [Int] = []) {
        reminderEnabled = true
        reminderTime = time
        reminderDays = days.isEmpty ? getAllDays() : days
        updateTimestamp()
        markForSync()
    }
    
    /// Отключает напоминания
    func disableReminders() {
        reminderEnabled = false
        reminderTime = nil
        reminderDays = []
        updateTimestamp()
        markForSync()
    }
    
    private func getAllDays() -> [Int] {
        return Array(0...6) // Все дни недели
    }
    
    // MARK: - Archive Management
    
    /// Архивирует привычку
    func archive() {
        isArchived = true
        archivedAt = Date()
        isActive = false
        updateTimestamp()
        markForSync()
    }
    
    /// Разархивирует привычку
    func unarchive() {
        isArchived = false
        archivedAt = nil
        isActive = true
        updateTimestamp()
        markForSync()
    }
}

// MARK: - HabitEntry Model

@Model
final class HabitEntry: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Int // Количество выполнений или значение
    var notes: String? // Заметки пользователя
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var habit: Habit?
    
    // MARK: - Initializers
    
    init(
        habit: Habit,
        date: Date = Date(),
        value: Int = 1,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.habit = habit
        self.date = Calendar.current.startOfDay(for: date)
        self.value = value
        self.notes = notes
        
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

// MARK: - HabitEntry Extensions

extension HabitEntry: Validatable {
    func validate() throws {
        if value < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

extension HabitEntry {
    
    /// Процент выполнения от цели
    var completionPercentage: Double {
        guard let habit = habit, habit.targetValue > 0 else { return 0.0 }
        return min(Double(value) / Double(habit.targetValue), 1.0)
    }
    
    /// Выполнена ли цель
    var isTargetMet: Bool {
        guard let habit = habit else { return false }
        return value >= habit.targetValue
    }
    
    /// Отформатированное значение с единицей измерения
    var formattedValue: String {
        guard let habit = habit else { return "\(value)" }
        
        if let unit = habit.unit {
            return "\(value) \(unit)"
        }
        
        return "\(value)"
    }
}

// MARK: - Habit Frequency

enum HabitFrequency: Codable, Hashable {
    case daily
    case weekly
    case custom([Int]) // Дни недели: 0 = воскресенье, 1 = понедельник, и т.д.
    
    var displayName: String {
        switch self {
        case .daily:
            return "Ежедневно"
        case .weekly:
            return "Еженедельно"
        case .custom(let days):
            let dayNames = days.map { dayName(for: $0) }
            return dayNames.joined(separator: ", ")
        }
    }
    
    private func dayName(for dayIndex: Int) -> String {
        let days = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        return days[safe: dayIndex] ?? "?"
    }
    
    /// Создает частоту для конкретных дней недели
    static func specificDays(_ days: [Int]) -> HabitFrequency {
        return .custom(days.sorted())
    }
    
    /// Создает частоту для рабочих дней
    static var workdays: HabitFrequency {
        return .custom([1, 2, 3, 4, 5]) // Пн-Пт
    }
    
    /// Создает частоту для выходных
    static var weekends: HabitFrequency {
        return .custom([0, 6]) // Сб-Вс
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 