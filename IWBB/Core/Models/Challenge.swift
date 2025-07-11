import Foundation
import SwiftData

// MARK: - Challenge
@Model
final class Challenge {
    @Attribute(.unique) var id: UUID
    var title: String
    var description: String
    var type: ChallengeType
    var difficulty: ChallengeDifficulty
    var category: AchievementCategory
    var iconName: String
    var colorHex: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var isGlobal: Bool
    var maxParticipants: Int?
    var pointsReward: Int
    var xpReward: Int
    var requirements: [String: Any] // JSON для хранения требований
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ChallengeParticipation.challenge)
    var participations: [ChallengeParticipation]
    
    init(
        title: String,
        description: String,
        type: ChallengeType,
        difficulty: ChallengeDifficulty,
        category: AchievementCategory,
        iconName: String,
        colorHex: String,
        startDate: Date,
        endDate: Date,
        isGlobal: Bool = false,
        maxParticipants: Int? = nil,
        pointsReward: Int,
        xpReward: Int,
        requirements: [String: Any] = [:]
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.type = type
        self.difficulty = difficulty
        self.category = category
        self.iconName = iconName
        self.colorHex = colorHex
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = true
        self.isGlobal = isGlobal
        self.maxParticipants = maxParticipants
        self.pointsReward = pointsReward
        self.xpReward = xpReward
        self.requirements = requirements
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Проверяет, активен ли вызов в данный момент
    var isCurrentlyActive: Bool {
        let now = Date()
        return isActive && now >= startDate && now <= endDate
    }
    
    /// Дней до окончания вызова
    var daysRemaining: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }
    
    /// Количество участников
    var participantCount: Int {
        return participations.count
    }
    
    /// Проверяет, может ли пользователь присоединиться к вызову
    func canJoin(userID: UUID) -> Bool {
        guard isCurrentlyActive else { return false }
        guard !participations.contains(where: { $0.userID == userID }) else { return false }
        
        if let maxParticipants = maxParticipants {
            return participantCount < maxParticipants
        }
        
        return true
    }
    
    /// Участие пользователя в вызове
    func participationForUser(_ userID: UUID) -> ChallengeParticipation? {
        return participations.first { $0.userID == userID }
    }
    
    /// Лидеры вызова
    var leaderboard: [ChallengeParticipation] {
        return participations
            .filter { $0.isActive }
            .sorted { $0.currentProgress > $1.currentProgress }
    }
}

// MARK: - ChallengeType
enum ChallengeType: String, CaseIterable, Codable {
    case personal = "personal"
    case global = "global"
    case competitive = "competitive"
    case cooperative = "cooperative"
    case seasonal = "seasonal"
    case special = "special"
    
    var localizedName: String {
        switch self {
        case .personal: return "Персональный"
        case .global: return "Глобальный"
        case .competitive: return "Соревновательный"
        case .cooperative: return "Совместный"
        case .seasonal: return "Сезонный"
        case .special: return "Особый"
        }
    }
    
    var iconName: String {
        switch self {
        case .personal: return "person.circle"
        case .global: return "globe"
        case .competitive: return "trophy"
        case .cooperative: return "person.2"
        case .seasonal: return "calendar"
        case .special: return "sparkles"
        }
    }
}

// MARK: - ChallengeDifficulty
enum ChallengeDifficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case expert = "expert"
    case legendary = "legendary"
    
    var localizedName: String {
        switch self {
        case .easy: return "Легкий"
        case .medium: return "Средний"
        case .hard: return "Сложный"
        case .expert: return "Экспертный"
        case .legendary: return "Легендарный"
        }
    }
    
    var colorHex: String {
        switch self {
        case .easy: return "#4CAF50"
        case .medium: return "#FFC107"
        case .hard: return "#FF9800"
        case .expert: return "#F44336"
        case .legendary: return "#9C27B0"
        }
    }
    
    var pointsMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .hard: return 2.0
        case .expert: return 3.0
        case .legendary: return 5.0
        }
    }
}

// MARK: - ChallengeParticipation
@Model
final class ChallengeParticipation {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var challengeID: UUID
    var joinedAt: Date
    var currentProgress: Int
    var targetProgress: Int
    var isCompleted: Bool
    var completedAt: Date?
    var isActive: Bool
    var rank: Int?
    var pointsEarned: Int
    var xpEarned: Int
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    var challenge: Challenge?
    @Relationship(deleteRule: .cascade, inverse: \ChallengeProgressEntry.participation)
    var progressEntries: [ChallengeProgressEntry]
    
    init(
        userID: UUID,
        challengeID: UUID,
        targetProgress: Int = 1
    ) {
        self.id = UUID()
        self.userID = userID
        self.challengeID = challengeID
        self.joinedAt = Date()
        self.currentProgress = 0
        self.targetProgress = targetProgress
        self.isCompleted = false
        self.isActive = true
        self.pointsEarned = 0
        self.xpEarned = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Обновляет прогресс участия
    func updateProgress(_ newProgress: Int) {
        currentProgress = newProgress
        
        if currentProgress >= targetProgress && !isCompleted {
            complete()
        }
        
        updatedAt = Date()
        needsSync = true
    }
    
    /// Завершает участие в вызове
    func complete() {
        isCompleted = true
        completedAt = Date()
        
        // Начисляем награды
        if let challenge = challenge {
            pointsEarned = challenge.pointsReward
            xpEarned = challenge.xpReward
        }
        
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
    
    /// Дней участия
    var daysParticipated: Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: joinedAt, to: Date()).day ?? 0
    }
}

// MARK: - ChallengeProgressEntry
@Model
final class ChallengeProgressEntry {
    @Attribute(.unique) var id: UUID
    var participationID: UUID
    var date: Date
    var progressValue: Int
    var description: String?
    var createdAt: Date
    
    // CloudKit Sync
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // Relationships
    var participation: ChallengeParticipation?
    
    init(
        participationID: UUID,
        date: Date,
        progressValue: Int,
        description: String? = nil
    ) {
        self.id = UUID()
        self.participationID = participationID
        self.date = date
        self.progressValue = progressValue
        self.description = description
        self.createdAt = Date()
        self.needsSync = true
    }
} 