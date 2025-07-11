//
//  IWBBApp.swift
//  IWBB
//
//  Created by AI Assistant
//  Основная точка входа приложения IWBB
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
        }
        .modelContainer(for: dataModels)
        .commands {
            // macOS Menu Commands
            CommandGroup(replacing: .newItem) {
                Button("Создать привычку") {
                    NavigationManager.shared.navigate(to: .createHabit, in: .habits)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Добавить задачу") {
                    NavigationManager.shared.navigate(to: .createTask, in: .tasks)
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Добавить транзакцию") {
                    NavigationManager.shared.navigate(to: .addTransaction, in: .finance)
                }
                .keyboardShortcut("m", modifiers: .command)
            }
            
            CommandGroup(after: .sidebar) {
                Button("Обзор") {
                    NavigationManager.shared.selectedTab = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Привычки") {
                    NavigationManager.shared.selectedTab = .habits
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Задачи") {
                    NavigationManager.shared.selectedTab = .tasks
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Финансы") {
                    NavigationManager.shared.selectedTab = .finance
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Button("Настройки") {
                    NavigationManager.shared.selectedTab = .settings
                }
                .keyboardShortcut("5", modifiers: .command)
            }
        }
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
            // Основные модели будут добавлены позже
            // User.self,
            // Habit.self,
            // Task.self,
            // Transaction.self,
            // Goal.self,
            // Budget.self,
            // Achievement.self,
            // Category.self
        ]
    }
}

// MARK: - Splash Screen
struct SplashScreenView: View {
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient.primaryGradient
                .ignoresSafeArea()
            
            VStack(spacing: Spacing.xxl) {
                // Логотип приложения
                VStack(spacing: Spacing.lg) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Text("IWBB")
                        .font(Typography.Display.large)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    Text("Ваш персональный планировщик")
                        .font(Typography.Body.large)
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
            color: ColorPalette.Primary.main
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Отслеживайте прогресс",
            description: "Визуализируйте свой прогресс с помощью наглядной статистики и графиков",
            color: ColorPalette.Secondary.main
        ),
        OnboardingPage(
            icon: "dollarsign.circle",
            title: "Управляйте финансами",
            description: "Контролируйте доходы и расходы, планируйте бюджет на будущее",
            color: ColorPalette.Financial.income
        ),
        OnboardingPage(
            icon: "trophy",
            title: "Получайте награды",
            description: "Зарабатывайте достижения и мотивируйтесь продолжать развиваться",
            color: ColorPalette.Semantic.warning
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
            VStack(spacing: Spacing.lg) {
                // Индикаторы страниц
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? ColorPalette.Primary.main : ColorPalette.Border.main)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                
                // Кнопки навигации
                HStack {
                    if currentPage > 0 {
                        SecondaryButton("Назад") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        PrimaryButton("Далее") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    } else {
                        PrimaryButton("Начать использовать") {
                            // Переход к основному приложению будет обработан в parent view
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, Spacing.screenPadding)
        }
        .background(ColorPalette.Background.primary)
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
        VStack(spacing: Spacing.xxxl) {
            Spacer()
            
            // Иконка
            Image(systemName: page.icon)
                .font(.system(size: 120, weight: .thin))
                .foregroundStyle(page.color)
            
            // Текст
            VStack(spacing: Spacing.lg) {
                Text(page.title)
                    .font(Typography.Display.medium)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.Text.primary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(Typography.Body.large)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, Spacing.screenPadding)
            
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
        .environment(\.theme, DefaultTheme())
}

#Preview("Splash Screen") {
    SplashScreenView()
}

#Preview("Onboarding") {
    OnboardingView()
}
#endif 