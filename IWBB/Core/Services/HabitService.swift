import Foundation
import SwiftData

// MARK: - HabitService Protocol

protocol HabitServiceProtocol: ServiceProtocol {
    func getActiveHabits() async throws -> [Habit]
    func getTodayHabits() async throws -> [Habit]
    func getHabit(by id: UUID) async throws -> Habit?
    func createHabit(_ habit: Habit) async throws
    func updateHabit(_ habit: Habit) async throws
    func deleteHabit(_ habit: Habit) async throws
    func toggleHabitCompletion(_ habit: Habit, date: Date) async throws -> Bool
    func markHabitComplete(_ habit: Habit, date: Date, value: Int?) async throws -> HabitEntry
    func incrementHabitValue(_ habit: Habit, date: Date, by amount: Int) async throws -> HabitEntry
    func getHabitStatistics(_ habit: Habit, period: StatisticsPeriod) async throws -> HabitStatistics
    func scheduleHabitReminders(_ habit: Habit) async throws
    func cancelHabitReminders(_ habit: Habit) async throws
    func archiveHabit(_ habit: Habit) async throws
    func unarchiveHabit(_ habit: Habit) async throws
}

// MARK: - HabitService Implementation

final class HabitService: HabitServiceProtocol {
    
    // MARK: - Properties
    
    private let habitRepository: HabitRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    
    var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    init(
        habitRepository: HabitRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.habitRepository = habitRepository
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("Initializing HabitService...")
        #endif
        
        // Проверяем и обновляем состояние привычек при запуске
        try await updateDailyHabitsStatus()
        
        isInitialized = true
        
        #if DEBUG
        print("HabitService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("Cleaning up HabitService...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("HabitService cleaned up")
        #endif
    }
    
    // MARK: - Habit Management
    
    func getActiveHabits() async throws -> [Habit] {
        return try await habitRepository.fetchActiveHabits()
    }
    
    func getTodayHabits() async throws -> [Habit] {
        return try await habitRepository.fetchHabitsForToday()
    }
    
    func getHabit(by id: UUID) async throws -> Habit? {
        return try await habitRepository.fetchHabit(by: id)
    }
    
    func createHabit(_ habit: Habit) async throws {
        try await habitRepository.save(habit)
        
        // Планируем напоминания если они включены
        if habit.reminderEnabled {
            try await scheduleHabitReminders(habit)
        }
    }
    
    func updateHabit(_ habit: Habit) async throws {
        try await habitRepository.update(habit)
        
        // Обновляем напоминания
        await cancelHabitReminders(habit)
        if habit.reminderEnabled {
            try await scheduleHabitReminders(habit)
        }
    }
    
    func deleteHabit(_ habit: Habit) async throws {
        // Отменяем все напоминания
        await cancelHabitReminders(habit)
        
        // Удаляем привычку
        try await habitRepository.delete(habit)
    }
    
    // MARK: - Habit Tracking
    
    func toggleHabitCompletion(_ habit: Habit, date: Date = Date()) async throws -> Bool {
        let existingEntry = try await habitRepository.getHabitEntry(habit: habit, date: date)
        
        if let entry = existingEntry {
            // Если запись существует и цель достигнута, сбрасываем значение
            if entry.isTargetMet {
                entry.value = 0
                try await habitRepository.update(habit)
                return false
            } else {
                // Если цель не достигнута, завершаем привычку
                try await markHabitComplete(habit, date: date, value: habit.targetValue)
                return true
            }
        } else {
            // Создаем новую запись
            try await markHabitComplete(habit, date: date, value: habit.targetValue)
            return true
        }
    }
    
    func markHabitComplete(_ habit: Habit, date: Date = Date(), value: Int? = nil) async throws -> HabitEntry {
        return try await habitRepository.markHabitComplete(habit, date: date, value: value)
    }
    
    func incrementHabitValue(_ habit: Habit, date: Date = Date(), by amount: Int = 1) async throws -> HabitEntry {
        return try await habitRepository.incrementHabitValue(habit, date: date, by: amount)
    }
    
    // MARK: - Statistics
    
    func getHabitStatistics(_ habit: Habit, period: StatisticsPeriod = .month) async throws -> HabitStatistics {
        return try await habitRepository.getStatistics(for: habit, period: period)
    }
    
    // MARK: - Notifications
    
    func scheduleHabitReminders(_ habit: Habit) async throws {
        guard habit.reminderEnabled,
              let reminderTime = habit.reminderTime else {
            return
        }
        
        let identifier = "habit_\(habit.id.uuidString)"
        
        try await notificationService.scheduleHabitReminder(
            habit.id,
            name: habit.name,
            time: reminderTime
        )
        
        #if DEBUG
        print("Scheduled reminder for habit: \(habit.name)")
        #endif
    }
    
    func cancelHabitReminders(_ habit: Habit) async {
        let identifier = "habit_\(habit.id.uuidString)"
        await notificationService.cancelNotification(for: identifier)
        
        #if DEBUG
        print("Cancelled reminders for habit: \(habit.name)")
        #endif
    }
    
    // MARK: - Archive Operations
    
    func archiveHabit(_ habit: Habit) async throws {
        await cancelHabitReminders(habit)
        try await habitRepository.archive(habit)
    }
    
    func unarchiveHabit(_ habit: Habit) async throws {
        try await habitRepository.unarchive(habit)
        
        if habit.reminderEnabled {
            try await scheduleHabitReminders(habit)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateDailyHabitsStatus() async throws {
        let habits = try await getActiveHabits()
        let today = Date()
        
        for habit in habits {
            if habit.shouldTrackForDate(today) {
                // Проверяем streak и обновляем статистику
                let _ = habit.currentStreak
            }
        }
    }
}

// MARK: - HabitService Extensions

extension HabitService {
    
    /// Получает привычки с самыми длинными streak
    func getTopStreakHabits(limit: Int = 5) async throws -> [Habit] {
        let habits = try await getActiveHabits()
        return Array(habits.sorted { $0.currentStreak > $1.currentStreak }.prefix(limit))
    }
    
    /// Получает привычки с лучшим процентом выполнения
    func getTopCompletionRateHabits(limit: Int = 5) async throws -> [Habit] {
        let habits = try await getActiveHabits()
        return Array(habits.sorted { $0.completionRate > $1.completionRate }.prefix(limit))
    }
    
    /// Получает общую статистику по всем привычкам
    func getOverallStatistics() async throws -> OverallHabitStatistics {
        let habits = try await getActiveHabits()
        let todayHabits = try await getTodayHabits()
        
        let completedToday = todayHabits.filter { $0.isCompletedToday }.count
        let totalToday = todayHabits.count
        
        let totalStreaks = habits.reduce(0) { $0 + $1.currentStreak }
        let averageStreak = habits.isEmpty ? 0 : Double(totalStreaks) / Double(habits.count)
        
        let totalCompletionRate = habits.reduce(0.0) { $0 + $1.completionRate }
        let averageCompletionRate = habits.isEmpty ? 0 : totalCompletionRate / Double(habits.count)
        
        return OverallHabitStatistics(
            totalHabits: habits.count,
            completedToday: completedToday,
            totalToday: totalToday,
            averageStreak: averageStreak,
            averageCompletionRate: averageCompletionRate
        )
    }
    
    /// Получает привычки, которые нуждаются в выполнении сегодня
    func getHabitsNeedingAttention() async throws -> [Habit] {
        let todayHabits = try await getTodayHabits()
        return todayHabits.filter { !$0.isCompletedToday }
    }
}

// MARK: - Supporting Types

struct OverallHabitStatistics {
    let totalHabits: Int
    let completedToday: Int
    let totalToday: Int
    let averageStreak: Double
    let averageCompletionRate: Double
    
    var todayCompletionRate: Double {
        return totalToday > 0 ? Double(completedToday) / Double(totalToday) : 0.0
    }
    
    var habitsRemaining: Int {
        return totalToday - completedToday
    }
} 