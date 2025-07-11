import SwiftUI

struct TaskRowView: View {
    let task: Task
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            TaskCheckboxView(
                isChecked: task.isCompleted,
                style: .standard,
                onToggle: onToggleComplete
            )
            
            // Task content
            VStack(alignment: .leading, spacing: 4) {
                // Title and tags
                HStack {
                    Text(task.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    // Priority indicator
                    PriorityBadgeView(
                        priority: task.priority,
                        style: .compact
                    )
                }
                
                // Description (if exists)
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Bottom row with metadata
                HStack(spacing: 8) {
                    // Due date
                    if let dueDate = task.dueDate {
                        DueDateView(
                            dueDate: dueDate,
                            isCompleted: task.isCompleted,
                            style: .compact
                        )
                    }
                    
                    // Category
                    if let category = task.category {
                        CategoryTagView(
                            category: category,
                            style: .compact
                        )
                    }
                    
                    // Subtasks indicator
                    if !task.subtasks.isEmpty {
                        subtasksIndicator
                    }
                    
                    // Recurring indicator
                    if task.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    // Has dependencies indicator
                    if !task.dependencies.isEmpty {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    // Progress indicator
                    if !task.subtasks.isEmpty {
                        progressIndicator
                    }
                }
            }
            
            // Action button
            Button {
                onTap()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackgroundColor)
                .opacity(isPressed ? 0.7 : 1.0)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            perform: {},
            onPressingChanged: { pressing in
                isPressed = pressing
            }
        )
    }
    
    // MARK: - Supporting Views
    
    private var subtasksIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: "list.bullet")
                .font(.caption2)
            Text("\(task.completedSubtasksCount)/\(task.subtasks.count)")
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
    
    private var progressIndicator: some View {
        let progress = task.completionProgress
        let progressColor: Color = {
            switch progress {
            case 0.0..<0.3:
                return .red
            case 0.3..<0.7:
                return .orange
            case 0.7..<1.0:
                return .yellow
            default:
                return .green
            }
        }()
        
        return HStack(spacing: 4) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .frame(width: 30, height: 4)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var rowBackgroundColor: Color {
        if task.isCompleted {
            return Color(.systemGray6)
        } else if task.isOverdue {
            return Color.red.opacity(0.1)
        } else if task.isHighPriority {
            return Color.orange.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Task Extensions

extension Task {
    var isHighPriority: Bool {
        priority == .high || priority == .urgent
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    var completedSubtasksCount: Int {
        subtasks.filter(\.isCompleted).count
    }
    
    var completionProgress: Double {
        guard !subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        return Double(completedSubtasksCount) / Double(subtasks.count)
    }
}

// MARK: - Preview

#Preview("Regular Task") {
    VStack {
        TaskRowView(
            task: Task.preview(),
            onTap: {},
            onToggleComplete: {},
            onDelete: {}
        )
        
        TaskRowView(
            task: Task.previewCompleted(),
            onTap: {},
            onToggleComplete: {},
            onDelete: {}
        )
        
        TaskRowView(
            task: Task.previewOverdue(),
            onTap: {},
            onToggleComplete: {},
            onDelete: {}
        )
    }
    .padding()
}

// MARK: - Preview Data

extension Task {
    static func preview() -> Task {
        let task = Task(
            title: "Купить продукты на неделю",
            description: "Молоко, хлеб, овощи и фрукты",
            priority: .medium
        )
        task.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        task.category = "Покупки"
        return task
    }
    
    static func previewCompleted() -> Task {
        let task = Task(
            title: "Закончить отчет",
            description: "Квартальный отчет по продажам",
            priority: .high
        )
        task.isCompleted = true
        task.completedAt = Date()
        task.category = "Работа"
        return task
    }
    
    static func previewOverdue() -> Task {
        let task = Task(
            title: "Записаться к врачу",
            description: "Плановый осмотр",
            priority: .medium
        )
        task.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        task.category = "Здоровье"
        return task
    }
} 