//
//  IWBBApp.swift
//  IWBB
//
//  Created by AI Assistant
//  Основная точка входа приложения IWBB для macOS
//

import SwiftUI
import SwiftData

@main
struct IWBBApp: App {
    
    // MARK: - App Storage
    @AppStorage("selectedColorScheme") private var selectedColorScheme = "system"
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    
    // MARK: - State
    @State private var showSplashScreen = true
    
    var body: some Scene {
        // Основное окно приложения
        WindowGroup {
            Group {
                if showSplashScreen {
                    SplashScreenView()
                        .onAppear {
                            // Скрываем splash screen через 2 секунды
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    showSplashScreen = false
                                }
                            }
                        }
                } else if isFirstLaunch {
                    OnboardingView()
                        .onAppear {
                            isFirstLaunch = false
                        }
                } else {
                    ContentView()
                }
            }
            .preferredColorScheme(colorScheme)
            .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: dataModels)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Команды меню для macOS
            CommandGroup(replacing: .newItem) {
                Button("Новая привычка") {
                    // Добавить новую привычку
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Новая задача") {
                    // Добавить новую задачу
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Новая цель") {
                    // Добавить новую цель
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Button("Новая транзакция") {
                    // Добавить новую транзакцию
                }
                .keyboardShortcut("m", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Divider()
                
                Button("Быстрое добавление") {
                    // Показать быстрое добавление
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            
            CommandGroup(before: .help) {
                Button("Экспорт данных") {
                    // Экспорт данных
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Button("Импорт данных") {
                    // Импорт данных
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Синхронизация") {
                    // Принудительная синхронизация
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Button("Настройки") {
                    // Открыть настройки
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        
        // Окно настроек
        Settings {
            SettingsView()
        }
        
        // Окно "О программе"
        Window("О программе IWBB", id: "about") {
            AboutView()
                .frame(width: 400, height: 300)
        }
        .windowResizability(.contentSize)
        
        // Окно аналитики (дополнительное)
        Window("Подробная аналитика", id: "analytics") {
            AdvancedAnalyticsView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultPosition(.topTrailing)
        .keyboardShortcut("a", modifiers: [.command, .shift])
    }
    
    // MARK: - Computed Properties
    
    /// Цветовая схема приложения
    private var colorScheme: ColorScheme? {
        switch selectedColorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // Системная
        }
    }
    
    /// Модели данных для SwiftData
    private var dataModels: [any PersistentModel.Type] {
        [
            User.self,
            Habit.self,
            Task.self,
            Transaction.self,
            Currency.self,
            Goal.self,
            Achievement.self,
            Category.self
        ]
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("selectedColorScheme") private var selectedColorScheme = "system"
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled = true
    @AppStorage("isNotificationsEnabled") private var isNotificationsEnabled = true
    @AppStorage("defaultHabitReminderTime") private var defaultHabitReminderTime = Date()
    
    var body: some View {
        TabView {
            // Общие настройки
            GeneralSettingsView()
                .tabItem {
                    Label("Общие", systemImage: "gear")
                }
                .tag("general")
            
            // Внешний вид
            AppearanceSettingsView()
                .tabItem {
                    Label("Внешний вид", systemImage: "paintbrush")
                }
                .tag("appearance")
            
            // Уведомления
            NotificationSettingsView()
                .tabItem {
                    Label("Уведомления", systemImage: "bell")
                }
                .tag("notifications")
            
            // Синхронизация
            SyncSettingsView()
                .tabItem {
                    Label("Синхронизация", systemImage: "icloud")
                }
                .tag("sync")
            
            // Конфиденциальность
            PrivacySettingsView()
                .tabItem {
                    Label("Конфиденциальность", systemImage: "lock")
                }
                .tag("privacy")
            
            // Дополнительно
            AdvancedSettingsView()
                .tabItem {
                    Label("Дополнительно", systemImage: "wrench.and.screwdriver")
                }
                .tag("advanced")
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Settings Views
struct GeneralSettingsView: View {
    @AppStorage("weekStartsOn") private var weekStartsOn = 1
    @AppStorage("preferredLanguage") private var preferredLanguage = "ru"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Основные настройки")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Form {
                    HStack {
                        Text("Язык интерфейса:")
                        Spacer()
                        Picker("Язык", selection: $preferredLanguage) {
                            Text("Русский").tag("ru")
                            Text("English").tag("en")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Неделя начинается с:")
                        Spacer()
                        Picker("День недели", selection: $weekStartsOn) {
                            Text("Понедельник").tag(1)
                            Text("Воскресенье").tag(0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("selectedColorScheme") private var selectedColorScheme = "system"
    @AppStorage("accentColor") private var accentColor = "blue"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Внешний вид")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Form {
                    HStack {
                        Text("Тема:")
                        Spacer()
                        Picker("Тема", selection: $selectedColorScheme) {
                            Text("Системная").tag("system")
                            Text("Светлая").tag("light")
                            Text("Тёмная").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    
                    HStack {
                        Text("Акцентный цвет:")
                        Spacer()
                        HStack {
                            ForEach(["blue", "green", "orange", "purple", "red"], id: \.self) { color in
                                Button(action: {
                                    accentColor = color
                                }) {
                                    Circle()
                                        .fill(colorForName(color))
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: accentColor == color ? 2 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func colorForName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        default: return .blue
        }
    }
}

struct NotificationSettingsView: View {
    @AppStorage("isNotificationsEnabled") private var isNotificationsEnabled = true
    @AppStorage("habitRemindersEnabled") private var habitRemindersEnabled = true
    @AppStorage("taskRemindersEnabled") private var taskRemindersEnabled = true
    @AppStorage("financialRemindersEnabled") private var financialRemindersEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Уведомления")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Включить уведомления", isOn: $isNotificationsEnabled)
                    
                    if isNotificationsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Напоминания о привычках", isOn: $habitRemindersEnabled)
                            Toggle("Напоминания о задачах", isOn: $taskRemindersEnabled)
                            Toggle("Финансовые напоминания", isOn: $financialRemindersEnabled)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SyncSettingsView: View {
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled = true
    @AppStorage("autoSyncInterval") private var autoSyncInterval = 300 // 5 минут
    @State private var lastSyncTime = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Синхронизация")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("iCloud синхронизация", isOn: $isCloudSyncEnabled)
                    
                    if isCloudSyncEnabled {
                        HStack {
                            Text("Автосинхронизация:")
                            Spacer()
                            Picker("Интервал", selection: $autoSyncInterval) {
                                Text("1 минута").tag(60)
                                Text("5 минут").tag(300)
                                Text("15 минут").tag(900)
                                Text("30 минут").tag(1800)
                                Text("1 час").tag(3600)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                        
                        HStack {
                            Text("Последняя синхронизация:")
                            Spacer()
                            Text(lastSyncTime.formatted(.dateTime.hour().minute()))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Spacer()
                            Button("Синхронизировать сейчас") {
                                lastSyncTime = Date()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PrivacySettingsView: View {
    @AppStorage("isAnalyticsEnabled") private var isAnalyticsEnabled = false
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Конфиденциальность")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Разрешить аналитику", isOn: $isAnalyticsEnabled)
                    Text("Помогает улучшить приложение")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                    
                    Toggle("Использовать Touch ID / Face ID", isOn: $isBiometricEnabled)
                    Text("Для защиты конфиденциальных данных")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("debugMode") private var debugMode = false
    @AppStorage("betaFeatures") private var betaFeatures = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Дополнительные настройки")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Режим отладки", isOn: $debugMode)
                    Toggle("Экспериментальные функции", isOn: $betaFeatures)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Экспорт данных") {
                            // Экспорт данных
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Импорт данных") {
                            // Импорт данных
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Сброс всех данных") {
                            // Сброс данных
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("IWBB")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Intelligent Work-Life Balance Planner")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Версия 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Text("Ваш персональный планировщик для достижения баланса между работой и жизнью.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button("Сайт") {
                        // Открыть сайт
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Поддержка") {
                        // Открыть поддержку
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer()
            
            Text("© 2024 IWBB. Все права защищены.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Advanced Analytics View
struct AdvancedAnalyticsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Подробная аналитика")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // Здесь будет подробная аналитика
                ScrollView {
                    VStack(spacing: 20) {
                        // Графики и диаграммы
                        Text("Детальные графики и статистика")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // Заглушки для графиков
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                Text("График прогресса привычек")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            )
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                Text("Финансовая аналитика")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            )
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                Text("Выполнение задач")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            )
                    }
                    .padding()
                }
            }
            .navigationTitle("Аналитика")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Экспорт") {
                        // Экспорт аналитики
                    }
                }
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashScreenView: View {
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(
                colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Логотип приложения
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Text("IWBB")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    Text("Ваш персональный планировщик")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(opacity)
                }
                
                // Индикатор загрузки
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            icon: "target",
            title: "Достигайте целей",
            description: "Планируйте задачи и формируйте полезные привычки для достижения ваших целей",
            color: .blue
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Отслеживайте прогресс",
            description: "Визуализируйте свой прогресс с помощью наглядной статистики и графиков",
            color: .green
        ),
        OnboardingPage(
            icon: "dollarsign.circle",
            title: "Управляйте финансами",
            description: "Контролируйте доходы и расходы, планируйте бюджет на будущее",
            color: .mint
        ),
        OnboardingPage(
            icon: "trophy",
            title: "Получайте награды",
            description: "Зарабатывайте достижения и мотивируйтесь продолжать развиваться",
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Контент страниц
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Нижняя панель
            VStack(spacing: 20) {
                // Индикаторы страниц
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? .blue : .gray)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                
                // Кнопки навигации
                HStack {
                    if currentPage > 0 {
                        Button("Назад") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        Button("Далее") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Начать использовать") {
                            // Переход к основному приложению будет обработан в parent view
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Onboarding Models
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Иконка
            Image(systemName: page.icon)
                .font(.system(size: 120, weight: .thin))
                .foregroundStyle(page.color)
            
            // Текст
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Extensions
extension IWBBApp {
    
    /// Настройка уведомлений
    private func configureNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    /// Настройка HealthKit (если требуется)
    private func configureHealthKit() {
        // Настройка HealthKit будет добавлена позже
    }
    
    /// Настройка CloudKit
    private func configureCloudKit() {
        // Настройка CloudKit будет добавлена позже
    }
}

// MARK: - Preview
#if DEBUG
#Preview("App") {
    ContentView()
}

#Preview("Splash Screen") {
    SplashScreenView()
}

#Preview("Onboarding") {
    OnboardingView()
}

#Preview("Settings") {
    SettingsView()
}

#Preview("About") {
    AboutView()
}
#endif 