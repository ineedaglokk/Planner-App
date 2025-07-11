import Foundation
import SwiftData

// MARK: - HabitRepository Protocol

protocol HabitRepositoryProtocol {
    func fetchActiveHabits() async throws -> [Habit]
    func fetchAllHabits() async throws -> [Habit]
    func fetchHabit(by id: UUID) async throws -> Habit?
    func fetchHabitsForToday() async throws -> [Habit]
    func save(_ habit: Habit) async throws
    func update(_ habit: Habit) async throws
    func delete(_ habit: Habit) async throws
    func markHabitComplete(_ habit: Habit, date: Date, value: Int?) async throws -> HabitEntry
    func incrementHabitValue(_ habit: Habit, date: Date, by amount: Int) async throws -> HabitEntry
    func getHabitEntry(habit: Habit, date: Date) async throws -> HabitEntry?
    func getHabitEntries(habit: Habit, from startDate: Date, to endDate: Date) async throws -> [HabitEntry]
    func archive(_ habit: Habit) async throws
    func unarchive(_ habit: Habit) async throws
    func getStatistics(for habit: Habit, period: StatisticsPeriod) async throws -> HabitStatistics
}

// MARK: - HabitRepository Implementation

final class HabitRepository: HabitRepositoryProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    
    // MARK: - Initialization
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }
    
    // MARK: - Fetch Methods
    
    func fetchActiveHabits() async throws -> [Habit] {
        let predicate = #Predicate<Habit> { habit in
            habit.isActive && !habit.isArchived
        }
        return try await dataService.fetch(Habit.self, predicate: predicate)
    }
    
    func fetchAllHabits() async throws -> [Habit] {
        return try await dataService.fetch(Habit.self, predicate: nil)
    }
    
    func fetchHabit(by id: UUID) async throws -> Habit? {
        let predicate = #Predicate<Habit> { habit in
            habit.id == id
        }
        return try await dataService.fetchOne(Habit.self, predicate: predicate)
    }
    
    func fetchHabitsForToday() async throws -> [Habit] {
        let today = Date()
        let activeHabits = try await fetchActiveHabits()
        
        return activeHabits.filter { habit in
            habit.shouldTrackForDate(today)
        }
    }
    
    // MARK: - CRUD Operations
    
    func save(_ habit: Habit) async throws {
        try habit.validate()
        try await dataService.save(habit)
    }
    
    func update(_ habit: Habit) async throws {
        try habit.validate()
        habit.updateTimestamp()
        habit.markForSync()
        try await dataService.update(habit)
    }
    
    func delete(_ habit: Habit) async throws {
        try await dataService.delete(habit)
    }
    
    // MARK: - Habit Tracking
    
    func markHabitComplete(_ habit: Habit, date: Date = Date(), value: Int? = nil) async throws -> HabitEntry {
        let entry = habit.markCompleted(on: date, value: value)
        try await dataService.save(entry)
        try await update(habit)
        return entry
    }
    
    func incrementHabitValue(_ habit: Habit, date: Date = Date(), by amount: Int = 1) async throws -> HabitEntry {
        let entry = habit.incrementValue(on: date, by: amount)
        try await dataService.save(entry)
        try await update(habit)
        return entry
    }
    
    func getHabitEntry(habit: Habit, date: Date) async throws -> HabitEntry? {
        return habit.getEntryForDate(date)
    }
    
    func getHabitEntries(habit: Habit, from startDate: Date, to endDate: Date) async throws -> [HabitEntry] {
        let predicate = #Predicate<HabitEntry> { entry in
            entry.habit?.id == habit.id &&
            entry.date >= startDate &&
            entry.date <= endDate
        }
        return try await dataService.fetch(HabitEntry.self, predicate: predicate)
    }
    
    // MARK: - Archive Operations
    
    func archive(_ habit: Habit) async throws {
        habit.archive()
        try await update(habit)
    }
    
    func unarchive(_ habit: Habit) async throws {
        habit.unarchive()
        try await update(habit)
    }
    
    // MARK: - Statistics
    
    func getStatistics(for habit: Habit, period: StatisticsPeriod) async throws -> HabitStatistics {
        let (startDate, endDate) = period.dateRange
        let entries = try await getHabitEntries(habit: habit, from: startDate, to: endDate)
        
        return HabitStatistics(
            habit: habit,
            period: period,
            entries: entries,
            currentStreak: habit.currentStreak,
            longestStreak: habit.longestStreak,
            completionRate: habit.completionRate,
            totalCompletions: habit.totalCompletions,
            bestDayResult: habit.bestDayResult
        )
    }
}

// MARK: - Supporting Types

enum StatisticsPeriod {
    case week
    case month
    case threeMonths
    case year
    case custom(startDate: Date, endDate: Date)
    
    var dateRange: (startDate: Date, endDate: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? now
            return (startOfWeek, endOfWeek)
            
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .day, value: -1, 
                                         to: calendar.date(byAdding: .month, value: 1, to: startOfMonth)!) ?? now
            return (startOfMonth, endOfMonth)
            
        case .threeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (threeMonthsAgo, now)
            
        case .year:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.date(byAdding: .day, value: -1,
                                        to: calendar.date(byAdding: .year, value: 1, to: startOfYear)!) ?? now
            return (startOfYear, endOfYear)
            
        case .custom(let startDate, let endDate):
            return (startDate, endDate)
        }
    }
}

struct HabitStatistics {
    let habit: Habit
    let period: StatisticsPeriod
    let entries: [HabitEntry]
    let currentStreak: Int
    let longestStreak: Int
    let completionRate: Double
    let totalCompletions: Int
    let bestDayResult: Int
    
    var averageDailyValue: Double {
        let totalDays = period.dateRange.1.timeIntervalSince(period.dateRange.0) / (24 * 60 * 60)
        return totalDays > 0 ? Double(totalCompletions) / totalDays : 0
    }
    
    var completedDays: Int {
        entries.count
    }
} 