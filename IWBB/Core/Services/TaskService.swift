import Foundation
import SwiftData

// MARK: - TaskService Protocol

protocol TaskServiceProtocol: ServiceProtocol {
    func getActiveTasks() async throws -> [Task]
    func getTodayTasks() async throws -> [Task]
    func getTomorrowTasks() async throws -> [Task]
    func getThisWeekTasks() async throws -> [Task]
    func getLaterTasks() async throws -> [Task]
    func getTask(by id: UUID) async throws -> Task?
    func searchTasks(_ searchText: String) async throws -> [Task]
    func getTasksByCategory(_ category: Category) async throws -> [Task]
    func getTasksByPriority(_ priority: Priority) async throws -> [Task]
    func getTasksByStatus(_ status: TaskStatus) async throws -> [Task]
    
    func createTask(_ task: Task) async throws
    func updateTask(_ task: Task) async throws
    func deleteTask(_ task: Task) async throws
    func bulkUpdateTasks(_ tasks: [Task]) async throws
    func bulkDeleteTasks(_ tasks: [Task]) async throws
    
    func completeTask(_ task: Task) async throws
    func uncompleteTask(_ task: Task) async throws
    func startTask(_ task: Task) async throws
    func pauseTask(_ task: Task) async throws
    func cancelTask(_ task: Task) async throws
    func updateTaskPriority(_ task: Task, priority: Priority) async throws
    
    func addSubtask(_ subtask: Task, to parent: Task) async throws
    func removeSubtask(_ subtask: Task) async throws
    func addTaskDependency(_ task: Task, dependsOn prerequisite: Task) async throws
    func removeTaskDependency(_ task: Task, from prerequisite: Task) async throws
    
    func scheduleTaskReminder(_ task: Task) async throws
    func cancelTaskReminder(_ task: Task) async throws
    func scheduleTaskDeadlineNotification(_ task: Task) async throws
    
    func archiveTask(_ task: Task) async throws
    func unarchiveTask(_ task: Task) async throws
    func getTaskStatistics(period: StatisticsPeriod) async throws -> TaskStatistics
    
    func processRecurringTasks() async throws
    func checkOverdueTasks() async throws
    func syncTaskNotifications() async throws
}

// MARK: - TaskService Implementation

final class TaskService: TaskServiceProtocol {
    
    // MARK: - Properties
    
    private let taskRepository: TaskRepositoryProtocol
    private let notificationService: NotificationServiceProtocol
    
    var isInitialized: Bool = false
    
    // MARK: - Initialization
    
    init(
        taskRepository: TaskRepositoryProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.taskRepository = taskRepository
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        #if DEBUG
        print("Initializing TaskService...")
        #endif
        
        // Обновляем статусы просроченных задач
        try await checkOverdueTasks()
        
        // Обрабатываем повторяющиеся задачи
        try await processRecurringTasks()
        
        // Синхронизируем уведомления
        try await syncTaskNotifications()
        
        isInitialized = true
        
        #if DEBUG
        print("TaskService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("Cleaning up TaskService...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("TaskService cleaned up")
        #endif
    }
    
    // MARK: - Task Fetching
    
    func getActiveTasks() async throws -> [Task] {
        return try await taskRepository.fetchActiveTasks()
    }
    
    func getTodayTasks() async throws -> [Task] {
        return try await taskRepository.fetchTasksForToday()
    }
    
    func getTomorrowTasks() async throws -> [Task] {
        return try await taskRepository.fetchTasksForTomorrow()
    }
    
    func getThisWeekTasks() async throws -> [Task] {
        return try await taskRepository.fetchTasksThisWeek()
    }
    
    func getLaterTasks() async throws -> [Task] {
        return try await taskRepository.fetchTasksLater()
    }
    
    func getTask(by id: UUID) async throws -> Task? {
        return try await taskRepository.fetchTask(by: id)
    }
    
    func searchTasks(_ searchText: String) async throws -> [Task] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return try await taskRepository.fetchTasksWithSearch(searchText)
    }
    
    func getTasksByCategory(_ category: Category) async throws -> [Task] {
        return try await taskRepository.fetchTasksByCategory(category)
    }
    
    func getTasksByPriority(_ priority: Priority) async throws -> [Task] {
        return try await taskRepository.fetchTasksByPriority(priority)
    }
    
    func getTasksByStatus(_ status: TaskStatus) async throws -> [Task] {
        return try await taskRepository.fetchTasksByStatus(status)
    }
    
    // MARK: - Task Management
    
    func createTask(_ task: Task) async throws {
        try await taskRepository.save(task)
        
        // Планируем уведомления если есть дедлайн
        if let _ = task.dueDate {
            try await scheduleTaskDeadlineNotification(task)
        }
        
        // Планируем напоминание если установлено
        if let _ = task.reminderDate {
            try await scheduleTaskReminder(task)
        }
    }
    
    func updateTask(_ task: Task) async throws {
        try await taskRepository.update(task)
        
        // Обновляем уведомления
        await cancelTaskReminder(task)
        
        if let _ = task.dueDate {
            try await scheduleTaskDeadlineNotification(task)
        }
        
        if let _ = task.reminderDate {
            try await scheduleTaskReminder(task)
        }
    }
    
    func deleteTask(_ task: Task) async throws {
        // Отменяем все уведомления
        await cancelTaskReminder(task)
        
        // Удаляем задачу
        try await taskRepository.delete(task)
    }
    
    func bulkUpdateTasks(_ tasks: [Task]) async throws {
        try await taskRepository.batchUpdate(tasks)
        
        // Обновляем уведомления для всех задач
        for task in tasks {
            await cancelTaskReminder(task)
            
            if let _ = task.dueDate {
                try? await scheduleTaskDeadlineNotification(task)
            }
            
            if let _ = task.reminderDate {
                try? await scheduleTaskReminder(task)
            }
        }
    }
    
    func bulkDeleteTasks(_ tasks: [Task]) async throws {
        // Отменяем уведомления для всех задач
        for task in tasks {
            await cancelTaskReminder(task)
        }
        
        try await taskRepository.batchDelete(tasks)
    }
    
    // MARK: - Task Status Management
    
    func completeTask(_ task: Task) async throws {
        try await taskRepository.markTaskComplete(task)
        
        // Отменяем уведомления для завершенной задачи
        await cancelTaskReminder(task)
        
        // Создаем следующую повторяющуюся задачу если нужно
        if task.isRecurring, let pattern = task.recurringPattern {
            try await createNextRecurringTask(from: task, pattern: pattern)
        }
        
        // Проверяем зависимые задачи и разблокируем их
        try await checkAndUnblockDependentTasks(for: task)
    }
    
    func uncompleteTask(_ task: Task) async throws {
        try await taskRepository.markTaskIncomplete(task)
        
        // Планируем уведомления заново
        if let _ = task.dueDate {
            try await scheduleTaskDeadlineNotification(task)
        }
        
        if let _ = task.reminderDate {
            try await scheduleTaskReminder(task)
        }
    }
    
    func startTask(_ task: Task) async throws {
        guard task.canStart else {
            throw TaskError.cannotStartTaskWithUnfinishedPrerequisites
        }
        
        try await taskRepository.updateTaskStatus(task, status: .inProgress)
    }
    
    func pauseTask(_ task: Task) async throws {
        try await taskRepository.updateTaskStatus(task, status: .onHold)
    }
    
    func cancelTask(_ task: Task) async throws {
        try await taskRepository.updateTaskStatus(task, status: .cancelled)
        await cancelTaskReminder(task)
    }
    
    func updateTaskPriority(_ task: Task, priority: Priority) async throws {
        try await taskRepository.updateTaskPriority(task, priority: priority)
    }
    
    // MARK: - Subtasks and Dependencies
    
    func addSubtask(_ subtask: Task, to parent: Task) async throws {
        subtask.parentTask = parent
        subtask.user = parent.user
        try await taskRepository.save(subtask)
        try await taskRepository.update(parent)
    }
    
    func removeSubtask(_ subtask: Task) async throws {
        let parent = subtask.parentTask
        subtask.parentTask = nil
        
        try await taskRepository.update(subtask)
        
        if let parent = parent {
            try await taskRepository.update(parent)
        }
    }
    
    func addTaskDependency(_ task: Task, dependsOn prerequisite: Task) async throws {
        // Проверяем на циклические зависимости
        if await hasCyclicDependency(task: task, prerequisite: prerequisite) {
            throw TaskError.cyclicDependencyDetected
        }
        
        task.addPrerequisite(prerequisite)
        try await taskRepository.update(task)
        try await taskRepository.update(prerequisite)
    }
    
    func removeTaskDependency(_ task: Task, from prerequisite: Task) async throws {
        task.removePrerequisite(prerequisite)
        try await taskRepository.update(task)
        try await taskRepository.update(prerequisite)
    }
    
    // MARK: - Notifications
    
    func scheduleTaskReminder(_ task: Task) async throws {
        guard let reminderDate = task.reminderDate else { return }
        
        try await notificationService.scheduleTaskDeadline(
            task.id,
            title: task.title,
            deadline: reminderDate
        )
    }
    
    func cancelTaskReminder(_ task: Task) async {
        await notificationService.cancelNotification(for: "task-\(task.id.uuidString)")
    }
    
    func scheduleTaskDeadlineNotification(_ task: Task) async throws {
        guard let dueDate = task.dueDate else { return }
        
        // Уведомление за 1 день до дедлайна
        let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: dueDate)
        
        if let reminderDate = oneDayBefore, reminderDate > Date() {
            try await notificationService.scheduleTaskDeadline(
                task.id,
                title: "Дедлайн завтра: \(task.title)",
                deadline: reminderDate
            )
        }
    }
    
    // MARK: - Archive Operations
    
    func archiveTask(_ task: Task) async throws {
        try await taskRepository.archive(task)
        await cancelTaskReminder(task)
    }
    
    func unarchiveTask(_ task: Task) async throws {
        try await taskRepository.unarchive(task)
        
        // Восстанавливаем уведомления если нужно
        if let _ = task.dueDate, !task.status.isCompleted {
            try await scheduleTaskDeadlineNotification(task)
        }
        
        if let _ = task.reminderDate, !task.status.isCompleted {
            try await scheduleTaskReminder(task)
        }
    }
    
    // MARK: - Statistics
    
    func getTaskStatistics(period: StatisticsPeriod) async throws -> TaskStatistics {
        return try await taskRepository.getTaskStatistics(for: period)
    }
    
    // MARK: - Background Tasks
    
    func processRecurringTasks() async throws {
        let allTasks = try await taskRepository.fetchAllTasks()
        let completedRecurringTasks = allTasks.filter { 
            $0.isRecurring && $0.status == .completed && $0.recurringPattern != nil 
        }
        
        for task in completedRecurringTasks {
            guard let pattern = task.recurringPattern else { continue }
            
            // Проверяем, нужно ли создать новую задачу
            if shouldCreateNextRecurringTask(from: task, pattern: pattern) {
                try await createNextRecurringTask(from: task, pattern: pattern)
            }
        }
    }
    
    func checkOverdueTasks() async throws {
        let activeTasks = try await taskRepository.fetchActiveTasks()
        let overdueTasks = activeTasks.filter { $0.isOverdue && $0.status != .completed }
        
        // Опционально: можно изменить статус просроченных задач
        // или отправить уведомления
        for task in overdueTasks {
            #if DEBUG
            print("Task '\(task.title)' is overdue")
            #endif
        }
    }
    
    func syncTaskNotifications() async throws {
        let activeTasks = try await taskRepository.fetchActiveTasks()
        let tasksWithDeadlines = activeTasks.filter { 
            $0.dueDate != nil && !$0.status.isCompleted 
        }
        
        for task in tasksWithDeadlines {
            try await scheduleTaskDeadlineNotification(task)
        }
        
        let tasksWithReminders = activeTasks.filter { 
            $0.reminderDate != nil && !$0.status.isCompleted 
        }
        
        for task in tasksWithReminders {
            try await scheduleTaskReminder(task)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func createNextRecurringTask(from task: Task, pattern: RecurringPattern) async throws {
        guard let nextDate = pattern.nextDate(from: task.dueDate ?? Date()) else { return }
        
        let nextTask = Task(
            title: task.title,
            description: task.description,
            priority: task.priority,
            dueDate: nextDate,
            category: task.category,
            parentTask: task.parentTask,
            parentGoal: task.parentGoal
        )
        
        nextTask.isRecurring = true
        nextTask.recurringPattern = pattern
        nextTask.tags = task.tags
        nextTask.estimatedDuration = task.estimatedDuration
        nextTask.location = task.location
        nextTask.url = task.url
        nextTask.user = task.user
        
        try await createTask(nextTask)
    }
    
    private func shouldCreateNextRecurringTask(from task: Task, pattern: RecurringPattern) -> Bool {
        guard let completedDate = task.completedDate else { return false }
        guard let nextDate = pattern.nextDate(from: task.dueDate ?? completedDate) else { return false }
        
        // Проверяем, что следующая дата еще не прошла
        if let endDate = pattern.endDate, nextDate > endDate {
            return false
        }
        
        // Проверяем максимальное количество повторений
        if let maxOccurrences = pattern.maxOccurrences {
            // Здесь можно добавить логику подсчета существующих повторений
            // Пока возвращаем true
        }
        
        return true
    }
    
    private func hasCyclicDependency(task: Task, prerequisite: Task) async -> Bool {
        // Простая проверка на прямую циклическую зависимость
        if prerequisite.prerequisiteTasks.contains(where: { $0.id == task.id }) {
            return true
        }
        
        // Рекурсивная проверка на более глубокие циклы
        for prereq in prerequisite.prerequisiteTasks {
            if await hasCyclicDependency(task: task, prerequisite: prereq) {
                return true
            }
        }
        
        return false
    }
    
    private func checkAndUnblockDependentTasks(for completedTask: Task) async throws {
        let dependentTasks = try await taskRepository.fetchDependentTasks(for: completedTask)
        
        for dependentTask in dependentTasks {
            if dependentTask.canStart && dependentTask.status == .pending {
                // Опционально: можно автоматически изменить статус на готов к выполнению
                // или отправить уведомление пользователю
                #if DEBUG
                print("Task '\(dependentTask.title)' is now ready to start")
                #endif
            }
        }
    }
}

// MARK: - Task Error Types

enum TaskError: LocalizedError {
    case cannotStartTaskWithUnfinishedPrerequisites
    case cyclicDependencyDetected
    case invalidRecurringPattern
    case taskNotFound
    
    var errorDescription: String? {
        switch self {
        case .cannotStartTaskWithUnfinishedPrerequisites:
            return "Нельзя начать задачу пока не выполнены все предварительные задачи"
        case .cyclicDependencyDetected:
            return "Обнаружена циклическая зависимость между задачами"
        case .invalidRecurringPattern:
            return "Неверный паттерн повторения"
        case .taskNotFound:
            return "Задача не найдена"
        }
    }
} 