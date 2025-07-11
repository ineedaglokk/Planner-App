import Foundation
import SwiftData
import UserNotifications

// MARK: - Base Service Protocol
protocol ServiceProtocol {
    var isInitialized: Bool { get }
    func initialize() async throws
    func cleanup() async
}

// MARK: - Data Service Protocol
protocol DataServiceProtocol: ServiceProtocol {
    var modelContainer: ModelContainer { get }
    var modelContext: ModelContext { get }
    
    // CRUD Operations
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) async throws -> [T]
    func fetchOne<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) async throws -> T?
    func save<T: PersistentModel>(_ model: T) async throws
    func update<T: PersistentModel>(_ model: T) async throws
    func delete<T: PersistentModel>(_ model: T) async throws
    func batchSave<T: PersistentModel>(_ models: [T]) async throws
    func batchDelete<T: PersistentModel>(_ models: [T]) async throws
    
    // CloudKit Sync
    func markForSync<T: PersistentModel>(_ model: T) async throws
    func performBatchSync() async throws
}

// MARK: - Notification Service Protocol
protocol NotificationServiceProtocol: ServiceProtocol {
    // Permission Management
    func requestPermission() async -> Bool
    func checkPermissionStatus() async -> UNAuthorizationStatus
    
    // Notification Scheduling
    func scheduleHabitReminder(_ habitID: UUID, name: String, time: Date) async throws
    func scheduleTaskDeadline(_ taskID: UUID, title: String, deadline: Date) async throws
    func scheduleBudgetAlert(_ budgetID: UUID, title: String, amount: Decimal) async throws
    
    // Notification Management
    func cancelNotification(for identifier: String) async
    func cancelAllNotifications() async
    func getPendingNotifications() async -> [UNNotificationRequest]
    
    // Notification Handling
    func handleNotificationResponse(_ response: UNNotificationResponse) async
}

// MARK: - UserDefaults Service Protocol
protocol UserDefaultsServiceProtocol: ServiceProtocol {
    // Theme Settings
    var themeMode: ThemeMode { get set }
    var accentColor: String { get set }
    
    // Onboarding & First Launch
    var isFirstLaunch: Bool { get set }
    var hasCompletedOnboarding: Bool { get set }
    var onboardingVersion: String { get set }
    
    // Feature Flags
    var isCloudSyncEnabled: Bool { get set }
    var isAnalyticsEnabled: Bool { get set }
    var isNotificationsEnabled: Bool { get set }
    
    // User Preferences
    var defaultHabitReminderTime: Date { get set }
    var weekStartsOn: WeekDay { get set }
    var preferredLanguage: String { get set }
    
    // Privacy Settings
    var isBiometricEnabled: Bool { get set }
    var autoLockTimeout: TimeInterval { get set }
    
    // Advanced Settings
    func setValue<T>(_ value: T, for key: UserDefaultsKey) where T: Codable
    func getValue<T>(_ type: T.Type, for key: UserDefaultsKey) -> T? where T: Codable
    func removeValue(for key: UserDefaultsKey)
    func reset()
}

// MARK: - Error Handling Service Protocol
protocol ErrorHandlingServiceProtocol: ServiceProtocol {
    // Error Processing
    func handle(_ error: Error, context: ErrorContext?) async
    func handle(_ error: AppError, context: ErrorContext?) async
    
    // Error Presentation
    func presentError(_ error: AppError, in view: ErrorPresentationView) async
    func presentErrorAlert(_ error: AppError, completion: @escaping () -> Void) async
    
    // Error Logging
    func logError(_ error: Error, context: ErrorContext?)
    func logCriticalError(_ error: Error, context: ErrorContext?)
    
    // Recovery Operations
    func attemptRecovery(for error: AppError) async -> Bool
    func getRecoveryOptions(for error: AppError) -> [RecoveryOption]
}

// MARK: - Supporting Types
enum ThemeMode: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

enum WeekDay: Int, CaseIterable, Codable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

enum UserDefaultsKey: String, CaseIterable {
    case themeMode = "theme_mode"
    case accentColor = "accent_color"
    case isFirstLaunch = "is_first_launch"
    case hasCompletedOnboarding = "has_completed_onboarding"
    case onboardingVersion = "onboarding_version"
    case isCloudSyncEnabled = "is_cloud_sync_enabled"
    case isAnalyticsEnabled = "is_analytics_enabled"
    case isNotificationsEnabled = "is_notifications_enabled"
    case defaultHabitReminderTime = "default_habit_reminder_time"
    case weekStartsOn = "week_starts_on"
    case preferredLanguage = "preferred_language"
    case isBiometricEnabled = "is_biometric_enabled"
    case autoLockTimeout = "auto_lock_timeout"
}

enum ErrorContext {
    case dataOperation(String)
    case networkOperation(String)
    case userAction(String)
    case backgroundTask(String)
    case initialization(String)
}

enum ErrorPresentationView {
    case alert
    case banner
    case toast
    case modal
} 