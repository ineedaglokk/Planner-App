import Foundation
import SwiftUI

// MARK: - GoalHierarchyViewModel

@Observable
final class GoalHierarchyViewModel {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let templateService: TemplateServiceProtocol
    private let projectManagementService: ProjectManagementServiceProtocol
    
    // State
    var rootGoals: [GoalHierarchy] = []
    var filteredGoals: [GoalHierarchy] = []
    var selectedGoal: GoalHierarchy?
    var goalTree: [GoalNode] = []
    
    // UI State
    var isLoading: Bool = false
    var error: AppError?
    var showingCreateGoal: Bool = false
    var showingGoalTemplates: Bool = false
    var expandedGoals: Set<UUID> = []
    
    // Search and filters
    var searchText: String = "" {
        didSet { applyFilters() }
    }
    var selectedTimeframe: GoalTimeframe? {
        didSet { applyFilters() }
    }
    var selectedStatus: GoalStatus? {
        didSet { applyFilters() }
    }
    var viewMode: GoalViewMode = .hierarchy {
        didSet { rebuildView() }
    }
    
    // Analytics
    var goalMetrics: GoalMetrics?
    var progressTrends: [ProgressTrend] = []
    var upcomingReviews: [ReviewItem] = []
    
    // Templates
    var availableTemplates: [ProjectTemplate] = []
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        templateService: TemplateServiceProtocol,
        projectManagementService: ProjectManagementServiceProtocol
    ) {
        self.dataService = dataService
        self.templateService = templateService
        self.projectManagementService = projectManagementService
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadGoals() async {
        isLoading = true
        error = nil
        
        do {
            rootGoals = try await dataService.fetch(GoalHierarchy.self, predicate: #Predicate<GoalHierarchy> { goal in
                goal.parentGoal == nil
            })
            
            // Загружаем дочерние цели для каждой корневой цели
            for rootGoal in rootGoals {
                try await loadChildGoals(for: rootGoal)
            }
            
            applyFilters()
            rebuildView()
            
            await loadGoalMetrics()
            await loadProgressTrends()
            await loadUpcomingReviews()
            await loadAvailableTemplates()
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func createGoal(
        title: String,
        description: String,
        timeframe: GoalTimeframe,
        parent: GoalHierarchy? = nil
    ) async {
        do {
            let newGoal = GoalHierarchy(
                title: title,
                description: description,
                timeframe: timeframe,
                parentGoal: parent
            )
            
            if let parent = parent {
                parent.addChildGoal(newGoal)
                try await updateGoal(parent)
            } else {
                rootGoals.append(newGoal)
            }
            
            try await dataService.save(newGoal)
            
            applyFilters()
            rebuildView()
            selectedGoal = newGoal
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func updateGoal(_ goal: GoalHierarchy) async {
        do {
            goal.updateTimestamp()
            try await dataService.update(goal)
            
            // Обновляем прогресс родительских целей
            if let parent = goal.parentGoal {
                try await updateParentProgress(parent)
            }
            
            applyFilters()
            rebuildView()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func deleteGoal(_ goal: GoalHierarchy) async {
        do {
            // Удаляем все дочерние цели
            for childGoal in goal.childGoals {
                try await deleteGoal(childGoal)
            }
            
            // Удаляем из родительской цели
            if let parent = goal.parentGoal {
                parent.removeChildGoal(goal)
                try await updateGoal(parent)
            } else {
                rootGoals.removeAll { $0.id == goal.id }
            }
            
            try await dataService.delete(goal)
            
            if selectedGoal?.id == goal.id {
                selectedGoal = nil
            }
            
            applyFilters()
            rebuildView()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func moveGoal(_ goal: GoalHierarchy, to newParent: GoalHierarchy?) async {
        do {
            // Удаляем из старого родителя
            if let oldParent = goal.parentGoal {
                oldParent.removeChildGoal(goal)
                try await updateGoal(oldParent)
            } else {
                rootGoals.removeAll { $0.id == goal.id }
            }
            
            // Добавляем к новому родителю
            goal.parentGoal = newParent
            if let newParent = newParent {
                newParent.addChildGoal(goal)
                try await updateGoal(newParent)
            } else {
                rootGoals.append(goal)
            }
            
            try await updateGoal(goal)
            
            applyFilters()
            rebuildView()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func addKeyResult(to goal: GoalHierarchy, title: String, targetValue: Double, metric: String) async {
        let keyResult = KeyResult(
            title: title,
            targetValue: targetValue,
            metric: metric
        )
        
        goal.addKeyResult(keyResult)
        await updateGoal(goal)
    }
    
    @MainActor
    func updateKeyResultProgress(_ keyResult: KeyResult, currentValue: Double) async {
        guard let goal = findGoalContaining(keyResult) else { return }
        
        keyResult.updateProgress(currentValue: currentValue)
        await updateGoal(goal)
    }
    
    @MainActor
    func createProjectFromGoal(_ goal: GoalHierarchy) async {
        do {
            // Ищем подходящие шаблоны для цели
            let templates = try await templateService.suggestTemplatesForGoal(goal)
            
            let project: Project
            if let template = templates.first {
                project = try await projectManagementService.createProject(from: template)
            } else {
                project = try await projectManagementService.createProject(from: nil)
            }
            
            project.name = goal.title
            project.description = goal.description
            goal.linkedProjectId = project.id
            
            try await projectManagementService.updateProject(project)
            await updateGoal(goal)
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    func toggleExpansion(for goal: GoalHierarchy) {
        if expandedGoals.contains(goal.id) {
            expandedGoals.remove(goal.id)
        } else {
            expandedGoals.insert(goal.id)
        }
        rebuildView()
    }
    
    func isExpanded(_ goal: GoalHierarchy) -> Bool {
        return expandedGoals.contains(goal.id)
    }
    
    func selectGoal(_ goal: GoalHierarchy) {
        selectedGoal = goal
    }
    
    func refreshData() async {
        await loadGoals()
    }
    
    // MARK: - Private Methods
    
    private func loadChildGoals(for goal: GoalHierarchy) async throws {
        let predicate = #Predicate<GoalHierarchy> { childGoal in
            childGoal.parentGoal?.id == goal.id
        }
        
        let childGoals = try await dataService.fetch(GoalHierarchy.self, predicate: predicate)
        
        for childGoal in childGoals {
            goal.addChildGoal(childGoal)
            try await loadChildGoals(for: childGoal)
        }
    }
    
    private func updateParentProgress(_ parent: GoalHierarchy) async throws {
        parent.updateProgressFromChildren()
        try await dataService.update(parent)
        
        if let grandparent = parent.parentGoal {
            try await updateParentProgress(grandparent)
        }
    }
    
    private func applyFilters() {
        var filtered = rootGoals
        
        // Текстовый поиск
        if !searchText.isEmpty {
            filtered = filtered.compactMap { goal in
                return filterGoalBySearch(goal, searchText: searchText)
            }
        }
        
        // Фильтр по временным рамкам
        if let timeframe = selectedTimeframe {
            filtered = filtered.compactMap { goal in
                return filterGoalByTimeframe(goal, timeframe: timeframe)
            }
        }
        
        // Фильтр по статусу
        if let status = selectedStatus {
            filtered = filtered.compactMap { goal in
                return filterGoalByStatus(goal, status: status)
            }
        }
        
        filteredGoals = filtered
    }
    
    private func filterGoalBySearch(_ goal: GoalHierarchy, searchText: String) -> GoalHierarchy? {
        let matchesSearch = goal.title.localizedCaseInsensitiveContains(searchText) ||
                           goal.description?.localizedCaseInsensitiveContains(searchText) == true
        
        let filteredChildren = goal.childGoals.compactMap { child in
            filterGoalBySearch(child, searchText: searchText)
        }
        
        if matchesSearch || !filteredChildren.isEmpty {
            let filteredGoal = goal.copy()
            filteredGoal.childGoals = filteredChildren
            return filteredGoal
        }
        
        return nil
    }
    
    private func filterGoalByTimeframe(_ goal: GoalHierarchy, timeframe: GoalTimeframe) -> GoalHierarchy? {
        let matchesTimeframe = goal.timeframe == timeframe
        
        let filteredChildren = goal.childGoals.compactMap { child in
            filterGoalByTimeframe(child, timeframe: timeframe)
        }
        
        if matchesTimeframe || !filteredChildren.isEmpty {
            let filteredGoal = goal.copy()
            filteredGoal.childGoals = filteredChildren
            return filteredGoal
        }
        
        return nil
    }
    
    private func filterGoalByStatus(_ goal: GoalHierarchy, status: GoalStatus) -> GoalHierarchy? {
        let matchesStatus = goal.status == status
        
        let filteredChildren = goal.childGoals.compactMap { child in
            filterGoalByStatus(child, status: status)
        }
        
        if matchesStatus || !filteredChildren.isEmpty {
            let filteredGoal = goal.copy()
            filteredGoal.childGoals = filteredChildren
            return filteredGoal
        }
        
        return nil
    }
    
    private func rebuildView() {
        switch viewMode {
        case .hierarchy:
            goalTree = buildGoalTree(from: filteredGoals, level: 0)
        case .flat:
            goalTree = buildFlatGoalList(from: filteredGoals)
        case .timeline:
            goalTree = buildTimelineView(from: filteredGoals)
        }
    }
    
    private func buildGoalTree(from goals: [GoalHierarchy], level: Int) -> [GoalNode] {
        var nodes: [GoalNode] = []
        
        for goal in goals.sorted(by: { $0.priority.rawValue > $1.priority.rawValue }) {
            let node = GoalNode(
                goal: goal,
                level: level,
                isExpanded: isExpanded(goal)
            )
            nodes.append(node)
            
            if isExpanded(goal) {
                let childNodes = buildGoalTree(from: goal.childGoals, level: level + 1)
                nodes.append(contentsOf: childNodes)
            }
        }
        
        return nodes
    }
    
    private func buildFlatGoalList(from goals: [GoalHierarchy]) -> [GoalNode] {
        var nodes: [GoalNode] = []
        
        func addGoalsRecursively(_ goals: [GoalHierarchy]) {
            for goal in goals {
                nodes.append(GoalNode(goal: goal, level: 0, isExpanded: false))
                addGoalsRecursively(goal.childGoals)
            }
        }
        
        addGoalsRecursively(goals)
        return nodes.sorted { $0.goal.priority.rawValue > $1.goal.priority.rawValue }
    }
    
    private func buildTimelineView(from goals: [GoalHierarchy]) -> [GoalNode] {
        var nodes: [GoalNode] = []
        
        func addGoalsRecursively(_ goals: [GoalHierarchy]) {
            for goal in goals {
                nodes.append(GoalNode(goal: goal, level: 0, isExpanded: false))
                addGoalsRecursively(goal.childGoals)
            }
        }
        
        addGoalsRecursively(goals)
        
        // Сортируем по временным рамкам и дедлайнам
        return nodes.sorted { node1, node2 in
            let timeframeOrder1 = node1.goal.timeframe.sortOrder
            let timeframeOrder2 = node2.goal.timeframe.sortOrder
            
            if timeframeOrder1 != timeframeOrder2 {
                return timeframeOrder1 < timeframeOrder2
            }
            
            // Если временные рамки одинаковые, сортируем по дедлайну
            if let deadline1 = node1.goal.targetDate, let deadline2 = node2.goal.targetDate {
                return deadline1 < deadline2
            }
            
            return node1.goal.createdAt < node2.goal.createdAt
        }
    }
    
    private func findGoalContaining(_ keyResult: KeyResult) -> GoalHierarchy? {
        func searchInGoal(_ goal: GoalHierarchy) -> GoalHierarchy? {
            if goal.keyResults.contains(where: { $0.id == keyResult.id }) {
                return goal
            }
            
            for childGoal in goal.childGoals {
                if let found = searchInGoal(childGoal) {
                    return found
                }
            }
            
            return nil
        }
        
        for rootGoal in rootGoals {
            if let found = searchInGoal(rootGoal) {
                return found
            }
        }
        
        return nil
    }
    
    @MainActor
    private func loadGoalMetrics() async {
        let allGoals = getAllGoals(from: rootGoals)
        
        let totalGoals = allGoals.count
        let completedGoals = allGoals.filter { $0.status == .completed }.count
        let inProgressGoals = allGoals.filter { $0.status == .inProgress }.count
        let overdueGoals = allGoals.filter { $0.isOverdue }.count
        
        let averageProgress = allGoals.isEmpty ? 0.0 :
            allGoals.reduce(0.0) { $0 + $1.progress } / Double(allGoals.count)
        
        let totalKeyResults = allGoals.reduce(0) { $0 + $1.keyResults.count }
        let completedKeyResults = allGoals.reduce(0) { $0 + $1.keyResults.filter { $0.isCompleted }.count }
        
        goalMetrics = GoalMetrics(
            totalGoals: totalGoals,
            completedGoals: completedGoals,
            inProgressGoals: inProgressGoals,
            overdueGoals: overdueGoals,
            averageProgress: averageProgress,
            totalKeyResults: totalKeyResults,
            completedKeyResults: completedKeyResults,
            completionRate: totalKeyResults > 0 ? Double(completedKeyResults) / Double(totalKeyResults) : 0.0
        )
    }
    
    @MainActor
    private func loadProgressTrends() async {
        // Загружаем данные о прогрессе за последние 30 дней
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        var trends: [ProgressTrend] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            let progressSnapshot = calculateProgressSnapshot(for: currentDate)
            trends.append(ProgressTrend(date: currentDate, progress: progressSnapshot))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        progressTrends = trends
    }
    
    @MainActor
    private func loadUpcomingReviews() async {
        let weekFromNow = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        let allGoals = getAllGoals(from: rootGoals)
        
        var reviews: [ReviewItem] = []
        
        for goal in allGoals {
            if let nextReview = goal.nextReviewDate, nextReview <= weekFromNow {
                reviews.append(ReviewItem(
                    goalId: goal.id,
                    goalTitle: goal.title,
                    reviewDate: nextReview,
                    reviewType: goal.reviewFrequency,
                    isOverdue: nextReview < Date()
                ))
            }
        }
        
        upcomingReviews = reviews.sorted { $0.reviewDate < $1.reviewDate }
    }
    
    @MainActor
    private func loadAvailableTemplates() async {
        do {
            availableTemplates = try await templateService.getRecommendedTemplates(for: .planning)
        } catch {
            print("Failed to load templates: \(error)")
        }
    }
    
    private func getAllGoals(from goals: [GoalHierarchy]) -> [GoalHierarchy] {
        var allGoals: [GoalHierarchy] = []
        
        for goal in goals {
            allGoals.append(goal)
            allGoals.append(contentsOf: getAllGoals(from: goal.childGoals))
        }
        
        return allGoals
    }
    
    private func calculateProgressSnapshot(for date: Date) -> Double {
        let allGoals = getAllGoals(from: rootGoals)
        
        // Для упрощения, используем текущий прогресс
        // В реальном приложении здесь была бы историческая база данных
        let activeGoals = allGoals.filter { $0.createdAt <= date }
        
        return activeGoals.isEmpty ? 0.0 :
            activeGoals.reduce(0.0) { $0 + $1.progress } / Double(activeGoals.count)
    }
}

// MARK: - Supporting Types

enum GoalViewMode: String, CaseIterable {
    case hierarchy = "Иерархия"
    case flat = "Список"
    case timeline = "Временная шкала"
}

struct GoalNode: Identifiable {
    let id = UUID()
    let goal: GoalHierarchy
    let level: Int
    let isExpanded: Bool
}

struct GoalMetrics {
    let totalGoals: Int
    let completedGoals: Int
    let inProgressGoals: Int
    let overdueGoals: Int
    let averageProgress: Double
    let totalKeyResults: Int
    let completedKeyResults: Int
    let completionRate: Double
}

struct ProgressTrend {
    let date: Date
    let progress: Double
}

struct ReviewItem: Identifiable {
    let id = UUID()
    let goalId: UUID
    let goalTitle: String
    let reviewDate: Date
    let reviewType: ReviewFrequency
    let isOverdue: Bool
}

extension GoalTimeframe {
    var sortOrder: Int {
        switch self {
        case .immediate: return 0
        case .shortTerm: return 1
        case .mediumTerm: return 2
        case .longTerm: return 3
        }
    }
} 