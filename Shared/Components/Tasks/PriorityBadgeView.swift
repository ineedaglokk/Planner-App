import SwiftUI

// MARK: - PriorityBadgeView

struct PriorityBadgeView: View {
    let priority: Priority
    let style: Style
    
    enum Style {
        case compact
        case full
        case icon
    }
    
    init(_ priority: Priority, style: Style = .compact) {
        self.priority = priority
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .compact:
            compactView
        case .full:
            fullView
        case .icon:
            iconView
        }
    }
    
    // MARK: - Style Variants
    
    @ViewBuilder
    private var compactView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
            
            Text(priority.shortDisplayName)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(priority.textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(priority.backgroundColor)
                .stroke(priority.borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var fullView: some View {
        HStack(spacing: 6) {
            Image(systemName: priority.icon)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(priority.iconColor)
            
            Text(priority.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(priority.textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(priority.backgroundColor)
                .stroke(priority.borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var iconView: some View {
        Image(systemName: priority.icon)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(priority.iconColor)
            .frame(width: 20, height: 20)
            .background(
                Circle()
                    .fill(priority.backgroundColor)
                    .stroke(priority.borderColor, lineWidth: 1)
            )
    }
}

// MARK: - Priority Extensions

extension Priority {
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        case .urgent:
            return .purple
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .low:
            return .green.opacity(0.1)
        case .medium:
            return .orange.opacity(0.1)
        case .high:
            return .red.opacity(0.1)
        case .urgent:
            return .purple.opacity(0.1)
        }
    }
    
    var borderColor: Color {
        color.opacity(0.3)
    }
    
    var textColor: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        case .urgent:
            return .purple
        }
    }
    
    var iconColor: Color {
        textColor
    }
    
    var icon: String {
        switch self {
        case .low:
            return "arrow.down.circle.fill"
        case .medium:
            return "minus.circle.fill"
        case .high:
            return "arrow.up.circle.fill"
        case .urgent:
            return "exclamationmark.circle.fill"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .low:
            return "Низ"
        case .medium:
            return "Сред"
        case .high:
            return "Выс"
        case .urgent:
            return "Срч"
        }
    }
}

// MARK: - Priority Picker

struct PriorityPicker: View {
    @Binding var selectedPriority: Priority
    let style: PriorityPickerStyle
    
    enum PriorityPickerStyle {
        case horizontal
        case vertical
        case menu
    }
    
    init(_ priority: Binding<Priority>, style: PriorityPickerStyle = .horizontal) {
        self._selectedPriority = priority
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .horizontal:
            horizontalPicker
        case .vertical:
            verticalPicker
        case .menu:
            menuPicker
        }
    }
    
    @ViewBuilder
    private var horizontalPicker: some View {
        HStack(spacing: 8) {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    selectedPriority = priority
                } label: {
                    PriorityBadgeView(priority, style: .compact)
                        .scaleEffect(selectedPriority == priority ? 1.0 : 0.9)
                        .opacity(selectedPriority == priority ? 1.0 : 0.6)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPriority)
    }
    
    @ViewBuilder
    private var verticalPicker: some View {
        VStack(spacing: 8) {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    selectedPriority = priority
                } label: {
                    HStack {
                        PriorityBadgeView(priority, style: .full)
                        
                        Spacer()
                        
                        if selectedPriority == priority {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedPriority == priority ? Color.blue.opacity(0.1) : Color.clear)
                            .stroke(selectedPriority == priority ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedPriority)
    }
    
    @ViewBuilder
    private var menuPicker: some View {
        Menu {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    selectedPriority = priority
                } label: {
                    HStack {
                        Image(systemName: priority.icon)
                        Text(priority.displayName)
                        
                        if selectedPriority == priority {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                PriorityBadgeView(selectedPriority, style: .compact)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray6))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
struct PriorityBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Compact style
            HStack {
                ForEach(Priority.allCases, id: \.self) { priority in
                    PriorityBadgeView(priority, style: .compact)
                }
            }
            
            // Full style
            HStack {
                ForEach(Priority.allCases, id: \.self) { priority in
                    PriorityBadgeView(priority, style: .full)
                }
            }
            
            // Icon style
            HStack {
                ForEach(Priority.allCases, id: \.self) { priority in
                    PriorityBadgeView(priority, style: .icon)
                }
            }
            
            Divider()
            
            // Priority Picker
            VStack(spacing: 16) {
                Text("Horizontal Picker")
                    .font(.headline)
                
                PriorityPicker(.constant(.medium), style: .horizontal)
                
                Text("Vertical Picker")
                    .font(.headline)
                
                PriorityPicker(.constant(.high), style: .vertical)
                
                Text("Menu Picker")
                    .font(.headline)
                
                PriorityPicker(.constant(.urgent), style: .menu)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif 