import Foundation
import SwiftData

// MARK: - Badge
@Model
final class Badge {
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String
    var iconName: String
    var colorHex: String
    var category: BadgeCategory
    var rarity: BadgeRarity
    var condition: BadgeCondition
    var isSecret: Bool
    var isActive: Bool
    var isSeasonal: Bool
    var seasonStartDate: Date?
    var seasonEndDate: Date?
    var unlockedCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \BadgeProgress.badge)
    var progressRecords: [BadgeProgress]
    
    init(
        name: String,
        description: String,
        iconName: String,
        colorHex: String,
        category: BadgeCategory,
        rarity: BadgeRarity,
        condition: BadgeCondition,
        isSecret: Bool = false,
        isActive: Bool = true,
        isSeasonal: Bool = false,
        seasonStartDate: Date? = nil,
        seasonEndDate: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.iconName = iconName
        self.colorHex = colorHex
        self.category = category
        self.rarity = rarity
        self.condition = condition
        self.isSecret = isSecret
        self.isActive = isActive
        self.isSeasonal = isSeasonal
        self.seasonStartDate = seasonStartDate
        self.seasonEndDate = seasonEndDate
        self.unlockedCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Проверяет, доступен ли значок в данный момент
    var isCurrentlyAvailable: Bool {
        guard isActive else { return false }
        
        if isSeasonal {
            let now = Date()
            guard let start = seasonStartDate, let end = seasonEndDate else { return false }
            return now >= start && now <= end
        }
        
        return true
    }
    
    /// Прогресс значка для пользователя
    func progressForUser(_ userID: UUID) -> BadgeProgress? {
        return progressRecords.first { $0.userID == userID }
    }
    
    /// Разблокирован ли значок для пользователя
    func isUnlockedForUser(_ userID: UUID) -> Bool {
        return progressRecords.first { $0.userID == userID }?.isUnlocked ?? false
    }
    
    /// Увеличивает счетчик разблокировок
    func incrementUnlockedCount() {
        unlockedCount += 1
        updatedAt = Date()
        needsSync = true
    }
}

// MARK: - BadgeCategory
enum BadgeCategory: String, CaseIterable, Codable {
    case habits = "habits"
    case tasks = "tasks"
    case goals = "goals"
    case streaks = "streaks"
    case milestones = "milestones"
    case achievements = "achievements"
    case challenges = "challenges"
    case social = "social"
    case seasonal = "seasonal"
    case special = "special"
    
    var localizedName: String {
        switch self {
        case .habits: return "Привычки"
        case .tasks: return "Задачи"
        case .goals: return "Цели"
        case .streaks: return "Серии"
        case .milestones: return "Вехи"
        case .achievements: return "Достижения"
        case .challenges: return "Вызовы"
        case .social: return "Социальные"
        case .seasonal: return "Сезонные"
        case .special: return "Особые"
        }
    }
    
    var iconName: String {
        switch self {
        case .habits: return "repeat.circle"
        case .tasks: return "checkmark.circle"
        case .goals: return "target"
        case .streaks: return "flame"
        case .milestones: return "flag"
        case .achievements: return "star"
        case .challenges: return "trophy"
        case .social: return "person.2"
        case .seasonal: return "calendar"
        case .special: return "sparkles"
        }
    }
}

// MARK: - BadgeRarity
enum BadgeRarity: String, CaseIterable, Codable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
    case diamond = "diamond"
    case legendary = "legendary"
    
    var localizedName: String {
        switch self {
        case .bronze: return "Бронзовый"
        case .silver: return "Серебряный"
        case .gold: return "Золотой"
        case .platinum: return "Платиновый"
        case .diamond: return "Бриллиантовый"
        case .legendary: return "Легендарный"
        }
    }
    
    var colorHex: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        case .diamond: return "#B9F2FF"
        case .legendary: return "#9C27B0"
        }
    }
    
    var pointsValue: Int {
        switch self {
        case .bronze: return 25
        case .silver: return 50
        case .gold: return 100
        case .platinum: return 200
        case .diamond: return 500
        case .legendary: return 1000
        }
    }
}

// MARK: - BadgeCondition
struct BadgeCondition: Codable {
    let type: BadgeConditionType
    let targetValue: Int
    let category: String?
    let timeframe: TimeFrame?
    let additionalParameters: [String: Any]?
    
    enum BadgeConditionType: String, CaseIterable, Codable {
        case habitStreak = "habit_streak"
        case habitTotal = "habit_total"
        case taskCompletion = "task_completion"
        case goalAchievement = "goal_achievement"
        case perfectDay = "perfect_day"
        case perfectWeek = "perfect_week"
        case perfectMonth = "perfect_month"
        case pointsEarned = "points_earned"
        case levelReached = "level_reached"
        case achievementCount = "achievement_count"
        case challengeWon = "challenge_won"
        case consecutiveDays = "consecutive_days"
        case categoryMastery = "category_mastery"
        case earlyBird = "early_bird"
        case nightOwl = "night_owl"
        case comeback = "comeback"
        case milestone = "milestone"
        case social = "social"
        case seasonal = "seasonal"
        case special = "special"
    }
    
    enum TimeFrame: String, CaseIterable, Codable {
        case day = "day"
        case week = "week"
        case month = "month"
        case quarter = "quarter"
        case year = "year"
        case allTime = "all_time"
    }
    
    init(
        type: BadgeConditionType,
        targetValue: Int,
        category: String? = nil,
        timeframe: TimeFrame? = nil,
        additionalParameters: [String: Any]? = nil
    ) {
        self.type = type
        self.targetValue = targetValue
        self.category = category
        self.timeframe = timeframe
        self.additionalParameters = additionalParameters
    }
}

// MARK: - BadgeProgress
@Model
final class BadgeProgress {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var badgeID: UUID
    var currentProgress: Int
    var targetProgress: Int
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
    var badge: Badge?
    
    init(
        userID: UUID,
        badgeID: UUID,
        targetProgress: Int
    ) {
        self.id = UUID()
        self.userID = userID
        self.badgeID = badgeID
        self.currentProgress = 0
        self.targetProgress = targetProgress
        self.isUnlocked = false
        self.notificationSent = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Обновляет прогресс значка
    func updateProgress(_ newProgress: Int) {
        currentProgress = newProgress
        
        if currentProgress >= targetProgress && !isUnlocked {
            unlock()
        }
        
        updatedAt = Date()
        needsSync = true
    }
    
    /// Разблокирует значок
    func unlock() {
        isUnlocked = true
        unlockedAt = Date()
        notificationSent = false
        badge?.incrementUnlockedCount()
        needsSync = true
    }
    
    /// Процент прогресса
    var progressPercentage: Double {
        return targetProgress > 0 ? Double(currentProgress) / Double(targetProgress) : 0.0
    }
    
    /// Процент прогресса в виде строки
    var progressString: String {
        return String(format: "%.1f%%", progressPercentage * 100)
    }
}

// MARK: - StreakRecord
@Model
final class StreakRecord {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var entityID: UUID // ID привычки или задачи
    var entityType: StreakEntityType
    var currentStreak: Int
    var longestStreak: Int
    var lastActivityDate: Date
    var streakStartDate: Date
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    init(
        userID: UUID,
        entityID: UUID,
        entityType: StreakEntityType
    ) {
        self.id = UUID()
        self.userID = userID
        self.entityID = entityID
        self.entityType = entityType
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastActivityDate = Date()
        self.streakStartDate = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Обновляет серию
    func updateStreak(activityDate: Date) {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: activityDate) ?? Date()
        
        if calendar.isDate(lastActivityDate, inSameDayAs: yesterday) {
            // Продолжаем серию
            currentStreak += 1
        } else if calendar.isDate(lastActivityDate, inSameDayAs: activityDate) {
            // Уже отмечено на сегодня
            return
        } else {
            // Серия прервана, начинаем новую
            currentStreak = 1
            streakStartDate = activityDate
        }
        
        lastActivityDate = activityDate
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        updatedAt = Date()
        needsSync = true
    }
    
    /// Проверяет, продолжается ли серия
    func checkStreakContinuity(currentDate: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? Date()
        
        return calendar.isDate(lastActivityDate, inSameDayAs: currentDate) ||
               calendar.isDate(lastActivityDate, inSameDayAs: yesterday)
    }
    
    /// Сбрасывает серию
    func resetStreak() {
        currentStreak = 0
        streakStartDate = Date()
        updatedAt = Date()
        needsSync = true
    }
}

// MARK: - StreakEntityType
enum StreakEntityType: String, CaseIterable, Codable {
    case habit = "habit"
    case task = "task"
    case goal = "goal"
    case challenge = "challenge"
    case overall = "overall"
    
    var localizedName: String {
        switch self {
        case .habit: return "Привычка"
        case .task: return "Задача"
        case .goal: return "Цель"
        case .challenge: return "Вызов"
        case .overall: return "Общая"
        }
    }
}

// MARK: - Reward
@Model
final class Reward {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var type: RewardType
    var title: String
    var description: String
    var value: String // JSON или строковое значение
    var isCollected: Bool
    var collectedAt: Date?
    var expiresAt: Date?
    var sourceType: RewardSourceType
    var sourceID: UUID?
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    init(
        userID: UUID,
        type: RewardType,
        title: String,
        description: String,
        value: String,
        sourceType: RewardSourceType,
        sourceID: UUID? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = UUID()
        self.userID = userID
        self.type = type
        self.title = title
        self.description = description
        self.value = value
        self.isCollected = false
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.expiresAt = expiresAt
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Собирает награду
    func collect() {
        isCollected = true
        collectedAt = Date()
        updatedAt = Date()
        needsSync = true
    }
    
    /// Проверяет, истекла ли награда
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// Дней до истечения
    var daysUntilExpiry: Int? {
        guard let expiresAt = expiresAt else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: Date(), to: expiresAt).day
    }
}

// MARK: - RewardType
enum RewardType: String, CaseIterable, Codable {
    case points = "points"
    case xp = "xp"
    case badge = "badge"
    case title = "title"
    case theme = "theme"
    case feature = "feature"
    case achievement = "achievement"
    case special = "special"
    
    var localizedName: String {
        switch self {
        case .points: return "Очки"
        case .xp: return "Опыт"
        case .badge: return "Значок"
        case .title: return "Титул"
        case .theme: return "Тема"
        case .feature: return "Функция"
        case .achievement: return "Достижение"
        case .special: return "Особая награда"
        }
    }
    
    var iconName: String {
        switch self {
        case .points: return "star.circle"
        case .xp: return "arrow.up.circle"
        case .badge: return "rosette"
        case .title: return "crown"
        case .theme: return "paintbrush"
        case .feature: return "gear"
        case .achievement: return "trophy"
        case .special: return "sparkles"
        }
    }
}

// MARK: - RewardSourceType
enum RewardSourceType: String, CaseIterable, Codable {
    case achievement = "achievement"
    case badge = "badge"
    case challenge = "challenge"
    case levelUp = "level_up"
    case milestone = "milestone"
    case special = "special"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var localizedName: String {
        switch self {
        case .achievement: return "Достижение"
        case .badge: return "Значок"
        case .challenge: return "Вызов"
        case .levelUp: return "Повышение уровня"
        case .milestone: return "Веха"
        case .special: return "Особое событие"
        case .daily: return "Ежедневная награда"
        case .weekly: return "Недельная награда"
        case .monthly: return "Месячная награда"
        }
    }
} 