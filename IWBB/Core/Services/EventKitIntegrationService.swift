import Foundation
import EventKit
import Combine

// MARK: - EventKit Integration Service Protocol

protocol EventKitIntegrationServiceProtocol: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    var isCalendarSyncEnabled: Bool { get }
    
    func requestCalendarAccess() async throws -> Bool
    func enableCalendarSync() async throws
    func disableCalendarSync() async throws
    
    func syncTimeBlockToCalendar(_ timeBlock: TimeBlock) async throws
    func removeTimeBlockFromCalendar(_ timeBlock: TimeBlock) async throws
    func updateTimeBlockInCalendar(_ timeBlock: TimeBlock) async throws
    
    func syncProjectToCalendar(_ project: Project) async throws
    func createProjectCalendar(_ project: Project) async throws -> EKCalendar
    
    func getCalendarEvents(for timeBlock: TimeBlock) async throws -> [EKEvent]
    func getConflictingEvents(for timeBlock: TimeBlock) async throws -> [EKEvent]
    
    func importEventsAsTimeBlocks(from calendar: EKCalendar, dateRange: DateInterval) async throws -> [TimeBlock]
}

// MARK: - EventKit Integration Service

@Observable
final class EventKitIntegrationService: EventKitIntegrationServiceProtocol {
    
    // MARK: - Dependencies
    
    private let eventStore: EKEventStore
    private let dataService: DataServiceProtocol
    private let userDefaultsService: UserDefaultsServiceProtocol
    
    // MARK: - Properties
    
    private(set) var authorizationStatus: EKAuthorizationStatus
    private(set) var isCalendarSyncEnabled: Bool
    
    private var plannerCalendar: EKCalendar?
    private var projectCalendars: [UUID: EKCalendar] = [:]
    
    // MARK: - Constants
    
    private struct Constants {
        static let plannerCalendarTitle = "Planner App"
        static let calendarSyncEnabledKey = "calendar_sync_enabled"
        static let plannerCalendarIdentifierKey = "planner_calendar_identifier"
        static let projectCalendarPrefixKey = "project_calendar_"
        static let timeBlockEventPrefix = "timeblock_"
        static let projectEventPrefix = "project_"
    }
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        userDefaultsService: UserDefaultsServiceProtocol
    ) {
        self.eventStore = EKEventStore()
        self.dataService = dataService
        self.userDefaultsService = userDefaultsService
        
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        self.isCalendarSyncEnabled = userDefaultsService.bool(for: Constants.calendarSyncEnabledKey)
        
        Task {
            await initializeCalendars()
        }
    }
    
    // MARK: - Authorization
    
    func requestCalendarAccess() async throws -> Bool {
        let status = try await eventStore.requestFullAccessToEvents()
        
        await MainActor.run {
            self.authorizationStatus = status
        }
        
        if status == .fullAccess {
            await initializeCalendars()
            return true
        } else {
            throw EventKitError.accessDenied
        }
    }
    
    func enableCalendarSync() async throws {
        guard authorizationStatus == .fullAccess else {
            throw EventKitError.accessDenied
        }
        
        // Create or find Planner calendar
        if plannerCalendar == nil {
            plannerCalendar = try await createPlannerCalendar()
        }
        
        await MainActor.run {
            self.isCalendarSyncEnabled = true
            self.userDefaultsService.set(true, for: Constants.calendarSyncEnabledKey)
        }
        
        // Sync existing time blocks
        await syncExistingTimeBlocks()
    }
    
    func disableCalendarSync() async throws {
        await MainActor.run {
            self.isCalendarSyncEnabled = false
            self.userDefaultsService.set(false, for: Constants.calendarSyncEnabledKey)
        }
        
        // Optionally remove all synced events
        // await removeAllSyncedEvents()
    }
    
    // MARK: - Time Block Synchronization
    
    func syncTimeBlockToCalendar(_ timeBlock: TimeBlock) async throws {
        guard isCalendarSyncEnabled, let calendar = plannerCalendar else {
            throw EventKitError.syncNotEnabled
        }
        
        // Check if event already exists
        if let existingEvent = try await findExistingEvent(for: timeBlock) {
            try await updateEvent(existingEvent, with: timeBlock)
        } else {
            try await createEvent(for: timeBlock, in: calendar)
        }
    }
    
    func removeTimeBlockFromCalendar(_ timeBlock: TimeBlock) async throws {
        guard isCalendarSyncEnabled else { return }
        
        if let event = try await findExistingEvent(for: timeBlock) {
            try eventStore.remove(event, span: .thisEvent)
            try eventStore.commit()
        }
    }
    
    func updateTimeBlockInCalendar(_ timeBlock: TimeBlock) async throws {
        guard isCalendarSyncEnabled else { return }
        
        if let existingEvent = try await findExistingEvent(for: timeBlock) {
            try await updateEvent(existingEvent, with: timeBlock)
        } else {
            try await syncTimeBlockToCalendar(timeBlock)
        }
    }
    
    // MARK: - Project Synchronization
    
    func syncProjectToCalendar(_ project: Project) async throws {
        guard isCalendarSyncEnabled else {
            throw EventKitError.syncNotEnabled
        }
        
        // Create project-specific calendar if needed
        if projectCalendars[project.id] == nil {
            let projectCalendar = try await createProjectCalendar(project)
            projectCalendars[project.id] = projectCalendar
        }
        
        // Sync project milestones and deadlines
        try await syncProjectMilestones(project)
    }
    
    func createProjectCalendar(_ project: Project) async throws -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "📋 \(project.name)"
        calendar.cgColor = (project.color?.color ?? .blue).cgColor
        
        // Find or create calendar source
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        } else {
            throw EventKitError.noCalendarSource
        }
        
        try eventStore.saveCalendar(calendar, commit: true)
        
        // Store calendar identifier
        let key = Constants.projectCalendarPrefixKey + project.id.uuidString
        userDefaultsService.set(calendar.calendarIdentifier, for: key)
        
        return calendar
    }
    
    // MARK: - Event Operations
    
    func getCalendarEvents(for timeBlock: TimeBlock) async throws -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: timeBlock.startDate,
            end: timeBlock.endDate,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate)
    }
    
    func getConflictingEvents(for timeBlock: TimeBlock) async throws -> [EKEvent] {
        let allEvents = try await getCalendarEvents(for: timeBlock)
        
        // Filter out our own events
        return allEvents.filter { event in
            !event.title.hasPrefix(Constants.timeBlockEventPrefix) &&
            !event.title.hasPrefix(Constants.projectEventPrefix)
        }
    }
    
    // MARK: - Import Operations
    
    func importEventsAsTimeBlocks(from calendar: EKCalendar, dateRange: DateInterval) async throws -> [TimeBlock] {
        let predicate = eventStore.predicateForEvents(
            withStart: dateRange.start,
            end: dateRange.end,
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        var timeBlocks: [TimeBlock] = []
        
        for event in events {
            // Skip all-day events and our own events
            guard !event.isAllDay,
                  !event.title.hasPrefix(Constants.timeBlockEventPrefix),
                  !event.title.hasPrefix(Constants.projectEventPrefix) else {
                continue
            }
            
            let timeBlock = TimeBlock(
                title: event.title,
                description: event.notes,
                startDate: event.startDate,
                endDate: event.endDate,
                task: nil,
                project: nil,
                isCompleted: false,
                calendarEventIdentifier: event.eventIdentifier
            )
            
            timeBlocks.append(timeBlock)
        }
        
        return timeBlocks
    }
    
    // MARK: - Private Methods
    
    private func initializeCalendars() async {
        guard authorizationStatus == .fullAccess else { return }
        
        // Find existing Planner calendar
        if let calendarId = userDefaultsService.string(for: Constants.plannerCalendarIdentifierKey),
           let calendar = eventStore.calendar(withIdentifier: calendarId) {
            plannerCalendar = calendar
        }
        
        // Load project calendars
        await loadProjectCalendars()
    }
    
    private func createPlannerCalendar() async throws -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = Constants.plannerCalendarTitle
        calendar.cgColor = UIColor.systemBlue.cgColor
        
        // Find appropriate source
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        } else {
            throw EventKitError.noCalendarSource
        }
        
        try eventStore.saveCalendar(calendar, commit: true)
        
        // Store calendar identifier
        userDefaultsService.set(calendar.calendarIdentifier, for: Constants.plannerCalendarIdentifierKey)
        
        return calendar
    }
    
    private func loadProjectCalendars() async {
        // This would load project calendar mappings from UserDefaults
        // and restore the projectCalendars dictionary
    }
    
    private func syncExistingTimeBlocks() async {
        do {
            let timeBlocks = try await dataService.fetch(TimeBlock.self)
            
            for timeBlock in timeBlocks {
                try await syncTimeBlockToCalendar(timeBlock)
            }
        } catch {
            print("Error syncing existing time blocks: \(error)")
        }
    }
    
    private func findExistingEvent(for timeBlock: TimeBlock) async throws -> EKEvent? {
        // If we have a stored event identifier, try to find it directly
        if let eventId = timeBlock.calendarEventIdentifier,
           let event = eventStore.event(withIdentifier: eventId) {
            return event
        }
        
        // Otherwise search by title and time
        let eventTitle = "\(Constants.timeBlockEventPrefix)\(timeBlock.title)"
        let predicate = eventStore.predicateForEvents(
            withStart: timeBlock.startDate,
            end: timeBlock.endDate,
            calendars: plannerCalendar.map { [$0] }
        )
        
        let events = eventStore.events(matching: predicate)
        return events.first { $0.title == eventTitle }
    }
    
    private func createEvent(for timeBlock: TimeBlock, in calendar: EKCalendar) async throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(Constants.timeBlockEventPrefix)\(timeBlock.title)"
        event.notes = timeBlock.description
        event.startDate = timeBlock.startDate
        event.endDate = timeBlock.endDate
        event.calendar = calendar
        
        // Add custom properties
        if let task = timeBlock.task {
            event.notes = (event.notes ?? "") + "\n\nЗадача: \(task.title)"
        }
        
        if let project = timeBlock.project {
            event.notes = (event.notes ?? "") + "\n\nПроект: \(project.name)"
        }
        
        // Set reminder
        let alarm = EKAlarm(relativeOffset: -15 * 60) // 15 minutes before
        event.addAlarm(alarm)
        
        try eventStore.save(event, span: .thisEvent)
        try eventStore.commit()
        
        // Update timeBlock with event identifier
        // This would require updating the TimeBlock model
        // timeBlock.calendarEventIdentifier = event.eventIdentifier
    }
    
    private func updateEvent(_ event: EKEvent, with timeBlock: TimeBlock) async throws {
        event.title = "\(Constants.timeBlockEventPrefix)\(timeBlock.title)"
        event.notes = timeBlock.description
        event.startDate = timeBlock.startDate
        event.endDate = timeBlock.endDate
        
        try eventStore.save(event, span: .thisEvent)
        try eventStore.commit()
    }
    
    private func syncProjectMilestones(_ project: Project) async throws {
        guard let projectCalendar = projectCalendars[project.id] else { return }
        
        // Create events for project start and end dates
        if let startDate = project.targetStartDate {
            let startEvent = EKEvent(eventStore: eventStore)
            startEvent.title = "\(Constants.projectEventPrefix)Начало: \(project.name)"
            startEvent.startDate = startDate
            startEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
            startEvent.calendar = projectCalendar
            startEvent.isAllDay = false
            
            try eventStore.save(startEvent, span: .thisEvent)
        }
        
        if let endDate = project.targetEndDate {
            let endEvent = EKEvent(eventStore: eventStore)
            endEvent.title = "\(Constants.projectEventPrefix)Дедлайн: \(project.name)"
            endEvent.startDate = endDate
            endEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: endDate) ?? endDate
            endEvent.calendar = projectCalendar
            endEvent.isAllDay = false
            
            try eventStore.save(endEvent, span: .thisEvent)
        }
        
        try eventStore.commit()
    }
}

// MARK: - EventKit Errors

enum EventKitError: LocalizedError {
    case accessDenied
    case syncNotEnabled
    case noCalendarSource
    case eventNotFound
    case calendarNotFound
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Доступ к календарю запрещен. Разрешите доступ в настройках."
        case .syncNotEnabled:
            return "Синхронизация с календарем отключена."
        case .noCalendarSource:
            return "Не удалось найти источник календаря."
        case .eventNotFound:
            return "Событие не найдено в календаре."
        case .calendarNotFound:
            return "Календарь не найден."
        }
    }
}

// MARK: - Calendar Sync Settings

struct CalendarSyncSettings {
    var isEnabled: Bool = false
    var syncTimeBlocks: Bool = true
    var syncProjects: Bool = true
    var createReminders: Bool = true
    var reminderOffset: TimeInterval = -15 * 60 // 15 minutes
    var useProjectColors: Bool = true
    var createProjectCalendars: Bool = false
}

// MARK: - Extensions

extension TimeBlock {
    var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    var durationInHours: Double {
        endDate.timeIntervalSince(startDate) / 3600
    }
}

extension EKEvent {
    var timeBlockIdentifier: UUID? {
        guard title.hasPrefix("timeblock_") else { return nil }
        // Extract UUID from title or notes if stored
        return nil // Would need custom implementation
    }
}

// MARK: - Mock Implementation

final class MockEventKitIntegrationService: EventKitIntegrationServiceProtocol {
    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var isCalendarSyncEnabled: Bool = false
    
    func requestCalendarAccess() async throws -> Bool {
        authorizationStatus = .fullAccess
        return true
    }
    
    func enableCalendarSync() async throws {
        isCalendarSyncEnabled = true
    }
    
    func disableCalendarSync() async throws {
        isCalendarSyncEnabled = false
    }
    
    func syncTimeBlockToCalendar(_ timeBlock: TimeBlock) async throws {
        // Mock implementation
    }
    
    func removeTimeBlockFromCalendar(_ timeBlock: TimeBlock) async throws {
        // Mock implementation
    }
    
    func updateTimeBlockInCalendar(_ timeBlock: TimeBlock) async throws {
        // Mock implementation
    }
    
    func syncProjectToCalendar(_ project: Project) async throws {
        // Mock implementation
    }
    
    func createProjectCalendar(_ project: Project) async throws -> EKCalendar {
        // Mock implementation - would need actual EKCalendar
        fatalError("Mock implementation")
    }
    
    func getCalendarEvents(for timeBlock: TimeBlock) async throws -> [EKEvent] {
        return []
    }
    
    func getConflictingEvents(for timeBlock: TimeBlock) async throws -> [EKEvent] {
        return []
    }
    
    func importEventsAsTimeBlocks(from calendar: EKCalendar, dateRange: DateInterval) async throws -> [TimeBlock] {
        return []
    }
} 