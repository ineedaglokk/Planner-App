//
//  EmptyStateViews.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Компоненты для состояний пустых экранов
//

import SwiftUI

// MARK: - Empty State Configuration
struct EmptyStateConfiguration {
    let icon: String
    let title: String
    let description: String
    let actionTitle: String?
    let secondaryActionTitle: String?
    let iconColor: Color
    let style: EmptyStateStyle
    let animation: EmptyStateAnimation
    
    enum EmptyStateStyle {
        case minimal
        case detailed
        case illustration
    }
    
    enum EmptyStateAnimation {
        case none
        case bounce
        case pulse
        case float
        case rotate
    }
    
    init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String? = nil,
        secondaryActionTitle: String? = nil,
        iconColor: Color = ColorPalette.Primary.main,
        style: EmptyStateStyle = .detailed,
        animation: EmptyStateAnimation = .pulse
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.iconColor = iconColor
        self.style = style
        self.animation = animation
    }
}

// MARK: - Generic Empty State View
struct EmptyStateView: View {
    let configuration: EmptyStateConfiguration
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    
    @State private var isAnimating = false
    
    init(
        configuration: EmptyStateConfiguration,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: AdaptiveSpacing.padding(24)) {
            Spacer()
            
            // Icon with Animation
            iconView
                .modifier(AnimationModifier(
                    animation: configuration.animation,
                    isAnimating: $isAnimating
                ))
            
            // Content
            contentView
            
            // Actions
            if configuration.actionTitle != nil || configuration.secondaryActionTitle != nil {
                actionButtons
            }
            
            Spacer()
        }
        .adaptivePadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var iconView: some View {
        switch configuration.style {
        case .minimal:
            Image(systemName: configuration.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(configuration.iconColor.opacity(0.6))
                
        case .detailed:
            ZStack {
                Circle()
                    .fill(configuration.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: configuration.icon)
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(configuration.iconColor)
            }
            
        case .illustration:
            ZStack {
                // Background circles for depth
                Circle()
                    .fill(configuration.iconColor.opacity(0.05))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(configuration.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: configuration.icon)
                    .font(.system(size: 55, weight: .medium))
                    .foregroundColor(configuration.iconColor)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: AdaptiveSpacing.padding(12)) {
            Text(configuration.title)
                .font(.system(size: AdaptiveTypography.title(), weight: .semibold))
                .foregroundColor(ColorPalette.Text.primary)
                .multilineTextAlignment(.center)
            
            Text(configuration.description)
                .font(.system(size: AdaptiveTypography.body()))
                .foregroundColor(ColorPalette.Text.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 300)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: AdaptiveSpacing.padding(12)) {
            if let actionTitle = configuration.actionTitle, let primaryAction = primaryAction {
                PrimaryButton(
                    actionTitle,
                    icon: "plus",
                    action: primaryAction
                )
                .frame(maxWidth: 200)
            }
            
            if let secondaryActionTitle = configuration.secondaryActionTitle,
               let secondaryAction = secondaryAction {
                TertiaryButton(
                    secondaryActionTitle,
                    action: secondaryAction
                )
                .frame(maxWidth: 200)
            }
        }
    }
    
    // MARK: - Animation
    private func startAnimation() {
        switch configuration.animation {
        case .none:
            break
        case .bounce:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        case .pulse:
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        case .float:
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        case .rotate:
            withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Animation Modifier
struct AnimationModifier: ViewModifier {
    let animation: EmptyStateConfiguration.EmptyStateAnimation
    @Binding var isAnimating: Bool
    
    func body(content: Content) -> some View {
        switch animation {
        case .none:
            content
        case .bounce:
            content
                .scaleEffect(isAnimating ? 1.1 : 1.0)
        case .pulse:
            content
                .scaleEffect(isAnimating ? 1.05 : 0.95)
        case .float:
            content
                .offset(y: isAnimating ? -10 : 10)
        case .rotate:
            content
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
        }
    }
}

// MARK: - Predefined Empty States
extension EmptyStateConfiguration {
    
    // MARK: - Habits
    static let noHabits = EmptyStateConfiguration(
        icon: "repeat.circle",
        title: "Нет активных привычек",
        description: "Создайте свою первую привычку и начните путь к лучшей версии себя!",
        actionTitle: "Создать привычку",
        iconColor: ColorPalette.Habits.health,
        animation: .pulse
    )
    
    static let habitsCompleted = EmptyStateConfiguration(
        icon: "checkmark.circle.fill",
        title: "Все привычки выполнены!",
        description: "Отличная работа! Все ваши привычки на сегодня выполнены.",
        iconColor: ColorPalette.Semantic.success,
        style: .illustration,
        animation: .bounce
    )
    
    // MARK: - Tasks
    static let noTasks = EmptyStateConfiguration(
        icon: "checklist",
        title: "Список задач пуст",
        description: "Добавьте первую задачу, чтобы начать планировать свой день эффективно.",
        actionTitle: "Добавить задачу",
        iconColor: ColorPalette.Secondary.main,
        animation: .float
    )
    
    static let tasksCompleted = EmptyStateConfiguration(
        icon: "checkmark.circle.fill",
        title: "Все задачи выполнены!",
        description: "Поздравляем! Вы справились со всеми задачами на сегодня.",
        secondaryActionTitle: "Добавить ещё",
        iconColor: ColorPalette.Semantic.success,
        style: .illustration,
        animation: .pulse
    )
    
    // MARK: - Goals
    static let noGoals = EmptyStateConfiguration(
        icon: "target",
        title: "Нет активных целей",
        description: "Поставьте первую цель и начните движение к своим мечтам!",
        actionTitle: "Создать цель",
        iconColor: ColorPalette.Primary.main,
        animation: .float
    )
    
    // MARK: - Finance
    static let noTransactions = EmptyStateConfiguration(
        icon: "creditcard",
        title: "Нет транзакций",
        description: "Начните отслеживать свои доходы и расходы для лучшего контроля финансов.",
        actionTitle: "Добавить транзакцию",
        iconColor: ColorPalette.Financial.income,
        animation: .pulse
    )
    
    static let noBudget = EmptyStateConfiguration(
        icon: "chart.pie",
        title: "Бюджет не настроен",
        description: "Создайте бюджет, чтобы планировать и контролировать свои расходы.",
        actionTitle: "Создать бюджет",
        iconColor: ColorPalette.Financial.savings,
        animation: .rotate
    )
    
    // MARK: - Search & Filters
    static let noSearchResults = EmptyStateConfiguration(
        icon: "magnifyingglass",
        title: "Ничего не найдено",
        description: "Попробуйте изменить запрос или очистить фильтры для поиска.",
        secondaryActionTitle: "Очистить фильтры",
        iconColor: ColorPalette.Text.secondary,
        style: .minimal,
        animation: .none
    )
    
    static let noFilterResults = EmptyStateConfiguration(
        icon: "line.3.horizontal.decrease.circle",
        title: "Нет результатов",
        description: "По выбранным фильтрам ничего не найдено. Попробуйте расширить критерии поиска.",
        secondaryActionTitle: "Сбросить фильтры",
        iconColor: ColorPalette.Text.secondary,
        style: .minimal,
        animation: .none
    )
    
    // MARK: - Network & Loading
    static let networkError = EmptyStateConfiguration(
        icon: "wifi.slash",
        title: "Нет подключения",
        description: "Проверьте интернет-соединение и попробуйте снова.",
        actionTitle: "Повторить",
        iconColor: ColorPalette.Semantic.error,
        style: .detailed,
        animation: .none
    )
    
    static let loadingError = EmptyStateConfiguration(
        icon: "exclamationmark.triangle",
        title: "Ошибка загрузки",
        description: "Что-то пошло не так. Попробуйте обновить данные.",
        actionTitle: "Обновить",
        secondaryActionTitle: "Сообщить о проблеме",
        iconColor: ColorPalette.Semantic.warning,
        animation: .none
    )
    
    // MARK: - Permissions
    static let notificationsDisabled = EmptyStateConfiguration(
        icon: "bell.slash",
        title: "Уведомления отключены",
        description: "Включите уведомления в настройках, чтобы не пропускать важные напоминания.",
        actionTitle: "Включить уведомления",
        iconColor: ColorPalette.Semantic.warning,
        animation: .none
    )
}

// MARK: - Specialized Empty State Views
struct HabitsEmptyState: View {
    let onCreateHabit: () -> Void
    
    var body: some View {
        EmptyStateView(
            configuration: .noHabits,
            primaryAction: onCreateHabit
        )
    }
}

struct TasksEmptyState: View {
    let onCreateTask: () -> Void
    let onViewCompleted: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: .noTasks,
            primaryAction: onCreateTask,
            secondaryAction: onViewCompleted
        )
    }
}

struct SearchEmptyState: View {
    let searchQuery: String
    let onClearFilters: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                icon: "magnifyingglass",
                title: "Нет результатов для \"\(searchQuery)\"",
                description: "Попробуйте другой запрос или проверьте правильность написания.",
                secondaryActionTitle: onClearFilters != nil ? "Очистить фильтры" : nil,
                iconColor: ColorPalette.Text.secondary,
                style: .minimal,
                animation: .none
            ),
            secondaryAction: onClearFilters
        )
    }
}

struct PermissionEmptyState: View {
    let permissionType: PermissionType
    let onRequestPermission: () -> Void
    
    enum PermissionType {
        case notifications
        case camera
        case location
        
        var configuration: EmptyStateConfiguration {
            switch self {
            case .notifications:
                return .notificationsDisabled
            case .camera:
                return EmptyStateConfiguration(
                    icon: "camera.fill",
                    title: "Нужен доступ к камере",
                    description: "Разрешите доступ к камере для сканирования QR-кодов и создания фото.",
                    actionTitle: "Разрешить доступ",
                    iconColor: ColorPalette.Primary.main
                )
            case .location:
                return EmptyStateConfiguration(
                    icon: "location.fill",
                    title: "Нужен доступ к геолокации",
                    description: "Разрешите доступ к геолокации для функций, привязанных к местоположению.",
                    actionTitle: "Разрешить доступ",
                    iconColor: ColorPalette.Primary.main
                )
            }
        }
    }
    
    var body: some View {
        EmptyStateView(
            configuration: permissionType.configuration,
            primaryAction: onRequestPermission
        )
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let error: Error
    let onRetry: () -> Void
    let onReport: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                icon: "exclamationmark.triangle.fill",
                title: "Произошла ошибка",
                description: error.localizedDescription,
                actionTitle: "Повторить",
                secondaryActionTitle: onReport != nil ? "Сообщить о проблеме" : nil,
                iconColor: ColorPalette.Semantic.error,
                animation: .none
            ),
            primaryAction: onRetry,
            secondaryAction: onReport
        )
    }
}

// MARK: - Success State View  
struct SuccessStateView: View {
    let title: String
    let message: String
    let actionTitle: String?
    let onAction: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                icon: "checkmark.circle.fill",
                title: title,
                description: message,
                actionTitle: actionTitle,
                iconColor: ColorPalette.Semantic.success,
                style: .illustration,
                animation: .bounce
            ),
            primaryAction: onAction
        )
    }
}

// MARK: - Preview
#Preview("Empty States") {
    TabView {
        // Habits Empty
        HabitsEmptyState {
            print("Create habit tapped")
        }
        .tabItem {
            Label("No Habits", systemImage: "repeat.circle")
        }
        
        // Tasks Completed
        EmptyStateView(configuration: .tasksCompleted)
        .tabItem {
            Label("Tasks Done", systemImage: "checkmark.circle")
        }
        
        // No Search Results
        SearchEmptyState(searchQuery: "test", onClearFilters: {
            print("Clear filters")
        })
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
        
        // Network Error
        EmptyStateView(
            configuration: .networkError,
            primaryAction: {
                print("Retry tapped")
            }
        )
        .tabItem {
            Label("Error", systemImage: "wifi.slash")
        }
        
        // Permission
        PermissionEmptyState(
            permissionType: .notifications,
            onRequestPermission: {
                print("Request permission")
            }
        )
        .tabItem {
            Label("Permission", systemImage: "bell.slash")
        }
    }
    .adaptivePreviews()
} 