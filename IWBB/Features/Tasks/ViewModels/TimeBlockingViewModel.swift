import Foundation
import SwiftUI
import EventKit

// MARK: - TimeBlockingViewModel

@Observable
final class TimeBlockingViewModel {
    
    // MARK: - Properties
    
    private let timeBlockingService: TimeBlockingServiceProtocol
    private let projectManagementService: ProjectManagementServiceProtocol
    private let taskService: TaskServiceProtocol
    
    // State
    var timeBlocks: [TimeBlock] = []
    var selectedDate: Date = Date() {
        didSet { loadTimeBlocks() }
    }
    var selectedTimeBlock: TimeBlock?
    var selectedWeek: Date = Date() {
        didSet { loadWeeklyData() }
    }
    
    // Calendar state
    var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    var isCalendarSyncEnabled: Bool = false
    
    // View modes
    var viewMode: TimeBlockViewMode = .day {
        didSet { 
            switch viewMode {
            case .day:
                loadTimeBlocks()
            case .week:
                loadWeeklyData()
            case .workload:
                loadWorkloadAnalysis()
            }
        }
    }
    
    // UI State
    var isLoading: Bool = false
    var error: AppError?
    var showingCreateTimeBlock: Bool = false
    var showingTaskPicker: Bool = false
    var showingOptimizationSuggestions: Bool = false
    
    // Time block creation
    var newTimeBlockTitle: String = ""
    var newTimeBlockStartTime: Date = Date()
    var newTimeBlockDuration: TimeInterval = 3600 // 1 час
    var selectedTask: ProjectTask?
    var selectedProject: Project?
    
    // Analytics
    var workloadInfo: WorkloadInfo?
    var weeklyWorkload: [WorkloadInfo] = []
    var optimizationSuggestions: [ScheduleOptimization] = []
    var productivityInsights: [ProductivityInsight] = []
    var timeBlockAnalytics: TimeBlockAnalytics?
    
    // Free time slots
    var suggestedTimeSlots: [TimeSlot] = []
    var freeTimeSlots: [TimeSlot] = []
    
    // Auto-scheduling
    var pendingTasks: [ProjectTask] = []
    var schedulingPreferences: SchedulingPreferences = .default
    
    // MARK: - Initialization
    
    init(
        timeBlockingService: TimeBlockingServiceProtocol,
        projectManagementService: ProjectManagementServiceProtocol,
        taskService: TaskServiceProtocol
    ) {
        self.timeBlockingService = timeBlockingService
        self.projectManagementService = projectManagementService
        self.taskService = taskService
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func initialize() async {
        await checkCalendarAuthorization()
        await loadTimeBlocks()
        await loadWorkloadInfo()
        await loadPendingTasks()
    }
    
    @MainActor
    func loadTimeBlocks() async {
        isLoading = true
        error = nil
        
        do {
            timeBlocks = try await timeBlockingService.getTimeBlocks(for: selectedDate)
            await loadFreeTimeSlots()
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadWeeklyData() async {
        isLoading = true
        error = nil
        
        do {
            let calendar = Calendar.current
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedWeek) else {
                throw AppError.validation("Invalid week date")
            }
            
            timeBlocks = try await timeBlockingService.getTimeBlocks(for: weekInterval)
            weeklyWorkload = try await timeBlockingService.calculateWorkload(for: selectedWeek)
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadWorkloadAnalysis() async {
        isLoading = true
        error = nil
        
        do {
            let period = DateInterval(start: selectedWeek, duration: 7 * 24 * 3600)
            timeBlockAnalytics = try await timeBlockingService.getTimeBlockAnalytics(for: period)
            
            // Загружаем insights для текущего пользователя
            // productivityInsights = try await timeBlockingService.getProductivityInsights(for: currentUser)
            
        } catch {
            self.error = AppError.from(error)
        }
        
        isLoading = false
    }
    
    @MainActor
    func createTimeBlock(
        title: String? = nil,
        startTime: Date? = nil,
        duration: TimeInterval? = nil,
        task: ProjectTask? = nil,
        project: Project? = nil
    ) async {
        do {
            let blockTitle = title ?? newTimeBlockTitle
            let blockStartTime = startTime ?? newTimeBlockStartTime
            let blockDuration = duration ?? newTimeBlockDuration
            
            let timeBlock: TimeBlock
            if let task = task ?? selectedTask {
                timeBlock = try await timeBlockingService.createTimeBlock(
                    for: task,
                    duration: blockDuration,
                    preferredDate: blockStartTime
                )
            } else if let project = project ?? selectedProject {
                timeBlock = try await timeBlockingService.createTimeBlock(
                    for: project,
                    duration: blockDuration,
                    preferredDate: blockStartTime
                )
            } else {
                timeBlock = try await timeBlockingService.createTimeBlock(
                    for: nil,
                    duration: blockDuration,
                    preferredDate: blockStartTime
                )
                timeBlock.title = blockTitle
                try await timeBlockingService.updateTimeBlock(timeBlock)
            }
            
            timeBlocks.append(timeBlock)
            timeBlocks.sort { $0.startDate < $1.startDate }
            
            // Очищаем форму
            resetCreateForm()
            
            // Обновляем связанные данные
            await loadWorkloadInfo()
            await loadFreeTimeSlots()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func updateTimeBlock(_ timeBlock: TimeBlock) async {
        do {
            try await timeBlockingService.updateTimeBlock(timeBlock)
            
            // Обновляем локальную копию
            if let index = timeBlocks.firstIndex(where: { $0.id == timeBlock.id }) {
                timeBlocks[index] = timeBlock
            }
            
            await loadWorkloadInfo()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func deleteTimeBlock(_ timeBlock: TimeBlock) async {
        do {
            try await timeBlockingService.deleteTimeBlock(timeBlock)
            timeBlocks.removeAll { $0.id == timeBlock.id }
            
            if selectedTimeBlock?.id == timeBlock.id {
                selectedTimeBlock = nil
            }
            
            await loadWorkloadInfo()
            await loadFreeTimeSlots()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func rescheduleTimeBlock(_ timeBlock: TimeBlock, to newDate: Date) async {
        do {
            try await timeBlockingService.rescheduleTimeBlock(timeBlock, to: newDate)
            
            // Обновляем локальную копию
            if let index = timeBlocks.firstIndex(where: { $0.id == timeBlock.id }) {
                timeBlocks[index] = timeBlock
                timeBlocks.sort { $0.startDate < $1.startDate }
            }
            
            await loadWorkloadInfo()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func findOptimalTimeSlots(for task: ProjectTask) async {
        do {
            suggestedTimeSlots = try await timeBlockingService.suggestOptimalTimeSlots(for: task)
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func findOptimalTimeSlots(
        duration: TimeInterval,
        energyLevel: EnergyLevel? = nil,
        timeOfDay: TimeOfDay? = nil
    ) async {
        do {
            suggestedTimeSlots = try await timeBlockingService.suggestOptimalTimeSlots(
                duration: duration,
                energyLevel: energyLevel,
                timeOfDay: timeOfDay
            )
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func optimizeSchedule() async {
        do {
            optimizationSuggestions = try await timeBlockingService.optimizeSchedule(for: selectedDate)
            showingOptimizationSuggestions = true
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func autoScheduleTasks(_ tasks: [ProjectTask]) async {
        do {
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedWeek)?.start ?? selectedWeek
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? startOfWeek
            let timeframe = DateInterval(start: startOfWeek, end: endOfWeek)
            
            let scheduledBlocks = try await timeBlockingService.autoScheduleTasks(
                tasks,
                within: timeframe,
                preferences: schedulingPreferences
            )
            
            timeBlocks.append(contentsOf: scheduledBlocks)
            timeBlocks.sort { $0.startDate < $1.startDate }
            
            await loadWorkloadInfo()
            
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func syncWithCalendar() async {
        guard calendarAuthorizationStatus == .authorized else {
            await requestCalendarAccess()
            return
        }
        
        do {
            try await timeBlockingService.syncWithCalendar()
            await loadTimeBlocks()
        } catch {
            self.error = AppError.from(error)
        }
    }
    
    @MainActor
    func requestCalendarAccess() async {
        // В реальном приложении здесь была бы проверка разрешений EventKit
        calendarAuthorizationStatus = .authorized
        isCalendarSyncEnabled = true
        await syncWithCalendar()
    }
    
    func selectTimeBlock(_ timeBlock: TimeBlock) {
        selectedTimeBlock = timeBlock
    }
    
    func selectTaskForTimeBlock(_ task: ProjectTask) {
        selectedTask = task
        newTimeBlockTitle = task.title
        newTimeBlockDuration = task.estimatedDuration ?? 3600
    }
    
    func selectProjectForTimeBlock(_ project: Project) {
        selectedProject = project
        newTimeBlockTitle = "Работа над: \(project.name)"
    }
    
    func resetCreateForm() {
        newTimeBlockTitle = ""
        newTimeBlockStartTime = Date()
        newTimeBlockDuration = 3600
        selectedTask = nil
        selectedProject = nil
        showingCreateTimeBlock = false
    }
    
    func refreshData() async {
        switch viewMode {
        case .day:
            await loadTimeBlocks()
        case .week:
            await loadWeeklyData()
        case .workload:
            await loadWorkloadAnalysis()
        }
        
        await loadWorkloadInfo()
        await loadPendingTasks()
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func checkCalendarAuthorization() async {
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        isCalendarSyncEnabled = calendarAuthorizationStatus == .authorized
    }
    
    @MainActor
    private func loadWorkloadInfo() async {
        do {
            workloadInfo = try await timeBlockingService.calculateWorkload(for: selectedDate)
        } catch {
            print("Failed to load workload info: \(error)")
        }
    }
    
    @MainActor
    private func loadFreeTimeSlots() async {
        do {
            freeTimeSlots = try await timeBlockingService.findFreeTimeSlots(
                for: selectedDate,
                duration: 3600 // 1 час минимум
            )
        } catch {
            print("Failed to load free time slots: \(error)")
        }
    }
    
    @MainActor
    private func loadPendingTasks() async {
        do {
            let allTasks = try await taskService.getActiveTasks()
            pendingTasks = allTasks.filter { task in
                // Задачи без назначенного time block
                return !timeBlocks.contains { timeBlock in
                    timeBlock.task?.id == task.id
                }
            }
        } catch {
            print("Failed to load pending tasks: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    func getTimeBlocksForHour(_ hour: Int) -> [TimeBlock] {
        let calendar = Calendar.current
        let startOfHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? startOfHour
        
        return timeBlocks.filter { timeBlock in
            timeBlock.startDate < endOfHour && timeBlock.endDate > startOfHour
        }
    }
    
    func getWorkingHours() -> Range<Int> {
        return schedulingPreferences.workingHours
    }
    
    func isWorkingDay(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return schedulingPreferences.workingDays.contains(weekday)
    }
    
    func getTotalScheduledTime(for date: Date) -> TimeInterval {
        let dayBlocks = timeBlocks.filter { 
            Calendar.current.isDate($0.startDate, inSameDayAs: date)
        }
        return dayBlocks.reduce(0) { $0 + $1.duration }
    }
    
    func getUtilizationRate(for date: Date) -> Double {
        guard let workload = workloadInfo else { return 0.0 }
        return workload.utilizationRate
    }
}

// MARK: - Supporting Types

enum TimeBlockViewMode: String, CaseIterable {
    case day = "День"
    case week = "Неделя"
    case workload = "Загрузка"
}

struct SchedulingPreferences {
    var workingHours: Range<Int> = 9..<18 // 9:00-18:00
    var workingDays: Set<Int> = [2, 3, 4, 5, 6] // Пн-Пт (в календаре воскресенье = 1)
    var preferredBreakDuration: TimeInterval = 900 // 15 минут
    var maxContinuousWork: TimeInterval = 7200 // 2 часа
    var energyLevelPreferences: [TimeOfDay: EnergyLevel] = [
        .morning: .high,
        .afternoon: .medium,
        .evening: .low
    ]
    
    static let `default` = SchedulingPreferences()
}

extension TimeBlock {
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
    
    var durationInHours: Double {
        return duration / 3600.0
    }
    
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

extension WorkloadInfo {
    var utilizationPercentage: Int {
        return Int(utilizationRate * 100)
    }
    
    var statusColor: Color {
        switch utilizationRate {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var statusText: String {
        switch utilizationRate {
        case 0..<0.5:
            return "Недогружен"
        case 0.5..<0.8:
            return "Оптимально"
        default:
            return "Перегружен"
        }
    }
}

// Дополнительные структуры для поддержки функциональности
struct TimeSlot: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let score: Double // Оценка оптимальности (0-1)
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
} 