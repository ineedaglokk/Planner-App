//
//  AppNavigation.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Навигационная система приложения
//

import SwiftUI

// MARK: - Tab Items
enum TabItem: String, CaseIterable {
    case dashboard = "dashboard"
    case habits = "habits"
    case tasks = "tasks"
    case finance = "finance"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .dashboard:
            return "Обзор"
        case .habits:
            return "Привычки"
        case .tasks:
            return "Задачи"
        case .finance:
            return "Финансы"
        case .settings:
            return "Настройки"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard:
            return "chart.line.uptrend.xyaxis"
        case .habits:
            return "repeat.circle"
        case .tasks:
            return "checkmark.circle"
        case .finance:
            return "dollarsign.circle"
        case .settings:
            return "gearshape"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .dashboard:
            return "chart.line.uptrend.xyaxis"
        case .habits:
            return "repeat.circle.fill"
        case .tasks:
            return "checkmark.circle.fill"
        case .finance:
            return "dollarsign.circle.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .dashboard:
            return ColorPalette.Primary.main
        case .habits:
            return ColorPalette.Habits.health
        case .tasks:
            return ColorPalette.Secondary.main
        case .finance:
            return ColorPalette.Financial.income
        case .settings:
            return ColorPalette.Text.secondary
        }
    }
}

// MARK: - Navigation Destinations
enum NavigationDestination: Hashable {
    // Habits
    case habitDetail(String) // Habit ID
    case createHabit
    case editHabit(String)
    case habitStatistics(String)
    
    // Tasks
    case taskDetail(String) // Task ID
    case createTask
    case editTask(String)
    case projectView(String)
    
    // Goals
    case goalDetail(String) // Goal ID
    case createGoal
    case editGoal(String)
    
    // Finance
    case transactionDetail(String) // Transaction ID
    case addTransaction
    case editTransaction(String)
    case budgetManagement
    case financialReports
    
    // Settings
    case profileSettings
    case notificationSettings
    case dataExport
    case about
    
    var title: String {
        switch self {
        case .habitDetail:
            return "Детали привычки"
        case .createHabit:
            return "Новая привычка"
        case .editHabit:
            return "Редактировать привычку"
        case .habitStatistics:
            return "Статистика привычки"
        case .taskDetail:
            return "Детали задачи"
        case .createTask:
            return "Новая задача"
        case .editTask:
            return "Редактировать задачу"
        case .projectView:
            return "Проект"
        case .goalDetail:
            return "Детали цели"
        case .createGoal:
            return "Новая цель"
        case .editGoal:
            return "Редактировать цель"
        case .transactionDetail:
            return "Детали транзакции"
        case .addTransaction:
            return "Добавить транзакцию"
        case .editTransaction:
            return "Редактировать транзакцию"
        case .budgetManagement:
            return "Управление бюджетом"
        case .financialReports:
            return "Финансовые отчеты"
        case .profileSettings:
            return "Профиль"
        case .notificationSettings:
            return "Уведомления"
        case .dataExport:
            return "Экспорт данных"
        case .about:
            return "О приложении"
        }
    }
}

// MARK: - Navigation Manager
@Observable
final class NavigationManager {
    
    // MARK: - Properties
    var selectedTab: TabItem = .dashboard
    var dashboardPath = NavigationPath()
    var habitsPath = NavigationPath()
    var tasksPath = NavigationPath()
    var financePath = NavigationPath()
    var settingsPath = NavigationPath()
    
    // MARK: - Singleton
    static let shared = NavigationManager()
    
    private init() {}
    
    // MARK: - Navigation Methods
    func navigate(to destination: NavigationDestination, in tab: TabItem) {
        selectedTab = tab
        
        switch tab {
        case .dashboard:
            dashboardPath.append(destination)
        case .habits:
            habitsPath.append(destination)
        case .tasks:
            tasksPath.append(destination)
        case .finance:
            financePath.append(destination)
        case .settings:
            settingsPath.append(destination)
        }
    }
    
    func popToRoot(in tab: TabItem) {
        switch tab {
        case .dashboard:
            dashboardPath = NavigationPath()
        case .habits:
            habitsPath = NavigationPath()
        case .tasks:
            tasksPath = NavigationPath()
        case .finance:
            financePath = NavigationPath()
        case .settings:
            settingsPath = NavigationPath()
        }
    }
    
    func popLast(in tab: TabItem) {
        switch tab {
        case .dashboard:
            if !dashboardPath.isEmpty { dashboardPath.removeLast() }
        case .habits:
            if !habitsPath.isEmpty { habitsPath.removeLast() }
        case .tasks:
            if !tasksPath.isEmpty { tasksPath.removeLast() }
        case .finance:
            if !financePath.isEmpty { financePath.removeLast() }
        case .settings:
            if !settingsPath.isEmpty { settingsPath.removeLast() }
        }
    }
    
    // MARK: - Deep Link Handling
    func handleDeepLink(_ url: URL) {
        // Пример: planner://habits/create
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let path = components?.path else { return }
        
        let pathComponents = path.split(separator: "/").map(String.init)
        
        switch pathComponents.first {
        case "habits":
            handleHabitsDeepLink(pathComponents)
        case "tasks":
            handleTasksDeepLink(pathComponents)
        case "finance":
            handleFinanceDeepLink(pathComponents)
        default:
            break
        }
    }
    
    private func handleHabitsDeepLink(_ components: [String]) {
        if components.count > 1 {
            switch components[1] {
            case "create":
                navigate(to: .createHabit, in: .habits)
            case "detail":
                if components.count > 2 {
                    navigate(to: .habitDetail(components[2]), in: .habits)
                }
            default:
                selectedTab = .habits
            }
        } else {
            selectedTab = .habits
        }
    }
    
    private func handleTasksDeepLink(_ components: [String]) {
        if components.count > 1 {
            switch components[1] {
            case "create":
                navigate(to: .createTask, in: .tasks)
            case "detail":
                if components.count > 2 {
                    navigate(to: .taskDetail(components[2]), in: .tasks)
                }
            default:
                selectedTab = .tasks
            }
        } else {
            selectedTab = .tasks
        }
    }
    
    private func handleFinanceDeepLink(_ components: [String]) {
        if components.count > 1 {
            switch components[1] {
            case "add":
                navigate(to: .addTransaction, in: .finance)
            case "budget":
                navigate(to: .budgetManagement, in: .finance)
            default:
                selectedTab = .finance
            }
        } else {
            selectedTab = .finance
        }
    }
}

// MARK: - Tab Bar View
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
        .background(
            Rectangle()
                .fill(ColorPalette.Background.surface)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: -2
                )
        )
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: IconSize.tabBar, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? tab.color : ColorPalette.Text.tertiary)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                Text(tab.title)
                    .font(Typography.Caption.small)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? tab.color : ColorPalette.Text.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(isSelected ? tab.color.opacity(0.1) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Navigation Bar Style
struct CustomNavigationBar: ViewModifier {
    let title: String
    let leadingAction: (() -> Void)?
    let trailingAction: (() -> Void)?
    let leadingIcon: String?
    let trailingIcon: String?
    
    init(
        title: String,
        leadingAction: (() -> Void)? = nil,
        trailingAction: (() -> Void)? = nil,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil
    ) {
        self.title = title
        self.leadingAction = leadingAction
        self.trailingAction = trailingAction
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
    }
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let leadingAction = leadingAction, let leadingIcon = leadingIcon {
                    ToolbarItem(placement: .navigationBarLeading) {
                        IconButton(icon: leadingIcon, style: .tertiary, action: leadingAction)
                    }
                }
                
                if let trailingAction = trailingAction, let trailingIcon = trailingIcon {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        IconButton(icon: trailingIcon, style: .tertiary, action: trailingAction)
                    }
                }
            }
    }
}

extension View {
    func customNavigationBar(
        title: String,
        leadingAction: (() -> Void)? = nil,
        trailingAction: (() -> Void)? = nil,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil
    ) -> some View {
        self.modifier(CustomNavigationBar(
            title: title,
            leadingAction: leadingAction,
            trailingAction: trailingAction,
            leadingIcon: leadingIcon,
            trailingIcon: trailingIcon
        ))
    }
}

// MARK: - Main App Navigation
struct AppNavigationView: View {
    @State private var navigationManager = NavigationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            Group {
                switch navigationManager.selectedTab {
                case .dashboard:
                    NavigationStack(path: $navigationManager.dashboardPath) {
                        DashboardTabView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                    
                case .habits:
                    NavigationStack(path: $navigationManager.habitsPath) {
                        HabitsTabView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                    
                case .tasks:
                    NavigationStack(path: $navigationManager.tasksPath) {
                        TasksTabView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                    
                case .finance:
                    NavigationStack(path: $navigationManager.financePath) {
                        FinanceTabView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                    
                case .settings:
                    NavigationStack(path: $navigationManager.settingsPath) {
                        SettingsTabView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                destinationView(for: destination)
                            }
                    }
                }
            }
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $navigationManager.selectedTab)
        }
        .background(ColorPalette.Background.primary)
        .onOpenURL { url in
            navigationManager.handleDeepLink(url)
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        // Habits
        case .habitDetail(let id):
            Text("Habit Detail: \(id)")
                .customNavigationBar(title: destination.title)
        case .createHabit:
            Text("Create Habit")
                .customNavigationBar(title: destination.title)
        case .editHabit(let id):
            Text("Edit Habit: \(id)")
                .customNavigationBar(title: destination.title)
        case .habitStatistics(let id):
            Text("Habit Statistics: \(id)")
                .customNavigationBar(title: destination.title)
            
        // Tasks
        case .taskDetail(let id):
            Text("Task Detail: \(id)")
                .customNavigationBar(title: destination.title)
        case .createTask:
            Text("Create Task")
                .customNavigationBar(title: destination.title)
        case .editTask(let id):
            Text("Edit Task: \(id)")
                .customNavigationBar(title: destination.title)
        case .projectView(let id):
            Text("Project View: \(id)")
                .customNavigationBar(title: destination.title)
            
        // Goals
        case .goalDetail(let id):
            Text("Goal Detail: \(id)")
                .customNavigationBar(title: destination.title)
        case .createGoal:
            Text("Create Goal")
                .customNavigationBar(title: destination.title)
        case .editGoal(let id):
            Text("Edit Goal: \(id)")
                .customNavigationBar(title: destination.title)
            
        // Finance
        case .transactionDetail(let id):
            Text("Transaction Detail: \(id)")
                .customNavigationBar(title: destination.title)
        case .addTransaction:
            Text("Add Transaction")
                .customNavigationBar(title: destination.title)
        case .editTransaction(let id):
            Text("Edit Transaction: \(id)")
                .customNavigationBar(title: destination.title)
        case .budgetManagement:
            Text("Budget Management")
                .customNavigationBar(title: destination.title)
        case .financialReports:
            Text("Financial Reports")
                .customNavigationBar(title: destination.title)
            
        // Settings
        case .profileSettings:
            Text("Profile Settings")
                .customNavigationBar(title: destination.title)
        case .notificationSettings:
            Text("Notification Settings")
                .customNavigationBar(title: destination.title)
        case .dataExport:
            Text("Data Export")
                .customNavigationBar(title: destination.title)
        case .about:
            Text("About")
                .customNavigationBar(title: destination.title)
        }
    }
}

// MARK: - Tab Views (Placeholder)
struct DashboardTabView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                Text("Dashboard Content")
                    .font(Typography.Headline.large)
                
                // Example navigation
                ActionCard(
                    title: "Создать привычку",
                    description: "Перейти к созданию новой привычки",
                    icon: "plus.circle"
                ) {
                    NavigationManager.shared.navigate(to: .createHabit, in: .habits)
                }
                
                ActionCard(
                    title: "Добавить задачу",
                    description: "Создать новую задачу",
                    icon: "note.text.badge.plus"
                ) {
                    NavigationManager.shared.navigate(to: .createTask, in: .tasks)
                }
            }
            .screenPadding()
        }
        .customNavigationBar(
            title: "Обзор",
            trailingAction: {
                print("Settings tapped")
            },
            trailingIcon: "gearshape"
        )
    }
}

struct HabitsTabView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                Text("Habits Content")
                    .font(Typography.Headline.large)
                
                InfoCard(
                    title: "Медитация",
                    subtitle: "Ежедневная практика",
                    icon: "heart.circle",
                    value: "7 дней"
                ) {
                    NavigationManager.shared.navigate(to: .habitDetail("meditation"), in: .habits)
                }
            }
            .screenPadding()
        }
        .customNavigationBar(
            title: "Привычки",
            trailingAction: {
                NavigationManager.shared.navigate(to: .createHabit, in: .habits)
            },
            trailingIcon: "plus"
        )
    }
}

struct TasksTabView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                Text("Tasks Content")
                    .font(Typography.Headline.large)
            }
            .screenPadding()
        }
        .customNavigationBar(
            title: "Задачи",
            trailingAction: {
                NavigationManager.shared.navigate(to: .createTask, in: .tasks)
            },
            trailingIcon: "plus"
        )
    }
}

struct FinanceTabView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                Text("Finance Content")
                    .font(Typography.Headline.large)
            }
            .screenPadding()
        }
        .customNavigationBar(
            title: "Финансы",
            trailingAction: {
                NavigationManager.shared.navigate(to: .addTransaction, in: .finance)
            },
            trailingIcon: "plus"
        )
    }
}

struct SettingsTabView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                Text("Settings Content")
                    .font(Typography.Headline.large)
                
                ActionCard(
                    title: "Профиль",
                    description: "Настройки профиля пользователя",
                    icon: "person.circle"
                ) {
                    NavigationManager.shared.navigate(to: .profileSettings, in: .settings)
                }
                
                ActionCard(
                    title: "Уведомления",
                    description: "Настройки уведомлений",
                    icon: "bell.circle"
                ) {
                    NavigationManager.shared.navigate(to: .notificationSettings, in: .settings)
                }
            }
            .screenPadding()
        }
        .customNavigationBar(title: "Настройки")
    }
}

// MARK: - Preview
#if DEBUG
struct NavigationPreview: View {
    var body: some View {
        AppNavigationView()
    }
}

#Preview {
    NavigationPreview()
}
#endif 