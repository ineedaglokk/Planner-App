import Foundation
import SwiftData

// MARK: - Game Service

protocol GameServiceProtocol {
    func processUserAction(_ action: UserAction, for user: User) async throws
    func getDashboardData(for user: User) async throws -> GamificationDashboard
    func initializeGamificationForUser(_ user: User) async throws
    func dailyUpdate(for user: User) async throws
    func weeklyUpdate(for user: User) async throws
    func monthlyUpdate(for user: User) async throws
    func getGameStats(for user: User) async throws -> GameStats
    func processHabitCompletion(_ habit: Habit, for user: User) async throws
    func processTaskCompletion(_ task: Task, for user: User) async throws
    func processGoalAchievement(_ goal: Goal, for user: User) async throws
    func checkAndTriggerEvents(for user: User) async throws
}

final class GameService: GameServiceProtocol {
    private let modelContext: ModelContext
    private let pointsService: PointsCalculationServiceProtocol
    private let achievementService: AchievementServiceProtocol
    private let challengeService: ChallengeServiceProtocol
    private let levelService: LevelProgressionServiceProtocol
    private let motivationService: MotivationServiceProtocol
    private let challengeProgressTracker: ChallengeProgressTracker
    
    init(
        modelContext: ModelContext,
        pointsService: PointsCalculationServiceProtocol,
        achievementService: AchievementServiceProtocol,
        challengeService: ChallengeServiceProtocol,
        levelService: LevelProgressionServiceProtocol,
        motivationService: MotivationServiceProtocol
    ) {
        self.modelContext = modelContext
        self.pointsService = pointsService
        self.achievementService = achievementService
        self.challengeService = challengeService
        self.levelService = levelService
        self.motivationService = motivationService
        self.challengeProgressTracker = ChallengeProgressTracker(
            modelContext: modelContext,
            challengeService: challengeService
        )
    }
    
    func processUserAction(_ action: UserAction, for user: User) async throws {
        switch action {
        case .habitCompleted(let habit):
            try await processHabitCompletion(habit, for: user)
        case .taskCompleted(let task):
            try await processTaskCompletion(task, for: user)
        case .goalAchieved(let goal):
            try await processGoalAchievement(goal, for: user)
        case .challengeJoined(let challenge):
            try await challengeService.joinChallenge(challenge, user: user)
        case .dailyLogin:
            try await processDailyLogin(for: user)
        case .perfectDay:
            try await processPerfectDay(for: user)
        case .comeback:
            try await processComeback(for: user)
        }
    }
    
    func getDashboardData(for user: User) async throws -> GamificationDashboard {
        let levelInfo = try await levelService.getLevelInfo(for: user)
        let nextLevelRequirements = try await levelService.getNextLevelRequirements(for: user)
        let recentAchievements = try await achievementService.getUnlockedAchievements(for: user)
        let activeChallenges = try await challengeService.getActiveChallenge(for: user)
        let availableChallenges = try await challengeService.getAvailableChallenges(for: user)
        let pointsHistory = try await pointsService.getPointsHistory(for: user, limit: 10)
        let motivationalMessage = try await motivationService.generateMotivationalMessage(for: user)
        let quote = try await motivationService.getMotivationalQuote()
        
        return GamificationDashboard(
            user: user,
            levelInfo: levelInfo,
            nextLevelRequirements: nextLevelRequirements,
            recentAchievements: Array(recentAchievements.prefix(5)),
            activeChallenges: activeChallenges,
            availableChallenges: Array(availableChallenges.prefix(3)),
            recentPointsHistory: pointsHistory,
            motivationalMessage: motivationalMessage,
            dailyQuote: quote
        )
    }
    
    func initializeGamificationForUser(_ user: User) async throws {
        // Создаем UserLevel если не существует
        try await levelService.updateUserLevel(for: user)
        
        // Создаем дефолтные достижения
        try await achievementService.createDefaultAchievements()
        
        // Создаем первоначальные вызовы
        if try await challengeService.getAvailableChallenges(for: user).isEmpty {
            _ = try await challengeService.createDailyChallenge()
            _ = try await challengeService.createWeeklyChallenge()
        }
        
        // Настраиваем мотивационные напоминания
        try await motivationService.scheduleMotivationalReminders(for: user)
        
        // Проверяем начальные достижения
        try await achievementService.checkAchievements(for: user)
    }
    
    func dailyUpdate(for user: User) async throws {
        // Проверяем идеальный день
        try await checkPerfectDay(for: user)
        
        // Обновляем уровень
        try await levelService.updateUserLevel(for: user)
        
        // Проверяем достижения
        try await achievementService.checkAchievements(for: user)
        
        // Проверяем вызовы
        try await checkAndTriggerEvents(for: user)
        
        // Отправляем мотивационное сообщение если нужно
        try await sendDailyMotivation(for: user)
    }
    
    func weeklyUpdate(for user: User) async throws {
        // Создаем новые еженедельные вызовы
        _ = try await challengeService.createWeeklyChallenge()
        
        // Анализируем прогресс за неделю
        let progressEncouragement = try await motivationService.getProgressEncouragement(for: user)
        
        // Отправляем еженедельную мотивацию
        try await motivationService.sendEncouragementNotification(for: user)
    }
    
    func monthlyUpdate(for user: User) async throws {
        // Создаем сезонные вызовы
        _ = try await challengeService.createSeasonalChallenge()
        
        // Проверяем престиж
        if try await levelService.checkPrestigeEligibility(for: user) {
            // Отправляем уведомление о возможности престижа
            await sendPrestigeEligibilityNotification(for: user)
        }
    }
    
    func getGameStats(for user: User) async throws -> GameStats {
        let levelInfo = try await levelService.getLevelInfo(for: user)
        let achievements = try await achievementService.getUnlockedAchievements(for: user)
        let challenges = try await challengeService.getCompletedChallenges(for: user)
        let pointsHistory = try await pointsService.getPointsHistory(for: user)
        
        // Статистика серий
        let longestStreak = user.habits.map { $0.longestStreak }.max() ?? 0
        let currentStreak = user.habits.map { $0.currentStreak }.max() ?? 0
        let totalHabitCompletions = user.habits.flatMap { $0.entries }.filter { $0.isCompleted }.count
        let totalTaskCompletions = user.tasks.filter { $0.status == .completed }.count
        
        // Статистика по категориям
        let categoryStats = calculateCategoryStats(for: user)
        
        return GameStats(
            level: levelInfo.currentLevel,
            totalXP: levelInfo.currentXP,
            totalPoints: user.totalPoints,
            prestigeLevel: levelInfo.prestigeLevel,
            achievementsCount: achievements.count,
            challengesCompleted: challenges.count,
            longestStreak: longestStreak,
            currentStreak: currentStreak,
            totalHabitCompletions: totalHabitCompletions,
            totalTaskCompletions: totalTaskCompletions,
            categoryStats: categoryStats,
            joinDate: user.createdAt,
            lastActiveDate: user.updatedAt
        )
    }
    
    func processHabitCompletion(_ habit: Habit, for user: User) async throws {
        // Начисляем очки
        let context = createActionContext(for: user, habit: habit)
        let pointsResult = await pointsService.calculatePoints(for: .habitCompleted(habit), context: context)
        try await pointsService.awardPoints(pointsResult, to: user)
        
        // Обновляем уровень
        try await levelService.updateUserLevel(for: user)
        
        // Отслеживаем прогресс вызовов
        try await challengeProgressTracker.trackHabitCompletion(habit: habit, user: user)
        
        // Проверяем достижения
        try await achievementService.checkAchievements(for: user)
        
        // Отправляем мотивацию для серии
        if habit.currentStreak > 0 && habit.currentStreak % 7 == 0 {
            let streakMotivation = try await motivationService.getStreakMotivation(for: habit)
            await sendStreakCelebration(streakMotivation, for: user)
        }
    }
    
    func processTaskCompletion(_ task: Task, for user: User) async throws {
        // Начисляем очки
        let context = createActionContext(for: user, task: task)
        let pointsResult = await pointsService.calculatePoints(for: .taskCompleted(task), context: context)
        try await pointsService.awardPoints(pointsResult, to: user)
        
        // Обновляем уровень
        try await levelService.updateUserLevel(for: user)
        
        // Отслеживаем прогресс вызовов
        try await challengeProgressTracker.trackTaskCompletion(task: task, user: user)
        
        // Проверяем достижения
        try await achievementService.checkAchievements(for: user)
    }
    
    func processGoalAchievement(_ goal: Goal, for user: User) async throws {
        // Начисляем очки
        let context = createActionContext(for: user, goal: goal)
        let pointsResult = await pointsService.calculatePoints(for: .goalAchieved(goal), context: context)
        try await pointsService.awardPoints(pointsResult, to: user)
        
        // Обновляем уровень
        try await levelService.updateUserLevel(for: user)
        
        // Проверяем достижения
        try await achievementService.checkAchievements(for: user)
        
        // Отправляем поздравление
        await sendGoalCelebration(for: goal, user: user)
    }
    
    func checkAndTriggerEvents(for user: User) async throws {
        // Проверяем различные события
        try await checkStreakMilestones(for: user)
        try await checkChallengeCompletions(for: user)
        try await checkLevelProgression(for: user)
        try await checkComebackStatus(for: user)
    }
    
    // MARK: - Private Methods
    
    private func createActionContext(for user: User, habit: Habit? = nil, task: Task? = nil, goal: Goal? = nil) -> ActionContext {
        let now = Date()
        let calendar = Calendar.current
        
        // Определяем контекст
        let isEarlyCompletion = calendar.component(.hour, from: now) < 10
        let isWeekend = calendar.component(.weekday, from: now) == 1 || calendar.component(.weekday, from: now) == 7
        let isPerfectDay = checkIfPerfectDay(for: user, date: now)
        let isComeback = checkIfComeback(for: user)
        
        return ActionContext(
            user: user,
            timestamp: now,
            isEarlyCompletion: isEarlyCompletion,
            isDifficultDay: false, // Можно добавить логику определения сложного дня
            isPerfectDay: isPerfectDay,
            isComeback: isComeback,
            isWeekend: isWeekend
        )
    }
    
    private func checkIfPerfectDay(for user: User, date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let activeHabits = user.habits.filter { $0.isActive }
        let completedHabits = activeHabits.filter { habit in
            habit.entries.contains { entry in
                entry.date >= startOfDay && entry.date < endOfDay && entry.isCompleted
            }
        }
        
        return completedHabits.count == activeHabits.count && activeHabits.count > 0
    }
    
    private func checkIfComeback(for user: User) -> Bool {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        
        // Проверяем, была ли активность вчера
        let hadActivityYesterday = user.habits.contains { habit in
            habit.entries.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: yesterday) && entry.isCompleted
            }
        }
        
        return !hadActivityYesterday
    }
    
    private func processDailyLogin(for user: User) async throws {
        let context = createActionContext(for: user)
        let pointsResult = await pointsService.calculatePoints(for: .dailyLogin, context: context)
        try await pointsService.awardPoints(pointsResult, to: user)
        
        try await levelService.updateUserLevel(for: user)
        try await achievementService.checkAchievements(for: user)
    }
    
    private func processPerfectDay(for user: User) async throws {
        let context = createActionContext(for: user)
        let pointsResult = await pointsService.calculatePoints(for: .perfectDay, context: context)
        try await pointsService.awardPoints(pointsResult, to: user)
        
        try await challengeProgressTracker.trackPerfectDay(user: user)
        try await levelService.updateUserLevel(for: user)
        try await achievementService.checkAchievements(for: user)
        
        // Отправляем поздравление
        await sendPerfectDayCelebration(for: user)
    }
    
    private func processComeback(for user: User) async throws {
        let context = createActionContext(for: user)
        let pointsResult = await pointsService.calculatePoints(for: .comeback, context: context)
        try await pointsService.awardPoints(pointsResult, to: user)
        
        try await levelService.updateUserLevel(for: user)
        try await achievementService.checkAchievements(for: user)
        
        // Отправляем приветственное сообщение
        let comebackMessage = try await motivationService.generateComebackMessage(for: user)
        await sendComebackMessage(comebackMessage, for: user)
    }
    
    private func checkPerfectDay(for user: User) async throws {
        if checkIfPerfectDay(for: user, date: Date()) {
            try await processPerfectDay(for: user)
        }
    }
    
    private func sendDailyMotivation(for user: User) async throws {
        // Отправляем мотивацию не каждый день, а с определенной частотой
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        
        if dayOfYear % 3 == 0 { // Каждый третий день
            try await motivationService.sendEncouragementNotification(for: user)
        }
    }
    
    private func checkStreakMilestones(for user: User) async throws {
        for habit in user.habits {
            let milestones = [7, 14, 21, 30, 60, 90, 180, 365]
            
            if milestones.contains(habit.currentStreak) {
                let context = createActionContext(for: user, habit: habit)
                let pointsResult = await pointsService.calculatePoints(for: .streakMilestone(habit.currentStreak), context: context)
                try await pointsService.awardPoints(pointsResult, to: user)
            }
        }
    }
    
    private func checkChallengeCompletions(for user: User) async throws {
        let activeChallenges = try await challengeService.getActiveChallenge(for: user)
        
        for challenge in activeChallenges {
            if try await challengeService.checkChallengeCompletion(challenge, user: user) {
                let celebrationMessage = try await motivationService.getCelebrationMessage(for: Achievement(
                    name: challenge.name,
                    description: challenge.description,
                    iconName: challenge.iconName,
                    category: .special,
                    rarity: .rare,
                    points: challenge.rewards.points,
                    requirements: AchievementRequirements(type: .challengesCompleted, targetValue: 1)
                ))
                
                await sendChallengeCompletion(celebrationMessage, for: user)
            }
        }
    }
    
    private func checkLevelProgression(for user: User) async throws {
        try await levelService.updateUserLevel(for: user)
    }
    
    private func checkComebackStatus(for user: User) async throws {
        if checkIfComeback(for: user) {
            try await processComeback(for: user)
        }
    }
    
    private func calculateCategoryStats(for user: User) -> [CategoryStats] {
        let categories = Set(user.habits.compactMap { $0.category })
        
        return categories.map { category in
            let categoryHabits = user.habits.filter { $0.category == category }
            let totalCompletions = categoryHabits.flatMap { $0.entries }.filter { $0.isCompleted }.count
            let averageStreak = categoryHabits.isEmpty ? 0 : categoryHabits.map { $0.currentStreak }.reduce(0, +) / categoryHabits.count
            
            return CategoryStats(
                category: category,
                totalHabits: categoryHabits.count,
                totalCompletions: totalCompletions,
                averageStreak: averageStreak
            )
        }
    }
    
    private func sendStreakCelebration(_ motivation: StreakMotivation, for user: User) async {
        let content = UNMutableNotificationContent()
        content.title = motivation.title
        content.body = motivation.message
        content.sound = .default
        content.categoryIdentifier = "STREAK_CELEBRATION"
        
        let identifier = "streak-celebration-\(user.id.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send streak celebration: \(error)")
        }
    }
    
    private func sendGoalCelebration(for goal: Goal, user: User) async {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Цель достигнута!"
        content.body = "Поздравляем! Вы достигли цели '\(goal.title)'"
        content.sound = .default
        content.categoryIdentifier = "GOAL_CELEBRATION"
        
        let identifier = "goal-celebration-\(goal.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send goal celebration: \(error)")
        }
    }
    
    private func sendPerfectDayCelebration(for user: User) async {
        let content = UNMutableNotificationContent()
        content.title = "🌟 Идеальный день!"
        content.body = "Поздравляем! Вы выполнили все привычки сегодня!"
        content.sound = .default
        content.categoryIdentifier = "PERFECT_DAY"
        
        let identifier = "perfect-day-\(user.id.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send perfect day celebration: \(error)")
        }
    }
    
    private func sendComebackMessage(_ message: ComebackMessage, for user: User) async {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.message
        content.sound = .default
        content.categoryIdentifier = "COMEBACK"
        
        let identifier = "comeback-\(user.id.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send comeback message: \(error)")
        }
    }
    
    private func sendChallengeCompletion(_ message: CelebrationMessage, for user: User) async {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.message
        content.sound = .default
        content.categoryIdentifier = "CHALLENGE_COMPLETION"
        
        let identifier = "challenge-completion-\(user.id.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send challenge completion: \(error)")
        }
    }
    
    private func sendPrestigeEligibilityNotification(for user: User) async {
        let content = UNMutableNotificationContent()
        content.title = "⭐ Престиж доступен!"
        content.body = "Вы достигли уровня для престижа! Готовы к новым вызовам?"
        content.sound = .default
        content.categoryIdentifier = "PRESTIGE_ELIGIBLE"
        
        let identifier = "prestige-eligible-\(user.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send prestige eligibility: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum UserAction {
    case habitCompleted(Habit)
    case taskCompleted(Task)
    case goalAchieved(Goal)
    case challengeJoined(Challenge)
    case dailyLogin
    case perfectDay
    case comeback
}

struct GamificationDashboard {
    let user: User
    let levelInfo: LevelInfo
    let nextLevelRequirements: NextLevelRequirements
    let recentAchievements: [Achievement]
    let activeChallenges: [Challenge]
    let availableChallenges: [Challenge]
    let recentPointsHistory: [PointsHistory]
    let motivationalMessage: MotivationalMessage
    let dailyQuote: Quote
}

struct GameStats {
    let level: Int
    let totalXP: Int
    let totalPoints: Int
    let prestigeLevel: Int
    let achievementsCount: Int
    let challengesCompleted: Int
    let longestStreak: Int
    let currentStreak: Int
    let totalHabitCompletions: Int
    let totalTaskCompletions: Int
    let categoryStats: [CategoryStats]
    let joinDate: Date
    let lastActiveDate: Date
}

struct CategoryStats {
    let category: Category
    let totalHabits: Int
    let totalCompletions: Int
    let averageStreak: Int
}

// MARK: - Game Service Extensions

extension GameService {
    /// Обработка пакетных действий для улучшения производительности
    func processBatchActions(_ actions: [UserAction], for user: User) async throws {
        for action in actions {
            try await processUserAction(action, for: user)
        }
        
        // Одна проверка всех событий в конце
        try await checkAndTriggerEvents(for: user)
    }
    
    /// Получение рекомендаций для пользователя
    func getRecommendations(for user: User) async throws -> [GameRecommendation] {
        var recommendations: [GameRecommendation] = []
        
        // Рекомендации по уровню
        let levelInfo = try await levelService.getLevelInfo(for: user)
        if levelInfo.progressPercentage > 0.8 {
            recommendations.append(GameRecommendation(
                type: .levelUp,
                title: "Почти новый уровень!",
                description: "Вам осталось \(levelInfo.requiredXP - levelInfo.progressXP) XP до следующего уровня",
                priority: .high,
                actionText: "Выполнить привычку"
            ))
        }
        
        // Рекомендации по достижениям
        let availableAchievements = try await achievementService.getAvailableAchievements(for: user)
        let closeAchievements = availableAchievements.filter { $0.progress > 0.7 }
        
        for achievement in closeAchievements.prefix(2) {
            recommendations.append(GameRecommendation(
                type: .achievement,
                title: "Достижение близко!",
                description: "'\(achievement.name)' - выполнено \(Int(achievement.progress * 100))%",
                priority: .medium,
                actionText: "Продолжить"
            ))
        }
        
        // Рекомендации по вызовам
        let availableChallenges = try await challengeService.getAvailableChallenges(for: user)
        if !availableChallenges.isEmpty {
            let challenge = availableChallenges.first!
            recommendations.append(GameRecommendation(
                type: .challenge,
                title: "Новый вызов!",
                description: "Попробуйте '\(challenge.name)' - завершается через \(challenge.daysRemaining) дней",
                priority: .medium,
                actionText: "Принять вызов"
            ))
        }
        
        return recommendations
    }
}

struct GameRecommendation {
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let actionText: String
    
    enum RecommendationType {
        case levelUp
        case achievement
        case challenge
        case streak
        case comeback
    }
    
    enum Priority {
        case low
        case medium
        case high
    }
} 