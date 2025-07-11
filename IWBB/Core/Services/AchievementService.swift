import Foundation
import SwiftData

// MARK: - AchievementService Protocol
protocol AchievementServiceProtocol: ServiceProtocol {
    func createAchievement(_ achievement: Achievement) async throws
    func updateAchievement(_ achievement: Achievement) async throws
    func deleteAchievement(_ achievement: Achievement) async throws
    func getAchievements() async throws -> [Achievement]
    func getAchievementsForUser(_ userID: UUID) async throws -> [Achievement]
    func getUnlockedAchievements(for userID: UUID) async throws -> [Achievement]
    func getLockedAchievements(for userID: UUID) async throws -> [Achievement]
    func getAchievementProgress(for userID: UUID, achievementID: UUID) async throws -> AchievementProgress?
    func updateAchievementProgress(for userID: UUID, achievementID: UUID, progress: Int) async throws
    func checkAchievements(for userID: UUID, userProgress: UserProgress) async throws -> [Achievement]
    func unlockAchievement(for userID: UUID, achievementID: UUID) async throws -> Bool
    func getAchievementsByCategory(_ category: AchievementCategory) async throws -> [Achievement]
    func getAchievementsByRarity(_ rarity: AchievementRarity) async throws -> [Achievement]
    func createDefaultAchievements() async throws
}

// MARK: - AchievementService Implementation
final class AchievementService: AchievementServiceProtocol {
    
    // MARK: - Properties
    private let modelContext: ModelContext
    private let pointsService: PointsCalculationServiceProtocol
    private let notificationService: NotificationServiceProtocol
    var isInitialized: Bool = false
    
    // MARK: - Initialization
    init(
        modelContext: ModelContext,
        pointsService: PointsCalculationServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.modelContext = modelContext
        self.pointsService = pointsService
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        #if DEBUG
        print("AchievementService initializing...")
        #endif
        
        guard !modelContext.isMainActor else {
            throw ServiceError.initializationFailed("ModelContext is not available")
        }
        
        // Создаем базовые достижения при первом запуске
        try await createDefaultAchievements()
        
        isInitialized = true
        
        #if DEBUG
        print("AchievementService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("AchievementService cleaning up...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("AchievementService cleaned up")
        #endif
    }
    
    // MARK: - Achievement Management
    func createAchievement(_ achievement: Achievement) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        modelContext.insert(achievement)
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Created achievement: \(achievement.title)")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to create achievement: \(error)")
        }
    }
    
    func updateAchievement(_ achievement: Achievement) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        achievement.updatedAt = Date()
        achievement.needsSync = true
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Updated achievement: \(achievement.title)")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to update achievement: \(error)")
        }
    }
    
    func deleteAchievement(_ achievement: Achievement) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        modelContext.delete(achievement)
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Deleted achievement: \(achievement.title)")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to delete achievement: \(error)")
        }
    }
    
    // MARK: - Achievement Retrieval
    func getAchievements() async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<Achievement> { $0.isActive }
        let descriptor = FetchDescriptor<Achievement>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.category),
                SortDescriptor(\.rarity),
                SortDescriptor(\.title)
            ]
        )
        
        do {
            let achievements = try modelContext.fetch(descriptor)
            return achievements
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch achievements: \(error)")
        }
    }
    
    func getAchievementsForUser(_ userID: UUID) async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let achievements = try await getAchievements()
        
        // Фильтруем скрытые достижения для пользователя
        return achievements.filter { achievement in
            if achievement.isHidden {
                return achievement.isUnlockedForUser(userID)
            }
            return true
        }
    }
    
    func getUnlockedAchievements(for userID: UUID) async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let achievements = try await getAchievements()
        return achievements.filter { $0.isUnlockedForUser(userID) }
    }
    
    func getLockedAchievements(for userID: UUID) async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let achievements = try await getAchievements()
        return achievements.filter { !$0.isUnlockedForUser(userID) && !$0.isHidden }
    }
    
    func getAchievementProgress(for userID: UUID, achievementID: UUID) async throws -> AchievementProgress? {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<AchievementProgress> { 
            $0.userID == userID && $0.achievementID == achievementID 
        }
        let descriptor = FetchDescriptor<AchievementProgress>(predicate: predicate)
        
        do {
            let progressRecords = try modelContext.fetch(descriptor)
            return progressRecords.first
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch achievement progress: \(error)")
        }
    }
    
    func getAchievementsByCategory(_ category: AchievementCategory) async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<Achievement> { $0.category == category && $0.isActive }
        let descriptor = FetchDescriptor<Achievement>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.rarity),
                SortDescriptor(\.title)
            ]
        )
        
        do {
            let achievements = try modelContext.fetch(descriptor)
            return achievements
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch achievements by category: \(error)")
        }
    }
    
    func getAchievementsByRarity(_ rarity: AchievementRarity) async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<Achievement> { $0.rarity == rarity && $0.isActive }
        let descriptor = FetchDescriptor<Achievement>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.category),
                SortDescriptor(\.title)
            ]
        )
        
        do {
            let achievements = try modelContext.fetch(descriptor)
            return achievements
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch achievements by rarity: \(error)")
        }
    }
    
    // MARK: - Achievement Progress
    func updateAchievementProgress(for userID: UUID, achievementID: UUID, progress: Int) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        // Получаем или создаем запись прогресса
        var progressRecord = try await getAchievementProgress(for: userID, achievementID: achievementID)
        
        if progressRecord == nil {
            // Получаем достижение для определения целевого прогресса
            guard let achievement = try await getAchievement(by: achievementID) else {
                throw ServiceError.invalidParameters("Achievement not found")
            }
            
            let targetProgress = getTargetProgress(for: achievement)
            progressRecord = AchievementProgress(
                userID: userID,
                achievementID: achievementID,
                targetProgress: targetProgress
            )
            
            modelContext.insert(progressRecord!)
        }
        
        // Обновляем прогресс
        progressRecord!.updateProgress(progress)
        
        do {
            try modelContext.save()
            
            // Проверяем разблокировку
            if progressRecord!.isUnlocked && !progressRecord!.notificationSent {
                try await sendAchievementNotification(for: userID, achievement: progressRecord!.achievement!)
                progressRecord!.notificationSent = true
                try modelContext.save()
            }
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to update achievement progress: \(error)")
        }
    }
    
    func checkAchievements(for userID: UUID, userProgress: UserProgress) async throws -> [Achievement] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let achievements = try await getAchievements()
        var unlockedAchievements: [Achievement] = []
        
        for achievement in achievements {
            guard !achievement.isUnlockedForUser(userID) else { continue }
            
            if try await checkAchievementRequirements(achievement, userProgress: userProgress) {
                let wasUnlocked = try await unlockAchievement(for: userID, achievementID: achievement.id)
                if wasUnlocked {
                    unlockedAchievements.append(achievement)
                }
            }
        }
        
        return unlockedAchievements
    }
    
    func unlockAchievement(for userID: UUID, achievementID: UUID) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let achievement = try await getAchievement(by: achievementID) else {
            throw ServiceError.invalidParameters("Achievement not found")
        }
        
        // Проверяем, не разблокировано ли уже
        if achievement.isUnlockedForUser(userID) {
            return false
        }
        
        // Получаем или создаем запись прогресса
        var progressRecord = try await getAchievementProgress(for: userID, achievementID: achievementID)
        
        if progressRecord == nil {
            let targetProgress = getTargetProgress(for: achievement)
            progressRecord = AchievementProgress(
                userID: userID,
                achievementID: achievementID,
                targetProgress: targetProgress
            )
            
            modelContext.insert(progressRecord!)
        }
        
        // Разблокируем достижение
        progressRecord!.unlock()
        
        do {
            try modelContext.save()
            
            // Начисляем очки
            _ = try await pointsService.awardPoints(
                to: userID,
                amount: achievement.points,
                source: .achievementUnlocked,
                sourceID: achievementID,
                reason: "Разблокировано достижение: \(achievement.title)"
            )
            
            // Отправляем уведомление
            try await sendAchievementNotification(for: userID, achievement: achievement)
            
            #if DEBUG
            print("Achievement unlocked: \(achievement.title) for user \(userID)")
            #endif
            
            return true
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to unlock achievement: \(error)")
        }
    }
    
    // MARK: - Default Achievements
    func createDefaultAchievements() async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        // Проверяем, есть ли уже достижения
        let existingAchievements = try await getAchievements()
        if !existingAchievements.isEmpty {
            return
        }
        
        let defaultAchievements = getDefaultAchievements()
        
        for achievement in defaultAchievements {
            modelContext.insert(achievement)
        }
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Created \(defaultAchievements.count) default achievements")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to create default achievements: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getAchievement(by id: UUID) async throws -> Achievement? {
        let predicate = #Predicate<Achievement> { $0.id == id }
        let descriptor = FetchDescriptor<Achievement>(predicate: predicate)
        
        do {
            let achievements = try modelContext.fetch(descriptor)
            return achievements.first
        } catch {
            return nil
        }
    }
    
    private func getTargetProgress(for achievement: Achievement) -> Int {
        // Извлекаем целевое значение из требований
        if let targetValue = achievement.requirements["targetValue"] as? Int {
            return targetValue
        }
        return 1
    }
    
    private func checkAchievementRequirements(_ achievement: Achievement, userProgress: UserProgress) async throws -> Bool {
        guard let requirementType = achievement.requirements["type"] as? String else {
            return false
        }
        
        guard let targetValue = achievement.requirements["targetValue"] as? Int else {
            return false
        }
        
        switch requirementType {
        case "habit_streak":
            return userProgress.currentStreak >= targetValue
            
        case "habit_total":
            return userProgress.completedHabits >= targetValue
            
        case "task_completion":
            return userProgress.completedTasks >= targetValue
            
        case "goal_achievement":
            return userProgress.achievedGoals >= targetValue
            
        case "points_earned":
            return userProgress.totalXP >= targetValue
            
        case "level_reached":
            return userProgress.currentLevel >= targetValue
            
        case "perfect_day":
            return userProgress.completionRate >= 1.0
            
        case "perfect_week":
            return userProgress.completionRate >= 1.0 && userProgress.daysActive >= 7
            
        case "perfect_month":
            return userProgress.completionRate >= 1.0 && userProgress.daysActive >= 30
            
        case "consistency":
            let requiredRate = (achievement.requirements["rate"] as? Double) ?? 0.8
            return userProgress.completionRate >= requiredRate
            
        case "category_mastery":
            if let categoryName = achievement.requirements["category"] as? String {
                // Проверяем мастерство в определенной категории
                return try await checkCategoryMastery(userProgress.userID, category: categoryName, targetValue: targetValue)
            }
            return false
            
        case "comeback":
            // Проверяем, есть ли "возвращение" после пропуска
            return try await checkComeback(userProgress.userID)
            
        case "early_bird":
            // Проверяем выполнение задач рано утром
            return try await checkEarlyBird(userProgress.userID, targetValue: targetValue)
            
        case "night_owl":
            // Проверяем выполнение задач поздно вечером
            return try await checkNightOwl(userProgress.userID, targetValue: targetValue)
            
        default:
            return false
        }
    }
    
    private func checkCategoryMastery(_ userID: UUID, category: String, targetValue: Int) async throws -> Bool {
        // Логика проверки мастерства в категории
        // Здесь нужно обратиться к HabitService или TaskService
        return false
    }
    
    private func checkComeback(_ userID: UUID) async throws -> Bool {
        // Логика проверки "возвращения" после пропуска
        return false
    }
    
    private func checkEarlyBird(_ userID: UUID, targetValue: Int) async throws -> Bool {
        // Логика проверки выполнения задач рано утром
        return false
    }
    
    private func checkNightOwl(_ userID: UUID, targetValue: Int) async throws -> Bool {
        // Логика проверки выполнения задач поздно вечером
        return false
    }
    
    private func sendAchievementNotification(for userID: UUID, achievement: Achievement) async throws {
        // Отправляем уведомление о разблокировке достижения
        #if DEBUG
        print("Sending achievement notification for: \(achievement.title)")
        #endif
        
        // Здесь будет логика отправки уведомления
        // Пока оставляем заглушку
    }
    
    private func getDefaultAchievements() -> [Achievement] {
        var achievements: [Achievement] = []
        
        // Достижения для привычек
        achievements.append(Achievement(
            title: "Первые шаги",
            description: "Выполните первую привычку",
            category: .habits,
            rarity: .common,
            iconName: "footprints",
            colorHex: "#4CAF50",
            points: 25,
            requirements: ["type": "habit_total", "targetValue": 1]
        ))
        
        achievements.append(Achievement(
            title: "Неделя силы",
            description: "Поддерживайте серию выполнения привычек 7 дней",
            category: .streaks,
            rarity: .uncommon,
            iconName: "flame",
            colorHex: "#FF9800",
            points: 100,
            requirements: ["type": "habit_streak", "targetValue": 7]
        ))
        
        achievements.append(Achievement(
            title: "Месяц дисциплины",
            description: "Поддерживайте серию выполнения привычек 30 дней",
            category: .streaks,
            rarity: .rare,
            iconName: "flame.fill",
            colorHex: "#F44336",
            points: 500,
            requirements: ["type": "habit_streak", "targetValue": 30]
        ))
        
        achievements.append(Achievement(
            title: "Сотня",
            description: "Выполните 100 привычек",
            category: .milestones,
            rarity: .rare,
            iconName: "100.circle",
            colorHex: "#2196F3",
            points: 300,
            requirements: ["type": "habit_total", "targetValue": 100]
        ))
        
        // Достижения для задач
        achievements.append(Achievement(
            title: "Продуктивный день",
            description: "Выполните 5 задач за день",
            category: .tasks,
            rarity: .common,
            iconName: "checkmark.circle",
            colorHex: "#4CAF50",
            points: 50,
            requirements: ["type": "task_completion", "targetValue": 5]
        ))
        
        achievements.append(Achievement(
            title: "Мастер задач",
            description: "Выполните 500 задач",
            category: .milestones,
            rarity: .epic,
            iconName: "star.circle",
            colorHex: "#9C27B0",
            points: 1000,
            requirements: ["type": "task_completion", "targetValue": 500]
        ))
        
        // Достижения для целей
        achievements.append(Achievement(
            title: "Целеустремленный",
            description: "Достигните первой цели",
            category: .goals,
            rarity: .common,
            iconName: "target",
            colorHex: "#FF5722",
            points: 100,
            requirements: ["type": "goal_achievement", "targetValue": 1]
        ))
        
        achievements.append(Achievement(
            title: "Достигатор",
            description: "Достигните 10 целей",
            category: .goals,
            rarity: .rare,
            iconName: "bullseye",
            colorHex: "#E91E63",
            points: 500,
            requirements: ["type": "goal_achievement", "targetValue": 10]
        ))
        
        // Особые достижения
        achievements.append(Achievement(
            title: "Идеальный день",
            description: "Выполните все запланированные привычки и задачи за день",
            category: .special,
            rarity: .epic,
            iconName: "star.fill",
            colorHex: "#FFD700",
            points: 200,
            requirements: ["type": "perfect_day", "targetValue": 1]
        ))
        
        achievements.append(Achievement(
            title: "Ранняя пташка",
            description: "Выполните 20 задач до 9:00 утра",
            category: .special,
            rarity: .rare,
            iconName: "sun.max",
            colorHex: "#FFC107",
            points: 300,
            requirements: ["type": "early_bird", "targetValue": 20]
        ))
        
        achievements.append(Achievement(
            title: "Полуночник",
            description: "Выполните 20 задач после 22:00",
            category: .special,
            rarity: .rare,
            iconName: "moon.stars",
            colorHex: "#3F51B5",
            points: 300,
            requirements: ["type": "night_owl", "targetValue": 20]
        ))
        
        achievements.append(Achievement(
            title: "Возвращение",
            description: "Восстановите серию привычек после пропуска",
            category: .special,
            rarity: .uncommon,
            iconName: "arrow.up.circle",
            colorHex: "#009688",
            points: 150,
            requirements: ["type": "comeback", "targetValue": 1]
        ))
        
        // Уровневые достижения
        achievements.append(Achievement(
            title: "Новичок",
            description: "Достигните 5 уровня",
            category: .milestones,
            rarity: .common,
            iconName: "1.circle",
            colorHex: "#607D8B",
            points: 100,
            requirements: ["type": "level_reached", "targetValue": 5]
        ))
        
        achievements.append(Achievement(
            title: "Опытный",
            description: "Достигните 20 уровня",
            category: .milestones,
            rarity: .uncommon,
            iconName: "20.circle",
            colorHex: "#795548",
            points: 300,
            requirements: ["type": "level_reached", "targetValue": 20]
        ))
        
        achievements.append(Achievement(
            title: "Эксперт",
            description: "Достигните 50 уровня",
            category: .milestones,
            rarity: .rare,
            iconName: "50.circle",
            colorHex: "#673AB7",
            points: 1000,
            requirements: ["type": "level_reached", "targetValue": 50]
        ))
        
        achievements.append(Achievement(
            title: "Мастер",
            description: "Достигните 100 уровня",
            category: .milestones,
            rarity: .legendary,
            iconName: "crown",
            colorHex: "#FF6F00",
            points: 5000,
            requirements: ["type": "level_reached", "targetValue": 100]
        ))
        
        // Сезонные достижения
        achievements.append(Achievement(
            title: "Новогодние обещания",
            description: "Выполните все привычки в январе",
            category: .seasonal,
            rarity: .legendary,
            iconName: "sparkles",
            colorHex: "#E1BEE7",
            points: 2000,
            requirements: ["type": "perfect_month", "targetValue": 31],
            isSeasonal: true,
            seasonStartDate: Calendar.current.date(from: DateComponents(month: 1, day: 1)),
            seasonEndDate: Calendar.current.date(from: DateComponents(month: 1, day: 31))
        ))
        
        return achievements
    }
} 