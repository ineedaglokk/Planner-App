import Foundation
import SwiftUI

// MARK: - HabitsListViewModel

@Observable
final class HabitsListViewModel {
    
    // MARK: - State
    
    struct State {
        var habits: [Habit] = []
        var filteredHabits: [Habit] = []
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var error: AppError?
        var searchText: String = ""
        var selectedFilter: HabitFilter = .all
        var selectedSort: HabitSort = .name
        var viewMode: ViewMode = .list
        var showCompletedHabits: Bool = true
        var selectedHabit: Habit?
        var showingCreateHabit: Bool = false
        var showingEditHabit: Bool = false
        var habitToDelete: Habit?
        var showingDeleteAlert: Bool = false
    }
    
    // MARK: - Input
    
    enum Input {
        case loadHabits
        case refreshHabits
        case searchTextChanged(String)
        case filterChanged(HabitFilter)
        case sortChanged(HabitSort)
        case viewModeChanged(ViewMode)
        case toggleShowCompleted
        case habitSelected(Habit)
        case toggleHabitCompletion(Habit)
        case incrementHabitValue(Habit)
        case createHabitTapped
        case editHabitTapped(Habit)
        case deleteHabitTapped(Habit)
        case confirmDelete
        case cancelDelete
        case dismissError
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let habitService: HabitServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let gameService: GameServiceProtocol
    private let user: User
    
    // MARK: - Initialization
    
    init(
        habitService: HabitServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol,
        gameService: GameServiceProtocol,
        user: User
    ) {
        self.habitService = habitService
        self.errorHandlingService = errorHandlingService
        self.gameService = gameService
        self.user = user
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadHabits:
                await loadHabits()
            case .refreshHabits:
                await refreshHabits()
            case .searchTextChanged(let text):
                state.searchText = text
                await filterAndSortHabits()
            case .filterChanged(let filter):
                state.selectedFilter = filter
                await filterAndSortHabits()
            case .sortChanged(let sort):
                state.selectedSort = sort
                await filterAndSortHabits()
            case .viewModeChanged(let mode):
                state.viewMode = mode
            case .toggleShowCompleted:
                state.showCompletedHabits.toggle()
                await filterAndSortHabits()
            case .habitSelected(let habit):
                state.selectedHabit = habit
            case .toggleHabitCompletion(let habit):
                await toggleHabitCompletion(habit)
            case .incrementHabitValue(let habit):
                await incrementHabitValue(habit)
            case .createHabitTapped:
                state.showingCreateHabit = true
            case .editHabitTapped(let habit):
                state.selectedHabit = habit
                state.showingEditHabit = true
            case .deleteHabitTapped(let habit):
                state.habitToDelete = habit
                state.showingDeleteAlert = true
            case .confirmDelete:
                await deleteHabit()
            case .cancelDelete:
                state.habitToDelete = nil
                state.showingDeleteAlert = false
            case .dismissError:
                state.error = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadHabits() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let habits = try await habitService.getActiveHabits()
            state.habits = habits
            await filterAndSortHabits()
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading habits"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshHabits() async {
        state.isRefreshing = true
        
        do {
            let habits = try await habitService.getActiveHabits()
            state.habits = habits
            await filterAndSortHabits()
            state.error = nil
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Refreshing habits"))
        }
        
        state.isRefreshing = false
    }
    
    @MainActor
    private func filterAndSortHabits() async {
        var filtered = state.habits
        
        // Apply search filter
        if !state.searchText.isEmpty {
            filtered = filtered.filter { habit in
                habit.name.localizedCaseInsensitiveContains(state.searchText) ||
                (habit.description?.localizedCaseInsensitiveContains(state.searchText) ?? false)
            }
        }
        
        // Apply category filter
        switch state.selectedFilter {
        case .all:
            break
        case .today:
            filtered = filtered.filter { $0.shouldTrackForDate(Date()) }
        case .completed:
            filtered = filtered.filter { $0.isCompletedToday }
        case .pending:
            filtered = filtered.filter { !$0.isCompletedToday && $0.shouldTrackForDate(Date()) }
        case .streaks:
            filtered = filtered.filter { $0.currentStreak > 0 }
        case .category(let category):
            filtered = filtered.filter { $0.category?.id == category.id }
        }
        
        // Apply completion visibility
        if !state.showCompletedHabits {
            filtered = filtered.filter { !$0.isCompletedToday }
        }
        
        // Apply sorting
        switch state.selectedSort {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .streak:
            filtered.sort { $0.currentStreak > $1.currentStreak }
        case .completionRate:
            filtered.sort { $0.completionRate > $1.completionRate }
        case .created:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .lastCompleted:
            filtered.sort { (first, second) in
                let firstLastEntry = first.entries.max(by: { $0.date < $1.date })?.date ?? Date.distantPast
                let secondLastEntry = second.entries.max(by: { $0.date < $1.date })?.date ?? Date.distantPast
                return firstLastEntry > secondLastEntry
            }
        }
        
        state.filteredHabits = filtered
    }
    
    @MainActor
    private func toggleHabitCompletion(_ habit: Habit) async {
        do {
            let wasCompleted = try await habitService.toggleHabitCompletion(habit)
            
            // 🎮 Trigger gamification if habit was completed
            if wasCompleted {
                try await gameService.processHabitCompletion(habit, for: user)
            }
            
            // Update local state
            if let index = state.habits.firstIndex(where: { $0.id == habit.id }) {
                state.habits[index] = habit
            }
            
            await filterAndSortHabits()
            
            // Show success feedback
            await showSuccessFeedback(for: habit, completed: wasCompleted)
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Toggling habit completion"))
        }
    }
    
    @MainActor
    private func incrementHabitValue(_ habit: Habit) async {
        do {
            let _ = try await habitService.incrementHabitValue(habit, date: Date(), by: 1)
            
            // Update local state
            if let index = state.habits.firstIndex(where: { $0.id == habit.id }) {
                state.habits[index] = habit
            }
            
            await filterAndSortHabits()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Incrementing habit value"))
        }
    }
    
    @MainActor
    private func deleteHabit() async {
        guard let habit = state.habitToDelete else { return }
        
        do {
            try await habitService.deleteHabit(habit)
            
            // Remove from local state
            state.habits.removeAll { $0.id == habit.id }
            await filterAndSortHabits()
            
            state.habitToDelete = nil
            state.showingDeleteAlert = false
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Deleting habit"))
            
            state.habitToDelete = nil
            state.showingDeleteAlert = false
        }
    }
    
    @MainActor
    private func showSuccessFeedback(for habit: Habit, completed: Bool) async {
        // This could trigger haptic feedback or show a toast
        // For now, we'll just log the success
        #if DEBUG
        print("Habit \(habit.name) \(completed ? "completed" : "uncompleted")")
        #endif
    }
}

// MARK: - Supporting Types

enum HabitFilter: CaseIterable, Hashable {
    case all
    case today
    case completed
    case pending
    case streaks
    case category(Category)
    
    var title: String {
        switch self {
        case .all:
            return "Все"
        case .today:
            return "Сегодня"
        case .completed:
            return "Выполнено"
        case .pending:
            return "Ожидает"
        case .streaks:
            return "Серии"
        case .category(let category):
            return category.name
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .today:
            return "calendar"
        case .completed:
            return "checkmark.circle"
        case .pending:
            return "clock"
        case .streaks:
            return "flame"
        case .category:
            return "folder"
        }
    }
    
    static var allCases: [HabitFilter] {
        return [.all, .today, .completed, .pending, .streaks]
    }
}

enum HabitSort: CaseIterable, Hashable {
    case name
    case streak
    case completionRate
    case created
    case lastCompleted
    
    var title: String {
        switch self {
        case .name:
            return "По названию"
        case .streak:
            return "По серии"
        case .completionRate:
            return "По проценту"
        case .created:
            return "По дате создания"
        case .lastCompleted:
            return "По последнему выполнению"
        }
    }
    
    var icon: String {
        switch self {
        case .name:
            return "textformat.abc"
        case .streak:
            return "flame"
        case .completionRate:
            return "percent"
        case .created:
            return "calendar.badge.plus"
        case .lastCompleted:
            return "clock.arrow.circlepath"
        }
    }
}

enum ViewMode: CaseIterable {
    case list
    case grid
    
    var title: String {
        switch self {
        case .list:
            return "Список"
        case .grid:
            return "Сетка"
        }
    }
    
    var icon: String {
        switch self {
        case .list:
            return "list.bullet"
        case .grid:
            return "square.grid.2x2"
        }
    }
}

// MARK: - Extensions

extension HabitsListViewModel {
    
    /// Получает статистику для отображения в заголовке
    var headerStats: HeaderStats {
        let today = Date()
        let todayHabits = state.habits.filter { $0.shouldTrackForDate(today) }
        let completed = todayHabits.filter { $0.isCompletedToday }
        let totalStreak = state.habits.reduce(0) { $0 + $1.currentStreak }
        
        return HeaderStats(
            totalHabits: state.habits.count,
            todayTotal: todayHabits.count,
            todayCompleted: completed.count,
            totalStreak: totalStreak,
            completionRate: todayHabits.isEmpty ? 0 : Double(completed.count) / Double(todayHabits.count)
        )
    }
    
    /// Проверяет, есть ли активные привычки
    var hasActiveHabits: Bool {
        !state.habits.isEmpty
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        !state.isLoading && state.filteredHabits.isEmpty
    }
    
    /// Получает сообщение для пустого состояния
    var emptyStateMessage: String {
        if !state.searchText.isEmpty {
            return "Привычки не найдены"
        } else if state.selectedFilter != .all {
            return "Нет привычек в этой категории"
        } else {
            return "У вас пока нет привычек"
        }
    }
}

struct HeaderStats {
    let totalHabits: Int
    let todayTotal: Int
    let todayCompleted: Int
    let totalStreak: Int
    let completionRate: Double
} 