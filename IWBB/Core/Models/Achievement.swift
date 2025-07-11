import Foundation
import SwiftData

// MARK: - Achievement
@Model
final class Achievement {
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String
    var category: AchievementCategory
    var rarity: AchievementRarity
    var iconName: String
    var colorHex: String
    var points: Int
    var requirements: [String: Any] // JSON для хранения требований
    var isActive: Bool
    var isHidden: Bool
    var unlockedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \AchievementProgress.achievement)
    var progressRecords: [AchievementProgress]
    
    init(
        title: String,
        description: String,
        category: AchievementCategory,
        rarity: AchievementRarity,
        iconName: String,
        colorHex: String,
        points: Int,
        requirements: [String: Any] = [:],
        isActive: Bool = true,
        isHidden: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.rarity = rarity
        self.iconName = iconName
        self.colorHex = colorHex
        self.points = points
        self.requirements = requirements
        self.isActive = isActive
        self.isHidden = isHidden
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Проверяет, выполнены ли требования для получения достижения
    func checkRequirements(userProgress: UserProgress) -> Bool {
        // Базовая логика проверки требований
        // Конкретная реализация будет в сервисе
        return false
    }
    
    /// Прогресс выполнения достижения для пользователя
    func progressForUser(_ userID: UUID) -> AchievementProgress? {
        return progressRecords.first { $0.userID == userID }
    }
    
    /// Разблокировано ли достижение для пользователя
    func isUnlockedForUser(_ userID: UUID) -> Bool {
        return progressRecords.first { $0.userID == userID }?.isUnlocked ?? false
    }
}

// MARK: - AchievementCategory
enum AchievementCategory: String, CaseIterable, Codable {
    case habits = "habits"
    case tasks = "tasks"
    case finance = "finance"
    case goals = "goals"
    case streaks = "streaks"
    case milestones = "milestones"
    case social = "social"
    case special = "special"
    case seasonal = "seasonal"
    
    var localizedName: String {
        switch self {
        case .habits: return "Привычки"
        case .tasks: return "Задачи"
        case .finance: return "Финансы"
        case .goals: return "Цели"
        case .streaks: return "Серии"
        case .milestones: return "Вехи"
        case .social: return "Социальные"
        case .special: return "Особые"
        case .seasonal: return "Сезонные"
        }
    }
    
    var iconName: String {
        switch self {
        case .habits: return "repeat.circle"
        case .tasks: return "checkmark.circle"
        case .finance: return "dollarsign.circle"
        case .goals: return "target"
        case .streaks: return "flame"
        case .milestones: return "star.circle"
        case .social: return "person.2"
        case .special: return "sparkles"
        case .seasonal: return "calendar"
        }
    }
}

// MARK: - AchievementRarity
enum AchievementRarity: String, CaseIterable, Codable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case mythical = "mythical"
    
    var localizedName: String {
        switch self {
        case .common: return "Обычное"
        case .uncommon: return "Необычное"
        case .rare: return "Редкое"
        case .epic: return "Эпическое"
        case .legendary: return "Легендарное"
        case .mythical: return "Мифическое"
        }
    }
    
    var colorHex: String {
        switch self {
        case .common: return "#9E9E9E"
        case .uncommon: return "#4CAF50"
        case .rare: return "#2196F3"
        case .epic: return "#9C27B0"
        case .legendary: return "#FF9800"
        case .mythical: return "#F44336"
        }
    }
    
    var pointsMultiplier: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 5
        case .legendary: return 8
        case .mythical: return 12
        }
    }
}

// MARK: - AchievementProgress
@Model
final class AchievementProgress {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var achievementID: UUID
    var currentProgress: Int
    var targetProgress: Int
    var progressPercentage: Double
    var isUnlocked: Bool
    var unlockedAt: Date?
    var notificationSent: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    var achievement: Achievement?
    
    init(
        userID: UUID,
        achievementID: UUID,
        currentProgress: Int = 0,
        targetProgress: Int = 1
    ) {
        self.id = UUID()
        self.userID = userID
        self.achievementID = achievementID
        self.currentProgress = currentProgress
        self.targetProgress = targetProgress
        self.progressPercentage = targetProgress > 0 ? Double(currentProgress) / Double(targetProgress) : 0.0
        self.isUnlocked = false
        self.notificationSent = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Обновляет прогресс и проверяет разблокировку
    func updateProgress(_ newProgress: Int) {
        currentProgress = newProgress
        progressPercentage = targetProgress > 0 ? Double(currentProgress) / Double(targetProgress) : 0.0
        
        if currentProgress >= targetProgress && !isUnlocked {
            unlock()
        }
        
        updatedAt = Date()
        needsSync = true
    }
    
    /// Разблокирует достижение
    func unlock() {
        isUnlocked = true
        unlockedAt = Date()
        notificationSent = false
        needsSync = true
    }
    
    /// Процент прогресса в виде строки
    var progressString: String {
        return String(format: "%.1f%%", progressPercentage * 100)
    }
}

// MARK: - UserLevel
@Model
final class UserLevel {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var currentLevel: Int
    var currentXP: Int
    var totalXP: Int
    var xpToNextLevel: Int
    var prestigeLevel: Int
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \LevelProgress.userLevel)
    var levelHistory: [LevelProgress]
    
    init(userID: UUID) {
        self.id = UUID()
        self.userID = userID
        self.currentLevel = 1
        self.currentXP = 0
        self.totalXP = 0
        self.xpToNextLevel = UserLevel.calculateXPRequirement(for: 2)
        self.prestigeLevel = 0
        self.title = "Новичок"
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Добавляет XP и проверяет повышение уровня
    func addXP(_ amount: Int) -> Bool {
        let oldLevel = currentLevel
        currentXP += amount
        totalXP += amount
        
        // Проверяем повышение уровня
        while currentXP >= xpToNextLevel {
            currentXP -= xpToNextLevel
            currentLevel += 1
            
            // Записываем историю повышения уровня
            let levelProgress = LevelProgress(
                userID: userID,
                level: currentLevel,
                xpGained: xpToNextLevel,
                achievedAt: Date()
            )
            levelHistory.append(levelProgress)
            
            // Обновляем требования для следующего уровня
            xpToNextLevel = UserLevel.calculateXPRequirement(for: currentLevel + 1)
        }
        
        // Обновляем титул
        title = UserLevel.titleForLevel(currentLevel)
        updatedAt = Date()
        needsSync = true
        
        return currentLevel > oldLevel
    }
    
    /// Вычисляет требования XP для уровня
    static func calculateXPRequirement(for level: Int) -> Int {
        // Прогрессивная формула: base * level^1.5
        let baseXP = 100
        return Int(Double(baseXP) * pow(Double(level), 1.5))
    }
    
    /// Возвращает титул для уровня
    static func titleForLevel(_ level: Int) -> String {
        switch level {
        case 1...5: return "Новичок"
        case 6...10: return "Ученик"
        case 11...20: return "Практик"
        case 21...35: return "Эксперт"
        case 36...50: return "Мастер"
        case 51...70: return "Гуру"
        case 71...90: return "Легенда"
        case 91...100: return "Чемпион"
        default: return "Бессмертный"
        }
    }
    
    /// Процент прогресса к следующему уровню
    var progressToNextLevel: Double {
        let totalXPForNextLevel = UserLevel.calculateXPRequirement(for: currentLevel + 1)
        return Double(currentXP) / Double(totalXPForNextLevel)
    }
}

// MARK: - LevelProgress
@Model
final class LevelProgress {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var level: Int
    var xpGained: Int
    var achievedAt: Date
    var rewardsClaimed: Bool
    var createdAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    var userLevel: UserLevel?
    
    init(
        userID: UUID,
        level: Int,
        xpGained: Int,
        achievedAt: Date
    ) {
        self.id = UUID()
        self.userID = userID
        self.level = level
        self.xpGained = xpGained
        self.achievedAt = achievedAt
        self.rewardsClaimed = false
        self.createdAt = Date()
        self.needsSync = true
    }
    
    /// Отмечает награды как полученные
    func claimRewards() {
        rewardsClaimed = true
        needsSync = true
    }
}

// MARK: - PointsHistory
@Model
final class PointsHistory {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var amount: Int
    var source: PointsSource
    var sourceID: UUID?
    var reason: String
    var multiplier: Double
    var bonusPoints: Int
    var earnedAt: Date
    var createdAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    init(
        userID: UUID,
        amount: Int,
        source: PointsSource,
        sourceID: UUID? = nil,
        reason: String,
        multiplier: Double = 1.0,
        bonusPoints: Int = 0
    ) {
        self.id = UUID()
        self.userID = userID
        self.amount = amount
        self.source = source
        self.sourceID = sourceID
        self.reason = reason
        self.multiplier = multiplier
        self.bonusPoints = bonusPoints
        self.earnedAt = Date()
        self.createdAt = Date()
        self.needsSync = true
    }
    
    /// Общие очки с учетом множителя и бонусов
    var totalPoints: Int {
        return Int(Double(amount) * multiplier) + bonusPoints
    }
}

// MARK: - PointsSource
enum PointsSource: String, CaseIterable, Codable {
    case habitCompleted = "habit_completed"
    case taskCompleted = "task_completed"
    case goalAchieved = "goal_achieved"
    case streakMilestone = "streak_milestone"
    case achievementUnlocked = "achievement_unlocked"
    case levelUp = "level_up"
    case challengeCompleted = "challenge_completed"
    case dailyLogin = "daily_login"
    case weeklyGoal = "weekly_goal"
    case monthlyGoal = "monthly_goal"
    case specialEvent = "special_event"
    case bonus = "bonus"
    
    var localizedName: String {
        switch self {
        case .habitCompleted: return "Выполнена привычка"
        case .taskCompleted: return "Выполнена задача"
        case .goalAchieved: return "Достигнута цель"
        case .streakMilestone: return "Веха серии"
        case .achievementUnlocked: return "Разблокировано достижение"
        case .levelUp: return "Повышение уровня"
        case .challengeCompleted: return "Выполнен вызов"
        case .dailyLogin: return "Ежедневный вход"
        case .weeklyGoal: return "Недельная цель"
        case .monthlyGoal: return "Месячная цель"
        case .specialEvent: return "Особое событие"
        case .bonus: return "Бонус"
        }
    }
    
    var iconName: String {
        switch self {
        case .habitCompleted: return "repeat.circle.fill"
        case .taskCompleted: return "checkmark.circle.fill"
        case .goalAchieved: return "target"
        case .streakMilestone: return "flame.fill"
        case .achievementUnlocked: return "star.fill"
        case .levelUp: return "arrow.up.circle.fill"
        case .challengeCompleted: return "flag.fill"
        case .dailyLogin: return "calendar"
        case .weeklyGoal: return "7.circle.fill"
        case .monthlyGoal: return "calendar.circle.fill"
        case .specialEvent: return "sparkles"
        case .bonus: return "plus.circle.fill"
        }
    }
    
    var basePoints: Int {
        switch self {
        case .habitCompleted: return 10
        case .taskCompleted: return 15
        case .goalAchieved: return 50
        case .streakMilestone: return 25
        case .achievementUnlocked: return 100
        case .levelUp: return 200
        case .challengeCompleted: return 75
        case .dailyLogin: return 5
        case .weeklyGoal: return 100
        case .monthlyGoal: return 300
        case .specialEvent: return 150
        case .bonus: return 20
        }
    }
}

// MARK: - UserProgress
struct UserProgress {
    let userID: UUID
    let totalHabits: Int
    let completedHabits: Int
    let currentStreak: Int
    let longestStreak: Int
    let totalTasks: Int
    let completedTasks: Int
    let totalGoals: Int
    let achievedGoals: Int
    let totalXP: Int
    let currentLevel: Int
    let daysActive: Int
    let lastActiveDate: Date
    
    var completionRate: Double {
        return totalHabits > 0 ? Double(completedHabits) / Double(totalHabits) : 0.0
    }
    
    var taskCompletionRate: Double {
        return totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
    }
    
    var goalAchievementRate: Double {
        return totalGoals > 0 ? Double(achievedGoals) / Double(totalGoals) : 0.0
    }
} 