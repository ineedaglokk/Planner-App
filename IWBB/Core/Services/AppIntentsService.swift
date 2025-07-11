import Foundation
import AppIntents
import SwiftData

// MARK: - App Intents Service

final class AppIntentsService {
    
    static let shared = AppIntentsService()
    
    private let dataService: DataServiceProtocol
    private let taskService: TaskServiceProtocol
    private let projectManagementService: ProjectManagementServiceProtocol
    private let timeBlockingService: TimeBlockingServiceProtocol
    
    private init() {
        let serviceContainer = ServiceContainer.shared
        self.dataService = serviceContainer.dataService
        self.taskService = serviceContainer.taskService
        self.projectManagementService = serviceContainer.projectManagementService
        self.timeBlockingService = serviceContainer.timeBlockingService
    }
    
    // MARK: - Intent Registration
    
    static func registerIntents() {
        // Intents are automatically registered via AppIntentsExtension
    }
}

// MARK: - Task Management Intents

// Create Task Intent
struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Создать задачу"
    static let description = IntentDescription("Создает новую задачу в Planner App")
    
    @Parameter(title: "Название задачи")
    var taskTitle: String
    
    @Parameter(title: "Проект", optionsProvider: ProjectOptionsProvider())
    var project: ProjectEntity?
    
    @Parameter(title: "Приоритет")
    var priority: PriorityEntity?
    
    @Parameter(title: "Описание")
    var taskDescription: String?
    
    @Parameter(title: "Дата выполнения")
    var dueDate: Date?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = AppIntentsService.shared
        
        guard let projectId = project?.id,
              let selectedProject = try await service.projectManagementService.getProject(projectId) else {
            throw AppIntentError.projectNotFound
        }
        
        let task = ProjectTask(
            title: taskTitle,
            description: taskDescription,
            project: selectedProject,
            priority: priority?.priority ?? .medium,
            dueDate: dueDate,
            status: .todo
        )
        
        let createdTask = try await service.taskService.createTask(task)
        
        return .result(
            dialog: IntentDialog("Задача '\(createdTask.title)' создана в проекте '\(selectedProject.name)'")
        )
    }
}

// Complete Task Intent
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Завершить задачу"
    static let description = IntentDescription("Отмечает задачу как выполненную")
    
    @Parameter(title: "Задача", optionsProvider: TaskOptionsProvider())
    var task: TaskEntity
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = AppIntentsService.shared
        
        guard let taskId = UUID(uuidString: task.id),
              var selectedTask = try await service.taskService.getTask(taskId) else {
            throw AppIntentError.taskNotFound
        }
        
        selectedTask.status = .completed
        selectedTask.completedAt = Date()
        
        try await service.taskService.updateTask(selectedTask)
        
        return .result(
            dialog: IntentDialog("Задача '\(selectedTask.title)' завершена! 🎉")
        )
    }
}

// Get Tasks Intent
struct GetTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "Показать задачи"
    static let description = IntentDescription("Показывает список текущих задач")
    
    @Parameter(title: "Проект", optionsProvider: ProjectOptionsProvider())
    var project: ProjectEntity?
    
    @Parameter(title: "Статус")
    var status: TaskStatusEntity?
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let service = AppIntentsService.shared
        
        var tasks: [ProjectTask]
        
        if let projectId = project?.id,
           let projectUUID = UUID(uuidString: projectId) {
            tasks = try await service.taskService.getTasksForProject(projectUUID)
        } else {
            tasks = try await service.taskService.getAllTasks()
        }
        
        // Filter by status if specified
        if let statusFilter = status {
            tasks = tasks.filter { $0.status == statusFilter.status }
        }
        
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        
        let dialogText = if incompleteTasks.isEmpty {
            "У вас нет незавершенных задач! ✅"
        } else {
            "У вас \(incompleteTasks.count) незавершенных задач"
        }
        
        return .result(
            dialog: IntentDialog(dialogText),
            view: TasksListSnippetView(tasks: incompleteTasks)
        )
    }
}

// MARK: - Project Management Intents

// Create Project Intent
struct CreateProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Создать проект"
    static let description = IntentDescription("Создает новый проект")
    
    @Parameter(title: "Название проекта")
    var projectName: String
    
    @Parameter(title: "Описание")
    var projectDescription: String?
    
    @Parameter(title: "Дата окончания")
    var endDate: Date?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = AppIntentsService.shared
        
        let project = Project(
            name: projectName,
            description: projectDescription,
            targetStartDate: Date(),
            targetEndDate: endDate,
            priority: .medium,
            status: .planning
        )
        
        let createdProject = try await service.projectManagementService.createProject(project)
        
        return .result(
            dialog: IntentDialog("Проект '\(createdProject.name)' создан!")
        )
    }
}

// Get Project Status Intent
struct GetProjectStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Статус проекта"
    static let description = IntentDescription("Показывает статус и прогресс проекта")
    
    @Parameter(title: "Проект", optionsProvider: ProjectOptionsProvider())
    var project: ProjectEntity
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let service = AppIntentsService.shared
        
        guard let projectId = UUID(uuidString: project.id),
              let selectedProject = try await service.projectManagementService.getProject(projectId) else {
            throw AppIntentError.projectNotFound
        }
        
        let tasks = try await service.taskService.getTasksForProject(projectId)
        let completedTasks = tasks.filter { $0.isCompleted }.count
        let totalTasks = tasks.count
        
        let progressText = totalTasks > 0 ? 
            "Прогресс: \(completedTasks) из \(totalTasks) задач завершено (\(Int(selectedProject.progress * 100))%)" :
            "Пока нет задач в проекте"
        
        return .result(
            dialog: IntentDialog("Проект '\(selectedProject.name)': \(selectedProject.status.displayName). \(progressText)"),
            view: ProjectStatusSnippetView(project: selectedProject, completedTasks: completedTasks, totalTasks: totalTasks)
        )
    }
}

// MARK: - Time Blocking Intents

// Create Time Block Intent
struct CreateTimeBlockIntent: AppIntent {
    static let title: LocalizedStringResource = "Запланировать время"
    static let description = IntentDescription("Создает блок времени для работы")
    
    @Parameter(title: "Название")
    var title: String
    
    @Parameter(title: "Дата и время начала")
    var startDate: Date
    
    @Parameter(title: "Длительность (в минутах)")
    var durationMinutes: Int
    
    @Parameter(title: "Задача", optionsProvider: TaskOptionsProvider())
    var task: TaskEntity?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = AppIntentsService.shared
        
        let duration = TimeInterval(durationMinutes * 60)
        let endDate = startDate.addingTimeInterval(duration)
        
        var linkedTask: ProjectTask?
        if let taskId = task?.id,
           let taskUUID = UUID(uuidString: taskId) {
            linkedTask = try await service.taskService.getTask(taskUUID)
        }
        
        let timeBlock = TimeBlock(
            title: title,
            description: nil,
            startDate: startDate,
            endDate: endDate,
            task: linkedTask,
            project: linkedTask?.project,
            isCompleted: false
        )
        
        try await service.timeBlockingService.createTimeBlock(timeBlock)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        return .result(
            dialog: IntentDialog("Время запланировано: '\(title)' с \(timeFormatter.string(from: startDate)) до \(timeFormatter.string(from: endDate))")
        )
    }
}

// Get Today's Schedule Intent
struct GetTodayScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Расписание на сегодня"
    static let description = IntentDescription("Показывает расписание на текущий день")
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let service = AppIntentsService.shared
        
        let today = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        
        let timeBlocks = try await service.timeBlockingService.getTimeBlocks(
            from: startOfDay,
            to: endOfDay
        )
        
        let dialogText = if timeBlocks.isEmpty {
            "На сегодня ничего не запланировано"
        } else {
            "На сегодня запланировано \(timeBlocks.count) блоков времени"
        }
        
        return .result(
            dialog: IntentDialog(dialogText),
            view: ScheduleSnippetView(timeBlocks: timeBlocks, date: today)
        )
    }
}

// MARK: - Quick Actions Intents

// Quick Add Task Intent
struct QuickAddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Быстро добавить задачу"
    static let description = IntentDescription("Быстро создает задачу с минимальной информацией")
    static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Что нужно сделать?")
    var taskTitle: String
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = AppIntentsService.shared
        
        // Get default project or create task without project
        let projects = try await service.projectManagementService.getAllProjects()
        let defaultProject = projects.first { $0.status == .active } ?? projects.first
        
        guard let project = defaultProject else {
            throw AppIntentError.noProjectsAvailable
        }
        
        let task = ProjectTask(
            title: taskTitle,
            description: nil,
            project: project,
            priority: .medium,
            status: .todo
        )
        
        try await service.taskService.createTask(task)
        
        return .result(
            dialog: IntentDialog("Задача '\(taskTitle)' добавлена в '\(project.name)'")
        )
    }
}

// Get Daily Summary Intent
struct GetDailySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Сводка дня"
    static let description = IntentDescription("Показывает сводку задач и расписания на день")
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let service = AppIntentsService.shared
        
        // Get tasks for today
        let today = Date()
        let tasks = try await service.taskService.getTasksDueToday()
        let completedToday = tasks.filter { $0.isCompleted }.count
        let pendingTasks = tasks.filter { !$0.isCompleted }.count
        
        // Get time blocks for today
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: today)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? today
        let timeBlocks = try await service.timeBlockingService.getTimeBlocks(from: startOfDay, to: endOfDay)
        
        let summaryText = """
        Сегодня: \(completedToday) задач завершено, \(pendingTasks) осталось. 
        Запланировано \(timeBlocks.count) блоков времени.
        """
        
        return .result(
            dialog: IntentDialog(summaryText),
            view: DailySummarySnippetView(
                completedTasks: completedToday,
                pendingTasks: pendingTasks,
                timeBlocks: timeBlocks.count
            )
        )
    }
}

// MARK: - Entity Definitions

struct ProjectEntity: AppEntity {
    let id: String
    let name: String
    
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Проект")
    static let defaultQuery = ProjectEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    init(project: Project) {
        self.id = project.id.uuidString
        self.name = project.name
    }
}

struct TaskEntity: AppEntity {
    let id: String
    let title: String
    let projectName: String?
    
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Задача")
    static let defaultQuery = TaskEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        let subtitle = projectName.map { "в \($0)" } ?? ""
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
    
    init(task: ProjectTask) {
        self.id = task.id.uuidString
        self.title = task.title
        self.projectName = task.project?.name
    }
}

struct PriorityEntity: AppEntity {
    let priority: Priority
    
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Приоритет")
    static let defaultQuery = PriorityEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(priority.displayName)")
    }
    
    var id: String { priority.rawValue }
}

struct TaskStatusEntity: AppEntity {
    let status: TaskStatus
    
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Статус задачи")
    static let defaultQuery = TaskStatusEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(status.displayName)")
    }
    
    var id: String { status.rawValue }
}

// MARK: - Entity Queries

struct ProjectEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        let service = AppIntentsService.shared
        let projects = try await service.projectManagementService.getAllProjects()
        
        return projects
            .filter { identifiers.contains($0.id.uuidString) }
            .map(ProjectEntity.init)
    }
    
    func suggestedEntities() async throws -> [ProjectEntity] {
        let service = AppIntentsService.shared
        let projects = try await service.projectManagementService.getAllProjects()
        
        return projects
            .filter { $0.status == .active || $0.status == .planning }
            .prefix(5)
            .map(ProjectEntity.init)
    }
}

struct TaskEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskEntity] {
        let service = AppIntentsService.shared
        let tasks = try await service.taskService.getAllTasks()
        
        return tasks
            .filter { identifiers.contains($0.id.uuidString) }
            .map(TaskEntity.init)
    }
    
    func suggestedEntities() async throws -> [TaskEntity] {
        let service = AppIntentsService.shared
        let tasks = try await service.taskService.getAllTasks()
        
        return tasks
            .filter { !$0.isCompleted }
            .prefix(10)
            .map(TaskEntity.init)
    }
}

struct PriorityEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PriorityEntity] {
        return Priority.allCases.map(PriorityEntity.init)
    }
    
    func suggestedEntities() async throws -> [PriorityEntity] {
        return Priority.allCases.map(PriorityEntity.init)
    }
}

struct TaskStatusEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskStatusEntity] {
        return TaskStatus.allCases.map(TaskStatusEntity.init)
    }
    
    func suggestedEntities() async throws -> [TaskStatusEntity] {
        return TaskStatus.allCases.map(TaskStatusEntity.init)
    }
}

// MARK: - Options Providers

struct ProjectOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [ProjectEntity] {
        let service = AppIntentsService.shared
        let projects = try await service.projectManagementService.getAllProjects()
        return projects.map(ProjectEntity.init)
    }
}

struct TaskOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [TaskEntity] {
        let service = AppIntentsService.shared
        let tasks = try await service.taskService.getAllTasks()
        return tasks.filter { !$0.isCompleted }.map(TaskEntity.init)
    }
}

// MARK: - Snippet Views

struct TasksListSnippetView: View {
    let tasks: [ProjectTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tasks.isEmpty {
                Text("Нет незавершенных задач")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks.prefix(5)) { task in
                    HStack {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 6, height: 6)
                        
                        Text(task.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let project = task.project {
                            Text(project.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if tasks.count > 5 {
                    Text("и еще \(tasks.count - 5)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

struct ProjectStatusSnippetView: View {
    let project: Project
    let completedTasks: Int
    let totalTasks: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: project.icon ?? "folder.fill")
                    .foregroundStyle(project.color?.color ?? .blue)
                
                Text(project.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text(project.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(project.status.color.opacity(0.2))
                    )
                    .foregroundStyle(project.status.color)
                
                Spacer()
                
                Text("\(Int(project.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if totalTasks > 0 {
                ProgressView(value: Double(completedTasks) / Double(totalTasks))
                    .tint(project.color?.color ?? .blue)
                
                Text("\(completedTasks) из \(totalTasks) задач")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

struct ScheduleSnippetView: View {
    let timeBlocks: [TimeBlock]
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, style: .date)
                .font(.headline)
                .fontWeight(.semibold)
            
            if timeBlocks.isEmpty {
                Text("Свободный день")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(timeBlocks.prefix(4)) { timeBlock in
                    HStack {
                        Text(timeBlock.startDate, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        Text(timeBlock.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
                
                if timeBlocks.count > 4 {
                    Text("и еще \(timeBlocks.count - 4)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

struct DailySummarySnippetView: View {
    let completedTasks: Int
    let pendingTasks: Int
    let timeBlocks: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сводка дня")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(completedTasks)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("завершено")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("\(pendingTasks)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("осталось")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("\(timeBlocks)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("блоков")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

// MARK: - App Intent Errors

enum AppIntentError: Error, LocalizedError {
    case projectNotFound
    case taskNotFound
    case noProjectsAvailable
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "Проект не найден"
        case .taskNotFound:
            return "Задача не найдена"
        case .noProjectsAvailable:
            return "Нет доступных проектов. Создайте проект сначала."
        case .invalidData:
            return "Неверные данные"
        }
    }
}

// MARK: - Extensions

extension Priority {
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        }
    }
}

extension TaskStatus {
    var displayName: String {
        switch self {
        case .todo: return "К выполнению"
        case .inProgress: return "В работе"
        case .completed: return "Завершена"
        case .cancelled: return "Отменена"
        }
    }
}

extension TaskServiceProtocol {
    func getTasksDueToday() async throws -> [ProjectTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let allTasks = try await getAllTasks()
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= today && dueDate < tomorrow
        }
    }
} 