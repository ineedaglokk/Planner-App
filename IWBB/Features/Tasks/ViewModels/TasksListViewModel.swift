import Foundation
import SwiftUI

// MARK: - TasksListViewModel

@Observable
final class TasksListViewModel {
    
    // MARK: - State
    
    struct State {
        var tasks: [Task] = []
        var filteredTasks: [Task] = []
        var isLoading: Bool = false
        var error: AppError?
        
        // Фильтрация и поиск
        var searchText: String = ""
        var selectedCategory: Category?
        var selectedPriority: Priority?
        var selectedStatus: TaskStatus?
        var selectedTimeFilter: TaskTimeFilter = .all
        
        // Группировка
        var groupBy: TaskGrouping = .dueDate
        var sortBy: TaskSorting = .priority
        
        // Выбор задач
        var selectedTasks: Set<UUID> = []
        var isSelectionMode: Bool = false
        
        // UI состояния
        var showCreateTask: Bool = false
        var showFilters: Bool = false
        var refreshID: UUID = UUID()
    }
    
    // MARK: - Input
    
    enum Input {
        case loadTasks
        case refreshTasks
        case searchTextChanged(String)
        case categoryFilterChanged(Category?)
        case priorityFilterChanged(Priority?)
        case statusFilterChanged(TaskStatus?)
        case timeFilterChanged(TaskTimeFilter)
        case groupingChanged(TaskGrouping)
        case sortingChanged(TaskSorting)
        case taskSelected(UUID)
        case taskDeselected(UUID)
        case toggleSelectionMode
        case clearSelection
        case toggleTaskCompletion(Task)
        case deleteTask(Task)
        case deleteTasks([Task])
        case bulkUpdatePriority([Task], Priority)
        case bulkUpdateCategory([Task], Category?)
        case archiveTasks([Task])
        case showCreateTask
        case hideCreateTask
        case toggleFilters
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let taskService: TaskServiceProtocol
    private let dateParser = DateParser()
    
    // MARK: - Computed Properties
    
    var groupedTasks: [TaskGroup] {
        groupTasks(state.filteredTasks, by: state.groupBy)
    }
    
    var hasActiveTasks: Bool {
        !state.filteredTasks.isEmpty
    }
    
    var selectedTasksCount: Int {
        state.selectedTasks.count
    }
    
    var canPerformBulkActions: Bool {
        state.isSelectionMode && !state.selectedTasks.isEmpty
    }
    
    // MARK: - Initialization
    
    init(taskService: TaskServiceProtocol) {
        self.taskService = taskService
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadTasks:
                await loadTasks()
            case .refreshTasks:
                await refreshTasks()
            case .searchTextChanged(let text):
                state.searchText = text
                await applyFilters()
            case .categoryFilterChanged(let category):
                state.selectedCategory = category
                await applyFilters()
            case .priorityFilterChanged(let priority):
                state.selectedPriority = priority
                await applyFilters()
            case .statusFilterChanged(let status):
                state.selectedStatus = status
                await applyFilters()
            case .timeFilterChanged(let filter):
                state.selectedTimeFilter = filter
                await applyFilters()
            case .groupingChanged(let grouping):
                state.groupBy = grouping
                state.refreshID = UUID()
            case .sortingChanged(let sorting):
                state.sortBy = sorting
                await applyFilters()
            case .taskSelected(let id):
                state.selectedTasks.insert(id)
            case .taskDeselected(let id):
                state.selectedTasks.remove(id)
            case .toggleSelectionMode:
                state.isSelectionMode.toggle()
                if !state.isSelectionMode {
                    state.selectedTasks.removeAll()
                }
            case .clearSelection:
                state.selectedTasks.removeAll()
            case .toggleTaskCompletion(let task):
                await toggleTaskCompletion(task)
            case .deleteTask(let task):
                await deleteTask(task)
            case .deleteTasks(let tasks):
                await deleteTasks(tasks)
            case .bulkUpdatePriority(let tasks, let priority):
                await bulkUpdatePriority(tasks, priority: priority)
            case .bulkUpdateCategory(let tasks, let category):
                await bulkUpdateCategory(tasks, category: category)
            case .archiveTasks(let tasks):
                await archiveTasks(tasks)
            case .showCreateTask:
                state.showCreateTask = true
            case .hideCreateTask:
                state.showCreateTask = false
            case .toggleFilters:
                state.showFilters.toggle()
            }
        }
    }
    
    // MARK: - Task Operations
    
    private func loadTasks() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let tasks = try await fetchTasksForCurrentFilter()
            state.tasks = tasks
            await applyFilters()
        } catch {
            state.error = AppError.from(error)
        }
        
        state.isLoading = false
    }
    
    private func refreshTasks() async {
        do {
            let tasks = try await fetchTasksForCurrentFilter()
            state.tasks = tasks
            await applyFilters()
            state.refreshID = UUID()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func fetchTasksForCurrentFilter() async throws -> [Task] {
        switch state.selectedTimeFilter {
        case .all:
            return try await taskService.getActiveTasks()
        case .today:
            return try await taskService.getTodayTasks()
        case .tomorrow:
            return try await taskService.getTomorrowTasks()
        case .thisWeek:
            return try await taskService.getThisWeekTasks()
        case .later:
            return try await taskService.getLaterTasks()
        case .overdue:
            let allTasks = try await taskService.getActiveTasks()
            return allTasks.filter { $0.isOverdue }
        }
    }
    
    private func applyFilters() async {
        var filtered = state.tasks
        
        // Поиск по тексту
        if !state.searchText.isEmpty {
            do {
                let searchResults = try await taskService.searchTasks(state.searchText)
                filtered = filtered.filter { task in
                    searchResults.contains { $0.id == task.id }
                }
            } catch {
                // Fallback к локальному поиску
                filtered = filtered.filter { task in
                    task.title.localizedCaseInsensitiveContains(state.searchText) ||
                    (task.description?.localizedCaseInsensitiveContains(state.searchText) ?? false) ||
                    task.tags.contains { $0.localizedCaseInsensitiveContains(state.searchText) }
                }
            }
        }
        
        // Фильтр по категории
        if let category = state.selectedCategory {
            filtered = filtered.filter { $0.category?.id == category.id }
        }
        
        // Фильтр по приоритету
        if let priority = state.selectedPriority {
            filtered = filtered.filter { $0.priority == priority }
        }
        
        // Фильтр по статусу
        if let status = state.selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        // Сортировка
        filtered = sortTasks(filtered, by: state.sortBy)
        
        state.filteredTasks = filtered
    }
    
    private func toggleTaskCompletion(_ task: Task) async {
        do {
            if task.status == .completed {
                try await taskService.uncompleteTask(task)
            } else {
                try await taskService.completeTask(task)
            }
            await refreshTasks()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func deleteTask(_ task: Task) async {
        do {
            try await taskService.deleteTask(task)
            await refreshTasks()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func deleteTasks(_ tasks: [Task]) async {
        do {
            try await taskService.bulkDeleteTasks(tasks)
            state.selectedTasks.removeAll()
            await refreshTasks()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func bulkUpdatePriority(_ tasks: [Task], priority: Priority) async {
        do {
            let updatedTasks = tasks.map { task in
                task.priority = priority
                return task
            }
            try await taskService.bulkUpdateTasks(updatedTasks)
            state.selectedTasks.removeAll()
            await refreshTasks()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func bulkUpdateCategory(_ tasks: [Task], category: Category?) async {
        do {
            let updatedTasks = tasks.map { task in
                task.category = category
                return task
            }
            try await taskService.bulkUpdateTasks(updatedTasks)
            state.selectedTasks.removeAll()
            await refreshTasks()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func archiveTasks(_ tasks: [Task]) async {
        do {
            for task in tasks {
                try await taskService.archiveTask(task)
            }
            state.selectedTasks.removeAll()
            await refreshTasks()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    // MARK: - Sorting and Grouping
    
    private func sortTasks(_ tasks: [Task], by sorting: TaskSorting) -> [Task] {
        switch sorting {
        case .priority:
            return tasks.sorted { $0.priority.sortOrder > $1.priority.sortOrder }
        case .dueDate:
            return tasks.sorted { task1, task2 in
                switch (task1.dueDate, task2.dueDate) {
                case (nil, nil): return false
                case (nil, _): return false
                case (_, nil): return true
                case (let date1?, let date2?): return date1 < date2
                }
            }
        case .title:
            return tasks.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .createdDate:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .status:
            return tasks.sorted { $0.status.rawValue < $1.status.rawValue }
        }
    }
    
    private func groupTasks(_ tasks: [Task], by grouping: TaskGrouping) -> [TaskGroup] {
        switch grouping {
        case .none:
            return [TaskGroup(title: "Все задачи", tasks: tasks)]
            
        case .dueDate:
            return groupTasksByDueDate(tasks)
            
        case .priority:
            return groupTasksByPriority(tasks)
            
        case .status:
            return groupTasksByStatus(tasks)
            
        case .category:
            return groupTasksByCategory(tasks)
        }
    }
    
    private func groupTasksByDueDate(_ tasks: [Task]) -> [TaskGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let weekFromNow = calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
        
        var groups: [TaskGroup] = []
        
        // Просроченные
        let overdue = tasks.filter { $0.isOverdue }
        if !overdue.isEmpty {
            groups.append(TaskGroup(title: "Просроченные", tasks: overdue))
        }
        
        // Сегодня
        let todayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: today)
        }
        if !todayTasks.isEmpty {
            groups.append(TaskGroup(title: "Сегодня", tasks: todayTasks))
        }
        
        // Завтра
        let tomorrowTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: tomorrow)
        }
        if !tomorrowTasks.isEmpty {
            groups.append(TaskGroup(title: "Завтра", tasks: tomorrowTasks))
        }
        
        // На этой неделе
        let thisWeekTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate > tomorrow && dueDate < weekFromNow
        }
        if !thisWeekTasks.isEmpty {
            groups.append(TaskGroup(title: "На этой неделе", tasks: thisWeekTasks))
        }
        
        // Позже
        let laterTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return true }
            return dueDate >= weekFromNow
        }
        if !laterTasks.isEmpty {
            groups.append(TaskGroup(title: "Позже", tasks: laterTasks))
        }
        
        return groups
    }
    
    private func groupTasksByPriority(_ tasks: [Task]) -> [TaskGroup] {
        let urgentTasks = tasks.filter { $0.priority == .urgent }
        let highTasks = tasks.filter { $0.priority == .high }
        let mediumTasks = tasks.filter { $0.priority == .medium }
        let lowTasks = tasks.filter { $0.priority == .low }
        
        var groups: [TaskGroup] = []
        
        if !urgentTasks.isEmpty {
            groups.append(TaskGroup(title: "Срочные", tasks: urgentTasks))
        }
        if !highTasks.isEmpty {
            groups.append(TaskGroup(title: "Высокий приоритет", tasks: highTasks))
        }
        if !mediumTasks.isEmpty {
            groups.append(TaskGroup(title: "Средний приоритет", tasks: mediumTasks))
        }
        if !lowTasks.isEmpty {
            groups.append(TaskGroup(title: "Низкий приоритет", tasks: lowTasks))
        }
        
        return groups
    }
    
    private func groupTasksByStatus(_ tasks: [Task]) -> [TaskGroup] {
        let pendingTasks = tasks.filter { $0.status == .pending }
        let inProgressTasks = tasks.filter { $0.status == .inProgress }
        let completedTasks = tasks.filter { $0.status == .completed }
        let onHoldTasks = tasks.filter { $0.status == .onHold }
        
        var groups: [TaskGroup] = []
        
        if !pendingTasks.isEmpty {
            groups.append(TaskGroup(title: "Ожидающие", tasks: pendingTasks))
        }
        if !inProgressTasks.isEmpty {
            groups.append(TaskGroup(title: "В работе", tasks: inProgressTasks))
        }
        if !onHoldTasks.isEmpty {
            groups.append(TaskGroup(title: "Приостановленные", tasks: onHoldTasks))
        }
        if !completedTasks.isEmpty {
            groups.append(TaskGroup(title: "Выполненные", tasks: completedTasks))
        }
        
        return groups
    }
    
    private func groupTasksByCategory(_ tasks: [Task]) -> [TaskGroup] {
        let grouped = Dictionary(grouping: tasks) { task in
            task.category?.name ?? "Без категории"
        }
        
        return grouped.map { categoryName, tasks in
            TaskGroup(title: categoryName, tasks: tasks)
        }.sorted { $0.title < $1.title }
    }
    
    // MARK: - Helper Methods
    
    func getSelectedTasks() -> [Task] {
        return state.filteredTasks.filter { state.selectedTasks.contains($0.id) }
    }
    
    func clearFilters() {
        state.searchText = ""
        state.selectedCategory = nil
        state.selectedPriority = nil
        state.selectedStatus = nil
        state.selectedTimeFilter = .all
        
        Task {
            await applyFilters()
        }
    }
}

// MARK: - Supporting Types

enum TaskTimeFilter: String, CaseIterable {
    case all = "all"
    case today = "today"
    case tomorrow = "tomorrow"
    case thisWeek = "thisWeek"
    case later = "later"
    case overdue = "overdue"
    
    var displayName: String {
        switch self {
        case .all: return "Все"
        case .today: return "Сегодня"
        case .tomorrow: return "Завтра"
        case .thisWeek: return "На этой неделе"
        case .later: return "Позже"
        case .overdue: return "Просроченные"
        }
    }
    
    var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .today: return "sun.max"
        case .tomorrow: return "moon"
        case .thisWeek: return "calendar"
        case .later: return "clock"
        case .overdue: return "exclamationmark.triangle"
        }
    }
}

enum TaskGrouping: String, CaseIterable {
    case none = "none"
    case dueDate = "dueDate"
    case priority = "priority"
    case status = "status"
    case category = "category"
    
    var displayName: String {
        switch self {
        case .none: return "Без группировки"
        case .dueDate: return "По дате"
        case .priority: return "По приоритету"
        case .status: return "По статусу"
        case .category: return "По категории"
        }
    }
}

enum TaskSorting: String, CaseIterable {
    case priority = "priority"
    case dueDate = "dueDate"
    case title = "title"
    case createdDate = "createdDate"
    case status = "status"
    
    var displayName: String {
        switch self {
        case .priority: return "По приоритету"
        case .dueDate: return "По дате"
        case .title: return "По названию"
        case .createdDate: return "По дате создания"
        case .status: return "По статусу"
        }
    }
}

struct TaskGroup {
    let title: String
    let tasks: [Task]
} 