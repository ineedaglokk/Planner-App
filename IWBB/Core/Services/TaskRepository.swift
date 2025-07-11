import Foundation
import SwiftData

// MARK: - TaskRepository Protocol

protocol TaskRepositoryProtocol {
    func fetchActiveTasks() async throws -> [Task]
    func fetchAllTasks() async throws -> [Task]
    func fetchTask(by id: UUID) async throws -> Task?
    func fetchTasksForToday() async throws -> [Task]
    func fetchTasksForTomorrow() async throws -> [Task]
    func fetchTasksThisWeek() async throws -> [Task]
    func fetchTasksLater() async throws -> [Task]
    func fetchTasksByPriority(_ priority: Priority) async throws -> [Task]
    func fetchTasksByStatus(_ status: TaskStatus) async throws -> [Task]
    func fetchTasksByCategory(_ category: Category) async throws -> [Task]
    func fetchTasksWithSearch(_ searchText: String) async throws -> [Task]
    func fetchSubtasks(for parentTask: Task) async throws -> [Task]
    func fetchDependentTasks(for task: Task) async throws -> [Task]
    
    func save(_ task: Task) async throws
    func update(_ task: Task) async throws
    func delete(_ task: Task) async throws
    func batchUpdate(_ tasks: [Task]) async throws
    func batchDelete(_ tasks: [Task]) async throws
    
    func markTaskComplete(_ task: Task) async throws
    func markTaskIncomplete(_ task: Task) async throws
    func updateTaskStatus(_ task: Task, status: TaskStatus) async throws
    func updateTaskPriority(_ task: Task, priority: Priority) async throws
    
    func archive(_ task: Task) async throws
    func unarchive(_ task: Task) async throws
    func getTaskStatistics(for period: StatisticsPeriod) async throws -> TaskStatistics
}

// MARK: - TaskRepository Implementation

final class TaskRepository: TaskRepositoryProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    
    // MARK: - Initialization
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }
    
    // MARK: - Fetch Methods
    
    func fetchActiveTasks() async throws -> [Task] {
        let predicate = #Predicate<Task> { task in
            !task.isArchived && task.status != .cancelled
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchAllTasks() async throws -> [Task] {
        return try await dataService.fetch(Task.self, predicate: nil)
    }
    
    func fetchTask(by id: UUID) async throws -> Task? {
        let predicate = #Predicate<Task> { task in
            task.id == id
        }
        return try await dataService.fetchOne(Task.self, predicate: predicate)
    }
    
    func fetchTasksForToday() async throws -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = #Predicate<Task> { task in
            !task.isArchived && 
            task.status != .cancelled &&
            task.dueDate != nil &&
            task.dueDate! >= today &&
            task.dueDate! < tomorrow
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksForTomorrow() async throws -> [Task] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
        
        let predicate = #Predicate<Task> { task in
            !task.isArchived && 
            task.status != .cancelled &&
            task.dueDate != nil &&
            task.dueDate! >= tomorrow &&
            task.dueDate! < dayAfterTomorrow
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksThisWeek() async throws -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekFromToday = calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
        
        let predicate = #Predicate<Task> { task in
            !task.isArchived && 
            task.status != .cancelled &&
            task.dueDate != nil &&
            task.dueDate! >= dayAfterTomorrow &&
            task.dueDate! < weekFromToday
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksLater() async throws -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekFromToday = calendar.date(byAdding: .weekOfYear, value: 1, to: today)!
        
        let predicate = #Predicate<Task> { task in
            !task.isArchived && 
            task.status != .cancelled &&
            (task.dueDate == nil || task.dueDate! >= weekFromToday)
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksByPriority(_ priority: Priority) async throws -> [Task] {
        let predicate = #Predicate<Task> { task in
            !task.isArchived && task.priority == priority
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksByStatus(_ status: TaskStatus) async throws -> [Task] {
        let predicate = #Predicate<Task> { task in
            !task.isArchived && task.status == status
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksByCategory(_ category: Category) async throws -> [Task] {
        let predicate = #Predicate<Task> { task in
            !task.isArchived && task.category?.id == category.id
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchTasksWithSearch(_ searchText: String) async throws -> [Task] {
        let lowercaseSearchText = searchText.lowercased()
        let predicate = #Predicate<Task> { task in
            !task.isArchived && (
                task.title.lowercased().contains(lowercaseSearchText) ||
                (task.description != nil && task.description!.lowercased().contains(lowercaseSearchText)) ||
                task.tags.contains { $0.lowercased().contains(lowercaseSearchText) }
            )
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchSubtasks(for parentTask: Task) async throws -> [Task] {
        let predicate = #Predicate<Task> { task in
            !task.isArchived && task.parentTask?.id == parentTask.id
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    func fetchDependentTasks(for task: Task) async throws -> [Task] {
        let predicate = #Predicate<Task> { dependentTask in
            !dependentTask.isArchived && 
            dependentTask.prerequisiteTasks.contains { $0.id == task.id }
        }
        return try await dataService.fetch(Task.self, predicate: predicate)
    }
    
    // MARK: - CRUD Operations
    
    func save(_ task: Task) async throws {
        try task.validate()
        try await dataService.save(task)
    }
    
    func update(_ task: Task) async throws {
        try task.validate()
        task.updateTimestamp()
        task.markForSync()
        try await dataService.update(task)
    }
    
    func delete(_ task: Task) async throws {
        try await dataService.delete(task)
    }
    
    func batchUpdate(_ tasks: [Task]) async throws {
        for task in tasks {
            try task.validate()
            task.updateTimestamp()
            task.markForSync()
        }
        try await dataService.batchSave(tasks)
    }
    
    func batchDelete(_ tasks: [Task]) async throws {
        try await dataService.batchDelete(tasks)
    }
    
    // MARK: - Task Status Management
    
    func markTaskComplete(_ task: Task) async throws {
        task.markCompleted()
        try await update(task)
    }
    
    func markTaskIncomplete(_ task: Task) async throws {
        task.status = .pending
        task.completedDate = nil
        task.actualDuration = nil
        try await update(task)
    }
    
    func updateTaskStatus(_ task: Task, status: TaskStatus) async throws {
        guard task.status.canTransitionTo.contains(status) else {
            throw ModelValidationError.missingRequiredField("Невозможно изменить статус с \(task.status.displayName) на \(status.displayName)")
        }
        
        task.status = status
        
        switch status {
        case .inProgress:
            task.start()
        case .completed:
            task.markCompleted()
        case .cancelled:
            task.cancel()
        case .onHold:
            task.pause()
        case .pending:
            if task.status == .inProgress {
                task.pause()
            }
        }
        
        try await update(task)
    }
    
    func updateTaskPriority(_ task: Task, priority: Priority) async throws {
        task.priority = priority
        try await update(task)
    }
    
    // MARK: - Archive Operations
    
    func archive(_ task: Task) async throws {
        task.archive()
        try await update(task)
    }
    
    func unarchive(_ task: Task) async throws {
        task.unarchive()
        try await update(task)
    }
    
    // MARK: - Statistics
    
    func getTaskStatistics(for period: StatisticsPeriod) async throws -> TaskStatistics {
        let (startDate, endDate) = period.dateRange
        
        let predicate = #Predicate<Task> { task in
            !task.isArchived &&
            task.createdAt >= startDate &&
            task.createdAt <= endDate
        }
        
        let tasks = try await dataService.fetch(Task.self, predicate: predicate)
        
        let completedTasks = tasks.filter { $0.status == .completed }
        let overdueTasks = tasks.filter { $0.isOverdue }
        let highPriorityTasks = tasks.filter { $0.priority == .high || $0.priority == .urgent }
        
        return TaskStatistics(
            period: period,
            totalTasks: tasks.count,
            completedTasks: completedTasks.count,
            overdueTasks: overdueTasks.count,
            highPriorityTasks: highPriorityTasks.count,
            averageCompletionTime: calculateAverageCompletionTime(completedTasks),
            productivityScore: calculateProductivityScore(tasks)
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateAverageCompletionTime(_ completedTasks: [Task]) -> TimeInterval {
        let tasksWithDuration = completedTasks.compactMap { $0.actualDuration }
        guard !tasksWithDuration.isEmpty else { return 0 }
        
        let totalDuration = tasksWithDuration.reduce(0, +)
        return totalDuration / Double(tasksWithDuration.count)
    }
    
    private func calculateProductivityScore(_ tasks: [Task]) -> Double {
        guard !tasks.isEmpty else { return 0.0 }
        
        let completedTasks = tasks.filter { $0.status == .completed }
        let overdueTasks = tasks.filter { $0.isOverdue }
        let highPriorityCompleted = completedTasks.filter { $0.priority == .high || $0.priority == .urgent }
        
        let completionRate = Double(completedTasks.count) / Double(tasks.count)
        let overdueRate = Double(overdueTasks.count) / Double(tasks.count)
        let priorityCompletionRate = tasks.isEmpty ? 0.0 : Double(highPriorityCompleted.count) / Double(tasks.count)
        
        // Формула продуктивности: (completion_rate * 0.6) + (priority_completion_rate * 0.3) - (overdue_rate * 0.1)
        return min(1.0, max(0.0, (completionRate * 0.6) + (priorityCompletionRate * 0.3) - (overdueRate * 0.1)))
    }
}

// MARK: - Supporting Types

enum StatisticsPeriod {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case custom(startDate: Date, endDate: Date)
    
    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)!.end
            return (startOfWeek, endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)!.start
            let endOfMonth = calendar.dateInterval(of: .month, for: now)!.end
            return (startOfMonth, endOfMonth)
            
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)!.start
            let endOfYear = calendar.dateInterval(of: .year, for: now)!.end
            return (startOfYear, endOfYear)
            
        case .custom(let startDate, let endDate):
            return (startDate, endDate)
        }
    }
}

struct TaskStatistics {
    let period: StatisticsPeriod
    let totalTasks: Int
    let completedTasks: Int
    let overdueTasks: Int
    let highPriorityTasks: Int
    let averageCompletionTime: TimeInterval
    let productivityScore: Double
    
    var completionRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    var overdueRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(overdueTasks) / Double(totalTasks)
    }
} 