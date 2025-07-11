//
//  PreviewHelpers.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Утилиты: Preview helpers для разработки в Xcode Previews
//

import SwiftUI

// MARK: - Device Presets
enum PreviewDevice: String, CaseIterable {
    case iPhoneSE = "iPhone SE (3rd generation)"
    case iPhone15 = "iPhone 15"
    case iPhone15Pro = "iPhone 15 Pro"
    case iPhone15ProMax = "iPhone 15 Pro Max"
    case iPadMini = "iPad mini (6th generation)"
    case iPadPro11 = "iPad Pro (11-inch)"
    case iPadPro129 = "iPad Pro (12.9-inch)"
    case mac = "Mac"
    
    var displayName: String {
        switch self {
        case .iPhoneSE:
            return "iPhone SE"
        case .iPhone15:
            return "iPhone 15"
        case .iPhone15Pro:
            return "iPhone 15 Pro"
        case .iPhone15ProMax:
            return "iPhone 15 Pro Max"
        case .iPadMini:
            return "iPad mini"
        case .iPadPro11:
            return "iPad Pro 11\""
        case .iPadPro129:
            return "iPad Pro 12.9\""
        case .mac:
            return "Mac"
        }
    }
    
    var deviceCategory: DeviceCategory {
        switch self {
        case .iPhoneSE, .iPhone15, .iPhone15Pro, .iPhone15ProMax:
            return .iPhone
        case .iPadMini, .iPadPro11, .iPadPro129:
            return .iPad
        case .mac:
            return .mac
        }
    }
    
    enum DeviceCategory {
        case iPhone
        case iPad
        case mac
    }
}

// MARK: - Preview Configurations
struct PreviewConfiguration {
    let device: PreviewDevice
    let colorScheme: ColorScheme?
    let orientation: Orientation?
    let locale: Locale?
    let sizeCategory: ContentSizeCategory?
    
    enum Orientation {
        case portrait
        case landscape
    }
    
    init(
        device: PreviewDevice,
        colorScheme: ColorScheme? = nil,
        orientation: Orientation? = nil,
        locale: Locale? = nil,
        sizeCategory: ContentSizeCategory? = nil
    ) {
        self.device = device
        self.colorScheme = colorScheme
        self.orientation = orientation
        self.locale = locale
        self.sizeCategory = sizeCategory
    }
}

// MARK: - Multi-Device Preview
struct MultiDevicePreview<Content: View>: View {
    let content: Content
    let configurations: [PreviewConfiguration]
    
    init(
        configurations: [PreviewConfiguration] = PreviewConfiguration.common,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.configurations = configurations
    }
    
    var body: some View {
        Group {
            ForEach(configurations.indices, id: \.self) { index in
                let config = configurations[index]
                
                content
                    .previewDevice(PreviewDevice(rawValue: config.device.rawValue))
                    .previewDisplayName(config.device.displayName)
                    .applyIf(config.colorScheme != nil) { view in
                        view.preferredColorScheme(config.colorScheme!)
                    }
                    .applyIf(config.sizeCategory != nil) { view in
                        view.environment(\.sizeCategory, config.sizeCategory!)
                    }
                    .applyIf(config.locale != nil) { view in
                        view.environment(\.locale, config.locale!)
                    }
            }
        }
    }
}

// MARK: - Preview Configuration Presets
extension PreviewConfiguration {
    static let common: [PreviewConfiguration] = [
        PreviewConfiguration(device: .iPhone15),
        PreviewConfiguration(device: .iPhone15ProMax),
        PreviewConfiguration(device: .iPadPro11)
    ]
    
    static let darkMode: [PreviewConfiguration] = [
        PreviewConfiguration(device: .iPhone15, colorScheme: .dark),
        PreviewConfiguration(device: .iPadPro11, colorScheme: .dark)
    ]
    
    static let accessibility: [PreviewConfiguration] = [
        PreviewConfiguration(device: .iPhone15, sizeCategory: .extraExtraExtraLarge),
        PreviewConfiguration(device: .iPhone15, sizeCategory: .extraSmall)
    ]
    
    static let allDevices: [PreviewConfiguration] = PreviewDevice.allCases.map {
        PreviewConfiguration(device: $0)
    }
}

// MARK: - Theme Preview Wrapper
struct ThemePreviewWrapper<Content: View>: View {
    let content: Content
    let theme: ThemeProtocol
    
    init(theme: ThemeProtocol = DefaultTheme(), @ViewBuilder content: () -> Content) {
        self.content = content()
        self.theme = theme
    }
    
    var body: some View {
        content
            .environment(\.theme, theme)
    }
}

// MARK: - State Preview Container
struct StatePreviewContainer<Content: View>: View {
    let states: [String: Content]
    
    init(@ViewBuilder states: () -> [(String, Content)]) {
        let stateList = states()
        self.states = Dictionary(uniqueKeysWithValues: stateList)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(Array(states.keys.sorted()), id: \.self) { stateName in
                VStack(alignment: .leading, spacing: 8) {
                    Text(stateName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    states[stateName]
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Mock Data Providers
struct MockDataProvider {
    // MARK: - User Data
    static let mockUser = User(
        name: "Иван Петров",
        email: "ivan@example.com",
        level: 5,
        totalPoints: 1250,
        createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
    )
    
    // MARK: - Habits Data
    static let mockHabits: [MockHabit] = [
        MockHabit(
            name: "Утренняя зарядка",
            category: "Здоровье",
            frequency: .daily,
            currentStreak: 15,
            bestStreak: 30,
            isCompleted: true
        ),
        MockHabit(
            name: "Чтение книг",
            category: "Обучение",
            frequency: .daily,
            currentStreak: 7,
            bestStreak: 12,
            isCompleted: false
        ),
        MockHabit(
            name: "Медитация",
            category: "Здоровье",
            frequency: .daily,
            currentStreak: 22,
            bestStreak: 25,
            isCompleted: true
        )
    ]
    
    // MARK: - Tasks Data
    static let mockTasks: [MockTask] = [
        MockTask(
            title: "Подготовить презентацию",
            description: "Создать слайды для встречи с клиентом",
            priority: .high,
            dueDate: Date().addingTimeInterval(2 * 24 * 60 * 60),
            isCompleted: false
        ),
        MockTask(
            title: "Купить продукты",
            description: "Молоко, хлеб, яйца",
            priority: .medium,
            dueDate: Date().addingTimeInterval(24 * 60 * 60),
            isCompleted: true
        ),
        MockTask(
            title: "Записаться к врачу",
            description: "Плановый осмотр",
            priority: .low,
            dueDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            isCompleted: false
        )
    ]
    
    // MARK: - Finance Data
    static let mockTransactions: [MockTransaction] = [
        MockTransaction(
            title: "Зарплата",
            amount: 75000,
            type: .income,
            category: "Работа",
            date: Date().addingTimeInterval(-5 * 24 * 60 * 60)
        ),
        MockTransaction(
            title: "Продукты",
            amount: -2500,
            type: .expense,
            category: "Еда",
            date: Date().addingTimeInterval(-2 * 24 * 60 * 60)
        ),
        MockTransaction(
            title: "Кафе",
            amount: -450,
            type: .expense,
            category: "Развлечения",
            date: Date().addingTimeInterval(-24 * 60 * 60)
        )
    ]
    
    // MARK: - Chart Data
    static let mockChartData: [ChartDataPoint] = [
        ChartDataPoint(label: "Пн", value: 5),
        ChartDataPoint(label: "Вт", value: 7),
        ChartDataPoint(label: "Ср", value: 3),
        ChartDataPoint(label: "Чт", value: 8),
        ChartDataPoint(label: "Пт", value: 6),
        ChartDataPoint(label: "Сб", value: 4),
        ChartDataPoint(label: "Вс", value: 9)
    ]
    
    static let mockTrendData: [TrendDataPoint] = {
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        return (0..<7).map { i in
            TrendDataPoint(
                date: Calendar.current.date(byAdding: .day, value: i, to: startDate)!,
                value: Double.random(in: 1...10)
            )
        }
    }()
}

// MARK: - Mock Models
struct MockHabit: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let frequency: Frequency
    let currentStreak: Int
    let bestStreak: Int
    let isCompleted: Bool
    
    enum Frequency {
        case daily
        case weekly
        case monthly
    }
}

struct MockTask: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let dueDate: Date
    let isCompleted: Bool
    
    enum Priority {
        case low
        case medium
        case high
        case urgent
    }
}

struct MockTransaction: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let type: TransactionType
    let category: String
    let date: Date
    
    enum TransactionType {
        case income
        case expense
    }
}

// MARK: - View Extensions for Previews
extension View {
    func previewWithAllDevices() -> some View {
        MultiDevicePreview(configurations: .allDevices) {
            self
        }
    }
    
    func previewWithCommonDevices() -> some View {
        MultiDevicePreview(configurations: .common) {
            self
        }
    }
    
    func previewWithDarkMode() -> some View {
        MultiDevicePreview(configurations: .darkMode) {
            self
        }
    }
    
    func previewWithAccessibility() -> some View {
        MultiDevicePreview(configurations: .accessibility) {
            self
        }
    }
    
    func previewWithStates<T>(_ states: [T], stateName: @escaping (T) -> String, content: @escaping (T) -> Self) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(Array(states.enumerated()), id: \.offset) { index, state in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stateName(state))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        content(state)
                    }
                    .padding()
                    .background(ColorPalette.Background.surface)
                    .adaptiveCornerRadius()
                    .cardShadow()
                }
            }
            .padding()
        }
        .background(ColorPalette.Background.grouped)
    }
    
    func applyIf<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        Group {
            if condition {
                transform(self)
            } else {
                self
            }
        }
    }
}

// MARK: - Navigation Manager for Previews
extension NavigationManager {
    static let preview: NavigationManager = {
        let manager = NavigationManager()
        manager.selectedTab = .dashboard
        return manager
    }()
}

// MARK: - Environment Setup for Previews
struct PreviewEnvironmentSetup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .environment(NavigationManager.preview)
            .environment(\.theme, DefaultTheme())
    }
}

// MARK: - Preview Macros
@available(iOS 17.0, *)
#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}

@available(iOS 17.0, *)
#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}

@available(iOS 17.0, *)
#Preview("iPad") {
    ContentView()
        .previewDevice(PreviewDevice.iPadPro11.rawValue)
}

// MARK: - Component Preview Helper
struct ComponentPreview<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    content
                }
                .adaptivePadding()
            }
            .navigationTitle(title)
            .background(ColorPalette.Background.grouped)
        }
    }
}

// MARK: - Usage Examples
#if DEBUG
struct PreviewHelpers_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Basic component preview
            ComponentPreview("Buttons") {
                VStack(spacing: 16) {
                    PrimaryButton("Primary") { }
                    SecondaryButton("Secondary") { }
                    TertiaryButton("Tertiary") { }
                }
            }
            .previewDisplayName("Component Preview")
            
            // State variations
            PrimaryButton("Loading", isLoading: true) { }
                .previewWithStates(
                    [false, true],
                    stateName: { $0 ? "Loading" : "Normal" }
                ) { isLoading in
                    PrimaryButton("Button", isLoading: isLoading) { }
                }
            
            // Multi-device preview
            VStack {
                Text("Hello, World!")
                    .font(.largeTitle)
                PrimaryButton("Action") { }
            }
            .previewWithCommonDevices()
        }
    }
}
#endif 