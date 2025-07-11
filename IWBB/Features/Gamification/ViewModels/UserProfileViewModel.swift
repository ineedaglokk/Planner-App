import Foundation
import SwiftUI

// MARK: - UserProfileViewModel

@Observable
final class UserProfileViewModel {
    
    // MARK: - State
    
    struct State {
        var userProfile: UserProfile?
        var gameStats: GameStats?
        var levelHistory: [LevelProgress] = []
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var error: AppError?
        var selectedTab: ProfileTab = .overview
        var selectedStatsPeriod: StatsPeriod = .allTime
        var showingPrestigeOptions: Bool = false
        var showingAchievementDetail: Achievement?
        var showingLevelDetail: Bool = false
        var showingStatsDetail: Bool = false
        var animatePrestigeAvailable: Bool = false
    }
    
    // MARK: - Input
    
    enum Input {
        case loadProfile
        case refreshProfile
        case tabChanged(ProfileTab)
        case statsPeriodChanged(StatsPeriod)
        case achievementTapped(Achievement)
        case levelDetailTapped
        case statsDetailTapped
        case prestigeTapped
        case confirmPrestige
        case dismissPrestigeOptions
        case dismissAchievementDetail
        case dismissLevelDetail
        case dismissStatsDetail
        case dismissError
        case shareProfile
        case exportStats
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let gameService: GameServiceProtocol
    private let achievementService: AchievementServiceProtocol
    private let levelService: LevelProgressionServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let user: User
    
    // MARK: - Initialization
    
    init(
        gameService: GameServiceProtocol,
        achievementService: AchievementServiceProtocol,
        levelService: LevelProgressionServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol,
        user: User
    ) {
        self.gameService = gameService
        self.achievementService = achievementService
        self.levelService = levelService
        self.errorHandlingService = errorHandlingService
        self.user = user
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadProfile:
                await loadProfile()
            case .refreshProfile:
                await refreshProfile()
            case .tabChanged(let tab):
                state.selectedTab = tab
            case .statsPeriodChanged(let period):
                state.selectedStatsPeriod = period
                await loadGameStats()
            case .achievementTapped(let achievement):
                state.showingAchievementDetail = achievement
            case .levelDetailTapped:
                state.showingLevelDetail = true
            case .statsDetailTapped:
                state.showingStatsDetail = true
            case .prestigeTapped:
                state.showingPrestigeOptions = true
            case .confirmPrestige:
                await performPrestige()
            case .dismissPrestigeOptions:
                state.showingPrestigeOptions = false
            case .dismissAchievementDetail:
                state.showingAchievementDetail = nil
            case .dismissLevelDetail:
                state.showingLevelDetail = false
            case .dismissStatsDetail:
                state.showingStatsDetail = false
            case .dismissError:
                state.error = nil
            case .shareProfile:
                await shareProfile()
            case .exportStats:
                await exportStats()
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadProfile() async {
        state.isLoading = true
        state.error = nil
        
        do {
            async let userProfile = loadUserProfile()
            async let gameStats = loadGameStats()
            async let levelHistory = loadLevelHistory()
            
            state.userProfile = try await userProfile
            state.gameStats = try await gameStats
            state.levelHistory = try await levelHistory
            
            // Check if prestige is available
            await checkPrestigeAvailability()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading user profile"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshProfile() async {
        state.isRefreshing = true
        
        do {
            async let userProfile = loadUserProfile()
            async let gameStats = loadGameStats()
            async let levelHistory = loadLevelHistory()
            
            state.userProfile = try await userProfile
            state.gameStats = try await gameStats
            state.levelHistory = try await levelHistory
            
            await checkPrestigeAvailability()
            
            state.error = nil
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Refreshing user profile"))
        }
        
        state.isRefreshing = false
    }
    
    private func loadUserProfile() async throws -> UserProfile {
        let levelInfo = try await levelService.getLevelInfo(for: user)
        let unlockedAchievements = try await achievementService.getUnlockedAchievements(for: user)
        let totalAchievements = try await achievementService.getTotalAchievementsCount()
        
        return UserProfile(
            user: user,
            levelInfo: levelInfo,
            unlockedAchievements: unlockedAchievements,
            totalAchievements: totalAchievements,
            joinDate: user.createdAt,
            lastActiveDate: user.updatedAt
        )
    }
    
    private func loadGameStats() async throws -> GameStats {
        return try await gameService.getGameStats(for: user)
    }
    
    private func loadLevelHistory() async throws -> [LevelProgress] {
        return try await levelService.getLevelHistory(for: user)
    }
    
    @MainActor
    private func checkPrestigeAvailability() async {
        do {
            let isEligible = try await levelService.checkPrestigeEligibility(for: user)
            
            if isEligible && !state.animatePrestigeAvailable {
                state.animatePrestigeAvailable = true
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.state.animatePrestigeAvailable = false
                }
            }
            
        } catch {
            // Prestige check failed, but this is not critical
            #if DEBUG
            print("Failed to check prestige eligibility: \(error)")
            #endif
        }
    }
    
    @MainActor
    private func performPrestige() async {
        do {
            try await levelService.performPrestige(for: user)
            
            // Refresh profile to show updated prestige status
            await refreshProfile()
            
            state.showingPrestigeOptions = false
            
            // Show success feedback
            await showSuccessFeedback(message: "Поздравляем с престижем! Вы получили особые привилегии.")
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Performing prestige"))
            
            state.showingPrestigeOptions = false
        }
    }
    
    @MainActor
    private func shareProfile() async {
        // Create shareable content
        guard let profile = state.userProfile else { return }
        
        let shareText = """
        Мой прогресс в планировщике привычек:
        
        🎯 Уровень: \(profile.levelInfo.currentLevel) (\(profile.levelInfo.title))
        ⭐ Достижения: \(profile.unlockedAchievements.count)/\(profile.totalAchievements)
        🔥 Общие очки: \(profile.levelInfo.totalPoints)
        
        Присоединяйтесь к формированию полезных привычек!
        """
        
        // This would trigger the share sheet
        #if DEBUG
        print("Sharing profile: \(shareText)")
        #endif
    }
    
    @MainActor
    private func exportStats() async {
        // Export detailed statistics
        guard let stats = state.gameStats else { return }
        
        // This would create a detailed export
        #if DEBUG
        print("Exporting stats: \(stats)")
        #endif
    }
    
    @MainActor
    private func showSuccessFeedback(message: String) async {
        // This could trigger haptic feedback or show a toast
        #if DEBUG
        print("Success: \(message)")
        #endif
    }
}

// MARK: - Supporting Types

enum ProfileTab: CaseIterable, Hashable {
    case overview
    case achievements
    case statistics
    case history
    
    var title: String {
        switch self {
        case .overview:
            return "Обзор"
        case .achievements:
            return "Достижения"
        case .statistics:
            return "Статистика"
        case .history:
            return "История"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "person"
        case .achievements:
            return "star"
        case .statistics:
            return "chart.bar"
        case .history:
            return "clock"
        }
    }
}

enum StatsPeriod: CaseIterable, Hashable {
    case week
    case month
    case year
    case allTime
    
    var title: String {
        switch self {
        case .week:
            return "Неделя"
        case .month:
            return "Месяц"
        case .year:
            return "Год"
        case .allTime:
            return "Всё время"
        }
    }
    
    var dateInterval: DateInterval {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .week:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            return DateInterval(start: weekStart, end: now)
        case .month:
            let monthStart = calendar.dateInterval(of: .month, for: now)!.start
            return DateInterval(start: monthStart, end: now)
        case .year:
            let yearStart = calendar.dateInterval(of: .year, for: now)!.start
            return DateInterval(start: yearStart, end: now)
        case .allTime:
            return DateInterval(start: Date.distantPast, end: now)
        }
    }
}

struct UserProfile {
    let user: User
    let levelInfo: LevelInfo
    let unlockedAchievements: [Achievement]
    let totalAchievements: Int
    let joinDate: Date
    let lastActiveDate: Date
    
    var achievementProgress: Double {
        guard totalAchievements > 0 else { return 0.0 }
        return Double(unlockedAchievements.count) / Double(totalAchievements)
    }
    
    var daysSinceJoin: Int {
        Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
    }
    
    var daysSinceLastActive: Int {
        Calendar.current.dateComponents([.day], from: lastActiveDate, to: Date()).day ?? 0
    }
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
    let completionRate: Double
}

// MARK: - Extensions

extension UserProfileViewModel {
    
    /// Проверяет, доступен ли престиж
    var isPrestigeAvailable: Bool {
        guard let levelInfo = state.userProfile?.levelInfo else { return false }
        return levelInfo.currentLevel >= 50
    }
    
    /// Получает описание текущего уровня
    var levelDescription: String {
        guard let levelInfo = state.userProfile?.levelInfo else { return "Загрузка..." }
        
        if levelInfo.prestigeLevel > 0 {
            return "Уровень \(levelInfo.currentLevel) • Престиж \(levelInfo.prestigeLevel)"
        } else {
            return "Уровень \(levelInfo.currentLevel)"
        }
    }
    
    /// Получает прогресс к следующему уровню
    var progressToNextLevel: Double {
        return state.userProfile?.levelInfo.progressToNextLevel ?? 0.0
    }
    
    /// Получает процент разблокированных достижений
    var achievementProgress: Double {
        return state.userProfile?.achievementProgress ?? 0.0
    }
    
    /// Получает топ категории по активности
    var topCategories: [CategoryStats] {
        return state.gameStats?.categoryStats
            .sorted { $0.totalCompletions > $1.totalCompletions }
            .prefix(5)
            .map { $0 } ?? []
    }
    
    /// Проверяет, есть ли данные для отображения
    var hasProfileData: Bool {
        return state.userProfile != nil
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        return !state.isLoading && !hasProfileData
    }
} 