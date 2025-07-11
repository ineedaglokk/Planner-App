import Foundation
import SwiftData
import SwiftUI

// MARK: - Service Container Protocol
protocol ServiceContainerProtocol {
    var dataService: DataServiceProtocol { get }
    var notificationService: NotificationServiceProtocol { get }
    var userDefaultsService: UserDefaultsServiceProtocol { get }
    var errorHandlingService: ErrorHandlingServiceProtocol { get }
    var habitService: HabitServiceProtocol { get }
    
    func initializeAllServices() async throws
    func cleanupAllServices() async
}

// MARK: - ServiceContainer Implementation
@Observable
final class ServiceContainer: ServiceContainerProtocol {
    
    // MARK: - Properties
    private let modelContainer: ModelContainer
    private var isInitialized: Bool = false
    
    // Services with lazy initialization
    private var _dataService: DataServiceProtocol?
    private var _notificationService: NotificationServiceProtocol?
    private var _userDefaultsService: UserDefaultsServiceProtocol?
    private var _errorHandlingService: ErrorHandlingServiceProtocol?
    private var _habitService: HabitServiceProtocol?
    
    // Service initialization queue
    private let serviceQueue = DispatchQueue(label: "com.plannerapp.services", qos: .userInitiated)
    
    // MARK: - Initialization
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    convenience init() {
        self.init(modelContainer: ModelContainer.shared)
    }
    
    // MARK: - Service Access Properties
    
    var dataService: DataServiceProtocol {
        if let service = _dataService {
            return service
        }
        
        let service = DataService(modelContainer: modelContainer)
        _dataService = service
        
        // Инициализируем сервис асинхронно если контейнер уже инициализирован
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var notificationService: NotificationServiceProtocol {
        if let service = _notificationService {
            return service
        }
        
        let service = NotificationService()
        _notificationService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var userDefaultsService: UserDefaultsServiceProtocol {
        if let service = _userDefaultsService {
            return service
        }
        
        let service = UserDefaultsService()
        _userDefaultsService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var errorHandlingService: ErrorHandlingServiceProtocol {
        if let service = _errorHandlingService {
            return service
        }
        
        let service = ErrorHandlingService()
        _errorHandlingService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var habitService: HabitServiceProtocol {
        if let service = _habitService {
            return service
        }
        
        let habitRepository = HabitRepository(dataService: dataService)
        let service = HabitService(
            habitRepository: habitRepository,
            notificationService: notificationService
        )
        _habitService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    // MARK: - Service Lifecycle
    
    func initializeAllServices() async throws {
        guard !isInitialized else {
            #if DEBUG
            print("ServiceContainer already initialized")
            #endif
            return
        }
        
        do {
            #if DEBUG
            print("Initializing ServiceContainer...")
            #endif
            
            // Инициализируем сервисы в правильном порядке
            
            // 1. Сначала ErrorHandlingService для обработки ошибок других сервисов
            try await errorHandlingService.initialize()
            
            // 2. UserDefaultsService для настроек
            try await userDefaultsService.initialize()
            
            // 3. DataService для работы с данными
            try await dataService.initialize()
            
            // 4. NotificationService последним, так как может зависеть от настроек
            try await notificationService.initialize()
            
            // 5. HabitService после всех зависимостей
            try await habitService.initialize()
            
            // Настраиваем связи между сервисами
            setupServiceDependencies()
            
            isInitialized = true
            
            #if DEBUG
            print("ServiceContainer initialized successfully")
            #endif
            
        } catch {
            // Если инициализация не удалась, очищаем частично инициализированные сервисы
            await cleanupAllServices()
            
            let appError = AppError.from(error)
            await errorHandlingService.handle(appError, context: .initialization("ServiceContainer initialization failed"))
            
            throw appError
        }
    }
    
    func cleanupAllServices() async {
        #if DEBUG
        print("Cleaning up ServiceContainer...")
        #endif
        
        // Очищаем сервисы в обратном порядке инициализации
        if let habitService = _habitService {
            await habitService.cleanup()
        }
        
        if let notificationService = _notificationService {
            await notificationService.cleanup()
        }
        
        if let dataService = _dataService {
            await dataService.cleanup()
        }
        
        if let userDefaultsService = _userDefaultsService {
            await userDefaultsService.cleanup()
        }
        
        if let errorHandlingService = _errorHandlingService {
            await errorHandlingService.cleanup()
        }
        
        // Обнуляем ссылки
        _dataService = nil
        _notificationService = nil
        _userDefaultsService = nil
        _errorHandlingService = nil
        _habitService = nil
        
        isInitialized = false
        
        #if DEBUG
        print("ServiceContainer cleaned up")
        #endif
    }
    
    // MARK: - Private Methods
    
    private func setupServiceDependencies() {
        // Настраиваем ErrorHandlingService как презентационный делегат
        // для отображения ошибок (это будет реализовано на уровне UI)
        
        #if DEBUG
        print("Service dependencies configured")
        #endif
    }
}

// MARK: - ServiceContainer Extensions

extension ServiceContainer {
    
    // MARK: - Convenience Methods
    
    /// Проверяет готовность всех сервисов
    var allServicesReady: Bool {
        return isInitialized &&
               (_dataService?.isInitialized ?? false) &&
               (_notificationService?.isInitialized ?? false) &&
               (_userDefaultsService?.isInitialized ?? false) &&
               (_errorHandlingService?.isInitialized ?? false) &&
               (_habitService?.isInitialized ?? false)
    }
    
    /// Возвращает статус каждого сервиса
    var serviceStatus: [String: Bool] {
        return [
            "DataService": _dataService?.isInitialized ?? false,
            "NotificationService": _notificationService?.isInitialized ?? false,
            "UserDefaultsService": _userDefaultsService?.isInitialized ?? false,
            "ErrorHandlingService": _errorHandlingService?.isInitialized ?? false,
            "HabitService": _habitService?.isInitialized ?? false
        ]
    }
    
    /// Перезапускает конкретный сервис
    func restartService<T: ServiceProtocol>(_ serviceType: T.Type) async throws {
        switch serviceType {
        case is DataServiceProtocol.Type:
            if let service = _dataService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is NotificationServiceProtocol.Type:
            if let service = _notificationService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is UserDefaultsServiceProtocol.Type:
            if let service = _userDefaultsService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is ErrorHandlingServiceProtocol.Type:
            if let service = _errorHandlingService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is HabitServiceProtocol.Type:
            if let service = _habitService {
                await service.cleanup()
                try await service.initialize()
            }
            
        default:
            throw AppError.serviceUnavailable("Unknown service type")
        }
    }
}

// MARK: - Factory Methods

extension ServiceContainer {
    
    /// Создает ServiceContainer для тестирования
    static func testing() -> ServiceContainer {
        let container = ServiceContainer(modelContainer: ModelContainer.testing())
        return container
    }
    
    /// Создает ServiceContainer для превью SwiftUI
    static func preview() -> ServiceContainer {
        let container = ServiceContainer(modelContainer: ModelContainer.preview)
        return container
    }
    
    /// Создает ServiceContainer с mock сервисами
    static func mock() -> ServiceContainer {
        let container = MockServiceContainer()
        return container
    }
}

// MARK: - SwiftUI Environment Integration

// Environment Key для ServiceContainer
struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainerProtocol = ServiceContainer()
}

extension EnvironmentValues {
    var services: ServiceContainerProtocol {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - View Modifier для инициализации сервисов

struct ServiceContainerModifier: ViewModifier {
    let container: ServiceContainerProtocol
    @State private var isInitialized = false
    @State private var initializationError: AppError?
    
    func body(content: Content) -> some View {
        content
            .environment(\.services, container)
            .task {
                guard !isInitialized else { return }
                
                do {
                    try await container.initializeAllServices()
                    isInitialized = true
                } catch {
                    initializationError = AppError.from(error)
                }
            }
            .alert("Ошибка инициализации", isPresented: .constant(initializationError != nil)) {
                Button("Повторить") {
                    Task {
                        initializationError = nil
                        do {
                            try await container.initializeAllServices()
                            isInitialized = true
                        } catch {
                            initializationError = AppError.from(error)
                        }
                    }
                }
                Button("Закрыть", role: .cancel) {
                    initializationError = nil
                }
            } message: {
                if let error = initializationError {
                    Text(error.localizedDescription)
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Подключает ServiceContainer к View
    func withServices(_ container: ServiceContainerProtocol = ServiceContainer()) -> some View {
        self.modifier(ServiceContainerModifier(container: container))
    }
}

// MARK: - Mock ServiceContainer для тестирования

final class MockServiceContainer: ServiceContainer {
    
    override init(modelContainer: ModelContainer) {
        super.init(modelContainer: modelContainer)
        
        // Устанавливаем mock сервисы
        _dataService = MockDataService()
        _notificationService = MockNotificationService()
        _userDefaultsService = MockUserDefaultsService()
        _errorHandlingService = MockErrorHandlingService()
        _habitService = MockHabitService()
    }
    
    convenience init() {
        self.init(modelContainer: ModelContainer.testing())
    }
    
    override func initializeAllServices() async throws {
        // Mock сервисы не требуют реальной инициализации
        #if DEBUG
        print("MockServiceContainer initialized")
        #endif
    }
    
    override func cleanupAllServices() async {
        #if DEBUG
        print("MockServiceContainer cleaned up")
        #endif
    }
}

// MARK: - Mock Services

// Mock DataService
private final class MockDataService: DataServiceProtocol {
    var modelContainer: ModelContainer = ModelContainer.testing()
    var modelContext: ModelContext { modelContainer.mainContext }
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T] {
        return []
    }
    
    func fetchOne<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) async throws -> T? {
        return nil
    }
    
    func save<T: PersistentModel>(_ model: T) async throws { }
    func update<T: PersistentModel>(_ model: T) async throws { }
    func delete<T: PersistentModel>(_ model: T) async throws { }
    func batchSave<T: PersistentModel>(_ models: [T]) async throws { }
    func batchDelete<T: PersistentModel>(_ models: [T]) async throws { }
    func markForSync<T: PersistentModel>(_ model: T) async throws { }
    func performBatchSync() async throws { }
}

// Mock NotificationService
private final class MockNotificationService: NotificationServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    func requestPermission() async -> Bool { return true }
    func checkPermissionStatus() async -> UNAuthorizationStatus { return .authorized }
    func scheduleHabitReminder(_ habitID: UUID, name: String, time: Date) async throws { }
    func scheduleTaskDeadline(_ taskID: UUID, title: String, deadline: Date) async throws { }
    func scheduleBudgetAlert(_ budgetID: UUID, title: String, amount: Decimal) async throws { }
    func cancelNotification(for identifier: String) async { }
    func cancelAllNotifications() async { }
    func getPendingNotifications() async -> [UNNotificationRequest] { return [] }
    func handleNotificationResponse(_ response: UNNotificationResponse) async { }
}

// Mock UserDefaultsService
private final class MockUserDefaultsService: UserDefaultsServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    var themeMode: ThemeMode = .system
    var accentColor: String = "#007AFF"
    var isFirstLaunch: Bool = false
    var hasCompletedOnboarding: Bool = true
    var onboardingVersion: String = "1.0"
    var isCloudSyncEnabled: Bool = true
    var isAnalyticsEnabled: Bool = true
    var isNotificationsEnabled: Bool = true
    var defaultHabitReminderTime: Date = Date()
    var weekStartsOn: WeekDay = .monday
    var preferredLanguage: String = "ru"
    var isBiometricEnabled: Bool = false
    var autoLockTimeout: TimeInterval = 300
    
    func setValue<T>(_ value: T, for key: UserDefaultsKey) where T: Codable { }
    func getValue<T>(_ type: T.Type, for key: UserDefaultsKey) -> T? where T: Codable { return nil }
    func removeValue(for key: UserDefaultsKey) { }
    func reset() { }
}

// Mock ErrorHandlingService
private final class MockErrorHandlingService: ErrorHandlingServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    func handle(_ error: Error, context: ErrorContext?) async { }
    func handle(_ error: AppError, context: ErrorContext?) async { }
    func presentError(_ error: AppError, in view: ErrorPresentationView) async { }
    func presentErrorAlert(_ error: AppError, completion: @escaping () -> Void) async { completion() }
    func logError(_ error: Error, context: ErrorContext?) { }
    func logCriticalError(_ error: Error, context: ErrorContext?) { }
    func attemptRecovery(for error: AppError) async -> Bool { return false }
    func getRecoveryOptions(for error: AppError) -> [RecoveryOption] { return [] }
}

// Mock HabitService
private final class MockHabitService: HabitServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func getActiveHabits() async throws -> [Habit] { return [] }
    func getTodayHabits() async throws -> [Habit] { return [] }
    func getHabit(by id: UUID) async throws -> Habit? { return nil }
    func createHabit(_ habit: Habit) async throws { }
    func updateHabit(_ habit: Habit) async throws { }
    func deleteHabit(_ habit: Habit) async throws { }
    func toggleHabitCompletion(_ habit: Habit, date: Date) async throws -> Bool { return false }
    func markHabitComplete(_ habit: Habit, date: Date, value: Int?) async throws -> HabitEntry {
        return HabitEntry(habit: habit, date: date, value: value ?? 1)
    }
    func incrementHabitValue(_ habit: Habit, date: Date, by amount: Int) async throws -> HabitEntry {
        return HabitEntry(habit: habit, date: date, value: amount)
    }
    func getHabitStatistics(_ habit: Habit, period: StatisticsPeriod) async throws -> HabitStatistics {
        return HabitStatistics(
            habit: habit,
            period: period,
            entries: [],
            currentStreak: 0,
            longestStreak: 0,
            completionRate: 0.0,
            totalCompletions: 0,
            bestDayResult: 0
        )
    }
    func scheduleHabitReminders(_ habit: Habit) async throws { }
    func cancelHabitReminders(_ habit: Habit) async throws { }
    func archiveHabit(_ habit: Habit) async throws { }
    func unarchiveHabit(_ habit: Habit) async throws { }
} 