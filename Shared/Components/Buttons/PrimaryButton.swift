//
//  PrimaryButton.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Основная кнопка приложения
//

import SwiftUI

// MARK: - Button Style Enum
enum ButtonStyleType {
    case primary
    case secondary
    case tertiary
    case destructive
    case outline
}

// MARK: - Button Size Enum
enum ButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 52
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .small: return .buttonSmall
        case .medium: return .buttonMedium
        case .large: return .buttonLarge
        }
    }
    
    var font: Font {
        switch self {
        case .small: return Typography.Button.small
        case .medium: return Typography.Button.medium
        case .large: return Typography.Button.large
        }
    }
}

// MARK: - Primary Button
struct PrimaryButton: View {
    
    // MARK: - Properties
    private let title: String
    private let icon: String?
    private let style: ButtonStyleType
    private let size: ButtonSize
    private let isLoading: Bool
    private let isDisabled: Bool
    private let action: () -> Void
    
    // MARK: - State
    @State private var isPressed = false
    
    // MARK: - Initialization
    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyleType = .primary,
        size: ButtonSize = .medium,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                action()
            }
        }) {
            HStack(spacing: Spacing.sm) {
                // Loading Indicator
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                }
                
                // Icon
                if let icon = icon, !isLoading {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                }
                
                // Title
                if !title.isEmpty {
                    Text(title)
                        .font(size.font)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isPressed ? ColorPalette.Primary.dark : ColorPalette.Primary.main
        case .secondary:
            return isPressed ? ColorPalette.Secondary.dark : ColorPalette.Secondary.main
        case .tertiary:
            return isPressed ? ColorPalette.Background.surface.opacity(0.8) : ColorPalette.Background.surface
        case .destructive:
            return isPressed ? ColorPalette.Semantic.error.opacity(0.8) : ColorPalette.Semantic.error
        case .outline:
            return isPressed ? ColorPalette.Primary.main.opacity(0.1) : Color.clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .secondary, .destructive:
            return ColorPalette.Text.onColor
        case .tertiary:
            return ColorPalette.Text.primary
        case .outline:
            return ColorPalette.Primary.main
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outline:
            return ColorPalette.Primary.main
        default:
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .outline:
            return 1.5
        default:
            return 0
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

// MARK: - Secondary Button
struct SecondaryButton: View {
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
            style: .secondary,
            size: size,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        )
    }
}

// MARK: - Tertiary Button
struct TertiaryButton: View {
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
            style: .tertiary,
            size: size,
            isLoading: isLoading,
            isDisabled: isDisabled,
            action: action
        )
    }
}

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
    private let style: ButtonStyleType
    private let size: ButtonSize
    private let isDisabled: Bool
    private let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String,
        style: ButtonStyleType = .tertiary,
        size: ButtonSize = .medium,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: size.height, height: size.height)
                .background(backgroundColor)
                .clipShape(Circle())
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isPressed ? ColorPalette.Primary.dark : ColorPalette.Primary.main
        case .secondary:
            return isPressed ? ColorPalette.Secondary.dark : ColorPalette.Secondary.main
        case .tertiary:
            return isPressed ? ColorPalette.Background.surface.opacity(0.8) : ColorPalette.Background.surface
        case .destructive:
            return isPressed ? ColorPalette.Semantic.error.opacity(0.8) : ColorPalette.Semantic.error
        case .outline:
            return isPressed ? ColorPalette.Primary.main.opacity(0.1) : Color.clear
        }
    }
    
    private var iconColor: Color {
        switch style {
        case .primary, .secondary, .destructive:
            return ColorPalette.Text.onColor
        case .tertiary:
            return ColorPalette.Text.primary
        case .outline:
            return ColorPalette.Primary.main
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return 16
        case .medium: return 20
        case .large: return 24
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    private let icon: String
    private let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        icon: String = "plus",
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(ColorPalette.Text.onColor)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient.primaryGradient
                )
                .clipShape(Circle())
                .applyShadow(.elevated)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Tag Button
struct TagButton: View {
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Text(title)
                .font(Typography.Label.medium)
                .fontWeight(.medium)
                .foregroundColor(textColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return isPressed ? ColorPalette.Primary.dark : ColorPalette.Primary.main
        } else {
            return isPressed ? ColorPalette.Background.surface.opacity(0.8) : ColorPalette.Background.surface
        }
    }
    
    private var textColor: Color {
        return isSelected ? ColorPalette.Text.onColor : ColorPalette.Text.primary
    }
    
    private var borderColor: Color {
        return isSelected ? Color.clear : ColorPalette.Border.main
    }
}

// MARK: - Preview
#if DEBUG
struct ButtonsPreview: View {
    @State private var isLoading = false
    @State private var selectedTag = "Первый"
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sectionSpacing) {
                
                // Primary Buttons
                buttonSection("Primary Buttons") {
                    VStack(spacing: Spacing.md) {
                        PrimaryButton("Большая кнопка", size: .large) {
                            print("Large button tapped")
                        }
                        
                        PrimaryButton("Средняя кнопка", icon: "star.fill") {
                            print("Medium button tapped")
                        }
                        
                        PrimaryButton("Малая кнопка", size: .small) {
                            print("Small button tapped")
                        }
                        
                        PrimaryButton("Загрузка", isLoading: isLoading) {
                            isLoading.toggle()
                        }
                        
                        PrimaryButton("Отключена", isDisabled: true) {
                            print("Disabled button")
                        }
                    }
                }
                
                // Button Styles
                buttonSection("Button Styles") {
                    VStack(spacing: Spacing.md) {
                        PrimaryButton("Primary Button", style: .primary) {
                            print("Primary")
                        }
                        
                        SecondaryButton("Secondary Button") {
                            print("Secondary")
                        }
                        
                        TertiaryButton("Tertiary Button") {
                            print("Tertiary")
                        }
                        
                        OutlineButton("Outline Button") {
                            print("Outline")
                        }
                        
                        DestructiveButton("Destructive Button") {
                            print("Destructive")
                        }
                    }
                }
                
                // Icon Buttons
                buttonSection("Icon Buttons") {
                    HStack(spacing: Spacing.md) {
                        IconButton(icon: "heart", style: .primary) {
                            print("Heart")
                        }
                        
                        IconButton(icon: "star", style: .secondary) {
                            print("Star")
                        }
                        
                        IconButton(icon: "bell", style: .tertiary) {
                            print("Bell")
                        }
                        
                        IconButton(icon: "trash", style: .destructive) {
                            print("Delete")
                        }
                    }
                }
                
                // Tag Buttons
                buttonSection("Tag Buttons") {
                    HStack(spacing: Spacing.sm) {
                        TagButton("Первый", isSelected: selectedTag == "Первый") {
                            selectedTag = "Первый"
                        }
                        
                        TagButton("Второй", isSelected: selectedTag == "Второй") {
                            selectedTag = "Второй"
                        }
                        
                        TagButton("Третий", isSelected: selectedTag == "Третий") {
                            selectedTag = "Третий"
                        }
                    }
                }
                
                // Floating Action Button
                buttonSection("Floating Action Button") {
                    HStack {
                        Spacer()
                        FloatingActionButton {
                            print("FAB tapped")
                        }
                        Spacer()
                    }
                }
            }
            .screenPadding()
        }
        .background(ColorPalette.Background.primary)
        .navigationTitle("Buttons")
    }
    
    @ViewBuilder
    private func buttonSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.Headline.medium)
                .foregroundColor(ColorPalette.Text.primary)
            
            content()
        }
    }
}

#Preview {
    ButtonsPreview()
}
#endif 