//
//  PickerComponents.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Picker'ы и Toggle'ы для форм
//

import SwiftUI

// MARK: - Custom Picker
struct PlannerPicker<SelectionValue: Hashable, Content: View>: View {
    // MARK: - Properties
    let title: String
    @Binding var selection: SelectionValue
    let content: Content
    let helperText: String?
    let errorText: String?
    let isRequired: Bool
    let isDisabled: Bool
    
    // MARK: - Initialization
    init(
        title: String,
        selection: Binding<SelectionValue>,
        helperText: String? = nil,
        errorText: String? = nil,
        isRequired: Bool = false,
        isDisabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._selection = selection
        self.helperText = helperText
        self.errorText = errorText
        self.isRequired = isRequired
        self.isDisabled = isDisabled
        self.content = content()
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            // Title Label
            titleLabel
            
            // Picker
            Picker(title, selection: $selection) {
                content
            }
            .pickerStyle(.menu)
            .disabled(isDisabled)
            .foregroundColor(isDisabled ? ColorPalette.Text.tertiary : ColorPalette.Text.primary)
            .padding(.horizontal, AdaptiveSpacing.padding(12))
            .padding(.vertical, AdaptiveSpacing.padding(14))
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: AdaptiveCornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .opacity(isDisabled ? 0.6 : 1.0)
            
            // Helper/Error Text
            bottomText
        }
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
        } else {
            return ColorPalette.Border.main
        }
    }
    
    private var borderWidth: CGFloat {
        errorText != nil ? 2 : 1
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
            return "Выберите \(title.lowercased())"
        }
    }
}

// MARK: - Segmented Picker
struct PlannerSegmentedPicker<SelectionValue: Hashable>: View {
    // MARK: - Properties
    let title: String
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    let helperText: String?
    let errorText: String?
    let isRequired: Bool
    let isDisabled: Bool
    
    // MARK: - Initialization
    init(
        title: String,
        selection: Binding<SelectionValue>,
        options: [(value: SelectionValue, label: String)],
        helperText: String? = nil,
        errorText: String? = nil,
        isRequired: Bool = false,
        isDisabled: Bool = false
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.helperText = helperText
        self.errorText = errorText
        self.isRequired = isRequired
        self.isDisabled = isDisabled
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            // Title Label
            titleLabel
            
            // Segmented Control
            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.6 : 1.0)
            
            // Helper/Error Text
            bottomText
        }
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
            return "Выберите один из вариантов для \(title.lowercased())"
        }
    }
}

// MARK: - Custom Toggle
struct PlannerToggle: View {
    // MARK: - Properties
    let title: String
    let description: String?
    @Binding var isOn: Bool
    let helperText: String?
    let errorText: String?
    let isDisabled: Bool
    let style: ToggleStyle
    
    // MARK: - Toggle Style
    enum ToggleStyle {
        case `default`
        case card
        case compact
    }
    
    // MARK: - Initialization
    init(
        title: String,
        description: String? = nil,
        isOn: Binding<Bool>,
        helperText: String? = nil,
        errorText: String? = nil,
        isDisabled: Bool = false,
        style: ToggleStyle = .default
    ) {
        self.title = title
        self.description = description
        self._isOn = isOn
        self.helperText = helperText
        self.errorText = errorText
        self.isDisabled = isDisabled
        self.style = style
    }
    
    // MARK: - Body
    var body: some View {
        switch style {
        case .default:
            defaultToggleView
        case .card:
            cardToggleView
        case .compact:
            compactToggleView
        }
    }
    
    // MARK: - Toggle Views
    @ViewBuilder
    private var defaultToggleView: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: AdaptiveTypography.body(), weight: .medium))
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    if let description = description {
                        Text(description)
                            .font(.system(size: AdaptiveTypography.body(14)))
                            .foregroundColor(ColorPalette.Text.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: ColorPalette.Primary.main))
                    .disabled(isDisabled)
            }
            
            bottomText
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    @ViewBuilder
    private var cardToggleView: some View {
        Button(action: {
            if !isDisabled {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOn.toggle()
                }
            }
        }) {
            VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(12)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: AdaptiveTypography.body(), weight: .medium))
                            .foregroundColor(isOn ? ColorPalette.Text.onColor : ColorPalette.Text.primary)
                        
                        if let description = description {
                            Text(description)
                                .font(.system(size: AdaptiveTypography.body(14)))
                                .foregroundColor(isOn ? ColorPalette.Text.onColor.opacity(0.8) : ColorPalette.Text.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: AdaptiveIcons.medium))
                        .foregroundColor(isOn ? ColorPalette.Text.onColor : ColorPalette.Text.secondary)
                }
                
                if helperText != nil || errorText != nil {
                    bottomText
                }
            }
            .adaptivePadding()
            .background(isOn ? ColorPalette.Primary.main : ColorPalette.Background.surface)
            .adaptiveCornerRadius()
            .overlay(
                RoundedRectangle(cornerRadius: AdaptiveCornerRadius.medium)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
    
    @ViewBuilder
    private var compactToggleView: some View {
        HStack(spacing: AdaptiveSpacing.padding(12)) {
            Text(title)
                .font(.system(size: AdaptiveTypography.body(14), weight: .medium))
                .foregroundColor(ColorPalette.Text.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: ColorPalette.Primary.main))
                .disabled(isDisabled)
        }
        .opacity(isDisabled ? 0.6 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var bottomText: some View {
        if let errorText = errorText {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: AdaptiveIcons.small))
                    .foregroundColor(style == .card && isOn ? ColorPalette.Text.onColor : ColorPalette.Semantic.error)
                
                Text(errorText)
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(style == .card && isOn ? ColorPalette.Text.onColor : ColorPalette.Semantic.error)
            }
        } else if let helperText = helperText {
            Text(helperText)
                .font(.system(size: AdaptiveTypography.body(12)))
                .foregroundColor(style == .card && isOn ? ColorPalette.Text.onColor.opacity(0.8) : ColorPalette.Text.secondary)
        }
    }
    
    // MARK: - Computed Properties
    private var borderColor: Color {
        if errorText != nil {
            return ColorPalette.Semantic.error
        } else if style == .card && isOn {
            return ColorPalette.Primary.main
        } else {
            return ColorPalette.Border.main
        }
    }
    
    private var borderWidth: CGFloat {
        errorText != nil ? 2 : 1
    }
    
    private var accessibilityLabel: String {
        var label = title
        if let description = description {
            label += ", \(description)"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if let errorText = errorText {
            return "Ошибка: \(errorText)"
        } else if let helperText = helperText {
            return helperText
        } else {
            return isOn ? "Включено, нажмите чтобы выключить" : "Выключено, нажмите чтобы включить"
        }
    }
}

// MARK: - Multi-selection Picker
struct PlannerMultiSelectionPicker<Item: Hashable & Identifiable>: View {
    // MARK: - Properties
    let title: String
    let items: [Item]
    @Binding var selectedItems: Set<Item>
    let itemLabel: (Item) -> String
    let helperText: String?
    let errorText: String?
    let isRequired: Bool
    let maxSelection: Int?
    
    // MARK: - Initialization
    init(
        title: String,
        items: [Item],
        selectedItems: Binding<Set<Item>>,
        itemLabel: @escaping (Item) -> String,
        helperText: String? = nil,
        errorText: String? = nil,
        isRequired: Bool = false,
        maxSelection: Int? = nil
    ) {
        self.title = title
        self.items = items
        self._selectedItems = selectedItems
        self.itemLabel = itemLabel
        self.helperText = helperText
        self.errorText = errorText
        self.isRequired = isRequired
        self.maxSelection = maxSelection
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveSpacing.padding(8)) {
            // Title Label
            titleLabel
            
            // Options
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AdaptiveSpacing.padding(8)) {
                ForEach(items) { item in
                    selectionButton(for: item)
                }
            }
            
            // Helper/Error Text
            bottomText
        }
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
            
            Spacer()
            
            if let maxSelection = maxSelection {
                Text("\(selectedItems.count)/\(maxSelection)")
                    .font(.system(size: AdaptiveTypography.body(12)))
                    .foregroundColor(ColorPalette.Text.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func selectionButton(for item: Item) -> some View {
        let isSelected = selectedItems.contains(item)
        let canSelect = maxSelection == nil || selectedItems.count < maxSelection! || isSelected
        
        Button(action: {
            if isSelected {
                selectedItems.remove(item)
            } else if canSelect {
                selectedItems.insert(item)
            }
        }) {
            HStack(spacing: AdaptiveSpacing.padding(8)) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: AdaptiveIcons.small))
                    .foregroundColor(isSelected ? ColorPalette.Primary.main : ColorPalette.Text.secondary)
                
                Text(itemLabel(item))
                    .font(.system(size: AdaptiveTypography.body(14)))
                    .foregroundColor(ColorPalette.Text.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .adaptivePadding(8)
            .background(isSelected ? ColorPalette.Primary.main.opacity(0.1) : ColorPalette.Background.surface)
            .adaptiveCornerRadius(.small)
            .overlay(
                RoundedRectangle(cornerRadius: AdaptiveCornerRadius.small)
                    .stroke(isSelected ? ColorPalette.Primary.main : ColorPalette.Border.main, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSelect && !isSelected)
        .opacity(canSelect || isSelected ? 1.0 : 0.6)
        .accessibilityLabel("\(itemLabel(item)), \(isSelected ? "выбрано" : "не выбрано")")
        .accessibilityHint(isSelected ? "Нажмите чтобы убрать из выбора" : "Нажмите чтобы добавить к выбору")
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
}

// MARK: - Preview
#Preview("Form Components") {
    ScrollView {
        VStack(spacing: 24) {
            // Picker
            PlannerPicker(
                title: "Приоритет",
                selection: .constant("medium"),
                helperText: "Выберите приоритет задачи",
                isRequired: true
            ) {
                Text("Низкий").tag("low")
                Text("Средний").tag("medium")
                Text("Высокий").tag("high")
                Text("Срочный").tag("urgent")
            }
            
            // Segmented Picker
            PlannerSegmentedPicker(
                title: "Тип привычки",
                selection: .constant("health"),
                options: [
                    ("health", "Здоровье"),
                    ("productivity", "Продуктивность"),
                    ("learning", "Обучение")
                ],
                helperText: "Категория для группировки привычек"
            )
            
            // Toggle Default
            PlannerToggle(
                title: "Уведомления",
                description: "Получать push-уведомления о привычках",
                isOn: .constant(true),
                helperText: "Поможет не забывать о привычках"
            )
            
            // Toggle Card
            PlannerToggle(
                title: "Синхронизация",
                description: "Синхронизировать данные через iCloud",
                isOn: .constant(false),
                style: .card
            )
            
            // Toggle Compact
            PlannerToggle(
                title: "Темная тема",
                isOn: .constant(true),
                style: .compact
            )
        }
        .adaptivePadding()
    }
    .adaptivePreviews()
} 