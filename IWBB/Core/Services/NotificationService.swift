import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func scheduleTaskNotification(for task: Task, minutesBefore: Int) async throws
    func scheduleTaskReminder(for task: Task, at date: Date) async throws
    func cancelNotification(for taskId: UUID) async
    func cancelAllNotifications() async
    func updateTaskNotifications(for task: Task) async
    func getPermissionStatus() async -> UNAuthorizationStatus
    func handleNotificationResponse(_ response: UNNotificationResponse) async
}

final class NotificationService: NSObject, NotificationServiceProtocol {
    static let shared = NotificationService()
    
    private let center = UNUserNotificationCenter.current()
    private var taskService: TaskService?
    
    // Notification categories
    private let taskDueCategory = "TASK_DUE_CATEGORY"
    private let taskReminderCategory = "TASK_REMINDER_CATEGORY"
    
    override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
    }
    
    func setTaskService(_ taskService: TaskService) {
        self.taskService = taskService
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            
            if granted {
                #if canImport(UIKit)
                await UIApplication.shared.registerForRemoteNotifications()
                #endif
            }
            
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    func getPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Task Notifications
    
    func scheduleTaskNotification(for task: Task, minutesBefore: Int = 0) async throws {
        guard let dueDate = task.dueDate else { return }
        
        let notificationDate = Calendar.current.date(
            byAdding: .minute,
            value: -minutesBefore,
            to: dueDate
        ) ?? dueDate
        
        // Don't schedule notifications for past dates
        guard notificationDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Дедлайн задачи"
        content.body = task.title
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = taskDueCategory
        
        // Add user info for handling
        content.userInfo = [
            "taskId": task.id.uuidString,
            "taskTitle": task.title,
            "notificationType": "due",
            "minutesBefore": minutesBefore
        ]
        
        // Add custom content if available
        if !task.taskDescription.isEmpty {
            content.subtitle = task.taskDescription
        }
        
        // Set priority based on task priority
        switch task.priority {
        case .urgent:
            content.interruptionLevel = .critical
        case .high:
            content.interruptionLevel = .active
        default:
            content.interruptionLevel = .passive
        }
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: notificationDate
            ),
            repeats: false
        )
        
        // Create request
        let identifier = "task_due_\(task.id.uuidString)_\(minutesBefore)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
        print("Scheduled notification for task '\(task.title)' at \(notificationDate)")
    }
    
    func scheduleTaskReminder(for task: Task, at date: Date) async throws {
        guard date > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Напоминание о задаче"
        content.body = task.title
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = taskReminderCategory
        
        content.userInfo = [
            "taskId": task.id.uuidString,
            "taskTitle": task.title,
            "notificationType": "reminder"
        ]
        
        if !task.taskDescription.isEmpty {
            content.subtitle = task.taskDescription
        }
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            ),
            repeats: false
        )
        
        let identifier = "task_reminder_\(task.id.uuidString)_\(Int(date.timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
        print("Scheduled reminder for task '\(task.title)' at \(date)")
    }
    
    func updateTaskNotifications(for task: Task) async {
        // Cancel existing notifications for this task
        await cancelNotification(for: task.id)
        
        // Don't schedule notifications for completed tasks
        guard !task.isCompleted else { return }
        
        // Schedule new notifications if task has due date and notifications are enabled
        guard task.hasNotifications, let dueDate = task.dueDate else { return }
        
        do {
            // Schedule multiple notifications based on priority
            let notificationOffsets = getNotificationOffsets(for: task.priority)
            
            for offset in notificationOffsets {
                try await scheduleTaskNotification(for: task, minutesBefore: offset)
            }
            
            print("Updated notifications for task: \(task.title)")
        } catch {
            print("Failed to update notifications for task \(task.title): \(error)")
        }
    }
    
    func cancelNotification(for taskId: UUID) async {
        let identifiers = await center.pendingNotificationRequests()
            .filter { $0.identifier.contains(taskId.uuidString) }
            .map { $0.identifier }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        
        print("Cancelled \(identifiers.count) notifications for task \(taskId)")
    }
    
    func cancelAllNotifications() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        
        print("Cancelled all notifications")
    }
    
    // MARK: - Recurring Task Notifications
    
    func scheduleRecurringTaskNotifications(for task: Task) async throws {
        guard task.isRecurring,
              let pattern = task.recurringPattern,
              let dueDate = task.dueDate else { return }
        
        // Schedule notifications for the next few occurrences
        let occurrences = generateRecurringDates(from: dueDate, pattern: pattern, count: 10)
        
        for (index, occurrence) in occurrences.enumerated() {
            let notificationOffsets = getNotificationOffsets(for: task.priority)
            
            for offset in notificationOffsets {
                let notificationDate = Calendar.current.date(
                    byAdding: .minute,
                    value: -offset,
                    to: occurrence
                ) ?? occurrence
                
                guard notificationDate > Date() else { continue }
                
                let content = UNMutableNotificationContent()
                content.title = "Повторяющаяся задача"
                content.body = task.title
                content.sound = .default
                content.badge = 1
                content.categoryIdentifier = taskDueCategory
                
                content.userInfo = [
                    "taskId": task.id.uuidString,
                    "taskTitle": task.title,
                    "notificationType": "recurring",
                    "occurrenceIndex": index,
                    "minutesBefore": offset
                ]
                
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: notificationDate
                    ),
                    repeats: false
                )
                
                let identifier = "task_recurring_\(task.id.uuidString)_\(index)_\(offset)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                
                try await center.add(request)
            }
        }
        
        print("Scheduled recurring notifications for task: \(task.title)")
    }
    
    // MARK: - Notification Response Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        guard let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            return
        }
        
        switch response.actionIdentifier {
        case "COMPLETE_TASK":
            await handleCompleteTaskAction(taskId: taskId)
            
        case "SNOOZE_TASK":
            await handleSnoozeTaskAction(taskId: taskId)
            
        case "VIEW_TASK":
            await handleViewTaskAction(taskId: taskId)
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            await handleViewTaskAction(taskId: taskId)
            
        default:
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupNotificationCategories() {
        // Task Due Category
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Завершить",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_TASK",
            title: "Отложить",
            options: []
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW_TASK",
            title: "Открыть",
            options: [.foreground]
        )
        
        let dueCategory = UNNotificationCategory(
            identifier: taskDueCategory,
            actions: [completeAction, snoozeAction, viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Task Reminder Category
        let reminderCategory = UNNotificationCategory(
            identifier: taskReminderCategory,
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([dueCategory, reminderCategory])
    }
    
    private func getNotificationOffsets(for priority: TaskPriority) -> [Int] {
        switch priority {
        case .urgent:
            return [0, 15, 60, 1440] // Now, 15 min, 1 hour, 1 day
        case .high:
            return [0, 30, 1440] // Now, 30 min, 1 day
        case .normal:
            return [0, 1440] // Now, 1 day
        case .low:
            return [1440] // 1 day
        }
    }
    
    private func generateRecurringDates(from startDate: Date, pattern: RecurringPattern, count: Int) -> [Date] {
        var dates: [Date] = []
        var currentDate = startDate
        
        for _ in 0..<count {
            dates.append(currentDate)
            
            switch pattern {
            case .daily:
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .weekly:
                currentDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case .monthly:
                currentDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            case .yearly:
                currentDate = Calendar.current.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
            case .custom(let interval):
                currentDate = Calendar.current.date(byAdding: .day, value: interval, to: currentDate) ?? currentDate
            }
        }
        
        return dates
    }
    
    // MARK: - Action Handlers
    
    private func handleCompleteTaskAction(taskId: UUID) async {
        guard let taskService = taskService else { return }
        
        do {
            await taskService.markTaskCompleted(taskId: taskId)
            await cancelNotification(for: taskId)
            print("Completed task \(taskId) from notification")
        } catch {
            print("Failed to complete task from notification: \(error)")
        }
    }
    
    private func handleSnoozeTaskAction(taskId: UUID) async {
        // Reschedule notification for 15 minutes later
        let snoozeDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        
        guard let taskService = taskService,
              let task = await taskService.getTask(id: taskId) else { return }
        
        do {
            try await scheduleTaskReminder(for: task, at: snoozeDate)
            print("Snoozed task \(taskId) until \(snoozeDate)")
        } catch {
            print("Failed to snooze task: \(error)")
        }
    }
    
    private func handleViewTaskAction(taskId: UUID) async {
        // Post notification to open task detail view
        NotificationCenter.default.post(
            name: .openTaskDetail,
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await handleNotificationResponse(response)
            completionHandler()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTaskDetail = Notification.Name("openTaskDetail")
    static let taskNotificationScheduled = Notification.Name("taskNotificationScheduled")
    static let taskNotificationCancelled = Notification.Name("taskNotificationCancelled")
}

// MARK: - Mock Implementation

final class MockNotificationService: NotificationServiceProtocol {
    private var scheduledNotifications: [String: Date] = [:]
    
    func requestPermission() async -> Bool {
        print("Mock: Requesting notification permission")
        return true
    }
    
    func scheduleTaskNotification(for task: Task, minutesBefore: Int) async throws {
        guard let dueDate = task.dueDate else { return }
        let notificationDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: dueDate) ?? dueDate
        scheduledNotifications[task.id.uuidString] = notificationDate
        print("Mock: Scheduled notification for task '\(task.title)' at \(notificationDate)")
    }
    
    func scheduleTaskReminder(for task: Task, at date: Date) async throws {
        scheduledNotifications["reminder_\(task.id.uuidString)"] = date
        print("Mock: Scheduled reminder for task '\(task.title)' at \(date)")
    }
    
    func cancelNotification(for taskId: UUID) async {
        scheduledNotifications.removeValue(forKey: taskId.uuidString)
        print("Mock: Cancelled notification for task \(taskId)")
    }
    
    func cancelAllNotifications() async {
        scheduledNotifications.removeAll()
        print("Mock: Cancelled all notifications")
    }
    
    func updateTaskNotifications(for task: Task) async {
        await cancelNotification(for: task.id)
        
        guard !task.isCompleted, task.hasNotifications, let _ = task.dueDate else { return }
        
        do {
            try await scheduleTaskNotification(for: task, minutesBefore: 0)
            try await scheduleTaskNotification(for: task, minutesBefore: 1440)
        } catch {
            print("Mock: Failed to update notifications: \(error)")
        }
    }
    
    func getPermissionStatus() async -> UNAuthorizationStatus {
        return .authorized
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        print("Mock: Handling notification response: \(response.actionIdentifier)")
    }
} 