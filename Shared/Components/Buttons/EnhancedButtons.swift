//
//  EnhancedButtons.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Дополнительные стили кнопок и анимации
//

import SwiftUI

// MARK: - Destructive Button
struct DestructiveButton: View {
    private let title: String
    private let icon: String?
    private let size: ButtonSize
    private let isLoading: Bool
    private let isDisabled: Bool
    private let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        PrimaryButton(
            title,
            icon: icon,
            style: .destructive,
            size: size,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        )
    }
}

// MARK: - Outline Button
struct OutlineButton: View {
    private let title: String
    private let icon: String?
    private let size: ButtonSize
    private let isLoading: Bool
    private let isDisabled: Bool
    private let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        PrimaryButton(
            title,
            icon: icon,
            style: .outline,
            size: size,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        )
    }
}

// MARK: - Icon Button
struct IconButton: View {
    private let icon: String
    private let size: IconButtonSize
    private let style: IconButtonStyle
    private let isDisabled: Bool
    private let action: () -> Void
    
    @State private var isPressed = false
    
    enum IconButtonSize {
        case small
        case medium
        case large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }
    }
    
    enum IconButtonStyle {
        case filled
        case outline
        case ghost
        
        func backgroundColor(isPressed: Bool) -> Color {
            switch self {
            case .filled:
                return isPressed ? ColorPalette.Primary.dark : ColorPalette.Primary.main
            case .outline:
                return isPressed ? ColorPalette.Primary.main.opacity(0.1) : Color.clear
            case .ghost:
                return isPressed ? ColorPalette.Background.surface : Color.clear
            }
        }
        
        func foregroundColor(isPressed: Bool) -> Color {
            switch self {
            case .filled:
                return ColorPalette.Text.onColor
            case .outline:
                return ColorPalette.Primary.main
            case .ghost:
                return ColorPalette.Text.secondary
            }
        }
        
        func borderColor() -> Color {
            switch self {
            case .filled, .ghost:
                return Color.clear
            case .outline:
                return ColorPalette.Primary.main
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .filled, .ghost:
                return 0
            case .outline:
                return 1.5
            }
        }
    }
    
    init(
        icon: String,
        size: IconButtonSize = .medium,
        style: IconButtonStyle = .filled,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundColor(style.foregroundColor(isPressed: isPressed))
                .frame(width: size.dimension, height: size.dimension)
                .background(style.backgroundColor(isPressed: isPressed))
                .overlay(
                    RoundedRectangle(cornerRadius: AdaptiveCornerRadius.small)
                        .stroke(style.borderColor(), lineWidth: style.borderWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: AdaptiveCornerRadius.small))
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel(icon)
        .accessibilityRole(.button)
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    private let icon: String
    private let size: FABSize
    private let position: FABPosition
    private let action: () -> Void
    
    @State private var isPressed = false
    @State private var isVisible = true
    
    enum FABSize {
        case small
        case regular
        case large
        
        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .regular: return 56
            case .large: return 72
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 20
            case .regular: return 24
            case .large: return 28
            }
        }
    }
    
    enum FABPosition {
        case bottomTrailing
        case bottomLeading
        case center
    }
    
    init(
        icon: String,
        size: FABSize = .regular,
        position: FABPosition = .bottomTrailing,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.position = position
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Strong haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(ColorPalette.Text.onColor)
                .frame(width: size.dimension, height: size.dimension)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorPalette.Primary.main, ColorPalette.Primary.dark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                .elevatedShadow()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .scaleEffect(isVisible ? 1.0 : 0.0)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                isVisible = true
            }
        }
        .accessibilityLabel(icon)
        .accessibilityRole(.button)
        .accessibilityHint("Floating action button")
    }
}

// MARK: - Toggle Button
struct ToggleButton: View {
    @Binding private var isSelected: Bool
    private let title: String
    private let icon: String?
    private let size: ButtonSize
    private let style: ToggleButtonStyle
    private let isDisabled: Bool
    
    enum ToggleButtonStyle {
        case filled
        case outline
        case chip
    }
    
    init(
        title: String,
        icon: String? = nil,
        isSelected: Binding<Bool>,
        size: ButtonSize = .medium,
        style: ToggleButtonStyle = .filled,
        isDisabled: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self._isSelected = isSelected
        self.size = size
        self.style = style
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSelected.toggle()
                }
                
                // Haptic feedback
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
            }
        }) {
            HStack(spacing: AdaptiveSpacing.padding(8)) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(textColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Выбрано" : "Не выбрано")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch style {
        case .filled:
            return isSelected ? ColorPalette.Primary.main : ColorPalette.Background.surface
        case .outline:
            return isSelected ? ColorPalette.Primary.main.opacity(0.1) : Color.clear
        case .chip:
            return isSelected ? ColorPalette.Primary.main.opacity(0.15) : ColorPalette.Background.grouped
        }
    }
    
    private var textColor: Color {
        switch style {
        case .filled:
            return isSelected ? ColorPalette.Text.onColor : ColorPalette.Text.primary
        case .outline, .chip:
            return isSelected ? ColorPalette.Primary.main : ColorPalette.Text.primary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .filled:
            return Color.clear
        case .outline:
            return isSelected ? ColorPalette.Primary.main : ColorPalette.Border.main
        case .chip:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .filled, .chip:
            return 0
        case .outline:
            return isSelected ? 2 : 1
        }
    }
    
    private var cornerRadius: CGFloat {
        switch style {
        case .filled, .outline:
            return AdaptiveCornerRadius.medium
        case .chip:
            return size.height / 2
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .filled, .outline:
            return AdaptiveSpacing.padding(16)
        case .chip:
            return AdaptiveSpacing.padding(12)
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .filled, .outline:
            return AdaptiveSpacing.padding(12)
        case .chip:
            return AdaptiveSpacing.padding(8)
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }
}

// MARK: - Link Button
struct LinkButton: View {
    private let title: String
    private let icon: String?
    private let size: LinkButtonSize
    private let action: () -> Void
    
    @State private var isPressed = false
    
    enum LinkButtonSize {
        case small
        case medium
        case large
        
        var font: Font {
            switch self {
            case .small:
                return .system(size: AdaptiveTypography.body(14), weight: .medium)
            case .medium:
                return .system(size: AdaptiveTypography.body(), weight: .medium)
            case .large:
                return .system(size: AdaptiveTypography.body(18), weight: .medium)
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }
    }
    
    init(
        _ title: String,
        icon: String? = nil,
        size: LinkButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(size.font)
                    .underline(isPressed)
            }
            .foregroundColor(ColorPalette.Primary.main)
            .opacity(isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel(title)
        .accessibilityRole(.link)
    }
}

// MARK: - Button Group
struct ButtonGroup<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    let axis: Axis
    
    enum Axis {
        case horizontal
        case vertical
    }
    
    init(
        spacing: CGFloat = AdaptiveSpacing.padding(12),
        axis: Axis = .horizontal,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.spacing = spacing
        self.axis = axis
    }
    
    var body: some View {
        switch axis {
        case .horizontal:
            HStack(spacing: spacing) {
                content
            }
        case .vertical:
            VStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - Preview
#Preview("Enhanced Buttons") {
    ScrollView {
        VStack(spacing: 24) {
            // Destructive and Outline
            ButtonGroup {
                DestructiveButton("Удалить") { }
                OutlineButton("Отмена") { }
            }
            
            // Icon Buttons
            ButtonGroup {
                IconButton(icon: "heart", style: .filled) { }
                IconButton(icon: "bookmark", style: .outline) { }
                IconButton(icon: "share", style: .ghost) { }
            }
            
            // Toggle Buttons
            VStack(spacing: 12) {
                ButtonGroup {
                    ToggleButton(title: "Важное", isSelected: .constant(true), style: .filled)
                    ToggleButton(title: "Срочное", isSelected: .constant(false), style: .filled)
                }
                
                ButtonGroup {
                    ToggleButton(title: "Работа", isSelected: .constant(true), style: .chip)
                    ToggleButton(title: "Дом", isSelected: .constant(false), style: .chip)
                    ToggleButton(title: "Спорт", isSelected: .constant(true), style: .chip)
                }
            }
            
            // Link Buttons
            VStack(alignment: .leading, spacing: 8) {
                LinkButton("Подробнее", icon: "arrow.right") { }
                LinkButton("Настройки", icon: "gearshape", size: .small) { }
                LinkButton("Справка", size: .large) { }
            }
            
            // Floating Action Button
            ZStack {
                Rectangle()
                    .fill(ColorPalette.Background.grouped)
                    .frame(height: 200)
                    .overlay(
                        Text("Содержимое экрана")
                            .foregroundColor(ColorPalette.Text.secondary)
                    )
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(icon: "plus") { }
                            .padding()
                    }
                }
            }
            .adaptiveCornerRadius()
        }
        .adaptivePadding()
    }
    .adaptivePreviews()
} 