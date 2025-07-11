import SwiftUI

struct CreateTaskView: View {
    let taskService: TaskService
    let taskToEdit: Task?
    
    @StateObject private var viewModel: CreateTaskViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: Field?
    
    init(taskService: TaskService, taskToEdit: Task? = nil) {
        self.taskService = taskService
        self.taskToEdit = taskToEdit
        self._viewModel = StateObject(wrappedValue: CreateTaskViewModel(
            taskService: taskService,
            taskToEdit: taskToEdit
        ))
    }
    
    enum Field {
        case title, description, naturalLanguageInput
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Natural Language Input Section
                naturalLanguageSection
                
                // Basic Information
                basicInfoSection
                
                // Due Date and Time
                dueDateSection
                
                // Category and Priority
                categoryPrioritySection
                
                // Subtasks
                subtasksSection
                
                // Recurring Tasks
                if !isEditMode {
                    recurringSection
                }
                
                // Dependencies
                dependenciesSection
                
                // Advanced Options
                advancedSection
            }
            .navigationTitle(isEditMode ? "Редактировать задачу" : "Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "Сохранить" : "Создать") {
                        Task {
                            await saveTask()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                    .fontWeight(.semibold)
                }
            }
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onAppear {
                if !isEditMode {
                    focusedField = .naturalLanguageInput
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var naturalLanguageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "Например: 'Купить молоко завтра в 15:00'",
                    text: $viewModel.naturalLanguageInput,
                    axis: .vertical
                )
                .focused($focusedField, equals: .naturalLanguageInput)
                .lineLimit(2...4)
                
                if !viewModel.parsedComponents.isEmpty {
                    parsedComponentsView
                }
                
                if !viewModel.dateSuggestions.isEmpty {
                    dateSuggestionsView
                }
            }
        } header: {
            Text("Быстрый ввод")
        } footer: {
            Text("Опишите задачу естественным языком, включая дату и время")
        }
    }
    
    private var basicInfoSection: some View {
        Section("Основная информация") {
            TextField("Название задачи", text: $viewModel.title)
                .focused($focusedField, equals: .title)
            
            TextField(
                "Описание (необязательно)",
                text: $viewModel.description,
                axis: .vertical
            )
            .focused($focusedField, equals: .description)
            .lineLimit(3...6)
        }
    }
    
    private var dueDateSection: some View {
        Section("Дедлайн") {
            HStack {
                Toggle("Установить дедлайн", isOn: $viewModel.hasDueDate)
                
                if viewModel.hasDueDate {
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: $viewModel.dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }
            }
            
            if viewModel.hasDueDate {
                DueDatePickerView(
                    selectedDate: $viewModel.dueDate,
                    hasTime: $viewModel.hasTime
                )
            }
        }
    }
    
    private var categoryPrioritySection: some View {
        Section("Категория и приоритет") {
            // Category
            HStack {
                Text("Категория")
                Spacer()
                CategoryPickerView(
                    selectedCategory: $viewModel.category,
                    availableCategories: viewModel.availableCategories
                )
            }
            
            // Priority
            HStack {
                Text("Приоритет")
                Spacer()
                Picker("Приоритет", selection: $viewModel.priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        HStack {
                            PriorityBadgeView(priority: priority, style: .full)
                            Text(priority.displayName)
                        }
                        .tag(priority)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    private var subtasksSection: some View {
        Section {
            ForEach(viewModel.subtasks.indices, id: \.self) { index in
                HStack {
                    TextField("Подзадача", text: $viewModel.subtasks[index].title)
                    
                    Button {
                        viewModel.removeSubtask(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .onDelete { indexSet in
                viewModel.removeSubtasks(at: indexSet)
            }
            
            Button {
                viewModel.addSubtask()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("Добавить подзадачу")
                }
            }
        } header: {
            Text("Подзадачи (\(viewModel.subtasks.count))")
        }
    }
    
    private var recurringSection: some View {
        Section("Повторение") {
            Toggle("Повторяющаяся задача", isOn: $viewModel.isRecurring)
            
            if viewModel.isRecurring {
                Picker("Паттерн повторения", selection: $viewModel.recurringPattern) {
                    ForEach(RecurringPattern.allCases, id: \.self) { pattern in
                        Text(pattern.displayName).tag(pattern)
                    }
                }
                .pickerStyle(.menu)
                
                if viewModel.recurringPattern == .custom {
                    Stepper(
                        "Каждые \(viewModel.customInterval) дн.",
                        value: $viewModel.customInterval,
                        in: 1...365
                    )
                }
            }
        }
    }
    
    private var dependenciesSection: some View {
        Section {
            ForEach(viewModel.dependencies, id: \.id) { dependency in
                HStack {
                    VStack(alignment: .leading) {
                        Text(dependency.title)
                            .font(.body)
                        if !dependency.taskDescription.isEmpty {
                            Text(dependency.taskDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.removeDependency(dependency)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button {
                viewModel.showDependencyPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Добавить зависимость")
                }
            }
        } header: {
            Text("Зависимости (\(viewModel.dependencies.count))")
        } footer: {
            Text("Эта задача будет доступна только после выполнения зависимых задач")
        }
        .sheet(isPresented: $viewModel.showDependencyPicker) {
            DependencyPickerView(
                selectedDependencies: $viewModel.dependencies,
                taskService: taskService,
                excludeTask: taskToEdit
            )
        }
    }
    
    private var advancedSection: some View {
        Section("Дополнительно") {
            Toggle("Отправить уведомление", isOn: $viewModel.shouldNotify)
            
            if viewModel.shouldNotify && viewModel.hasDueDate {
                Picker("За сколько уведомить", selection: $viewModel.notificationOffset) {
                    Text("В срок").tag(0)
                    Text("За 5 минут").tag(5)
                    Text("За 15 минут").tag(15)
                    Text("За 30 минут").tag(30)
                    Text("За 1 час").tag(60)
                    Text("За 1 день").tag(1440)
                }
                .pickerStyle(.menu)
            }
            
            Toggle("Добавить к избранным", isOn: $viewModel.isFavorite)
        }
    }
    
    // MARK: - Supporting Views
    
    private var parsedComponentsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Распознано:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 8)
            ], spacing: 4) {
                ForEach(viewModel.parsedComponents, id: \.type) { component in
                    HStack(spacing: 4) {
                        Image(systemName: component.icon)
                            .font(.caption2)
                        Text(component.value)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                    .onTapGesture {
                        viewModel.applyParsedComponent(component)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
    
    private var dateSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Предложения:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.dateSuggestions, id: \.text) { suggestion in
                        Button(suggestion.text) {
                            viewModel.applyDateSuggestion(suggestion)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helper Properties
    
    private var isEditMode: Bool {
        taskToEdit != nil
    }
    
    // MARK: - Actions
    
    private func saveTask() async {
        let success = await viewModel.saveTask()
        if success {
            dismiss()
        }
    }
}

// MARK: - Supporting Views

struct DependencyPickerView: View {
    @Binding var selectedDependencies: [Task]
    let taskService: TaskService
    let excludeTask: Task?
    
    @Environment(\.dismiss) private var dismiss
    @State private var availableTasks: [Task] = []
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTasks) { task in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(task.title)
                                .font(.body)
                            if !task.taskDescription.isEmpty {
                                Text(task.taskDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedDependencies.contains(where: { $0.id == task.id }) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleDependency(task)
                    }
                }
            }
            .navigationTitle("Выберите зависимости")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Поиск задач...")
            .onAppear {
                loadAvailableTasks()
            }
        }
    }
    
    private var filteredTasks: [Task] {
        let tasks = availableTasks.filter { task in
            // Exclude the task being edited and completed tasks
            if let excludeTask = excludeTask, task.id == excludeTask.id { return false }
            if task.isCompleted { return false }
            
            if searchText.isEmpty {
                return true
            } else {
                return task.title.localizedCaseInsensitiveContains(searchText) ||
                       task.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return tasks.sorted { $0.title < $1.title }
    }
    
    private func toggleDependency(_ task: Task) {
        if selectedDependencies.contains(where: { $0.id == task.id }) {
            selectedDependencies.removeAll { $0.id == task.id }
        } else {
            selectedDependencies.append(task)
        }
    }
    
    private func loadAvailableTasks() {
        Task {
            availableTasks = await taskService.getAllTasks()
        }
    }
}

// MARK: - Preview

#Preview("Create Task") {
    CreateTaskView(taskService: MockTaskService())
        .modelContainer(for: Task.self, inMemory: true)
}

#Preview("Edit Task") {
    CreateTaskView(
        taskService: MockTaskService(),
        taskToEdit: Task.preview()
    )
    .modelContainer(for: Task.self, inMemory: true)
} 