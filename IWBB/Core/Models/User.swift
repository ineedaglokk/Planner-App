import Foundation
import SwiftData

// MARK: - User Model

@Model
final class User: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String?
    var avatar: String? // Путь к файлу аватара или Base64
    
    // Геймификация
    var level: Int
    var totalPoints: Int
    var currentExperience: Int
    var experienceToNextLevel: Int
    
    // Статистика
    var totalHabitsCompleted: Int
    var totalTasksCompleted: Int
    var currentStreak: Int
    var longestStreak: Int
    var totalDaysActive: Int
    
    // Настройки пользователя
    @Attribute(.externalStorage) var preferences: UserPreferences
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    @Relationship(deleteRule: .cascade) var habits: [Habit]
    @Relationship(deleteRule: .cascade) var tasks: [Task]
    @Relationship(deleteRule: .cascade) var goals: [Goal]
    @Relationship(deleteRule: .cascade) var transactions: [Transaction]
    @Relationship(deleteRule: .cascade) var budgets: [Budget]
    @Relationship(deleteRule: .cascade) var achievements: [Achievement]
    @Relationship(deleteRule: .cascade) var categories: [Category]
    
    // MARK: - Initializers
    
    init(
        name: String,
        email: String? = nil,
        preferences: UserPreferences = UserPreferences()
    ) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.preferences = preferences
        
        // Геймификация
        self.level = 1
        self.totalPoints = 0
        self.currentExperience = 0
        self.experienceToNextLevel = 100
        
        // Статистика
        self.totalHabitsCompleted = 0
        self.totalTasksCompleted = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalDaysActive = 0
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        // Relationships
        self.habits = []
        self.tasks = []
        self.goals = []
        self.transactions = []
        self.budgets = []
        self.achievements = []
        self.categories = []
    }
}

// MARK: - User Extensions

extension User: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if let email = email, !email.isEmpty {
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            if !emailPredicate.evaluate(with: email) {
                throw ModelValidationError.missingRequiredField("Некорректный email")
            }
        }
    }
}

extension User {
    
    // MARK: - Computed Properties
    
    /// Процент прогресса до следующего уровня
    var progressToNextLevel: Double {
        guard experienceToNextLevel > 0 else { return 1.0 }
        return Double(currentExperience) / Double(experienceToNextLevel)
    }
    
    /// Активные привычки
    var activeHabits: [Habit] {
        habits.filter { $0.isActive && !$0.isArchived }
    }
    
    /// Незавершенные задачи
    var pendingTasks: [Task] {
        tasks.filter { $0.status == .pending || $0.status == .inProgress }
    }
    
    /// Активные цели
    var activeGoals: [Goal] {
        goals.filter { !$0.isCompleted && !$0.isArchived }
    }
    
    // MARK: - Experience and Level Management
    
    /// Добавляет опыт пользователю
    func addExperience(_ points: Int) {
        currentExperience += points
        totalPoints += points
        
        // Проверяем повышение уровня
        while currentExperience >= experienceToNextLevel {
            levelUp()
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Повышение уровня
    private func levelUp() {
        currentExperience -= experienceToNextLevel
        level += 1
        experienceToNextLevel = calculateExperienceForNextLevel()
        
        // Можно добавить достижение за новый уровень
        // createLevelAchievement()
    }
    
    /// Вычисляет необходимый опыт для следующего уровня
    private func calculateExperienceForNextLevel() -> Int {
        return level * 100 + (level - 1) * 50 // Прогрессивное увеличение
    }
    
    // MARK: - Statistics Management
    
    /// Обновляет статистику выполненных привычек
    func incrementHabitsCompleted() {
        totalHabitsCompleted += 1
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет статистику выполненных задач
    func incrementTasksCompleted() {
        totalTasksCompleted += 1
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет информацию о стрике
    func updateStreak(_ newStreak: Int) {
        currentStreak = newStreak
        if newStreak > longestStreak {
            longestStreak = newStreak
        }
        updateTimestamp()
        markForSync()
    }
    
    /// Увеличивает количество активных дней
    func incrementActiveDays() {
        totalDaysActive += 1
        updateTimestamp()
        markForSync()
    }
}

// MARK: - User Preferences

struct UserPreferences: Codable, Hashable {
    
    // MARK: - Theme Settings
    
    var theme: ThemeMode
    var accentColor: String // Hex цвет
    var isDarkModeEnabled: Bool
    
    // MARK: - Notification Settings
    
    var notificationSettings: NotificationSettings
    
    // MARK: - Privacy Settings
    
    var privacySettings: PrivacySettings
    
    // MARK: - App Settings
    
    var language: String
    var dateFormat: String
    var timeFormat: String // 12/24 hour
    var currency: String
    var firstDayOfWeek: Int // 0 = Sunday, 1 = Monday
    
    // MARK: - Feature Settings
    
    var isGameModeEnabled: Bool
    var isAnalyticsEnabled: Bool
    var isBiometricEnabled: Bool
    var autoBackupEnabled: Bool
    
    // MARK: - Default Initializer
    
    init() {
        self.theme = .system
        self.accentColor = "#007AFF" // iOS Blue
        self.isDarkModeEnabled = false
        
        self.notificationSettings = NotificationSettings()
        self.privacySettings = PrivacySettings()
        
        self.language = "ru"
        self.dateFormat = "dd.MM.yyyy"
        self.timeFormat = "24"
        self.currency = "RUB"
        self.firstDayOfWeek = 1 // Monday
        
        self.isGameModeEnabled = true
        self.isAnalyticsEnabled = true
        self.isBiometricEnabled = false
        self.autoBackupEnabled = true
    }
}

// MARK: - Supporting Structures

enum ThemeMode: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Светлая"
        case .dark: return "Темная"
        case .system: return "Системная"
        }
    }
}

struct NotificationSettings: Codable, Hashable {
    var isEnabled: Bool
    var habitReminders: Bool
    var taskDeadlines: Bool
    var goalMilestones: Bool
    var weeklyReports: Bool
    var achievementNotifications: Bool
    var budgetAlerts: Bool
    
    // Время уведомлений
    var habitReminderTime: String // "09:00"
    var weeklyReportDay: Int // 0 = Sunday
    var weeklyReportTime: String // "18:00"
    
    init() {
        self.isEnabled = true
        self.habitReminders = true
        self.taskDeadlines = true
        self.goalMilestones = true
        self.weeklyReports = true
        self.achievementNotifications = true
        self.budgetAlerts = true
        
        self.habitReminderTime = "09:00"
        self.weeklyReportDay = 0 // Sunday
        self.weeklyReportTime = "18:00"
    }
}

struct PrivacySettings: Codable, Hashable {
    var shareDataWithAnalytics: Bool
    var shareUsageStatistics: Bool
    var allowCrashReporting: Bool
    var shareWithHealthKit: Bool
    var allowCloudSync: Bool
    var requireBiometricForSensitiveData: Bool
    
    init() {
        self.shareDataWithAnalytics = false
        self.shareUsageStatistics = true
        self.allowCrashReporting = true
        self.shareWithHealthKit = false
        self.allowCloudSync = true
        self.requireBiometricForSensitiveData = false
    }
} 