import Foundation
import SwiftUI

// MARK: - KanbanBoardViewModel

@Observable
final class KanbanBoardViewModel {
    
    // MARK: - Properties
    
    private let projectManagementService: ProjectManagementServiceProtocol
    private let taskService: TaskServiceProtocol
    private let dataService: DataServiceProtocol
    
    // State
    var selectedProject: Project? {
        didSet { loadProjectTasks() }
    }
    var availableProjects: [Project] = []
    var kanbanColumns: [KanbanColumn] = []
    var allTasks: [ProjectTask] = []
    
    // Board configuration
    var boardLayout: BoardLayout = .standard {
        didSet { rebuildColumns() }
    }
    var customColumns: [CustomColumn] = []
    
    // UI State
    var isLoading: Bool = false
    var error: AppError?
    var showingCreateTask: Bool = false
    var showingColumnEditor: Bool = false
    var showingBoardSettings: Bool = false
    
    // Drag & Drop
    var draggedTask: ProjectTask?
    var dragOverColumn: UUID?
    var isDragging: Bool = false
    
    // Filters
    var searchText: String = "" {
        didSet { applyFilters() }
    }
    var selectedAssignee: User? {
        didSet { applyFilters() }
    }
    var selectedPriority: Priority? {
        didSet { applyFilters() }
    }
    var showCompletedTasks: Bool = false {
        didSet { applyFilters() }
    }
    var selectedTags: Set<String> = [] {
        didSet { applyFilters() }
    }
    
    // Analytics
    var boardMetrics: BoardMetrics?
    var columnMetrics: [UUID: ColumnMetrics] = [:]
    var velocityData: [VelocityPoint] = []
    var burndownData: [BurndownPoint] = []
    
    // Task creation
    var newTaskTitle: String = ""
    var newTaskDescription: String = ""
    var newTaskPriority: Priority = .medium
    var newTaskAssignee: User?
    var newTaskColumn: KanbanColumn?
    
    // MARK: - Initialization
    
    init(
        projectManagementService: ProjectManagementServiceProtocol,
        taskService: TaskServiceProtocol,
        dataService: DataServiceProtocol
    ) {
        self.projectManagementService = projectManagementService
        self.taskService = taskService
        self.dataService = dataService
        setupDefaultColumns()
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadProjects() async {
        isLoading = true
        error = nil
        
        do {
            availableProjects = try await projectManagementService.getActiveProjects()
            
            if selectedProject == nil && !availableProjects.isEmpty {
                selectedProject = availableProjects.first
            }
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadProjectTasks() async {
        guard let project = selectedProject else {
            allTasks = []
            rebuildColumns()
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Получаем все задачи проекта
            allTasks = project.tasks
            rebuildColumns()
            applyFilters()
            
            await loadBoardAnalytics()
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func createTask(
        title: String? = nil,
        description: String? = nil,
        priority: Priority? = nil,
        assignee: User? = nil,
        column: KanbanColumn? = nil
    ) async {
        guard let project = selectedProject else { return }
        
        do {
            let task = ProjectTask(
                title: title ?? newTaskTitle,
                description: description ?? newTaskDescription,
                priority: priority ?? newTaskPriority,
                project: project
            )
            
            task.assignee = assignee ?? newTaskAssignee
            
            // Устанавливаем статус на основе колонки
            if let targetColumn = column ?? newTaskColumn {
                task.kanbanColumn = targetColumn.type
                task.status = targetColumn.type.taskStatus
            }
            
            try await taskService.createTask(task)
            
            allTasks.append(task)
            rebuildColumns()
            applyFilters()
            
            // Очищаем форму
            resetCreateForm()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func moveTask(_ task: ProjectTask, to column: KanbanColumn) async {
        guard task.kanbanColumn != column.type else { return }
        
        do {
            let oldColumn = task.kanbanColumn
            
            task.kanbanColumn = column.type
            task.status = column.type.taskStatus
            
            // Обновляем timestamp для отслеживания flow времени
            task.updateStatusTimestamp()
            
            try await taskService.updateTask(task)
            
            rebuildColumns()
            await updateColumnMetrics(for: oldColumn)
            await updateColumnMetrics(for: column.type)
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func updateTask(_ task: ProjectTask) async {
        do {
            try await taskService.updateTask(task)
            rebuildColumns()
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func deleteTask(_ task: ProjectTask) async {
        do {
            try await taskService.deleteTask(task)
            allTasks.removeAll { $0.id == task.id }
            rebuildColumns()
            applyFilters()
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func addCustomColumn(_ column: CustomColumn) async {
        customColumns.append(column)
        rebuildColumns()
    }
    
    @MainActor
    func removeCustomColumn(_ column: CustomColumn) async {
        customColumns.removeAll { $0.id == column.id }
        
        // Перемещаем задачи из удаляемой колонки в backlog
        for task in allTasks where task.kanbanColumn == column.type {
            task.kanbanColumn = .backlog
            task.status = .pending
            try? await taskService.updateTask(task)
        }
        
        rebuildColumns()
    }
    
    @MainActor
    func reorderColumns(_ columns: [KanbanColumn]) async {
        kanbanColumns = columns
    }
    
    func startDragging(_ task: ProjectTask) {
        draggedTask = task
        isDragging = true
    }
    
    func endDragging() {
        draggedTask = nil
        dragOverColumn = nil
        isDragging = false
    }
    
    func dragEntered(column: UUID) {
        dragOverColumn = column
    }
    
    func dragExited() {
        dragOverColumn = nil
    }
    
    @MainActor
    func handleDrop(task: ProjectTask, in column: KanbanColumn) async {
        await moveTask(task, to: column)
        endDragging()
    }
    
    func selectProject(_ project: Project) {
        selectedProject = project
    }
    
    func resetCreateForm() {
        newTaskTitle = ""
        newTaskDescription = ""
        newTaskPriority = .medium
        newTaskAssignee = nil
        newTaskColumn = nil
        showingCreateTask = false
    }
    
    func refreshData() async {
        await loadProjects()
        await loadProjectTasks()
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultColumns() {
        let defaultColumns: [KanbanColumnType] = [.backlog, .todo, .inProgress, .review, .done]
        kanbanColumns = defaultColumns.map { type in
            KanbanColumn(
                id: UUID(),
                type: type,
                title: type.displayName,
                tasks: [],
                wipLimit: type.defaultWipLimit,
                isCollapsed: false
            )
        }
    }
    
    private func rebuildColumns() {
        var columns: [KanbanColumn] = []
        
        switch boardLayout {
        case .standard:
            columns = buildStandardColumns()
        case .simple:
            columns = buildSimpleColumns()
        case .detailed:
            columns = buildDetailedColumns()
        case .custom:
            columns = buildCustomColumns()
        }
        
        kanbanColumns = columns
    }
    
    private func buildStandardColumns() -> [KanbanColumn] {
        let columnTypes: [KanbanColumnType] = [.backlog, .todo, .inProgress, .review, .done]
        
        return columnTypes.map { type in
            let tasks = allTasks.filter { $0.kanbanColumn == type }
            return KanbanColumn(
                id: UUID(),
                type: type,
                title: type.displayName,
                tasks: tasks,
                wipLimit: type.defaultWipLimit,
                isCollapsed: false
            )
        }
    }
    
    private func buildSimpleColumns() -> [KanbanColumn] {
        let columnTypes: [KanbanColumnType] = [.todo, .inProgress, .done]
        
        return columnTypes.map { type in
            let tasks = allTasks.filter { $0.kanbanColumn == type }
            return KanbanColumn(
                id: UUID(),
                type: type,
                title: type.displayName,
                tasks: tasks,
                wipLimit: type.defaultWipLimit,
                isCollapsed: false
            )
        }
    }
    
    private func buildDetailedColumns() -> [KanbanColumn] {
        let columnTypes: [KanbanColumnType] = [
            .backlog, .ready, .inProgress, .codeReview, .testing, .deployment, .done
        ]
        
        return columnTypes.map { type in
            let tasks = allTasks.filter { $0.kanbanColumn == type }
            return KanbanColumn(
                id: UUID(),
                type: type,
                title: type.displayName,
                tasks: tasks,
                wipLimit: type.defaultWipLimit,
                isCollapsed: false
            )
        }
    }
    
    private func buildCustomColumns() -> [KanbanColumn] {
        var columns: [KanbanColumn] = []
        
        // Добавляем стандартные колонки
        for columnType in [KanbanColumnType.backlog, .todo] {
            let tasks = allTasks.filter { $0.kanbanColumn == columnType }
            columns.append(KanbanColumn(
                id: UUID(),
                type: columnType,
                title: columnType.displayName,
                tasks: tasks,
                wipLimit: columnType.defaultWipLimit,
                isCollapsed: false
            ))
        }
        
        // Добавляем кастомные колонки
        for customColumn in customColumns.sorted(by: { $0.order < $1.order }) {
            let tasks = allTasks.filter { $0.kanbanColumn == customColumn.type }
            columns.append(KanbanColumn(
                id: customColumn.id,
                type: customColumn.type,
                title: customColumn.title,
                tasks: tasks,
                wipLimit: customColumn.wipLimit,
                isCollapsed: false
            ))
        }
        
        // Добавляем Done колонку
        let doneTasks = allTasks.filter { $0.kanbanColumn == .done }
        columns.append(KanbanColumn(
            id: UUID(),
            type: .done,
            title: KanbanColumnType.done.displayName,
            tasks: doneTasks,
            wipLimit: nil,
            isCollapsed: false
        ))
        
        return columns
    }
    
    private func applyFilters() {
        var filteredTasks = allTasks
        
        // Применяем поисковый фильтр
        if !searchText.isEmpty {
            filteredTasks = filteredTasks.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Фильтр по исполнителю
        if let assignee = selectedAssignee {
            filteredTasks = filteredTasks.filter { $0.assignee?.id == assignee.id }
        }
        
        // Фильтр по приоритету
        if let priority = selectedPriority {
            filteredTasks = filteredTasks.filter { $0.priority == priority }
        }
        
        // Фильтр завершенных задач
        if !showCompletedTasks {
            filteredTasks = filteredTasks.filter { !$0.isCompleted }
        }
        
        // Фильтр по тегам
        if !selectedTags.isEmpty {
            filteredTasks = filteredTasks.filter { task in
                !Set(task.tags).isDisjoint(with: selectedTags)
            }
        }
        
        // Обновляем задачи в колонках
        for i in kanbanColumns.indices {
            kanbanColumns[i].tasks = filteredTasks.filter { 
                $0.kanbanColumn == kanbanColumns[i].type 
            }
        }
    }
    
    @MainActor
    private func loadBoardAnalytics() async {
        guard let project = selectedProject else { return }
        
        do {
            let metrics = try await projectManagementService.getProjectMetrics(project)
            
            boardMetrics = BoardMetrics(
                totalTasks: allTasks.count,
                completedTasks: allTasks.filter { $0.isCompleted }.count,
                inProgressTasks: allTasks.filter { $0.status == .inProgress }.count,
                blockedTasks: allTasks.filter { $0.status == .blocked }.count,
                averageCycleTime: calculateAverageCycleTime(),
                throughput: calculateThroughput()
            )
            
            // Загружаем метрики по колонкам
            for column in kanbanColumns {
                await updateColumnMetrics(for: column.type)
            }
            
            await loadVelocityData()
            await loadBurndownData()
            
        } catch {
            print("Failed to load board analytics: \(error)")
        }
    }
    
    @MainActor
    private func updateColumnMetrics(for columnType: KanbanColumnType) async {
        let columnTasks = allTasks.filter { $0.kanbanColumn == columnType }
        
        let metrics = ColumnMetrics(
            taskCount: columnTasks.count,
            averageTimeInColumn: calculateAverageTimeInColumn(for: columnType),
            wipViolations: calculateWipViolations(for: columnType),
            throughput: calculateColumnThroughput(for: columnType)
        )
        
        columnMetrics[UUID()] = metrics // В реальном приложении использовать ID колонки
    }
    
    @MainActor
    private func loadVelocityData() async {
        // Загружаем данные скорости команды за последние 8 недель
        let calendar = Calendar.current
        let endDate = Date()
        var velocityPoints: [VelocityPoint] = []
        
        for weekOffset in 0..<8 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: endDate) else { continue }
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            
            let weekTasks = allTasks.filter { task in
                guard let completedDate = task.completedAt else { return false }
                return completedDate >= weekStart && completedDate < weekEnd
            }
            
            let storyPoints = weekTasks.reduce(0) { $0 + ($1.storyPoints ?? 0) }
            velocityPoints.append(VelocityPoint(week: weekStart, storyPoints: storyPoints))
        }
        
        velocityData = velocityPoints.reversed()
    }
    
    @MainActor
    private func loadBurndownData() async {
        guard let project = selectedProject else { return }
        
        // Генерируем данные burndown chart на основе оставшихся story points
        let calendar = Calendar.current
        let startDate = project.startDate ?? project.createdAt
        let endDate = project.targetEndDate ?? calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        
        let totalStoryPoints = allTasks.reduce(0) { $0 + ($1.storyPoints ?? 0) }
        let completedStoryPoints = allTasks.filter { $0.isCompleted }.reduce(0) { $0 + ($1.storyPoints ?? 0) }
        let remainingStoryPoints = totalStoryPoints - completedStoryPoints
        
        var burndownPoints: [BurndownPoint] = []
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        for dayOffset in 0...dayCount {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }
            
            // Идеальная линия
            let idealRemaining = totalStoryPoints * (1.0 - Double(dayOffset) / Double(dayCount))
            
            // Фактическая линия (упрощенная)
            let actualRemaining = date <= Date() ? Double(remainingStoryPoints) : nil
            
            burndownPoints.append(BurndownPoint(
                date: date,
                idealRemaining: idealRemaining,
                actualRemaining: actualRemaining
            ))
        }
        
        burndownData = burndownPoints
    }
    
    // MARK: - Analytics Helper Methods
    
    private func calculateAverageCycleTime() -> TimeInterval {
        let completedTasks = allTasks.filter { $0.isCompleted }
        guard !completedTasks.isEmpty else { return 0 }
        
        let totalCycleTime = completedTasks.compactMap { task in
            guard let startedAt = task.startedAt,
                  let completedAt = task.completedAt else { return nil }
            return completedAt.timeIntervalSince(startedAt)
        }.reduce(0, +)
        
        return totalCycleTime / Double(completedTasks.count)
    }
    
    private func calculateThroughput() -> Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        
        let recentlyCompleted = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }
        
        return Double(recentlyCompleted.count)
    }
    
    private func calculateAverageTimeInColumn(for columnType: KanbanColumnType) -> TimeInterval {
        // Упрощенная реализация - в реальном приложении нужно отслеживать
        // время входа и выхода из каждой колонки
        return 0
    }
    
    private func calculateWipViolations(for columnType: KanbanColumnType) -> Int {
        guard let wipLimit = columnType.defaultWipLimit else { return 0 }
        let tasksInColumn = allTasks.filter { $0.kanbanColumn == columnType }.count
        return max(0, tasksInColumn - wipLimit)
    }
    
    private func calculateColumnThroughput(for columnType: KanbanColumnType) -> Double {
        // Упрощенная реализация
        return 0
    }
}

// MARK: - Supporting Types

enum BoardLayout: String, CaseIterable {
    case standard = "Стандартная"
    case simple = "Простая"
    case detailed = "Детальная"
    case custom = "Настраиваемая"
}

enum KanbanColumnType: String, CaseIterable {
    case backlog = "backlog"
    case ready = "ready"
    case todo = "todo"
    case inProgress = "inProgress"
    case codeReview = "codeReview"
    case testing = "testing"
    case review = "review"
    case deployment = "deployment"
    case done = "done"
    case blocked = "blocked"
    
    var displayName: String {
        switch self {
        case .backlog: return "Бэклог"
        case .ready: return "Готово к работе"
        case .todo: return "К выполнению"
        case .inProgress: return "В работе"
        case .codeReview: return "Code Review"
        case .testing: return "Тестирование"
        case .review: return "На проверке"
        case .deployment: return "Деплой"
        case .done: return "Выполнено"
        case .blocked: return "Заблокировано"
        }
    }
    
    var defaultWipLimit: Int? {
        switch self {
        case .inProgress: return 3
        case .codeReview: return 2
        case .testing: return 2
        case .review: return 2
        default: return nil
        }
    }
    
    var taskStatus: TaskStatus {
        switch self {
        case .backlog, .ready, .todo: return .pending
        case .inProgress: return .inProgress
        case .codeReview, .testing, .review: return .inReview
        case .deployment: return .inProgress
        case .done: return .completed
        case .blocked: return .blocked
        }
    }
}

struct KanbanColumn: Identifiable {
    let id: UUID
    let type: KanbanColumnType
    let title: String
    var tasks: [ProjectTask]
    let wipLimit: Int?
    var isCollapsed: Bool
    
    var isWipViolated: Bool {
        guard let limit = wipLimit else { return false }
        return tasks.count > limit
    }
}

struct CustomColumn: Identifiable {
    let id: UUID
    let title: String
    let type: KanbanColumnType
    let wipLimit: Int?
    let order: Int
}

struct BoardMetrics {
    let totalTasks: Int
    let completedTasks: Int
    let inProgressTasks: Int
    let blockedTasks: Int
    let averageCycleTime: TimeInterval
    let throughput: Double
    
    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

struct ColumnMetrics {
    let taskCount: Int
    let averageTimeInColumn: TimeInterval
    let wipViolations: Int
    let throughput: Double
}

struct VelocityPoint {
    let week: Date
    let storyPoints: Int
}

struct BurndownPoint {
    let date: Date
    let idealRemaining: Double
    let actualRemaining: Double?
}

// Расширения для ProjectTask
extension ProjectTask {
    var kanbanColumn: KanbanColumnType {
        get {
            // В реальном приложении это должно быть сохранено в базе данных
            switch status {
            case .pending: return .todo
            case .inProgress: return .inProgress
            case .inReview: return .review
            case .completed: return .done
            case .cancelled: return .done
            case .blocked: return .blocked
            }
        }
        set {
            // Здесь должна быть логика обновления kanbanColumn в базе данных
        }
    }
    
    var storyPoints: Int? {
        // В реальном приложении это должно быть свойство модели
        return estimatedDuration != nil ? max(1, Int(estimatedDuration! / 3600)) : nil
    }
} 