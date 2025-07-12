//
//  ContentView.swift
//  IWBB
//
//  Created by AI Assistant
//  Десктопная навигационная структура приложения для macOS
//

import SwiftUI

// MARK: - Main Content View (Desktop)
struct ContentView: View {
    
    // MARK: - State
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar (левая панель)
            SidebarView(selectedItem: $selectedSidebarItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // Detail View (основной контент)
            DetailView(selectedItem: selectedSidebarItem)
        }
        .navigationTitle("IWBB")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                MacOSToolbarView()
            }
        }
    }
}

// MARK: - Sidebar Navigation Items
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "dashboard"
    case habits = "habits"
    case tasks = "tasks"
    case goals = "goals"
    case finance = "finance"
    case analytics = "analytics"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Обзор"
        case .habits: return "Привычки"
        case .tasks: return "Задачи"
        case .goals: return "Цели"
        case .finance: return "Финансы"
        case .analytics: return "Аналитика"
        case .settings: return "Настройки"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .habits: return "repeat.circle"
        case .tasks: return "checkmark.circle"
        case .goals: return "target"
        case .finance: return "dollarsign.circle"
        case .analytics: return "chart.bar"
        case .settings: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .dashboard: return .blue
        case .habits: return .green
        case .tasks: return .orange
        case .goals: return .purple
        case .finance: return .mint
        case .analytics: return .pink
        case .settings: return .gray
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок приложения
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("IWBB")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Поиск
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Поиск", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Основная навигация
            List(selection: $selectedItem) {
                Section("Главное") {
                    ForEach([SidebarItem.dashboard, .habits, .tasks, .goals], id: \.self) { item in
                        SidebarRow(item: item)
                            .tag(item)
                    }
                }
                
                Section("Финансы") {
                    SidebarRow(item: .finance)
                        .tag(SidebarItem.finance)
                    
                    SidebarRow(item: .analytics)
                        .tag(SidebarItem.analytics)
                }
                
                Section("Другое") {
                    SidebarRow(item: .settings)
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            // Нижняя панель с информацией
            VStack(spacing: 8) {
                Divider()
                
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Синхронизация")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Обновлено")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Sidebar Row
struct SidebarRow: View {
    let item: SidebarItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(item.color)
                .frame(width: 20, height: 20)
            
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail View
struct DetailView: View {
    let selectedItem: SidebarItem?
    
    var body: some View {
        Group {
            if let item = selectedItem {
                switch item {
                case .dashboard:
                    DesktopDashboardView()
                case .habits:
                    DesktopHabitsView()
                case .tasks:
                    DesktopTasksView()
                case .goals:
                    DesktopGoalsView()
                case .finance:
                    DesktopFinanceView()
                case .analytics:
                    DesktopAnalyticsView()
                case .settings:
                    DesktopSettingsView()
                }
            } else {
                WelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - macOS Toolbar
struct MacOSToolbarView: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "plus")
            }
            .help("Создать новый элемент")
            
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Экспорт данных")
            
            Button(action: {}) {
                Image(systemName: "cloud.fill")
            }
            .help("Синхронизация")
            
            Button(action: {}) {
                Image(systemName: "bell")
            }
            .help("Уведомления")
        }
    }
}

// MARK: - Desktop Views (Адаптированные для macOS)

struct DesktopDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Заголовок
                HStack {
                    Text("Обзор")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("Сегодня, \(Date().formatted(.dateTime.weekday(.wide).month().day()))")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Статистика в сетке
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                    StatsCard(title: "Привычки", value: "5/8", subtitle: "выполнено сегодня", color: .green, icon: "repeat.circle")
                    StatsCard(title: "Задачи", value: "12", subtitle: "активных", color: .blue, icon: "checkmark.circle")
                    StatsCard(title: "Цели", value: "3", subtitle: "в процессе", color: .purple, icon: "target")
                    StatsCard(title: "Баланс", value: "₽125,000", subtitle: "текущий", color: .mint, icon: "dollarsign.circle")
                }
                .padding(.horizontal)
                
                // Последние активности
                VStack(alignment: .leading, spacing: 12) {
                    Text("Последние активности")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ActivityRow(title: "Выполнена привычка: Пить воду", time: "2 мин назад", icon: "drop.fill", color: .blue)
                        ActivityRow(title: "Добавлена задача: Закончить проект", time: "15 мин назад", icon: "plus.circle", color: .orange)
                        ActivityRow(title: "Потрачено: ₽3,500 на продукты", time: "1 час назад", icon: "minus.circle", color: .red)
                        ActivityRow(title: "Достигнута цель: Прочитать 10 книг", time: "2 часа назад", icon: "trophy.fill", color: .yellow)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
        }
        .padding(.vertical)
    }
}

struct DesktopHabitsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Заголовок
            HStack {
                Text("Привычки")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Добавить привычку") {
                    // Действие добавления
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Фильтры
            HStack {
                Button("Все") {}
                    .buttonStyle(.bordered)
                
                Button("Активные") {}
                    .buttonStyle(.bordered)
                
                Button("Завершенные") {}
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Menu("Сортировка") {
                    Button("По названию") {}
                    Button("По дате создания") {}
                    Button("По прогрессу") {}
                }
                .menuStyle(.borderedButton)
            }
            .padding(.horizontal)
            
            // Список привычек
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<10) { index in
                        HabitCard(
                            title: "Привычка \(index + 1)",
                            description: "Описание привычки",
                            progress: Double.random(in: 0.2...1.0),
                            streak: Int.random(in: 1...30)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct DesktopTasksView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Задачи")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Добавить задачу") {
                    // Действие добавления
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Список задач
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(0..<15) { index in
                        TaskRow(
                            title: "Задача \(index + 1)",
                            description: "Описание задачи",
                            isCompleted: index % 3 == 0,
                            priority: TaskPriority.allCases.randomElement() ?? .medium
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct DesktopGoalsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Цели")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Добавить цель") {
                    // Действие добавления
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Сетка целей
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(0..<6) { index in
                        GoalCard(
                            title: "Цель \(index + 1)",
                            description: "Описание цели",
                            progress: Double.random(in: 0.1...0.9),
                            deadline: Date().addingTimeInterval(TimeInterval.random(in: 86400...2592000))
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct DesktopFinanceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Финансы")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Добавить транзакцию") {
                    // Действие добавления
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            // Баланс карточка
            VStack(alignment: .leading, spacing: 16) {
                Text("Общий баланс")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("₽125,000")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack {
                    Text("↗")
                        .foregroundColor(.green)
                    Text("+₽5,000")
                        .foregroundColor(.green)
                    Text("за месяц")
                        .foregroundColor(.secondary)
                }
                .font(.headline)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Транзакции
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(0..<20) { index in
                        TransactionRow(
                            title: "Транзакция \(index + 1)",
                            amount: index % 2 == 0 ? "+₽\(Int.random(in: 1000...50000))" : "-₽\(Int.random(in: 100...5000))",
                            date: Date().addingTimeInterval(-TimeInterval.random(in: 0...2592000))
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct DesktopAnalyticsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Аналитика")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    AnalyticsCard(title: "Прогресс привычек", value: "85%", chart: "chart.line.uptrend.xyaxis")
                    AnalyticsCard(title: "Выполнение задач", value: "12/15", chart: "chart.pie")
                    AnalyticsCard(title: "Достижение целей", value: "3/5", chart: "chart.bar")
                    AnalyticsCard(title: "Финансовый рост", value: "+15%", chart: "chart.line.uptrend.xyaxis")
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct DesktopSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Настройки")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGroup(title: "Общие") {
                        SettingsRow(title: "Тема", value: "Системная")
                        SettingsRow(title: "Язык", value: "Русский")
                        SettingsRow(title: "Уведомления", value: "Включены")
                    }
                    
                    SettingsGroup(title: "Синхронизация") {
                        SettingsRow(title: "iCloud", value: "Включено")
                        SettingsRow(title: "Автосинхронизация", value: "Включена")
                    }
                    
                    SettingsGroup(title: "Данные") {
                        SettingsRow(title: "Экспорт данных", value: "")
                        SettingsRow(title: "Импорт данных", value: "")
                        SettingsRow(title: "Сброс данных", value: "")
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Добро пожаловать в IWBB")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Выберите раздел в боковой панели для начала работы")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Components
struct StatsCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ActivityRow: View {
    let title: String
    let time: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct HabitCard: View {
    let title: String
    let description: String
    let progress: Double
    let streak: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Серия: \(streak) дней")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            ProgressView(value: progress)
                .progressViewStyle(CircularProgressViewStyle())
                .frame(width: 30, height: 30)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(10)
    }
}

struct TaskRow: View {
    let title: String
    let description: String
    let isCompleted: Bool
    let priority: TaskPriority
    
    var body: some View {
        HStack {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .strikethrough(isCompleted)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            TaskPriorityBadge(priority: priority)
        }
        .padding(.vertical, 4)
    }
}

struct GoalCard: View {
    let title: String
    let description: String
    let progress: Double
    let deadline: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .lineLimit(2)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            HStack {
                Text("Прогресс: \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(deadline.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct TransactionRow: View {
    let title: String
    let amount: String
    let date: Date
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(date.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(amount)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(amount.hasPrefix("+") ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let chart: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: chart)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: 4) {
                content
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Supporting Types
enum TaskPriority: String, CaseIterable {
    case low = "Низкий"
    case medium = "Средний"
    case high = "Высокий"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

struct TaskPriorityBadge: View {
    let priority: TaskPriority
    
    var body: some View {
        Text(priority.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.color.opacity(0.2))
            .foregroundColor(priority.color)
            .cornerRadius(6)
    }
}

// MARK: - TabItem для совместимости
enum TabItem: String, CaseIterable {
    case dashboard = "dashboard"
    case habits = "habits"
    case tasks = "tasks"
    case finance = "finance"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .dashboard: return "Обзор"
        case .habits: return "Привычки"
        case .tasks: return "Задачи"
        case .finance: return "Финансы"
        case .settings: return "Настройки"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .habits: return "repeat.circle"
        case .tasks: return "checkmark.circle"
        case .finance: return "dollarsign.circle"
        case .settings: return "gear"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .habits: return "repeat.circle.fill"
        case .tasks: return "checkmark.circle.fill"
        case .finance: return "dollarsign.circle.fill"
        case .settings: return "gear.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
} 