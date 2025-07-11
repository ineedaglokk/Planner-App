import Foundation
import SwiftData

// MARK: - ChallengeService Protocol
protocol ChallengeServiceProtocol: ServiceProtocol {
    func createChallenge(_ challenge: Challenge) async throws
    func updateChallenge(_ challenge: Challenge) async throws
    func deleteChallenge(_ challenge: Challenge) async throws
    func getActiveChallenges() async throws -> [Challenge]
    func getChallengesByType(_ type: ChallengeType) async throws -> [Challenge]
    func getChallengesByDifficulty(_ difficulty: ChallengeDifficulty) async throws -> [Challenge]
    func joinChallenge(_ challengeID: UUID, userID: UUID) async throws -> Bool
    func leaveChallenge(_ challengeID: UUID, userID: UUID) async throws -> Bool
    func updateChallengeProgress(_ challengeID: UUID, userID: UUID, progress: Int) async throws
    func getLeaderboard(_ challengeID: UUID) async throws -> [ChallengeParticipation]
    func getUserParticipations(for userID: UUID) async throws -> [ChallengeParticipation]
    func getActiveChallengesForUser(_ userID: UUID) async throws -> [Challenge]
    func completeChallenge(_ challengeID: UUID, userID: UUID) async throws -> Bool
    func checkChallengeCompletion(_ challengeID: UUID) async throws
    func createDefaultChallenges() async throws
}

// MARK: - ChallengeService Implementation
final class ChallengeService: ChallengeServiceProtocol {
    
    // MARK: - Properties
    private let modelContext: ModelContext
    private let pointsService: PointsCalculationServiceProtocol
    private let achievementService: AchievementServiceProtocol
    private let notificationService: NotificationServiceProtocol
    var isInitialized: Bool = false
    
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
        print("ChallengeService initializing...")
        #endif
        
        guard !modelContext.isMainActor else {
            throw ServiceError.initializationFailed("ModelContext is not available")
        }
        
        // Создаем базовые вызовы при первом запуске
        try await createDefaultChallenges()
        
        isInitialized = true
        
        #if DEBUG
        print("ChallengeService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("ChallengeService cleaning up...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("ChallengeService cleaned up")
        #endif
    }
    
    // MARK: - Challenge Management
    func createChallenge(_ challenge: Challenge) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        modelContext.insert(challenge)
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Created challenge: \(challenge.title)")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to create challenge: \(error)")
        }
    }
    
    func updateChallenge(_ challenge: Challenge) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        challenge.updatedAt = Date()
        challenge.needsSync = true
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Updated challenge: \(challenge.title)")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to update challenge: \(error)")
        }
    }
    
    func deleteChallenge(_ challenge: Challenge) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        challenge.isActive = false
        challenge.updatedAt = Date()
        challenge.needsSync = true
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Deleted challenge: \(challenge.title)")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to delete challenge: \(error)")
        }
    }
    
    // MARK: - Challenge Retrieval
    func getActiveChallenges() async throws -> [Challenge] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let now = Date()
        let predicate = #Predicate<Challenge> { 
            $0.isActive && $0.startDate <= now && $0.endDate >= now 
        }
        let descriptor = FetchDescriptor<Challenge>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.endDate),
                SortDescriptor(\.difficulty),
                SortDescriptor(\.title)
            ]
        )
        
        do {
            let challenges = try modelContext.fetch(descriptor)
            return challenges
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch active challenges: \(error)")
        }
    }
    
    func getChallengesByType(_ type: ChallengeType) async throws -> [Challenge] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<Challenge> { $0.type == type && $0.isActive }
        let descriptor = FetchDescriptor<Challenge>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.endDate),
                SortDescriptor(\.difficulty),
                SortDescriptor(\.title)
            ]
        )
        
        do {
            let challenges = try modelContext.fetch(descriptor)
            return challenges
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch challenges by type: \(error)")
        }
    }
    
    func getChallengesByDifficulty(_ difficulty: ChallengeDifficulty) async throws -> [Challenge] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<Challenge> { $0.difficulty == difficulty && $0.isActive }
        let descriptor = FetchDescriptor<Challenge>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.endDate),
                SortDescriptor(\.type),
                SortDescriptor(\.title)
            ]
        )
        
        do {
            let challenges = try modelContext.fetch(descriptor)
            return challenges
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch challenges by difficulty: \(error)")
        }
    }
    
    // MARK: - Challenge Participation
    func joinChallenge(_ challengeID: UUID, userID: UUID) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let challenge = try await getChallenge(by: challengeID) else {
            throw ServiceError.invalidParameters("Challenge not found")
        }
        
        // Проверяем, может ли пользователь присоединиться
        guard challenge.canJoin(userID: userID) else {
            return false
        }
        
        // Проверяем, не участвует ли уже пользователь
        if challenge.participationForUser(userID) != nil {
            return false
        }
        
        // Создаем участие
        let targetProgress = getTargetProgress(for: challenge)
        let participation = ChallengeParticipation(
            userID: userID,
            challengeID: challengeID,
            targetProgress: targetProgress
        )
        
        modelContext.insert(participation)
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("User \(userID) joined challenge: \(challenge.title)")
            #endif
            
            return true
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to join challenge: \(error)")
        }
    }
    
    func leaveChallenge(_ challengeID: UUID, userID: UUID) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let participation = try await getParticipation(challengeID: challengeID, userID: userID) else {
            return false
        }
        
        participation.isActive = false
        participation.updatedAt = Date()
        participation.needsSync = true
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("User \(userID) left challenge: \(challengeID)")
            #endif
            
            return true
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to leave challenge: \(error)")
        }
    }
    
    func updateChallengeProgress(_ challengeID: UUID, userID: UUID, progress: Int) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard var participation = try await getParticipation(challengeID: challengeID, userID: userID) else {
            throw ServiceError.invalidParameters("Participation not found")
        }
        
        let oldProgress = participation.currentProgress
        participation.updateProgress(progress)
        
        // Создаем запись прогресса
        let progressEntry = ChallengeProgressEntry(
            participationID: participation.id,
            date: Date(),
            progressValue: progress - oldProgress,
            description: "Прогресс обновлен"
        )
        
        modelContext.insert(progressEntry)
        
        do {
            try modelContext.save()
            
            // Проверяем завершение вызова
            if participation.isCompleted {
                _ = try await completeChallenge(challengeID, userID: userID)
            }
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to update challenge progress: \(error)")
        }
    }
    
    // MARK: - Challenge Completion
    func completeChallenge(_ challengeID: UUID, userID: UUID) async throws -> Bool {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let challenge = try await getChallenge(by: challengeID) else {
            throw ServiceError.invalidParameters("Challenge not found")
        }
        
        guard let participation = try await getParticipation(challengeID: challengeID, userID: userID) else {
            throw ServiceError.invalidParameters("Participation not found")
        }
        
        guard !participation.isCompleted else {
            return false
        }
        
        // Завершаем участие
        participation.complete()
        
        do {
            try modelContext.save()
            
            // Начисляем очки
            _ = try await pointsService.awardPoints(
                to: userID,
                amount: challenge.pointsReward,
                source: .challengeCompleted,
                sourceID: challengeID,
                reason: "Завершен вызов: \(challenge.title)"
            )
            
            // Отправляем уведомление
            try await sendCompletionNotification(for: userID, challenge: challenge)
            
            #if DEBUG
            print("Challenge completed: \(challenge.title) by user \(userID)")
            #endif
            
            return true
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to complete challenge: \(error)")
        }
    }
    
    func checkChallengeCompletion(_ challengeID: UUID) async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let challenge = try await getChallenge(by: challengeID) else {
            return
        }
        
        // Проверяем, закончился ли вызов
        if Date() > challenge.endDate {
            challenge.isActive = false
            challenge.updatedAt = Date()
            challenge.needsSync = true
            
            // Обрабатываем завершение для всех участников
            let activeParticipations = challenge.participations.filter { $0.isActive }
            
            for participation in activeParticipations {
                if participation.currentProgress >= participation.targetProgress {
                    _ = try await completeChallenge(challengeID, userID: participation.userID)
                } else {
                    participation.isActive = false
                    participation.updatedAt = Date()
                    participation.needsSync = true
                }
            }
            
            try modelContext.save()
        }
    }
    
    // MARK: - Leaderboard & Statistics
    func getLeaderboard(_ challengeID: UUID) async throws -> [ChallengeParticipation] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        guard let challenge = try await getChallenge(by: challengeID) else {
            throw ServiceError.invalidParameters("Challenge not found")
        }
        
        return challenge.leaderboard
    }
    
    func getUserParticipations(for userID: UUID) async throws -> [ChallengeParticipation] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<ChallengeParticipation> { $0.userID == userID }
        let descriptor = FetchDescriptor<ChallengeParticipation>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.joinedAt, order: .reverse)]
        )
        
        do {
            let participations = try modelContext.fetch(descriptor)
            return participations
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch user participations: \(error)")
        }
    }
    
    func getActiveChallengesForUser(_ userID: UUID) async throws -> [Challenge] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let participations = try await getUserParticipations(for: userID)
        let activeChallengeIDs = participations
            .filter { $0.isActive && !$0.isCompleted }
            .map { $0.challengeID }
        
        var activeChallenges: [Challenge] = []
        
        for challengeID in activeChallengeIDs {
            if let challenge = try await getChallenge(by: challengeID),
               challenge.isCurrentlyActive {
                activeChallenges.append(challenge)
            }
        }
        
        return activeChallenges
    }
    
    // MARK: - Default Challenges
    func createDefaultChallenges() async throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        // Проверяем, есть ли уже вызовы
        let existingChallenges = try await getActiveChallenges()
        if !existingChallenges.isEmpty {
            return
        }
        
        let defaultChallenges = getDefaultChallenges()
        
        for challenge in defaultChallenges {
            modelContext.insert(challenge)
        }
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Created \(defaultChallenges.count) default challenges")
            #endif
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to create default challenges: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getChallenge(by id: UUID) async throws -> Challenge? {
        let predicate = #Predicate<Challenge> { $0.id == id }
        let descriptor = FetchDescriptor<Challenge>(predicate: predicate)
        
        do {
            let challenges = try modelContext.fetch(descriptor)
            return challenges.first
        } catch {
            return nil
        }
    }
    
    private func getParticipation(challengeID: UUID, userID: UUID) async throws -> ChallengeParticipation? {
        let predicate = #Predicate<ChallengeParticipation> { 
            $0.challengeID == challengeID && $0.userID == userID && $0.isActive 
        }
        let descriptor = FetchDescriptor<ChallengeParticipation>(predicate: predicate)
        
        do {
            let participations = try modelContext.fetch(descriptor)
            return participations.first
        } catch {
            return nil
        }
    }
    
    private func getTargetProgress(for challenge: Challenge) -> Int {
        // Извлекаем целевое значение из требований
        if let targetValue = challenge.requirements["targetValue"] as? Int {
            return targetValue
        }
        return 1
    }
    
    private func sendCompletionNotification(for userID: UUID, challenge: Challenge) async throws {
        // Отправляем уведомление о завершении вызова
        #if DEBUG
        print("Sending challenge completion notification for: \(challenge.title)")
        #endif
        
        // Здесь будет логика отправки уведомления
        // Пока оставляем заглушку
    }
    
    private func getDefaultChallenges() -> [Challenge] {
        var challenges: [Challenge] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Недельный вызов постоянства
        let weeklyChallenge = Challenge(
            title: "Неделя постоянства",
            description: "Выполните любые 3 привычки каждый день в течение недели",
            type: .personal,
            difficulty: .easy,
            category: .habits,
            iconName: "calendar.badge.checkmark",
            colorHex: "#4CAF50",
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 7, to: today) ?? today,
            pointsReward: 100,
            xpReward: 200,
            requirements: ["type": "daily_habits", "targetValue": 21] // 3 привычки * 7 дней
        )
        challenges.append(weeklyChallenge)
        
        // Месячный вызов продуктивности
        let monthlyChallenge = Challenge(
            title: "Месяц продуктивности",
            description: "Выполните 150 задач за месяц",
            type: .global,
            difficulty: .medium,
            category: .tasks,
            iconName: "checkmark.circle.fill",
            colorHex: "#2196F3",
            startDate: today,
            endDate: calendar.date(byAdding: .month, value: 1, to: today) ?? today,
            pointsReward: 500,
            xpReward: 1000,
            requirements: ["type": "task_completion", "targetValue": 150]
        )
        challenges.append(monthlyChallenge)
        
        // Вызов раннего подъема
        let earlyBirdChallenge = Challenge(
            title: "Ранняя пташка",
            description: "Выполните 10 задач до 9:00 утра",
            type: .personal,
            difficulty: .medium,
            category: .special,
            iconName: "sunrise",
            colorHex: "#FF9800",
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 14, to: today) ?? today,
            pointsReward: 200,
            xpReward: 400,
            requirements: ["type": "early_completion", "targetValue": 10]
        )
        challenges.append(earlyBirdChallenge)
        
        // Фитнес вызов
        let fitnessChallenge = Challenge(
            title: "Фитнес марафон",
            description: "Тренируйтесь 20 дней из 30",
            type: .global,
            difficulty: .hard,
            category: .habits,
            iconName: "figure.run",
            colorHex: "#F44336",
            startDate: today,
            endDate: calendar.date(byAdding: .month, value: 1, to: today) ?? today,
            pointsReward: 750,
            xpReward: 1500,
            requirements: ["type": "fitness_days", "targetValue": 20]
        )
        challenges.append(fitnessChallenge)
        
        // Вызов для новичков
        let beginnerChallenge = Challenge(
            title: "Первые шаги",
            description: "Создайте 3 привычки и выполните их в течение 3 дней",
            type: .personal,
            difficulty: .easy,
            category: .habits,
            iconName: "footprints",
            colorHex: "#9C27B0",
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 5, to: today) ?? today,
            pointsReward: 50,
            xpReward: 100,
            requirements: ["type": "beginner_habits", "targetValue": 9] // 3 привычки * 3 дня
        )
        challenges.append(beginnerChallenge)
        
        // Соревновательный вызов
        let competitiveChallenge = Challenge(
            title: "Соревнование недели",
            description: "Наберите больше очков, чем другие участники",
            type: .competitive,
            difficulty: .expert,
            category: .milestones,
            iconName: "trophy",
            colorHex: "#FFD700",
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 7, to: today) ?? today,
            isGlobal: true,
            maxParticipants: 50,
            pointsReward: 1000,
            xpReward: 2000,
            requirements: ["type": "points_competition", "targetValue": 500]
        )
        challenges.append(competitiveChallenge)
        
        // Вызов постоянства
        let consistencyChallenge = Challenge(
            title: "Мастер постоянства",
            description: "Поддерживайте 90% выполнение всех привычек в течение 2 недель",
            type: .personal,
            difficulty: .hard,
            category: .habits,
            iconName: "target",
            colorHex: "#795548",
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 14, to: today) ?? today,
            pointsReward: 400,
            xpReward: 800,
            requirements: ["type": "consistency_rate", "targetValue": 90]
        )
        challenges.append(consistencyChallenge)
        
        // Экстремальный вызов
        let extremeChallenge = Challenge(
            title: "Невозможное возможно",
            description: "Выполните 50 задач за 5 дней",
            type: .personal,
            difficulty: .legendary,
            category: .tasks,
            iconName: "flame.fill",
            colorHex: "#E91E63",
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 5, to: today) ?? today,
            pointsReward: 1500,
            xpReward: 3000,
            requirements: ["type": "extreme_productivity", "targetValue": 50]
        )
        challenges.append(extremeChallenge)
        
        return challenges
    }
} 