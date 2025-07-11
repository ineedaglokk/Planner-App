import Foundation
import SwiftUI

// MARK: - AchievementsGalleryViewModel

@Observable
final class AchievementsGalleryViewModel {
    
    // MARK: - State
    
    struct State {
        var achievements: [Achievement] = []
        var filteredAchievements: [Achievement] = []
        var isLoading: Bool = false
        var isRefreshing: Bool = false
        var error: AppError?
        var searchText: String = ""
        var selectedFilter: AchievementFilter = .all
        var selectedSort: AchievementSort = .rarity
        var selectedRarity: AchievementRarity?
        var selectedCategory: AchievementCategory?
        var viewMode: ViewMode = .grid
        var showUnlockedOnly: Bool = false
        var showHiddenAchievements: Bool = false
        var selectedAchievement: Achievement?
        var showingAchievementDetail: Bool = false
        var showingFilters: Bool = false
        var animateNewUnlock: Achievement?
    }
    
    // MARK: - Input
    
    enum Input {
        case loadAchievements
        case refreshAchievements
        case searchTextChanged(String)
        case filterChanged(AchievementFilter)
        case sortChanged(AchievementSort)
        case rarityFilterChanged(AchievementRarity?)
        case categoryFilterChanged(AchievementCategory?)
        case viewModeChanged(ViewMode)
        case toggleUnlockedOnly
        case toggleHiddenAchievements
        case achievementTapped(Achievement)
        case showFilters
        case dismissFilters
        case resetFilters
        case dismissAchievementDetail
        case claimReward(Achievement)
        case shareAchievement(Achievement)
        case dismissError
    }
    
    // MARK: - Properties
    
    private(set) var state = State()
    
    // Dependencies
    private let achievementService: AchievementServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let user: User
    
    // MARK: - Initialization
    
    init(
        achievementService: AchievementServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol,
        user: User
    ) {
        self.achievementService = achievementService
        self.errorHandlingService = errorHandlingService
        self.user = user
    }
    
    // MARK: - Input Handling
    
    func send(_ input: Input) {
        Task { @MainActor in
            switch input {
            case .loadAchievements:
                await loadAchievements()
            case .refreshAchievements:
                await refreshAchievements()
            case .searchTextChanged(let text):
                state.searchText = text
                await filterAndSortAchievements()
            case .filterChanged(let filter):
                state.selectedFilter = filter
                await filterAndSortAchievements()
            case .sortChanged(let sort):
                state.selectedSort = sort
                await filterAndSortAchievements()
            case .rarityFilterChanged(let rarity):
                state.selectedRarity = rarity
                await filterAndSortAchievements()
            case .categoryFilterChanged(let category):
                state.selectedCategory = category
                await filterAndSortAchievements()
            case .viewModeChanged(let mode):
                state.viewMode = mode
            case .toggleUnlockedOnly:
                state.showUnlockedOnly.toggle()
                await filterAndSortAchievements()
            case .toggleHiddenAchievements:
                state.showHiddenAchievements.toggle()
                await filterAndSortAchievements()
            case .achievementTapped(let achievement):
                state.selectedAchievement = achievement
                state.showingAchievementDetail = true
            case .showFilters:
                state.showingFilters = true
            case .dismissFilters:
                state.showingFilters = false
            case .resetFilters:
                await resetFilters()
            case .dismissAchievementDetail:
                state.showingAchievementDetail = false
                state.selectedAchievement = nil
            case .claimReward(let achievement):
                await claimReward(achievement)
            case .shareAchievement(let achievement):
                await shareAchievement(achievement)
            case .dismissError:
                state.error = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func loadAchievements() async {
        state.isLoading = true
        state.error = nil
        
        do {
            let achievements = try await achievementService.getAllAchievements(for: user)
            state.achievements = achievements
            await filterAndSortAchievements()
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Loading achievements"))
        }
        
        state.isLoading = false
    }
    
    @MainActor
    private func refreshAchievements() async {
        state.isRefreshing = true
        
        do {
            let achievements = try await achievementService.getAllAchievements(for: user)
            
            // Check for new unlocks
            let newUnlocks = achievements.filter { newAchievement in
                let oldAchievement = state.achievements.first { $0.id == newAchievement.id }
                return newAchievement.isUnlockedForUser(user.id) && !(oldAchievement?.isUnlockedForUser(user.id) ?? false)
            }
            
            state.achievements = achievements
            await filterAndSortAchievements()
            
            // Animate new unlocks
            if let newUnlock = newUnlocks.first {
                state.animateNewUnlock = newUnlock
                
                // Reset animation after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.state.animateNewUnlock = nil
                }
            }
            
            state.error = nil
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .data("Refreshing achievements"))
        }
        
        state.isRefreshing = false
    }
    
    @MainActor
    private func filterAndSortAchievements() async {
        var filtered = state.achievements
        
        // Apply search filter
        if !state.searchText.isEmpty {
            filtered = filtered.filter { achievement in
                achievement.title.localizedCaseInsensitiveContains(state.searchText) ||
                achievement.description.localizedCaseInsensitiveContains(state.searchText)
            }
        }
        
        // Apply main filter
        switch state.selectedFilter {
        case .all:
            break
        case .unlocked:
            filtered = filtered.filter { $0.isUnlockedForUser(user.id) }
        case .locked:
            filtered = filtered.filter { !$0.isUnlockedForUser(user.id) }
        case .inProgress:
            filtered = filtered.filter { achievement in
                guard let progress = achievement.progressForUser(user.id) else { return false }
                return progress.currentProgress > 0 && !progress.isUnlocked
            }
        case .recent:
            filtered = filtered.filter { achievement in
                guard let unlockedAt = achievement.unlockedAt else { return false }
                return Calendar.current.isDateInToday(unlockedAt) ||
                       Calendar.current.isDate(unlockedAt, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            }
        }
        
        // Apply rarity filter
        if let rarity = state.selectedRarity {
            filtered = filtered.filter { $0.rarity == rarity }
        }
        
        // Apply category filter
        if let category = state.selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Apply unlocked only filter
        if state.showUnlockedOnly {
            filtered = filtered.filter { $0.isUnlockedForUser(user.id) }
        }
        
        // Apply hidden achievements filter
        if !state.showHiddenAchievements {
            filtered = filtered.filter { !$0.isHidden }
        }
        
        // Apply sorting
        switch state.selectedSort {
        case .rarity:
            filtered.sort { $0.rarity.pointsMultiplier > $1.rarity.pointsMultiplier }
        case .points:
            filtered.sort { $0.points > $1.points }
        case .progress:
            filtered.sort { first, second in
                let firstProgress = first.progressForUser(user.id)?.progressPercentage ?? 0
                let secondProgress = second.progressForUser(user.id)?.progressPercentage ?? 0
                return firstProgress > secondProgress
            }
        case .category:
            filtered.sort { $0.category.localizedName < $1.category.localizedName }
        case .alphabetical:
            filtered.sort { $0.title < $1.title }
        case .dateUnlocked:
            filtered.sort { first, second in
                let firstDate = first.unlockedAt ?? Date.distantPast
                let secondDate = second.unlockedAt ?? Date.distantPast
                return firstDate > secondDate
            }
        }
        
        state.filteredAchievements = filtered
    }
    
    @MainActor
    private func resetFilters() async {
        state.selectedFilter = .all
        state.selectedRarity = nil
        state.selectedCategory = nil
        state.showUnlockedOnly = false
        state.showHiddenAchievements = false
        state.searchText = ""
        state.showingFilters = false
        
        await filterAndSortAchievements()
    }
    
    @MainActor
    private func claimReward(_ achievement: Achievement) async {
        do {
            try await achievementService.claimReward(achievement, for: user)
            
            // Update local achievement
            if let index = state.achievements.firstIndex(where: { $0.id == achievement.id }) {
                // This would update the achievement's claimed status
                // For now, we'll just refresh the data
                await refreshAchievements()
            }
            
            // Show success feedback
            await showSuccessFeedback(message: "Награда получена!")
            
        } catch {
            state.error = AppError.from(error)
            await errorHandlingService.handle(state.error!, context: .user("Claiming achievement reward"))
        }
    }
    
    @MainActor
    private func shareAchievement(_ achievement: Achievement) async {
        let shareText = """
        Я получил достижение в планировщике привычек!
        
        🏆 \(achievement.title)
        📝 \(achievement.description)
        ⭐ \(achievement.rarity.localizedName)
        🎯 \(achievement.points) очков
        
        Присоединяйтесь к формированию полезных привычек!
        """
        
        // This would trigger the share sheet
        #if DEBUG
        print("Sharing achievement: \(shareText)")
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

enum AchievementFilter: CaseIterable, Hashable {
    case all
    case unlocked
    case locked
    case inProgress
    case recent
    
    var title: String {
        switch self {
        case .all:
            return "Все"
        case .unlocked:
            return "Разблокированные"
        case .locked:
            return "Заблокированные"
        case .inProgress:
            return "В процессе"
        case .recent:
            return "Недавние"
        }
    }
    
    var icon: String {
        switch self {
        case .all:
            return "star"
        case .unlocked:
            return "lock.open"
        case .locked:
            return "lock"
        case .inProgress:
            return "hourglass"
        case .recent:
            return "clock"
        }
    }
}

enum AchievementSort: CaseIterable, Hashable {
    case rarity
    case points
    case progress
    case category
    case alphabetical
    case dateUnlocked
    
    var title: String {
        switch self {
        case .rarity:
            return "По редкости"
        case .points:
            return "По очкам"
        case .progress:
            return "По прогрессу"
        case .category:
            return "По категории"
        case .alphabetical:
            return "По алфавиту"
        case .dateUnlocked:
            return "По дате разблокировки"
        }
    }
    
    var icon: String {
        switch self {
        case .rarity:
            return "diamond"
        case .points:
            return "star.fill"
        case .progress:
            return "chart.bar"
        case .category:
            return "folder"
        case .alphabetical:
            return "textformat.abc"
        case .dateUnlocked:
            return "calendar"
        }
    }
}

enum ViewMode: CaseIterable, Hashable {
    case grid
    case list
    
    var title: String {
        switch self {
        case .grid:
            return "Сетка"
        case .list:
            return "Список"
        }
    }
    
    var icon: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

// MARK: - Extensions

extension AchievementsGalleryViewModel {
    
    /// Получает статистику достижений
    var achievementStats: AchievementStats {
        let total = state.achievements.count
        let unlocked = state.achievements.filter { $0.isUnlockedForUser(user.id) }.count
        let inProgress = state.achievements.filter { achievement in
            guard let progress = achievement.progressForUser(user.id) else { return false }
            return progress.currentProgress > 0 && !progress.isUnlocked
        }.count
        
        let totalPoints = state.achievements
            .filter { $0.isUnlockedForUser(user.id) }
            .reduce(0) { $0 + $1.points }
        
        let rarityStats = Dictionary(grouping: state.achievements.filter { $0.isUnlockedForUser(user.id) }) { $0.rarity }
            .mapValues { $0.count }
        
        return AchievementStats(
            total: total,
            unlocked: unlocked,
            inProgress: inProgress,
            completionRate: total > 0 ? Double(unlocked) / Double(total) : 0.0,
            totalPoints: totalPoints,
            rarityStats: rarityStats
        )
    }
    
    /// Получает количество активных фильтров
    var activeFiltersCount: Int {
        var count = 0
        
        if state.selectedFilter != .all { count += 1 }
        if state.selectedRarity != nil { count += 1 }
        if state.selectedCategory != nil { count += 1 }
        if state.showUnlockedOnly { count += 1 }
        if state.showHiddenAchievements { count += 1 }
        if !state.searchText.isEmpty { count += 1 }
        
        return count
    }
    
    /// Проверяет, есть ли достижения для отображения
    var hasAchievements: Bool {
        !state.achievements.isEmpty
    }
    
    /// Проверяет, показывается ли пустое состояние
    var showEmptyState: Bool {
        !state.isLoading && state.filteredAchievements.isEmpty
    }
    
    /// Получает сообщение для пустого состояния
    var emptyStateMessage: String {
        if !state.searchText.isEmpty {
            return "Достижения не найдены"
        } else if activeFiltersCount > 0 {
            return "Нет достижений с выбранными фильтрами"
        } else {
            return "Достижения загружаются..."
        }
    }
    
    /// Получает прогресс ближайшего достижения
    var nextAchievementProgress: (achievement: Achievement, progress: Double)? {
        let inProgressAchievements = state.achievements.compactMap { achievement -> (Achievement, Double)? in
            guard let progress = achievement.progressForUser(user.id),
                  progress.currentProgress > 0 && !progress.isUnlocked else { return nil }
            return (achievement, progress.progressPercentage)
        }
        
        return inProgressAchievements.max { $0.1 < $1.1 }
    }
}

struct AchievementStats {
    let total: Int
    let unlocked: Int
    let inProgress: Int
    let completionRate: Double
    let totalPoints: Int
    let rarityStats: [AchievementRarity: Int]
} 