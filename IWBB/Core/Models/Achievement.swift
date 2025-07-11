import Foundation
import SwiftData

// MARK: - Achievement Model

@Model
final class Achievement: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String
    var type: AchievementType
    var category: AchievementCategory
    var rarity: AchievementRarity
    
    // Критерии достижения
    var criteria: AchievementCriteria
    var targetValue: Double // Целевое значение для достижения
    var currentProgress: Double // Текущий прогресс
    
    // Статус
    var isUnlocked: Bool
    var isSecret: Bool // Скрытое достижение
    var unlockedDate: Date?
    
    // Визуализация
    var icon: String // SF Symbol name
    var color: String // Hex color
    var badgeImage: String? // Название изображения значка
    
    // Награды
    var pointsReward: Int
    var experienceReward: Int
    var unlockableContent: String? // Разблокируемый контент
    var specialReward: String? // Описание особой награды
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    
    // MARK: - Initializers
    
    init(
        title: String,
        description: String,
        type: AchievementType,
        category: AchievementCategory = .general,
        rarity: AchievementRarity = .common,
        criteria: AchievementCriteria,
        targetValue: Double,
        pointsReward: Int = 0,
        experienceReward: Int = 0,
        isSecret: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.type = type
        self.category = category
        self.rarity = rarity
        self.criteria = criteria
        self.targetValue = targetValue
        self.currentProgress = 0.0
        self.pointsReward = pointsReward
        self.experienceReward = experienceReward
        self.isSecret = isSecret
        
        // Статус
        self.isUnlocked = false
        
        // Визуализация
        self.icon = type.defaultIcon
        self.color = rarity.color
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
}

// MARK: - Achievement Extensions

extension Achievement: Validatable {
    func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if targetValue <= 0 {
            throw ModelValidationError.missingRequiredField("Целевое значение должно быть больше 0")
        }
        
        if currentProgress < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

extension Achievement {
    
    // MARK: - Computed Properties
    
    /// Прогресс выполнения (0.0 - 1.0)
    var progress: Double {
        guard targetValue > 0 else { return 0.0 }
        return min(currentProgress / targetValue, 1.0)
    }
    
    /// Прогресс в процентах
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    /// Готово ли достижение к разблокировке
    var isReadyToUnlock: Bool {
        return !isUnlocked && progress >= 1.0
    }
    
    /// Форматированный прогресс
    var formattedProgress: String {
        switch criteria {
        case .streakDays, .completedHabits, .completedTasks, .completedGoals, .daysActive:
            return "\(Int(currentProgress)) из \(Int(targetValue))"
        case .totalPoints, .level:
            return "\(Int(currentProgress))/\(Int(targetValue))"
        case .savingsAmount, .spentAmount:
            return String(format: "%.0f из %.0f ₽", currentProgress, targetValue)
        case .custom:
            return "\(Int(currentProgress))/\(Int(targetValue))"
        }
    }
    
    /// Название для отображения (скрывает секретные)
    var displayTitle: String {
        if isSecret && !isUnlocked {
            return "???"
        }
        return title
    }
    
    /// Описание для отображения (скрывает секретные)
    var displayDescription: String {
        if isSecret && !isUnlocked {
            return "Секретное достижение"
        }
        return description
    }
    
    /// Эмодзи для типа достижения
    var typeEmoji: String {
        return type.emoji
    }
    
    // MARK: - Achievement Management
    
    /// Обновляет прогресс достижения
    func updateProgress(_ newProgress: Double, shouldAutoUnlock: Bool = true) {
        let oldProgress = currentProgress
        currentProgress = max(0, newProgress)
        
        // Автоматическое разблокирование
        if shouldAutoUnlock && !isUnlocked && currentProgress >= targetValue {
            unlock()
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Увеличивает прогресс на значение
    func incrementProgress(by value: Double, shouldAutoUnlock: Bool = true) {
        updateProgress(currentProgress + value, shouldAutoUnlock: shouldAutoUnlock)
    }
    
    /// Разблокирует достижение
    func unlock() {
        guard !isUnlocked else { return }
        
        isUnlocked = true
        unlockedDate = Date()
        
        // Награждаем пользователя
        if let user = user {
            user.addExperience(experienceReward)
            // user.addPoints(pointsReward) - если есть отдельная система очков
        }
        
        updateTimestamp()
        markForSync()
    }
    
    /// Сбрасывает достижение (для тестирования)
    func reset() {
        isUnlocked = false
        unlockedDate = nil
        currentProgress = 0.0
        updateTimestamp()
        markForSync()
    }
    
    /// Проверяет условие достижения
    func checkCondition(for user: User) -> Bool {
        let currentValue = getCurrentValue(for: user)
        return currentValue >= targetValue
    }
    
    /// Получает текущее значение для критерия
    private func getCurrentValue(for user: User) -> Double {
        switch criteria {
        case .streakDays:
            return Double(user.currentStreak)
        case .completedHabits:
            return Double(user.totalHabitsCompleted)
        case .completedTasks:
            return Double(user.totalTasksCompleted)
        case .completedGoals:
            return Double(user.goals.filter { $0.isCompleted }.count)
        case .totalPoints:
            return Double(user.totalPoints)
        case .level:
            return Double(user.level)
        case .daysActive:
            return Double(user.totalDaysActive)
        case .savingsAmount:
            // Подсчет общих сбережений (доходы - расходы)
            let income = user.transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.convertedAmount }
            let expenses = user.transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.convertedAmount }
            return Double(income - expenses)
        case .spentAmount:
            // Общая потраченная сумма
            return Double(user.transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.convertedAmount })
        case .custom:
            return currentProgress // Для пользовательских критериев используем сохраненный прогресс
        }
    }
    
    /// Обновляет прогресс на основе данных пользователя
    func updateProgressFromUser(_ user: User) {
        let newProgress = getCurrentValue(for: user)
        updateProgress(newProgress)
    }
}

// MARK: - Supporting Enums

enum AchievementType: String, Codable, CaseIterable {
    case habit = "habit"
    case task = "task"
    case goal = "goal"
    case finance = "finance"
    case streak = "streak"
    case level = "level"
    case social = "social"
    case milestone = "milestone"
    case special = "special"
    
    var displayName: String {
        switch self {
        case .habit: return "Привычки"
        case .task: return "Задачи"
        case .goal: return "Цели"
        case .finance: return "Финансы"
        case .streak: return "Серии"
        case .level: return "Уровень"
        case .social: return "Социальные"
        case .milestone: return "Вехи"
        case .special: return "Особые"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .habit: return "repeat.circle"
        case .task: return "checkmark.circle"
        case .goal: return "target"
        case .finance: return "dollarsign.circle"
        case .streak: return "flame"
        case .level: return "star.circle"
        case .social: return "person.2.circle"
        case .milestone: return "flag.circle"
        case .special: return "crown"
        }
    }
    
    var emoji: String {
        switch self {
        case .habit: return "🔁"
        case .task: return "✅"
        case .goal: return "🎯"
        case .finance: return "💰"
        case .streak: return "🔥"
        case .level: return "⭐"
        case .social: return "👥"
        case .milestone: return "🚩"
        case .special: return "👑"
        }
    }
}

enum AchievementCategory: String, Codable, CaseIterable {
    case general = "general"
    case productivity = "productivity"
    case health = "health"
    case finance = "finance"
    case social = "social"
    case creative = "creative"
    case learning = "learning"
    case lifestyle = "lifestyle"
    
    var displayName: String {
        switch self {
        case .general: return "Общие"
        case .productivity: return "Продуктивность"
        case .health: return "Здоровье"
        case .finance: return "Финансы"
        case .social: return "Социальные"
        case .creative: return "Творчество"
        case .learning: return "Обучение"
        case .lifestyle: return "Образ жизни"
        }
    }
}

enum AchievementRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        switch self {
        case .common: return "Обычное"
        case .uncommon: return "Необычное"
        case .rare: return "Редкое"
        case .epic: return "Эпическое"
        case .legendary: return "Легендарное"
        }
    }
    
    var color: String {
        switch self {
        case .common: return "#8E8E93"      // Gray
        case .uncommon: return "#34C759"    // Green
        case .rare: return "#007AFF"        // Blue
        case .epic: return "#AF52DE"        // Purple
        case .legendary: return "#FF9500"   // Orange
        }
    }
    
    var experienceMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.5
        case .rare: return 2.0
        case .epic: return 3.0
        case .legendary: return 5.0
        }
    }
}

enum AchievementCriteria: String, Codable, CaseIterable {
    case streakDays = "streak_days"
    case completedHabits = "completed_habits"
    case completedTasks = "completed_tasks"
    case completedGoals = "completed_goals"
    case totalPoints = "total_points"
    case level = "level"
    case daysActive = "days_active"
    case savingsAmount = "savings_amount"
    case spentAmount = "spent_amount"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .streakDays: return "Дни подряд"
        case .completedHabits: return "Выполненные привычки"
        case .completedTasks: return "Выполненные задачи"
        case .completedGoals: return "Достигнутые цели"
        case .totalPoints: return "Общие очки"
        case .level: return "Уровень"
        case .daysActive: return "Активные дни"
        case .savingsAmount: return "Сумма сбережений"
        case .spentAmount: return "Потраченная сумма"
        case .custom: return "Особый критерий"
        }
    }
}

// MARK: - Predefined Achievements

extension Achievement {
    
    /// Создает набор предустановленных достижений
    static func createDefaultAchievements() -> [Achievement] {
        var achievements: [Achievement] = []
        
        // Достижения за привычки
        achievements.append(contentsOf: [
            Achievement(
                title: "Первый шаг",
                description: "Выполните свою первую привычку",
                type: .habit,
                category: .general,
                rarity: .common,
                criteria: .completedHabits,
                targetValue: 1,
                pointsReward: 10,
                experienceReward: 50
            ),
            Achievement(
                title: "Приверженец",
                description: "Выполните 100 привычек",
                type: .habit,
                category: .productivity,
                rarity: .uncommon,
                criteria: .completedHabits,
                targetValue: 100,
                pointsReward: 100,
                experienceReward: 500
            ),
            Achievement(
                title: "Мастер привычек",
                description: "Выполните 1000 привычек",
                type: .habit,
                category: .productivity,
                rarity: .rare,
                criteria: .completedHabits,
                targetValue: 1000,
                pointsReward: 500,
                experienceReward: 2000
            )
        ])
        
        // Достижения за серии
        achievements.append(contentsOf: [
            Achievement(
                title: "Неделя силы воли",
                description: "Поддерживайте серию 7 дней",
                type: .streak,
                category: .productivity,
                rarity: .common,
                criteria: .streakDays,
                targetValue: 7,
                pointsReward: 50,
                experienceReward: 200
            ),
            Achievement(
                title: "Месяц дисциплины",
                description: "Поддерживайте серию 30 дней",
                type: .streak,
                category: .productivity,
                rarity: .uncommon,
                criteria: .streakDays,
                targetValue: 30,
                pointsReward: 200,
                experienceReward: 800
            ),
            Achievement(
                title: "Год постоянства",
                description: "Поддерживайте серию 365 дней",
                type: .streak,
                category: .lifestyle,
                rarity: .legendary,
                criteria: .streakDays,
                targetValue: 365,
                pointsReward: 2000,
                experienceReward: 10000,
                isSecret: true
            )
        ])
        
        // Достижения за задачи
        achievements.append(contentsOf: [
            Achievement(
                title: "Продуктивный день",
                description: "Выполните 10 задач",
                type: .task,
                category: .productivity,
                rarity: .common,
                criteria: .completedTasks,
                targetValue: 10,
                pointsReward: 20,
                experienceReward: 100
            ),
            Achievement(
                title: "Мега продуктивность",
                description: "Выполните 500 задач",
                type: .task,
                category: .productivity,
                rarity: .rare,
                criteria: .completedTasks,
                targetValue: 500,
                pointsReward: 300,
                experienceReward: 1500
            )
        ])
        
        // Достижения за цели
        achievements.append(contentsOf: [
            Achievement(
                title: "Целеустремленный",
                description: "Достигните своей первой цели",
                type: .goal,
                category: .general,
                rarity: .common,
                criteria: .completedGoals,
                targetValue: 1,
                pointsReward: 100,
                experienceReward: 300
            ),
            Achievement(
                title: "Покоритель вершин",
                description: "Достигните 10 целей",
                type: .goal,
                category: .productivity,
                rarity: .uncommon,
                criteria: .completedGoals,
                targetValue: 10,
                pointsReward: 500,
                experienceReward: 1000
            )
        ])
        
        // Финансовые достижения
        achievements.append(contentsOf: [
            Achievement(
                title: "Первые сбережения",
                description: "Накопите 10,000 рублей",
                type: .finance,
                category: .finance,
                rarity: .common,
                criteria: .savingsAmount,
                targetValue: 10000,
                pointsReward: 100,
                experienceReward: 500
            ),
            Achievement(
                title: "Финансовая подушка",
                description: "Накопите 100,000 рублей",
                type: .finance,
                category: .finance,
                rarity: .uncommon,
                criteria: .savingsAmount,
                targetValue: 100000,
                pointsReward: 500,
                experienceReward: 2000
            ),
            Achievement(
                title: "Миллионер",
                description: "Накопите 1,000,000 рублей",
                type: .finance,
                category: .finance,
                rarity: .legendary,
                criteria: .savingsAmount,
                targetValue: 1000000,
                pointsReward: 5000,
                experienceReward: 20000,
                isSecret: true
            )
        ])
        
        // Достижения за уровень
        achievements.append(contentsOf: [
            Achievement(
                title: "Новичок",
                description: "Достигните 5 уровня",
                type: .level,
                category: .general,
                rarity: .common,
                criteria: .level,
                targetValue: 5,
                pointsReward: 50,
                experienceReward: 200
            ),
            Achievement(
                title: "Эксперт",
                description: "Достигните 25 уровня",
                type: .level,
                category: .productivity,
                rarity: .uncommon,
                criteria: .level,
                targetValue: 25,
                pointsReward: 250,
                experienceReward: 1000
            ),
            Achievement(
                title: "Гуру продуктивности",
                description: "Достигните 50 уровня",
                type: .level,
                category: .productivity,
                rarity: .epic,
                criteria: .level,
                targetValue: 50,
                pointsReward: 1000,
                experienceReward: 5000
            )
        ])
        
        return achievements
    }
} 