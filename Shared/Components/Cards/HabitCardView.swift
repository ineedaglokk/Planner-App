import SwiftUI

// MARK: - HabitCardView

struct HabitCardView: View {
    let habit: Habit
    let style: CardStyle
    let onToggle: () -> Void
    let onTap: (() -> Void)?
    
    @State private var isPressed = false
    @State private var showCheckmark = false
    
    enum CardStyle {
        case compact
        case expanded
        case minimal
        case detailed
    }
    
    init(
        habit: Habit,
        style: CardStyle = .compact,
        onToggle: @escaping () -> Void,
        onTap: (() -> Void)? = nil
    ) {
        self.habit = habit
        self.style = style
        self.onToggle = onToggle
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap ?? {}) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }
    
    @ViewBuilder
    private var cardContent: some View {
        switch style {
        case .compact:
            compactCard
        case .expanded:
            expandedCard
        case .minimal:
            minimalCard
        case .detailed:
            detailedCard
        }
    }
    
    // MARK: - Compact Style
    
    private var compactCard: some View {
        HStack(spacing: 12) {
            // Habit icon and progress
            ZStack {
                Circle()
                    .fill(habitColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                HabitProgressRingView(
                    habit: habit,
                    size: 50,
                    showDetails: false
                )
            }
            
            // Habit info
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let description = habit.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    HabitStreakView(habit: habit, style: .minimal)
                    
                    if habit.targetValue > 1 {
                        progressText
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Toggle button
            toggleButton
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Expanded Style
    
    private var expandedCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    if let description = habit.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                HabitProgressRingView(
                    habit: habit,
                    size: 60,
                    showDetails: true
                )
            }
            
            HStack {
                HabitStreakView(habit: habit, style: .compact)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if habit.targetValue > 1 {
                        progressText
                    }
                    
                    toggleButton
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Minimal Style
    
    private var minimalCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(habitColor)
                .frame(width: 8, height: 8)
            
            Text(habit.name)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            HabitStreakView(habit: habit, style: .minimal)
            
            toggleButton
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        }
    }
    
    // MARK: - Detailed Style
    
    private var detailedCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: habit.icon)
                        .font(.title2)
                        .foregroundStyle(habitColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if let description = habit.description, !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                toggleButton
            }
            
            // Progress and stats
            HStack(spacing: 16) {
                HabitProgressRingView(
                    habit: habit,
                    size: 80,
                    showDetails: true
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HabitStreakView(habit: habit, style: .detailed)
                    
                    if habit.targetValue > 1 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Сегодня")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            progressText
                        }
                    }
                }
                
                Spacer()
            }
            
            // Completion rate
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Выполнение за месяц")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(habit.completionRate * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(habitColor)
                }
                
                ProgressView(value: habit.completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: habitColor))
                    .scaleEffect(y: 0.6)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Supporting Views
    
    private var toggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                onToggle()
                showCheckmark = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCheckmark = false
            }
        }) {
            ZStack {
                Circle()
                    .fill(isCompleted ? habitColor : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                
                if showCheckmark {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: isCompleted ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isCompleted ? .white : .gray)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
    }
    
    private var progressText: some View {
        let todayEntry = habit.getTodayEntry()
        let currentValue = todayEntry?.value ?? 0
        
        return HStack(spacing: 2) {
            Text("\(currentValue)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(habitColor)
            
            Text("/ \(habit.targetValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let unit = habit.unit {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var isCompleted: Bool {
        habit.isCompletedToday
    }
    
    private var habitColor: Color {
        Color(hex: habit.color) ?? .blue
    }
}

// MARK: - HabitListCardView

struct HabitListCardView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var showingActionSheet = false
    
    var body: some View {
        HabitCardView(
            habit: habit,
            style: .compact,
            onToggle: onToggle,
            onTap: {
                // Navigation to detail view will be handled by parent
            }
        )
        .contextMenu {
            Button("Редактировать", systemImage: "pencil") {
                onEdit?()
            }
            
            if habit.isActive {
                Button("Архивировать", systemImage: "archivebox") {
                    // Archive action
                }
            } else {
                Button("Восстановить", systemImage: "arrow.up.bin") {
                    // Unarchive action
                }
            }
            
            Divider()
            
            Button("Удалить", systemImage: "trash", role: .destructive) {
                onDelete?()
            }
        }
    }
}

// MARK: - HabitGridCardView

struct HabitGridCardView: View {
    let habit: Habit
    let onToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HabitProgressRingView(
                    habit: habit,
                    size: 60,
                    showDetails: false
                )
                
                VStack(spacing: 4) {
                    Text(habit.name)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    HabitStreakView(habit: habit, style: .minimal)
                }
                
                Button(action: onToggle) {
                    Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(habit.isCompletedToday ? Color(hex: habit.color) ?? .blue : .gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview("Habit Card Styles") {
    let sampleHabit = Habit(
        name: "Вода",
        description: "Пить 8 стаканов воды в день",
        icon: "drop.fill",
        color: "#007AFF",
        targetValue: 8,
        unit: "стаканы"
    )
    
    ScrollView {
        VStack(spacing: 16) {
            HabitCardView(habit: sampleHabit, style: .compact, onToggle: {})
            HabitCardView(habit: sampleHabit, style: .expanded, onToggle: {})
            HabitCardView(habit: sampleHabit, style: .minimal, onToggle: {})
            HabitCardView(habit: sampleHabit, style: .detailed, onToggle: {})
        }
        .padding()
    }
}

#Preview("Habit Grid") {
    let sampleHabits = [
        Habit(name: "Вода", icon: "drop.fill", color: "#007AFF"),
        Habit(name: "Спорт", icon: "figure.run", color: "#FF3B30"),
        Habit(name: "Чтение", icon: "book.fill", color: "#34C759"),
        Habit(name: "Медитация", icon: "leaf.fill", color: "#FF9500")
    ]
    
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
        ForEach(sampleHabits, id: \.id) { habit in
            HabitGridCardView(
                habit: habit,
                onToggle: {},
                onTap: {}
            )
        }
    }
    .padding()
} 