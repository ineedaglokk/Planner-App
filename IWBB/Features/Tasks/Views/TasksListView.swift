import SwiftUI
import SwiftData

struct TasksListView: View {
    @StateObject private var viewModel: TasksListViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateTask = false
    @State private var selectedTask: Task?
    
    init(taskService: TaskService) {
        self._viewModel = StateObject(wrappedValue: TasksListViewModel(taskService: taskService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterSection
                
                // Content
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.filteredTasks.isEmpty {
                    emptyStateView
                } else {
                    tasksList
                }
            }
            .navigationTitle("Задачи")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        groupingMenu
                        Divider()
                        filterMenu
                        Divider()
                        sortingMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTask) {
                CreateTaskView(taskService: viewModel.taskService)
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task, taskService: viewModel.taskService)
            }
            .refreshable {
                await viewModel.refreshTasks()
            }
            .onAppear {
                viewModel.loadTasks()
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Поиск задач..."
            )
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Active filters display
            if !viewModel.activeFilters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.activeFilters, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                onRemove: {
                                    viewModel.removeFilter(filter)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Stats summary
            if !viewModel.filteredTasks.isEmpty {
                TasksStatsView(
                    total: viewModel.filteredTasks.count,
                    completed: viewModel.completedTasksCount,
                    overdue: viewModel.overdueTasksCount
                )
                .padding(.horizontal)
            }
        }
        .animation(.easeInOut, value: viewModel.activeFilters)
    }
    
    // MARK: - Tasks List
    
    private var tasksList: some View {
        List {
            ForEach(viewModel.groupedTasks.keys.sorted(by: viewModel.groupSortComparator), id: \.self) { group in
                Section {
                    ForEach(viewModel.groupedTasks[group] ?? []) { task in
                        TaskRowView(
                            task: task,
                            onTap: {
                                selectedTask = task
                            },
                            onToggleComplete: {
                                Task {
                                    await viewModel.toggleTaskCompletion(task)
                                }
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteTask(task)
                                }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Удалить", role: .destructive) {
                                Task {
                                    await viewModel.deleteTask(task)
                                }
                            }
                            
                            Button("Изменить") {
                                selectedTask = task
                            }
                            .tint(.blue)
                            
                            if !task.isCompleted {
                                Button("Готово") {
                                    Task {
                                        await viewModel.toggleTaskCompletion(task)
                                    }
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task {
                                    await viewModel.toggleTaskCompletion(task)
                                }
                            } label: {
                                Label(
                                    task.isCompleted ? "Не выполнено" : "Выполнено",
                                    systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                                )
                            }
                            .tint(task.isCompleted ? .orange : .green)
                        }
                    }
                } header: {
                    Text(viewModel.groupDisplayName(for: group))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            // Bulk actions section
            if viewModel.isSelectionMode {
                Section {
                    bulkActionsView
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: viewModel.groupedTasks)
    }
    
    // MARK: - Bulk Actions
    
    private var bulkActionsView: some View {
        HStack {
            Button("Выбрать всё") {
                viewModel.selectAllTasks()
            }
            .disabled(viewModel.selectedTaskIds.count == viewModel.filteredTasks.count)
            
            Spacer()
            
            Button("Завершить выбранные") {
                Task {
                    await viewModel.completeSelectedTasks()
                }
            }
            .disabled(viewModel.selectedTaskIds.isEmpty)
            
            Spacer()
            
            Button("Удалить выбранные", role: .destructive) {
                Task {
                    await viewModel.deleteSelectedTasks()
                }
            }
            .disabled(viewModel.selectedTaskIds.isEmpty)
        }
        .font(.caption)
    }
    
    // MARK: - Menu Sections
    
    private var groupingMenu: some View {
        Menu("Группировка") {
            ForEach(TaskGrouping.allCases, id: \.self) { grouping in
                Button {
                    viewModel.setGrouping(grouping)
                } label: {
                    HStack {
                        Text(grouping.displayName)
                        if viewModel.currentGrouping == grouping {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    private var filterMenu: some View {
        Menu("Фильтры") {
            Button("Только активные") {
                viewModel.toggleFilter(.active)
            }
            
            Button("Только завершенные") {
                viewModel.toggleFilter(.completed)
            }
            
            Button("Просроченные") {
                viewModel.toggleFilter(.overdue)
            }
            
            Button("Сегодня") {
                viewModel.toggleFilter(.today)
            }
            
            Button("На этой неделе") {
                viewModel.toggleFilter(.thisWeek)
            }
            
            Divider()
            
            Menu("По приоритету") {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button(priority.displayName) {
                        viewModel.toggleFilter(.priority(priority))
                    }
                }
            }
        }
    }
    
    private var sortingMenu: some View {
        Menu("Сортировка") {
            ForEach(TaskSorting.allCases, id: \.self) { sorting in
                Button {
                    viewModel.setSorting(sorting)
                } label: {
                    HStack {
                        Text(sorting.displayName)
                        if viewModel.currentSorting == sorting {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Loading and Empty States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка задач...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Нет задач")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Создать задачу") {
                showingCreateTask = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateMessage: String {
        if !viewModel.searchText.isEmpty {
            return "По запросу \"\(viewModel.searchText)\" ничего не найдено"
        } else if !viewModel.activeFilters.isEmpty {
            return "Нет задач, соответствующих выбранным фильтрам"
        } else {
            return "Создайте вашу первую задачу, чтобы начать планирование"
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue)
        .clipShape(Capsule())
    }
}

struct TasksStatsView: View {
    let total: Int
    let completed: Int
    let overdue: Int
    
    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                title: "Всего",
                value: total,
                color: .blue
            )
            
            StatItem(
                title: "Выполнено",
                value: completed,
                color: .green
            )
            
            if overdue > 0 {
                StatItem(
                    title: "Просрочено",
                    value: overdue,
                    color: .red
                )
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatItem: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    TasksListView(taskService: MockTaskService())
        .modelContainer(for: Task.self, inMemory: true)
} 