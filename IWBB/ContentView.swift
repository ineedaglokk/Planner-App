//
//  ContentView.swift
//  IWBB
//
//  Created by AI Assistant
//  Основной интерфейс приложения с навигацией
//

import SwiftUI

struct ContentView: View {
    
    // MARK: - Properties
    @State private var navigationManager = NavigationManager.shared
    @State private var themeManager = ThemeManager.shared
    
    var body: some View {
        Group {
            #if os(iOS)
            iOSContentView()
            #elseif os(macOS)
            macOSContentView()
            #endif
        }
        .environment(\.navigationManager, navigationManager)
        .environment(\.theme, themeManager.currentTheme)
        .onAppear {
            configureAppearance()
        }
    }
    
    // MARK: - iOS Content
    @ViewBuilder
    private func iOSContentView() -> some View {
        AppNavigationView()
            .onOpenURL { url in
                navigationManager.handleDeepLink(url)
            }
    }
    
    // MARK: - macOS Content  
    @ViewBuilder
    private func macOSContentView() -> some View {
        NavigationSplitView {
            // Sidebar
            macOSSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // Detail View
            macOSDetailView()
        }
        .navigationTitle("IWBB")
    }
    
    // MARK: - macOS Sidebar
    @ViewBuilder
    private func macOSSidebar() -> some View {
        List(selection: $navigationManager.selectedTab) {
            Section("Основное") {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: tab.icon)
                                .foregroundColor(tab.color)
                                .frame(width: 20)
                            
                            Text(tab.title)
                                .font(Typography.Body.medium)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - macOS Detail View
    @ViewBuilder 
    private func macOSDetailView() -> some View {
        Group {
            switch navigationManager.selectedTab {
            case .dashboard:
                DashboardTabView()
            case .habits:
                HabitsTabView()
            case .tasks:
                TasksTabView()
            case .finance:
                FinanceTabView()
            case .settings:
                SettingsTabView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // MARK: - Configuration
    private func configureAppearance() {
        // Настройка глобального внешнего вида
        #if os(iOS)
        configureTabBarAppearance()
        configureNavigationBarAppearance()
        #endif
    }
    
    #if os(iOS)
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ColorPalette.Background.surface)
        
        // Настройка цветов иконок
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(ColorPalette.Text.tertiary)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(ColorPalette.Primary.main)
        
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(ColorPalette.Text.tertiary),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(ColorPalette.Primary.main),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(ColorPalette.Background.primary)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(ColorPalette.Text.primary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(ColorPalette.Text.primary),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    #endif
}

// MARK: - Environment Keys
struct NavigationManagerKey: EnvironmentKey {
    static let defaultValue = NavigationManager.shared
}

extension EnvironmentValues {
    var navigationManager: NavigationManager {
        get { self[NavigationManagerKey.self] }
        set { self[NavigationManagerKey.self] = newValue }
    }
}

// MARK: - Dashboard Enhanced View
struct DashboardTabView: View {
    
    @State private var currentTime = Date()
    @State private var showQuickActions = false
    
    // Timer для обновления времени
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sectionSpacing) {
                
                // Приветствие и время
                greetingSection
                
                // Быстрые действия
                quickActionsSection
                
                // Сегодняшние задачи
                todayTasksSection
                
                // Статистика привычек
                habitsStatsSection
                
                // Финансовая сводка
                financeSummarySection
                
                // Достижения
                achievementsSection
            }
            .screenPadding()
        }
        .refreshable {
            // Обновление данных
            await refreshDashboardData()
        }
        .customNavigationBar(
            title: "Обзор",
            trailingAction: {
                showQuickActions.toggle()
            },
            trailingIcon: "plus.circle"
        )
        .sheet(isPresented: $showQuickActions) {
            QuickActionsSheet()
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(greetingText)
                        .font(Typography.Headline.large)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text(formatDate(currentTime))
                        .font(Typography.Body.medium)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                // Погода или настроение виджет
                weatherWidget
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Быстрые действия")
                .font(Typography.Headline.medium)
                .foregroundColor(ColorPalette.Text.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                ActionCard(
                    title: "Отметить привычку",
                    description: "Быстро отметить выполненную привычку",
                    icon: "checkmark.circle.fill",
                    color: ColorPalette.Habits.health
                ) {
                    // Quick habit check
                }
                
                ActionCard(
                    title: "Добавить задачу",
                    description: "Создать новую задачу",
                    icon: "plus.circle.fill",
                    color: ColorPalette.Secondary.main
                ) {
                    NavigationManager.shared.navigate(to: .createTask, in: .tasks)
                }
                
                ActionCard(
                    title: "Записать расход",
                    description: "Добавить новую транзакцию",
                    icon: "minus.circle.fill",
                    color: ColorPalette.Financial.expense
                ) {
                    NavigationManager.shared.navigate(to: .addTransaction, in: .finance)
                }
                
                ActionCard(
                    title: "Посмотреть цели",
                    description: "Проверить прогресс целей",
                    icon: "target",
                    color: ColorPalette.Primary.main
                ) {
                    // Goals view
                }
            }
        }
    }
    
    @ViewBuilder
    private var todayTasksSection: some View {
        InfoCard(
            title: "Задачи на сегодня",
            subtitle: "Осталось выполнить",
            icon: "checklist",
            value: "3 из 7",
            style: .elevated
        ) {
            NavigationManager.shared.selectedTab = .tasks
        }
    }
    
    @ViewBuilder
    private var habitsStatsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Привычки")
                    .font(Typography.Headline.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                
                Spacer()
                
                Button("Все") {
                    NavigationManager.shared.selectedTab = .habits
                }
                .font(Typography.Body.medium)
                .foregroundColor(ColorPalette.Primary.main)
            }
            
            HStack(spacing: Spacing.md) {
                StatisticCard(
                    title: "Выполнено сегодня",
                    value: "5/8",
                    change: "+2",
                    changeType: .positive,
                    icon: "checkmark.circle",
                    color: ColorPalette.Semantic.success
                )
                
                StatisticCard(
                    title: "Серия дней",
                    value: "12",
                    change: "+1",
                    changeType: .positive,
                    icon: "flame",
                    color: ColorPalette.Semantic.warning
                )
            }
        }
    }
    
    @ViewBuilder
    private var financeSummarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Финансы")
                    .font(Typography.Headline.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                
                Spacer()
                
                Button("Подробнее") {
                    NavigationManager.shared.selectedTab = .finance
                }
                .font(Typography.Body.medium)
                .foregroundColor(ColorPalette.Primary.main)
            }
            
            HStack(spacing: Spacing.md) {
                StatisticCard(
                    title: "Доходы",
                    value: "₽45,000",
                    change: "+8%",
                    changeType: .positive,
                    icon: "arrow.up.circle",
                    color: ColorPalette.Financial.income
                )
                
                StatisticCard(
                    title: "Расходы",
                    value: "₽32,500",
                    change: "-3%",
                    changeType: .negative,
                    icon: "arrow.down.circle",
                    color: ColorPalette.Financial.expense
                )
            }
        }
    }
    
    @ViewBuilder
    private var achievementsSection: some View {
        InfoCard(
            title: "Последние достижения",
            subtitle: "Новое достижение разблокировано!",
            icon: "trophy.fill",
            value: "🏆",
            style: .filled
        ) {
            // Achievements view
        }
    }
    
    @ViewBuilder
    private var weatherWidget: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text("22°")
                .font(Typography.Title.large)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.Text.primary)
        }
        .padding(Spacing.md)
        .background(ColorPalette.Background.surface)
        .cardCornerRadius()
        .cardShadow()
    }
    
    // MARK: - Computed Properties
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        switch hour {
        case 6..<12:
            return "Доброе утро!"
        case 12..<17:
            return "Добрый день!"
        case 17..<22:
            return "Добрый вечер!"
        default:
            return "Доброй ночи!"
        }
    }
    
    // MARK: - Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date).capitalized
    }
    
    @MainActor
    private func refreshDashboardData() async {
        // Имитация загрузки данных
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        currentTime = Date()
    }
}

// MARK: - Quick Actions Sheet
struct QuickActionsSheet: View {
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    
                    Text("Быстрые действия")
                        .font(Typography.Headline.large)
                        .foregroundColor(ColorPalette.Text.primary)
                        .padding(.top, Spacing.lg)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Spacing.md) {
                        
                        quickActionButton("Новая привычка", icon: "plus.circle", color: ColorPalette.Habits.health) {
                            NavigationManager.shared.navigate(to: .createHabit, in: .habits)
                            dismiss()
                        }
                        
                        quickActionButton("Новая задача", icon: "note.text.badge.plus", color: ColorPalette.Secondary.main) {
                            NavigationManager.shared.navigate(to: .createTask, in: .tasks)
                            dismiss()
                        }
                        
                        quickActionButton("Добавить доход", icon: "plus.rectangle.on.rectangle", color: ColorPalette.Financial.income) {
                            NavigationManager.shared.navigate(to: .addTransaction, in: .finance)
                            dismiss()
                        }
                        
                        quickActionButton("Записать расход", icon: "minus.rectangle", color: ColorPalette.Financial.expense) {
                            NavigationManager.shared.navigate(to: .addTransaction, in: .finance)
                            dismiss()
                        }
                        
                        quickActionButton("Новая цель", icon: "target", color: ColorPalette.Primary.main) {
                            NavigationManager.shared.navigate(to: .createGoal, in: .dashboard)
                            dismiss()
                        }
                        
                        quickActionButton("Настройки", icon: "gearshape", color: ColorPalette.Text.secondary) {
                            NavigationManager.shared.selectedTab = .settings
                            dismiss()
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    @ViewBuilder
    private func quickActionButton(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(Typography.Body.medium)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(ColorPalette.Background.surface)
            .cardCornerRadius()
            .cardShadow()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#if DEBUG
#Preview("ContentView") {
    ContentView()
}

#Preview("Dashboard") {
    DashboardTabView()
}

#Preview("Quick Actions") {
    QuickActionsSheet()
}
#endif 