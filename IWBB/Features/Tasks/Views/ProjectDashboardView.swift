import SwiftUI
import Charts

// MARK: - ProjectDashboardView

struct ProjectDashboardView: View {
    @Environment(\.services) private var services
    @State private var viewModel: ProjectDashboardViewModel
    
    // UI State
    @State private var selectedTab: DashboardTab = .overview
    @State private var showingFilters = false
    @State private var showingCreateProject = false
    
    init() {
        let services = ServiceContainer()
        _viewModel = State(initialValue: ProjectDashboardViewModel(
            projectManagementService: services.projectManagementService,
            templateService: services.templateService,
            timeBlockingService: services.timeBlockingService
        ))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            ProjectSidebarView(
                projects: viewModel.filteredProjects,
                selectedProject: viewModel.selectedProject,
                onProjectSelected: { project in
                    Task { await viewModel.selectProject(project) }
                }
            )
            .navigationTitle("Проекты")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateProject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            // Main Content
            TabView(selection: $selectedTab) {
                OverviewTabView()
                    .tabItem {
                        Label("Обзор", systemImage: "chart.bar.fill")
                    }
                    .tag(DashboardTab.overview)
                
                ProjectsListTabView()
                    .tabItem {
                        Label("Проекты", systemImage: "folder.fill")
                    }
                    .tag(DashboardTab.projects)
                
                AnalyticsTabView()
                    .tabItem {
                        Label("Аналитика", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(DashboardTab.analytics)
                
                TemplatesTabView()
                    .tabItem {
                        Label("Шаблоны", systemImage: "doc.text.fill")
                    }
                    .tag(DashboardTab.templates)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    
                    Button(action: { Task { await viewModel.refreshData() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await viewModel.loadProjects()
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectSheet()
        }
        .sheet(isPresented: $showingFilters) {
            FiltersSheet()
        }
        .alert("Ошибка", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Tab Views
    
    @ViewBuilder
    private func OverviewTabView() -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Dashboard Metrics
                DashboardMetricsSection()
                
                // Quick Actions
                QuickActionsSection()
                
                // Recent Projects
                RecentProjectsSection()
                
                // Upcoming Deadlines
                UpcomingDeadlinesSection()
                
                // Workload Distribution
                WorkloadDistributionSection()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func ProjectsListTabView() -> some View {
        VStack(spacing: 0) {
            // Search and Filters Bar
            ProjectsFilterBar()
            
            // Projects List
            if viewModel.isLoading {
                ProgressView("Загрузка проектов...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredProjects.isEmpty {
                EmptyProjectsView()
            } else {
                ProjectsGridView()
            }
        }
    }
    
    @ViewBuilder
    private func AnalyticsTabView() -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if let metrics = viewModel.overallMetrics {
                    // Overall Performance Chart
                    ProjectPerformanceChart(metrics: metrics)
                    
                    // Progress Trends
                    ProgressTrendsChart()
                    
                    // Project Completion Rate
                    CompletionRateChart()
                    
                    // Time Distribution
                    TimeDistributionChart()
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func TemplatesTabView() -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Recommended Templates
                RecommendedTemplatesSection()
                
                // Popular Templates
                PopularTemplatesSection()
                
                // My Templates
                MyTemplatesSection()
            }
            .padding()
        }
    }
}

// MARK: - Dashboard Metrics Section

private struct DashboardMetricsSection: View {
    @Environment(\.services) private var services
    @EnvironmentObject private var viewModel: ProjectDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Обзор проектов")
                .font(.title2)
                .fontWeight(.bold)
            
            if let metrics = viewModel.overallMetrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    MetricCard(
                        title: "Всего проектов",
                        value: "\(metrics.totalProjects)",
                        icon: "folder.fill",
                        color: .blue
                    )
                    
                    MetricCard(
                        title: "Завершено",
                        value: "\(metrics.completedProjects)",
                        subtitle: "\(Int(metrics.completionRate * 100))%",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    MetricCard(
                        title: "В работе",
                        value: "\(metrics.onTrackProjects)",
                        icon: "clock.fill",
                        color: .orange
                    )
                    
                    MetricCard(
                        title: "Просрочено",
                        value: "\(metrics.overdueProjects)",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            } else {
                MetricsSkeleton()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Metric Card

private struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    
    init(title: String, value: String, subtitle: String? = nil, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Quick Actions Section

private struct QuickActionsSection: View {
    @EnvironmentObject private var viewModel: ProjectDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Быстрые действия")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                QuickActionButton(
                    title: "Новый проект",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    viewModel.showingCreateProject = true
                }
                
                QuickActionButton(
                    title: "Из шаблона",
                    icon: "doc.text.fill",
                    color: .purple
                ) {
                    viewModel.showingProjectTemplates = true
                }
                
                QuickActionButton(
                    title: "Импорт",
                    icon: "square.and.arrow.down.fill",
                    color: .green
                ) {
                    // Import project action
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Projects Section

private struct RecentProjectsSection: View {
    @EnvironmentObject private var viewModel: ProjectDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Недавние проекты")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Все проекты") {
                    // Show all projects
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.filteredProjects.prefix(5))) { project in
                    ProjectRowView(project: project) {
                        Task { await viewModel.selectProject(project) }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Project Row View

private struct ProjectRowView: View {
    let project: Project
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Project Icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(project.color?.color ?? .blue)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: project.icon ?? "folder.fill")
                            .foregroundStyle(.white)
                            .font(.title3)
                    }
                
                // Project Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if let description = project.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Progress and Status
                    HStack {
                        ProgressView(value: project.progress)
                            .frame(width: 80)
                        
                        Text("\(Int(project.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        ProjectStatusBadge(status: project.status)
                    }
                }
                
                Spacer()
                
                // Due Date
                if let dueDate = project.targetEndDate {
                    VStack(alignment: .trailing) {
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if project.isOverdue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Status Badge

private struct ProjectStatusBadge: View {
    let status: ProjectStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(status.color.opacity(0.2))
            )
            .foregroundStyle(status.color)
    }
}

// MARK: - Upcoming Deadlines Section

private struct UpcomingDeadlinesSection: View {
    @EnvironmentObject private var viewModel: ProjectDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ближайшие дедлайны")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.upcomingDeadlines.isEmpty {
                Text("Нет ближайших дедлайнов")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.upcomingDeadlines) { deadline in
                        DeadlineRowView(deadline: deadline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .primary.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Deadline Row View

private struct DeadlineRowView: View {
    let deadline: DeadlineItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: deadline.type.iconName)
                .foregroundStyle(deadline.isOverdue ? .red : .orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(deadline.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text(deadline.deadline, style: .relative)
                    .font(.caption)
                    .foregroundStyle(deadline.isOverdue ? .red : .secondary)
            }
            
            Spacer()
            
            PriorityBadge(priority: deadline.priority)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(deadline.isOverdue ? Color.red.opacity(0.1) : Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Supporting Views and Extensions

private struct MetricsSkeleton: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 100)
                    .redacted(reason: .placeholder)
            }
        }
    }
}

private struct PriorityBadge: View {
    let priority: Priority
    
    var body: some View {
        Circle()
            .fill(priority.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Dashboard Tab Enum

private enum DashboardTab: String, CaseIterable {
    case overview = "overview"
    case projects = "projects"
    case analytics = "analytics"
    case templates = "templates"
}

// MARK: - Extensions

extension ProjectStatus {
    var displayName: String {
        switch self {
        case .planning: return "Планирование"
        case .active: return "Активный"
        case .onHold: return "Приостановлен"
        case .completed: return "Завершен"
        case .cancelled: return "Отменен"
        }
    }
    
    var color: Color {
        switch self {
        case .planning: return .blue
        case .active: return .green
        case .onHold: return .orange
        case .completed: return .green
        case .cancelled: return .red
        }
    }
}

extension Priority {
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ProjectDashboardView()
        .environment(\.services, ServiceContainer.preview())
} 