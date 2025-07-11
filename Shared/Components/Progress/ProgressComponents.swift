//
//  ProgressComponents.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Индикаторы прогресса и progress rings
//

import SwiftUI

// MARK: - Progress Bar
struct PlannerProgressBar: View {
    let progress: Double // 0.0 to 1.0
    let height: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat?
    let showPercentage: Bool
    let animated: Bool
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        height: CGFloat = 8,
        backgroundColor: Color = ColorPalette.Background.grouped,
        foregroundColor: Color = ColorPalette.Primary.main,
        cornerRadius: CGFloat? = nil,
        showPercentage: Bool = false,
        animated: Bool = true
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.height = height
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius ?? height / 2
        self.showPercentage = showPercentage
        self.animated = animated
    }
    
    var body: some View {
        VStack(spacing: AdaptiveSpacing.padding(4)) {
            HStack {
                if showPercentage {
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: AdaptiveTypography.body(12), weight: .medium))
                        .foregroundColor(ColorPalette.Text.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: cornerRadius!)
                        .fill(backgroundColor)
                        .frame(height: height)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: cornerRadius!)
                        .fill(foregroundColor)
                        .frame(
                            width: geometry.size.width * (animated ? animatedProgress : progress),
                            height: height
                        )
                        .animation(
                            animated ? .easeInOut(duration: 1.0) : nil,
                            value: animatedProgress
                        )
                }
            }
            .frame(height: height)
            .onAppear {
                if animated {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        animatedProgress = progress
                    }
                }
            }
            .onChange(of: progress) { _, newValue in
                if animated {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        animatedProgress = newValue
                    }
                } else {
                    animatedProgress = newValue
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Прогресс \(Int(progress * 100)) процентов")
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

// MARK: - Segmented Progress Bar
struct SegmentedProgressBar: View {
    let segments: [ProgressSegment]
    let height: CGFloat
    let spacing: CGFloat
    let cornerRadius: CGFloat?
    let showLabels: Bool
    
    struct ProgressSegment: Identifiable {
        let id = UUID()
        let value: Double
        let color: Color
        let label: String?
        
        init(value: Double, color: Color, label: String? = nil) {
            self.value = value
            self.color = color
            self.label = label
        }
    }
    
    init(
        segments: [ProgressSegment],
        height: CGFloat = 8,
        spacing: CGFloat = 2,
        cornerRadius: CGFloat? = nil,
        showLabels: Bool = false
    ) {
        self.segments = segments
        self.height = height
        self.spacing = spacing
        self.cornerRadius = cornerRadius ?? height / 2
        self.showLabels = showLabels
    }
    
    var body: some View {
        VStack(spacing: AdaptiveSpacing.padding(8)) {
            // Progress Bar
            HStack(spacing: spacing) {
                ForEach(segments) { segment in
                    RoundedRectangle(cornerRadius: cornerRadius!)
                        .fill(segment.color)
                        .frame(height: height)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: segment.value, anchor: .leading)
                        .animation(.easeInOut(duration: 0.8), value: segment.value)
                }
            }
            
            // Labels
            if showLabels {
                HStack {
                    ForEach(segments) { segment in
                        if let label = segment.label {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(segment.color)
                                    .frame(width: 8, height: 8)
                                
                                Text(label)
                                    .font(.system(size: AdaptiveTypography.body(10)))
                                    .foregroundColor(ColorPalette.Text.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Circular Progress
struct CircularProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let showPercentage: Bool
    let percentageFont: Font
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        size: CGFloat = 60,
        lineWidth: CGFloat? = nil,
        backgroundColor: Color = ColorPalette.Background.grouped,
        foregroundColor: Color = ColorPalette.Primary.main,
        showPercentage: Bool = true,
        percentageFont: Font? = nil
    ) {
        self.progress = min(max(progress, 0.0), 1.0)
        self.size = size
        self.lineWidth = lineWidth ?? size * 0.1
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.showPercentage = showPercentage
        self.percentageFont = percentageFont ?? .system(size: size * 0.2, weight: .semibold)
    }
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    foregroundColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: animatedProgress)
            
            // Percentage Text
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(percentageFont)
                    .foregroundColor(ColorPalette.Text.primary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Круговой прогресс \(Int(progress * 100)) процентов")
    }
}

// MARK: - Step Progress Indicator
struct StepProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let completedColor: Color
    let currentColor: Color
    let futureColor: Color
    let showLabels: Bool
    let labels: [String]?
    
    init(
        currentStep: Int,
        totalSteps: Int,
        completedColor: Color = ColorPalette.Semantic.success,
        currentColor: Color = ColorPalette.Primary.main,
        futureColor: Color = ColorPalette.Background.grouped,
        showLabels: Bool = false,
        labels: [String]? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.completedColor = completedColor
        self.currentColor = currentColor
        self.futureColor = futureColor
        self.showLabels = showLabels
        self.labels = labels
    }
    
    var body: some View {
        VStack(spacing: AdaptiveSpacing.padding(8)) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    HStack {
                        // Step Circle
                        ZStack {
                            Circle()
                                .fill(stepBackgroundColor(for: step))
                                .frame(width: 24, height: 24)
                            
                            if step <= currentStep {
                                Image(systemName: step < currentStep ? "checkmark" : "\(step)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(stepTextColor(for: step))
                            } else {
                                Text("\(step)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(stepTextColor(for: step))
                            }
                        }
                        
                        // Connection Line
                        if step < totalSteps {
                            Rectangle()
                                .fill(step < currentStep ? completedColor : futureColor)
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            
            // Labels
            if showLabels, let labels = labels {
                HStack {
                    ForEach(0..<labels.count, id: \.self) { index in
                        Text(labels[index])
                            .font(.system(size: AdaptiveTypography.body(10)))
                            .foregroundColor(stepLabelColor(for: index + 1))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Шаг \(currentStep) из \(totalSteps)")
    }
    
    private func stepBackgroundColor(for step: Int) -> Color {
        if step < currentStep {
            return completedColor
        } else if step == currentStep {
            return currentColor
        } else {
            return futureColor
        }
    }
    
    private func stepTextColor(for step: Int) -> Color {
        if step <= currentStep {
            return ColorPalette.Text.onColor
        } else {
            return ColorPalette.Text.secondary
        }
    }
    
    private func stepLabelColor(for step: Int) -> Color {
        if step <= currentStep {
            return ColorPalette.Text.primary
        } else {
            return ColorPalette.Text.secondary
        }
    }
}

// MARK: - Loading Progress
struct LoadingProgress: View {
    let isLoading: Bool
    let progress: Double?
    let message: String?
    let style: LoadingStyle
    
    enum LoadingStyle {
        case spinner
        case progressBar
        case dots
    }
    
    init(
        isLoading: Bool,
        progress: Double? = nil,
        message: String? = nil,
        style: LoadingStyle = .spinner
    ) {
        self.isLoading = isLoading
        self.progress = progress
        self.message = message
        self.style = style
    }
    
    var body: some View {
        if isLoading {
            VStack(spacing: AdaptiveSpacing.padding(16)) {
                switch style {
                case .spinner:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorPalette.Primary.main))
                        .scaleEffect(1.2)
                
                case .progressBar:
                    if let progress = progress {
                        VStack(spacing: AdaptiveSpacing.padding(8)) {
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.Primary.main))
                                .frame(height: 4)
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: AdaptiveTypography.body(12)))
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    } else {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.Primary.main))
                    }
                
                case .dots:
                    LoadingDotsView()
                }
                
                if let message = message {
                    Text(message)
                        .font(.system(size: AdaptiveTypography.body(14)))
                        .foregroundColor(ColorPalette.Text.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .adaptivePadding()
            .background(ColorPalette.Background.surface)
            .adaptiveCornerRadius()
            .cardShadow()
        }
    }
}

// MARK: - Loading Dots Animation
struct LoadingDotsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(ColorPalette.Primary.main)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Achievement Progress
struct AchievementProgress: View {
    let title: String
    let description: String
    let progress: Double
    let maxValue: Int
    let currentValue: Int
    let icon: String
    let color: Color
    let isCompleted: Bool
    
    init(
        title: String,
        description: String,
        progress: Double,
        maxValue: Int,
        currentValue: Int,
        icon: String,
        color: Color = ColorPalette.Primary.main,
        isCompleted: Bool = false
    ) {
        self.title = title
        self.description = description
        self.progress = progress
        self.maxValue = maxValue
        self.currentValue = currentValue
        self.icon = icon
        self.color = color
        self.isCompleted = isCompleted
    }
    
    var body: some View {
        HStack(spacing: AdaptiveSpacing.padding(16)) {
            // Icon
            ZStack {
                Circle()
                    .fill(isCompleted ? color : color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isCompleted ? ColorPalette.Text.onColor : color)
                
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ColorPalette.Text.onColor)
                        .background(Circle().fill(color))
                        .offset(x: 18, y: -18)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(4)) {
                Text(title)
                    .font(.system(size: AdaptiveTypography.body(), weight: .semibold))
                    .foregroundColor(ColorPalette.Text.primary)
                
                Text(description)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Text.secondary)
                    .lineLimit(2)
                
                HStack {
                    PlannerProgressBar(
                        progress: progress,
                        height: 6,
                        foregroundColor: color,
                        showPercentage: false
                    )
                    
                    Text("\(currentValue)/\(maxValue)")
                        .font(.system(size: AdaptiveTypography.body(10), weight: .medium))
                        .foregroundColor(ColorPalette.Text.secondary)
                        .frame(minWidth: 40)
                }
            }
        }
        .adaptivePadding()
        .background(ColorPalette.Background.surface)
        .adaptiveCornerRadius()
        .overlay(
            RoundedRectangle(cornerRadius: AdaptiveCornerRadius.medium)
                .stroke(isCompleted ? color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(description), прогресс \(currentValue) из \(maxValue)")
    }
}

// MARK: - Preview
#Preview("Progress Components") {
    ScrollView {
        VStack(spacing: 20) {
            // Progress Bars
            VStack(spacing: 12) {
                PlannerProgressBar(progress: 0.75, showPercentage: true)
                PlannerProgressBar(progress: 0.4, height: 12, foregroundColor: ColorPalette.Semantic.success)
            }
            
            // Segmented Progress
            SegmentedProgressBar(
                segments: [
                    SegmentedProgressBar.ProgressSegment(value: 1.0, color: ColorPalette.Semantic.success, label: "Завершено"),
                    SegmentedProgressBar.ProgressSegment(value: 0.6, color: ColorPalette.Semantic.warning, label: "В процессе"),
                    SegmentedProgressBar.ProgressSegment(value: 0.3, color: ColorPalette.Semantic.error, label: "Не начато")
                ],
                showLabels: true
            )
            
            // Circular Progress
            HStack {
                CircularProgress(progress: 0.8, size: 80)
                CircularProgress(progress: 0.45, size: 60, foregroundColor: ColorPalette.Secondary.main)
                CircularProgress(progress: 0.9, size: 100, showPercentage: false)
            }
            
            // Step Progress
            StepProgressIndicator(
                currentStep: 3,
                totalSteps: 5,
                showLabels: true,
                labels: ["Старт", "Настройка", "Прогресс", "Проверка", "Завершение"]
            )
            
            // Achievement Progress
            AchievementProgress(
                title: "Мастер привычек",
                description: "Выполните 100 привычек подряд",
                progress: 0.65,
                maxValue: 100,
                currentValue: 65,
                icon: "star.fill"
            )
            
            // Loading
            LoadingProgress(
                isLoading: true,
                progress: 0.6,
                message: "Синхронизация данных...",
                style: .progressBar
            )
        }
        .adaptivePadding()
    }
    .adaptivePreviews()
} 