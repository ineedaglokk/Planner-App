import Foundation
import SwiftData
import UserNotifications

// MARK: - Mock Service Factory

final class MockServiceFactory {
    
    /// Создает полный набор mock сервисов для тестирования
    static func createMockServices() -> ServiceContainerProtocol {
        return MockServiceContainer()
    }
    
    /// Создает mock сервис с настраиваемым поведением
    static func createMockServiceContainer(
        dataServiceBehavior: MockDataServiceBehavior = .normal,
        notificationServiceBehavior: MockNotificationServiceBehavior = .normal,
        userDefaultsServiceBehavior: MockUserDefaultsServiceBehavior = .normal,
        errorHandlingServiceBehavior: MockErrorHandlingServiceBehavior = .normal
    ) -> ServiceContainerProtocol {
        return ConfigurableMockServiceContainer(
            dataServiceBehavior: dataServiceBehavior,
            notificationServiceBehavior: notificationServiceBehavior,
            userDefaultsServiceBehavior: userDefaultsServiceBehavior,
            errorHandlingServiceBehavior: errorHandlingServiceBehavior
        )
    }
}

// MARK: - Mock Behavior Enums

enum MockDataServiceBehavior {
    case normal
    case saveFails
    case fetchFails
    case syncFails
    case slow // Добавляет задержки
}

enum MockNotificationServiceBehavior {
    case normal
    case permissionDenied
    case schedulingFails
    case slow
}

enum MockUserDefaultsServiceBehavior {
    case normal
    case firstLaunch
    case onboardingIncomplete
}

enum MockErrorHandlingServiceBehavior {
    case normal
    case allErrorsCritical
    case recoveryAlwaysFails
}

// MARK: - Configurable Mock ServiceContainer

final class ConfigurableMockServiceContainer: ServiceContainerProtocol {
    
    private let _dataService: DataServiceProtocol
    private let _notificationService: NotificationServiceProtocol
    private let _userDefaultsService: UserDefaultsServiceProtocol
    private let _errorHandlingService: ErrorHandlingServiceProtocol
    
    init(
        dataServiceBehavior: MockDataServiceBehavior,
        notificationServiceBehavior: MockNotificationServiceBehavior,
        userDefaultsServiceBehavior: MockUserDefaultsServiceBehavior,
        errorHandlingServiceBehavior: MockErrorHandlingServiceBehavior
    ) {
        self._dataService = ConfigurableMockDataService(behavior: dataServiceBehavior)
        self._notificationService = ConfigurableMockNotificationService(behavior: notificationServiceBehavior)
        self._userDefaultsService = ConfigurableMockUserDefaultsService(behavior: userDefaultsServiceBehavior)
        self._errorHandlingService = ConfigurableMockErrorHandlingService(behavior: errorHandlingServiceBehavior)
    }
    
    var dataService: DataServiceProtocol { _dataService }
    var notificationService: NotificationServiceProtocol { _notificationService }
    var userDefaultsService: UserDefaultsServiceProtocol { _userDefaultsService }
    var errorHandlingService: ErrorHandlingServiceProtocol { _errorHandlingService }
    
    func initializeAllServices() async throws {
        try await dataService.initialize()
        try await notificationService.initialize()
        try await userDefaultsService.initialize()
        try await errorHandlingService.initialize()
    }
    
    func cleanupAllServices() async {
        await dataService.cleanup()
        await notificationService.cleanup()
        await userDefaultsService.cleanup()
        await errorHandlingService.cleanup()
    }
}

// MARK: - Configurable Mock DataService

final class ConfigurableMockDataService: DataServiceProtocol {
    
    var modelContainer: ModelContainer = ModelContainer.testing()
    var modelContext: ModelContext { modelContainer.mainContext }
    private(set) var isInitialized: Bool = false
    
    private let behavior: MockDataServiceBehavior
    private var storage: [String: [Any]] = [:]
    
    init(behavior: MockDataServiceBehavior) {
        self.behavior = behavior
    }
    
    func initialize() async throws {
        if behavior == .slow {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
        }
        isInitialized = true
    }
    
    func cleanup() async {
        storage.removeAll()
        isInitialized = false
    }
    
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>? = nil) async throws -> [T] {
        if behavior == .fetchFails {
            throw AppError.fetchFailed("Mock fetch failure")
        }
        
        if behavior == .slow {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        }
        
        let key = String(describing: type)
        return storage[key] as? [T] ?? []
    }
    
    func fetchOne<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) async throws -> T? {
        let results: [T] = try await fetch(type, predicate: predicate)
        return results.first
    }
    
    func save<T: PersistentModel>(_ model: T) async throws {
        if behavior == .saveFails {
            throw AppError.saveFailed("Mock save failure")
        }
        
        if behavior == .slow {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 секунды
        }
        
        let key = String(describing: type(of: model))
        var items = storage[key] ?? []
        items.append(model)
        storage[key] = items
    }
    
    func update<T: PersistentModel>(_ model: T) async throws {
        // Mock implementation
    }
    
    func delete<T: PersistentModel>(_ model: T) async throws {
        let key = String(describing: type(of: model))
        storage[key] = []
    }
    
    func batchSave<T: PersistentModel>(_ models: [T]) async throws {
        for model in models {
            try await save(model)
        }
    }
    
    func batchDelete<T: PersistentModel>(_ models: [T]) async throws {
        for model in models {
            try await delete(model)
        }
    }
    
    func markForSync<T: PersistentModel>(_ model: T) async throws {
        if behavior == .syncFails {
            throw AppError.syncFailed("Mock sync marking failure")
        }
    }
    
    func performBatchSync() async throws {
        if behavior == .syncFails {
            throw AppError.syncFailed("Mock batch sync failure")
        }
        
        if behavior == .slow {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 секунды
        }
    }
}

// MARK: - Configurable Mock NotificationService

final class ConfigurableMockNotificationService: NotificationServiceProtocol {
    
    private(set) var isInitialized: Bool = false
    private let behavior: MockNotificationServiceBehavior
    private var scheduledNotifications: [String: MockNotification] = [:]
    
    init(behavior: MockNotificationServiceBehavior) {
        self.behavior = behavior
    }
    
    func initialize() async throws {
        if behavior == .slow {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        isInitialized = true
    }
    
    func cleanup() async {
        scheduledNotifications.removeAll()
        isInitialized = false
    }
    
    func requestPermission() async -> Bool {
        if behavior == .permissionDenied {
            return false
        }
        
        if behavior == .slow {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        return true
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        switch behavior {
        case .permissionDenied:
            return .denied
        default:
            return .authorized
        }
    }
    
    func scheduleHabitReminder(_ habitID: UUID, name: String, time: Date) async throws {
        if behavior == .schedulingFails {
            throw AppError.notificationSchedulingFailed("Mock scheduling failure")
        }
        
        let identifier = "habit-\(habitID.uuidString)"
        let notification = MockNotification(
            identifier: identifier,
            title: "Время для привычки",
            body: "Не забудьте выполнить: \(name)",
            type: .habitReminder
        )
        
        scheduledNotifications[identifier] = notification
    }
    
    func scheduleTaskDeadline(_ taskID: UUID, title: String, deadline: Date) async throws {
        if behavior == .schedulingFails {
            throw AppError.notificationSchedulingFailed("Mock scheduling failure")
        }
        
        let identifier = "task-\(taskID.uuidString)"
        let notification = MockNotification(
            identifier: identifier,
            title: "Приближается дедлайн задачи",
            body: "Через час истекает срок выполнения: \(title)",
            type: .taskDeadline
        )
        
        scheduledNotifications[identifier] = notification
    }
    
    func scheduleBudgetAlert(_ budgetID: UUID, title: String, amount: Decimal) async throws {
        if behavior == .schedulingFails {
            throw AppError.notificationSchedulingFailed("Mock scheduling failure")
        }
        
        let identifier = "budget-\(budgetID.uuidString)"
        let notification = MockNotification(
            identifier: identifier,
            title: "Превышение бюджета",
            body: "Бюджет '\(title)' превышен на \(amount) ₽",
            type: .budgetAlert
        )
        
        scheduledNotifications[identifier] = notification
    }
    
    func cancelNotification(for identifier: String) async {
        scheduledNotifications.removeValue(forKey: identifier)
    }
    
    func cancelAllNotifications() async {
        scheduledNotifications.removeAll()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        // Возвращаем пустой массив для mock
        return []
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        // Mock implementation
    }
    
    // Helper methods для тестирования
    var scheduledNotificationCount: Int {
        return scheduledNotifications.count
    }
    
    func getScheduledNotification(for identifier: String) -> MockNotification? {
        return scheduledNotifications[identifier]
    }
}

// MARK: - Configurable Mock UserDefaultsService

final class ConfigurableMockUserDefaultsService: UserDefaultsServiceProtocol {
    
    private(set) var isInitialized: Bool = false
    private let behavior: MockUserDefaultsServiceBehavior
    private var storage: [String: Any] = [:]
    
    init(behavior: MockUserDefaultsServiceBehavior) {
        self.behavior = behavior
        setupInitialValues()
    }
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        isInitialized = false
    }
    
    // MARK: - Properties with behavior-based values
    
    var themeMode: ThemeMode {
        get { getValue(ThemeMode.self, for: .themeMode) ?? .system }
        set { setValue(newValue, for: .themeMode) }
    }
    
    var accentColor: String {
        get { getValue(String.self, for: .accentColor) ?? "#007AFF" }
        set { setValue(newValue, for: .accentColor) }
    }
    
    var isFirstLaunch: Bool {
        get {
            switch behavior {
            case .firstLaunch:
                return true
            default:
                return getValue(Bool.self, for: .isFirstLaunch) ?? false
            }
        }
        set { setValue(newValue, for: .isFirstLaunch) }
    }
    
    var hasCompletedOnboarding: Bool {
        get {
            switch behavior {
            case .onboardingIncomplete:
                return false
            default:
                return getValue(Bool.self, for: .hasCompletedOnboarding) ?? true
            }
        }
        set { setValue(newValue, for: .hasCompletedOnboarding) }
    }
    
    var onboardingVersion: String {
        get { getValue(String.self, for: .onboardingVersion) ?? "1.0" }
        set { setValue(newValue, for: .onboardingVersion) }
    }
    
    var isCloudSyncEnabled: Bool {
        get { getValue(Bool.self, for: .isCloudSyncEnabled) ?? true }
        set { setValue(newValue, for: .isCloudSyncEnabled) }
    }
    
    var isAnalyticsEnabled: Bool {
        get { getValue(Bool.self, for: .isAnalyticsEnabled) ?? true }
        set { setValue(newValue, for: .isAnalyticsEnabled) }
    }
    
    var isNotificationsEnabled: Bool {
        get { getValue(Bool.self, for: .isNotificationsEnabled) ?? true }
        set { setValue(newValue, for: .isNotificationsEnabled) }
    }
    
    var defaultHabitReminderTime: Date {
        get { getValue(Date.self, for: .defaultHabitReminderTime) ?? Date() }
        set { setValue(newValue, for: .defaultHabitReminderTime) }
    }
    
    var weekStartsOn: WeekDay {
        get { getValue(WeekDay.self, for: .weekStartsOn) ?? .monday }
        set { setValue(newValue, for: .weekStartsOn) }
    }
    
    var preferredLanguage: String {
        get { getValue(String.self, for: .preferredLanguage) ?? "ru" }
        set { setValue(newValue, for: .preferredLanguage) }
    }
    
    var isBiometricEnabled: Bool {
        get { getValue(Bool.self, for: .isBiometricEnabled) ?? false }
        set { setValue(newValue, for: .isBiometricEnabled) }
    }
    
    var autoLockTimeout: TimeInterval {
        get { getValue(TimeInterval.self, for: .autoLockTimeout) ?? 300 }
        set { setValue(newValue, for: .autoLockTimeout) }
    }
    
    // MARK: - Generic Methods
    
    func setValue<T>(_ value: T, for key: UserDefaultsKey) where T: Codable {
        storage[key.rawValue] = value
    }
    
    func getValue<T>(_ type: T.Type, for key: UserDefaultsKey) -> T? where T: Codable {
        return storage[key.rawValue] as? T
    }
    
    func removeValue(for key: UserDefaultsKey) {
        storage.removeValue(forKey: key.rawValue)
    }
    
    func reset() {
        storage.removeAll()
        setupInitialValues()
    }
    
    private func setupInitialValues() {
        switch behavior {
        case .firstLaunch:
            setValue(true, for: .isFirstLaunch)
            setValue(false, for: .hasCompletedOnboarding)
        case .onboardingIncomplete:
            setValue(false, for: .isFirstLaunch)
            setValue(false, for: .hasCompletedOnboarding)
        case .normal:
            setValue(false, for: .isFirstLaunch)
            setValue(true, for: .hasCompletedOnboarding)
        }
        
        setValue(ThemeMode.system, for: .themeMode)
        setValue("#007AFF", for: .accentColor)
        setValue("1.0", for: .onboardingVersion)
        setValue(true, for: .isCloudSyncEnabled)
        setValue(true, for: .isAnalyticsEnabled)
        setValue(true, for: .isNotificationsEnabled)
        setValue(Date(), for: .defaultHabitReminderTime)
        setValue(WeekDay.monday, for: .weekStartsOn)
        setValue("ru", for: .preferredLanguage)
        setValue(false, for: .isBiometricEnabled)
        setValue(300.0, for: .autoLockTimeout)
    }
}

// MARK: - Configurable Mock ErrorHandlingService

final class ConfigurableMockErrorHandlingService: ErrorHandlingServiceProtocol {
    
    private(set) var isInitialized: Bool = false
    private let behavior: MockErrorHandlingServiceBehavior
    private var handledErrors: [AppError] = []
    
    init(behavior: MockErrorHandlingServiceBehavior) {
        self.behavior = behavior
    }
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        handledErrors.removeAll()
        isInitialized = false
    }
    
    func handle(_ error: Error, context: ErrorContext?) async {
        let appError = AppError.from(error)
        await handle(appError, context: context)
    }
    
    func handle(_ error: AppError, context: ErrorContext?) async {
        handledErrors.append(error)
    }
    
    func presentError(_ error: AppError, in view: ErrorPresentationView) async {
        handledErrors.append(error)
    }
    
    func presentErrorAlert(_ error: AppError, completion: @escaping () -> Void) async {
        handledErrors.append(error)
        completion()
    }
    
    func logError(_ error: Error, context: ErrorContext?) {
        let appError = AppError.from(error)
        handledErrors.append(appError)
    }
    
    func logCriticalError(_ error: Error, context: ErrorContext?) {
        let appError = AppError.from(error)
        handledErrors.append(appError)
    }
    
    func attemptRecovery(for error: AppError) async -> Bool {
        switch behavior {
        case .recoveryAlwaysFails:
            return false
        default:
            return error.canRetry
        }
    }
    
    func getRecoveryOptions(for error: AppError) -> [RecoveryOption] {
        return [
            RecoveryOption(
                title: "Повторить",
                description: "Попробовать снова",
                action: .retry
            ),
            RecoveryOption(
                title: "Закрыть",
                description: "Закрыть сообщение",
                action: .dismissError
            )
        ]
    }
    
    // Helper methods для тестирования
    var handledErrorCount: Int {
        return handledErrors.count
    }
    
    func getHandledErrors() -> [AppError] {
        return handledErrors
    }
    
    func clearHandledErrors() {
        handledErrors.removeAll()
    }
}

// MARK: - Supporting Types

struct MockNotification {
    let identifier: String
    let title: String
    let body: String
    let type: MockNotificationType
}

enum MockNotificationType {
    case habitReminder
    case taskDeadline
    case budgetAlert
    case achievement
}

// MARK: - Mock Service Extensions

extension ConfigurableMockDataService {
    
    /// Добавляет тестовые данные в хранилище
    func addMockData<T: PersistentModel>(_ items: [T]) {
        let key = String(describing: T.self)
        storage[key] = items
    }
    
    /// Возвращает количество сохраненных элементов определенного типа
    func getMockDataCount<T: PersistentModel>(for type: T.Type) -> Int {
        let key = String(describing: type)
        return (storage[key] as? [T])?.count ?? 0
    }
    
    /// Очищает все mock данные
    func clearAllMockData() {
        storage.removeAll()
    }
} 