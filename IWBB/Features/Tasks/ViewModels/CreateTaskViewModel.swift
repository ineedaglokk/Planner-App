import Foundation
import SwiftUI

// MARK: - CreateTaskViewModel

@Observable
final class CreateTaskViewModel {
    
    // MARK: - State
    
    struct State {
        var title: String = ""
        var description: String = ""
        var dueDateText: String = ""
        var priority: Priority = .medium
        var category: Category?
        var tags: [String] = []
        var currentTag: String = ""
        var estimatedDuration: TimeInterval?
        var location: String = ""
        var url: String = ""
        
        // Recurring settings
        var isRecurring: Bool = false
        var recurringPattern: RecurringPattern?
        
        // Reminder settings
        var hasReminder: Bool = false
        var reminderDate: Date?
        
        // Subtasks
        var subtasks: [SubtaskItem] = []
        var currentSubtask: String = ""
        
        // Dependencies
        var prerequisites: [Task] = []
        
        // UI states
        var isLoading: Bool = false
        var error: AppError?
        var showDatePicker: Bool = false
        var showCategoryPicker: Bool = false
        var showRecurringSettings: Bool = false
        var showDurationPicker: Bool = false
        var showPrerequisitesPicker: Bool = false
        
        // Date suggestions
        var dateSuggestions: [DateSuggestion] = []
        var showDateSuggestions: Bool = false
        
        // Validation
        var titleError: String?
        var dueDateError: String?
        
        // Computed
        var dueDate: Date?
        var isValid: Bool = false
    }
    
    // MARK: - Input
    
    enum Input {
        case titleChanged(String)
        case descriptionChanged(String)
        case dueDateTextChanged(String)
        case priorityChanged(Priority)
        case categoryChanged(Category?)
        case tagAdded(String)
        case tagRemoved(String)
        case currentTagChanged(String)
        case addCurrentTag
        case estimatedDurationChanged(TimeInterval?)
        case locationChanged(String)
        case urlChanged(String)
        case isRecurringToggled
        case recurringPatternChanged(RecurringPattern?)
        case hasReminderToggled
        case reminderDateChanged(Date?)
        case subtaskAdded(String)
        case subtaskRemoved(UUID)
        case subtaskToggled(UUID)
        case currentSubtaskChanged(String)
        case addCurrentSubtask
        case prerequisiteAdded(Task)
        case prerequisiteRemoved(Task)
        case toggleDatePicker
        case toggleCategoryPicker
        case toggleRecurringSettings
        case toggleDurationPicker
        case togglePrerequisitesPicker
        case dateSuggestionSelected(DateSuggestion)
        case save
        case reset
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let taskService: TaskServiceProtocol
    private let dateParser = DateParser()
    
    // Mode
    private let mode: Mode
    private let editingTask: Task?
    
    enum Mode {
        case create
        case edit(Task)
    }
    
    // MARK: - Initialization
    
    init(taskService: TaskServiceProtocol, editingTask: Task? = nil) {
        self.taskService = taskService
        self.editingTask = editingTask
        self.mode = editingTask != nil ? .edit(editingTask!) : .create
        
        if let task = editingTask {
            loadTaskForEditing(task)
        }
        
        updateValidation()
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .titleChanged(let title):
                state.title = title
                updateValidation()
                
            case .descriptionChanged(let description):
                state.description = description
                
            case .dueDateTextChanged(let text):
                state.dueDateText = text
                await handleDateTextChange(text)
                
            case .priorityChanged(let priority):
                state.priority = priority
                
            case .categoryChanged(let category):
                state.category = category
                
            case .tagAdded(let tag):
                addTag(tag)
                
            case .tagRemoved(let tag):
                removeTag(tag)
                
            case .currentTagChanged(let tag):
                state.currentTag = tag
                
            case .addCurrentTag:
                addCurrentTag()
                
            case .estimatedDurationChanged(let duration):
                state.estimatedDuration = duration
                
            case .locationChanged(let location):
                state.location = location
                
            case .urlChanged(let url):
                state.url = url
                
            case .isRecurringToggled:
                state.isRecurring.toggle()
                if !state.isRecurring {
                    state.recurringPattern = nil
                }
                
            case .recurringPatternChanged(let pattern):
                state.recurringPattern = pattern
                
            case .hasReminderToggled:
                state.hasReminder.toggle()
                if !state.hasReminder {
                    state.reminderDate = nil
                }
                
            case .reminderDateChanged(let date):
                state.reminderDate = date
                
            case .subtaskAdded(let title):
                addSubtask(title)
                
            case .subtaskRemoved(let id):
                removeSubtask(id)
                
            case .subtaskToggled(let id):
                toggleSubtask(id)
                
            case .currentSubtaskChanged(let text):
                state.currentSubtask = text
                
            case .addCurrentSubtask:
                addCurrentSubtask()
                
            case .prerequisiteAdded(let task):
                addPrerequisite(task)
                
            case .prerequisiteRemoved(let task):
                removePrerequisite(task)
                
            case .toggleDatePicker:
                state.showDatePicker.toggle()
                
            case .toggleCategoryPicker:
                state.showCategoryPicker.toggle()
                
            case .toggleRecurringSettings:
                state.showRecurringSettings.toggle()
                
            case .toggleDurationPicker:
                state.showDurationPicker.toggle()
                
            case .togglePrerequisitesPicker:
                state.showPrerequisitesPicker.toggle()
                
            case .dateSuggestionSelected(let suggestion):
                selectDateSuggestion(suggestion)
                
            case .save:
                await saveTask()
                
            case .reset:
                resetForm()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTaskForEditing(_ task: Task) {
        state.title = task.title
        state.description = task.description ?? ""
        state.priority = task.priority
        state.category = task.category
        state.tags = task.tags
        state.estimatedDuration = task.estimatedDuration
        state.location = task.location ?? ""
        state.url = task.url ?? ""
        state.isRecurring = task.isRecurring
        state.recurringPattern = task.recurringPattern
        state.hasReminder = task.reminderDate != nil
        state.reminderDate = task.reminderDate
        
        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "ru_RU")
            state.dueDateText = formatter.string(from: dueDate)
            state.dueDate = dueDate
        }
        
        // Load subtasks
        state.subtasks = task.subtasks.map { subtask in
            SubtaskItem(
                id: subtask.id,
                title: subtask.title,
                isCompleted: subtask.status == .completed
            )
        }
        
        state.prerequisites = task.prerequisiteTasks
    }
    
    private func handleDateTextChange(_ text: String) async {
        // Parse the date
        let parsedDate = dateParser.parseDate(from: text)
        state.dueDate = parsedDate
        
        // Get suggestions
        let suggestions = dateParser.getSuggestions(for: text)
        state.dateSuggestions = suggestions
        state.showDateSuggestions = !text.isEmpty && !suggestions.isEmpty
        
        // Validate
        if !text.isEmpty && parsedDate == nil {
            state.dueDateError = "Не удалось распознать дату"
        } else {
            state.dueDateError = nil
        }
        
        updateValidation()
    }
    
    private func selectDateSuggestion(_ suggestion: DateSuggestion) {
        state.dueDateText = suggestion.text
        state.dueDate = suggestion.date
        state.showDateSuggestions = false
        state.dueDateError = nil
        updateValidation()
    }
    
    private func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty && !state.tags.contains(cleanTag) {
            state.tags.append(cleanTag)
        }
    }
    
    private func removeTag(_ tag: String) {
        state.tags.removeAll { $0 == tag }
    }
    
    private func addCurrentTag() {
        let cleanTag = state.currentTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty && !state.tags.contains(cleanTag) {
            state.tags.append(cleanTag)
            state.currentTag = ""
        }
    }
    
    private func addSubtask(_ title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            let subtask = SubtaskItem(title: cleanTitle)
            state.subtasks.append(subtask)
        }
    }
    
    private func removeSubtask(_ id: UUID) {
        state.subtasks.removeAll { $0.id == id }
    }
    
    private func toggleSubtask(_ id: UUID) {
        if let index = state.subtasks.firstIndex(where: { $0.id == id }) {
            state.subtasks[index].isCompleted.toggle()
        }
    }
    
    private func addCurrentSubtask() {
        let cleanTitle = state.currentSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty {
            let subtask = SubtaskItem(title: cleanTitle)
            state.subtasks.append(subtask)
            state.currentSubtask = ""
        }
    }
    
    private func addPrerequisite(_ task: Task) {
        if !state.prerequisites.contains(where: { $0.id == task.id }) {
            state.prerequisites.append(task)
        }
    }
    
    private func removePrerequisite(_ task: Task) {
        state.prerequisites.removeAll { $0.id == task.id }
    }
    
    private func updateValidation() {
        // Title validation
        if state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.titleError = "Название не может быть пустым"
            state.isValid = false
        } else {
            state.titleError = nil
            state.isValid = state.dueDateError == nil
        }
    }
    
    private func saveTask() async {
        guard state.isValid else { return }
        
        state.isLoading = true
        state.error = nil
        
        do {
            let task: Task
            
            switch mode {
            case .create:
                task = Task(
                    title: state.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: state.description.isEmpty ? nil : state.description,
                    priority: state.priority,
                    dueDate: state.dueDate,
                    category: state.category
                )
                
            case .edit(let existingTask):
                task = existingTask
                task.title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
                task.description = state.description.isEmpty ? nil : state.description
                task.priority = state.priority
                task.dueDate = state.dueDate
                task.category = state.category
            }
            
            // Set additional properties
            task.tags = state.tags
            task.estimatedDuration = state.estimatedDuration
            task.location = state.location.isEmpty ? nil : state.location
            task.url = state.url.isEmpty ? nil : state.url
            task.isRecurring = state.isRecurring
            task.recurringPattern = state.recurringPattern
            task.reminderDate = state.hasReminder ? state.reminderDate : nil
            
            switch mode {
            case .create:
                try await taskService.createTask(task)
                
                // Create subtasks
                for subtaskItem in state.subtasks {
                    let subtask = Task(
                        title: subtaskItem.title,
                        priority: state.priority,
                        category: state.category
                    )
                    if subtaskItem.isCompleted {
                        subtask.status = .completed
                    }
                    try await taskService.addSubtask(subtask, to: task)
                }
                
                // Add prerequisites
                for prerequisite in state.prerequisites {
                    try await taskService.addTaskDependency(task, dependsOn: prerequisite)
                }
                
            case .edit:
                try await taskService.updateTask(task)
                
                // Update subtasks (simplified - in real app you'd need more sophisticated merging)
                // For now, we'll leave subtask management to the detail view
            }
            
            // Reset form after successful save
            resetForm()
            
        } catch {
            state.error = AppError.from(error)
        }
        
        state.isLoading = false
    }
    
    private func resetForm() {
        state = State()
        updateValidation()
    }
    
    // MARK: - Helper Methods
    
    func getDurationText() -> String? {
        guard let duration = state.estimatedDuration else { return nil }
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)ч \(minutes)м"
        } else {
            return "\(minutes)м"
        }
    }
    
    func getPrerequisiteNames() -> String {
        if state.prerequisites.isEmpty {
            return "Не выбраны"
        }
        return state.prerequisites.map { $0.title }.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

struct SubtaskItem: Identifiable {
    let id: UUID = UUID()
    let title: String
    var isCompleted: Bool = false
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
    }
    
    init(id: UUID, title: String, isCompleted: Bool) {
        self.title = title
        self.isCompleted = isCompleted
    }
} 