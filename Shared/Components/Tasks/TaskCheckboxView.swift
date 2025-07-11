import SwiftUI

// MARK: - TaskCheckboxView

struct TaskCheckboxView: View {
    let isCompleted: Bool
    let priority: Priority
    let style: Style
    let action: () -> Void
    
    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0
    
    enum Style {
        case standard
        case large
        case minimal
        case priority
    }
    
    init(
        isCompleted: Bool,
        priority: Priority = .medium,
        style: Style = .standard,
        action: @escaping () -> Void
    ) {
        self.isCompleted = isCompleted
        self.priority = priority
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
            switch style {
            case .standard:
                standardCheckbox
            case .large:
                largeCheckbox
            case .minimal:
                minimalCheckbox
            case .priority:
                priorityCheckbox
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scale)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCompleted)
    }
    
    // MARK: - Style Variants
    
    @ViewBuilder
    private var standardCheckbox: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isCompleted ? checkboxColor : Color.clear)
                .stroke(checkboxColor, lineWidth: 2)
                .frame(width: 22, height: 22)
            
            // Checkmark
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.8 : 1.0)
            }
        }
    }
    
    @ViewBuilder
    private var largeCheckbox: some View {
        ZStack {
            // Background circle with gradient
            Circle()
                .fill(
                    isCompleted 
                    ? LinearGradient(
                        colors: [checkboxColor, checkboxColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .stroke(checkboxColor, lineWidth: 3)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                        .opacity(isCompleted ? 1 : 0)
                )
            
            // Animated checkmark
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .opacity(isAnimating ? 0.7 : 1.0)
            }
        }
    }
    
    @ViewBuilder
    private var minimalCheckbox: some View {
        ZStack {
            // Simple circle
            Circle()
                .fill(isCompleted ? checkboxColor.opacity(0.2) : Color.clear)
                .stroke(checkboxColor.opacity(0.5), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            
            // Small checkmark
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(checkboxColor)
            }
        }
    }
    
    @ViewBuilder
    private var priorityCheckbox: some View {
        ZStack {
            // Priority-colored background
            RoundedRectangle(cornerRadius: 6)
                .fill(isCompleted ? priority.color : Color.clear)
                .stroke(priority.color, lineWidth: 2)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                        .opacity(isCompleted ? 1 : 0)
                )
            
            // Priority icon or checkmark
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Image(systemName: priority.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(priority.color.opacity(0.6))
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var checkboxColor: Color {
        switch priority {
        case .low:
            return .green
        case .medium:
            return .blue
        case .high:
            return .orange
        case .urgent:
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Scale animation
        withAnimation(.easeInOut(duration: 0.1)) {
            scale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                scale = 1.0
            }
        }
        
        // Completion animation
        if !isCompleted {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAnimating = false
                }
            }
        }
        
        // Call the action
        action()
    }
}

// MARK: - TaskStatusView

struct TaskStatusView: View {
    let status: TaskStatus
    let size: CGFloat
    
    init(_ status: TaskStatus, size: CGFloat = 20) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(status.backgroundColor)
                .stroke(status.borderColor, lineWidth: 2)
                .frame(width: size, height: size)
            
            Image(systemName: status.icon)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(status.iconColor)
        }
    }
}

// MARK: - TaskStatus Extensions

extension TaskStatus {
    var backgroundColor: Color {
        switch self {
        case .pending:
            return .gray.opacity(0.1)
        case .inProgress:
            return .blue.opacity(0.2)
        case .completed:
            return .green.opacity(0.2)
        case .cancelled:
            return .red.opacity(0.1)
        case .onHold:
            return .orange.opacity(0.1)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .pending:
            return .gray.opacity(0.5)
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red.opacity(0.7)
        case .onHold:
            return .orange
        }
    }
    
    var iconColor: Color {
        switch self {
        case .pending:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red
        case .onHold:
            return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "circle"
        case .inProgress:
            return "play.fill"
        case .completed:
            return "checkmark"
        case .cancelled:
            return "xmark"
        case .onHold:
            return "pause.fill"
        }
    }
}

// MARK: - Bulk Selection Checkbox

struct BulkSelectionCheckbox: View {
    let isSelected: Bool
    let isIndeterminate: Bool
    let action: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    init(
        isSelected: Bool,
        isIndeterminate: Bool = false,
        action: @escaping () -> Void
    ) {
        self.isSelected = isSelected
        self.isIndeterminate = isIndeterminate
        self.action = action
    }
    
    var body: some View {
        Button(action: handleTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected || isIndeterminate ? .blue : Color.clear)
                    .stroke(.blue, lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                if isIndeterminate {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 8, height: 2)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scale)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isIndeterminate)
    }
    
    private func handleTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.1)) {
            scale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                scale = 1.0
            }
        }
        
        action()
    }
}

// MARK: - Subtask Checkbox

struct SubtaskCheckbox: View {
    let isCompleted: Bool
    let depth: Int
    let action: () -> Void
    
    init(
        isCompleted: Bool,
        depth: Int = 0,
        action: @escaping () -> Void
    ) {
        self.isCompleted = isCompleted
        self.depth = depth
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Indentation for nested subtasks
                ForEach(0..<depth, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20)
                }
                
                // Connector line for nested tasks
                if depth > 0 {
                    VStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 1, height: 8)
                        
                        Spacer()
                    }
                    .frame(width: 12)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 1)
                }
                
                // Checkbox
                ZStack {
                    Circle()
                        .fill(isCompleted ? .blue : Color.clear)
                        .stroke(.blue.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
struct TaskCheckboxView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Standard checkboxes
            HStack(spacing: 20) {
                TaskCheckboxView(isCompleted: false, priority: .medium, style: .standard) { }
                TaskCheckboxView(isCompleted: true, priority: .medium, style: .standard) { }
            }
            
            // Large checkboxes
            HStack(spacing: 20) {
                TaskCheckboxView(isCompleted: false, priority: .high, style: .large) { }
                TaskCheckboxView(isCompleted: true, priority: .high, style: .large) { }
            }
            
            // Priority checkboxes
            HStack(spacing: 20) {
                ForEach(Priority.allCases, id: \.self) { priority in
                    VStack(spacing: 8) {
                        TaskCheckboxView(isCompleted: false, priority: priority, style: .priority) { }
                        TaskCheckboxView(isCompleted: true, priority: priority, style: .priority) { }
                    }
                }
            }
            
            // Task status indicators
            HStack(spacing: 20) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    VStack(spacing: 4) {
                        TaskStatusView(status)
                        Text(status.displayName)
                            .font(.caption2)
                    }
                }
            }
            
            // Bulk selection
            HStack(spacing: 20) {
                BulkSelectionCheckbox(isSelected: false) { }
                BulkSelectionCheckbox(isSelected: true) { }
                BulkSelectionCheckbox(isSelected: false, isIndeterminate: true) { }
            }
            
            // Subtask checkboxes
            VStack(alignment: .leading, spacing: 8) {
                SubtaskCheckbox(isCompleted: false, depth: 0) { }
                SubtaskCheckbox(isCompleted: true, depth: 1) { }
                SubtaskCheckbox(isCompleted: false, depth: 2) { }
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif 