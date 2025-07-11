import SwiftUI

// MARK: - Project Sidebar View

struct ProjectSidebarView: View {
    let projects: [Project]
    let selectedProject: Project?
    let onProjectSelected: (Project) -> Void
    
    // UI State
    @State private var searchText = ""
    @State private var selectedFilter: ProjectFilter = .all
    @State private var groupBy: ProjectGrouping = .status
    @State private var showingFilters = false
    
    // Filtered and grouped projects
    private var filteredProjects: [Project] {
        var filtered = projects
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText) ||
                (project.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                project.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .planning:
            filtered = filtered.filter { $0.status == .planning }
        case .completed:
            filtered = filtered.filter { $0.status == .completed }
        case .overdue:
            filtered = filtered.filter { $0.isOverdue }
        case .highPriority:
            filtered = filtered.filter { $0.priority == .high }
        case .recent:
            let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            filtered = filtered.filter { $0.updatedAt > oneWeekAgo }
        }
        
        return filtered
    }
    
    private var groupedProjects: [(String, [Project])] {
        let grouped: [String: [Project]]
        
        switch groupBy {
        case .status:
            grouped = Dictionary(grouping: filteredProjects) { $0.status.displayName }
        case .priority:
            grouped = Dictionary(grouping: filteredProjects) { $0.priority.displayName }
        case .recent:
            grouped = Dictionary(grouping: filteredProjects) { project in
                let calendar = Calendar.current
                if calendar.isDateInToday(project.updatedAt) {
                    return "Сегодня"
                } else if calendar.isDateInYesterday(project.updatedAt) {
                    return "Вчера"
                } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(project.updatedAt) == true {
                    return "На этой неделе"
                } else {
                    return "Ранее"
                }
            }
        case .none:
            return [("Все проекты", filteredProjects)]
        }
        
        return grouped.sorted { lhs, rhs in
            let order = groupBy.sortOrder
            guard let lhsIndex = order.firstIndex(of: lhs.key),
                  let rhsIndex = order.firstIndex(of: rhs.key) else {
                return lhs.key < rhs.key
            }
            return lhsIndex < rhsIndex
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filters
            SearchFilterHeader()
            
            // Projects List
            ProjectsList()
            
            // Sidebar Footer
            SidebarFooter()
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Search and Filter Header
    
    @ViewBuilder
    private func SearchFilterHeader() -> some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Поиск проектов...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
            
            // Filter and Group Controls
            HStack {
                // Filter Picker
                Menu {
                    ForEach(ProjectFilter.allCases, id: \.self) { filter in
                        Button(filter.displayName) {
                            selectedFilter = filter
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedFilter.iconName)
                        Text(selectedFilter.displayName)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(selectedFilter != .all ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    )
                    .foregroundStyle(selectedFilter != .all ? .blue : .primary)
                }
                
                Spacer()
                
                // Group By Picker
                Menu {
                    ForEach(ProjectGrouping.allCases, id: \.self) { grouping in
                        Button(grouping.displayName) {
                            groupBy = grouping
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.3.group")
                        Text(groupBy.displayName)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                    .foregroundStyle(.primary)
                }
            }
            
            // Active Filters Indicator
            if selectedFilter != .all || !searchText.isEmpty {
                ActiveFiltersIndicator()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    @ViewBuilder
    private func ActiveFiltersIndicator() -> some View {
        HStack {
            Text("Активные фильтры:")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if selectedFilter != .all {
                FilterChip(text: selectedFilter.displayName) {
                    selectedFilter = .all
                }
            }
            
            if !searchText.isEmpty {
                FilterChip(text: "«\(searchText)»") {
                    searchText = ""
                }
            }
            
            Spacer()
            
            Button("Сбросить") {
                selectedFilter = .all
                searchText = ""
            }
            .font(.caption2)
            .foregroundStyle(.blue)
        }
    }
    
    // MARK: - Projects List
    
    @ViewBuilder
    private func ProjectsList() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if groupedProjects.isEmpty {
                    EmptyProjectsView()
                } else {
                    ForEach(groupedProjects, id: \.0) { groupName, groupProjects in
                        ProjectGroupView(
                            groupName: groupName,
                            projects: groupProjects,
                            selectedProject: selectedProject,
                            onProjectSelected: onProjectSelected
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Sidebar Footer
    
    @ViewBuilder
    private func SidebarFooter() -> some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Text("\(filteredProjects.count) из \(projects.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Quick Stats
                if !projects.isEmpty {
                    let completedCount = projects.filter { $0.status == .completed }.count
                    let completionRate = Double(completedCount) / Double(projects.count)
                    
                    Text("\(Int(completionRate * 100))% завершено")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Quick Actions
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "plus.circle",
                    title: "Новый",
                    color: .blue
                ) {
                    // Create new project
                }
                
                QuickActionButton(
                    icon: "doc.text",
                    title: "Шаблон",
                    color: .purple
                ) {
                    // Create from template
                }
                
                QuickActionButton(
                    icon: "square.and.arrow.down",
                    title: "Импорт",
                    color: .green
                ) {
                    // Import project
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Project Group View

private struct ProjectGroupView: View {
    let groupName: String
    let projects: [Project]
    let selectedProject: Project?
    let onProjectSelected: (Project) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(groupName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("(\(projects.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // Group Projects
            if isExpanded {
                LazyVStack(spacing: 6) {
                    ForEach(projects) { project in
                        ProjectRowView(
                            project: project,
                            isSelected: selectedProject?.id == project.id,
                            onSelect: { onProjectSelected(project) }
                        )
                    }
                }
                .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Project Row View

private struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Project Icon
                RoundedRectangle(cornerRadius: 6)
                    .fill(project.color?.color ?? .blue)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: project.icon ?? "folder.fill")
                            .foregroundStyle(.white)
                            .font(.caption)
                    }
                
                // Project Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        // Status Indicator
                        Circle()
                            .fill(project.status.color)
                            .frame(width: 6, height: 6)
                        
                        Text(project.status.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Progress
                        Text("\(Int(project.progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Indicators
                VStack(alignment: .trailing, spacing: 2) {
                    if project.isOverdue {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                    }
                    
                    if project.priority == .high {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                    }
                    
                    if let dueDate = project.targetEndDate {
                        Text(dueDate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

private struct EmptyProjectsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Проекты не найдены")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Попробуйте изменить фильтры поиска или создайте новый проект")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Создать проект") {
                // Create new project action
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct FilterChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption2)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.2))
        )
        .foregroundStyle(.blue)
    }
}

private struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Types

enum ProjectFilter: CaseIterable {
    case all, active, planning, completed, overdue, highPriority, recent
    
    var displayName: String {
        switch self {
        case .all: return "Все"
        case .active: return "Активные"
        case .planning: return "Планирование"
        case .completed: return "Завершенные"
        case .overdue: return "Просроченные"
        case .highPriority: return "Высокий приоритет"
        case .recent: return "Недавние"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "folder"
        case .active: return "play.circle"
        case .planning: return "clock"
        case .completed: return "checkmark.circle"
        case .overdue: return "exclamationmark.triangle"
        case .highPriority: return "arrow.up.circle"
        case .recent: return "clock.arrow.circlepath"
        }
    }
}

enum ProjectGrouping: CaseIterable {
    case none, status, priority, recent
    
    var displayName: String {
        switch self {
        case .none: return "Без группировки"
        case .status: return "По статусу"
        case .priority: return "По приоритету"
        case .recent: return "По времени"
        }
    }
    
    var sortOrder: [String] {
        switch self {
        case .status:
            return ["Планирование", "Активный", "Приостановлен", "Завершен", "Отменен"]
        case .priority:
            return ["Высокий", "Средний", "Низкий"]
        case .recent:
            return ["Сегодня", "Вчера", "На этой неделе", "Ранее"]
        case .none:
            return []
        }
    }
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

// MARK: - Preview

#Preview {
    NavigationView {
        ProjectSidebarView(
            projects: Project.sampleData,
            selectedProject: nil,
            onProjectSelected: { _ in }
        )
        .frame(width: 280)
        
        Text("Выберите проект")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
    }
} 