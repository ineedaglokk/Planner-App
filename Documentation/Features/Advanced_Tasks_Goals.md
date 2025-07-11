# 🎯 Расширенные задачи и цели - Этап 11

## 📋 Обзор

Этап 11 представляет собой мощную систему управления задачами и целями с продвинутой функциональностью, включающую иерархичные цели, smart планирование, project management и advanced организацию.

## 🏗️ Архитектурные принципы

- **Иерархичность**: Long-term goals → Milestones → Tasks breakdown
- **Smart Planning**: AI-assisted планирование и рекомендации
- **Project Management**: Полноценное управление проектами
- **Time Blocking**: Интеграция с календарем и focus modes
- **Template System**: Переиспользуемые шаблоны проектов и задач

## 📊 Основные функции

### 1. 🎲 Иерархичные цели

```
🎯 Long-term Goal (год)
├── 🎯 Milestone 1 (квартал)
│   ├── 📋 Project A
│   │   ├── ✅ Task 1
│   │   ├── ✅ Task 2
│   │   └── ✅ Task 3
│   └── 📋 Project B
└── 🎯 Milestone 2 (квартал)
    └── 📋 Project C
```

**Возможности:**
- Progress tracking через всю иерархию
- Dependencies между задачами и проектами
- Automatic milestone calculation
- Visual hierarchy representation

### 2. 🧠 Smart планирование

**Time Blocking:**
- Calendar integration с EventKit
- Automatic scheduling suggestions
- Workload balancing
- Time estimation improvements

**Effort Estimation:**
- Historical data analysis
- Task similarity detection
- Learning from completion times
- Smart duration predictions

**Focus Modes Integration:**
- iOS 15+ Focus modes support
- Context-aware task suggestions
- Distraction minimization
- Deep work sessions

### 3. 📁 Project Management

**Multi-step Projects:**
- Project templates library
- Gantt chart visualization (simplified)
- Resource allocation tracking
- Project progress analytics

**Team Collaboration (будущее):**
- Shared project spaces
- Task assignment system
- Progress synchronization
- Comment and review system

### 4. 🔧 Advanced организация

**Custom Views:**
- Kanban board с drag & drop
- Calendar view с time blocks
- List view с smart filtering
- Gantt chart для проектов

**Smart Filters:**
- Saved searches system
- Context-based filtering
- AI-powered categorization
- Custom sorting algorithms

**Bulk Operations:**
- Multi-select interface
- Batch status updates
- Mass deadline changes
- Template application

## 🏛️ Модели данных

### 1. Project Model
```swift
@Model
final class Project: CloudKitSyncable, Timestampable, Gamifiable, Categorizable, Prioritizable, Archivable {
    var id: UUID
    var name: String
    var description: String?
    var priority: Priority
    var status: ProjectStatus
    var startDate: Date
    var targetEndDate: Date?
    var actualEndDate: Date?
    var estimatedEffort: TimeInterval? // Общее расчетное время
    var actualEffort: TimeInterval? // Фактическое время
    var progress: Double // 0.0 - 1.0
    var template: ProjectTemplate?
    
    // Relationships
    var parentGoal: Goal?
    var tasks: [ProjectTask]
    var timeBlocks: [TimeBlock]
    var milestones: [ProjectMilestone]
    var dependencies: [Project] // Зависимые проекты
}
```

### 2. ProjectTask Model
```swift
@Model
final class ProjectTask: CloudKitSyncable, Timestampable, Gamifiable, Prioritizable {
    var id: UUID
    var title: String
    var description: String?
    var priority: Priority
    var status: TaskStatus
    var estimatedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var assignedTimeBlocks: [TimeBlock]
    
    // Project context
    var project: Project
    var phase: ProjectPhase?
    var dependencies: [ProjectTask]
    var subtasks: [ProjectTask]
}
```

### 3. TimeBlock Model
```swift
@Model
final class TimeBlock: CloudKitSyncable, Timestampable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isFlexible: Bool // Может ли быть перемещен
    var isCompleted: Bool
    var actualStartDate: Date?
    var actualEndDate: Date?
    
    // Associations
    var task: ProjectTask?
    var project: Project?
    var focusMode: String? // iOS Focus mode identifier
    var calendarEventID: String? // EventKit event ID
}
```

### 4. ProjectTemplate Model
```swift
@Model
final class ProjectTemplate: CloudKitSyncable, Timestampable {
    var id: UUID
    var name: String
    var description: String?
    var category: TemplateCategory
    var isPublic: Bool // Доступен другим пользователям
    var usageCount: Int
    var estimatedDuration: TimeInterval?
    
    // Template structure
    var phases: [ProjectPhaseTemplate]
    var defaultTasks: [TaskTemplate]
    var suggestedTimeBlocks: [TimeBlockTemplate]
}
```

### 5. GoalHierarchy Model
```swift
@Model
final class GoalHierarchy: CloudKitSyncable, Timestampable {
    var id: UUID
    var name: String
    var description: String?
    var timeframe: GoalTimeframe
    var targetDate: Date?
    
    // Hierarchy
    var parentGoal: GoalHierarchy?
    var childGoals: [GoalHierarchy]
    var projects: [Project]
    var milestones: [HierarchyMilestone]
    
    // Progress calculation
    var manualProgress: Double? // Ручной прогресс
    var calculatedProgress: Double // Автоматический расчет
}
```

## 🔧 Сервисная архитектура

### 1. ProjectManagementService
```swift
protocol ProjectManagementServiceProtocol: ServiceProtocol {
    // Project CRUD
    func createProject(from template: ProjectTemplate?) async throws -> Project
    func updateProjectProgress(_ project: Project) async throws
    func calculateProjectCompletion(_ project: Project) async -> Double
    
    // Dependencies
    func addDependency(from: Project, to: Project) async throws
    func validateDependencies(_ project: Project) async throws -> [DependencyConflict]
    func getProjectSchedule(_ project: Project) async throws -> [ScheduleItem]
    
    // Templates
    func applyTemplate(_ template: ProjectTemplate, to project: Project) async throws
    func createTemplateFromProject(_ project: Project) async throws -> ProjectTemplate
}
```

### 2. TimeBlockingService
```swift
protocol TimeBlockingServiceProtocol: ServiceProtocol {
    // Time blocking
    func createTimeBlock(for task: ProjectTask, duration: TimeInterval, preferredDate: Date?) async throws -> TimeBlock
    func suggestOptimalTimeSlots(for task: ProjectTask) async throws -> [TimeSlot]
    func rescheduleTimeBlock(_ timeBlock: TimeBlock, to newDate: Date) async throws
    
    // Calendar integration
    func syncWithCalendar() async throws
    func createCalendarEvent(for timeBlock: TimeBlock) async throws
    func handleCalendarEventUpdate(_ eventID: String) async throws
    
    // Workload balancing
    func calculateWorkload(for date: Date) async throws -> WorkloadInfo
    func suggestWorkloadDistribution(for week: Date) async throws -> [WorkloadSuggestion]
}
```

### 3. TemplateService
```swift
protocol TemplateServiceProtocol: ServiceProtocol {
    // Template management
    func getAllTemplates() async throws -> [ProjectTemplate]
    func getTemplatesForCategory(_ category: TemplateCategory) async throws -> [ProjectTemplate]
    func createTemplate(from project: Project, name: String, isPublic: Bool) async throws -> ProjectTemplate
    
    // Template application
    func instantiateTemplate(_ template: ProjectTemplate) async throws -> Project
    func suggestTemplatesForGoal(_ goal: GoalHierarchy) async throws -> [ProjectTemplate]
    
    // Community templates (будущее)
    func shareTemplate(_ template: ProjectTemplate) async throws
    func importTemplate(id: String) async throws -> ProjectTemplate
}
```

### 4. CalendarIntegrationService
```swift
protocol CalendarIntegrationServiceProtocol: ServiceProtocol {
    // EventKit integration
    func requestCalendarAccess() async throws -> Bool
    func getAvailableCalendars() async throws -> [EKCalendar]
    func createEvent(for timeBlock: TimeBlock, in calendar: EKCalendar) async throws -> EKEvent
    
    // Sync management
    func syncTimeBlocksWithCalendar() async throws
    func handleExternalCalendarChange(_ notification: Notification) async throws
    
    // Free time detection
    func findFreeTimeSlots(between start: Date, and end: Date, duration: TimeInterval) async throws -> [TimeSlot]
    func checkTimeSlotAvailability(_ timeSlot: TimeSlot) async throws -> Bool
}
```

### 5. FocusModeService
```swift
protocol FocusModeServiceProtocol: ServiceProtocol {
    // Focus modes integration
    func getCurrentFocusMode() async -> String?
    func suggestFocusModeForTask(_ task: ProjectTask) async -> String?
    func activateFocusMode(_ focusMode: String, for duration: TimeInterval) async throws
    
    // Context-aware suggestions
    func getTasksForCurrentContext() async throws -> [ProjectTask]
    func suggestOptimalWorkEnvironment(for task: ProjectTask) async -> WorkEnvironmentSuggestion
}
```

## 🎨 ViewModels

### 1. ProjectDashboardViewModel
```swift
@Observable
final class ProjectDashboardViewModel {
    struct State {
        var activeProjects: [Project] = []
        var recentProjects: [Project] = []
        var overdueTasks: [ProjectTask] = []
        var upcomingDeadlines: [ProjectTask] = []
        var workloadInfo: WorkloadInfo?
        var isLoading: Bool = false
        var selectedProject: Project?
    }
    
    enum Input {
        case loadDashboard
        case selectProject(Project)
        case createNewProject
        case applyTemplate(ProjectTemplate)
        case updateProjectStatus(Project, ProjectStatus)
    }
}
```

### 2. GoalHierarchyViewModel
```swift
@Observable
final class GoalHierarchyViewModel {
    struct State {
        var rootGoals: [GoalHierarchy] = []
        var selectedGoal: GoalHierarchy?
        var expandedGoals: Set<UUID> = []
        var hierarchyView: HierarchyViewType = .tree
        var progressData: [HierarchyProgressData] = []
    }
    
    enum Input {
        case loadHierarchy
        case selectGoal(GoalHierarchy)
        case expandGoal(GoalHierarchy)
        case createChildGoal(parent: GoalHierarchy)
        case updateGoalProgress(GoalHierarchy, Double)
        case changeViewType(HierarchyViewType)
    }
}
```

### 3. KanbanBoardViewModel
```swift
@Observable
final class KanbanBoardViewModel {
    struct State {
        var columns: [KanbanColumn] = []
        var tasks: [ProjectTask] = []
        var draggedTask: ProjectTask?
        var selectedProject: Project?
        var filters: KanbanFilters = KanbanFilters()
    }
    
    enum Input {
        case loadProject(Project)
        case moveTask(ProjectTask, to: KanbanColumn)
        case createTask(in: KanbanColumn)
        case updateTask(ProjectTask)
        case applyFilters(KanbanFilters)
    }
}
```

### 4. TimeBlockingViewModel
```swift
@Observable
final class TimeBlockingViewModel {
    struct State {
        var timeBlocks: [TimeBlock] = []
        var selectedDate: Date = Date()
        var calendarEvents: [EKEvent] = []
        var workloadInfo: WorkloadInfo?
        var suggestedSlots: [TimeSlot] = []
        var draggedTimeBlock: TimeBlock?
    }
    
    enum Input {
        case selectDate(Date)
        case createTimeBlock(for: ProjectTask, at: Date)
        case moveTimeBlock(TimeBlock, to: Date)
        case loadSuggestions(for: ProjectTask)
        case syncWithCalendar
    }
}
```

## 🖼️ Пользовательский интерфейс

### 1. ProjectDashboardView
```swift
struct ProjectDashboardView: View {
    @StateObject private var viewModel = ProjectDashboardViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    // Summary cards
                    ProjectSummaryCardsView(projects: viewModel.state.activeProjects)
                    
                    // Active projects grid
                    ActiveProjectsGridView(projects: viewModel.state.activeProjects)
                    
                    // Upcoming deadlines
                    UpcomingDeadlinesView(tasks: viewModel.state.upcomingDeadlines)
                    
                    // Workload overview
                    WorkloadOverviewView(workload: viewModel.state.workloadInfo)
                }
            }
            .navigationTitle("Проекты")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Добавить") {
                        Button("Новый проект") {
                            viewModel.send(.createNewProject)
                        }
                        Button("Из шаблона") {
                            // Show template picker
                        }
                    }
                }
            }
        }
    }
}
```

### 2. GoalHierarchyView
```swift
struct GoalHierarchyView: View {
    @StateObject private var viewModel = GoalHierarchyViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // View type picker
                HierarchyViewTypePicker(
                    selection: $viewModel.state.hierarchyView
                )
                
                // Hierarchy content
                switch viewModel.state.hierarchyView {
                case .tree:
                    GoalTreeView(
                        goals: viewModel.state.rootGoals,
                        expandedGoals: viewModel.state.expandedGoals,
                        onSelect: { goal in
                            viewModel.send(.selectGoal(goal))
                        },
                        onExpand: { goal in
                            viewModel.send(.expandGoal(goal))
                        }
                    )
                    
                case .timeline:
                    GoalTimelineView(
                        goals: viewModel.state.rootGoals,
                        progressData: viewModel.state.progressData
                    )
                    
                case .progress:
                    HierarchicalProgressView(
                        progressData: viewModel.state.progressData
                    )
                }
            }
            .navigationTitle("Цели")
        }
    }
}
```

### 3. KanbanBoardView
```swift
struct KanbanBoardView: View {
    @StateObject private var viewModel = KanbanBoardViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.md) {
                    ForEach(viewModel.state.columns) { column in
                        KanbanColumnView(
                            column: column,
                            tasks: tasksForColumn(column),
                            onTaskMove: { task, newColumn in
                                viewModel.send(.moveTask(task, to: newColumn))
                            },
                            onTaskCreate: {
                                viewModel.send(.createTask(in: column))
                            }
                        )
                        .frame(width: 300)
                    }
                }
                .padding()
            }
            .navigationTitle("Канбан")
        }
    }
}
```

### 4. TimeBlockingView
```swift
struct TimeBlockingView: View {
    @StateObject private var viewModel = TimeBlockingViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // Date selector
                DatePicker(
                    "Дата",
                    selection: $viewModel.state.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                
                // Calendar view with time blocks
                ScrollView {
                    CalendarDayView(
                        date: viewModel.state.selectedDate,
                        timeBlocks: viewModel.state.timeBlocks,
                        calendarEvents: viewModel.state.calendarEvents,
                        onTimeBlockMove: { timeBlock, newTime in
                            viewModel.send(.moveTimeBlock(timeBlock, to: newTime))
                        },
                        onTimeSlotTap: { time in
                            // Show task selector for creating time block
                        }
                    )
                }
                
                // Suggested time slots
                if !viewModel.state.suggestedSlots.isEmpty {
                    SuggestedTimeSlotsView(
                        slots: viewModel.state.suggestedSlots,
                        onSlotSelect: { slot in
                            // Create time block at suggested slot
                        }
                    )
                }
            }
            .navigationTitle("Time Blocking")
        }
    }
}
```

## 🧩 Продвинутые компоненты

### 1. HierarchicalProgressView
```swift
struct HierarchicalProgressView: View {
    let progressData: [HierarchyProgressData]
    
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(progressData) { data in
                HierarchyProgressBar(
                    goal: data.goal,
                    progress: data.progress,
                    childrenProgress: data.childrenProgress,
                    level: data.level
                )
            }
        }
    }
}
```

### 2. TimeBlockComponent
```swift
struct TimeBlockComponent: View {
    let timeBlock: TimeBlock
    let onMove: (Date) -> Void
    let onResize: (TimeInterval) -> Void
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(timeBlock.color)
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeBlock.title)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text(timeBlock.duration.formatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Handle drag to move time block
                    }
                    .onEnded { value in
                        // Commit time block move
                    }
            )
    }
}
```

### 3. DependencyVisualizerView
```swift
struct DependencyVisualizerView: View {
    let tasks: [ProjectTask]
    let dependencies: [TaskDependency]
    
    var body: some View {
        Canvas { context, size in
            // Draw dependency graph
            drawDependencyGraph(
                context: context,
                size: size,
                tasks: tasks,
                dependencies: dependencies
            )
        }
        .background(Color.clear)
    }
}
```

### 4. EffortEstimationPicker
```swift
struct EffortEstimationPicker: View {
    @Binding var selectedDuration: TimeInterval?
    let suggestions: [TimeInterval]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Расчетное время")
                .font(.headline)
            
            // Quick options
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                ForEach(suggestions, id: \.self) { duration in
                    Button(duration.formatted) {
                        selectedDuration = duration
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedDuration == duration ? .primary : .secondary)
                }
            }
            
            // Custom duration picker
            DurationPicker(duration: $selectedDuration)
        }
    }
}
```

### 5. ProjectGanttChart
```swift
struct ProjectGanttChart: View {
    let project: Project
    let tasks: [ProjectTask]
    let timeRange: ClosedRange<Date>
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Time header
                GanttTimeHeader(timeRange: timeRange)
                
                // Task rows
                ForEach(tasks) { task in
                    GanttTaskRow(
                        task: task,
                        timeRange: timeRange,
                        dependencies: task.dependencies
                    )
                }
            }
        }
        .background(Color(.systemBackground))
    }
}
```

## 🔗 Интеграции

### 1. EventKit Integration
```swift
// CalendarIntegrationService implementation
func createCalendarEvent(for timeBlock: TimeBlock) async throws -> EKEvent {
    let eventStore = EKEventStore()
    let event = EKEvent(eventStore: eventStore)
    
    event.title = timeBlock.title
    event.startDate = timeBlock.startDate
    event.endDate = timeBlock.endDate
    event.calendar = eventStore.defaultCalendarForNewEvents
    
    // Add custom metadata
    event.notes = "Created by Planner App"
    event.url = URL(string: "plannerapp://timeblock/\(timeBlock.id)")
    
    try eventStore.save(event, span: .thisEvent)
    
    // Update time block with calendar event ID
    timeBlock.calendarEventID = event.eventIdentifier
    
    return event
}
```

### 2. Shortcuts Integration
```swift
// App Intents for Shortcuts
struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    
    @Parameter(title: "Task Title")
    var title: String
    
    @Parameter(title: "Project")
    var project: ProjectEntity?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let taskService = ServiceContainer.shared.taskService
        
        let task = ProjectTask(
            title: title,
            project: project?.project
        )
        
        try await taskService.createTask(task)
        
        return .result(dialog: "Task '\(title)' created successfully")
    }
}
```

### 3. Focus Modes Integration
```swift
// FocusModeService implementation
func activateFocusMode(_ focusMode: String, for duration: TimeInterval) async throws {
    if #available(iOS 15.0, *) {
        // Request focus mode activation
        let request = INStartWorkoutIntent()
        request.workoutName = INSpeakableString(spokenPhrase: focusMode)
        
        // Use Shortcuts integration to activate focus mode
        // This would require a pre-configured shortcut
    }
}

func getCurrentFocusMode() async -> String? {
    // Detect current focus mode through system APIs
    // This might require private APIs or heuristics
    return nil // Placeholder
}
```

## 📊 Performance Optimizations

### 1. Efficient Hierarchy Loading
```swift
// Lazy loading for large hierarchies
func loadGoalHierarchy(limit: Int = 50) async throws -> [GoalHierarchy] {
    let descriptor = FetchDescriptor<GoalHierarchy>(
        predicate: #Predicate { $0.parentGoal == nil },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    
    return try await dataService.fetch(GoalHierarchy.self, predicate: descriptor.predicate)
}
```

### 2. Smart Pagination
```swift
// Pagination for large project lists
struct ProjectPagination {
    var offset: Int = 0
    var limit: Int = 20
    var hasMore: Bool = true
    
    mutating func loadNext() async throws -> [Project] {
        let projects = try await projectService.getProjects(
            offset: offset,
            limit: limit
        )
        
        offset += projects.count
        hasMore = projects.count == limit
        
        return projects
    }
}
```

### 3. Background Processing
```swift
// Background calculations for progress
func calculateHierarchyProgress() async {
    await withTaskGroup(of: Void.self) { group in
        for goal in rootGoals {
            group.addTask {
                await self.calculateGoalProgress(goal)
            }
        }
    }
}
```

## 🎨 UX Innovations

### 1. Natural Language Goal Creation
```swift
struct NaturalLanguageGoalParser {
    func parseGoalInput(_ input: String) -> GoalSuggestion? {
        // "I want to save $10,000 by December 2024"
        // → Financial goal, target: $10,000, deadline: Dec 2024
        
        // "Read 24 books this year"
        // → Education goal, target: 24 books, deadline: end of year
        
        // Use NLP to extract goal parameters
        return nil // Placeholder
    }
}
```

### 2. Smart Deadline Suggestions
```swift
func suggestDeadlines(for task: ProjectTask) -> [Date] {
    var suggestions: [Date] = []
    
    // Based on similar tasks
    if let similarTaskDuration = findSimilarTaskDuration(task) {
        suggestions.append(Date().addingTimeInterval(similarTaskDuration))
    }
    
    // Based on project timeline
    if let project = task.project,
       let projectEnd = project.targetEndDate {
        suggestions.append(projectEnd.addingTimeInterval(-7 * 24 * 3600)) // Week before
    }
    
    // Based on workload
    if let nextAvailableSlot = findNextAvailableWorkSlot() {
        suggestions.append(nextAvailableSlot)
    }
    
    return suggestions.sorted()
}
```

### 3. Context-Aware Task Suggestions
```swift
func getContextualTaskSuggestions() async -> [ProjectTask] {
    let currentTime = Date()
    let currentLocation = await getCurrentLocation()
    let currentFocusMode = await getCurrentFocusMode()
    
    var suggestions: [ProjectTask] = []
    
    // Time-based suggestions
    if Calendar.current.component(.hour, from: currentTime) < 10 {
        // Morning tasks
        suggestions.append(contentsOf: getMorningTasks())
    }
    
    // Location-based suggestions
    if currentLocation?.isHome == true {
        suggestions.append(contentsOf: getHomeTasks())
    }
    
    // Focus mode based suggestions
    if currentFocusMode == "Work" {
        suggestions.append(contentsOf: getWorkTasks())
    }
    
    return suggestions
}
```

## 🧪 Тестирование

### Unit Tests
- Model validation tests
- Service logic tests  
- Algorithm performance tests
- Dependency resolution tests

### Integration Tests
- Calendar sync tests
- Template application tests
- Hierarchy calculation tests
- Cross-service communication tests

### UI Tests
- Drag & drop functionality
- Navigation flow tests
- Performance under load
- Accessibility compliance

## 🔮 Будущие возможности

### Machine Learning
- Task duration prediction
- Optimal scheduling AI
- Goal success probability
- Personalized recommendations

### Advanced Analytics
- Productivity insights
- Goal achievement patterns
- Time usage analysis
- Bottleneck identification

### Collaboration Features
- Team project spaces
- Shared goal hierarchies
- Real-time collaboration
- Progress sharing

---

*Документация создана для этапа 11 развития приложения Планнер* 