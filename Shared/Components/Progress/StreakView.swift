import SwiftUI

// MARK: - StreakView

struct StreakView: View {
    let currentStreak: Int
    let longestStreak: Int
    let style: StreakStyle
    let color: Color
    
    enum StreakStyle {
        case compact
        case detailed
        case flame
        case minimal
    }
    
    init(
        currentStreak: Int,
        longestStreak: Int = 0,
        style: StreakStyle = .compact,
        color: Color = .orange
    ) {
        self.currentStreak = max(currentStreak, 0)
        self.longestStreak = max(longestStreak, 0)
        self.style = style
        self.color = color
    }
    
    var body: some View {
        switch style {
        case .compact:
            compactStreakView
        case .detailed:
            detailedStreakView
        case .flame:
            flameStreakView
        case .minimal:
            minimalStreakView
        }
    }
    
    // MARK: - Compact Style
    
    private var compactStreakView: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streakColor)
                .font(.caption)
            
            Text("\(currentStreak)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(streakColor.opacity(0.1))
        }
    }
    
    // MARK: - Detailed Style
    
    private var detailedStreakView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streakColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(currentStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("дней подряд")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if longestStreak > 0 && longestStreak != currentStreak {
                Text("Лучший: \(longestStreak)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Flame Style
    
    private var flameStreakView: some View {
        ZStack {
            // Flame animation background
            if currentStreak > 0 {
                flameAnimation
            }
            
            VStack(spacing: 2) {
                Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.title)
                    .foregroundStyle(streakColor)
                    .scaleEffect(currentStreak > 0 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentStreak)
                
                Text("\(currentStreak)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 60, height: 80)
    }
    
    // MARK: - Minimal Style
    
    private var minimalStreakView: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streakColor)
                .font(.system(size: 12))
            
            Text("\(currentStreak)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Supporting Views
    
    private var flameAnimation: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                streakColor.opacity(0.3),
                                streakColor.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 30, height: 30)
                    .scaleEffect(pulseScale(for: index))
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.3),
                        value: currentStreak
                    )
            }
        }
    }
    
    private func pulseScale(for index: Int) -> CGFloat {
        return currentStreak > 0 ? (1.0 + Double(index) * 0.2) : 0.5
    }
    
    private var streakColor: Color {
        if currentStreak == 0 {
            return .gray
        } else if currentStreak >= 30 {
            return .purple
        } else if currentStreak >= 14 {
            return .blue
        } else if currentStreak >= 7 {
            return .green
        } else {
            return color
        }
    }
}

// MARK: - HabitStreakView

struct HabitStreakView: View {
    let habit: Habit
    let style: StreakView.StreakStyle
    
    init(habit: Habit, style: StreakView.StreakStyle = .compact) {
        self.habit = habit
        self.style = style
    }
    
    var body: some View {
        StreakView(
            currentStreak: habit.currentStreak,
            longestStreak: habit.longestStreak,
            style: style,
            color: Color(hex: habit.color) ?? .orange
        )
    }
}

// MARK: - StreakBadgeView

struct StreakBadgeView: View {
    let streak: Int
    let isPersonalRecord: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(badgeColor)
                .font(.caption2)
            
            Text("\(streak)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            if isPersonalRecord {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 8))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            Capsule()
                .fill(badgeColor)
        }
    }
    
    private var badgeColor: Color {
        if streak >= 30 {
            return .purple
        } else if streak >= 14 {
            return .blue
        } else if streak >= 7 {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - StreakProgressView

struct StreakProgressView: View {
    let currentStreak: Int
    let targetStreak: Int
    let color: Color
    
    init(
        currentStreak: Int,
        targetStreak: Int = 30,
        color: Color = .orange
    ) {
        self.currentStreak = max(currentStreak, 0)
        self.targetStreak = max(targetStreak, 1)
        self.color = color
    }
    
    private var progress: Double {
        min(Double(currentStreak) / Double(targetStreak), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(color)
                        .font(.caption)
                    
                    Text("Streak")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(currentStreak) / \(targetStreak)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .scaleEffect(y: 0.8)
            
            if currentStreak >= targetStreak {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption2)
                    
                    Text("Цель достигнута!")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        }
    }
}

// MARK: - StreakMilestoneView

struct StreakMilestoneView: View {
    let streak: Int
    
    private var milestone: (title: String, icon: String, color: Color) {
        if streak >= 365 {
            return ("Год силы!", "crown.fill", .purple)
        } else if streak >= 100 {
            return ("Сотня!", "star.fill", .blue)
        } else if streak >= 30 {
            return ("Месяц!", "flame.fill", .orange)
        } else if streak >= 7 {
            return ("Неделя!", "checkmark.circle.fill", .green)
        } else {
            return ("Начало пути", "play.circle.fill", .gray)
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: milestone.icon)
                .font(.title2)
                .foregroundStyle(milestone.color)
            
            Text(milestone.title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(milestone.color)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(milestone.color.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(milestone.color.opacity(0.3), lineWidth: 1)
                }
        }
    }
}

// MARK: - Preview

#Preview("Streak Styles") {
    VStack(spacing: 20) {
        StreakView(currentStreak: 5, style: .compact)
        StreakView(currentStreak: 12, longestStreak: 25, style: .detailed)
        StreakView(currentStreak: 8, style: .flame)
        StreakView(currentStreak: 3, style: .minimal)
    }
    .padding()
}

#Preview("Habit Streak") {
    let sampleHabit = Habit(
        name: "Медитация",
        description: "Ежедневная медитация",
        icon: "leaf.fill",
        color: "#34C759"
    )
    
    VStack(spacing: 20) {
        HabitStreakView(habit: sampleHabit, style: .detailed)
        HabitStreakView(habit: sampleHabit, style: .flame)
        
        StreakBadgeView(streak: 15, isPersonalRecord: true)
        StreakBadgeView(streak: 7, isPersonalRecord: false)
    }
    .padding()
}

#Preview("Streak Progress") {
    VStack(spacing: 16) {
        StreakProgressView(currentStreak: 8, targetStreak: 30)
        StreakProgressView(currentStreak: 30, targetStreak: 30, color: .green)
        
        StreakMilestoneView(streak: 15)
        StreakMilestoneView(streak: 100)
    }
    .padding()
} 