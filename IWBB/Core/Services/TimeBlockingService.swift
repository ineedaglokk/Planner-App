import Foundation
import SwiftData
import EventKit

// MARK: - TimeBlockingService Protocol

protocol TimeBlockingServiceProtocol: ServiceProtocol {
    // Time Block Management
    func createTimeBlock(for task: ProjectTask?, duration: TimeInterval, preferredDate: Date?) async throws -> TimeBlock
    func createTimeBlock(for project: Project?, duration: TimeInterval, preferredDate: Date?) async throws -> TimeBlock
    func getTimeBlock(by id: UUID) async throws -> TimeBlock?
    func getTimeBlocks(for date: Date) async throws -> [TimeBlock]
    func getTimeBlocks(for dateRange: DateInterval) async throws -> [TimeBlock]
    func updateTimeBlock(_ timeBlock: TimeBlock) async throws
    func deleteTimeBlock(_ timeBlock: TimeBlock) async throws
    
    // Scheduling and Optimization
    func suggestOptimalTimeSlots(for task: ProjectTask) async throws -> [TimeSlot]
    func suggestOptimalTimeSlots(duration: TimeInterval, energyLevel: EnergyLevel?, timeOfDay: TimeOfDay?) async throws -> [TimeSlot]
    func rescheduleTimeBlock(_ timeBlock: TimeBlock, to newDate: Date) async throws
    func optimizeSchedule(for date: Date) async throws -> [ScheduleOptimization]
    func findFreeTimeSlots(for date: Date, duration: TimeInterval) async throws -> [TimeSlot]
    
    // Calendar Integration
    func syncWithCalendar() async throws
    func createCalendarEvent(for timeBlock: TimeBlock) async throws
    func updateCalendarEvent(for timeBlock: TimeBlock) async throws
    func deleteCalendarEvent(for timeBlock: TimeBlock) async throws
    func handleCalendarEventUpdate(_ eventID: String) async throws
    func importCalendarEvents(from calendarIdentifier: String) async throws -> [TimeBlock]
    
    // Workload Management
    func calculateWorkload(for date: Date) async throws -> WorkloadInfo
    func calculateWorkload(for week: Date) async throws -> [WorkloadInfo]
    func suggestWorkloadDistribution(for week: Date) async throws -> [WorkloadSuggestion]
    func getWorkloadTrends(for period: DateInterval) async throws -> WorkloadTrends
    
    // Analytics and Insights
    func getTimeBlockAnalytics(for period: DateInterval) async throws -> TimeBlockAnalytics
    func getProductivityInsights(for user: User) async throws -> [ProductivityInsight]
    func generateTimeReports(for period: DateInterval) async throws -> TimeReport
    
    // Auto-scheduling
    func autoScheduleTasks(_ tasks: [ProjectTask], within timeframe: DateInterval, preferences: SchedulingPreferences) async throws -> [TimeBlock]
    func rebalanceSchedule(for date: Date, constraints: SchedulingConstraints?) async throws -> [TimeBlock]
}

// MARK: - TimeBlockingService Implementation

@Observable
final class TimeBlockingService: TimeBlockingServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let calendarService: CalendarIntegrationServiceProtocol
    private let notificationService: NotificationServiceProtocol
    
    private(set) var isInitialized: Bool = false
    
    // Scheduling engine
    private let schedulingEngine = SchedulingEngine()
    private let workloadCalculator = WorkloadCalculator()
    private let analyticsEngine = TimeBlockAnalyticsEngine()
    
    // Calendar integration
    private let eventStore = EKEventStore()
    private var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    
    // Caching
    private var workloadCache: [String: WorkloadInfo] = [:] // Key: date string
    private var timeSlotCache: [String: [TimeSlot]] = [:] // Key: date + duration
    private let cacheQueue = DispatchQueue(label: "com.plannerapp.timeblocking.cache", qos: .utility)
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        calendarService: CalendarIntegrationServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.dataService = dataService
        self.calendarService = calendarService
        self.notificationService = notificationService
    }
    
    // MARK: - ServiceProtocol
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        do {
            // Запрашиваем доступ к календарю
            try await requestCalendarAccess()
            
            // Инициализируем движок планирования
            try await schedulingEngine.initialize()
            
            // Синхронизируем с календарем
            try await syncWithCalendar()
            
            isInitialized = true
            
            #if DEBUG
            print("TimeBlockingService initialized successfully")
            #endif
            
        } catch {
            throw AppError.from(error)
        }
    }
    
    func cleanup() async {
        // Очищаем кэши
        workloadCache.removeAll()
        timeSlotCache.removeAll()
        
        // Очищаем движок планирования
        await schedulingEngine.cleanup()
        
        isInitialized = false
        
        #if DEBUG
        print("TimeBlockingService cleaned up")
        #endif
    }
    
    // MARK: - Time Block Management
    
    func createTimeBlock(for task: ProjectTask? = nil, duration: TimeInterval, preferredDate: Date? = nil) async throws -> TimeBlock {
        let title = task?.title ?? "Рабочий блок"
        let startDate = preferredDate ?? Date()
        let endDate = startDate.addingTimeInterval(duration)
        
        // Проверяем конфликты
        let conflicts = try await checkTimeConflicts(startDate: startDate, endDate: endDate)
        if !conflicts.isEmpty {
            // Пытаемся найти альтернативное время
            if let alternativeSlot = try await findAlternativeTimeSlot(duration: duration, near: startDate) {
                let timeBlock = TimeBlock(
                    title: title,
                    startDate: alternativeSlot.startDate,
                    endDate: alternativeSlot.endDate,
                    task: task
                )
                
                try await dataService.save(timeBlock)
                
                // Создаем событие календаря
                if timeBlock.syncWithCalendar {
                    try await createCalendarEvent(for: timeBlock)
                }
                
                await invalidateWorkloadCache(for: alternativeSlot.startDate)
                
                return timeBlock
            } else {
                throw AppError.from(TimeBlockingError.noAvailableTimeSlots)
            }
        }
        
        let timeBlock = TimeBlock(
            title: title,
            startDate: startDate,
            endDate: endDate,
            task: task
        )
        
        try await dataService.save(timeBlock)
        
        // Создаем событие календаря
        if timeBlock.syncWithCalendar {
            try await createCalendarEvent(for: timeBlock)
        }
        
        await invalidateWorkloadCache(for: startDate)
        
        return timeBlock
    }
    
    func createTimeBlock(for project: Project? = nil, duration: TimeInterval, preferredDate: Date? = nil) async throws -> TimeBlock {
        let title = project?.name ?? "Проектная работа"
        let startDate = preferredDate ?? Date()
        let endDate = startDate.addingTimeInterval(duration)
        
        let timeBlock = TimeBlock(
            title: title,
            startDate: startDate,
            endDate: endDate,
            project: project
        )
        
        try await dataService.save(timeBlock)
        
        if timeBlock.syncWithCalendar {
            try await createCalendarEvent(for: timeBlock)
        }
        
        await invalidateWorkloadCache(for: startDate)
        
        return timeBlock
    }
    
    func getTimeBlock(by id: UUID) async throws -> TimeBlock? {
        let predicate = #Predicate<TimeBlock> { timeBlock in
            timeBlock.id == id
        }
        let timeBlocks = try await dataService.fetch(TimeBlock.self, predicate: predicate)
        return timeBlocks.first
    }
    
    func getTimeBlocks(for date: Date) async throws -> [TimeBlock] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let predicate = #Predicate<TimeBlock> { timeBlock in
            timeBlock.startDate >= startOfDay && timeBlock.startDate < endOfDay
        }
        
        return try await dataService.fetch(TimeBlock.self, predicate: predicate)
    }
    
    func getTimeBlocks(for dateRange: DateInterval) async throws -> [TimeBlock] {
        let predicate = #Predicate<TimeBlock> { timeBlock in
            timeBlock.startDate >= dateRange.start && timeBlock.endDate <= dateRange.end
        }
        
        return try await dataService.fetch(TimeBlock.self, predicate: predicate)
    }
    
    func updateTimeBlock(_ timeBlock: TimeBlock) async throws {
        try timeBlock.validate()
        timeBlock.updateTimestamp()
        timeBlock.markForSync()
        
        try await dataService.update(timeBlock)
        
        // Обновляем событие календаря
        if timeBlock.syncWithCalendar {
            try await updateCalendarEvent(for: timeBlock)
        }
        
        await invalidateWorkloadCache(for: timeBlock.startDate)
    }
    
    func deleteTimeBlock(_ timeBlock: TimeBlock) async throws {
        // Удаляем событие календаря
        if timeBlock.syncWithCalendar {
            try await deleteCalendarEvent(for: timeBlock)
        }
        
        try await dataService.delete(timeBlock)
        
        await invalidateWorkloadCache(for: timeBlock.startDate)
    }
    
    // MARK: - Scheduling and Optimization
    
    func suggestOptimalTimeSlots(for task: ProjectTask) async throws -> [TimeSlot] {
        let duration = task.estimatedDuration ?? 3600 // 1 час по умолчанию
        let energyLevel = task.energyLevel
        let timeOfDay = task.timeOfDay
        
        return try await suggestOptimalTimeSlots(
            duration: duration,
            energyLevel: energyLevel,
            timeOfDay: timeOfDay
        )
    }
    
    func suggestOptimalTimeSlots(duration: TimeInterval, energyLevel: EnergyLevel? = nil, timeOfDay: TimeOfDay? = nil) async throws -> [TimeSlot] {
        let cacheKey = "\(Date().timeIntervalSinceReferenceDate)_\(duration)_\(energyLevel?.rawValue ?? 0)_\(timeOfDay?.rawValue ?? "")"
        
        // Проверяем кэш
        if let cachedSlots = timeSlotCache[cacheKey] {
            return cachedSlots
        }
        
        let suggestions = await schedulingEngine.suggestTimeSlots(
            duration: duration,
            energyLevel: energyLevel,
            timeOfDay: timeOfDay,
            availableTimeBlocks: try await getTimeBlocks(for: Date()),
            userPreferences: getUserSchedulingPreferences()
        )
        
        // Кэшируем результат
        timeSlotCache[cacheKey] = suggestions
        
        return suggestions
    }
    
    func rescheduleTimeBlock(_ timeBlock: TimeBlock, to newDate: Date) async throws {
        guard timeBlock.canBeRescheduled else {
            throw AppError.from(TimeBlockingError.cannotReschedule)
        }
        
        let duration = timeBlock.duration
        let newEndDate = newDate.addingTimeInterval(duration)
        
        // Проверяем конфликты в новом времени
        let conflicts = try await checkTimeConflicts(startDate: newDate, endDate: newEndDate, excluding: timeBlock.id)
        if !conflicts.isEmpty {
            throw AppError.from(TimeBlockingError.timeSlotConflict)
        }
        
        let oldDate = timeBlock.startDate
        
        timeBlock.reschedule(to: newDate)
        try await updateTimeBlock(timeBlock)
        
        // Инвалидируем кэш для обеих дат
        await invalidateWorkloadCache(for: oldDate)
        await invalidateWorkloadCache(for: newDate)
    }
    
    func optimizeSchedule(for date: Date) async throws -> [ScheduleOptimization] {
        let timeBlocks = try await getTimeBlocks(for: date)
        return await schedulingEngine.optimizeSchedule(timeBlocks)
    }
    
    func findFreeTimeSlots(for date: Date, duration: TimeInterval) async throws -> [TimeSlot] {
        let timeBlocks = try await getTimeBlocks(for: date)
        let calendarEvents = try await getCalendarEvents(for: date)
        
        return schedulingEngine.findFreeSlots(
            on: date,
            duration: duration,
            existingTimeBlocks: timeBlocks,
            calendarEvents: calendarEvents
        )
    }
    
    // MARK: - Calendar Integration
    
    func syncWithCalendar() async throws {
        guard calendarAuthorizationStatus == .authorized else {
            throw AppError.from(CalendarError.accessDenied)
        }
        
        // Получаем события из календаря за последнюю неделю и следующие 2 недели
        let startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Синхронизируем события с time blocks
        for event in events {
            try await syncCalendarEvent(event)
        }
    }
    
    func createCalendarEvent(for timeBlock: TimeBlock) async throws {
        guard let calendar = try await getDefaultCalendar() else {
            throw AppError.from(CalendarError.noDefaultCalendar)
        }
        
        if let event = timeBlock.createCalendarEvent(in: calendar) {
            try eventStore.save(event, span: .thisEvent)
            timeBlock.calendarEventID = event.eventIdentifier
            try await updateTimeBlock(timeBlock)
        }
    }
    
    func updateCalendarEvent(for timeBlock: TimeBlock) async throws {
        guard let eventID = timeBlock.calendarEventID,
              let event = eventStore.event(withIdentifier: eventID) else {
            // Если события нет, создаем новое
            try await createCalendarEvent(for: timeBlock)
            return
        }
        
        timeBlock.updateCalendarEvent(event)
        try eventStore.save(event, span: .thisEvent)
    }
    
    func deleteCalendarEvent(for timeBlock: TimeBlock) async throws {
        guard let eventID = timeBlock.calendarEventID,
              let event = eventStore.event(withIdentifier: eventID) else {
            return
        }
        
        try eventStore.remove(event, span: .thisEvent)
        timeBlock.calendarEventID = nil
    }
    
    func handleCalendarEventUpdate(_ eventID: String) async throws {
        guard let event = eventStore.event(withIdentifier: eventID) else { return }
        
        // Находим соответствующий time block
        let predicate = #Predicate<TimeBlock> { timeBlock in
            timeBlock.calendarEventID == eventID
        }
        
        let timeBlocks = try await dataService.fetch(TimeBlock.self, predicate: predicate)
        
        if let timeBlock = timeBlocks.first {
            // Обновляем time block на основе изменений в календаре
            timeBlock.title = event.title
            timeBlock.startDate = event.startDate
            timeBlock.endDate = event.endDate
            timeBlock.location = event.location
            timeBlock.notes = event.notes
            
            try await updateTimeBlock(timeBlock)
        }
    }
    
    func importCalendarEvents(from calendarIdentifier: String) async throws -> [TimeBlock] {
        let calendar = eventStore.calendar(withIdentifier: calendarIdentifier)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendar.map { [$0] })
        let events = eventStore.events(matching: predicate)
        
        var importedTimeBlocks: [TimeBlock] = []
        
        for event in events {
            let timeBlock = TimeBlock(
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate
            )
            
            timeBlock.location = event.location
            timeBlock.notes = event.notes
            timeBlock.calendarEventID = event.eventIdentifier
            timeBlock.syncWithCalendar = false // Избегаем дублирования
            
            try await dataService.save(timeBlock)
            importedTimeBlocks.append(timeBlock)
        }
        
        return importedTimeBlocks
    }
    
    // MARK: - Workload Management
    
    func calculateWorkload(for date: Date) async throws -> WorkloadInfo {
        let dateKey = DateFormatter.yyyyMMdd.string(from: date)
        
        // Проверяем кэш
        if let cachedWorkload = workloadCache[dateKey] {
            return cachedWorkload
        }
        
        let workload = await workloadCalculator.calculateWorkload(
            for: date,
            timeBlocks: try await getTimeBlocks(for: date),
            calendarEvents: try await getCalendarEvents(for: date)
        )
        
        // Кэшируем результат
        workloadCache[dateKey] = workload
        
        return workload
    }
    
    func calculateWorkload(for week: Date) async throws -> [WorkloadInfo] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: week) else {
            throw AppError.from(TimeBlockingError.invalidDateRange)
        }
        
        var workloads: [WorkloadInfo] = []
        var currentDate = weekInterval.start
        
        while currentDate < weekInterval.end {
            let workload = try await calculateWorkload(for: currentDate)
            workloads.append(workload)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return workloads
    }
    
    func suggestWorkloadDistribution(for week: Date) async throws -> [WorkloadSuggestion] {
        let workloads = try await calculateWorkload(for: week)
        return workloadCalculator.suggestDistribution(workloads)
    }
    
    func getWorkloadTrends(for period: DateInterval) async throws -> WorkloadTrends {
        let timeBlocks = try await getTimeBlocks(for: period)
        return analyticsEngine.calculateTrends(timeBlocks, in: period)
    }
    
    // MARK: - Analytics and Insights
    
    func getTimeBlockAnalytics(for period: DateInterval) async throws -> TimeBlockAnalytics {
        let timeBlocks = try await getTimeBlocks(for: period)
        return analyticsEngine.generateAnalytics(timeBlocks, for: period)
    }
    
    func getProductivityInsights(for user: User) async throws -> [ProductivityInsight] {
        let period = DateInterval(start: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(), end: Date())
        let timeBlocks = try await getTimeBlocks(for: period)
        
        return analyticsEngine.generateProductivityInsights(timeBlocks, for: user)
    }
    
    func generateTimeReports(for period: DateInterval) async throws -> TimeReport {
        let analytics = try await getTimeBlockAnalytics(for: period)
        let workloadTrends = try await getWorkloadTrends(for: period)
        
        return TimeReport(
            period: period,
            analytics: analytics,
            trends: workloadTrends,
            generatedAt: Date()
        )
    }
    
    // MARK: - Auto-scheduling
    
    func autoScheduleTasks(_ tasks: [ProjectTask], within timeframe: DateInterval, preferences: SchedulingPreferences) async throws -> [TimeBlock] {
        let availableSlots = try await findAvailableSlots(in: timeframe)
        
        return await schedulingEngine.autoSchedule(
            tasks: tasks,
            availableSlots: availableSlots,
            preferences: preferences
        )
    }
    
    func rebalanceSchedule(for date: Date, constraints: SchedulingConstraints? = nil) async throws -> [TimeBlock] {
        let timeBlocks = try await getTimeBlocks(for: date)
        
        return await schedulingEngine.rebalanceSchedule(
            timeBlocks: timeBlocks,
            constraints: constraints ?? SchedulingConstraints.default
        )
    }
    
    // MARK: - Private Methods
    
    private func requestCalendarAccess() async throws {
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        
        if calendarAuthorizationStatus == .notDetermined {
            calendarAuthorizationStatus = try await eventStore.requestAccess(to: .event) ? .authorized : .denied
        }
        
        if calendarAuthorizationStatus != .authorized {
            throw AppError.from(CalendarError.accessDenied)
        }
    }
    
    private func getDefaultCalendar() async throws -> EKCalendar? {
        return eventStore.defaultCalendarForNewEvents
    }
    
    private func getCalendarEvents(for date: Date) async throws -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    private func checkTimeConflicts(startDate: Date, endDate: Date, excluding excludeId: UUID? = nil) async throws -> [TimeBlockConflict] {
        let timeBlocks = try await getTimeBlocks(for: startDate)
        var conflicts: [TimeBlockConflict] = []
        
        for timeBlock in timeBlocks {
            if timeBlock.id == excludeId { continue }
            
            if timeBlock.startDate < endDate && timeBlock.endDate > startDate {
                conflicts.append(TimeBlockConflict(
                    conflictingTimeBlock: timeBlock,
                    proposedStart: startDate,
                    proposedEnd: endDate
                ))
            }
        }
        
        return conflicts
    }
    
    private func findAlternativeTimeSlot(duration: TimeInterval, near preferredDate: Date) async throws -> TimeSlot? {
        let freeSlots = try await findFreeTimeSlots(for: preferredDate, duration: duration)
        
        // Находим ближайший к предпочитаемому времени
        return freeSlots.min { slot1, slot2 in
            abs(slot1.startDate.timeIntervalSince(preferredDate)) < abs(slot2.startDate.timeIntervalSince(preferredDate))
        }
    }
    
    private func syncCalendarEvent(_ event: EKEvent) async throws {
        // Проверяем, есть ли уже time block для этого события
        let predicate = #Predicate<TimeBlock> { timeBlock in
            timeBlock.calendarEventID == event.eventIdentifier
        }
        
        let existingTimeBlocks = try await dataService.fetch(TimeBlock.self, predicate: predicate)
        
        if existingTimeBlocks.isEmpty {
            // Создаем новый time block
            let timeBlock = TimeBlock(
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate
            )
            
            timeBlock.calendarEventID = event.eventIdentifier
            timeBlock.location = event.location
            timeBlock.notes = event.notes
            timeBlock.syncWithCalendar = false // Избегаем обратной синхронизации
            
            try await dataService.save(timeBlock)
        } else if let timeBlock = existingTimeBlocks.first {
            // Обновляем существующий time block
            timeBlock.title = event.title
            timeBlock.startDate = event.startDate
            timeBlock.endDate = event.endDate
            timeBlock.location = event.location
            timeBlock.notes = event.notes
            
            try await updateTimeBlock(timeBlock)
        }
    }
    
    private func findAvailableSlots(in timeframe: DateInterval) async throws -> [TimeSlot] {
        let calendar = Calendar.current
        var availableSlots: [TimeSlot] = []
        var currentDate = timeframe.start
        
        while currentDate < timeframe.end {
            let daySlots = try await findFreeTimeSlots(for: currentDate, duration: 3600) // 1 час слоты
            availableSlots.append(contentsOf: daySlots)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return availableSlots
    }
    
    private func getUserSchedulingPreferences() -> SchedulingPreferences {
        // Заглушка для пользовательских предпочтений
        return SchedulingPreferences(
            preferredWorkingHours: 9...17,
            energyLevelOptimization: true,
            breakDuration: 900, // 15 минут
            maxContinuousWorkTime: 7200, // 2 часа
            preferredFocusBlocks: [.morning, .afternoon]
        )
    }
    
    private func invalidateWorkloadCache(for date: Date) async {
        let dateKey = DateFormatter.yyyyMMdd.string(from: date)
        await cacheQueue.run {
            self.workloadCache.removeValue(forKey: dateKey)
        }
    }
}

// MARK: - Supporting Classes

class SchedulingEngine {
    func initialize() async throws {
        // Инициализация алгоритмов планирования
    }
    
    func cleanup() async {
        // Очистка ресурсов
    }
    
    func suggestTimeSlots(duration: TimeInterval, energyLevel: EnergyLevel?, timeOfDay: TimeOfDay?, availableTimeBlocks: [TimeBlock], userPreferences: SchedulingPreferences) async -> [TimeSlot] {
        // Алгоритм предложения оптимальных временных слотов
        var suggestions: [TimeSlot] = []
        
        let calendar = Calendar.current
        let today = Date()
        
        // Получаем рабочие часы
        let workingHours = userPreferences.preferredWorkingHours
        
        for hour in workingHours {
            guard let slotStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) else { continue }
            let slotEnd = slotStart.addingTimeInterval(duration)
            
            // Проверяем конфликты
            let hasConflict = availableTimeBlocks.contains { timeBlock in
                timeBlock.startDate < slotEnd && timeBlock.endDate > slotStart
            }
            
            if !hasConflict {
                let score = calculateSlotScore(
                    slotStart: slotStart,
                    energyLevel: energyLevel,
                    timeOfDay: timeOfDay,
                    preferences: userPreferences
                )
                
                suggestions.append(TimeSlot(
                    startDate: slotStart,
                    endDate: slotEnd,
                    score: score
                ))
            }
        }
        
        return suggestions.sorted { $0.score > $1.score }
    }
    
    func optimizeSchedule(_ timeBlocks: [TimeBlock]) async -> [ScheduleOptimization] {
        var optimizations: [ScheduleOptimization] = []
        
        // Анализируем расписание на предмет оптимизации
        for timeBlock in timeBlocks {
            if let optimization = analyzeTimeBlock(timeBlock) {
                optimizations.append(optimization)
            }
        }
        
        return optimizations
    }
    
    func findFreeSlots(on date: Date, duration: TimeInterval, existingTimeBlocks: [TimeBlock], calendarEvents: [EKEvent]) -> [TimeSlot] {
        let calendar = Calendar.current
        let startOfDay = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date
        let endOfDay = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date
        
        var occupiedSlots: [DateInterval] = []
        
        // Добавляем time blocks
        for timeBlock in existingTimeBlocks {
            occupiedSlots.append(DateInterval(start: timeBlock.startDate, end: timeBlock.endDate))
        }
        
        // Добавляем события календаря
        for event in calendarEvents {
            occupiedSlots.append(DateInterval(start: event.startDate, end: event.endDate))
        }
        
        // Сортируем занятые слоты
        occupiedSlots.sort { $0.start < $1.start }
        
        var freeSlots: [TimeSlot] = []
        var currentTime = startOfDay
        
        for occupiedSlot in occupiedSlots {
            if currentTime < occupiedSlot.start {
                let freeSlotDuration = occupiedSlot.start.timeIntervalSince(currentTime)
                if freeSlotDuration >= duration {
                    let endTime = min(currentTime.addingTimeInterval(duration), occupiedSlot.start)
                    freeSlots.append(TimeSlot(
                        startDate: currentTime,
                        endDate: endTime,
                        score: 1.0
                    ))
                }
            }
            currentTime = max(currentTime, occupiedSlot.end)
        }
        
        // Проверяем время после последнего занятого слота
        if currentTime < endOfDay {
            let remainingDuration = endOfDay.timeIntervalSince(currentTime)
            if remainingDuration >= duration {
                freeSlots.append(TimeSlot(
                    startDate: currentTime,
                    endDate: currentTime.addingTimeInterval(duration),
                    score: 1.0
                ))
            }
        }
        
        return freeSlots
    }
    
    func autoSchedule(tasks: [ProjectTask], availableSlots: [TimeSlot], preferences: SchedulingPreferences) async -> [TimeBlock] {
        var scheduledBlocks: [TimeBlock] = []
        var remainingSlots = availableSlots.sorted { $0.score > $1.score }
        
        for task in tasks.sorted(by: { $0.priority.rawValue > $1.priority.rawValue }) {
            guard let duration = task.estimatedDuration else { continue }
            
            if let slot = remainingSlots.first(where: { $0.duration >= duration }) {
                let timeBlock = TimeBlock(
                    title: task.title,
                    startDate: slot.startDate,
                    endDate: slot.startDate.addingTimeInterval(duration),
                    task: task
                )
                
                timeBlock.isAutoScheduled = true
                scheduledBlocks.append(timeBlock)
                
                // Удаляем использованный слот
                remainingSlots.removeAll { $0.startDate == slot.startDate }
            }
        }
        
        return scheduledBlocks
    }
    
    func rebalanceSchedule(timeBlocks: [TimeBlock], constraints: SchedulingConstraints) async -> [TimeBlock] {
        // Алгоритм перебалансировки расписания
        return timeBlocks // Заглушка
    }
    
    // Helper methods
    private func calculateSlotScore(slotStart: Date, energyLevel: EnergyLevel?, timeOfDay: TimeOfDay?, preferences: SchedulingPreferences) -> Double {
        var score: Double = 1.0
        
        let hour = Calendar.current.component(.hour, from: slotStart)
        
        // Бонус за предпочитаемые рабочие часы
        if preferences.preferredWorkingHours.contains(hour) {
            score += 0.5
        }
        
        // Бонус за соответствие энергетическому уровню
        if let requiredEnergy = energyLevel {
            let currentEnergy = EnergyLevel.currentEnergyLevel(at: hour)
            if currentEnergy.rawValue >= requiredEnergy.rawValue {
                score += 0.3
            }
        }
        
        // Бонус за предпочитаемое время дня
        if let preferredTime = timeOfDay {
            if preferredTime.contains(hour: hour) {
                score += 0.2
            }
        }
        
        return score
    }
    
    private func analyzeTimeBlock(_ timeBlock: TimeBlock) -> ScheduleOptimization? {
        // Анализ time block на предмет оптимизации
        if timeBlock.duration > 7200 { // Более 2 часов
            return ScheduleOptimization(
                type: .splitLongBlock,
                timeBlock: timeBlock,
                description: "Рекомендуется разделить длинный блок на части",
                potentialBenefit: "Повышение концентрации и продуктивности"
            )
        }
        
        return nil
    }
}

class WorkloadCalculator {
    func calculateWorkload(for date: Date, timeBlocks: [TimeBlock], calendarEvents: [EKEvent]) async -> WorkloadInfo {
        let totalScheduledTime = timeBlocks.reduce(0) { $0 + $1.duration }
        let totalCalendarTime = calendarEvents.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        
        let workingHoursInDay: TimeInterval = 8 * 3600 // 8 часов
        let utilization = (totalScheduledTime + totalCalendarTime) / workingHoursInDay
        
        return WorkloadInfo(
            date: date,
            scheduledTime: totalScheduledTime,
            availableTime: workingHoursInDay - totalScheduledTime - totalCalendarTime,
            utilization: utilization,
            overbooked: utilization > 1.0,
            recommendations: generateWorkloadRecommendations(utilization: utilization)
        )
    }
    
    func suggestDistribution(_ workloads: [WorkloadInfo]) -> [WorkloadSuggestion] {
        var suggestions: [WorkloadSuggestion] = []
        
        let overloadedDays = workloads.filter { $0.overbooked }
        let underloadedDays = workloads.filter { $0.utilization < 0.6 }
        
        if !overloadedDays.isEmpty && !underloadedDays.isEmpty {
            suggestions.append(WorkloadSuggestion(
                type: .redistributeTasks,
                description: "Перенесите задачи с перегруженных дней на менее загруженные",
                affectedDates: overloadedDays.map { $0.date } + underloadedDays.map { $0.date }
            ))
        }
        
        return suggestions
    }
    
    private func generateWorkloadRecommendations(utilization: Double) -> [String] {
        var recommendations: [String] = []
        
        if utilization > 1.2 {
            recommendations.append("День сильно перегружен. Рассмотрите перенос некоторых задач.")
        } else if utilization > 1.0 {
            recommendations.append("День перегружен. Возможны задержки.")
        } else if utilization < 0.4 {
            recommendations.append("День недогружен. Можно добавить дополнительные задачи.")
        }
        
        return recommendations
    }
}

class TimeBlockAnalyticsEngine {
    func generateAnalytics(_ timeBlocks: [TimeBlock], for period: DateInterval) -> TimeBlockAnalytics {
        let totalTime = timeBlocks.reduce(0) { $0 + $1.duration }
        let completedBlocks = timeBlocks.filter { $0.isCompleted }
        let completionRate = timeBlocks.isEmpty ? 0.0 : Double(completedBlocks.count) / Double(timeBlocks.count)
        
        let averageProductivity = calculateAverageProductivity(timeBlocks)
        let mostProductiveTime = findMostProductiveTime(timeBlocks)
        
        return TimeBlockAnalytics(
            period: period,
            totalTimeBlocks: timeBlocks.count,
            totalScheduledTime: totalTime,
            completionRate: completionRate,
            averageProductivity: averageProductivity,
            mostProductiveTime: mostProductiveTime,
            categoryBreakdown: generateCategoryBreakdown(timeBlocks)
        )
    }
    
    func calculateTrends(_ timeBlocks: [TimeBlock], in period: DateInterval) -> WorkloadTrends {
        // Группируем по дням
        let calendar = Calendar.current
        var dailyWorkloads: [Date: TimeInterval] = [:]
        
        for timeBlock in timeBlocks {
            let day = calendar.startOfDay(for: timeBlock.startDate)
            dailyWorkloads[day, default: 0] += timeBlock.duration
        }
        
        let values = Array(dailyWorkloads.values)
        let averageWorkload = values.isEmpty ? 0 : values.reduce(0, +) / TimeInterval(values.count)
        
        return WorkloadTrends(
            period: period,
            averageWorkload: averageWorkload,
            peakWorkloadDay: dailyWorkloads.max { $0.value < $1.value }?.key,
            trendDirection: calculateTrendDirection(values)
        )
    }
    
    func generateProductivityInsights(_ timeBlocks: [TimeBlock], for user: User) -> [ProductivityInsight] {
        var insights: [ProductivityInsight] = []
        
        // Анализ времени суток
        let morningBlocks = timeBlocks.filter { Calendar.current.component(.hour, from: $0.startDate) < 12 }
        let afternoonBlocks = timeBlocks.filter { Calendar.current.component(.hour, from: $0.startDate) >= 12 }
        
        let morningProductivity = calculateAverageProductivity(morningBlocks)
        let afternoonProductivity = calculateAverageProductivity(afternoonBlocks)
        
        if morningProductivity > afternoonProductivity {
            insights.append(ProductivityInsight(
                type: .timeOfDay,
                title: "Утренняя продуктивность",
                description: "Вы более продуктивны утром",
                recommendation: "Планируйте сложные задачи на утренние часы"
            ))
        }
        
        return insights
    }
    
    // Helper methods
    private func calculateAverageProductivity(_ timeBlocks: [TimeBlock]) -> Double {
        let productiveBlocks = timeBlocks.compactMap { $0.productivity?.rawValue }
        return productiveBlocks.isEmpty ? 0.0 : Double(productiveBlocks.reduce(0, +)) / Double(productiveBlocks.count)
    }
    
    private func findMostProductiveTime(_ timeBlocks: [TimeBlock]) -> TimeOfDay? {
        var timeProductivity: [TimeOfDay: [Int]] = [:]
        
        for timeBlock in timeBlocks {
            guard let productivity = timeBlock.productivity else { continue }
            
            let hour = Calendar.current.component(.hour, from: timeBlock.startDate)
            let timeOfDay = TimeOfDay.current() // Можно улучшить логику определения
            
            timeProductivity[timeOfDay, default: []].append(productivity.rawValue)
        }
        
        return timeProductivity.max { pair1, pair2 in
            let avg1 = Double(pair1.value.reduce(0, +)) / Double(pair1.value.count)
            let avg2 = Double(pair2.value.reduce(0, +)) / Double(pair2.value.count)
            return avg1 < avg2
        }?.key
    }
    
    private func generateCategoryBreakdown(_ timeBlocks: [TimeBlock]) -> [CategoryTimeBreakdown] {
        var categoryTime: [String: TimeInterval] = [:]
        
        for timeBlock in timeBlocks {
            let category = timeBlock.task?.project.category?.name ?? "Без категории"
            categoryTime[category, default: 0] += timeBlock.duration
        }
        
        return categoryTime.map { CategoryTimeBreakdown(category: $0.key, totalTime: $0.value) }
    }
    
    private func calculateTrendDirection(_ values: [TimeInterval]) -> TrendDirection {
        guard values.count > 1 else { return .stable }
        
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / TimeInterval(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / TimeInterval(secondHalf.count)
        
        let change = (secondAvg - firstAvg) / firstAvg
        
        if change > 0.1 {
            return .increasing
        } else if change < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
}

// MARK: - Supporting Types

struct TimeSlot {
    let startDate: Date
    let endDate: Date
    let score: Double
    
    var duration: TimeInterval {
        return endDate.timeIntervalSince(startDate)
    }
}

struct TimeBlockConflict {
    let conflictingTimeBlock: TimeBlock
    let proposedStart: Date
    let proposedEnd: Date
}

struct WorkloadInfo {
    let date: Date
    let scheduledTime: TimeInterval
    let availableTime: TimeInterval
    let utilization: Double
    let overbooked: Bool
    let recommendations: [String]
}

struct WorkloadSuggestion {
    enum SuggestionType {
        case redistributeTasks
        case addBreaks
        case reduceWorkload
        case optimizeSchedule
    }
    
    let type: SuggestionType
    let description: String
    let affectedDates: [Date]
}

struct WorkloadTrends {
    let period: DateInterval
    let averageWorkload: TimeInterval
    let peakWorkloadDay: Date?
    let trendDirection: TrendDirection
}

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

struct ScheduleOptimization {
    enum OptimizationType {
        case splitLongBlock
        case combineShortBlocks
        case moveToOptimalTime
        case addBuffer
    }
    
    let type: OptimizationType
    let timeBlock: TimeBlock
    let description: String
    let potentialBenefit: String
}

struct SchedulingPreferences {
    let preferredWorkingHours: ClosedRange<Int>
    let energyLevelOptimization: Bool
    let breakDuration: TimeInterval
    let maxContinuousWorkTime: TimeInterval
    let preferredFocusBlocks: [TimeOfDay]
}

struct SchedulingConstraints {
    let mustStartAfter: Date?
    let mustFinishBefore: Date?
    let minimumBreakBetweenTasks: TimeInterval
    let maxTasksPerDay: Int?
    
    static let `default` = SchedulingConstraints(
        mustStartAfter: nil,
        mustFinishBefore: nil,
        minimumBreakBetweenTasks: 900, // 15 минут
        maxTasksPerDay: nil
    )
}

struct TimeBlockAnalytics {
    let period: DateInterval
    let totalTimeBlocks: Int
    let totalScheduledTime: TimeInterval
    let completionRate: Double
    let averageProductivity: Double
    let mostProductiveTime: TimeOfDay?
    let categoryBreakdown: [CategoryTimeBreakdown]
}

struct CategoryTimeBreakdown {
    let category: String
    let totalTime: TimeInterval
}

struct ProductivityInsight {
    enum InsightType {
        case timeOfDay
        case duration
        case frequency
        case pattern
    }
    
    let type: InsightType
    let title: String
    let description: String
    let recommendation: String
}

struct TimeReport {
    let period: DateInterval
    let analytics: TimeBlockAnalytics
    let trends: WorkloadTrends
    let generatedAt: Date
}

// MARK: - Errors

enum TimeBlockingError: Error {
    case noAvailableTimeSlots
    case timeSlotConflict
    case cannotReschedule
    case invalidDateRange
    case calendarSyncFailed
}

enum CalendarError: Error {
    case accessDenied
    case noDefaultCalendar
    case eventNotFound
    case syncFailed
}

// MARK: - Extensions

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
} 