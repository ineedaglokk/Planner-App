import Foundation
import SwiftUI

// MARK: - ProjectDashboardViewModel

@Observable
final class ProjectDashboardViewModel {
    
    // MARK: - Properties
    
    private let projectManagementService: ProjectManagementServiceProtocol
    private let templateService: TemplateServiceProtocol
    private let timeBlockingService: TimeBlockingServiceProtocol
    
    // State
    var projects: [Project] = []
    var filteredProjects: [Project] = []
    var selectedProject: Project?
    var projectMetrics: ProjectMetrics?
    var projectInsights: [ProjectInsight] = []
    
    // Filters and sorting
    var searchText: String = "" {
        didSet { applyFilters() }
    }
    var selectedFilter: ProjectFilter = .all {
        didSet { applyFilters() }
    }
    var sortOrder: ProjectSortOrder = .priority {
        didSet { applySorting() }
    }
    
    // UI State
    var isLoading: Bool = false
    var isLoadingMetrics: Bool = false
    var error: AppError?
    var showingCreateProject: Bool = false
    var showingProjectTemplates: Bool = false
    
    // Templates
    var availableTemplates: [ProjectTemplate] = []
    var recommendedTemplates: [ProjectTemplate] = []
    
    // Analytics
    var overallMetrics: DashboardMetrics?
    var workloadDistribution: [WorkloadInfo] = []
    var upcomingDeadlines: [DeadlineItem] = []
    
    // MARK: - Initialization
    
    init(
        projectManagementService: ProjectManagementServiceProtocol,
        templateService: TemplateServiceProtocol,
        timeBlockingService: TimeBlockingServiceProtocol
    ) {
        self.projectManagementService = projectManagementService
        self.templateService = templateService
        self.timeBlockingService = timeBlockingService
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadProjects() async {
        isLoading = true
        error = nil
        
        do {
            async let activeProjects = projectManagementService.getActiveProjects()
            async let templates = templateService.getRecommendedTemplates(for: nil)
            async let overallMetrics = calculateOverallMetrics()
            
            projects = try await activeProjects
            recommendedTemplates = try await templates
            self.overallMetrics = try await overallMetrics
            
            applyFilters()
            await loadUpcomingDeadlines()
            await loadWorkloadDistribution()
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func selectProject(_ project: Project) async {
        selectedProject = project
        await loadProjectMetrics(for: project)
        await loadProjectInsights(for: project)
    }
    
    @MainActor
    func createProjectFromTemplate(_ template: ProjectTemplate) async {
        do {
            let newProject = try await projectManagementService.createProject(from: template)
            projects.append(newProject)
            applyFilters()
            selectedProject = newProject
            await loadProjectMetrics(for: newProject)
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func createEmptyProject(name: String, description: String) async {
        do {
            let newProject = try await projectManagementService.createProject(from: nil)
            newProject.name = name
            newProject.description = description
            try await projectManagementService.updateProject(newProject)
            
            projects.append(newProject)
            applyFilters()
            selectedProject = newProject
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func updateProject(_ project: Project) async {
        do {
            try await projectManagementService.updateProject(project)
            
            // Обновляем проект в локальном массиве
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = project
                applyFilters()
            }
            
            // Перезагружаем метрики если это выбранный проект
            if selectedProject?.id == project.id {
                await loadProjectMetrics(for: project)
                await loadProjectInsights(for: project)
            }
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func deleteProject(_ project: Project) async {
        do {
            try await projectManagementService.deleteProject(project)
            projects.removeAll { $0.id == project.id }
            applyFilters()
            
            if selectedProject?.id == project.id {
                selectedProject = nil
                projectMetrics = nil
                projectInsights = []
            }
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func archiveProject(_ project: Project) async {
        do {
            try await projectManagementService.archiveProject(project)
            projects.removeAll { $0.id == project.id }
            applyFilters()
            
            if selectedProject?.id == project.id {
                selectedProject = nil
                projectMetrics = nil
                projectInsights = []
            }
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    func refreshData() async {
        await loadProjects()
        if let selectedProject = selectedProject {
            await loadProjectMetrics(for: selectedProject)
            await loadProjectInsights(for: selectedProject)
        }
    }
    
    // MARK: - Private Methods
    
    private func applyFilters() {
        var filtered = projects
        
        // Применяем текстовый поиск
        if !searchText.isEmpty {
            filtered = filtered.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText) ||
                project.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Применяем фильтры
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .planning:
            filtered = filtered.filter { $0.status == .planning }
        case .onHold:
            filtered = filtered.filter { $0.status == .onHold }
        case .overdue:
            filtered = filtered.filter { $0.isOverdue }
        case .highPriority:
            filtered = filtered.filter { $0.priority == .high }
        case .dueThisWeek:
            let weekFromNow = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
            filtered = filtered.filter { project in
                guard let dueDate = project.targetEndDate else { return false }
                return dueDate <= weekFromNow
            }
        }
        
        filteredProjects = filtered
        applySorting()
    }
    
    private func applySorting() {
        switch sortOrder {
        case .name:
            filteredProjects.sort { $0.name < $1.name }
        case .priority:
            filteredProjects.sort { $0.priority.rawValue > $1.priority.rawValue }
        case .progress:
            filteredProjects.sort { $0.progress > $1.progress }
        case .dueDate:
            filteredProjects.sort { project1, project2 in
                guard let date1 = project1.targetEndDate else { return false }
                guard let date2 = project2.targetEndDate else { return true }
                return date1 < date2
            }
        case .created:
            filteredProjects.sort { $0.createdAt > $1.createdAt }
        case .updated:
            filteredProjects.sort { $0.updatedAt > $1.updatedAt }
        }
    }
    
    @MainActor
    private func loadProjectMetrics(for project: Project) async {
        isLoadingMetrics = true
        
        do {
            projectMetrics = try await projectManagementService.getProjectMetrics(project)
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoadingMetrics = false
    }
    
    @MainActor
    private func loadProjectInsights(for project: Project) async {
        do {
            projectInsights = try await projectManagementService.getProjectInsights(project)
        } catch {
            // Insights не критичны, просто логируем ошибку
            print("Failed to load project insights: \(error)")
        }
    }
    
    private func calculateOverallMetrics() async throws -> DashboardMetrics {
        let allProjects = try await projectManagementService.getAllProjects()
        let activeProjects = allProjects.filter { !$0.isArchived }
        
        let totalProjects = activeProjects.count
        let completedProjects = activeProjects.filter { $0.status == .completed }.count
        let overdueProjects = activeProjects.filter { $0.isOverdue }.count
        let onTrackProjects = activeProjects.filter { $0.isOnTrack }.count
        
        let averageProgress = activeProjects.isEmpty ? 0.0 : 
            activeProjects.reduce(0.0) { $0 + $1.progress } / Double(activeProjects.count)
        
        let totalTasks = activeProjects.reduce(0) { $0 + $1.tasks.count }
        let completedTasks = activeProjects.reduce(0) { $0 + $1.completedTasksCount }
        
        return DashboardMetrics(
            totalProjects: totalProjects,
            completedProjects: completedProjects,
            overdueProjects: overdueProjects,
            onTrackProjects: onTrackProjects,
            averageProgress: averageProgress,
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            completionRate: totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        )
    }
    
    @MainActor
    private func loadUpcomingDeadlines() async {
        let weekFromNow = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        
        var deadlines: [DeadlineItem] = []
        
        for project in projects {
            // Добавляем дедлайн проекта
            if let projectDeadline = project.targetEndDate, projectDeadline <= weekFromNow {
                deadlines.append(DeadlineItem(
                    id: project.id,
                    title: project.name,
                    type: .project,
                    deadline: projectDeadline,
                    priority: project.priority,
                    isOverdue: projectDeadline < Date()
                ))
            }
            
            // Добавляем важные вехи
            for milestone in project.milestones {
                if milestone.targetDate <= weekFromNow && !milestone.isCompleted {
                    deadlines.append(DeadlineItem(
                        id: milestone.id,
                        title: milestone.title,
                        type: .milestone,
                        deadline: milestone.targetDate,
                        priority: project.priority,
                        isOverdue: milestone.targetDate < Date()
                    ))
                }
            }
            
            // Добавляем критические задачи
            for task in project.tasks {
                if let taskDeadline = task.dueDate, 
                   taskDeadline <= weekFromNow && 
                   !task.isCompleted && 
                   task.priority.rawValue >= Priority.high.rawValue {
                    deadlines.append(DeadlineItem(
                        id: task.id,
                        title: task.title,
                        type: .task,
                        deadline: taskDeadline,
                        priority: task.priority,
                        isOverdue: taskDeadline < Date()
                    ))
                }
            }
        }
        
        upcomingDeadlines = deadlines.sorted { $0.deadline < $1.deadline }
    }
    
    @MainActor
    private func loadWorkloadDistribution() async {
        do {
            let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
            workloadDistribution = try await timeBlockingService.calculateWorkload(for: startOfWeek)
        } catch {
            print("Failed to load workload distribution: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum ProjectFilter: String, CaseIterable {
    case all = "Все"
    case active = "Активные"
    case planning = "Планирование"
    case onHold = "Приостановлен"
    case overdue = "Просрочен"
    case highPriority = "Высокий приоритет"
    case dueThisWeek = "Срок на неделе"
}

enum ProjectSortOrder: String, CaseIterable {
    case name = "По названию"
    case priority = "По приоритету"
    case progress = "По прогрессу"
    case dueDate = "По сроку"
    case created = "По дате создания"
    case updated = "По обновлению"
}

struct DashboardMetrics {
    let totalProjects: Int
    let completedProjects: Int
    let overdueProjects: Int
    let onTrackProjects: Int
    let averageProgress: Double
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double
}

struct DeadlineItem: Identifiable {
    let id: UUID
    let title: String
    let type: DeadlineType
    let deadline: Date
    let priority: Priority
    let isOverdue: Bool
}

enum DeadlineType {
    case project
    case milestone
    case task
    
    var iconName: String {
        switch self {
        case .project: return "folder"
        case .milestone: return "flag"
        case .task: return "checkmark.circle"
        }
    }
} 