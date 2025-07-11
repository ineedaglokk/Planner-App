import SwiftUI

// MARK: - Create Task Sheet

struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    
    // Initialization
    let initialProject: Project?
    let initialColumn: KanbanColumnType?
    
    init(project: Project? = nil, column: KanbanColumnType? = nil) {
        self.initialProject = project
        self.initialColumn = column
    }
    
    // Form State
    @State private var taskTitle = ""
    @State private var taskDescription = ""
    @State private var selectedProject: Project?
    @State private var selectedPriority: Priority = .medium
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var hasDueDate = false
    @State private var estimatedDuration: TimeInterval = 3600 // 1 hour
    @State private var hasEstimatedDuration = false
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var assignee = ""
    @State private var hasAssignee = false
    
    // Subtasks
    @State private var subtasks: [SubtaskItem] = []
    @State private var newSubtaskTitle = ""
    @State private var showingSubtasks = false
    
    // Dependencies
    @State private var dependencies: [ProjectTask] = []
    @State private var showingDependencies = false
    
    // Time Blocking
    @State private var shouldCreateTimeBlock = false
    @State private var timeBlockDate = Date()
    @State private var timeBlockStartTime = Date()
    
    // State
    @State private var availableProjects: [Project] = []
    @State private var availableTasks: [ProjectTask] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    // Validation
    private var isValid: Bool {
        !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedProject != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Basic Information
                    BasicInformationSection()
                    
                    // Project Selection
                    ProjectSelectionSection()
                    
                    // Priority and Scheduling
                    PrioritySchedulingSection()
                    
                    // Time Estimation
                    TimeEstimationSection()
                    
                    // Assignment
                    AssignmentSection()
                    
                    // Subtasks
                    SubtasksSection()
                    
                    // Dependencies
                    DependenciesSection()
                    
                    // Time Blocking
                    TimeBlockingSection()
                    
                    // Tags
                    TagsSection()
                }
                .padding()
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        Task { await createTask() }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .task {
                await loadData()
            }
            .alert("Ошибка", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Basic Information Section
    
    @ViewBuilder
    private func BasicInformationSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Основная информация")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TextField("Название задачи", text: $taskTitle)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Описание (необязательно)", text: $taskDescription, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Project Selection Section
    
    @ViewBuilder
    private func ProjectSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Проект")
                .font(.headline)
                .fontWeight(.semibold)
            
            if availableProjects.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Загрузка проектов...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Выберите проект", selection: $selectedProject) {
                    Text("Выберите проект...")
                        .tag(nil as Project?)
                    
                    ForEach(availableProjects) { project in
                        HStack {
                            Image(systemName: project.icon ?? "folder.fill")
                                .foregroundStyle(project.color?.color ?? .blue)
                            Text(project.name)
                        }
                        .tag(project as Project?)
                    }
                }
                .pickerStyle(.menu)
                
                if let selectedProject = selectedProject {
                    ProjectInfoCard(project: selectedProject)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Priority and Scheduling Section
    
    @ViewBuilder
    private func PrioritySchedulingSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Приоритет и сроки")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Priority Selection
                HStack {
                    Text("Приоритет:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Picker("Приоритет", selection: $selectedPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 8, height: 8)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Due Date
                Toggle("Установить дату выполнения", isOn: $hasDueDate)
                
                if hasDueDate {
                    DatePicker("Дата выполнения", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Time Estimation Section
    
    @ViewBuilder
    private func TimeEstimationSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Временная оценка")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("Добавить оценку времени", isOn: $hasEstimatedDuration)
                
                if hasEstimatedDuration {
                    HStack {
                        Text("Оценка:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        DurationPickerView(duration: $estimatedDuration)
                    }
                    
                    // Quick Presets
                    HStack {
                        ForEach(DurationPreset.allCases, id: \.self) { preset in
                            Button(preset.displayName) {
                                estimatedDuration = preset.duration
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Assignment Section
    
    @ViewBuilder
    private func AssignmentSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Назначение")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("Назначить исполнителя", isOn: $hasAssignee)
                
                if hasAssignee {
                    TextField("Имя исполнителя", text: $assignee)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Subtasks Section
    
    @ViewBuilder
    private func SubtasksSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Подзадачи")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingSubtasks.toggle() }) {
                    Image(systemName: showingSubtasks ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.blue)
                }
            }
            
            if showingSubtasks {
                VStack(spacing: 12) {
                    // Add Subtask
                    HStack {
                        TextField("Название подзадачи", text: $newSubtaskTitle)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Добавить") {
                            addSubtask()
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // Subtasks List
                    if !subtasks.isEmpty {
                        LazyVStack(spacing: 8) {
                            ForEach(subtasks.indices, id: \.self) { index in
                                SubtaskRowView(
                                    subtask: $subtasks[index],
                                    onDelete: { removeSubtask(at: index) }
                                )
                            }
                        }
                    }
                }
            } else if !subtasks.isEmpty {
                Text("\(subtasks.count) подзадач")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Dependencies Section
    
    @ViewBuilder
    private func DependenciesSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Зависимости")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showingDependencies.toggle() }) {
                    Image(systemName: showingDependencies ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.blue)
                }
            }
            
            if showingDependencies {
                VStack(spacing: 12) {
                    Text("Эта задача зависит от:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Available Tasks Picker
                    Picker("Добавить зависимость", selection: Binding<ProjectTask?>(
                        get: { nil },
                        set: { task in
                            if let task = task, !dependencies.contains(where: { $0.id == task.id }) {
                                dependencies.append(task)
                            }
                        }
                    )) {
                        Text("Выберите задачу...")
                            .tag(nil as ProjectTask?)
                        
                        ForEach(availableTasksForDependency) { task in
                            Text(task.title)
                                .tag(task as ProjectTask?)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Dependencies List
                    if !dependencies.isEmpty {
                        LazyVStack(spacing: 8) {
                            ForEach(dependencies) { task in
                                DependencyRowView(task: task) {
                                    dependencies.removeAll { $0.id == task.id }
                                }
                            }
                        }
                    }
                }
            } else if !dependencies.isEmpty {
                Text("\(dependencies.count) зависимостей")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Time Blocking Section
    
    @ViewBuilder
    private func TimeBlockingSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Планирование времени")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("Создать блок времени", isOn: $shouldCreateTimeBlock)
                
                if shouldCreateTimeBlock {
                    VStack(spacing: 8) {
                        DatePicker("Дата", selection: $timeBlockDate, displayedComponents: .date)
                        
                        DatePicker("Время начала", selection: $timeBlockStartTime, displayedComponents: .hourAndMinute)
                        
                        if hasEstimatedDuration {
                            HStack {
                                Text("Длительность:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text(formatDuration(estimatedDuration))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Tags Section
    
    @ViewBuilder
    private func TagsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Теги")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    TextField("Добавить тег", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTag() }
                    
                    Button("Добавить") { addTag() }
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(text: tag) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func ProjectInfoCard(project: Project) -> some View {
        HStack {
            Image(systemName: project.icon ?? "folder.fill")
                .foregroundStyle(project.color?.color ?? .blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let description = project.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text("\(Int(project.progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Computed Properties
    
    private var availableTasksForDependency: [ProjectTask] {
        availableTasks.filter { task in
            guard let selectedProject = selectedProject else { return false }
            return task.project?.id == selectedProject.id && !dependencies.contains(where: { $0.id == task.id })
        }
    }
    
    // MARK: - Helper Methods
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty && !tags.contains(trimmedTag) else { return }
        
        tags.append(trimmedTag)
        newTag = ""
    }
    
    private func addSubtask() {
        let trimmedTitle = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        subtasks.append(SubtaskItem(title: trimmedTitle))
        newSubtaskTitle = ""
    }
    
    private func removeSubtask(at index: Int) {
        subtasks.remove(at: index)
    }
    
    private func loadData() async {
        do {
            async let projects = services.projectManagementService.getAllProjects()
            async let tasks = services.taskService.getAllTasks()
            
            availableProjects = try await projects
            availableTasks = try await tasks
            
            // Set initial values
            if let initialProject = initialProject {
                selectedProject = initialProject
            }
        } catch {
            self.error = error
        }
    }
    
    private func createTask() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let project = selectedProject else { return }
            
            let task = ProjectTask(
                title: taskTitle,
                description: taskDescription.isEmpty ? nil : taskDescription,
                project: project,
                priority: selectedPriority,
                dueDate: hasDueDate ? dueDate : nil,
                estimatedDuration: hasEstimatedDuration ? estimatedDuration : nil,
                assignee: hasAssignee ? assignee : nil,
                tags: tags,
                status: initialColumn?.toTaskStatus() ?? .todo,
                dependencies: dependencies.map { $0.id }
            )
            
            let createdTask = try await services.taskService.createTask(task)
            
            // Create subtasks
            for subtaskItem in subtasks {
                let subtask = ProjectTask(
                    title: subtaskItem.title,
                    description: nil,
                    project: project,
                    priority: selectedPriority,
                    parentTask: createdTask,
                    status: .todo
                )
                try await services.taskService.createTask(subtask)
            }
            
            // Create time block if requested
            if shouldCreateTimeBlock && hasEstimatedDuration {
                let calendar = Calendar.current
                let startTime = calendar.dateInterval(of: .day, for: timeBlockDate)?.start ?? timeBlockDate
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeBlockStartTime)
                
                if let finalStartTime = calendar.date(bySettingHour: timeComponents.hour ?? 9, 
                                                   minute: timeComponents.minute ?? 0, 
                                                   second: 0, 
                                                   of: startTime) {
                    
                    let timeBlock = TimeBlock(
                        title: taskTitle,
                        description: "Работа над задачей: \(taskTitle)",
                        startDate: finalStartTime,
                        duration: estimatedDuration,
                        task: createdTask,
                        project: project,
                        isCompleted: false
                    )
                    
                    try await services.timeBlockingService.createTimeBlock(timeBlock)
                }
            }
            
            dismiss()
        } catch {
            self.error = error
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)ч \(minutes)мин"
        } else if hours > 0 {
            return "\(hours)ч"
        } else {
            return "\(minutes)мин"
        }
    }
}

// MARK: - Supporting Types

struct SubtaskItem: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted = false
}

enum DurationPreset: CaseIterable {
    case thirtyMinutes, oneHour, twoHours, halfDay, fullDay
    
    var duration: TimeInterval {
        switch self {
        case .thirtyMinutes: return 1800
        case .oneHour: return 3600
        case .twoHours: return 7200
        case .halfDay: return 14400
        case .fullDay: return 28800
        }
    }
    
    var displayName: String {
        switch self {
        case .thirtyMinutes: return "30мин"
        case .oneHour: return "1ч"
        case .twoHours: return "2ч"
        case .halfDay: return "4ч"
        case .fullDay: return "8ч"
        }
    }
}

// MARK: - Supporting Views

private struct SubtaskRowView: View {
    @Binding var subtask: SubtaskItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: { subtask.isCompleted.toggle() }) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            TextField("Название подзадачи", text: $subtask.title)
                .textFieldStyle(.plain)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct DependencyRowView: View {
    let task: ProjectTask
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.right")
                .foregroundStyle(.blue)
                .font(.caption)
            
            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

private struct DurationPickerView: View {
    @Binding var duration: TimeInterval
    
    private var hours: Int {
        Int(duration) / 3600
    }
    
    private var minutes: Int {
        Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
    }
    
    var body: some View {
        HStack {
            Picker("Часы", selection: Binding(
                get: { hours },
                set: { duration = TimeInterval($0 * 3600 + minutes * 60) }
            )) {
                ForEach(0..<24) { hour in
                    Text("\(hour)ч").tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 100)
            .clipped()
            
            Picker("Минуты", selection: Binding(
                get: { minutes },
                set: { duration = TimeInterval(hours * 3600 + $0 * 60) }
            )) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text("\(minute)мин").tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 100)
            .clipped()
        }
    }
}

// MARK: - Extensions

extension KanbanColumnType {
    func toTaskStatus() -> TaskStatus {
        switch self {
        case .backlog, .ready, .todo: return .todo
        case .inProgress: return .inProgress
        case .done: return .completed
        default: return .inProgress
        }
    }
}

// MARK: - Preview

#Preview {
    CreateTaskSheet()
        .environment(\.services, ServiceContainer.preview())
} 