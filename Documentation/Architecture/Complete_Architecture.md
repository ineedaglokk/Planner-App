# iOS/macOS Планнер - Техническая Архитектура

## Оглавление
1. [Обзор архитектуры](#обзор-архитектуры)
2. [Структура проекта](#структура-проекта)
3. [Модели данных (SwiftData)](#модели-данных-swiftdata)
4. [Архитектурные паттерны](#архитектурные-паттерны)
5. [Сервисная архитектура](#сервисная-архитектура)
6. [Навигация и UI](#навигация-и-ui)
7. [Дизайн-система](#дизайн-система)
8. [Интеграции и расширения](#интеграции-и-расширения)
9. [Data Flow и State Management](#data-flow-и-state-management)
10. [Безопасность и производительность](#безопасность-и-производительность)

---

## Обзор архитектуры

### Архитектурные принципы
- **Offline-first**: Приложение полностью функционально без интернета
- **Modular Design**: Независимые feature-модули с четкими границами
- **Protocol-Oriented**: Максимальное использование протоколов для абстракции
- **Declarative UI**: SwiftUI для всего пользовательского интерфейса
- **Async/Await**: Современный подход к асинхронному программированию
- **Clean Architecture**: Четкое разделение слоев ответственности

### Технологический стек
```
Platform: iOS 17.0+, macOS 14.0+, watchOS 10.0+
Language: Swift 5.9+
UI Framework: SwiftUI 5.0
Data: SwiftData + CloudKit
Architecture: MVVM + Swift Concurrency
Navigation: NavigationStack
Charts: Swift Charts
Widgets: WidgetKit + App Intents
Testing: XCTest + Swift Testing
CI/CD: Xcode Cloud + GitHub Actions
```

---

## Структура проекта

### Файловая структура
```
PlannerApp/
├── 📁 App/                          # Application Entry Point
│   ├── PlannerApp.swift            # Main App file
│   ├── ContentView.swift           # Root content view
│   └── AppDelegate.swift           # App lifecycle
├── 📁 Core/                         # Core Infrastructure
│   ├── 📁 Models/                  # SwiftData Models
│   │   ├── User.swift
│   │   ├── Habit.swift
│   │   ├── HabitEntry.swift
│   │   ├── Task.swift
│   │   ├── Goal.swift
│   │   ├── Transaction.swift
│   │   ├── Budget.swift
│   │   ├── Achievement.swift
│   │   ├── Category.swift
│   │   └── ModelContainer+Extensions.swift
│   ├── 📁 Services/                # Business Logic Services
│   │   ├── DataService.swift
│   │   ├── NotificationService.swift
│   │   ├── HealthKitService.swift
│   │   ├── GameService.swift
│   │   ├── SyncService.swift
│   │   └── ServiceContainer.swift
│   ├── 📁 Repositories/            # Data Access Layer
│   │   ├── HabitRepository.swift
│   │   ├── TaskRepository.swift
│   │   ├── FinanceRepository.swift
│   │   └── UserRepository.swift
│   └── 📁 Utilities/               # Helpers & Extensions
│       ├── Extensions/
│       ├── Constants.swift
│       ├── Formatters.swift
│       └── ErrorHandling.swift
├── 📁 Features/                     # Feature Modules
│   ├── 📁 Dashboard/               # Overview & Analytics
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── 📁 Habits/                  # Habit Tracking
│   │   ├── Views/
│   │   │   ├── HabitsListView.swift
│   │   │   ├── HabitDetailView.swift
│   │   │   ├── CreateHabitView.swift
│   │   │   └── HabitCalendarView.swift
│   │   ├── ViewModels/
│   │   │   ├── HabitsListViewModel.swift
│   │   │   ├── HabitDetailViewModel.swift
│   │   │   └── CreateHabitViewModel.swift
│   │   └── Components/
│   │       ├── HabitCardView.swift
│   │       ├── StreakView.swift
│   │       └── ProgressRingView.swift
│   ├── 📁 Tasks/                   # Task Management
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── 📁 Finance/                 # Financial Management
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── 📁 Goals/                   # Goal Setting
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   ├── 📁 Gamification/            # Points & Achievements
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Components/
│   └── 📁 Settings/                # App Settings
│       ├── Views/
│       ├── ViewModels/
│       └── Components/
├── 📁 Shared/                       # Shared UI Components
│   ├── 📁 Components/              # Reusable Components
│   │   ├── Buttons/
│   │   ├── Cards/
│   │   ├── Forms/
│   │   ├── Charts/
│   │   └── Progress/
│   ├── 📁 Themes/                  # Design System
│   │   ├── Colors.swift
│   │   ├── Typography.swift
│   │   ├── Spacing.swift
│   │   └── Theme.swift
│   └── 📁 Navigation/              # Navigation Helpers
│       ├── NavigationManager.swift
│       ├── TabRouter.swift
│       └── DeepLinkHandler.swift
├── 📁 Widgets/                      # WidgetKit Extensions
│   ├── HabitWidget/
│   ├── TaskWidget/
│   ├── FinanceWidget/
│   └── Shared/
├── 📁 Tests/                        # All Tests
│   ├── UnitTests/
│   ├── IntegrationTests/
│   ├── UITests/
│   └── PerformanceTests/
└── 📁 Resources/                    # Assets & Configuration
    ├── Assets.xcassets
    ├── Localizable.strings
    ├── Info.plist
    └── Entitlements.plist
```

---

## Модели данных (SwiftData)

### Базовые протоколы
```swift
// Базовые протоколы для всех моделей
protocol Identifiable {
    var id: UUID { get }
}

protocol Timestampable {
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

protocol CloudKitSyncable: Identifiable {
    var cloudKitRecordID: String? { get set }
    var needsSync: Bool { get set }
    var lastSynced: Date? { get set }
}

protocol Gamifiable {
    var points: Int { get }
    func calculatePoints() -> Int
}

protocol Categorizable {
    var category: Category? { get set }
}
```

### Основные модели

#### 1. User Model
```swift
@Model
final class User: CloudKitSyncable, Timestampable {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var preferences: UserPreferences
    var level: Int
    var totalPoints: Int
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var habits: [Habit]
    @Relationship(deleteRule: .cascade) var tasks: [Task]
    @Relationship(deleteRule: .cascade) var goals: [Goal]
    @Relationship(deleteRule: .cascade) var transactions: [Transaction]
    @Relationship(deleteRule: .cascade) var achievements: [Achievement]
}

struct UserPreferences: Codable {
    var theme: ThemeMode
    var notifications: NotificationSettings
    var privacy: PrivacySettings
    var language: String
}
```

#### 2. Habit Model
```swift
@Model
final class Habit: CloudKitSyncable, Timestampable, Gamifiable, Categorizable {
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var icon: String // SF Symbol name
    var color: String // Hex color
    var frequency: HabitFrequency
    var reminderTime: Date?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var entries: [HabitEntry]
    var category: Category?
    var user: User?
    
    // Computed Properties
    var currentStreak: Int { /* calculation */ }
    var longestStreak: Int { /* calculation */ }
    var completionRate: Double { /* calculation */ }
    var points: Int { calculatePoints() }
    
    func calculatePoints() -> Int {
        return currentStreak * 10 + entries.count * 5
    }
}

enum HabitFrequency: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case custom = "custom"
}
```

#### 3. Task Model
```swift
@Model
final class Task: CloudKitSyncable, Timestampable, Gamifiable, Categorizable {
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String?
    var priority: TaskPriority
    var status: TaskStatus
    var dueDate: Date?
    var estimatedDuration: TimeInterval?
    var actualDuration: TimeInterval?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    var category: Category?
    var user: User?
    var parentGoal: Goal?
    @Relationship(deleteRule: .cascade) var subtasks: [Task]
    var parentTask: Task?
    
    var points: Int { calculatePoints() }
    
    func calculatePoints() -> Int {
        let basePoints = priority.points
        let timeBonus = dueDate?.timeIntervalSinceNow ?? 0 > 0 ? 5 : 0
        return basePoints + timeBonus
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var points: Int {
        switch self {
        case .low: return 5
        case .medium: return 10
        case .high: return 15
        case .urgent: return 20
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
}
```

#### 4. Transaction Model
```swift
@Model
final class Transaction: CloudKitSyncable, Timestampable, Categorizable {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var type: TransactionType
    var description: String?
    var date: Date
    var account: String?
    var receiptPhoto: String? // File path
    var isRecurring: Bool
    var recurringPattern: RecurringPattern?
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    var category: Category?
    var user: User?
    var budget: Budget?
}

enum TransactionType: String, Codable, CaseIterable {
    case income = "income"
    case expense = "expense"
    case transfer = "transfer"
}

struct RecurringPattern: Codable {
    var frequency: RecurringFrequency
    var interval: Int
    var endDate: Date?
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily, weekly, monthly, yearly
}
```

### ModelContainer конфигурация
```swift
extension ModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            User.self,
            Habit.self,
            HabitEntry.self,
            Task.self,
            Goal.self,
            Transaction.self,
            Budget.self,
            Achievement.self,
            Category.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.yourcompany.planner")
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
```

---

## Архитектурные паттерны

### MVVM + SwiftUI
```swift
// View Model Protocol
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Input
    
    var state: State { get }
    func send(_ input: Input)
}

// Example ViewModel Implementation
@Observable
final class HabitsListViewModel: ViewModelProtocol {
    
    // MARK: - State
    struct State {
        var habits: [Habit] = []
        var isLoading: Bool = false
        var error: AppError?
        var searchText: String = ""
        var selectedCategory: Category?
    }
    
    // MARK: - Input
    enum Input {
        case loadHabits
        case searchTextChanged(String)
        case categorySelected(Category?)
        case habitToggled(Habit)
        case deleteHabit(Habit)
    }
    
    // MARK: - Properties
    private(set) var state = State()
    
    // Dependencies
    private let habitRepository: HabitRepositoryProtocol
    private let gameService: GameServiceProtocol
    
    // MARK: - Initialization
    init(
        habitRepository: HabitRepositoryProtocol,
        gameService: GameServiceProtocol
    ) {
        self.habitRepository = habitRepository
        self.gameService = gameService
    }
    
    // MARK: - Input Handling
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadHabits:
                await loadHabits()
            case .searchTextChanged(let text):
                state.searchText = text
                await filterHabits()
            case .categorySelected(let category):
                state.selectedCategory = category
                await filterHabits()
            case .habitToggled(let habit):
                await toggleHabit(habit)
            case .deleteHabit(let habit):
                await deleteHabit(habit)
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadHabits() async {
        state.isLoading = true
        
        do {
            let habits = try await habitRepository.fetchActiveHabits()
            state.habits = habits
            state.error = nil
        } catch {
            state.error = AppError.from(error)
        }
        
        state.isLoading = false
    }
}
```

### Repository Pattern
```swift
// Repository Protocol
protocol HabitRepositoryProtocol {
    func fetchActiveHabits() async throws -> [Habit]
    func fetchHabit(by id: UUID) async throws -> Habit?
    func save(_ habit: Habit) async throws
    func delete(_ habit: Habit) async throws
    func markHabitComplete(_ habit: Habit, date: Date) async throws
}

// Repository Implementation
final class HabitRepository: HabitRepositoryProtocol {
    private let modelContext: ModelContext
    private let syncService: SyncServiceProtocol
    
    init(modelContext: ModelContext, syncService: SyncServiceProtocol) {
        self.modelContext = modelContext
        self.syncService = syncService
    }
    
    func fetchActiveHabits() async throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func save(_ habit: Habit) async throws {
        modelContext.insert(habit)
        habit.needsSync = true
        habit.updatedAt = Date()
        
        try modelContext.save()
        
        // Trigger sync
        await syncService.scheduleSync()
    }
}
```

---

## Сервисная архитектура

### Service Container (Dependency Injection)
```swift
protocol ServiceContainerProtocol {
    var dataService: DataServiceProtocol { get }
    var notificationService: NotificationServiceProtocol { get }
    var healthKitService: HealthKitServiceProtocol { get }
    var gameService: GameServiceProtocol { get }
    var syncService: SyncServiceProtocol { get }
}

@Observable
final class ServiceContainer: ServiceContainerProtocol {
    lazy var dataService: DataServiceProtocol = DataService(modelContext: modelContext)
    lazy var notificationService: NotificationServiceProtocol = NotificationService()
    lazy var healthKitService: HealthKitServiceProtocol = HealthKitService()
    lazy var gameService: GameServiceProtocol = GameService(dataService: dataService)
    lazy var syncService: SyncServiceProtocol = SyncService(dataService: dataService)
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}

// Environment Key для внедрения зависимостей
struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainerProtocol = ServiceContainer(
        modelContext: ModelContainer.shared.mainContext
    )
}

extension EnvironmentValues {
    var services: ServiceContainerProtocol {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}
```

### Core Services

#### 1. DataService
```swift
protocol DataServiceProtocol {
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T]
    func save<T: PersistentModel>(_ model: T) async throws
    func delete<T: PersistentModel>(_ model: T) async throws
    func batchSave<T: PersistentModel>(_ models: [T]) async throws
}

final class DataService: DataServiceProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>? = nil) async throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
    
    func save<T: PersistentModel>(_ model: T) async throws {
        modelContext.insert(model)
        try modelContext.save()
    }
}
```

#### 2. NotificationService
```swift
protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func scheduleHabitReminder(_ habit: Habit) async
    func scheduleTaskDeadline(_ task: Task) async
    func cancelNotifications(for id: String) async
    func handleNotificationResponse(_ response: UNNotificationResponse) async
}

final class NotificationService: NSObject, NotificationServiceProtocol {
    private let center = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        center.delegate = self
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            return false
        }
    }
    
    func scheduleHabitReminder(_ habit: Habit) async {
        guard let reminderTime = habit.reminderTime else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Время для привычки"
        content.body = habit.name
        content.sound = .default
        content.categoryIdentifier = "HABIT_REMINDER"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "habit-\(habit.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

#### 3. GameService
```swift
protocol GameServiceProtocol {
    func awardPoints(_ points: Int, for action: GameAction) async
    func checkAchievements(for user: User) async
    func calculateLevel(from points: Int) -> Int
    func getAvailableChallenges() async -> [Challenge]
}

final class GameService: GameServiceProtocol {
    private let dataService: DataServiceProtocol
    
    init(dataService: DataServiceProtocol) {
        self.dataService = dataService
    }
    
    func awardPoints(_ points: Int, for action: GameAction) async {
        // Implementation
    }
    
    func checkAchievements(for user: User) async {
        // Check various achievement conditions
        await checkStreakAchievements(for: user)
        await checkTaskCompletionAchievements(for: user)
        await checkFinancialGoalAchievements(for: user)
    }
}

enum GameAction {
    case habitCompleted(Habit)
    case taskCompleted(Task)
    case goalAchieved(Goal)
    case streakMilestone(Int)
}
```

---

## Навигация и UI

### Navigation Architecture
```swift
// Main Navigation Structure
struct ContentView: View {
    @State private var tabSelection: Tab = .dashboard
    @Environment(\.services) private var services
    
    var body: some View {
        TabView(selection: $tabSelection) {
            DashboardView()
                .tabItem { Label("Обзор", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.dashboard)
            
            HabitsView()
                .tabItem { Label("Привычки", systemImage: "repeat.circle") }
                .tag(Tab.habits)
            
            TasksView()
                .tabItem { Label("Задачи", systemImage: "checkmark.circle") }
                .tag(Tab.tasks)
            
            FinanceView()
                .tabItem { Label("Финансы", systemImage: "dollarsign.circle") }
                .tag(Tab.finance)
            
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .environment(\.services, services)
    }
}

enum Tab: String, CaseIterable {
    case dashboard, habits, tasks, finance, settings
}
```

### NavigationStack Usage
```swift
struct HabitsView: View {
    @State private var navigationPath = NavigationPath()
    @State private var viewModel = HabitsListViewModel()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            HabitsListView(viewModel: viewModel)
                .navigationTitle("Привычки")
                .navigationDestination(for: HabitDestination.self) { destination in
                    switch destination {
                    case .detail(let habit):
                        HabitDetailView(habit: habit)
                    case .create:
                        CreateHabitView()
                    case .edit(let habit):
                        EditHabitView(habit: habit)
                    }
                }
        }
    }
}

enum HabitDestination: Hashable {
    case detail(Habit)
    case create
    case edit(Habit)
}
```

---

## Дизайн-система

### Theme System
```swift
// Theme Protocol
protocol ThemeProtocol {
    var colors: ColorPalette { get }
    var typography: Typography { get }
    var spacing: Spacing { get }
    var cornerRadii: CornerRadii { get }
}

// Color System
struct ColorPalette {
    // Primary Colors
    let primary: Color
    let primaryLight: Color
    let primaryDark: Color
    
    // Secondary Colors
    let secondary: Color
    let secondaryLight: Color
    let secondaryDark: Color
    
    // Semantic Colors
    let success: Color
    let warning: Color
    let error: Color
    let info: Color
    
    // Neutral Colors
    let background: Color
    let surface: Color
    let onBackground: Color
    let onSurface: Color
    
    // Text Colors
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
}

// Typography System
struct Typography {
    let largeTitle: Font
    let title1: Font
    let title2: Font
    let title3: Font
    let headline: Font
    let body: Font
    let callout: Font
    let subheadline: Font
    let footnote: Font
    let caption1: Font
    let caption2: Font
}

// Spacing System (8pt grid)
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### Reusable Components
```swift
// Primary Button Component
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isDisabled: Bool
    
    init(
        _ title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? Color.gray : Theme.colors.primary)
            )
            .foregroundColor(.white)
        }
        .disabled(isDisabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// Card Component
struct CardView<Content: View>: View {
    let content: Content
    let padding: EdgeInsets
    
    init(
        padding: EdgeInsets = EdgeInsets(
            top: Spacing.md,
            leading: Spacing.md,
            bottom: Spacing.md,
            trailing: Spacing.md
        ),
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.colors.surface)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
    }
}
```

---

## Интеграции и расширения

### WidgetKit Integration
```swift
// Widget Bundle
@main
struct PlannerWidgets: WidgetBundle {
    var body: some Widget {
        HabitProgressWidget()
        TaskSummaryWidget()
        FinanceOverviewWidget()
    }
}

// Habit Progress Widget
struct HabitProgressWidget: Widget {
    let kind: String = "HabitProgressWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: HabitWidgetConfigurationIntent.self,
            provider: HabitTimelineProvider()
        ) { entry in
            HabitProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Прогресс привычек")
        .description("Отслеживайте свои привычки прямо с главного экрана")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Timeline Provider
struct HabitTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: Date(), habits: sampleHabits)
    }
    
    func snapshot(for configuration: HabitWidgetConfigurationIntent, in context: Context) async -> HabitEntry {
        HabitEntry(date: Date(), habits: await loadHabits())
    }
    
    func timeline(for configuration: HabitWidgetConfigurationIntent, in context: Context) async -> Timeline<HabitEntry> {
        let habits = await loadHabits()
        let entry = HabitEntry(date: Date(), habits: habits)
        
        // Update timeline every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
```

### App Intents (Siri Integration)
```swift
// Mark Habit Complete Intent
struct MarkHabitCompleteIntent: AppIntent {
    static var title: LocalizedStringResource = "Отметить привычку выполненной"
    static var description = IntentDescription("Отметить привычку как выполненную на сегодня")
    
    @Parameter(title: "Привычка")
    var habit: HabitEntity
    
    func perform() async throws -> some IntentResult {
        let habitRepository = ServiceContainer.shared.habitRepository
        
        do {
            try await habitRepository.markHabitComplete(habit.habit, date: Date())
            
            return .result(dialog: "Привычка \(habit.name) отмечена как выполненная!")
        } catch {
            throw AppError.failedToMarkHabitComplete
        }
    }
}

// Habit Entity for App Intents
struct HabitEntity: AppEntity {
    let id: UUID
    let name: String
    let habit: Habit
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Привычка"
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static var defaultQuery = HabitEntityQuery()
}
```

### HealthKit Integration
```swift
protocol HealthKitServiceProtocol {
    func requestAuthorization() async -> Bool
    func syncStepCount() async throws -> Int
    func syncSleepData() async throws -> [SleepSample]
    func syncWorkoutData() async throws -> [WorkoutSample]
}

final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType()
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            return true
        } catch {
            return false
        }
    }
    
    func syncStepCount() async throws -> Int {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let stepCount = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(stepCount))
            }
            
            healthStore.execute(query)
        }
    }
}
```

---

## Data Flow и State Management

### Reactive Data Flow
```swift
// Observable State Management
@Observable
final class AppState {
    var user: User?
    var isAuthenticated: Bool = false
    var networkStatus: NetworkStatus = .unknown
    var syncStatus: SyncStatus = .idle
    
    // Feature States
    var habitsState = HabitsState()
    var tasksState = TasksState()
    var financeState = FinanceState()
}

@Observable
final class HabitsState {
    var habits: [Habit] = []
    var selectedHabit: Habit?
    var isLoading: Bool = false
    var error: AppError?
    var filters: HabitFilters = HabitFilters()
}

// State Updates через Actions
enum AppAction {
    case userAuthenticated(User)
    case userLoggedOut
    case networkStatusChanged(NetworkStatus)
    case syncStatusChanged(SyncStatus)
    
    // Habit Actions
    case habitsLoaded([Habit])
    case habitCreated(Habit)
    case habitUpdated(Habit)
    case habitDeleted(UUID)
}

// Action Handler
final class AppActionHandler {
    func handle(_ action: AppAction, state: inout AppState) {
        switch action {
        case .userAuthenticated(let user):
            state.user = user
            state.isAuthenticated = true
            
        case .userLoggedOut:
            state.user = nil
            state.isAuthenticated = false
            state.habitsState = HabitsState()
            state.tasksState = TasksState()
            state.financeState = FinanceState()
            
        case .habitsLoaded(let habits):
            state.habitsState.habits = habits
            state.habitsState.isLoading = false
            
        case .habitCreated(let habit):
            state.habitsState.habits.append(habit)
            
        // ... other actions
        }
    }
}
```

### Error Handling
```swift
enum AppError: Error, LocalizedError {
    case networkUnavailable
    case dataCorrupted
    case syncFailed(String)
    case authenticationFailed
    case permissionDenied
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Нет подключения к интернету"
        case .dataCorrupted:
            return "Данные повреждены"
        case .syncFailed(let reason):
            return "Ошибка синхронизации: \(reason)"
        case .authenticationFailed:
            return "Ошибка авторизации"
        case .permissionDenied:
            return "Доступ запрещен"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error)
    }
}

// Error Handler Service
protocol ErrorHandlerProtocol {
    func handle(_ error: AppError)
    func showErrorAlert(_ error: AppError)
    func logError(_ error: AppError)
}

final class ErrorHandler: ErrorHandlerProtocol {
    func handle(_ error: AppError) {
        logError(error)
        
        // Show user-friendly error message
        DispatchQueue.main.async {
            self.showErrorAlert(error)
        }
    }
    
    func showErrorAlert(_ error: AppError) {
        // Implementation for showing alerts
    }
    
    func logError(_ error: AppError) {
        // Log to analytics/crash reporting
        print("Error: \(error.localizedDescription)")
    }
}
```

---

## Безопасность и производительность

### Security Measures
```swift
// Biometric Authentication
import LocalAuthentication

final class BiometricService {
    func authenticateUser() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Для доступа к приложению требуется аутентификация"
            )
            return result
        } catch {
            return false
        }
    }
}

// Data Encryption
import CryptoKit

final class EncryptionService {
    private let key = SymmetricKey(size: .bits256)
    
    func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    func decrypt(_ encryptedData: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
```

### Performance Optimization
```swift
// Memory Management
final class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func image(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// Background Processing
actor BackgroundProcessor {
    func processHeavyTask<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        return try await withTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            return try await group.next()!
        }
    }
}

// Lazy Loading для больших списков
struct LazyHabitsList: View {
    @State private var habits: [Habit] = []
    @State private var isLoading = false
    
    var body: some View {
        LazyVStack {
            ForEach(habits) { habit in
                HabitRowView(habit: habit)
                    .onAppear {
                        if habit == habits.last {
                            loadMoreHabits()
                        }
                    }
            }
            
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private func loadMoreHabits() {
        guard !isLoading else { return }
        // Load more implementation
    }
}
```

---

## Тестирование

### Test Architecture
```swift
// Test Base Classes
class BaseTestCase: XCTestCase {
    var services: MockServiceContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        
        // Setup in-memory Core Data stack
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: testSchema, configurations: [configuration])
        modelContext = container.mainContext
        
        // Setup mock services
        services = MockServiceContainer(modelContext: modelContext)
    }
}

// Mock Services
final class MockHabitRepository: HabitRepositoryProtocol {
    var habits: [Habit] = []
    
    func fetchActiveHabits() async throws -> [Habit] {
        return habits.filter { $0.isActive }
    }
    
    func save(_ habit: Habit) async throws {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
    }
}

// Test Example
final class HabitsListViewModelTests: BaseTestCase {
    private var viewModel: HabitsListViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = HabitsListViewModel(
            habitRepository: services.habitRepository,
            gameService: services.gameService
        )
    }
    
    func testLoadHabits() async throws {
        // Given
        let testHabits = [
            Habit(name: "Test Habit 1"),
            Habit(name: "Test Habit 2")
        ]
        services.habitRepository.habits = testHabits
        
        // When
        viewModel.send(.loadHabits)
        
        // Wait for async operation
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        XCTAssertEqual(viewModel.state.habits.count, 2)
        XCTAssertFalse(viewModel.state.isLoading)
        XCTAssertNil(viewModel.state.error)
    }
}
```

---

Эта архитектура обеспечивает:

✅ **Масштабируемость** - модульная структура позволяет легко добавлять новые функции
✅ **Тестируемость** - четкое разделение ответственности и dependency injection
✅ **Производительность** - оптимизированные решения для работы с данными
✅ **Современность** - использование последних технологий iOS
✅ **Безопасность** - защита данных и конфиденциальности пользователей

Используйте этот документ как руководство при реализации каждого компонента приложения. 