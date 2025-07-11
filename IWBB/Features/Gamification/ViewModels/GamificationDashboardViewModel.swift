import Foundation
import SwiftUI

// MARK: - GamificationDashboardViewModel

@Observable
final class GamificationDashboardViewModel {
    
    // MARK: - State
    
    struct State {
        var dashboardData: GamificationDashboard?
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var error: AppError?
        var selectedTab: DashboardTab = .overview
        var showingAchievementDetail: Achievement?
        var showingChallengeDetail: Challenge?
        var showingLevelDetail: Bool = false
        var showingProfile: Bool = false
        var animateNewAchievement: Bool = false
        var animateLevelUp: Bool = false
        var recentNotifications: [GamificationNotification] = []
        var showingNotifications: Bool = false
    }
    
    // MARK: - Input
    
    enum Input {
        case loadDashboard
        case refreshDashboard
        case tabChanged(DashboardTab)
        case achievementTapped(Achievement)
        case challengeTapped(Challenge)
        case levelDetailTapped
        case profileTapped
        case joinChallenge(Challenge)
        case claimReward(Achievement)
        case dismissAchievementDetail
        case dismissChallengeDetail
        case dismissLevelDetail
        case dismissProfile
        case dismissError
        case showNotifications
        case dismissNotifications
        case markNotificationAsRead(GamificationNotification)
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let gameService: GameServiceProtocol
    private let achievementService: AchievementServiceProtocol
    private let challengeService: ChallengeServiceProtocol
    private let levelService: LevelProgressionServiceProtocol
    private let motivationService: MotivationServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let user: User
    
    // MARK: - Initialization
    
    init(
        gameService: GameServiceProtocol,
        achievementService: AchievementServiceProtocol,
        challengeService: ChallengeServiceProtocol,
        levelService: LevelProgressionServiceProtocol,
        motivationService: MotivationServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol,
        user: User
    ) {
        self.gameService = gameService
        self.achievementService = achievementService
        self.challengeService = challengeService
        self.levelService = levelService
        self.motivationService = motivationService
        self.errorHandlingService = errorHandlingService
        self.user = user
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadDashboard:
                await loadDashboard()
            case .refreshDashboard:
                await refreshDashboard()
            case .tabChanged(let tab):
                state.selectedTab = tab
            case .achievementTapped(let achievement):
                state.showingAchievementDetail = achievement
            case .challengeTapped(let challenge):
                state.showingChallengeDetail = challenge
            case .levelDetailTapped:
                state.showingLevelDetail = true
            case .profileTapped:
                state.showingProfile = true
            case .joinChallenge(let challenge):
                await joinChallenge(challenge)
            case .claimReward(let achievement):
                await claimReward(achievement)
            case .dismissAchievementDetail:
                state.showingAchievementDetail = nil
            case .dismissChallengeDetail:
                state.showingChallengeDetail = nil
            case .dismissLevelDetail:
                state.showingLevelDetail = false
            case .dismissProfile:
                state.showingProfile = false
            case .dismissError:
                state.error = nil
            case .showNotifications:
                state.showingNotifications = true
                await loadNotifications()
            case .dismissNotifications:
                state.showingNotifications = false
            case .markNotificationAsRead(let notification):
                await markNotificationAsRead(notification)
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadDashboard() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let dashboardData = try await gameService.getDashboardData(for: user)
            state.dashboardData = dashboardData
            
            // Check for new achievements to animate
            await checkForNewAchievements()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading gamification dashboard"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshDashboard() async {
        state.isRefreshing = true
        
        do {
            let dashboardData = try await gameService.getDashboardData(for: user)
            state.dashboardData = dashboardData
            
            // Check for level up
            await checkForLevelUp()
            
            state.error = nil
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Refreshing gamification dashboard"))
        }
        
        state.isRefreshing = false
    }
    
    @MainActor
    private func joinChallenge(_ challenge: Challenge) async {
        do {
            try await challengeService.joinChallenge(challenge, user: user)
            
            // Refresh dashboard to show updated challenge status
            await refreshDashboard()
            
            // Show success feedback
            await showSuccessFeedback(message: "Вы присоединились к вызову «\(challenge.name)»!")
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Joining challenge"))
        }
    }
    
    @MainActor
    private func claimReward(_ achievement: Achievement) async {
        do {
            try await achievementService.claimReward(achievement, for: user)
            
            // Refresh dashboard to show updated achievement status
            await refreshDashboard()
            
            // Show success feedback
            await showSuccessFeedback(message: "Награда получена!")
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Claiming reward"))
        }
    }
    
    @MainActor
    private func checkForNewAchievements() async {
        // Check if there are any new achievements since last visit
        // This would typically be stored in user defaults or a separate service
        // For now, we'll just animate if there are recent achievements
        if let dashboardData = state.dashboardData,
           let recentAchievement = dashboardData.recentAchievements.first,
           Calendar.current.isDateInToday(recentAchievement.unlockedAt ?? Date()) {
            
            state.animateNewAchievement = true
            
            // Reset animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.state.animateNewAchievement = false
            }
        }
    }
    
    @MainActor
    private func checkForLevelUp() async {
        // Check if user leveled up recently
        if let dashboardData = state.dashboardData,
           let levelInfo = dashboardData.levelInfo {
            
            // This would typically compare with previously stored level
            // For now, we'll check if the level is a round number (milestone)
            if levelInfo.currentLevel % 5 == 0 && levelInfo.currentLevel > 1 {
                state.animateLevelUp = true
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.state.animateLevelUp = false
                }
            }
        }
    }
    
    @MainActor
    private func loadNotifications() async {
        do {
            // Load recent gamification notifications
            let notifications = try await motivationService.getRecentNotifications(for: user)
            state.recentNotifications = notifications
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading notifications"))
        }
    }
    
    @MainActor
    private func markNotificationAsRead(_ notification: GamificationNotification) async {
        do {
            try await motivationService.markNotificationAsRead(notification, for: user)
            
            // Update local state
            if let index = state.recentNotifications.firstIndex(where: { $0.id == notification.id }) {
                state.recentNotifications[index].isRead = true
            }
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Marking notification as read"))
        }
    }
    
    @MainActor
    private func showSuccessFeedback(message: String) async {
        // This could trigger haptic feedback or show a toast
        // For now, we'll just log the success
        #if DEBUG
        print("Success: \(message)")
        #endif
    }
}

// MARK: - Supporting Types

enum DashboardTab: CaseIterable, Hashable {
    case overview
    case achievements
    case challenges
    case progress
    
    var title: String {
        switch self {
        case .overview:
            return "Обзор"
        case .achievements:
            return "Достижения"
        case .challenges:
            return "Вызовы"
        case .progress:
            return "Прогресс"
        }
    }
    
    var icon: String {
        switch self {
        case .overview:
            return "house"
        case .achievements:
            return "star"
        case .challenges:
            return "flag"
        case .progress:
            return "chart.bar"
        }
    }
}

struct GamificationNotification: Identifiable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let date: Date
    var isRead: Bool
    
    enum NotificationType {
        case achievement
        case levelUp
        case challenge
        case streak
        case motivation
    }
}

// MARK: - Extensions

extension GamificationDashboardViewModel {
    
    /// Получает прогресс к следующему уровню
    var progressToNextLevel: Double {
        guard let levelInfo = state.dashboardData?.levelInfo else { return 0.0 }
        return levelInfo.progressToNextLevel
    }
    
    /// Получает текущий уровень пользователя
    var currentLevel: Int {
        return state.dashboardData?.levelInfo?.currentLevel ?? 1
    }
    
    /// Получает текущий титул пользователя
    var currentTitle: String {
        return state.dashboardData?.levelInfo?.title ?? "Новичок"
    }
    
    /// Получает общее количество очков
    var totalPoints: Int {
        return state.dashboardData?.levelInfo?.totalPoints ?? 0
    }
    
    /// Проверяет, есть ли доступные вызовы
    var hasAvailableChallenges: Bool {
        return !(state.dashboardData?.availableChallenges.isEmpty ?? true)
    }
    
    /// Проверяет, есть ли активные вызовы
    var hasActiveChallenges: Bool {
        return !(state.dashboardData?.activeChallenges.isEmpty ?? true)
    }
    
    /// Получает количество непрочитанных уведомлений
    var unreadNotificationsCount: Int {
        return state.recentNotifications.filter { !$0.isRead }.count
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        return !state.isLoading && state.dashboardData == nil
    }
    
    /// Получает сообщение для пустого состояния
    var emptyStateMessage: String {
        return "Начните отслеживать привычки, чтобы увидеть ваш прогресс!"
    }
}

// MARK: - Dashboard Data Model

struct GamificationDashboard {
    let user: User
    let levelInfo: LevelInfo?
    let nextLevelRequirements: NextLevelRequirements?
    let recentAchievements: [Achievement]
    let activeChallenges: [Challenge]
    let availableChallenges: [Challenge]
    let recentPointsHistory: [PointsHistory]
    let motivationalMessage: String?
    let dailyQuote: String?
}

struct LevelInfo {
    let currentLevel: Int
    let currentXP: Int
    let totalPoints: Int
    let progressToNextLevel: Double
    let title: String
    let prestigeLevel: Int
}

struct NextLevelRequirements {
    let xpRequired: Int
    let estimatedDays: Int
    let suggestedActions: [String]
} 