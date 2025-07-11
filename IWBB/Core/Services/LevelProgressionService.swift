import Foundation
import SwiftData

// MARK: - LevelProgressionService Protocol
protocol LevelProgressionServiceProtocol: ServiceProtocol {
    func getUserLevel(for userID: UUID) async throws -> UserLevel?
    func createUserLevel(for userID: UUID) async throws -> UserLevel
    func addXP(to userID: UUID, amount: Int) async throws -> Bool
    func calculateLevelForXP(_ xp: Int) -> Int
    func getXPRequiredForLevel(_ level: Int) -> Int
    func getXPRequiredForNextLevel(userLevel: UserLevel) -> Int
    func getLevelProgress(for userID: UUID) async throws -> LevelProgress?
    func getRecentLevelUps(for userID: UUID, limit: Int) async throws -> [LevelProgress]
    func getTopUsers(limit: Int) async throws -> [UserLevel]
    func getUserRank(for userID: UUID) async throws -> Int?
    func getPrestigeRequirements() -> (level: Int, multiplier: Double)
    func performPrestige(for userID: UUID) async throws -> Bool
    func getLevelRewards(for level: Int) -> [LevelReward]
    func claimLevelReward(for userID: UUID, level: Int) async throws -> Bool
}

// MARK: - LevelProgressionService Implementation
final class LevelProgressionService: LevelProgressionServiceProtocol {
    
    // MARK: - Properties
    private let modelContext: ModelContext
    private let pointsService: PointsCalculationServiceProtocol
    private let achievementService: AchievementServiceProtocol
    private let notificationService: NotificationServiceProtocol
    var isInitialized: Bool = false
    
    // Constants
    private let baseXPRequirement = 100
    private let xpGrowthRate = 1.5
    private let prestigeLevel = 100
    private let prestigeMultiplier = 2.0
    
    // MARK: - Initialization
    init(
        modelContext: ModelContext,
        pointsService: PointsCalculationServiceProtocol,
        achievementService: AchievementServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.modelContext = modelContext
        self.pointsService = pointsService
        self.achievementService = achievementService
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        #if DEBUG
        print("LevelProgressionService initializing...")
        #endif
        
        guard !modelContext.isMainActor else {
            throw ServiceError.initializationFailed("ModelContext is not available")
        }
        
        isInitialized = true
        
        #if DEBUG
        print("LevelProgressionService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("LevelProgressionService cleaning up...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("LevelProgressionService cleaned up")
        #endif
    }
    
    // MARK: - User Level Management
    func getUserLevel(for userID: UUID) async throws -> UserLevel? {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<UserLevel> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserLevel>(predicate: predicate)
        
        do {
            let userLevels = try modelContext.fetch(descriptor)
            return userLevels.first
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch user level: \(error)")
        }
    }
    
    func createUserLevel(for userID: UUID) async throws -> UserLevel {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        // Проверяем, не существует ли уже уровень для пользователя
        if let existingLevel = try await getUserLevel(for: userID) {
            return existingLevel
        }
        
        let userLevel = UserLevel(userID: userID)
        modelContext.insert(userLevel)
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Created user level for user: \(userID)")
            #endif
            
            return userLevel
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to create user level: \(error)")
        }
    }
    
    func addXP(to userID: UUID, amount: Int) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard amount > 0 else {
            return false
        }
        
        // Получаем или создаем уровень пользователя
        var userLevel = try await getUserLevel(for: userID)
        if userLevel == nil {
            userLevel = try await createUserLevel(for: userID)
        }
        
        guard let level = userLevel else {
            throw ServiceError.dataOperationFailed("Failed to get or create user level")
        }
        
        // Добавляем XP и проверяем повышение уровня
        let leveledUp = level.addXP(amount)
        
        do {
            try modelContext.save()
            
            if leveledUp {
                // Отправляем уведомление о повышении уровня
                try await sendLevelUpNotification(for: userID, newLevel: level.currentLevel)
                
                // Начисляем бонусные очки за повышение уровня
                _ = try await pointsService.awardPoints(
                    to: userID,
                    amount: calculateLevelUpBonus(level: level.currentLevel),
                    source: .levelUp,
                    sourceID: nil,
                    reason: "Повышение до \(level.currentLevel) уровня"
                )
                
                // Проверяем достижения
                let userProgress = try await getUserProgress(for: userID)
                _ = try await achievementService.checkAchievements(for: userID, userProgress: userProgress)
                
                #if DEBUG
                print("User \(userID) leveled up to level \(level.currentLevel)")
                #endif
            }
            
            return leveledUp
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to add XP: \(error)")
        }
    }
    
    // MARK: - Level Calculations
    func calculateLevelForXP(_ xp: Int) -> Int {
        if xp <= 0 { return 1 }
        
        var level = 1
        var totalXPRequired = 0
        
        while totalXPRequired < xp {
            level += 1
            totalXPRequired += getXPRequiredForLevel(level)
        }
        
        return level - 1
    }
    
    func getXPRequiredForLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        
        // Экспоненциальная формула: base * (level ^ growthRate)
        return Int(Double(baseXPRequirement) * pow(Double(level), xpGrowthRate))
    }
    
    func getXPRequiredForNextLevel(userLevel: UserLevel) -> Int {
        return userLevel.xpToNextLevel
    }
    
    // MARK: - Level Progress
    func getLevelProgress(for userID: UUID) async throws -> LevelProgress? {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<LevelProgress> { 
            $0.userID == userID 
        }
        let descriptor = FetchDescriptor<LevelProgress>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        
        do {
            let progressRecords = try modelContext.fetch(descriptor)
            return progressRecords.first
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch level progress: \(error)")
        }
    }
    
    func getRecentLevelUps(for userID: UUID, limit: Int = 10) async throws -> [LevelProgress] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<LevelProgress> { $0.userID == userID }
        let descriptor = FetchDescriptor<LevelProgress>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            let levelUps = try modelContext.fetch(descriptor)
            return levelUps
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch recent level ups: \(error)")
        }
    }
    
    // MARK: - Leaderboards & Rankings
    func getTopUsers(limit: Int = 50) async throws -> [UserLevel] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let descriptor = FetchDescriptor<UserLevel>(
            sortBy: [
                SortDescriptor(\.currentLevel, order: .reverse),
                SortDescriptor(\.totalXP, order: .reverse)
            ]
        )
        descriptor.fetchLimit = limit
        
        do {
            let topUsers = try modelContext.fetch(descriptor)
            return topUsers
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch top users: \(error)")
        }
    }
    
    func getUserRank(for userID: UUID) async throws -> Int? {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let userLevel = try await getUserLevel(for: userID) else {
            return nil
        }
        
        // Подсчитываем количество пользователей с более высоким уровнем или XP
        let predicate = #Predicate<UserLevel> { otherLevel in
            otherLevel.currentLevel > userLevel.currentLevel ||
            (otherLevel.currentLevel == userLevel.currentLevel && otherLevel.totalXP > userLevel.totalXP)
        }
        let descriptor = FetchDescriptor<UserLevel>(predicate: predicate)
        
        do {
            let higherLevelUsers = try modelContext.fetch(descriptor)
            return higherLevelUsers.count + 1
        } catch {
            throw ServiceError.dataOperationFailed("Failed to calculate user rank: \(error)")
        }
    }
    
    // MARK: - Prestige System
    func getPrestigeRequirements() -> (level: Int, multiplier: Double) {
        return (level: prestigeLevel, multiplier: prestigeMultiplier)
    }
    
    func performPrestige(for userID: UUID) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let userLevel = try await getUserLevel(for: userID) else {
            throw ServiceError.invalidParameters("User level not found")
        }
        
        // Проверяем требования для престижа
        guard userLevel.currentLevel >= prestigeLevel else {
            return false
        }
        
        // Выполняем престиж
        userLevel.prestigeLevel += 1
        userLevel.currentLevel = 1
        userLevel.currentXP = 0
        userLevel.totalXP = 0
        userLevel.xpToNextLevel = UserLevel.calculateXPRequirement(for: 2)
        userLevel.title = "★\(userLevel.prestigeLevel) " + UserLevel.titleForLevel(1)
        userLevel.updatedAt = Date()
        userLevel.needsSync = true
        
        // Создаем запись о престиже
        let prestigeProgress = LevelProgress(
            userID: userID,
            level: 1,
            xpGained: 0,
            achievedAt: Date()
        )
        modelContext.insert(prestigeProgress)
        
        do {
            try modelContext.save()
            
            // Начисляем престижные очки
            _ = try await pointsService.awardPoints(
                to: userID,
                amount: calculatePrestigeBonus(prestigeLevel: userLevel.prestigeLevel),
                source: .special,
                sourceID: nil,
                reason: "Престиж уровень \(userLevel.prestigeLevel)"
            )
            
            // Отправляем уведомление
            try await sendPrestigeNotification(for: userID, prestigeLevel: userLevel.prestigeLevel)
            
            #if DEBUG
            print("User \(userID) performed prestige to level \(userLevel.prestigeLevel)")
            #endif
            
            return true
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to perform prestige: \(error)")
        }
    }
    
    // MARK: - Level Rewards
    func getLevelRewards(for level: Int) -> [LevelReward] {
        var rewards: [LevelReward] = []
        
        // Основные награды за уровни
        if level % 5 == 0 {
            // Каждые 5 уровней - особая награда
            rewards.append(LevelReward(
                type: .points,
                value: level * 50,
                title: "Бонусные очки",
                description: "Получите \(level * 50) очков"
            ))
        }
        
        if level % 10 == 0 {
            // Каждые 10 уровней - титул
            rewards.append(LevelReward(
                type: .title,
                value: 0,
                title: "Новый титул",
                description: "Разблокирован титул: \(UserLevel.titleForLevel(level))"
            ))
        }
        
        if level % 25 == 0 {
            // Каждые 25 уровней - особые привилегии
            rewards.append(LevelReward(
                type: .feature,
                value: 0,
                title: "Премиум функция",
                description: "Разблокированы дополнительные возможности"
            ))
        }
        
        // Особые вехи
        switch level {
        case 1:
            rewards.append(LevelReward(
                type: .achievement,
                value: 0,
                title: "Добро пожаловать!",
                description: "Вы начали свой путь к совершенству"
            ))
        case 50:
            rewards.append(LevelReward(
                type: .theme,
                value: 0,
                title: "Золотая тема",
                description: "Разблокирована эксклюзивная золотая тема"
            ))
        case 100:
            rewards.append(LevelReward(
                type: .special,
                value: 0,
                title: "Возможность престижа",
                description: "Теперь вы можете выполнить престиж"
            ))
        default:
            break
        }
        
        return rewards
    }
    
    func claimLevelReward(for userID: UUID, level: Int) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let userLevel = try await getUserLevel(for: userID) else {
            throw ServiceError.invalidParameters("User level not found")
        }
        
        // Проверяем, достиг ли пользователь этого уровня
        guard userLevel.currentLevel >= level else {
            return false
        }
        
        // Проверяем, не получал ли уже награды
        let levelProgress = userLevel.levelHistory.first { $0.level == level }
        guard let progress = levelProgress, !progress.rewardsClaimed else {
            return false
        }
        
        // Отмечаем награды как полученные
        progress.claimRewards()
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Level rewards claimed for user \(userID) at level \(level)")
            #endif
            
            return true
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to claim level reward: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getUserProgress(for userID: UUID) async throws -> UserProgress {
        // Получаем статистику пользователя для проверки достижений
        // Это упрощенная версия, в реальности нужно собирать данные из других сервисов
        
        guard let userLevel = try await getUserLevel(for: userID) else {
            throw ServiceError.dataOperationFailed("User level not found")
        }
        
        return UserProgress(
            userID: userID,
            totalHabits: 0, // Получить из HabitService
            completedHabits: 0,
            currentStreak: 0,
            longestStreak: 0,
            totalTasks: 0, // Получить из TaskService
            completedTasks: 0,
            totalGoals: 0, // Получить из GoalService
            achievedGoals: 0,
            totalXP: userLevel.totalXP,
            currentLevel: userLevel.currentLevel,
            daysActive: 0, // Вычислить из истории активности
            lastActiveDate: Date()
        )
    }
    
    private func calculateLevelUpBonus(level: Int) -> Int {
        // Бонус за повышение уровня
        switch level {
        case 1...10: return level * 10
        case 11...25: return level * 15
        case 26...50: return level * 20
        case 51...75: return level * 25
        case 76...100: return level * 30
        default: return level * 50
        }
    }
    
    private func calculatePrestigeBonus(prestigeLevel: Int) -> Int {
        // Экспоненциальный бонус за престиж
        return Int(1000 * pow(Double(prestigeLevel), 1.5))
    }
    
    private func sendLevelUpNotification(for userID: UUID, newLevel: Int) async throws {
        // Отправляем уведомление о повышении уровня
        #if DEBUG
        print("Sending level up notification for user \(userID), new level: \(newLevel)")
        #endif
        
        // Здесь будет логика отправки уведомления
        // Пока оставляем заглушку
    }
    
    private func sendPrestigeNotification(for userID: UUID, prestigeLevel: Int) async throws {
        // Отправляем уведомление о престиже
        #if DEBUG
        print("Sending prestige notification for user \(userID), prestige level: \(prestigeLevel)")
        #endif
        
        // Здесь будет логика отправки уведомления
        // Пока оставляем заглушку
    }
}

// MARK: - Supporting Types

struct LevelReward {
    let type: RewardType
    let value: Int
    let title: String
    let description: String
}

enum LevelRewardType {
    case points
    case xp
    case title
    case theme
    case feature
    case achievement
    case special
} 