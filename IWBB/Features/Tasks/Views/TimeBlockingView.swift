import SwiftUI
import Charts
import EventKit

// MARK: - TimeBlockingView

struct TimeBlockingView: View {
    @Environment(\.services) private var services
    @State private var viewModel: TimeBlockingViewModel
    
    // UI State
    @State private var selectedHour: Int?
    @State private var showingTaskPicker = false
    @State private var showingCalendarSync = false
    
    init() {
        let services = ServiceContainer()
        _viewModel = State(initialValue: TimeBlockingViewModel(
            timeBlockingService: services.timeBlockingService,
            projectManagementService: services.projectManagementService,
            taskService: services.taskService
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with Date Picker and View Mode
                TimeBlockingHeaderView()
                
                // Main Content based on view mode
                switch viewModel.viewMode {
                case .day:
                    DayTimelineView()
                case .week:
                    WeekScheduleView()
                case .workload:
                    WorkloadAnalysisView()
                }
            }
            .navigationTitle("Time Blocking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if viewModel.isCalendarSyncEnabled {
                        Button(action: { Task { await viewModel.syncWithCalendar() } }) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                        }
                    } else {
                        Button(action: { showingCalendarSync = true }) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Button(action: { Task { await viewModel.optimizeSchedule() } }) {
                        Image(systemName: "sparkles")
                    }
                    
                    Button(action: { viewModel.showingCreateTimeBlock = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.initialize()
            }
            .sheet(isPresented: $viewModel.showingCreateTimeBlock) {
                CreateTimeBlockSheet()
            }
            .sheet(isPresented: $viewModel.showingTaskPicker) {
                TaskPickerSheet()
            }
            .sheet(isPresented: $showingCalendarSync) {
                CalendarSyncSheet()
            }
            .sheet(isPresented: $viewModel.showingOptimizationSuggestions) {
                OptimizationSuggestionsSheet()
            }
            .alert("Ошибка", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Time Blocking Header

private struct TimeBlockingHeaderView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // View Mode Selector
            Picker("Режим просмотра", selection: $viewModel.viewMode) {
                ForEach(TimeBlockViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Date Navigation
            if viewModel.viewMode == .day {
                DayNavigationView()
            } else if viewModel.viewMode == .week {
                WeekNavigationView()
            }
            
            // Workload Indicator
            if let workload = viewModel.workloadInfo {
                WorkloadIndicatorView(workload: workload)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Day Navigation

private struct DayNavigationView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        HStack {
            Button(action: {
                let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                viewModel.selectedDate = previousDay
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            
            Spacer()
            
            DatePicker(
                "Выбрать дату",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            
            Spacer()
            
            Button(action: {
                let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                viewModel.selectedDate = nextDay
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
    }
}

// MARK: - Week Navigation

private struct WeekNavigationView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        HStack {
            Button(action: {
                let previousWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: viewModel.selectedWeek) ?? viewModel.selectedWeek
                viewModel.selectedWeek = previousWeek
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            
            Spacer()
            
            VStack {
                Text("Неделя")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: viewModel.selectedWeek) {
                    Text("\(weekInterval.start, formatter: DateFormatter.dayMonth) - \(weekInterval.end, formatter: DateFormatter.dayMonth)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            Button(action: {
                let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: viewModel.selectedWeek) ?? viewModel.selectedWeek
                viewModel.selectedWeek = nextWeek
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
    }
}

// MARK: - Workload Indicator

private struct WorkloadIndicatorView: View {
    let workload: WorkloadInfo
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Загрузка")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ProgressView(value: workload.utilizationRate)
                        .frame(width: 80)
                        .tint(workload.statusColor)
                    
                    Text("\(workload.utilizationPercentage)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(workload.statusColor)
                }
            }
            
            Text(workload.statusText)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(workload.statusColor.opacity(0.2))
                )
                .foregroundStyle(workload.statusColor)
            
            Spacer()
        }
    }
}

// MARK: - Day Timeline View

private struct DayTimelineView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.getWorkingHours(), id: \.self) { hour in
                    TimelineHourView(hour: hour)
                        .id(hour)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Timeline Hour View

private struct TimelineHourView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    let hour: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Hour Header
            HStack {
                Text("\(hour):00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }
            .padding(.horizontal)
            
            // Time Blocks for this hour
            let timeBlocks = viewModel.getTimeBlocksForHour(hour)
            
            if timeBlocks.isEmpty {
                // Empty slot - can drop here
                EmptyTimeSlotView(hour: hour)
            } else {
                ForEach(timeBlocks) { timeBlock in
                    TimeBlockCardView(timeBlock: timeBlock)
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                }
            }
        }
        .frame(minHeight: 60)
    }
}

// MARK: - Empty Time Slot

private struct EmptyTimeSlotView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    let hour: Int
    
    var body: some View {
        Rectangle()
            .fill(viewModel.dragOverColumn != nil ? Color.blue.opacity(0.1) : Color.clear)
            .frame(height: 60)
            .overlay {
                if viewModel.dragOverColumn == nil {
                    Button(action: {
                        let calendar = Calendar.current
                        let startTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: viewModel.selectedDate) ?? Date()
                        viewModel.newTimeBlockStartTime = startTime
                        viewModel.showingCreateTimeBlock = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                            Text("Добавить блок")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDrop(of: [.text], isTargeted: nil) { providers in
                // Handle drop here
                return true
            }
    }
}

// MARK: - Time Block Card

private struct TimeBlockCardView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    let timeBlock: TimeBlock
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(timeBlock.startDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timeBlock.endDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(timeBlock.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let task = timeBlock.task {
                        TaskPriorityIndicator(priority: task.priority)
                    }
                }
                
                if let task = timeBlock.task {
                    Text(task.project?.name ?? "Задача")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let project = timeBlock.project {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(timeBlock.timeRange)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    Text("\(Int(timeBlock.durationInHours * 10) / 10)ч")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Actions
            Menu {
                Button("Редактировать", systemImage: "pencil") {
                    showingDetails = true
                }
                
                Button("Переместить", systemImage: "arrow.up.arrow.down") {
                    // Show time picker for rescheduling
                }
                
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    Task { await viewModel.deleteTimeBlock(timeBlock) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(timeBlock.task?.priority.color.opacity(0.1) ?? Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(timeBlock.task?.priority.color ?? .blue, lineWidth: 1)
                )
        )
        .onDrag {
            viewModel.startDragging(timeBlock)
            return NSItemProvider(object: timeBlock.id.uuidString as NSString)
        }
        .sheet(isPresented: $showingDetails) {
            TimeBlockDetailSheet(timeBlock: timeBlock)
        }
    }
}

// MARK: - Task Priority Indicator

private struct TaskPriorityIndicator: View {
    let priority: Priority
    
    var body: some View {
        Circle()
            .fill(priority.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Week Schedule View

private struct WeekScheduleView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Week Overview Chart
                WeekOverviewChart()
                
                // Daily Workload Cards
                if !viewModel.weeklyWorkload.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(viewModel.weeklyWorkload, id: \.date) { workload in
                            DailyWorkloadCard(workload: workload)
                        }
                    }
                }
                
                // Free Time Suggestions
                if !viewModel.freeTimeSlots.isEmpty {
                    FreeTimeSuggestionsSection()
                }
                
                // Pending Tasks for Auto-scheduling
                if !viewModel.pendingTasks.isEmpty {
                    PendingTasksSection()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Week Overview Chart

private struct WeekOverviewChart: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Недельная загрузка")
                .font(.title2)
                .fontWeight(.bold)
            
            if !viewModel.weeklyWorkload.isEmpty {
                Chart(viewModel.weeklyWorkload, id: \.date) { workload in
                    BarMark(
                        x: .value("День", workload.date, unit: .day),
                        y: .value("Загрузка", workload.utilizationRate)
                    )
                    .foregroundStyle(
                        workload.utilizationRate > 0.8 ? .red :
                        workload.utilizationRate > 0.5 ? .orange : .green
                    )
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let rate = value.as(Double.self) {
                                Text("\(Int(rate * 100))%")
                            }
                        }
                    }
                }
                .frame(height: 200)
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

// MARK: - Daily Workload Card

private struct DailyWorkloadCard: View {
    let workload: WorkloadInfo
    
    var body: some View {
        VStack(spacing: 8) {
            Text(workload.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            CircularProgressView(
                progress: workload.utilizationRate,
                color: workload.statusColor,
                size: 40
            )
            
            Text("\(workload.utilizationPercentage)%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(workload.statusColor)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(workload.statusColor.opacity(0.1))
        )
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Free Time Suggestions Section

private struct FreeTimeSuggestionsSection: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Свободное время")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.freeTimeSlots.prefix(5)) { slot in
                    FreeTimeSlotCard(slot: slot)
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

// MARK: - Free Time Slot Card

private struct FreeTimeSlotCard: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    let slot: TimeSlot
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(slot.startDate, style: .time) - \(slot.endDate, style: .time)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(slot.duration / 3600))ч \(Int((slot.duration.truncatingRemainder(dividingBy: 3600)) / 60))мин")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if slot.score > 0.7 {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
            
            Button("Заблокировать") {
                Task {
                    await viewModel.createTimeBlock(
                        startTime: slot.startDate,
                        duration: slot.duration
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Pending Tasks Section

private struct PendingTasksSection: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ожидающие планирования")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Запланировать все") {
                    Task { await viewModel.autoScheduleTasks(viewModel.pendingTasks) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.pendingTasks.prefix(5)) { task in
                    PendingTaskCard(task: task)
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

// MARK: - Pending Task Card

private struct PendingTaskCard: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    let task: ProjectTask
    
    var body: some View {
        HStack {
            TaskPriorityIndicator(priority: task.priority)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let project = task.project {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if let duration = task.estimatedDuration {
                Text("\(Int(duration / 3600))ч")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button("Найти время") {
                Task { await viewModel.findOptimalTimeSlots(for: task) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Workload Analysis View

private struct WorkloadAnalysisView: View {
    @EnvironmentObject private var viewModel: TimeBlockingViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Time Block Analytics
                if let analytics = viewModel.timeBlockAnalytics {
                    TimeBlockAnalyticsSection(analytics: analytics)
                }
                
                // Productivity Insights
                if !viewModel.productivityInsights.isEmpty {
                    ProductivityInsightsSection()
                }
                
                // Optimization Suggestions
                if !viewModel.optimizationSuggestions.isEmpty {
                    OptimizationSuggestionsSection()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Time Block Analytics Section

private struct TimeBlockAnalyticsSection: View {
    let analytics: TimeBlockAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Аналитика времени")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                AnalyticsCard(
                    title: "Всего блоков",
                    value: "\(analytics.totalBlocks)",
                    icon: "rectangle.3.group.fill",
                    color: .blue
                )
                
                AnalyticsCard(
                    title: "Ср. длительность",
                    value: "\(Int(analytics.averageDuration / 3600))ч",
                    icon: "clock.fill",
                    color: .orange
                )
            }
            
            if let productiveTime = analytics.mostProductiveTime {
                Text("Самое продуктивное время: \(productiveTime, style: .time)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

// MARK: - Analytics Card

private struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    TimeBlockingView()
        .environment(\.services, ServiceContainer.preview())
} 