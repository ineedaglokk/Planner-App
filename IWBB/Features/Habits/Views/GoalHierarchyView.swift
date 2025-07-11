import SwiftUI
import Charts

// MARK: - GoalHierarchyView

struct GoalHierarchyView: View {
    @Environment(\.services) private var services
    @State private var viewModel: GoalHierarchyViewModel
    
    // UI State
    @State private var showingCreateGoal = false
    @State private var showingGoalDetails = false
    @State private var showingAnalytics = false
    
    init() {
        let services = ServiceContainer()
        _viewModel = State(initialValue: GoalHierarchyViewModel(
            dataService: services.dataService,
            templateService: services.templateService,
            projectManagementService: services.projectManagementService
        ))
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with Goals Tree
            GoalsSidebarView()
        } detail: {
            // Main Content
            if let selectedGoal = viewModel.selectedGoal {
                GoalDetailView(goal: selectedGoal)
            } else {
                GoalsOverviewView()
            }
        }
        .navigationTitle("Цели")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button("Создать цель", systemImage: "plus") {
                        showingCreateGoal = true
                    }
                    
                    Button("Из шаблона", systemImage: "doc.text") {
                        viewModel.showingGoalTemplates = true
                    }
                    
                    Divider()
                    
                    Button("Аналитика", systemImage: "chart.bar") {
                        showingAnalytics = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                
                Button(action: { Task { await viewModel.refreshData() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await viewModel.loadGoals()
        }
        .sheet(isPresented: $showingCreateGoal) {
            CreateGoalSheet()
        }
        .sheet(isPresented: $showingAnalytics) {
            GoalAnalyticsSheet()
        }
        .environmentObject(viewModel)
    }
    
    // MARK: - Goals Sidebar
    
    @ViewBuilder
    private func GoalsSidebarView() -> some View {
        VStack(spacing: 0) {
            // View Mode Picker
            ViewModePicker()
            
            // Search and Filters
            GoalsSearchBar()
            
            // Goals Content
            if viewModel.isLoading {
                ProgressView("Загрузка целей...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.goalTree.isEmpty {
                EmptyGoalsView()
            } else {
                GoalsTreeView()
            }
        }
    }
    
    // MARK: - Goals Overview
    
    @ViewBuilder
    private func GoalsOverviewView() -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Goals Metrics
                GoalMetricsSection()
                
                // Progress Trends
                ProgressTrendsSection()
                
                // Upcoming Reviews
                UpcomingReviewsSection()
                
                // Quick Actions
                GoalQuickActionsSection()
            }
            .padding()
        }
    }
}

// MARK: - View Mode Picker

private struct ViewModePicker: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    
    var body: some View {
        Picker("Режим просмотра", selection: $viewModel.viewMode) {
            ForEach(GoalViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
}

// MARK: - Goals Search Bar

private struct GoalsSearchBar: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    @State private var showingFilters = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Поиск целей...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            // Active Filters
            if viewModel.selectedTimeframe != nil || viewModel.selectedStatus != nil {
                ActiveFiltersView()
            }
            
            // Filter Button
            Button(action: { showingFilters.toggle() }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Фильтры")
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingFilters) {
            GoalFiltersSheet()
        }
    }
}

// MARK: - Active Filters View

private struct ActiveFiltersView: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let timeframe = viewModel.selectedTimeframe {
                    FilterChip(text: timeframe.displayName) {
                        viewModel.selectedTimeframe = nil
                    }
                }
                
                if let status = viewModel.selectedStatus {
                    FilterChip(text: status.displayName) {
                        viewModel.selectedStatus = nil
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.2))
        )
        .foregroundStyle(.blue)
    }
}

// MARK: - Goals Tree View

private struct GoalsTreeView: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.goalTree) { node in
                    GoalNodeView(node: node)
                        .id(node.id)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Goal Node View

private struct GoalNodeView: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    let node: GoalNode
    
    var body: some View {
        VStack(spacing: 0) {
            // Goal Row
            HStack(spacing: 12) {
                // Indentation for hierarchy
                if node.level > 0 {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: CGFloat(node.level * 20))
                }
                
                // Expand/Collapse Button
                if !node.goal.childGoals.isEmpty {
                    Button(action: {
                        viewModel.toggleExpansion(for: node.goal)
                    }) {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 16)
                }
                
                // Goal Content
                GoalRowContent(goal: node.goal)
                
                Spacer()
                
                // Goal Actions
                GoalActionsMenu(goal: node.goal)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedGoal?.id == node.goal.id ? 
                          Color.blue.opacity(0.1) : Color(.systemBackground))
            )
            .onTapGesture {
                viewModel.selectGoal(node.goal)
            }
        }
    }
}

// MARK: - Goal Row Content

private struct GoalRowContent: View {
    let goal: GoalHierarchy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and Status
            HStack {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                GoalStatusBadge(status: goal.status)
            }
            
            // Progress Bar
            ProgressView(value: goal.progress)
                .tint(goal.status.color)
            
            // Metadata
            HStack {
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let targetDate = goal.targetDate {
                    Text(targetDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(goal.isOverdue ? .red : .secondary)
                }
                
                GoalTimeframeBadge(timeframe: goal.timeframe)
            }
            
            // Key Results (for OKR)
            if !goal.keyResults.isEmpty {
                KeyResultsPreview(keyResults: goal.keyResults)
            }
        }
    }
}

// MARK: - Goal Status Badge

private struct GoalStatusBadge: View {
    let status: GoalStatus
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Goal Timeframe Badge

private struct GoalTimeframeBadge: View {
    let timeframe: GoalTimeframe
    
    var body: some View {
        Text(timeframe.shortName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(timeframe.color.opacity(0.2))
            )
            .foregroundStyle(timeframe.color)
    }
}

// MARK: - Key Results Preview

private struct KeyResultsPreview: View {
    let keyResults: [KeyResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(keyResults.prefix(3)) { keyResult in
                HStack {
                    Circle()
                        .fill(keyResult.isCompleted ? .green : .orange)
                        .frame(width: 4, height: 4)
                    
                    Text(keyResult.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(Int(keyResult.progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            if keyResults.count > 3 {
                Text("и еще \(keyResults.count - 3)...")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Goal Actions Menu

private struct GoalActionsMenu: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    let goal: GoalHierarchy
    
    var body: some View {
        Menu {
            Button("Редактировать", systemImage: "pencil") {
                viewModel.selectedGoal = goal
            }
            
            Button("Добавить подцель", systemImage: "plus") {
                Task { 
                    await viewModel.createGoal(
                        title: "Новая подцель",
                        description: "",
                        timeframe: .shortTerm,
                        parent: goal
                    )
                }
            }
            
            if !goal.keyResults.isEmpty {
                Button("Управлять KR", systemImage: "target") {
                    // Show key results management
                }
            }
            
            Button("Создать проект", systemImage: "folder") {
                Task { await viewModel.createProjectFromGoal(goal) }
            }
            
            Divider()
            
            Button("Удалить", systemImage: "trash", role: .destructive) {
                Task { await viewModel.deleteGoal(goal) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Goal Metrics Section

private struct GoalMetricsSection: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Обзор целей")
                .font(.title2)
                .fontWeight(.bold)
            
            if let metrics = viewModel.goalMetrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    GoalMetricCard(
                        title: "Всего целей",
                        value: "\(metrics.totalGoals)",
                        icon: "target",
                        color: .blue
                    )
                    
                    GoalMetricCard(
                        title: "Завершено",
                        value: "\(metrics.completedGoals)",
                        subtitle: "\(Int(metrics.completionRate * 100))%",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    GoalMetricCard(
                        title: "В работе",
                        value: "\(metrics.inProgressGoals)",
                        icon: "clock.fill",
                        color: .orange
                    )
                }
                
                // Key Results Metrics
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    GoalMetricCard(
                        title: "Ключевые результаты",
                        value: "\(metrics.totalKeyResults)",
                        subtitle: "Всего",
                        icon: "key.fill",
                        color: .purple
                    )
                    
                    GoalMetricCard(
                        title: "Завершенные KR",
                        value: "\(metrics.completedKeyResults)",
                        subtitle: "\(Int(metrics.completionRate * 100))%",
                        icon: "key.fill",
                        color: .green
                    )
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

// MARK: - Goal Metric Card

private struct GoalMetricCard: View {
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
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
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

// MARK: - Progress Trends Section

private struct ProgressTrendsSection: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Динамика прогресса")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.progressTrends.isEmpty {
                Chart(viewModel.progressTrends, id: \.date) { trend in
                    LineMark(
                        x: .value("Дата", trend.date),
                        y: .value("Прогресс", trend.progress)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Дата", trend.date),
                        y: .value("Прогресс", trend.progress)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let progress = value.as(Double.self) {
                                Text("\(Int(progress * 100))%")
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                Text("Недостаточно данных для отображения трендов")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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

// MARK: - Upcoming Reviews Section

private struct UpcomingReviewsSection: View {
    @EnvironmentObject private var viewModel: GoalHierarchyViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Предстоящие ревью")
                .font(.title2)
                .fontWeight(.bold)
            
            if viewModel.upcomingReviews.isEmpty {
                Text("Нет запланированных ревью")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.upcomingReviews) { review in
                        ReviewRowView(review: review)
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

// MARK: - Review Row View

private struct ReviewRowView: View {
    let review: ReviewItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.circle")
                .foregroundStyle(review.isOverdue ? .red : .blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(review.goalTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Ревью \(review.reviewType.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(review.reviewDate, style: .relative)
                .font(.caption)
                .foregroundStyle(review.isOverdue ? .red : .secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(review.isOverdue ? Color.red.opacity(0.1) : Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Extensions

extension GoalStatus {
    var displayName: String {
        switch self {
        case .draft: return "Черновик"
        case .active: return "Активная"
        case .inProgress: return "В работе"
        case .completed: return "Завершена"
        case .onHold: return "Приостановлена"
        case .cancelled: return "Отменена"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .active: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .onHold: return .yellow
        case .cancelled: return .red
        }
    }
}

extension GoalTimeframe {
    var displayName: String {
        switch self {
        case .immediate: return "Немедленно"
        case .shortTerm: return "Краткосрочная"
        case .mediumTerm: return "Среднесрочная"
        case .longTerm: return "Долгосрочная"
        }
    }
    
    var shortName: String {
        switch self {
        case .immediate: return "Сейчас"
        case .shortTerm: return "КС"
        case .mediumTerm: return "СС"
        case .longTerm: return "ДС"
        }
    }
    
    var color: Color {
        switch self {
        case .immediate: return .red
        case .shortTerm: return .orange
        case .mediumTerm: return .blue
        case .longTerm: return .purple
        }
    }
}

extension ReviewFrequency {
    var displayName: String {
        switch self {
        case .weekly: return "еженедельно"
        case .monthly: return "ежемесячно"
        case .quarterly: return "ежеквартально"
        case .yearly: return "ежегодно"
        case .custom: return "по расписанию"
        }
    }
}

// MARK: - Empty Views and Placeholders

private struct EmptyGoalsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Нет целей")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text("Создайте свою первую цель, чтобы начать достигать результатов")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Создать цель") {
                // Create goal action
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    GoalHierarchyView()
        .environment(\.services, ServiceContainer.preview())
} 