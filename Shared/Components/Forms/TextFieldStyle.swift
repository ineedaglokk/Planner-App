//
//  TextFieldStyle.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Стилизованные текстовые поля для форм
//

import SwiftUI

// MARK: - Custom Text Field Style
struct PlannerTextFieldStyle: TextFieldStyle {
    let state: FieldState
    let cornerRadius: CGFloat
    
    init(state: FieldState = .normal, cornerRadius: CGFloat = AdaptiveCornerRadius.medium) {
        self.state = state
        self.cornerRadius = cornerRadius
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: AdaptiveTypography.body(), weight: .regular))
            .foregroundColor(textColor)
            .padding(.horizontal, AdaptiveSpacing.padding(12))
            .padding(.vertical, AdaptiveSpacing.padding(14))
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .animation(.easeInOut(duration: 0.2), value: state)
    }
    
    private var backgroundColor: Color {
        switch state {
        case .normal, .focused:
            return ColorPalette.Background.surface
        case .error:
            return ColorPalette.Semantic.error.opacity(0.05)
        case .disabled:
            return ColorPalette.Background.surface.opacity(0.5)
        case .success:
            return ColorPalette.Semantic.success.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .normal:
            return ColorPalette.Border.main
        case .focused:
            return ColorPalette.Primary.main
        case .error:
            return ColorPalette.Semantic.error
        case .disabled:
            return ColorPalette.Border.main.opacity(0.5)
        case .success:
            return ColorPalette.Semantic.success
        }
    }
    
    private var textColor: Color {
        switch state {
        case .disabled:
            return ColorPalette.Text.tertiary
        default:
            return ColorPalette.Text.primary
        }
    }
    
    private var borderWidth: CGFloat {
        switch state {
        case .focused, .error, .success:
            return 2
        default:
            return 1
        }
    }
}

// MARK: - Field State
enum FieldState {
    case normal
    case focused
    case error
    case disabled
    case success
}

// MARK: - Enhanced Text Field
struct PlannerTextField: View {
    // MARK: - Properties
    let title: String
    @Binding var text: String
    let placeholder: String
    let helperText: String?
    let errorText: String?
    let isRequired: Bool
    let isSecure: Bool
    let keyboardType: UIKeyboardType
    let autocapitalization: TextInputAutocapitalization
    let isDisabled: Bool
    
    @FocusState private var isFocused: Bool
    @State private var isSecureTextVisible = false
    
    // MARK: - Initialization
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        helperText: String? = nil,
        errorText: String? = nil,
        isRequired: Bool = false,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences,
        isDisabled: Bool = false
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.helperText = helperText
        self.errorText = errorText
        self.isRequired = isRequired
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.isDisabled = isDisabled
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            // Title Label
            titleLabel
            
            // Text Field
            textFieldView
            
            // Helper/Error Text
            bottomText
        }
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var titleLabel: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                .foregroundColor(ColorPalette.Text.primary)
            
            if isRequired {
                Text("*")
                    .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                    .foregroundColor(ColorPalette.Semantic.error)
            }
        }
    }
    
    @ViewBuilder
    private var textFieldView: some View {
        HStack {
            if isSecure && !isSecureTextVisible {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlannerTextFieldStyle(state: fieldState))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .focused($isFocused)
                    .disabled(isDisabled)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlannerTextFieldStyle(state: fieldState))
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .focused($isFocused)
                    .disabled(isDisabled)
            }
            
            if isSecure {
                Button(action: { isSecureTextVisible.toggle() }) {
                    Image(systemName: isSecureTextVisible ? "eye.slash" : "eye")
                        .font(.system(size: AdaptiveIcons.small))
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                .padding(.trailing, AdaptiveSpacing.padding(8))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    @ViewBuilder
    private var bottomText: some View {
        if let errorText = errorText {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: AdaptiveIcons.small))
                    .foregroundColor(ColorPalette.Semantic.error)
                
                Text(errorText)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Semantic.error)
            }
        } else if let helperText = helperText {
            Text(helperText)
                .font(.system(size: AdaptiveTypography.body(12)))
                .foregroundColor(ColorPalette.Text.secondary)
        }
    }
    
    // MARK: - Computed Properties
    private var fieldState: FieldState {
        if isDisabled {
            return .disabled
        } else if errorText != nil {
            return .error
        } else if isFocused {
            return .focused
        } else {
            return .normal
        }
    }
    
    private var accessibilityLabel: String {
        var label = title
        if isRequired {
            label += ", обязательное поле"
        }
        if isSecure {
            label += ", защищенный ввод"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if let errorText = errorText {
            return "Ошибка: \(errorText)"
        } else if let helperText = helperText {
            return helperText
        } else {
            return "Введите \(title.lowercased())"
        }
    }
}

// MARK: - Multi-line Text Field
struct PlannerTextEditor: View {
    // MARK: - Properties
    let title: String
    @Binding var text: String
    let placeholder: String
    let helperText: String?
    let errorText: String?
    let isRequired: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let isDisabled: Bool
    
    @FocusState private var isFocused: Bool
    
    // MARK: - Initialization
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        helperText: String? = nil,
        errorText: String? = nil,
        isRequired: Bool = false,
        minHeight: CGFloat = 80,
        maxHeight: CGFloat = 200,
        isDisabled: Bool = false
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.helperText = helperText
        self.errorText = errorText
        self.isRequired = isRequired
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.isDisabled = isDisabled
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            // Title Label
            titleLabel
            
            // Text Editor
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AdaptiveCornerRadius.medium)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: AdaptiveCornerRadius.medium)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .frame(minHeight: minHeight, maxHeight: maxHeight)
                
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: AdaptiveTypography.body()))
                        .foregroundColor(ColorPalette.Text.placeholder)
                        .padding(.horizontal, AdaptiveSpacing.padding(12))
                        .padding(.vertical, AdaptiveSpacing.padding(14))
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: AdaptiveTypography.body()))
                    .foregroundColor(ColorPalette.Text.primary)
                    .padding(.horizontal, AdaptiveSpacing.padding(8))
                    .padding(.vertical, AdaptiveSpacing.padding(10))
                    .focused($isFocused)
                    .disabled(isDisabled)
                    .scrollContentBackground(.hidden)
            }
            
            // Helper/Error Text
            bottomText
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var titleLabel: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                .foregroundColor(ColorPalette.Text.primary)
            
            if isRequired {
                Text("*")
                    .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                    .foregroundColor(ColorPalette.Semantic.error)
            }
        }
    }
    
    @ViewBuilder
    private var bottomText: some View {
        if let errorText = errorText {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: AdaptiveIcons.small))
                    .foregroundColor(ColorPalette.Semantic.error)
                
                Text(errorText)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Semantic.error)
            }
        } else if let helperText = helperText {
            Text(helperText)
                .font(.system(size: AdaptiveTypography.body(12)))
                .foregroundColor(ColorPalette.Text.secondary)
        }
    }
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        if isDisabled {
            return ColorPalette.Background.surface.opacity(0.5)
        } else if errorText != nil {
            return ColorPalette.Semantic.error.opacity(0.05)
        } else {
            return ColorPalette.Background.surface
        }
    }
    
    private var borderColor: Color {
        if isDisabled {
            return ColorPalette.Border.main.opacity(0.5)
        } else if errorText != nil {
            return ColorPalette.Semantic.error
        } else if isFocused {
            return ColorPalette.Primary.main
        } else {
            return ColorPalette.Border.main
        }
    }
    
    private var borderWidth: CGFloat {
        if isFocused || errorText != nil {
            return 2
        } else {
            return 1
        }
    }
    
    private var accessibilityLabel: String {
        var label = title
        if isRequired {
            label += ", обязательное поле"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if let errorText = errorText {
            return "Ошибка: \(errorText)"
        } else if let helperText = helperText {
            return helperText
        } else {
            return "Введите \(title.lowercased())"
        }
    }
}

// MARK: - Preview
#Preview("Text Fields") {
    VStack(spacing: 20) {
        PlannerTextField(
            title: "Имя пользователя",
            text: .constant(""),
            placeholder: "Введите ваше имя",
            helperText: "Это имя будет отображаться в профиле",
            isRequired: true
        )
        
        PlannerTextField(
            title: "Пароль",
            text: .constant(""),
            placeholder: "Введите пароль",
            isRequired: true,
            isSecure: true
        )
        
        PlannerTextField(
            title: "Email с ошибкой",
            text: .constant("invalid-email"),
            placeholder: "email@example.com",
            errorText: "Некорректный формат email",
            keyboardType: .emailAddress
        )
        
        PlannerTextEditor(
            title: "Описание",
            text: .constant(""),
            placeholder: "Введите описание цели...",
            helperText: "Опишите детали вашей цели"
        )
    }
    .adaptivePadding()
    .adaptivePreviews()
} 