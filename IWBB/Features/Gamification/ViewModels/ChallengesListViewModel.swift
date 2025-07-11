import Foundation
import SwiftUI

// MARK: - ChallengesListViewModel

@Observable
final class ChallengesListViewModel {
    
    // MARK: - State
    
    struct State {
        var availableChallenges: [Challenge] = []
        var activeChallenges: [Challenge] = []
        var completedChallenges: [Challenge] = []
        var filteredChallenges: [Challenge] = []
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var error: AppError?
        var selectedTab: ChallengeTab = .available
        var selectedFilter: ChallengeFilter = .all
        var selectedSort: ChallengeSort = .difficulty
        var selectedDifficulty: ChallengeDifficulty?
        var selectedCategory: ChallengeCategory?
        var searchText: String = ""
        var showingFilters: Bool = false
        var selectedChallenge: Challenge?
        var showingChallengeDetail: Bool = false
        var showingCreateChallenge: Bool = false
        var showingLeaderboard: Bool = false
        var animateNewChallenge: Challenge?
        var joinChallengeInProgress: Set<UUID> = []
    }
    
    // MARK: - Input
    
    enum Input {
        case loadChallenges
        case refreshChallenges
        case tabChanged(ChallengeTab)
        case filterChanged(ChallengeFilter)
        case sortChanged(ChallengeSort)
        case difficultyFilterChanged(ChallengeDifficulty?)
        case categoryFilterChanged(ChallengeCategory?)
        case searchTextChanged(String)
        case challengeTapped(Challenge)
        case joinChallenge(Challenge)
        case leaveChallenge(Challenge)
        case createChallengeTapped
        case showLeaderboard(Challenge)
        case showFilters
        case dismissFilters
        case resetFilters
        case dismissChallengeDetail
        case dismissCreateChallenge
        case dismissLeaderboard
        case dismissError
        case shareChallenge(Challenge)
        case reportChallenge(Challenge)
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let challengeService: ChallengeServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let user: User
    
    // MARK: - Initialization
    
    init(
        challengeService: ChallengeServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol,
        user: User
    ) {
        self.challengeService = challengeService
        self.errorHandlingService = errorHandlingService
        self.user = user
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadChallenges:
                await loadChallenges()
            case .refreshChallenges:
                await refreshChallenges()
            case .tabChanged(let tab):
                state.selectedTab = tab
                await filterAndSortChallenges()
            case .filterChanged(let filter):
                state.selectedFilter = filter
                await filterAndSortChallenges()
            case .sortChanged(let sort):
                state.selectedSort = sort
                await filterAndSortChallenges()
            case .difficultyFilterChanged(let difficulty):
                state.selectedDifficulty = difficulty
                await filterAndSortChallenges()
            case .categoryFilterChanged(let category):
                state.selectedCategory = category
                await filterAndSortChallenges()
            case .searchTextChanged(let text):
                state.searchText = text
                await filterAndSortChallenges()
            case .challengeTapped(let challenge):
                state.selectedChallenge = challenge
                state.showingChallengeDetail = true
            case .joinChallenge(let challenge):
                await joinChallenge(challenge)
            case .leaveChallenge(let challenge):
                await leaveChallenge(challenge)
            case .createChallengeTapped:
                state.showingCreateChallenge = true
            case .showLeaderboard(let challenge):
                state.selectedChallenge = challenge
                state.showingLeaderboard = true
            case .showFilters:
                state.showingFilters = true
            case .dismissFilters:
                state.showingFilters = false
            case .resetFilters:
                await resetFilters()
            case .dismissChallengeDetail:
                state.showingChallengeDetail = false
                state.selectedChallenge = nil
            case .dismissCreateChallenge:
                state.showingCreateChallenge = false
            case .dismissLeaderboard:
                state.showingLeaderboard = false
            case .dismissError:
                state.error = nil
            case .shareChallenge(let challenge):
                await shareChallenge(challenge)
            case .reportChallenge(let challenge):
                await reportChallenge(challenge)
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadChallenges() async {
        state.isLoading = true
        state.error = nil
        
        do {
            async let available = challengeService.getAvailableChallenges(for: user)
            async let active = challengeService.getActiveChallenge(for: user)
            async let completed = challengeService.getCompletedChallenges(for: user)
            
            state.availableChallenges = try await available
            state.activeChallenges = try await active
            state.completedChallenges = try await completed
            
            await filterAndSortChallenges()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading challenges"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshChallenges() async {
        state.isRefreshing = true
        
        do {
            async let available = challengeService.getAvailableChallenges(for: user)
            async let active = challengeService.getActiveChallenge(for: user)
            async let completed = challengeService.getCompletedChallenges(for: user)
            
            let newAvailable = try await available
            let newActive = try await active
            let newCompleted = try await completed
            
            // Check for new challenges
            let newChallenges = newAvailable.filter { newChallenge in
                !state.availableChallenges.contains { $0.id == newChallenge.id }
            }
            
            state.availableChallenges = newAvailable
            state.activeChallenges = newActive
            state.completedChallenges = newCompleted
            
            await filterAndSortChallenges()
            
            // Animate new challenges
            if let newChallenge = newChallenges.first {
                state.animateNewChallenge = newChallenge
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.state.animateNewChallenge = nil
                }
            }
            
            state.error = nil
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Refreshing challenges"))
        }
        
        state.isRefreshing = false
    }
    
    @MainActor
    private func filterAndSortChallenges() async {
        var challenges: [Challenge] = []
        
        // Get challenges based on selected tab
        switch state.selectedTab {
        case .available:
            challenges = state.availableChallenges
        case .active:
            challenges = state.activeChallenges
        case .completed:
            challenges = state.completedChallenges
        case .all:
            challenges = state.availableChallenges + state.activeChallenges + state.completedChallenges
        }
        
        // Apply search filter
        if !state.searchText.isEmpty {
            challenges = challenges.filter { challenge in
                challenge.name.localizedCaseInsensitiveContains(state.searchText) ||
                challenge.description.localizedCaseInsensitiveContains(state.searchText)
            }
        }
        
        // Apply main filter
        switch state.selectedFilter {
        case .all:
            break
        case .today:
            challenges = challenges.filter { challenge in
                Calendar.current.isDateInToday(challenge.startDate) ||
                (challenge.startDate <= Date() && challenge.endDate >= Date())
            }
        case .thisWeek:
            let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!
            challenges = challenges.filter { challenge in
                weekInterval.contains(challenge.startDate) ||
                (challenge.startDate <= weekInterval.end && challenge.endDate >= weekInterval.start)
            }
        case .personal:
            challenges = challenges.filter { $0.type == .personal }
        case .community:
            challenges = challenges.filter { $0.type == .community }
        case .competitive:
            challenges = challenges.filter { $0.type == .competitive }
        case .expiringSoon:
            let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            challenges = challenges.filter { challenge in
                challenge.endDate <= threeDaysFromNow && challenge.endDate >= Date()
            }
        }
        
        // Apply difficulty filter
        if let difficulty = state.selectedDifficulty {
            challenges = challenges.filter { $0.difficulty == difficulty }
        }
        
        // Apply category filter
        if let category = state.selectedCategory {
            challenges = challenges.filter { $0.category == category }
        }
        
        // Apply sorting
        switch state.selectedSort {
        case .difficulty:
            challenges.sort { $0.difficulty.rawValue < $1.difficulty.rawValue }
        case .duration:
            challenges.sort { $0.duration.days < $1.duration.days }
        case .popularity:
            challenges.sort { $0.participantCount > $1.participantCount }
        case .reward:
            challenges.sort { $0.rewards.points > $1.rewards.points }
        case .endDate:
            challenges.sort { $0.endDate < $1.endDate }
        case .startDate:
            challenges.sort { $0.startDate < $1.startDate }
        case .alphabetical:
            challenges.sort { $0.name < $1.name }
        }
        
        state.filteredChallenges = challenges
    }
    
    @MainActor
    private func joinChallenge(_ challenge: Challenge) async {
        state.joinChallengeInProgress.insert(challenge.id)
        
        do {
            try await challengeService.joinChallenge(challenge, user: user)
            
            // Move challenge from available to active
            state.availableChallenges.removeAll { $0.id == challenge.id }
            state.activeChallenges.append(challenge)
            
            await filterAndSortChallenges()
            
            // Show success feedback
            await showSuccessFeedback(message: "Вы присоединились к вызову «\(challenge.name)»!")
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Joining challenge"))
        }
        
        state.joinChallengeInProgress.remove(challenge.id)
    }
    
    @MainActor
    private func leaveChallenge(_ challenge: Challenge) async {
        do {
            try await challengeService.leaveChallenge(challenge, user: user)
            
            // Move challenge from active to available
            state.activeChallenges.removeAll { $0.id == challenge.id }
            state.availableChallenges.append(challenge)
            
            await filterAndSortChallenges()
            
            // Show success feedback
            await showSuccessFeedback(message: "Вы покинули вызов «\(challenge.name)»")
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Leaving challenge"))
        }
    }
    
    @MainActor
    private func resetFilters() async {
        state.selectedFilter = .all
        state.selectedDifficulty = nil
        state.selectedCategory = nil
        state.searchText = ""
        state.showingFilters = false
        
        await filterAndSortChallenges()
    }
    
    @MainActor
    private func shareChallenge(_ challenge: Challenge) async {
        let shareText = """
        Присоединяйтесь к вызову в планировщике привычек!
        
        🏆 \(challenge.name)
        📝 \(challenge.description)
        ⚡ Сложность: \(challenge.difficulty.localizedName)
        🎯 Награда: \(challenge.rewards.points) очков
        ⏰ До: \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))
        
        Давайте развиваться вместе!
        """
        
        // This would trigger the share sheet
        #if DEBUG
        print("Sharing challenge: \(shareText)")
        #endif
    }
    
    @MainActor
    private func reportChallenge(_ challenge: Challenge) async {
        // This would open a report dialog
        #if DEBUG
        print("Reporting challenge: \(challenge.name)")
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

enum ChallengeTab: CaseIterable, Hashable {
    case available
    case active
    case completed
    case all
    
    var title: String {
        switch self {
        case .available:
            return "Доступные"
        case .active:
            return "Активные"
        case .completed:
            return "Завершенные"
        case .all:
            return "Все"
        }
    }
    
    var icon: String {
        switch self {
        case .available:
            return "flag"
        case .active:
            return "flame"
        case .completed:
            return "checkmark.circle"
        case .all:
            return "list.bullet"
        }
    }
}

enum ChallengeFilter: CaseIterable, Hashable {
    case all
    case today
    case thisWeek
    case personal
    case community
    case competitive
    case expiringSoon
    
    var title: String {
        switch self {
        case .all:
            return "Все"
        case .today:
            return "Сегодня"
        case .thisWeek:
            return "На этой неделе"
        case .personal:
            return "Личные"
        case .community:
            return "Сообщество"
        case .competitive:
            return "Соревновательные"
        case .expiringSoon:
            return "Заканчиваются"
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "flag"
        case .today:
            return "calendar"
        case .thisWeek:
            return "calendar.badge.clock"
        case .personal:
            return "person"
        case .community:
            return "person.2"
        case .competitive:
            return "trophy"
        case .expiringSoon:
            return "clock"
        }
    }
}

enum ChallengeSort: CaseIterable, Hashable {
    case difficulty
    case duration
    case popularity
    case reward
    case endDate
    case startDate
    case alphabetical
    
    var title: String {
        switch self {
        case .difficulty:
            return "По сложности"
        case .duration:
            return "По продолжительности"
        case .popularity:
            return "По популярности"
        case .reward:
            return "По награде"
        case .endDate:
            return "По дате окончания"
        case .startDate:
            return "По дате начала"
        case .alphabetical:
            return "По алфавиту"
        }
    }
    
    var icon: String {
        switch self {
        case .difficulty:
            return "chart.bar"
        case .duration:
            return "clock"
        case .popularity:
            return "person.3"
        case .reward:
            return "star"
        case .endDate:
            return "calendar.badge.minus"
        case .startDate:
            return "calendar.badge.plus"
        case .alphabetical:
            return "textformat.abc"
        }
    }
}

// MARK: - Extensions

extension ChallengesListViewModel {
    
    /// Получает статистику вызовов
    var challengeStats: ChallengeStats {
        let total = state.availableChallenges.count + state.activeChallenges.count + state.completedChallenges.count
        let active = state.activeChallenges.count
        let completed = state.completedChallenges.count
        
        let totalPoints = state.completedChallenges.reduce(0) { $0 + $1.rewards.points }
        
        let completionRate = total > 0 ? Double(completed) / Double(total) : 0.0
        
        return ChallengeStats(
            total: total,
            available: state.availableChallenges.count,
            active: active,
            completed: completed,
            completionRate: completionRate,
            totalPointsEarned: totalPoints
        )
    }
    
    /// Получает количество активных фильтров
    var activeFiltersCount: Int {
        var count = 0
        
        if state.selectedFilter != .all { count += 1 }
        if state.selectedDifficulty != nil { count += 1 }
        if state.selectedCategory != nil { count += 1 }
        if !state.searchText.isEmpty { count += 1 }
        
        return count
    }
    
    /// Проверяет, есть ли вызовы для отображения
    var hasChallenges: Bool {
        !state.availableChallenges.isEmpty || !state.activeChallenges.isEmpty || !state.completedChallenges.isEmpty
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        !state.isLoading && state.filteredChallenges.isEmpty
    }
    
    /// Получает сообщение для пустого состояния
    var emptyStateMessage: String {
        if !state.searchText.isEmpty {
            return "Вызовы не найдены"
        } else if activeFiltersCount > 0 {
            return "Нет вызовов с выбранными фильтрами"
        } else {
            switch state.selectedTab {
            case .available:
                return "Нет доступных вызовов"
            case .active:
                return "Нет активных вызовов"
            case .completed:
                return "Нет завершенных вызовов"
            case .all:
                return "Нет вызовов"
            }
        }
    }
    
    /// Получает текущие активные вызовы
    var currentActiveChallenges: [Challenge] {
        state.activeChallenges.filter { $0.startDate <= Date() && $0.endDate >= Date() }
    }
    
    /// Получает вызовы, которые скоро заканчиваются
    var expiringSoonChallenges: [Challenge] {
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return state.activeChallenges.filter { 
            $0.endDate <= threeDaysFromNow && $0.endDate >= Date()
        }
    }
    
    /// Проверяет, участвует ли пользователь в вызове
    func isParticipating(in challenge: Challenge) -> Bool {
        return state.activeChallenges.contains { $0.id == challenge.id }
    }
    
    /// Проверяет, выполняется ли присоединение к вызову
    func isJoining(challenge: Challenge) -> Bool {
        return state.joinChallengeInProgress.contains(challenge.id)
    }
}

struct ChallengeStats {
    let total: Int
    let available: Int
    let active: Int
    let completed: Int
    let completionRate: Double
    let totalPointsEarned: Int
} 