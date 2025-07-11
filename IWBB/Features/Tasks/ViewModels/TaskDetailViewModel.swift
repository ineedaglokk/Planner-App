import Foundation
import SwiftUI

// MARK: - TaskDetailViewModel

@Observable
final class TaskDetailViewModel {
    
    // MARK: - State
    
    struct State {
        var task: Task?
        var isLoading: Bool = false
        var error: AppError?
        
        // Subtasks
        var subtasks: [Task] = []
        var newSubtaskTitle: String = ""
        var isAddingSubtask: Bool = false
        
        // Dependencies
        var prerequisites: [Task] = []
        var dependentTasks: [Task] = []
        
        // Time tracking
        var isTimerRunning: Bool = false
        var startTime: Date?
        var elapsedTime: TimeInterval = 0
        var timerDisplayText: String = "00:00"
        
        // Comments/Notes
        var comments: [TaskComment] = []
        var newComment: String = ""
        
        // UI states
        var showEditTask: Bool = false
        var showDeleteConfirmation: Bool = false
        var showSubtaskOptions: Task?
        var showAddPrerequisite: Bool = false
        var showTimeTracker: Bool = false
        var showProgress: Bool = false
        
        // Analytics
        var statistics: TaskDetailStatistics?
        
        // Actions
        var actionHistory: [TaskAction] = []
        
        // Refresh
        var refreshID: UUID = UUID()
    }
    
    // MARK: - Input
    
    enum Input {
        case loadTask(UUID)
        case refreshTask
        case toggleTaskCompletion
        case startTask
        case pauseTask
        case cancelTask
        case updatePriority(Priority)
        case updateDueDate(Date?)
        case addSubtask(String)
        case removeSubtask(Task)
        case toggleSubtaskCompletion(Task)
        case addPrerequisite(Task)
        case removePrerequisite(Task)
        case startTimer
        case pauseTimer
        case stopTimer
        case addComment(String)
        case editComment(TaskComment, String)
        case deleteComment(TaskComment)
        case showEditTask
        case hideEditTask
        case deleteTask
        case archiveTask
        case duplicateTask
        case shareTask
        case exportTask
        case showSubtaskOptions(Task)
        case hideSubtaskOptions
        case toggleTimeTracker
        case toggleProgress
        case newSubtaskTitleChanged(String)
        case newCommentChanged(String)
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let taskService: TaskServiceProtocol
    private var timer: Timer?
    
    // MARK: - Computed Properties
    
    var progressPercentage: Double {
        guard let task = state.task else { return 0.0 }
        return task.progress
    }
    
    var completedSubtasksCount: Int {
        state.subtasks.filter { $0.status == .completed }.count
    }
    
    var totalSubtasksCount: Int {
        state.subtasks.count
    }
    
    var canStart: Bool {
        guard let task = state.task else { return false }
        return task.canStart && task.status == .pending
    }
    
    var canComplete: Bool {
        guard let task = state.task else { return false }
        return !task.status.isCompleted
    }
    
    var timeSpentText: String {
        guard let task = state.task,
              let duration = task.actualDuration ?? task.estimatedDuration else {
            return "Не указано"
        }
        return formatDuration(duration)
    }
    
    var estimatedTimeText: String {
        guard let task = state.task,
              let duration = task.estimatedDuration else {
            return "Не указано"
        }
        return formatDuration(duration)
    }
    
    // MARK: - Initialization
    
    init(taskService: TaskServiceProtocol) {
        self.taskService = taskService
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadTask(let id):
                await loadTask(id)
                
            case .refreshTask:
                await refreshTask()
                
            case .toggleTaskCompletion:
                await toggleTaskCompletion()
                
            case .startTask:
                await startTask()
                
            case .pauseTask:
                await pauseTask()
                
            case .cancelTask:
                await cancelTask()
                
            case .updatePriority(let priority):
                await updatePriority(priority)
                
            case .updateDueDate(let date):
                await updateDueDate(date)
                
            case .addSubtask(let title):
                await addSubtask(title)
                
            case .removeSubtask(let subtask):
                await removeSubtask(subtask)
                
            case .toggleSubtaskCompletion(let subtask):
                await toggleSubtaskCompletion(subtask)
                
            case .addPrerequisite(let prerequisite):
                await addPrerequisite(prerequisite)
                
            case .removePrerequisite(let prerequisite):
                await removePrerequisite(prerequisite)
                
            case .startTimer:
                startTimer()
                
            case .pauseTimer:
                pauseTimer()
                
            case .stopTimer:
                stopTimer()
                
            case .addComment(let text):
                addComment(text)
                
            case .editComment(let comment, let newText):
                editComment(comment, newText: newText)
                
            case .deleteComment(let comment):
                deleteComment(comment)
                
            case .showEditTask:
                state.showEditTask = true
                
            case .hideEditTask:
                state.showEditTask = false
                
            case .deleteTask:
                await deleteTask()
                
            case .archiveTask:
                await archiveTask()
                
            case .duplicateTask:
                await duplicateTask()
                
            case .shareTask:
                shareTask()
                
            case .exportTask:
                exportTask()
                
            case .showSubtaskOptions(let subtask):
                state.showSubtaskOptions = subtask
                
            case .hideSubtaskOptions:
                state.showSubtaskOptions = nil
                
            case .toggleTimeTracker:
                state.showTimeTracker.toggle()
                
            case .toggleProgress:
                state.showProgress.toggle()
                
            case .newSubtaskTitleChanged(let title):
                state.newSubtaskTitle = title
                
            case .newCommentChanged(let comment):
                state.newComment = comment
            }
        }
    }
    
    // MARK: - Task Operations
    
    private func loadTask(_ id: UUID) async {
        state.isLoading = true
        state.error = nil
        
        do {
            guard let task = try await taskService.getTask(by: id) else {
                state.error = TaskError.taskNotFound
                state.isLoading = false
                return
            }
            
            state.task = task
            
            // Load related data
            await loadSubtasks()
            await loadDependencies()
            await loadStatistics()
            await loadActionHistory()
            
        } catch {
            state.error = AppError.from(error)
        }
        
        state.isLoading = false
    }
    
    private func refreshTask() async {
        guard let taskId = state.task?.id else { return }
        
        do {
            guard let task = try await taskService.getTask(by: taskId) else {
                state.error = TaskError.taskNotFound
                return
            }
            
            state.task = task
            state.refreshID = UUID()
            
            // Refresh related data
            await loadSubtasks()
            await loadDependencies()
            await loadStatistics()
            
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func loadSubtasks() async {
        guard let task = state.task else { return }
        
        do {
            // Subtasks are already loaded as part of the relationship
            state.subtasks = task.subtasks.filter { !$0.isArchived }
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func loadDependencies() async {
        guard let task = state.task else { return }
        
        state.prerequisites = task.prerequisiteTasks
        
        do {
            // Load dependent tasks manually since we need to query for them
            let allTasks = try await taskService.getActiveTasks()
            state.dependentTasks = allTasks.filter { dependentTask in
                dependentTask.prerequisiteTasks.contains { $0.id == task.id }
            }
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func loadStatistics() async {
        guard let task = state.task else { return }
        
        do {
            let stats = try await taskService.getTaskStatistics(period: .thisMonth)
            
            state.statistics = TaskDetailStatistics(
                totalTimeSpent: task.actualDuration ?? 0,
                estimatedTime: task.estimatedDuration ?? 0,
                pointsEarned: task.points,
                completionRate: task.progress,
                daysActive: calculateDaysActive(task),
                streakDays: calculateStreakDays(task)
            )
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func loadActionHistory() async {
        // In a real app, this would load from a separate action tracking system
        // For now, we'll create some mock data based on task properties
        
        guard let task = state.task else { return }
        
        var actions: [TaskAction] = []
        
        actions.append(TaskAction(
            type: .created,
            timestamp: task.createdAt,
            description: "Задача создана"
        ))
        
        if let startDate = task.startDate {
            actions.append(TaskAction(
                type: .started,
                timestamp: startDate,
                description: "Задача начата"
            ))
        }
        
        if let completedDate = task.completedDate {
            actions.append(TaskAction(
                type: .completed,
                timestamp: completedDate,
                description: "Задача выполнена"
            ))
        }
        
        state.actionHistory = actions.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func toggleTaskCompletion() async {
        guard let task = state.task else { return }
        
        do {
            if task.status == .completed {
                try await taskService.uncompleteTask(task)
                addActionHistory(.reopened, "Задача открыта заново")
            } else {
                try await taskService.completeTask(task)
                addActionHistory(.completed, "Задача выполнена")
                stopTimer()
            }
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func startTask() async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.startTask(task)
            addActionHistory(.started, "Задача начата")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func pauseTask() async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.pauseTask(task)
            addActionHistory(.paused, "Задача приостановлена")
            pauseTimer()
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func cancelTask() async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.cancelTask(task)
            addActionHistory(.cancelled, "Задача отменена")
            stopTimer()
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func updatePriority(_ priority: Priority) async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.updateTaskPriority(task, priority: priority)
            addActionHistory(.priorityChanged, "Приоритет изменен на \(priority.displayName)")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func updateDueDate(_ date: Date?) async {
        guard let task = state.task else { return }
        
        task.dueDate = date
        
        do {
            try await taskService.updateTask(task)
            addActionHistory(.dueDateChanged, date != nil ? "Дедлайн установлен" : "Дедлайн удален")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    // MARK: - Subtask Operations
    
    private func addSubtask(_ title: String) async {
        guard let task = state.task else { return }
        
        let subtask = Task(
            title: title,
            priority: task.priority,
            category: task.category,
            parentTask: task
        )
        
        do {
            try await taskService.addSubtask(subtask, to: task)
            state.newSubtaskTitle = ""
            addActionHistory(.subtaskAdded, "Добавлена подзадача: \(title)")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func removeSubtask(_ subtask: Task) async {
        do {
            try await taskService.removeSubtask(subtask)
            addActionHistory(.subtaskRemoved, "Удалена подзадача: \(subtask.title)")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func toggleSubtaskCompletion(_ subtask: Task) async {
        do {
            if subtask.status == .completed {
                try await taskService.uncompleteTask(subtask)
            } else {
                try await taskService.completeTask(subtask)
            }
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    // MARK: - Dependency Operations
    
    private func addPrerequisite(_ prerequisite: Task) async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.addTaskDependency(task, dependsOn: prerequisite)
            addActionHistory(.dependencyAdded, "Добавлена зависимость: \(prerequisite.title)")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func removePrerequisite(_ prerequisite: Task) async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.removeTaskDependency(task, from: prerequisite)
            addActionHistory(.dependencyRemoved, "Удалена зависимость: \(prerequisite.title)")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    // MARK: - Timer Operations
    
    private func startTimer() {
        guard let task = state.task, !state.isTimerRunning else { return }
        
        state.isTimerRunning = true
        state.startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        addActionHistory(.timerStarted, "Запущен таймер")
    }
    
    private func pauseTimer() {
        guard state.isTimerRunning else { return }
        
        state.isTimerRunning = false
        timer?.invalidate()
        timer = nil
        
        addActionHistory(.timerPaused, "Таймер приостановлен")
    }
    
    private func stopTimer() {
        guard state.isTimerRunning || state.elapsedTime > 0 else { return }
        
        state.isTimerRunning = false
        timer?.invalidate()
        timer = nil
        
        // Save elapsed time to task
        if let task = state.task, state.elapsedTime > 0 {
            let currentDuration = task.actualDuration ?? 0
            task.actualDuration = currentDuration + state.elapsedTime
            
            Task {
                try? await taskService.updateTask(task)
            }
        }
        
        state.elapsedTime = 0
        state.startTime = nil
        updateTimerDisplay()
        
        addActionHistory(.timerStopped, "Таймер остановлен")
    }
    
    private func updateTimer() {
        guard let startTime = state.startTime else { return }
        
        state.elapsedTime = Date().timeIntervalSince(startTime)
        updateTimerDisplay()
    }
    
    private func updateTimerDisplay() {
        let totalSeconds = Int(state.elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            state.timerDisplayText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            state.timerDisplayText = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - Comments
    
    private func addComment(_ text: String) {
        let comment = TaskComment(
            id: UUID(),
            text: text,
            timestamp: Date(),
            author: "Current User" // In real app, this would be the current user
        )
        
        state.comments.append(comment)
        state.newComment = ""
        
        addActionHistory(.commentAdded, "Добавлен комментарий")
    }
    
    private func editComment(_ comment: TaskComment, newText: String) {
        if let index = state.comments.firstIndex(where: { $0.id == comment.id }) {
            state.comments[index].text = newText
            state.comments[index].isEdited = true
            addActionHistory(.commentEdited, "Комментарий изменен")
        }
    }
    
    private func deleteComment(_ comment: TaskComment) {
        state.comments.removeAll { $0.id == comment.id }
        addActionHistory(.commentDeleted, "Комментарий удален")
    }
    
    // MARK: - Actions
    
    private func deleteTask() async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.deleteTask(task)
            state.task = nil
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func archiveTask() async {
        guard let task = state.task else { return }
        
        do {
            try await taskService.archiveTask(task)
            addActionHistory(.archived, "Задача архивирована")
            await refreshTask()
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func duplicateTask() async {
        guard let originalTask = state.task else { return }
        
        let duplicatedTask = Task(
            title: "\(originalTask.title) (копия)",
            description: originalTask.description,
            priority: originalTask.priority,
            category: originalTask.category
        )
        
        duplicatedTask.tags = originalTask.tags
        duplicatedTask.estimatedDuration = originalTask.estimatedDuration
        duplicatedTask.location = originalTask.location
        duplicatedTask.url = originalTask.url
        
        do {
            try await taskService.createTask(duplicatedTask)
            addActionHistory(.duplicated, "Задача дублирована")
        } catch {
            state.error = AppError.from(error)
        }
    }
    
    private func shareTask() {
        // Implementation for sharing task
        addActionHistory(.shared, "Задача поделена")
    }
    
    private func exportTask() {
        // Implementation for exporting task
        addActionHistory(.exported, "Задача экспортирована")
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else {
            return "\(minutes)м"
        }
    }
    
    private func calculateDaysActive(_ task: Task) -> Int {
        let calendar = Calendar.current
        let daysSinceCreation = calendar.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        return max(1, daysSinceCreation)
    }
    
    private func calculateStreakDays(_ task: Task) -> Int {
        // Simplified calculation - in real app this would be more sophisticated
        return task.subtasks.filter { $0.status == .completed }.count
    }
    
    private func addActionHistory(_ type: TaskActionType, _ description: String) {
        let action = TaskAction(
            type: type,
            timestamp: Date(),
            description: description
        )
        state.actionHistory.insert(action, at: 0)
    }
}

// MARK: - Supporting Types

struct TaskDetailStatistics {
    let totalTimeSpent: TimeInterval
    let estimatedTime: TimeInterval
    let pointsEarned: Int
    let completionRate: Double
    let daysActive: Int
    let streakDays: Int
}

struct TaskComment: Identifiable {
    let id: UUID
    var text: String
    let timestamp: Date
    let author: String
    var isEdited: Bool = false
}

struct TaskAction: Identifiable {
    let id = UUID()
    let type: TaskActionType
    let timestamp: Date
    let description: String
}

enum TaskActionType {
    case created
    case started
    case paused
    case completed
    case cancelled
    case reopened
    case priorityChanged
    case dueDateChanged
    case subtaskAdded
    case subtaskRemoved
    case dependencyAdded
    case dependencyRemoved
    case timerStarted
    case timerPaused
    case timerStopped
    case commentAdded
    case commentEdited
    case commentDeleted
    case archived
    case duplicated
    case shared
    case exported
    
    var icon: String {
        switch self {
        case .created: return "plus.circle"
        case .started: return "play.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .reopened: return "arrow.clockwise.circle"
        case .priorityChanged: return "exclamationmark.triangle"
        case .dueDateChanged: return "calendar"
        case .subtaskAdded: return "plus.square"
        case .subtaskRemoved: return "minus.square"
        case .dependencyAdded: return "link"
        case .dependencyRemoved: return "link.badge.minus"
        case .timerStarted: return "timer"
        case .timerPaused: return "timer.square"
        case .timerStopped: return "timer.square"
        case .commentAdded: return "bubble.left"
        case .commentEdited: return "bubble.left.fill"
        case .commentDeleted: return "bubble.left.and.exclamationmark.bubble.right"
        case .archived: return "archivebox"
        case .duplicated: return "doc.on.doc"
        case .shared: return "square.and.arrow.up"
        case .exported: return "square.and.arrow.down"
        }
    }
} 