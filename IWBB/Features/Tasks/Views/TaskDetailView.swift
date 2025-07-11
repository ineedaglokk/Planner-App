import SwiftUI

struct TaskDetailView: View {
    let task: Task
    let taskService: TaskService
    
    @StateObject private var viewModel: TaskDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    
    init(task: Task, taskService: TaskService) {
        self.task = task
        self.taskService = taskService
        self._viewModel = StateObject(wrappedValue: TaskDetailViewModel(
            task: task,
            taskService: taskService
        ))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with title and status
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Timer Section (if not completed)
                    if !task.isCompleted {
                        timerSection
                    }
                    
                    // Progress Section
                    progressSection
                    
                    // Description
                    if !task.taskDescription.isEmpty {
                        descriptionSection
                    }
                    
                    // Subtasks
                    if !task.subtasks.isEmpty {
                        subtasksSection
                    }
                    
                    // Dependencies
                    if !task.dependencies.isEmpty {
                        dependenciesSection
                    }
                    
                    // Metadata
                    metadataSection
                    
                    // Activity History
                    activitySection
                    
                    // Statistics
                    statisticsSection
                }
                .padding()
            }
            .navigationTitle("Детали задачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                        
                        Button {
                            Task {
                                await viewModel.toggleTaskCompletion()
                            }
                        } label: {
                            Label(
                                task.isCompleted ? "Отметить как не выполнено" : "Отметить как выполнено",
                                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                            )
                        }
                        
                        Button {
                            Task {
                                await viewModel.toggleFavorite()
                            }
                        } label: {
                            Label(
                                task.isFavorite ? "Удалить из избранного" : "Добавить в избранное",
                                systemImage: task.isFavorite ? "heart.fill" : "heart"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteTask()
                                dismiss()
                            }
                        } label: {
                            Label("Удалить задачу", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                CreateTaskView(
                    taskService: taskService,
                    taskToEdit: task
                )
            }
            .onAppear {
                viewModel.startObserving()
            }
            .onDisappear {
                viewModel.stopObserving()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                TaskCheckboxView(
                    isChecked: task.isCompleted,
                    style: .large,
                    onToggle: {
                        Task {
                            await viewModel.toggleTaskCompletion()
                        }
                    }
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        PriorityBadgeView(
                            priority: task.priority,
                            style: .full
                        )
                        
                        if let category = task.category {
                            CategoryTagView(
                                category: category,
                                style: .full
                            )
                        }
                        
                        if task.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            
            if let dueDate = task.dueDate {
                DueDateView(
                    dueDate: dueDate,
                    isCompleted: task.isCompleted,
                    style: .detailed
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            if !task.isCompleted {
                Button {
                    Task {
                        await viewModel.toggleTaskCompletion()
                    }
                } label: {
                    Label("Завершить", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button {
                showingEditSheet = true
            } label: {
                Label("Изменить", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            if !task.isCompleted && viewModel.canStartTimer {
                Button {
                    viewModel.startTimer()
                } label: {
                    Label("Начать", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
    
    private var timerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Время работы")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.isTimerRunning {
                    Button("Пауза") {
                        viewModel.pauseTimer()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                } else if viewModel.timerElapsed > 0 {
                    Button("Продолжить") {
                        viewModel.resumeTimer()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            
            // Timer Display
            VStack(spacing: 8) {
                Text(viewModel.formattedTimerTime)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.isTimerRunning ? .green : .primary)
                
                if viewModel.totalTimeSpent > 0 {
                    Text("Всего: \(viewModel.formattedTotalTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            
            // Timer Controls
            if viewModel.isTimerRunning || viewModel.timerElapsed > 0 {
                HStack(spacing: 16) {
                    if viewModel.isTimerRunning {
                        Button("Пауза") {
                            viewModel.pauseTimer()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Продолжить") {
                            viewModel.resumeTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    
                    Button("Остановить") {
                        viewModel.stopTimer()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Button("Сбросить") {
                        viewModel.resetTimer()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Прогресс")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(viewModel.completionProgress * 100))%")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: viewModel.completionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 2)
            
            if !task.subtasks.isEmpty {
                HStack {
                    Text("Подзадач выполнено:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(viewModel.completedSubtasksCount) из \(task.subtasks.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Описание")
                .font(.headline)
            
            Text(task.taskDescription)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Подзадачи (\(task.subtasks.count))")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(task.subtasks.sorted(by: { !$0.isCompleted && $1.isCompleted })) { subtask in
                    HStack(spacing: 12) {
                        TaskCheckboxView(
                            isChecked: subtask.isCompleted,
                            style: .standard,
                            onToggle: {
                                Task {
                                    await viewModel.toggleSubtaskCompletion(subtask)
                                }
                            }
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(subtask.title)
                                .font(.body)
                                .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                                .strikethrough(subtask.isCompleted)
                            
                            if !subtask.taskDescription.isEmpty {
                                Text(subtask.taskDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let dueDate = subtask.dueDate {
                            DueDateView(
                                dueDate: dueDate,
                                isCompleted: subtask.isCompleted,
                                style: .compact
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Зависимости (\(task.dependencies.count))")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(task.dependencies) { dependency in
                    HStack(spacing: 12) {
                        TaskCheckboxView(
                            isChecked: dependency.isCompleted,
                            style: .standard,
                            onToggle: { }
                        )
                        .disabled(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dependency.title)
                                .font(.body)
                                .foregroundColor(dependency.isCompleted ? .secondary : .primary)
                                .strikethrough(dependency.isCompleted)
                            
                            if !dependency.taskDescription.isEmpty {
                                Text(dependency.taskDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        PriorityBadgeView(
                            priority: dependency.priority,
                            style: .compact
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var metadataSection: some View {
        VStack(spacing: 12) {
            Text("Информация")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                MetadataRow(
                    label: "Создано",
                    value: DateFormatter.detailed.string(from: task.createdAt)
                )
                
                if let completedAt = task.completedAt {
                    MetadataRow(
                        label: "Завершено",
                        value: DateFormatter.detailed.string(from: completedAt)
                    )
                }
                
                if task.isRecurring {
                    MetadataRow(
                        label: "Повторение",
                        value: task.recurringPattern?.displayName ?? "Не задано"
                    )
                }
                
                if task.hasNotifications {
                    MetadataRow(
                        label: "Уведомления",
                        value: "Включены"
                    )
                }
                
                if viewModel.totalTimeSpent > 0 {
                    MetadataRow(
                        label: "Время работы",
                        value: viewModel.formattedTotalTime
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Активность")
                .font(.headline)
            
            if viewModel.activityHistory.isEmpty {
                Text("Нет записей")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.activityHistory.prefix(5), id: \.timestamp) { activity in
                        HStack(spacing: 12) {
                            Image(systemName: activity.icon)
                                .foregroundColor(activity.color)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.description)
                                    .font(.body)
                                
                                Text(activity.formattedTimestamp)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if viewModel.activityHistory.count > 5 {
                    Button("Показать всю историю") {
                        viewModel.showAllActivity = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            Text("Статистика")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    title: "Дней до дедлайна",
                    value: viewModel.daysUntilDue,
                    icon: "calendar",
                    color: viewModel.daysUntilDueColor
                )
                
                StatCard(
                    title: "Производительность",
                    value: "\(Int(viewModel.completionProgress * 100))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
                
                if !task.subtasks.isEmpty {
                    StatCard(
                        title: "Подзадачи",
                        value: "\(viewModel.completedSubtasksCount)/\(task.subtasks.count)",
                        icon: "list.bullet",
                        color: .green
                    )
                }
                
                if viewModel.totalTimeSpent > 0 {
                    StatCard(
                        title: "Время",
                        value: viewModel.formattedTotalTimeShort,
                        icon: "timer",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Supporting Views

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let detailed: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    TaskDetailView(
        task: Task.preview(),
        taskService: MockTaskService()
    )
} 