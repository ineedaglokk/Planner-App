import SwiftUI
import Charts

// MARK: - KanbanBoardView

struct KanbanBoardView: View {
    @Environment(\.services) private var services
    @State private var viewModel: KanbanBoardViewModel
    
    // UI State
    @State private var selectedTask: ProjectTask?
    @State private var showingTaskDetail = false
    @State private var showingCreateTask = false
    @State private var showingBoardSettings = false
    
    init() {
        let services = ServiceContainer()
        _viewModel = State(initialValue: KanbanBoardViewModel(
            taskService: services.taskService,
            projectManagementService: services.projectManagementService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Board Header
                KanbanHeaderView()
                
                // Board Content
                KanbanColumnsView()
                
                // Board Footer with Analytics
                if viewModel.showAnalytics {
                    KanbanAnalyticsBar()
                }
            }
            .navigationTitle(viewModel.selectedProject?.name ?? "Kanban Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateTask = true }) {
                        Image(systemName: "plus")
                    }
                    
                    Button(action: { showingBoardSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    
                    Button(action: { viewModel.showAnalytics.toggle() }) {
                        Image(systemName: "chart.bar")
                    }
                }
            }
            .task {
                await viewModel.loadTasks()
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskSheet()
            }
            .sheet(isPresented: $showingBoardSettings) {
                BoardSettingsSheet()
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = selectedTask {
                    TaskDetailSheet(task: task)
                }
            }
            .alert("Ошибка", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Kanban Header

private struct KanbanHeaderView: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Board Layout Picker
            Picker("Макет доски", selection: $viewModel.boardLayout) {
                ForEach(BoardLayout.allCases, id: \.self) { layout in
                    Text(layout.displayName)
                        .tag(layout)
                }
            }
            .pickerStyle(.segmented)
            
            // Filters and Search
            HStack {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Поиск задач...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: { viewModel.searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                
                // Filters Menu
                Menu {
                    Section("Исполнитель") {
                        ForEach(viewModel.availableAssignees, id: \.self) { assignee in
                            Button(assignee) {
                                viewModel.selectedAssignee = assignee
                            }
                        }
                        
                        Button("Без исполнителя") {
                            viewModel.selectedAssignee = "Unassigned"
                        }
                        
                        Button("Сбросить") {
                            viewModel.selectedAssignee = nil
                        }
                    }
                    
                    Section("Приоритет") {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            Button(priority.displayName) {
                                viewModel.selectedPriority = priority
                            }
                        }
                        
                        Button("Сбросить") {
                            viewModel.selectedPriority = nil
                        }
                    }
                    
                    Section("Теги") {
                        ForEach(viewModel.availableTags, id: \.self) { tag in
                            Button(tag) {
                                if viewModel.selectedTags.contains(tag) {
                                    viewModel.selectedTags.remove(tag)
                                } else {
                                    viewModel.selectedTags.insert(tag)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Фильтры")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.hasActiveFilters ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    )
                    .foregroundStyle(viewModel.hasActiveFilters ? .blue : .primary)
                }
            }
            
            // Active Filters
            if viewModel.hasActiveFilters {
                ActiveFiltersRow()
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Active Filters Row

private struct ActiveFiltersRow: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let assignee = viewModel.selectedAssignee {
                    FilterChip(text: assignee) {
                        viewModel.selectedAssignee = nil
                    }
                }
                
                if let priority = viewModel.selectedPriority {
                    FilterChip(text: priority.displayName) {
                        viewModel.selectedPriority = nil
                    }
                }
                
                ForEach(Array(viewModel.selectedTags), id: \.self) { tag in
                    FilterChip(text: tag) {
                        viewModel.selectedTags.remove(tag)
                    }
                }
                
                Button("Очистить все") {
                    viewModel.clearAllFilters()
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.2))
        )
        .foregroundStyle(.blue)
    }
}

// MARK: - Kanban Columns View

private struct KanbanColumnsView: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(viewModel.visibleColumns, id: \.type) { column in
                    KanbanColumnView(column: column)
                        .frame(width: 300)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Kanban Column View

private struct KanbanColumnView: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    let column: KanbanColumn
    
    var body: some View {
        VStack(spacing: 0) {
            // Column Header
            ColumnHeaderView(column: column)
            
            // Tasks List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.getTasksForColumn(column.type)) { task in
                        TaskCardView(task: task, column: column.type)
                            .onTapGesture {
                                viewModel.selectedTask = task
                            }
                    }
                    
                    // Add Task Button
                    if column.type == .backlog || column.type == .todo {
                        AddTaskToColumnButton(column: column.type)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onDrop(of: [.text], isTargeted: nil) { providers in
            return viewModel.handleTaskDrop(to: column.type, providers: providers)
        }
    }
}

// MARK: - Column Header View

private struct ColumnHeaderView: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    let column: KanbanColumn
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Column Icon
                Image(systemName: column.type.iconName)
                    .foregroundStyle(column.type.color)
                    .font(.title3)
                
                // Column Title
                Text(column.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Task Count
                Text("\(viewModel.getTaskCount(for: column.type))")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(column.type.color.opacity(0.2))
                    )
                    .foregroundStyle(column.type.color)
            }
            
            // WIP Limit Indicator
            if let wipLimit = column.wipLimit {
                WIPLimitIndicatorView(
                    current: viewModel.getTaskCount(for: column.type),
                    limit: wipLimit,
                    isViolated: viewModel.isWIPLimitViolated(for: column.type)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(column.type.color.opacity(0.1))
        )
    }
}

// MARK: - WIP Limit Indicator

private struct WIPLimitIndicatorView: View {
    let current: Int
    let limit: Int
    let isViolated: Bool
    
    var body: some View {
        HStack {
            Text("WIP: \(current)/\(limit)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isViolated ? .red : .secondary)
            
            Spacer()
            
            if isViolated {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Task Card View

private struct TaskCardView: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    let task: ProjectTask
    let column: KanbanColumnType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with Priority and Actions
            HStack {
                PriorityBadge(priority: task.priority)
                
                Spacer()
                
                Menu {
                    ForEach(KanbanColumnType.allCases.filter { $0 != column }, id: \.self) { targetColumn in
                        Button("Переместить в \(targetColumn.displayName)") {
                            Task { await viewModel.moveTask(task, to: targetColumn) }
                        }
                    }
                    
                    Divider()
                    
                    Button("Редактировать", systemImage: "pencil") {
                        viewModel.selectedTask = task
                    }
                    
                    Button("Удалить", systemImage: "trash", role: .destructive) {
                        Task { await viewModel.deleteTask(task) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Task Title
            Text(task.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Task Description
            if let description = task.taskDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            
            // Tags
            if !task.tags.isEmpty {
                TaskTagsView(tags: task.tags)
            }
            
            // Footer with Assignee and Due Date
            HStack {
                // Assignee
                if let assignee = task.assignee {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        
                        Text(assignee)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Due Date
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(task.isOverdue ? .red : .orange)
                            .font(.caption2)
                        
                        Text(dueDate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
            }
            
            // Subtasks Progress
            if !task.subtasks.isEmpty {
                SubtasksProgressView(subtasks: task.subtasks)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(task.priority.color.opacity(0.3), lineWidth: 1)
                )
        )
        .onDrag {
            viewModel.startDragging(task)
            return NSItemProvider(object: task.id.uuidString as NSString)
        }
    }
}

// MARK: - Priority Badge

private struct PriorityBadge: View {
    let priority: Priority
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priority.color)
                .frame(width: 6, height: 6)
            
            Text(priority.displayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(priority.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(priority.color.opacity(0.15))
        )
    }
}

// MARK: - Task Tags View

private struct TaskTagsView: View {
    let tags: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                        )
                        .foregroundStyle(.secondary)
                }
                
                if tags.count > 3 {
                    Text("+\(tags.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Subtasks Progress View

private struct SubtasksProgressView: View {
    let subtasks: [ProjectTask]
    
    private var completedCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }
    
    private var progress: Double {
        guard !subtasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(subtasks.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Подзадачи")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(completedCount)/\(subtasks.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(.blue)
        }
    }
}

// MARK: - Add Task to Column Button

private struct AddTaskToColumnButton: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    let column: KanbanColumnType
    
    var body: some View {
        Button(action: {
            viewModel.newTaskColumn = column
            viewModel.showingCreateTask = true
        }) {
            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.blue)
                
                Text("Добавить задачу")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1, style: StrokeStyle(dash: [5]))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kanban Analytics Bar

private struct KanbanAnalyticsBar: View {
    @EnvironmentObject private var viewModel: KanbanBoardViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Quick Metrics
            if let metrics = viewModel.boardMetrics {
                HStack(spacing: 16) {
                    QuickMetricView(
                        title: "Скорость",
                        value: String(format: "%.1f", metrics.velocity),
                        subtitle: "задач/неделя",
                        color: .blue
                    )
                    
                    QuickMetricView(
                        title: "Время цикла",
                        value: String(format: "%.1f", metrics.averageCycleTime),
                        subtitle: "дней",
                        color: .orange
                    )
                    
                    QuickMetricView(
                        title: "Lead Time",
                        value: String(format: "%.1f", metrics.averageLeadTime),
                        subtitle: "дней",
                        color: .green
                    )
                    
                    Spacer()
                }
            }
            
            // WIP Violations
            if !viewModel.wipViolations.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    
                    Text("Превышение WIP лимитов: \(viewModel.wipViolations.count)")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Подробнее") {
                        viewModel.showingWIPDetails = true
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(
            Rectangle()
                .fill(Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 2, x: 0, y: -1)
        )
    }
}

// MARK: - Quick Metric View

private struct QuickMetricView: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Extensions

extension KanbanColumnType {
    var displayName: String {
        switch self {
        case .backlog: return "Бэклог"
        case .ready: return "Готово к работе"
        case .todo: return "К выполнению"
        case .inProgress: return "В работе"
        case .codeReview: return "Code Review"
        case .testing: return "Тестирование"
        case .review: return "Ревью"
        case .deployment: return "Деплой"
        case .done: return "Выполнено"
        case .blocked: return "Заблокировано"
        case .custom: return "Кастомная"
        }
    }
    
    var iconName: String {
        switch self {
        case .backlog: return "list.bullet"
        case .ready: return "tray"
        case .todo: return "circle"
        case .inProgress: return "play.circle"
        case .codeReview: return "eye.circle"
        case .testing: return "checkmark.circle"
        case .review: return "magnifyingglass.circle"
        case .deployment: return "arrow.up.circle"
        case .done: return "checkmark.circle.fill"
        case .blocked: return "exclamationmark.triangle"
        case .custom: return "square.stack"
        }
    }
    
    var color: Color {
        switch self {
        case .backlog: return .gray
        case .ready: return .blue
        case .todo: return .orange
        case .inProgress: return .yellow
        case .codeReview: return .purple
        case .testing: return .cyan
        case .review: return .indigo
        case .deployment: return .pink
        case .done: return .green
        case .blocked: return .red
        case .custom: return .brown
        }
    }
}

extension BoardLayout {
    var displayName: String {
        switch self {
        case .standard: return "Стандартный"
        case .simple: return "Упрощенный"
        case .detailed: return "Детальный"
        case .custom: return "Настраиваемый"
        }
    }
}

extension Priority {
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        }
    }
}

// MARK: - Preview

#Preview {
    KanbanBoardView()
        .environment(\.services, ServiceContainer.preview())
} 