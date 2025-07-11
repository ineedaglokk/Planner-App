//
//  ContentView.swift
//  IWBB
//
//  Created by AI Assistant
//  Основная навигационная структура приложения
//

import SwiftUI

struct ContentView: View {
    
    // MARK: - Navigation State
    @State private var navigationManager = NavigationManager.shared
    @State private var selectedTab: TabItem = .dashboard
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            NavigationStack(path: $navigationManager.dashboardPath) {
                DashboardView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(TabItem.dashboard.title, systemImage: selectedTab == .dashboard ? TabItem.dashboard.selectedIcon : TabItem.dashboard.icon)
            }
            .tag(TabItem.dashboard)
            
            // Habits Tab
            NavigationStack(path: $navigationManager.habitsPath) {
                HabitsListView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(TabItem.habits.title, systemImage: selectedTab == .habits ? TabItem.habits.selectedIcon : TabItem.habits.icon)
            }
            .tag(TabItem.habits)
            
            // Tasks & Goals Tab
            NavigationStack(path: $navigationManager.tasksPath) {
                TasksAndGoalsView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(TabItem.tasks.title, systemImage: selectedTab == .tasks ? TabItem.tasks.selectedIcon : TabItem.tasks.icon)
            }
            .tag(TabItem.tasks)
            
            // Finance Tab
            NavigationStack(path: $navigationManager.financePath) {
                FinanceTabView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(TabItem.finance.title, systemImage: selectedTab == .finance ? TabItem.finance.selectedIcon : TabItem.finance.icon)
            }
            .tag(TabItem.finance)
            
            // Profile & Settings Tab
            NavigationStack(path: $navigationManager.settingsPath) {
                ProfileAndSettingsView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem {
                Label(TabItem.settings.title, systemImage: selectedTab == .settings ? TabItem.settings.selectedIcon : TabItem.settings.icon)
            }
            .tag(TabItem.settings)
        }
        .onChange(of: selectedTab) { _, newValue in
            navigationManager.selectedTab = newValue
        }
        .accentColor(ColorPalette.Primary.main)
        .environment(navigationManager)
    }
    
    // MARK: - Navigation Destination Builder
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        // Habits
        case .habitDetail(let id):
            HabitDetailView(habitID: id)
        case .createHabit:
            CreateHabitView()
        case .editHabit(let id):
            EditHabitView(habitID: id)
        case .habitStatistics(let id):
            HabitStatisticsView(habitID: id)
            
        // Tasks
        case .taskDetail(let id):
            TaskDetailView(taskID: id)
        case .createTask:
            CreateTaskView()
        case .editTask(let id):
            EditTaskView(taskID: id)
        case .projectView(let id):
            ProjectView(projectID: id)
            
        // Goals
        case .goalDetail(let id):
            GoalDetailView(goalID: id)
        case .createGoal:
            CreateGoalView()
        case .editGoal(let id):
            EditGoalView(goalID: id)
            
        // Finance
        case .transactionDetail(let id):
            TransactionDetailView(transactionID: id)
        case .addTransaction:
            AddTransactionView()
        case .editTransaction(let id):
            EditTransactionView(transactionID: id)
        case .budgetManagement:
            BudgetManagementView()
        case .financialReports:
            FinancialReportsView()
            
        // Settings
        case .profileSettings:
            ProfileSettingsView()
        case .notificationSettings:
            NotificationSettingsView()
        case .dataExport:
            DataExportView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - Placeholder Views (временные заглушки)
struct DashboardView: View {
    var body: some View {
        VStack {
            Text("Дашборд")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Здесь будет обзор всех данных")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Обзор")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct HabitsListView: View {
    var body: some View {
        VStack {
            Text("Привычки")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Список ваших привычек")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Привычки")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct TasksAndGoalsView: View {
    var body: some View {
        VStack {
            Text("Задачи и Цели")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Управление задачами и целями")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Задачи и Цели")
        .navigationBarTitleDisplayMode(.large)
    }
}

// FinanceView теперь используется как FinanceTabView

struct ProfileAndSettingsView: View {
    var body: some View {
        VStack {
            Text("Профиль и Настройки")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Настройки приложения")
                .foregroundColor(.secondary)
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Detail View Placeholders
struct HabitDetailView: View {
    let habitID: String
    var body: some View {
        Text("Детали привычки \(habitID)")
    }
}

struct CreateHabitView: View {
    var body: some View {
        Text("Создание новой привычки")
    }
}

struct EditHabitView: View {
    let habitID: String
    var body: some View {
        Text("Редактирование привычки \(habitID)")
    }
}

struct HabitStatisticsView: View {
    let habitID: String
    var body: some View {
        Text("Статистика привычки \(habitID)")
    }
}

struct TaskDetailView: View {
    let taskID: String
    var body: some View {
        Text("Детали задачи \(taskID)")
    }
}

struct CreateTaskView: View {
    var body: some View {
        Text("Создание новой задачи")
    }
}

struct EditTaskView: View {
    let taskID: String
    var body: some View {
        Text("Редактирование задачи \(taskID)")
    }
}

struct ProjectView: View {
    let projectID: String
    var body: some View {
        Text("Проект \(projectID)")
    }
}

struct GoalDetailView: View {
    let goalID: String
    var body: some View {
        Text("Детали цели \(goalID)")
    }
}

struct CreateGoalView: View {
    var body: some View {
        Text("Создание новой цели")
    }
}

struct EditGoalView: View {
    let goalID: String
    var body: some View {
        Text("Редактирование цели \(goalID)")
    }
}

struct TransactionDetailView: View {
    let transactionID: String
    var body: some View {
        Text("Детали транзакции \(transactionID)")
    }
}

struct AddTransactionView: View {
    var body: some View {
        Text("Добавление транзакции")
    }
}

struct EditTransactionView: View {
    let transactionID: String
    var body: some View {
        Text("Редактирование транзакции \(transactionID)")
    }
}

struct BudgetManagementView: View {
    var body: some View {
        Text("Управление бюджетом")
    }
}

struct FinancialReportsView: View {
    var body: some View {
        Text("Финансовые отчеты")
    }
}

struct ProfileSettingsView: View {
    var body: some View {
        Text("Настройки профиля")
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        Text("Настройки уведомлений")
    }
}

struct DataExportView: View {
    var body: some View {
        Text("Экспорт данных")
    }
}

struct AboutView: View {
    var body: some View {
        Text("О приложении")
    }
}

#Preview {
    ContentView()
        .environment(NavigationManager.shared)
} 