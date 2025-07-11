import Foundation
import SwiftData

// MARK: - Motivation Service

protocol MotivationServiceProtocol {
    func generateMotivationalMessage(for user: User) async throws -> MotivationalMessage
    func getMotivationalQuote() async throws -> Quote
    func sendEncouragementNotification(for user: User) async throws
    func generatePersonalizedTip(for user: User) async throws -> PersonalizedTip
    func getCelebrationMessage(for achievement: Achievement) async throws -> CelebrationMessage
    func getStreakMotivation(for habit: Habit) async throws -> StreakMotivation
    func generateComebackMessage(for user: User) async throws -> ComebackMessage
    func scheduleMotivationalReminders(for user: User) async throws
    func getProgressEncouragement(for user: User) async throws -> ProgressEncouragement
    func generateRewardCelebration(for reward: String, user: User) async throws -> RewardCelebration
}

final class MotivationService: MotivationServiceProtocol {
    private let modelContext: ModelContext
    private let notificationService: NotificationServiceProtocol
    private let analyticsService: HabitAnalyticsServiceProtocol?
    
    init(
        modelContext: ModelContext,
        notificationService: NotificationServiceProtocol,
        analyticsService: HabitAnalyticsServiceProtocol? = nil
    ) {
        self.modelContext = modelContext
        self.notificationService = notificationService
        self.analyticsService = analyticsService
    }
    
    func generateMotivationalMessage(for user: User) async throws -> MotivationalMessage {
        let userStats = try await getUserStats(for: user)
        let motivationType = determineMotivationType(for: userStats)
        
        switch motivationType {
        case .encouragement:
            return generateEncouragementMessage(for: user, stats: userStats)
        case .celebration:
            return generateCelebrationMessage(for: user, stats: userStats)
        case .challenge:
            return generateChallengeMessage(for: user, stats: userStats)
        case .support:
            return generateSupportMessage(for: user, stats: userStats)
        case .inspiration:
            return generateInspirationMessage(for: user, stats: userStats)
        }
    }
    
    func getMotivationalQuote() async throws -> Quote {
        let quotes = QuoteDatabase.all
        let randomQuote = quotes.randomElement() ?? QuoteDatabase.default
        
        return Quote(
            text: randomQuote.text,
            author: randomQuote.author,
            category: randomQuote.category,
            mood: randomQuote.mood
        )
    }
    
    func sendEncouragementNotification(for user: User) async throws {
        let message = try await generateMotivationalMessage(for: user)
        
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.categoryIdentifier = "MOTIVATION"
        
        // Добавляем персональную иконку в зависимости от типа
        switch message.type {
        case .encouragement:
            content.subtitle = "💪 Мотивация"
        case .celebration:
            content.subtitle = "🎉 Поздравления"
        case .challenge:
            content.subtitle = "🎯 Вызов"
        case .support:
            content.subtitle = "🤝 Поддержка"
        case .inspiration:
            content.subtitle = "✨ Вдохновение"
        }
        
        let identifier = "motivation-\(user.id.uuidString)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send encouragement notification: \(error)")
        }
    }
    
    func generatePersonalizedTip(for user: User) async throws -> PersonalizedTip {
        let userStats = try await getUserStats(for: user)
        let weakestArea = identifyWeakestArea(for: userStats)
        let tip = generateTipForArea(weakestArea, user: user)
        
        return PersonalizedTip(
            title: tip.title,
            content: tip.content,
            category: tip.category,
            difficulty: tip.difficulty,
            estimatedTime: tip.estimatedTime,
            actionSteps: tip.actionSteps
        )
    }
    
    func getCelebrationMessage(for achievement: Achievement) async throws -> CelebrationMessage {
        let celebrationTypes = CelebrationMessageGenerator.messagesForAchievement(achievement)
        let randomCelebration = celebrationTypes.randomElement() ?? CelebrationMessageGenerator.default
        
        return CelebrationMessage(
            title: randomCelebration.title,
            message: randomCelebration.message,
            emoji: randomCelebration.emoji,
            animation: randomCelebration.animation,
            sound: randomCelebration.sound,
            shareText: randomCelebration.shareText
        )
    }
    
    func getStreakMotivation(for habit: Habit) async throws -> StreakMotivation {
        let streakLength = habit.currentStreak
        let motivationLevel = determineStreakMotivationLevel(for: streakLength)
        
        return StreakMotivationGenerator.generate(
            for: habit,
            streakLength: streakLength,
            motivationLevel: motivationLevel
        )
    }
    
    func generateComebackMessage(for user: User) async throws -> ComebackMessage {
        let daysSinceLastActivity = try await calculateDaysSinceLastActivity(for: user)
        let previousStreak = try await getLongestStreak(for: user)
        
        return ComebackMessageGenerator.generate(
            daysSinceLastActivity: daysSinceLastActivity,
            previousStreak: previousStreak,
            userName: user.name
        )
    }
    
    func scheduleMotivationalReminders(for user: User) async throws {
        let userStats = try await getUserStats(for: user)
        
        // Планируем напоминания на основе активности пользователя
        if userStats.averageCompletionRate < 0.5 {
            // Пользователь нуждается в дополнительной мотивации
            await scheduleFrequentReminders(for: user)
        } else if userStats.averageCompletionRate > 0.8 {
            // Пользователь активен, достаточно еженедельных напоминаний
            await scheduleWeeklyReminders(for: user)
        } else {
            // Стандартные напоминания
            await scheduleStandardReminders(for: user)
        }
    }
    
    func getProgressEncouragement(for user: User) async throws -> ProgressEncouragement {
        let userStats = try await getUserStats(for: user)
        let progressType = determineProgressType(for: userStats)
        
        return ProgressEncouragementGenerator.generate(
            for: user,
            stats: userStats,
            progressType: progressType
        )
    }
    
    func generateRewardCelebration(for reward: String, user: User) async throws -> RewardCelebration {
        return RewardCelebrationGenerator.generate(
            reward: reward,
            userName: user.name,
            userLevel: user.level
        )
    }
    
    // MARK: - Private Methods
    
    private func getUserStats(for user: User) async throws -> UserStats {
        let calendar = Calendar.current
        let last30Days = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        // Получаем статистику за последние 30 дней
        let habitCompletions = user.habits.flatMap { $0.entries }
            .filter { $0.date >= last30Days && $0.isCompleted }
            .count
        
        let taskCompletions = user.tasks
            .filter { $0.status == .completed && $0.updatedAt >= last30Days }
            .count
        
        let activeDays = try await calculateActiveDays(for: user, since: last30Days)
        let averageCompletionRate = try await calculateAverageCompletionRate(for: user)
        let longestStreak = user.habits.map { $0.longestStreak }.max() ?? 0
        let currentStreak = user.habits.map { $0.currentStreak }.max() ?? 0
        
        return UserStats(
            habitCompletions: habitCompletions,
            taskCompletions: taskCompletions,
            activeDays: activeDays,
            averageCompletionRate: averageCompletionRate,
            longestStreak: longestStreak,
            currentStreak: currentStreak,
            totalXP: user.totalXP,
            totalPoints: user.totalPoints,
            level: user.level
        )
    }
    
    private func determineMotivationType(for stats: UserStats) -> MotivationType {
        if stats.currentStreak == 0 && stats.longestStreak > 7 {
            return .support // Потерял серию
        } else if stats.currentStreak > stats.longestStreak {
            return .celebration // Новый рекорд
        } else if stats.averageCompletionRate < 0.3 {
            return .encouragement // Нужна мотивация
        } else if stats.averageCompletionRate > 0.8 {
            return .challenge // Предлагаем вызов
        } else {
            return .inspiration // Вдохновение
        }
    }
    
    private func generateEncouragementMessage(for user: User, stats: UserStats) -> MotivationalMessage {
        let messages = [
            MotivationalMessage(
                type: .encouragement,
                title: "Не сдавайтесь!",
                body: "Каждый день - новая возможность стать лучше. Вы можете это сделать, \(user.name)!",
                actionText: "Выполнить привычку",
                iconName: "heart.fill"
            ),
            MotivationalMessage(
                type: .encouragement,
                title: "Маленькие шаги важны",
                body: "Прогресс - это не всегда гигантские скачки. Иногда достаточно одного маленького шага.",
                actionText: "Сделать шаг",
                iconName: "figure.walk"
            ),
            MotivationalMessage(
                type: .encouragement,
                title: "Верьте в себя",
                body: "У вас есть сила изменить свою жизнь. Начните прямо сейчас!",
                actionText: "Начать сейчас",
                iconName: "star.fill"
            )
        ]
        
        return messages.randomElement() ?? messages[0]
    }
    
    private func generateCelebrationMessage(for user: User, stats: UserStats) -> MotivationalMessage {
        return MotivationalMessage(
            type: .celebration,
            title: "Поздравляем!",
            body: "Вы показываете отличные результаты! Ваша серия из \(stats.currentStreak) дней впечатляет!",
            actionText: "Продолжить",
            iconName: "party.popper.fill"
        )
    }
    
    private func generateChallengeMessage(for user: User, stats: UserStats) -> MotivationalMessage {
        return MotivationalMessage(
            type: .challenge,
            title: "Новый вызов!",
            body: "Вы готовы к новым высотам? Попробуйте добавить еще одну привычку!",
            actionText: "Принять вызов",
            iconName: "target"
        )
    }
    
    private func generateSupportMessage(for user: User, stats: UserStats) -> MotivationalMessage {
        return MotivationalMessage(
            type: .support,
            title: "Мы с вами",
            body: "Не расстраивайтесь из-за неудач. Важно встать и продолжить двигаться вперед.",
            actionText: "Начать заново",
            iconName: "hands.sparkles.fill"
        )
    }
    
    private func generateInspirationMessage(for user: User, stats: UserStats) -> MotivationalMessage {
        return MotivationalMessage(
            type: .inspiration,
            title: "Вдохновение дня",
            body: "Лучшее время для посадки дерева было 20 лет назад. Второе лучшее время - сейчас.",
            actionText: "Действовать",
            iconName: "lightbulb.fill"
        )
    }
    
    private func identifyWeakestArea(for stats: UserStats) -> WeakArea {
        if stats.habitCompletions < 10 {
            return .habitConsistency
        } else if stats.taskCompletions < 5 {
            return .taskManagement
        } else if stats.currentStreak < 3 {
            return .streakBuilding
        } else {
            return .motivation
        }
    }
    
    private func generateTipForArea(_ area: WeakArea, user: User) -> TipContent {
        switch area {
        case .habitConsistency:
            return TipContent(
                title: "Совет по постоянству",
                content: "Начните с малого - выполняйте привычку всего 2 минуты в день. Постоянство важнее интенсивности.",
                category: "Привычки",
                difficulty: .easy,
                estimatedTime: 2,
                actionSteps: [
                    "Выберите одну простую привычку",
                    "Поставьте напоминание на телефоне",
                    "Выполняйте её в одно и то же время",
                    "Отмечайте прогресс в приложении"
                ]
            )
        case .taskManagement:
            return TipContent(
                title: "Управление задачами",
                content: "Используйте правило 2 минут: если задача займет меньше 2 минут, сделайте её сразу.",
                category: "Продуктивность",
                difficulty: .medium,
                estimatedTime: 5,
                actionSteps: [
                    "Просмотрите список задач",
                    "Найдите задачи на 2 минуты",
                    "Выполните их немедленно",
                    "Отметьте как выполненные"
                ]
            )
        case .streakBuilding:
            return TipContent(
                title: "Построение серий",
                content: "Фокусируйтесь на том, чтобы не прерывать серию. Лучше сделать минимум, чем не сделать ничего.",
                category: "Мотивация",
                difficulty: .medium,
                estimatedTime: 3,
                actionSteps: [
                    "Выберите одну приоритетную привычку",
                    "Установите минимальную планку",
                    "Выполняйте даже в трудные дни",
                    "Празднуйте каждый день серии"
                ]
            )
        case .motivation:
            return TipContent(
                title: "Поддержание мотивации",
                content: "Визуализируйте свои цели. Представьте, каким вы станете через год регулярных привычек.",
                category: "Мотивация",
                difficulty: .easy,
                estimatedTime: 5,
                actionSteps: [
                    "Закройте глаза и представьте свои цели",
                    "Опишите свою идеальную жизнь",
                    "Подумайте о первом шаге",
                    "Сделайте этот шаг сегодня"
                ]
            )
        }
    }
    
    private func calculateActiveDays(for user: User, since date: Date) async throws -> Int {
        let calendar = Calendar.current
        var activeDays = 0
        var currentDate = date
        
        while currentDate <= Date() {
            let hasActivity = await hasUserActivity(on: currentDate, for: user)
            if hasActivity {
                activeDays += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return activeDays
    }
    
    private func calculateAverageCompletionRate(for user: User) async throws -> Double {
        let activeHabits = user.habits.filter { $0.isActive }
        guard !activeHabits.isEmpty else { return 0.0 }
        
        let totalCompletionRates = activeHabits.map { habit in
            let totalEntries = habit.entries.count
            let completedEntries = habit.entries.filter { $0.isCompleted }.count
            return totalEntries > 0 ? Double(completedEntries) / Double(totalEntries) : 0.0
        }
        
        return totalCompletionRates.reduce(0, +) / Double(totalCompletionRates.count)
    }
    
    private func calculateDaysSinceLastActivity(for user: User) async throws -> Int {
        let calendar = Calendar.current
        let today = Date()
        
        // Ищем последний день активности
        var currentDate = today
        var daysSince = 0
        
        for _ in 0..<30 { // Проверяем последние 30 дней
            if await hasUserActivity(on: currentDate, for: user) {
                return daysSince
            }
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            daysSince += 1
        }
        
        return daysSince
    }
    
    private func getLongestStreak(for user: User) async throws -> Int {
        return user.habits.map { $0.longestStreak }.max() ?? 0
    }
    
    private func hasUserActivity(on date: Date, for user: User) async -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        // Проверяем активность в привычках
        let habitActivity = user.habits.contains { habit in
            habit.entries.contains { entry in
                entry.date >= startOfDay && entry.date < endOfDay && entry.isCompleted
            }
        }
        
        // Проверяем активность в задачах
        let taskActivity = user.tasks.contains { task in
            task.status == .completed && task.updatedAt >= startOfDay && task.updatedAt < endOfDay
        }
        
        return habitActivity || taskActivity
    }
    
    private func scheduleFrequentReminders(for user: User) async {
        // Ежедневные напоминания для пользователей с низкой активностью
        let content = UNMutableNotificationContent()
        content.title = "Не забудьте о своих целях"
        content.body = "Даже один маленький шаг приближает вас к успеху!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_MOTIVATION"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 19, minute: 0),
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-motivation-\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule daily reminders: \(error)")
        }
    }
    
    private func scheduleWeeklyReminders(for user: User) async {
        // Еженедельные напоминания для активных пользователей
        let content = UNMutableNotificationContent()
        content.title = "Еженедельная мотивация"
        content.body = "Отличная работа на этой неделе! Продолжайте двигаться к своим целям!"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_MOTIVATION"
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(weekday: 2, hour: 9, minute: 0), // Понедельник 9:00
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "weekly-motivation-\(user.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule weekly reminders: \(error)")
        }
    }
    
    private func scheduleStandardReminders(for user: User) async {
        // Стандартные напоминания 3 раза в неделю
        let days = [2, 4, 6] // Понедельник, среда, пятница
        
        for day in days {
            let content = UNMutableNotificationContent()
            content.title = "Время для привычек"
            content.body = "Как дела с вашими привычками? Небольшой прогресс лучше, чем никакого!"
            content.sound = .default
            content.categoryIdentifier = "STANDARD_MOTIVATION"
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(weekday: day, hour: 18, minute: 0),
                repeats: true
            )
            
            let request = UNNotificationRequest(
                identifier: "standard-motivation-\(day)-\(user.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Failed to schedule standard reminders: \(error)")
            }
        }
    }
    
    private func determineStreakMotivationLevel(for streakLength: Int) -> StreakMotivationLevel {
        switch streakLength {
        case 0: return .restart
        case 1...6: return .building
        case 7...20: return .strong
        case 21...59: return .impressive
        case 60...179: return .legendary
        default: return .mythical
        }
    }
    
    private func determineProgressType(for stats: UserStats) -> ProgressType {
        let recentProgress = stats.averageCompletionRate
        
        if recentProgress > 0.8 {
            return .excellent
        } else if recentProgress > 0.6 {
            return .good
        } else if recentProgress > 0.4 {
            return .moderate
        } else {
            return .needsImprovement
        }
    }
}

// MARK: - Supporting Types

struct UserStats {
    let habitCompletions: Int
    let taskCompletions: Int
    let activeDays: Int
    let averageCompletionRate: Double
    let longestStreak: Int
    let currentStreak: Int
    let totalXP: Int
    let totalPoints: Int
    let level: Int
}

enum MotivationType {
    case encouragement
    case celebration
    case challenge
    case support
    case inspiration
}

enum WeakArea {
    case habitConsistency
    case taskManagement
    case streakBuilding
    case motivation
}

enum StreakMotivationLevel {
    case restart
    case building
    case strong
    case impressive
    case legendary
    case mythical
}

enum ProgressType {
    case excellent
    case good
    case moderate
    case needsImprovement
}

struct MotivationalMessage {
    let type: MotivationType
    let title: String
    let body: String
    let actionText: String
    let iconName: String
}

struct Quote {
    let text: String
    let author: String
    let category: String
    let mood: String
}

struct PersonalizedTip {
    let title: String
    let content: String
    let category: String
    let difficulty: Difficulty
    let estimatedTime: Int
    let actionSteps: [String]
    
    enum Difficulty {
        case easy
        case medium
        case hard
    }
}

struct TipContent {
    let title: String
    let content: String
    let category: String
    let difficulty: PersonalizedTip.Difficulty
    let estimatedTime: Int
    let actionSteps: [String]
}

struct CelebrationMessage {
    let title: String
    let message: String
    let emoji: String
    let animation: String
    let sound: String
    let shareText: String
}

struct StreakMotivation {
    let title: String
    let message: String
    let encouragement: String
    let nextMilestone: Int
    let motivationLevel: StreakMotivationLevel
}

struct ComebackMessage {
    let title: String
    let message: String
    let encouragement: String
    let actionText: String
    let iconName: String
}

struct ProgressEncouragement {
    let title: String
    let message: String
    let progressType: ProgressType
    let suggestions: [String]
    let nextGoal: String
}

struct RewardCelebration {
    let title: String
    let message: String
    let animation: String
    let sound: String
    let shareText: String
}

// MARK: - Message Generators

struct QuoteDatabase {
    static let all: [Quote] = [
        Quote(text: "Не важно, насколько медленно вы идете, пока вы не останавливаетесь.", author: "Конфуций", category: "Мотивация", mood: "Вдохновляющий"),
        Quote(text: "Успех - это сумма небольших усилий, повторяемых день за днем.", author: "Роберт Кольер", category: "Привычки", mood: "Мотивирующий"),
        Quote(text: "Лучшее время для посадки дерева было 20 лет назад. Второе лучшее время - сейчас.", author: "Китайская пословица", category: "Действие", mood: "Мотивирующий"),
        Quote(text: "Вы не можете вернуться назад и изменить начало, но можете начать там, где находитесь, и изменить концовку.", author: "К.С. Льюис", category: "Изменения", mood: "Надежда"),
        Quote(text: "Мотивация - это то, что заставляет вас начать. Привычка - это то, что заставляет вас продолжать.", author: "Джим Рон", category: "Привычки", mood: "Мотивирующий")
    ]
    
    static let `default` = Quote(text: "Каждый день - новая возможность стать лучше.", author: "Неизвестно", category: "Мотивация", mood: "Вдохновляющий")
}

struct CelebrationMessageGenerator {
    static func messagesForAchievement(_ achievement: Achievement) -> [CelebrationMessage] {
        switch achievement.rarity {
        case .common:
            return [
                CelebrationMessage(
                    title: "Поздравляем!",
                    message: "Вы получили достижение '\(achievement.name)'!",
                    emoji: "🎉",
                    animation: "confetti",
                    sound: "celebration",
                    shareText: "Я только что получил достижение '\(achievement.name)' в планировщике!"
                )
            ]
        case .legendary:
            return [
                CelebrationMessage(
                    title: "Невероятно!",
                    message: "Вы достигли легендарного уровня с '\(achievement.name)'!",
                    emoji: "👑",
                    animation: "fireworks",
                    sound: "epic_celebration",
                    shareText: "Я достиг легендарного достижения '\(achievement.name)'! 👑"
                )
            ]
        default:
            return [
                CelebrationMessage(
                    title: "Отлично!",
                    message: "Достижение '\(achievement.name)' разблокировано!",
                    emoji: "⭐",
                    animation: "sparkles",
                    sound: "achievement",
                    shareText: "Новое достижение разблокировано: '\(achievement.name)' ⭐"
                )
            ]
        }
    }
    
    static let `default` = CelebrationMessage(
        title: "Поздравляем!",
        message: "Вы получили новое достижение!",
        emoji: "🎉",
        animation: "confetti",
        sound: "celebration",
        shareText: "Я получил новое достижение!"
    )
}

struct StreakMotivationGenerator {
    static func generate(for habit: Habit, streakLength: Int, motivationLevel: StreakMotivationLevel) -> StreakMotivation {
        switch motivationLevel {
        case .restart:
            return StreakMotivation(
                title: "Новое начало",
                message: "Каждый эксперт когда-то был новичком. Начните свою серию заново!",
                encouragement: "Первый день - самый важный. Вы можете это сделать!",
                nextMilestone: 7,
                motivationLevel: .restart
            )
        case .building:
            return StreakMotivation(
                title: "Набираем обороты",
                message: "Серия из \(streakLength) дней - отличное начало! Продолжайте двигаться к неделе.",
                encouragement: "Каждый день приближает вас к цели. Не останавливайтесь!",
                nextMilestone: 7,
                motivationLevel: .building
            )
        case .strong:
            return StreakMotivation(
                title: "Сильная серия",
                message: "\(streakLength) дней подряд - это впечатляет! Стремитесь к месяцу.",
                encouragement: "Вы доказали, что можете быть постоянными. Продолжайте!",
                nextMilestone: 30,
                motivationLevel: .strong
            )
        case .impressive:
            return StreakMotivation(
                title: "Впечатляющая серия",
                message: "\(streakLength) дней - это настоящее достижение! Стремитесь к 60 дням.",
                encouragement: "Вы в зоне мастерства! Эта привычка становится частью вас.",
                nextMilestone: 60,
                motivationLevel: .impressive
            )
        case .legendary:
            return StreakMotivation(
                title: "Легендарная серия",
                message: "\(streakLength) дней - вы легенда! Стремитесь к полугоду.",
                encouragement: "Вы вдохновляете других своим постоянством!",
                nextMilestone: 180,
                motivationLevel: .legendary
            )
        case .mythical:
            return StreakMotivation(
                title: "Мифическая серия",
                message: "\(streakLength) дней - это невероятно! Вы мастер привычек.",
                encouragement: "Вы достигли уровня, о котором мечтают многие!",
                nextMilestone: 365,
                motivationLevel: .mythical
            )
        }
    }
}

struct ComebackMessageGenerator {
    static func generate(daysSinceLastActivity: Int, previousStreak: Int, userName: String) -> ComebackMessage {
        if daysSinceLastActivity <= 3 {
            return ComebackMessage(
                title: "Добро пожаловать обратно!",
                message: "Мы скучали по вам, \(userName)! Готовы продолжить путь к своим целям?",
                encouragement: "Небольшой перерыв - это нормально. Главное - вернуться!",
                actionText: "Продолжить",
                iconName: "hand.wave.fill"
            )
        } else if daysSinceLastActivity <= 7 {
            return ComebackMessage(
                title: "Время возвращения!",
                message: "Неделя прошла быстро. Давайте восстановим ваши привычки!",
                encouragement: "Помните вашу серию из \(previousStreak) дней? Вы можете повторить это!",
                actionText: "Начать заново",
                iconName: "arrow.clockwise"
            )
        } else {
            return ComebackMessage(
                title: "Мы вас ждали!",
                message: "Прошло уже \(daysSinceLastActivity) дней. Готовы к новому старту?",
                encouragement: "Каждый день - новая возможность. Начните с малого!",
                actionText: "Новый старт",
                iconName: "sunrise.fill"
            )
        }
    }
}

struct ProgressEncouragementGenerator {
    static func generate(for user: User, stats: UserStats, progressType: ProgressType) -> ProgressEncouragement {
        switch progressType {
        case .excellent:
            return ProgressEncouragement(
                title: "Превосходный прогресс!",
                message: "Вы на вершине своей формы! Коэффициент выполнения \(Int(stats.averageCompletionRate * 100))%",
                progressType: .excellent,
                suggestions: [
                    "Попробуйте добавить новую привычку",
                    "Поделитесь своим опытом с друзьями",
                    "Установите более амбициозные цели"
                ],
                nextGoal: "Поддержать высокий уровень в течение месяца"
            )
        case .good:
            return ProgressEncouragement(
                title: "Хорошая работа!",
                message: "Вы на правильном пути! Коэффициент выполнения \(Int(stats.averageCompletionRate * 100))%",
                progressType: .good,
                suggestions: [
                    "Постарайтесь быть более последовательными",
                    "Установите напоминания для сложных дней",
                    "Празднуйте маленькие победы"
                ],
                nextGoal: "Поднять коэффициент выполнения до 80%"
            )
        case .moderate:
            return ProgressEncouragement(
                title: "Продолжайте стараться!",
                message: "Есть место для улучшений. Коэффициент выполнения \(Int(stats.averageCompletionRate * 100))%",
                progressType: .moderate,
                suggestions: [
                    "Сосредоточьтесь на одной привычке",
                    "Уменьшите нагрузку до комфортного уровня",
                    "Найдите мотивацию в маленьких победах"
                ],
                nextGoal: "Поднять коэффициент выполнения до 60%"
            )
        case .needsImprovement:
            return ProgressEncouragement(
                title: "Время для изменений!",
                message: "Не расстраивайтесь! Каждый может улучшить свои результаты.",
                progressType: .needsImprovement,
                suggestions: [
                    "Начните с одной простой привычки",
                    "Сделайте привычки максимально легкими",
                    "Свяжите новые привычки с существующими"
                ],
                nextGoal: "Выполнить одну привычку 7 дней подряд"
            )
        }
    }
}

struct RewardCelebrationGenerator {
    static func generate(reward: String, userName: String, userLevel: Int) -> RewardCelebration {
        return RewardCelebration(
            title: "Награда получена!",
            message: "\(userName), вы заработали '\(reward)'! Поздравляем с достижением!",
            animation: "reward_celebration",
            sound: "reward_sound",
            shareText: "Я получил награду '\(reward)' за свои достижения!"
        )
    }
} 