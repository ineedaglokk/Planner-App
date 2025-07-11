import SwiftUI

// MARK: - ProgressRingView

struct ProgressRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let primaryColor: Color
    let backgroundColor: Color
    let showPercentage: Bool
    let animationDuration: Double
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        lineWidth: CGFloat = 8,
        size: CGFloat = 60,
        primaryColor: Color = .blue,
        backgroundColor: Color = Color(.systemGray5),
        showPercentage: Bool = true,
        animationDuration: Double = 1.0
    ) {
        self.progress = min(max(progress, 0), 1.0)
        self.lineWidth = lineWidth
        self.size = size
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor
        self.showPercentage = showPercentage
        self.animationDuration = animationDuration
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    primaryColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(
                    .easeInOut(duration: animationDuration),
                    value: animatedProgress
                )
            
            // Center content
            if showPercentage {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(primaryColor)
                    .animation(
                        .easeInOut(duration: animationDuration),
                        value: animatedProgress
                    )
            }
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.easeInOut(duration: animationDuration)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - HabitProgressRingView

struct HabitProgressRingView: View {
    let habit: Habit
    let size: CGFloat
    let showDetails: Bool
    
    init(
        habit: Habit,
        size: CGFloat = 60,
        showDetails: Bool = true
    ) {
        self.habit = habit
        self.size = size
        self.showDetails = showDetails
    }
    
    private var progress: Double {
        habit.todayProgress
    }
    
    private var ringColor: Color {
        Color(hex: habit.color) ?? .blue
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ProgressRingView(
                progress: progress,
                lineWidth: size / 7.5,
                size: size,
                primaryColor: ringColor,
                showPercentage: false
            )
            .overlay {
                VStack(spacing: 2) {
                    Image(systemName: habit.icon)
                        .font(.system(size: size * 0.25))
                        .foregroundStyle(ringColor)
                    
                    if showDetails {
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if showDetails {
                Text(habit.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: size + 10)
            }
        }
    }
}

// MARK: - Animated Progress Ring

struct AnimatedProgressRingView: View {
    let targetProgress: Double
    let duration: Double
    let delay: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    
    @State private var currentProgress: Double = 0
    
    init(
        progress: Double,
        duration: Double = 1.5,
        delay: Double = 0,
        color: Color = .blue,
        size: CGFloat = 80,
        lineWidth: CGFloat = 6
    ) {
        self.targetProgress = min(max(progress, 0), 1.0)
        self.duration = duration
        self.delay = delay
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)
            
            // Progress
            Circle()
                .trim(from: 0, to: currentProgress)
                .stroke(
                    color.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            // Percentage text
            Text("\(Int(currentProgress * 100))%")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(
                .easeInOut(duration: duration)
                .delay(delay)
            ) {
                currentProgress = targetProgress
            }
        }
    }
}

// MARK: - Multi-Value Progress Ring

struct MultiValueProgressRingView: View {
    struct ProgressData {
        let value: Double
        let color: Color
        let label: String?
    }
    
    let progressData: [ProgressData]
    let size: CGFloat
    let lineWidth: CGFloat
    let spacing: CGFloat
    
    init(
        progressData: [ProgressData],
        size: CGFloat = 100,
        lineWidth: CGFloat = 8,
        spacing: CGFloat = 4
    ) {
        self.progressData = progressData
        self.size = size
        self.lineWidth = lineWidth
        self.spacing = spacing
    }
    
    var body: some View {
        ZStack {
            ForEach(Array(progressData.enumerated()), id: \.offset) { index, data in
                let radius = size/2 - (CGFloat(index) * (lineWidth + spacing))
                
                Circle()
                    .stroke(Color(.systemGray6), lineWidth: lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                
                Circle()
                    .trim(from: 0, to: data.value)
                    .stroke(
                        data.color,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: data.value)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("Basic Progress Ring") {
    VStack(spacing: 20) {
        ProgressRingView(progress: 0.75)
        ProgressRingView(progress: 0.3, primaryColor: .green)
        ProgressRingView(progress: 1.0, primaryColor: .orange)
    }
    .padding()
}

#Preview("Habit Progress Ring") {
    let sampleHabit = Habit(
        name: "Вода",
        description: "Пить 8 стаканов воды",
        icon: "drop.fill",
        color: "#007AFF",
        targetValue: 8,
        unit: "стаканы"
    )
    
    VStack(spacing: 20) {
        HabitProgressRingView(habit: sampleHabit, size: 80)
        HabitProgressRingView(habit: sampleHabit, size: 60)
        HabitProgressRingView(habit: sampleHabit, size: 40, showDetails: false)
    }
    .padding()
}

#Preview("Animated Progress Ring") {
    VStack(spacing: 20) {
        AnimatedProgressRingView(progress: 0.85, color: .blue)
        AnimatedProgressRingView(progress: 0.45, color: .green, size: 60)
        AnimatedProgressRingView(progress: 0.25, color: .orange, size: 100)
    }
    .padding()
} 