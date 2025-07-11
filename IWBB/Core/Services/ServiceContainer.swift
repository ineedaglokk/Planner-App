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
    var taskService: TaskServiceProtocol { get }
    
    // Finance Services
    var transactionRepository: TransactionRepositoryProtocol { get }
    var financeService: FinanceServiceProtocol { get }
    var categoryService: CategoryServiceProtocol { get }
    var currencyService: CurrencyServiceProtocol { get }
    
    // Advanced Tasks & Goals Services
    var projectManagementService: ProjectManagementServiceProtocol { get }
    var timeBlockingService: TimeBlockingServiceProtocol { get }
    var templateService: TemplateServiceProtocol { get }
    
    // Integration Services
    var eventKitIntegrationService: EventKitIntegrationServiceProtocol { get }
    
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
    private var _taskService: TaskServiceProtocol?
    
    // Finance Services
    private var _transactionRepository: TransactionRepositoryProtocol?
    private var _financeService: FinanceServiceProtocol?
    private var _categoryService: CategoryServiceProtocol?
    private var _currencyService: CurrencyServiceProtocol?
    
    // Advanced Services
    private var _projectManagementService: ProjectManagementServiceProtocol?
    private var _timeBlockingService: TimeBlockingServiceProtocol?
    private var _templateService: TemplateServiceProtocol?
    
    // Integration Services
    private var _eventKitIntegrationService: EventKitIntegrationServiceProtocol?
    
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
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let service = MockNotificationService()
            _notificationService = service
            return service
        }
        #endif
        
        let service = NotificationService.shared
        _notificationService = service
        
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
    
    var taskService: TaskServiceProtocol {
        if let service = _taskService {
            return service
        }
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let service = MockTaskService()
            _taskService = service
            return service
        }
        #endif
        
        let taskRepository = TaskRepository(modelContext: modelContainer.mainContext)
        let dateParser = DateParser()
        let service = TaskService(
            repository: taskRepository,
            dateParser: dateParser,
            notificationService: notificationService
        )
        _taskService = service
        
        // Set up bidirectional dependency
        if let notificationService = notificationService as? NotificationService {
            notificationService.setTaskService(service)
        }
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    // MARK: - Finance Services Access Properties
    
    var transactionRepository: TransactionRepositoryProtocol {
        if let repository = _transactionRepository {
            return repository
        }
        
        let repository = TransactionRepository(
            modelContext: modelContainer.mainContext,
            syncService: SyncService() // Placeholder, нужно будет реализовать SyncService
        )
        _transactionRepository = repository
        
        return repository
    }
    
    var financeService: FinanceServiceProtocol {
        if let service = _financeService {
            return service
        }
        
        let service = FinanceService(
            transactionRepository: transactionRepository,
            categoryService: categoryService,
            currencyService: currencyService,
            dataService: dataService,
            notificationService: notificationService
        )
        _financeService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var categoryService: CategoryServiceProtocol {
        if let service = _categoryService {
            return service
        }
        
        let service = CategoryService(
            dataService: dataService,
            mlService: nil // ML service placeholder
        )
        _categoryService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var currencyService: CurrencyServiceProtocol {
        if let service = _currencyService {
            return service
        }
        
        let service = CurrencyService(
            dataService: dataService,
            userDefaultsService: userDefaultsService,
            notificationService: notificationService
        )
        _currencyService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    // MARK: - Advanced Services Access Properties
    
    var projectManagementService: ProjectManagementServiceProtocol {
        if let service = _projectManagementService {
            return service
        }
        
        let service = ProjectManagementService(
            dataService: dataService,
            notificationService: notificationService,
            templateService: templateService
        )
        _projectManagementService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var timeBlockingService: TimeBlockingServiceProtocol {
        if let service = _timeBlockingService {
            return service
        }
        
        let calendarService = SimpleCalendarService()
        let service = TimeBlockingService(
            dataService: dataService,
            calendarService: calendarService,
            notificationService: notificationService
        )
        _timeBlockingService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    var templateService: TemplateServiceProtocol {
        if let service = _templateService {
            return service
        }
        
        let analyticsService = SimpleAnalyticsService()
        let service = TemplateService(
            dataService: dataService,
            cloudService: nil,
            analyticsService: analyticsService
        )
        _templateService = service
        
        if isInitialized {
            Task {
                try? await service.initialize()
            }
        }
        
        return service
    }
    
    // MARK: - Integration Services Access Properties
    
    var eventKitIntegrationService: EventKitIntegrationServiceProtocol {
        if let service = _eventKitIntegrationService {
            return service
        }
        
        let service = EventKitIntegrationService(
            dataService: dataService,
            userDefaultsService: userDefaultsService
        )
        _eventKitIntegrationService = service
        
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
            
            // 6. TaskService после всех зависимостей
            try await taskService.initialize()
            
            // 7. Finance Services after all dependencies
            try await initializeFinanceServices()
            
            // 8. Advanced Services after all dependencies
            try await initializeAdvancedServices()
            
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
        if let templateService = _templateService {
            await templateService.cleanup()
        }
        
        if let timeBlockingService = _timeBlockingService {
            await timeBlockingService.cleanup()
        }
        
        if let projectManagementService = _projectManagementService {
            await projectManagementService.cleanup()
        }
        
        if let taskService = _taskService {
            await taskService.cleanup()
        }
        
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
        
        // Cleanup finance services
        if let currencyService = _currencyService {
            await currencyService.cleanup()
        }
        
        if let categoryService = _categoryService {
            await categoryService.cleanup()
        }
        
        if let financeService = _financeService {
            await financeService.cleanup()
        }
        
        if let transactionRepository = _transactionRepository {
            await transactionRepository.cleanup()
        }
        
        // Обнуляем ссылки
        _dataService = nil
        _notificationService = nil
        _userDefaultsService = nil
        _errorHandlingService = nil
        _habitService = nil
        _taskService = nil
        _transactionRepository = nil
        _financeService = nil
        _categoryService = nil
        _currencyService = nil
        _projectManagementService = nil
        _timeBlockingService = nil
        _templateService = nil
        
        isInitialized = false
        
        #if DEBUG
        print("ServiceContainer cleaned up")
        #endif
    }
    
    // MARK: - Private Methods
    
    private func initializeFinanceServices() async throws {
        #if DEBUG
        print("Initializing Finance Services...")
        #endif
        
        // Initialize services in correct order considering dependencies
        // CategoryService first (no dependencies on other finance services)
        try await categoryService.initialize()
        
        // CurrencyService next (no dependencies on other finance services)
        try await currencyService.initialize()
        
        // TransactionRepository (depends on data service which is already initialized)
        try await transactionRepository.initialize()
        
        // FinanceService last (depends on all other finance services)
        try await financeService.initialize()
        
        #if DEBUG
        print("Finance Services initialized successfully")
        #endif
    }
    
    private func initializeAdvancedServices() async throws {
        #if DEBUG
        print("Initializing Advanced Services...")
        #endif
        
        try await projectManagementService.initialize()
        try await timeBlockingService.initialize()
        try await templateService.initialize()
        
        #if DEBUG
        print("Advanced Services initialized successfully")
        #endif
    }
    
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
               (_habitService?.isInitialized ?? false) &&
               (_taskService?.isInitialized ?? false) &&
               (_transactionRepository?.isInitialized ?? false) &&
               (_financeService?.isInitialized ?? false) &&
               (_categoryService?.isInitialized ?? false) &&
               (_currencyService?.isInitialized ?? false) &&
               (_projectManagementService?.isInitialized ?? false) &&
               (_timeBlockingService?.isInitialized ?? false) &&
               (_templateService?.isInitialized ?? false)
    }
    
    /// Возвращает статус каждого сервиса
    var serviceStatus: [String: Bool] {
        return [
            "DataService": _dataService?.isInitialized ?? false,
            "NotificationService": _notificationService?.isInitialized ?? false,
            "UserDefaultsService": _userDefaultsService?.isInitialized ?? false,
            "ErrorHandlingService": _errorHandlingService?.isInitialized ?? false,
            "HabitService": _habitService?.isInitialized ?? false,
            "TaskService": _taskService?.isInitialized ?? false,
            "TransactionRepository": _transactionRepository?.isInitialized ?? false,
            "FinanceService": _financeService?.isInitialized ?? false,
            "CategoryService": _categoryService?.isInitialized ?? false,
            "CurrencyService": _currencyService?.isInitialized ?? false,
            "ProjectManagementService": _projectManagementService?.isInitialized ?? false,
            "TimeBlockingService": _timeBlockingService?.isInitialized ?? false,
            "TemplateService": _templateService?.isInitialized ?? false
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
            
        case is TaskServiceProtocol.Type:
            if let service = _taskService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is TransactionRepositoryProtocol.Type:
            if let repository = _transactionRepository {
                await repository.cleanup()
                try await repository.initialize()
            }
            
        case is FinanceServiceProtocol.Type:
            if let service = _financeService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is CategoryServiceProtocol.Type:
            if let service = _categoryService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is CurrencyServiceProtocol.Type:
            if let service = _currencyService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is ProjectManagementServiceProtocol.Type:
            if let service = _projectManagementService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is TimeBlockingServiceProtocol.Type:
            if let service = _timeBlockingService {
                await service.cleanup()
                try await service.initialize()
            }
            
        case is TemplateServiceProtocol.Type:
            if let service = _templateService {
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
        _taskService = MockTaskService()
        
        // Mock Finance Services
        _transactionRepository = MockTransactionRepository()
        _financeService = MockFinanceService()
        _categoryService = MockCategoryService()
        _currencyService = MockCurrencyService()

        // Mock Advanced Services
        _projectManagementService = MockProjectManagementService()
        _timeBlockingService = MockTimeBlockingService()
        _templateService = MockTemplateService()
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

// Mock TaskService
private final class MockTaskService: TaskServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func getActiveTasks() async throws -> [Task] { return [] }
    func getTodayTasks() async throws -> [Task] { return [] }
    func getTomorrowTasks() async throws -> [Task] { return [] }
    func getThisWeekTasks() async throws -> [Task] { return [] }
    func getLaterTasks() async throws -> [Task] { return [] }
    func getTask(by id: UUID) async throws -> Task? { return nil }
    func searchTasks(_ searchText: String) async throws -> [Task] { return [] }
    func getTasksByCategory(_ category: Category) async throws -> [Task] { return [] }
    func getTasksByPriority(_ priority: Priority) async throws -> [Task] { return [] }
    func getTasksByStatus(_ status: TaskStatus) async throws -> [Task] { return [] }
    
    func createTask(_ task: Task) async throws { }
    func updateTask(_ task: Task) async throws { }
    func deleteTask(_ task: Task) async throws { }
    func bulkUpdateTasks(_ tasks: [Task]) async throws { }
    func bulkDeleteTasks(_ tasks: [Task]) async throws { }
    
    func completeTask(_ task: Task) async throws { }
    func uncompleteTask(_ task: Task) async throws { }
    func startTask(_ task: Task) async throws { }
    func pauseTask(_ task: Task) async throws { }
    func cancelTask(_ task: Task) async throws { }
    func updateTaskPriority(_ task: Task, priority: Priority) async throws { }
    
    func addSubtask(_ subtask: Task, to parent: Task) async throws { }
    func removeSubtask(_ subtask: Task) async throws { }
    func addTaskDependency(_ task: Task, dependsOn prerequisite: Task) async throws { }
    func removeTaskDependency(_ task: Task, from prerequisite: Task) async throws { }
    
    func scheduleTaskReminder(_ task: Task) async throws { }
    func cancelTaskReminder(_ task: Task) async throws { }
    func scheduleTaskDeadlineNotification(_ task: Task) async throws { }
    
    func archiveTask(_ task: Task) async throws { }
    func unarchiveTask(_ task: Task) async throws { }
    func getTaskStatistics(period: StatisticsPeriod) async throws -> TaskStatistics {
        return TaskStatistics(
            period: period,
            totalTasks: 0,
            completedTasks: 0,
            overdueTasks: 0,
            highPriorityTasks: 0,
            averageCompletionTime: 0,
            productivityScore: 0.0
        )
    }
    
    func processRecurringTasks() async throws { }
    func checkOverdueTasks() async throws { }
    func syncTaskNotifications() async throws { }
}

// MARK: - Mock Finance Services

// Mock TransactionRepository
private final class MockTransactionRepository: TransactionRepositoryProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func fetchTransactions(from startDate: Date?, to endDate: Date?, type: TransactionType?, category: Category?) async throws -> [Transaction] { return [] }
    func fetchTransaction(by id: UUID) async throws -> Transaction? { return nil }
    func save(_ transaction: Transaction) async throws { }
    func delete(_ transaction: Transaction) async throws { }
    func batchSave(_ transactions: [Transaction]) async throws { }
    func getMonthlyBalance(for date: Date) async throws -> FinanceBalance {
        return FinanceBalance(income: 0, expenses: 0, period: DateInterval(start: date, duration: 86400), transactionCount: 0)
    }
    func getWeeklyBalance(for date: Date) async throws -> FinanceBalance {
        return FinanceBalance(income: 0, expenses: 0, period: DateInterval(start: date, duration: 86400), transactionCount: 0)
    }
    func getYearlyBalance(for date: Date) async throws -> FinanceBalance {
        return FinanceBalance(income: 0, expenses: 0, period: DateInterval(start: date, duration: 86400), transactionCount: 0)
    }
    func getTopCategories(for period: DateInterval, type: TransactionType) async throws -> [CategorySummary] { return [] }
    func getTrendData(for period: DateInterval) async throws -> [BalancePoint] { return [] }
    func searchTransactions(query: String) async throws -> [Transaction] { return [] }
    func getRecentTransactions(limit: Int) async throws -> [Transaction] { return [] }
    func getTransactionsByAccount(_ account: String) async throws -> [Transaction] { return [] }
    func getRecurringTransactions() async throws -> [Transaction] { return [] }
    func getTotalBalance() async throws -> Decimal { return 0 }
    func getMonthlySpending(for date: Date) async throws -> Decimal { return 0 }
    func getMonthlyIncome(for date: Date) async throws -> Decimal { return 0 }
    func getAverageTransactionAmount(for type: TransactionType) async throws -> Decimal { return 0 }
    func getTransactionsInCurrency(_ currency: String) async throws -> [Transaction] { return [] }
    func convertTransactionsToBaseCurrency(_ transactions: [Transaction]) async throws -> [Transaction] { return transactions }
}

// Mock FinanceService
private final class MockFinanceService: FinanceServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func calculateBalance(for period: DateInterval) async throws -> FinanceBalance {
        return FinanceBalance(income: 0, expenses: 0, period: period, transactionCount: 0)
    }
    func generateFinancialReport(for period: DateInterval) async throws -> FinancialReport {
        return FinancialReport(
            period: period,
            totalIncome: 0,
            totalExpenses: 0,
            netIncome: 0,
            topExpenseCategories: [],
            topIncomeCategories: [],
            budgetPerformance: [],
            savingsRate: 0,
            expenseGrowth: 0,
            insights: [],
            generatedAt: Date()
        )
    }
    func predictFutureBalance(days: Int) async throws -> [BalancePrediction] { return [] }
    func getSpendingTrend(for period: DateInterval) async throws -> SpendingTrend {
        return SpendingTrend(
            period: period,
            dailyAverages: [:],
            weeklyTotals: [:],
            monthlyTotals: [:],
            trendDirection: .stable,
            changePercentage: 0
        )
    }
    func createBudget(_ budget: Budget) async throws { }
    func updateBudget(_ budget: Budget) async throws { }
    func checkBudgetStatus(_ budget: Budget) async throws -> BudgetStatus { return .onTrack }
    func getBudgetProgress(_ budget: Budget) async throws -> BudgetProgress {
        return BudgetProgress(
            budget: budget,
            spent: 0,
            remaining: budget.limit,
            progress: 0,
            daysRemaining: 30,
            recommendedDailySpending: 0,
            isOnTrack: true,
            projectedOverrun: nil
        )
    }
    func sendBudgetNotificationIfNeeded(_ budget: Budget) async throws { }
    func getCurrencyRates() async throws -> [String: Decimal] { return [:] }
    func convertAmount(_ amount: Decimal, from: String, to: String) async throws -> Decimal { return amount }
    func updateExchangeRates() async throws { }
    func getBaseCurrency() async throws -> Currency { return Currency(code: "RUB", name: "Рубль", symbol: "₽", isBase: true) }
    func processTransaction(_ transaction: Transaction) async throws { }
    func bulkImportTransactions(_ transactions: [Transaction]) async throws { }
    func categorizeTransaction(_ transaction: Transaction) async throws -> Category? { return nil }
    func detectDuplicateTransactions(_ transactions: [Transaction]) async throws -> [Transaction] { return [] }
    func getSpendingInsights(for period: DateInterval) async throws -> [FinanceInsight] { return [] }
    func getBudgetRecommendations() async throws -> [BudgetRecommendation] { return [] }
    func getRecurringTransactionSuggestions() async throws -> [RecurringTransactionSuggestion] { return [] }
}

// Mock CategoryService
private final class MockCategoryService: CategoryServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func getDefaultCategories() async throws -> [Category] { return [] }
    func createCustomCategory(_ category: Category) async throws { }
    func updateCategory(_ category: Category) async throws { }
    func deleteCategory(_ category: Category) async throws { }
    func getCategoriesForType(_ type: CategoryType) async throws -> [Category] { return [] }
    func getCategoryStats(for period: DateInterval) async throws -> [CategoryStats] { return [] }
    func getCategoryTrends(for category: Category, period: DateInterval) async throws -> CategoryTrend {
        return CategoryTrend(
            category: category,
            period: period,
            dailyAverages: [:],
            weeklyTotals: [:],
            monthlyTotals: [:],
            trendDirection: .stable,
            changePercentage: 0,
            projectedNextMonth: 0
        )
    }
    func getTopCategories(limit: Int, type: TransactionType) async throws -> [Category] { return [] }
    func suggestCategory(for description: String, amount: Decimal) async -> Category? { return nil }
    func getCategorySuggestions(based on: [Transaction]) async throws -> [CategorySuggestion] { return [] }
    func learnFromCategorization(_ transaction: Transaction, category: Category) async throws { }
    func createSubcategory(_ subcategory: Category, parent: Category) async throws { }
    func getCategoryHierarchy() async throws -> [CategoryNode] { return [] }
    func getSubcategories(for parent: Category) async throws -> [Category] { return [] }
    func exportCategories() async throws -> [CategoryExport] { return [] }
    func importCategories(_ categories: [CategoryImport]) async throws { }
}

// Mock CurrencyService
private final class MockCurrencyService: CurrencyServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func getBaseCurrency() async throws -> Currency { return Currency(code: "RUB", name: "Рубль", symbol: "₽", isBase: true) }
    func setBaseCurrency(_ currency: Currency) async throws { }
    func getAllCurrencies() async throws -> [Currency] { return [] }
    func getSupportedCurrencies() async throws -> [Currency] { return [] }
    func addCustomCurrency(_ currency: Currency) async throws { }
    func getAllExchangeRates() async throws -> [String: Decimal] { return [:] }
    func getExchangeRate(from: String, to: String) async throws -> Decimal { return 1.0 }
    func updateExchangeRates() async throws { }
    func getLastUpdateTime() async throws -> Date? { return nil }
    func convertAmount(_ amount: Decimal, from: String, to: String) async throws -> Decimal { return amount }
    func convertToBaseCurrency(_ amount: Decimal, from currency: String) async throws -> Decimal { return amount }
    func convertFromBaseCurrency(_ amount: Decimal, to currency: String) async throws -> Decimal { return amount }
    func formatAmount(_ amount: Decimal, in currency: String) -> String { return "\(amount) \(currency)" }
    func formatAmountWithSymbol(_ amount: Decimal, currency: String) -> String { return "\(amount) ₽" }
    func getCurrencySymbol(for code: String) -> String? { return "₽" }
    func getHistoricalRates(for currency: String, days: Int) async throws -> [HistoricalRate] { return [] }
    func getCurrencyTrend(for currency: String, period: DateInterval) async throws -> CurrencyTrend {
        return CurrencyTrend(
            currency: currency,
            period: period,
            startRate: 1.0,
            endRate: 1.0,
            highestRate: 1.0,
            lowestRate: 1.0,
            averageRate: 1.0,
            volatility: 0,
            trendDirection: .stable,
            changePercentage: 0
        )
    }
    func subscribeToRateUpdates(for currency: String) async throws { }
    func unsubscribeFromRateUpdates(for currency: String) async throws { }
    func getSignificantRateChanges() async throws -> [RateChange] { return [] }
}

// MARK: - Mock Advanced Services

// Mock ProjectManagementService
private final class MockProjectManagementService: ProjectManagementServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func createProject(from template: ProjectTemplate?) async throws -> Project {
        return Project(name: "Mock Project", description: "Mock description")
    }
    func getProject(by id: UUID) async throws -> Project? { return nil }
    func getAllProjects() async throws -> [Project] { return [] }
    func getActiveProjects() async throws -> [Project] { return [] }
    func updateProject(_ project: Project) async throws { }
    func deleteProject(_ project: Project) async throws { }
    func archiveProject(_ project: Project) async throws { }
    
    func updateProjectProgress(_ project: Project) async throws { }
    func calculateProjectCompletion(_ project: Project) async -> Double { return 0.0 }
    func calculateProjectEffort(_ project: Project) async -> (estimated: TimeInterval?, actual: TimeInterval?) {
        return (estimated: nil, actual: nil)
    }
    
    func addDependency(from: Project, to: Project) async throws { }
    func removeDependency(from: Project, to: Project) async throws { }
    func validateDependencies(_ project: Project) async throws -> [DependencyConflict] { return [] }
    func getProjectSchedule(_ project: Project) async throws -> [ScheduleItem] { return [] }
    func resolveScheduleConflicts(_ conflicts: [ScheduleConflict]) async throws -> [ScheduleResolution] { return [] }
    
    func applyTemplate(_ template: ProjectTemplate, to project: Project) async throws { }
    func createTemplateFromProject(_ project: Project, name: String, isPublic: Bool) async throws -> ProjectTemplate {
        return ProjectTemplate(name: name, category: .planning)
    }
    func getAllTemplates() async throws -> [ProjectTemplate] { return [] }
    func getRecommendedTemplates(for category: TemplateCategory?) async throws -> [ProjectTemplate] { return [] }
    
    func getProjectMetrics(_ project: Project) async throws -> ProjectMetrics {
        return ProjectMetrics(project: project, completionRate: 0.0, timeUtilization: 0.0, taskVelocity: 0.0)
    }
    func getProjectInsights(_ project: Project) async throws -> [ProjectInsight] { return [] }
    func predictProjectCompletion(_ project: Project) async throws -> ProjectPrediction {
        return ProjectPrediction(project: project, estimatedCompletionDate: Date(), confidence: 0.0)
    }
    
    func bulkUpdateProjects(_ projects: [Project], operation: ProjectBulkOperation) async throws { }
    func exportProject(_ project: Project) async throws -> ProjectExportData {
        return ProjectExportData(project: [:], metadata: [:])
    }
    func importProject(from data: ProjectExportData) async throws -> Project {
        return Project(name: "Imported Project", description: "Imported description")
    }
}

// MARK: - Simple Calendar Service Protocol and Implementation

protocol CalendarIntegrationServiceProtocol: ServiceProtocol {
    // Простая заглушка для календарной интеграции
}

// Простая реализация календарного сервиса
final class SimpleCalendarService: CalendarIntegrationServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        isInitialized = false
    }
}

// Mock TimeBlockingService
private final class MockTimeBlockingService: TimeBlockingServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func createTimeBlock(for task: ProjectTask?, duration: TimeInterval, preferredDate: Date?) async throws -> TimeBlock {
        return TimeBlock(title: "Mock Block", startDate: Date(), endDate: Date().addingTimeInterval(duration))
    }
    func createTimeBlock(for project: Project?, duration: TimeInterval, preferredDate: Date?) async throws -> TimeBlock {
        return TimeBlock(title: "Mock Project Block", startDate: Date(), endDate: Date().addingTimeInterval(duration))
    }
    func getTimeBlock(by id: UUID) async throws -> TimeBlock? { return nil }
    func getTimeBlocks(for date: Date) async throws -> [TimeBlock] { return [] }
    func getTimeBlocks(for dateRange: DateInterval) async throws -> [TimeBlock] { return [] }
    func updateTimeBlock(_ timeBlock: TimeBlock) async throws { }
    func deleteTimeBlock(_ timeBlock: TimeBlock) async throws { }
    
    func suggestOptimalTimeSlots(for task: ProjectTask) async throws -> [TimeSlot] { return [] }
    func suggestOptimalTimeSlots(duration: TimeInterval, energyLevel: EnergyLevel?, timeOfDay: TimeOfDay?) async throws -> [TimeSlot] { return [] }
    func rescheduleTimeBlock(_ timeBlock: TimeBlock, to newDate: Date) async throws { }
    func optimizeSchedule(for date: Date) async throws -> [ScheduleOptimization] { return [] }
    func findFreeTimeSlots(for date: Date, duration: TimeInterval) async throws -> [TimeSlot] { return [] }
    
    func syncWithCalendar() async throws { }
    func createCalendarEvent(for timeBlock: TimeBlock) async throws { }
    func updateCalendarEvent(for timeBlock: TimeBlock) async throws { }
    func deleteCalendarEvent(for timeBlock: TimeBlock) async throws { }
    func handleCalendarEventUpdate(_ eventID: String) async throws { }
    func importCalendarEvents(from calendarIdentifier: String) async throws -> [TimeBlock] { return [] }
    
    func calculateWorkload(for date: Date) async throws -> WorkloadInfo {
        return WorkloadInfo(date: date, totalTime: 0, scheduledTime: 0, freeTime: 0, utilizationRate: 0.0)
    }
    func calculateWorkload(for week: Date) async throws -> [WorkloadInfo] { return [] }
    func suggestWorkloadDistribution(for week: Date) async throws -> [WorkloadSuggestion] { return [] }
    func getWorkloadTrends(for period: DateInterval) async throws -> WorkloadTrends {
        return WorkloadTrends(period: period, averageUtilization: 0.0, peakDays: [], lightDays: [])
    }
    
    func getTimeBlockAnalytics(for period: DateInterval) async throws -> TimeBlockAnalytics {
        return TimeBlockAnalytics(period: period, totalBlocks: 0, averageDuration: 0, mostProductiveTime: nil)
    }
    func getProductivityInsights(for user: User) async throws -> [ProductivityInsight] { return [] }
    func generateTimeReports(for period: DateInterval) async throws -> TimeReport {
        return TimeReport(period: period, totalTime: 0, breakdown: [:], insights: [])
    }
    
    func autoScheduleTasks(_ tasks: [ProjectTask], within timeframe: DateInterval, preferences: SchedulingPreferences) async throws -> [TimeBlock] { return [] }
    func rebalanceSchedule(for date: Date, constraints: SchedulingConstraints?) async throws -> [TimeBlock] { return [] }
}

// Mock TemplateService
private final class MockTemplateService: TemplateServiceProtocol {
    var isInitialized: Bool = true
    
    func initialize() async throws { }
    func cleanup() async { }
    
    func getAllTemplates() async throws -> [ProjectTemplate] { return [] }
    func getTemplate(by id: UUID) async throws -> ProjectTemplate? { return nil }
    func getTemplatesForCategory(_ category: TemplateCategory) async throws -> [ProjectTemplate] { return [] }
    func getUserTemplates() async throws -> [ProjectTemplate] { return [] }
    func getPublicTemplates() async throws -> [ProjectTemplate] { return [] }
    func saveTemplate(_ template: ProjectTemplate) async throws { }
    func updateTemplate(_ template: ProjectTemplate) async throws { }
    func deleteTemplate(_ template: ProjectTemplate) async throws { }
    
    func instantiateTemplate(_ template: ProjectTemplate) async throws -> Project {
        return Project(name: template.name, description: template.description)
    }
    func previewTemplate(_ template: ProjectTemplate) async throws -> TemplatePreview {
        return TemplatePreview(template: template, estimatedTasks: 0, estimatedPhases: 0, estimatedMilestones: 0)
    }
    func validateTemplate(_ template: ProjectTemplate) async throws -> [TemplateValidationError] { return [] }
    
    func getRecommendedTemplates(for category: TemplateCategory?) async throws -> [ProjectTemplate] { return [] }
    func suggestTemplatesForGoal(_ goal: GoalHierarchy) async throws -> [ProjectTemplate] { return [] }
    func getSimilarTemplates(to template: ProjectTemplate) async throws -> [ProjectTemplate] { return [] }
    func getTrendingTemplates() async throws -> [ProjectTemplate] { return [] }
    
    func rateTemplate(_ template: ProjectTemplate, rating: Double) async throws { }
    func getTemplateReviews(_ template: ProjectTemplate) async throws -> [TemplateReview] { return [] }
    func addReview(to template: ProjectTemplate, review: TemplateReview) async throws { }
    
    func publishTemplate(_ template: ProjectTemplate) async throws { }
    func shareTemplate(_ template: ProjectTemplate) async throws -> String { return "mock://share" }
    func importTemplate(from data: TemplateData) async throws -> ProjectTemplate {
        return ProjectTemplate(name: "Imported Template", category: .planning)
    }
    func exportTemplate(_ template: ProjectTemplate) async throws -> TemplateData {
        return TemplateData(metadata: TemplateMetadata(version: "1.0", exportDate: Date()), templateData: [:])
    }
    
    func getTemplateAnalytics(_ template: ProjectTemplate) async throws -> TemplateAnalytics {
        return TemplateAnalytics(template: template, totalUsage: 0, averageRating: 0.0, downloadCount: 0)
    }
    func getTemplateUsageStatistics() async throws -> TemplateUsageStatistics {
        return TemplateUsageStatistics(totalTemplates: 0, publicTemplates: 0, totalUsage: 0, averageRating: 0.0)
    }
    func generateTemplateInsights() async throws -> [TemplateInsight] { return [] }
} 

# MARK: - Simple Analytics Service Protocol and Implementation

protocol AnalyticsServiceProtocol: ServiceProtocol {
    func trackTemplateUsage(_ templateId: UUID) async
    func trackTemplateRating(_ templateId: UUID, rating: Double) async
    func trackTemplateReview(_ templateId: UUID) async
    func trackTemplatePublication(_ templateId: UUID) async
    func trackTemplateShare(_ templateId: UUID) async
    func trackTemplateImport(_ templateId: UUID) async
    func getTemplateUsageOverTime(_ templateId: UUID) async -> [UsageDataPoint]
}

// Простая реализация аналитического сервиса
final class SimpleAnalyticsService: AnalyticsServiceProtocol {
    var isInitialized: Bool = false
    
    func initialize() async throws {
        isInitialized = true
    }
    
    func cleanup() async {
        isInitialized = false
    }
    
    func trackTemplateUsage(_ templateId: UUID) async { }
    func trackTemplateRating(_ templateId: UUID, rating: Double) async { }
    func trackTemplateReview(_ templateId: UUID) async { }
    func trackTemplatePublication(_ templateId: UUID) async { }
    func trackTemplateShare(_ templateId: UUID) async { }
    func trackTemplateImport(_ templateId: UUID) async { }
    func getTemplateUsageOverTime(_ templateId: UUID) async -> [UsageDataPoint] { return [] }
}

// Простая структура для данных использования
struct UsageDataPoint {
    let date: Date
    let count: Int
} 