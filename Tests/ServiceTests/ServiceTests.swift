import XCTest
import SwiftData
import UserNotifications
@testable import IWBB

// MARK: - Base Test Case

class BaseServiceTestCase: XCTestCase {
    
    var serviceContainer: ServiceContainerProtocol!
    var mockDataService: ConfigurableMockDataService!
    var mockNotificationService: ConfigurableMockNotificationService!
    var mockUserDefaultsService: ConfigurableMockUserDefaultsService!
    var mockErrorHandlingService: ConfigurableMockErrorHandlingService!
    
    override func setUp() {
        super.setUp()
        setupMockServices()
    }
    
    override func tearDown() {
        Task {
            await serviceContainer.cleanupAllServices()
        }
        serviceContainer = nil
        mockDataService = nil
        mockNotificationService = nil
        mockUserDefaultsService = nil
        mockErrorHandlingService = nil
        super.tearDown()
    }
    
    private func setupMockServices() {
        serviceContainer = MockServiceFactory.createMockServiceContainer()
        
        // Получаем ссылки на mock сервисы для детального тестирования
        if let container = serviceContainer as? ConfigurableMockServiceContainer {
            mockDataService = container.dataService as? ConfigurableMockDataService
            mockNotificationService = container.notificationService as? ConfigurableMockNotificationService
            mockUserDefaultsService = container.userDefaultsService as? ConfigurableMockUserDefaultsService
            mockErrorHandlingService = container.errorHandlingService as? ConfigurableMockErrorHandlingService
        }
    }
}

// MARK: - DataService Tests

final class DataServiceTests: BaseServiceTestCase {
    
    func testDataServiceInitialization() async throws {
        // Given
        let dataService = DataService.testing()
        
        // When
        try await dataService.initialize()
        
        // Then
        XCTAssertTrue(dataService.isInitialized)
    }
    
    func testDataServiceCleanup() async throws {
        // Given
        let dataService = DataService.testing()
        try await dataService.initialize()
        
        // When
        await dataService.cleanup()
        
        // Then
        XCTAssertFalse(dataService.isInitialized)
    }
    
    func testSaveAndFetch() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        // When & Then
        // Mock implementation always returns empty arrays
        // В реальном тестировании здесь были бы конкретные модели
        let results: [User] = try await container.dataService.fetch(User.self)
        XCTAssertEqual(results.count, 0)
    }
    
    func testFetchFailure() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            dataServiceBehavior: .fetchFails
        )
        try await container.initializeAllServices()
        
        // When & Then
        do {
            let _: [User] = try await container.dataService.fetch(User.self)
            XCTFail("Expected fetch to fail")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
    
    func testSaveFailure() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            dataServiceBehavior: .saveFails
        )
        try await container.initializeAllServices()
        
        // Create test user
        let testUser = User(name: "Test User", email: "test@example.com")
        
        // When & Then
        do {
            try await container.dataService.save(testUser)
            XCTFail("Expected save to fail")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
    
    func testBatchOperations() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let testUsers = [
            User(name: "User 1", email: "user1@example.com"),
            User(name: "User 2", email: "user2@example.com")
        ]
        
        // When
        try await container.dataService.batchSave(testUsers)
        
        // Then
        // In mock implementation, we can verify the operation completed without error
        XCTAssertTrue(container.dataService.isInitialized)
    }
}

// MARK: - NotificationService Tests

final class NotificationServiceTests: BaseServiceTestCase {
    
    func testNotificationServiceInitialization() async throws {
        // Given
        let notificationService = NotificationService.testing()
        
        // When
        try await notificationService.initialize()
        
        // Then
        XCTAssertTrue(notificationService.isInitialized)
    }
    
    func testRequestPermissionSuccess() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            notificationServiceBehavior: .normal
        )
        try await container.initializeAllServices()
        
        // When
        let granted = await container.notificationService.requestPermission()
        
        // Then
        XCTAssertTrue(granted)
    }
    
    func testRequestPermissionDenied() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            notificationServiceBehavior: .permissionDenied
        )
        try await container.initializeAllServices()
        
        // When
        let granted = await container.notificationService.requestPermission()
        
        // Then
        XCTAssertFalse(granted)
    }
    
    func testScheduleHabitReminder() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let habitID = UUID()
        let habitName = "Test Habit"
        let reminderTime = Date()
        
        // When
        try await container.notificationService.scheduleHabitReminder(
            habitID,
            name: habitName,
            time: reminderTime
        )
        
        // Then
        if let mockService = container.notificationService as? ConfigurableMockNotificationService {
            XCTAssertEqual(mockService.scheduledNotificationCount, 1)
            
            let notification = mockService.getScheduledNotification(for: "habit-\(habitID.uuidString)")
            XCTAssertNotNil(notification)
            XCTAssertEqual(notification?.title, "Время для привычки")
            XCTAssertEqual(notification?.type, .habitReminder)
        }
    }
    
    func testScheduleTaskDeadline() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let taskID = UUID()
        let taskTitle = "Test Task"
        let deadline = Date().addingTimeInterval(3600) // 1 hour from now
        
        // When
        try await container.notificationService.scheduleTaskDeadline(
            taskID,
            title: taskTitle,
            deadline: deadline
        )
        
        // Then
        if let mockService = container.notificationService as? ConfigurableMockNotificationService {
            XCTAssertEqual(mockService.scheduledNotificationCount, 1)
            
            let notification = mockService.getScheduledNotification(for: "task-\(taskID.uuidString)")
            XCTAssertNotNil(notification)
            XCTAssertEqual(notification?.type, .taskDeadline)
        }
    }
    
    func testSchedulingFailure() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            notificationServiceBehavior: .schedulingFails
        )
        try await container.initializeAllServices()
        
        // When & Then
        do {
            try await container.notificationService.scheduleHabitReminder(
                UUID(),
                name: "Test",
                time: Date()
            )
            XCTFail("Expected scheduling to fail")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
    
    func testCancelNotification() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let habitID = UUID()
        let identifier = "habit-\(habitID.uuidString)"
        
        // Schedule notification first
        try await container.notificationService.scheduleHabitReminder(
            habitID,
            name: "Test Habit",
            time: Date()
        )
        
        // When
        await container.notificationService.cancelNotification(for: identifier)
        
        // Then
        if let mockService = container.notificationService as? ConfigurableMockNotificationService {
            XCTAssertEqual(mockService.scheduledNotificationCount, 0)
        }
    }
}

// MARK: - UserDefaultsService Tests

final class UserDefaultsServiceTests: BaseServiceTestCase {
    
    func testUserDefaultsServiceInitialization() async throws {
        // Given
        let userDefaultsService = UserDefaultsService.testing()
        
        // When
        try await userDefaultsService.initialize()
        
        // Then
        XCTAssertTrue(userDefaultsService.isInitialized)
    }
    
    func testThemeMode() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        // When
        container.userDefaultsService.themeMode = .dark
        
        // Then
        XCTAssertEqual(container.userDefaultsService.themeMode, .dark)
    }
    
    func testFirstLaunchBehavior() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            userDefaultsServiceBehavior: .firstLaunch
        )
        try await container.initializeAllServices()
        
        // Then
        XCTAssertTrue(container.userDefaultsService.isFirstLaunch)
        XCTAssertFalse(container.userDefaultsService.hasCompletedOnboarding)
    }
    
    func testOnboardingIncompleteBehavior() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            userDefaultsServiceBehavior: .onboardingIncomplete
        )
        try await container.initializeAllServices()
        
        // Then
        XCTAssertFalse(container.userDefaultsService.hasCompletedOnboarding)
    }
    
    func testGenericValueStorage() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        struct TestData: Codable, Equatable {
            let name: String
            let value: Int
        }
        
        let testData = TestData(name: "test", value: 42)
        
        // When
        container.userDefaultsService.setValue(testData, for: .accentColor) // Using existing key for test
        let retrievedData: TestData? = container.userDefaultsService.getValue(TestData.self, for: .accentColor)
        
        // Then
        XCTAssertEqual(retrievedData, testData)
    }
    
    func testReset() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        // Modify some values
        container.userDefaultsService.themeMode = .dark
        container.userDefaultsService.accentColor = "#FF0000"
        
        // When
        container.userDefaultsService.reset()
        
        // Then
        XCTAssertEqual(container.userDefaultsService.themeMode, .system)
        XCTAssertEqual(container.userDefaultsService.accentColor, "#007AFF")
    }
}

// MARK: - ErrorHandlingService Tests

final class ErrorHandlingServiceTests: BaseServiceTestCase {
    
    func testErrorHandlingServiceInitialization() async throws {
        // Given
        let errorHandlingService = ErrorHandlingService.testing()
        
        // When
        try await errorHandlingService.initialize()
        
        // Then
        XCTAssertTrue(errorHandlingService.isInitialized)
    }
    
    func testHandleError() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let testError = AppError.networkUnavailable
        
        // When
        await container.errorHandlingService.handle(testError)
        
        // Then
        if let mockService = container.errorHandlingService as? ConfigurableMockErrorHandlingService {
            XCTAssertEqual(mockService.handledErrorCount, 1)
            XCTAssertEqual(mockService.getHandledErrors().first, testError)
        }
    }
    
    func testRecoveryOptions() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let networkError = AppError.networkUnavailable
        let permissionError = AppError.notificationPermissionDenied
        
        // When
        let networkOptions = container.errorHandlingService.getRecoveryOptions(for: networkError)
        let permissionOptions = container.errorHandlingService.getRecoveryOptions(for: permissionError)
        
        // Then
        XCTAssertFalse(networkOptions.isEmpty)
        XCTAssertFalse(permissionOptions.isEmpty)
        
        // Check that retry option is available for network error
        XCTAssertTrue(networkOptions.contains { $0.title == "Повторить" })
        
        // Check that close option is always available
        XCTAssertTrue(networkOptions.contains { $0.title == "Закрыть" })
        XCTAssertTrue(permissionOptions.contains { $0.title == "Закрыть" })
    }
    
    func testAttemptRecovery() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            errorHandlingServiceBehavior: .recoveryAlwaysFails
        )
        try await container.initializeAllServices()
        
        let retryableError = AppError.networkUnavailable
        
        // When
        let recovered = await container.errorHandlingService.attemptRecovery(for: retryableError)
        
        // Then
        XCTAssertFalse(recovered) // Because we set recovery to always fail
    }
    
    func testLogError() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let testError = AppError.dataCorrupted("Test corruption")
        
        // When
        container.errorHandlingService.logError(testError, context: .dataOperation("test"))
        
        // Then
        if let mockService = container.errorHandlingService as? ConfigurableMockErrorHandlingService {
            XCTAssertEqual(mockService.handledErrorCount, 1)
        }
    }
}

// MARK: - ServiceContainer Tests

final class ServiceContainerTests: BaseServiceTestCase {
    
    func testServiceContainerInitialization() async throws {
        // Given
        let container = ServiceContainer.testing()
        
        // When
        try await container.initializeAllServices()
        
        // Then
        XCTAssertTrue(container.allServicesReady)
    }
    
    func testServiceContainerCleanup() async throws {
        // Given
        let container = ServiceContainer.testing()
        try await container.initializeAllServices()
        
        // When
        await container.cleanupAllServices()
        
        // Then
        XCTAssertFalse(container.allServicesReady)
    }
    
    func testServiceStatus() async throws {
        // Given
        let container = ServiceContainer.testing()
        
        // When
        let statusBefore = container.serviceStatus
        try await container.initializeAllServices()
        let statusAfter = container.serviceStatus
        
        // Then
        XCTAssertTrue(statusBefore.values.allSatisfy { !$0 })
        XCTAssertTrue(statusAfter.values.allSatisfy { $0 })
    }
    
    func testFactoryMethods() {
        // Given & When
        let testingContainer = ServiceContainer.testing()
        let previewContainer = ServiceContainer.preview()
        let mockContainer = ServiceContainer.mock()
        
        // Then
        XCTAssertNotNil(testingContainer)
        XCTAssertNotNil(previewContainer)
        XCTAssertNotNil(mockContainer)
        XCTAssertTrue(mockContainer is MockServiceContainer)
    }
    
    func testMockServiceContainer() async throws {
        // Given
        let container = MockServiceFactory.createMockServices()
        
        // When
        try await container.initializeAllServices()
        
        // Then
        XCTAssertTrue(container.dataService.isInitialized)
        XCTAssertTrue(container.notificationService.isInitialized)
        XCTAssertTrue(container.userDefaultsService.isInitialized)
        XCTAssertTrue(container.errorHandlingService.isInitialized)
    }
}

// MARK: - Integration Tests

final class ServiceIntegrationTests: BaseServiceTestCase {
    
    func testServiceCommunication() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        // When - Simulate a data save operation that triggers notification
        let testUser = User(name: "Test User", email: "test@example.com")
        try await container.dataService.save(testUser)
        
        // Schedule a habit reminder
        let habitID = UUID()
        try await container.notificationService.scheduleHabitReminder(
            habitID,
            name: "Test Habit",
            time: Date()
        )
        
        // Log an error
        let testError = AppError.saveFailed("Test error")
        await container.errorHandlingService.handle(testError)
        
        // Then - Verify all operations completed successfully
        if let mockNotificationService = container.notificationService as? ConfigurableMockNotificationService,
           let mockErrorService = container.errorHandlingService as? ConfigurableMockErrorHandlingService {
            
            XCTAssertEqual(mockNotificationService.scheduledNotificationCount, 1)
            XCTAssertEqual(mockErrorService.handledErrorCount, 1)
        }
    }
    
    func testErrorPropagation() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            dataServiceBehavior: .saveFails
        )
        try await container.initializeAllServices()
        
        let testUser = User(name: "Test User", email: "test@example.com")
        
        // When
        do {
            try await container.dataService.save(testUser)
            XCTFail("Expected save to fail")
        } catch {
            // Then
            XCTAssertTrue(error is AppError)
            
            // Verify error was handled by error service
            await container.errorHandlingService.handle(error)
            
            if let mockErrorService = container.errorHandlingService as? ConfigurableMockErrorHandlingService {
                XCTAssertGreaterThan(mockErrorService.handledErrorCount, 0)
            }
        }
    }
    
    func testUserDefaultsIntegration() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        // When - Check if notifications are enabled in settings
        let notificationsEnabled = container.userDefaultsService.isNotificationsEnabled
        
        if notificationsEnabled {
            // Try to schedule a notification
            let habitID = UUID()
            try await container.notificationService.scheduleHabitReminder(
                habitID,
                name: "Settings Test",
                time: Date()
            )
            
            // Then
            if let mockService = container.notificationService as? ConfigurableMockNotificationService {
                XCTAssertEqual(mockService.scheduledNotificationCount, 1)
            }
        }
        
        XCTAssertTrue(notificationsEnabled) // Mock service returns true by default
    }
}

// MARK: - Performance Tests

final class ServicePerformanceTests: BaseServiceTestCase {
    
    func testSlowServiceInitialization() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer(
            dataServiceBehavior: .slow,
            notificationServiceBehavior: .slow
        )
        
        // When
        let startTime = Date()
        try await container.initializeAllServices()
        let endTime = Date()
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertGreaterThan(duration, 1.0) // Should take at least 1 second due to slow behavior
    }
    
    func testBatchOperationPerformance() async throws {
        // Given
        let container = MockServiceFactory.createMockServiceContainer()
        try await container.initializeAllServices()
        
        let testUsers = (1...100).map { User(name: "User \($0)", email: "user\($0)@example.com") }
        
        // When
        let startTime = Date()
        try await container.dataService.batchSave(testUsers)
        let endTime = Date()
        
        // Then
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0) // Should complete quickly with mock service
    }
}

// MARK: - Error Handling Tests

final class ErrorHandlingIntegrationTests: BaseServiceTestCase {
    
    func testAppErrorMapping() {
        // Given
        let systemError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        let appError = AppError.from(systemError)
        
        // Then
        XCTAssertEqual(appError, AppError.unknown(systemError))
    }
    
    func testErrorSeverityClassification() {
        // Given
        let errors: [(AppError, ErrorSeverity)] = [
            (.networkUnavailable, .medium),
            (.dataCorrupted("test"), .critical),
            (.invalidInput("test"), .low),
            (.saveFailed("test"), .high)
        ]
        
        // When & Then
        for (error, expectedSeverity) in errors {
            XCTAssertEqual(error.severity, expectedSeverity, "Error \(error) should have severity \(expectedSeverity)")
        }
    }
    
    func testErrorRecoveryCapability() {
        // Given
        let retryableErrors: [AppError] = [
            .networkUnavailable,
            .fetchFailed("test"),
            .syncFailed("test")
        ]
        
        let nonRetryableErrors: [AppError] = [
            .dataCorrupted("test"),
            .authenticationFailed("test"),
            .permissionDenied("test")
        ]
        
        // When & Then
        for error in retryableErrors {
            XCTAssertTrue(error.canRetry, "Error \(error) should be retryable")
        }
        
        for error in nonRetryableErrors {
            XCTAssertFalse(error.canRetry, "Error \(error) should not be retryable")
        }
    }
} 