import Foundation
import UserNotifications
import UIKit

// MARK: - NotificationService Implementation
@Observable
final class NotificationService: NSObject, NotificationServiceProtocol {
    
    // MARK: - Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private(set) var isInitialized: Bool = false
    
    // Notification Categories
    private let habitReminderCategory = "HABIT_REMINDER"
    private let taskDeadlineCategory = "TASK_DEADLINE"
    private let budgetAlertCategory = "BUDGET_ALERT"
    private let achievementCategory = "ACHIEVEMENT_UNLOCK"
    
    // MARK: - Initialization
    override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        guard !isInitialized else { return }
        
        do {
            // Настраиваем категории уведомлений
            setupNotificationCategories()
            
            // Запрашиваем разрешения
            let granted = await requestPermission()
            
            if !granted {
                #if DEBUG
                print("Notification permissions not granted")
                #endif
            }
            
            isInitialized = true
            
            #if DEBUG
            print("NotificationService initialized successfully")
            #endif
            
        } catch {
            throw AppError.from(error)
        }
    }
    
    func cleanup() async {
        // Отменяем все запланированные уведомления
        await cancelAllNotifications()
        
        isInitialized = false
        
        #if DEBUG
        print("NotificationService cleaned up")
        #endif
    }
    
    // MARK: - Permission Management
    
    func requestPermission() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [
                .alert,
                .badge,
                .sound,
                .provisional,
                .criticalAlert
            ]
            
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            if granted {
                #if DEBUG
                print("Notification permissions granted")
                #endif
            }
            
            return granted
        } catch {
            #if DEBUG
            print("Failed to request notification permissions: \(error)")
            #endif
            return false
        }
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleHabitReminder(_ habitID: UUID, name: String, time: Date) async throws {
        let identifier = "habit-\(habitID.uuidString)"
        
        // Создаем контент уведомления
        let content = UNMutableNotificationContent()
        content.title = "Время для привычки"
        content.body = "Не забудьте выполнить: \(name)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = habitReminderCategory
        
        // Добавляем пользовательские данные
        content.userInfo = [
            "type": "habit_reminder",
            "habitID": habitID.uuidString,
            "habitName": name
        ]
        
        // Создаем триггер на основе времени
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        // Создаем запрос
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            
            #if DEBUG
            print("Scheduled habit reminder for \(name) at \(time)")
            #endif
            
        } catch {
            throw AppError.notificationSchedulingFailed("Failed to schedule habit reminder: \(error.localizedDescription)")
        }
    }
    
    func scheduleTaskDeadline(_ taskID: UUID, title: String, deadline: Date) async throws {
        let identifier = "task-\(taskID.uuidString)"
        
        // Планируем уведомление за час до дедлайна
        let notificationDate = deadline.addingTimeInterval(-3600) // -1 час
        
        // Проверяем, что время уведомления в будущем
        guard notificationDate > Date() else {
            throw AppError.notificationSchedulingFailed("Task deadline is too close or in the past")
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Приближается дедлайн задачи"
        content.body = "Через час истекает срок выполнения: \(title)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = taskDeadlineCategory
        
        content.userInfo = [
            "type": "task_deadline",
            "taskID": taskID.uuidString,
            "taskTitle": title,
            "deadline": ISO8601DateFormatter().string(from: deadline)
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: notificationDate.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            
            #if DEBUG
            print("Scheduled task deadline reminder for \(title)")
            #endif
            
        } catch {
            throw AppError.notificationSchedulingFailed("Failed to schedule task deadline: \(error.localizedDescription)")
        }
    }
    
    func scheduleBudgetAlert(_ budgetID: UUID, title: String, amount: Decimal) async throws {
        let identifier = "budget-\(budgetID.uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = "Превышение бюджета"
        content.body = "Бюджет '\(title)' превышен на \(amount) ₽"
        content.sound = .defaultCritical
        content.badge = 1
        content.categoryIdentifier = budgetAlertCategory
        
        content.userInfo = [
            "type": "budget_alert",
            "budgetID": budgetID.uuidString,
            "budgetTitle": title,
            "excessAmount": NSDecimalNumber(decimal: amount).stringValue
        ]
        
        // Немедленное уведомление
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            
            #if DEBUG
            print("Scheduled budget alert for \(title)")
            #endif
            
        } catch {
            throw AppError.notificationSchedulingFailed("Failed to schedule budget alert: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Achievement Notifications
    
    func scheduleAchievementUnlock(_ achievementID: UUID, title: String, description: String) async throws {
        let identifier = "achievement-\(achievementID.uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = "🏆 Достижение разблокировано!"
        content.body = "\(title): \(description)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = achievementCategory
        
        content.userInfo = [
            "type": "achievement_unlock",
            "achievementID": achievementID.uuidString,
            "achievementTitle": title
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            
            #if DEBUG
            print("Scheduled achievement notification for \(title)")
            #endif
            
        } catch {
            throw AppError.notificationSchedulingFailed("Failed to schedule achievement notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(for identifier: String) async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        
        #if DEBUG
        print("Cancelled notification: \(identifier)")
        #endif
    }
    
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        
        #if DEBUG
        print("Cancelled all notifications")
        #endif
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    // MARK: - Notification Response Handling
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        guard let type = userInfo["type"] as? String else {
            #if DEBUG
            print("Unknown notification type")
            #endif
            return
        }
        
        switch type {
        case "habit_reminder":
            await handleHabitReminderResponse(response, userInfo: userInfo)
        case "task_deadline":
            await handleTaskDeadlineResponse(response, userInfo: userInfo)
        case "budget_alert":
            await handleBudgetAlertResponse(response, userInfo: userInfo)
        case "achievement_unlock":
            await handleAchievementResponse(response, userInfo: userInfo)
        default:
            #if DEBUG
            print("Unhandled notification type: \(type)")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationCategories() {
        // Действия для напоминаний о привычках
        let markHabitCompleteAction = UNNotificationAction(
            identifier: "MARK_HABIT_COMPLETE",
            title: "Отметить выполненной",
            options: [.foreground]
        )
        
        let postponeHabitAction = UNNotificationAction(
            identifier: "POSTPONE_HABIT",
            title: "Напомнить позже",
            options: []
        )
        
        let habitCategory = UNNotificationCategory(
            identifier: habitReminderCategory,
            actions: [markHabitCompleteAction, postponeHabitAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Действия для дедлайнов задач
        let markTaskCompleteAction = UNNotificationAction(
            identifier: "MARK_TASK_COMPLETE",
            title: "Отметить выполненной",
            options: [.foreground]
        )
        
        let openTaskAction = UNNotificationAction(
            identifier: "OPEN_TASK",
            title: "Открыть задачу",
            options: [.foreground]
        )
        
        let taskCategory = UNNotificationCategory(
            identifier: taskDeadlineCategory,
            actions: [markTaskCompleteAction, openTaskAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Действия для бюджетных уведомлений
        let viewBudgetAction = UNNotificationAction(
            identifier: "VIEW_BUDGET",
            title: "Просмотреть бюджет",
            options: [.foreground]
        )
        
        let budgetCategory = UNNotificationCategory(
            identifier: budgetAlertCategory,
            actions: [viewBudgetAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Действия для достижений
        let viewAchievementAction = UNNotificationAction(
            identifier: "VIEW_ACHIEVEMENT",
            title: "Посмотреть",
            options: [.foreground]
        )
        
        let achievementCategory = UNNotificationCategory(
            identifier: achievementCategory,
            actions: [viewAchievementAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Регистрируем категории
        notificationCenter.setNotificationCategories([
            habitCategory,
            taskCategory,
            budgetCategory,
            achievementCategory
        ])
        
        #if DEBUG
        print("Notification categories configured")
        #endif
    }
    
    // MARK: - Response Handlers
    
    private func handleHabitReminderResponse(_ response: UNNotificationResponse, userInfo: [AnyHashable: Any]) async {
        guard let habitIDString = userInfo["habitID"] as? String,
              let habitID = UUID(uuidString: habitIDString) else {
            return
        }
        
        switch response.actionIdentifier {
        case "MARK_HABIT_COMPLETE":
            // Здесь будет интеграция с DataService для отметки привычки
            #if DEBUG
            print("Marking habit \(habitID) as complete")
            #endif
            
        case "POSTPONE_HABIT":
            // Перепланируем уведомление на 30 минут позже
            if let habitName = userInfo["habitName"] as? String {
                let newTime = Date().addingTimeInterval(1800) // +30 минут
                try? await scheduleHabitReminder(habitID, name: habitName, time: newTime)
            }
            
        default:
            break
        }
    }
    
    private func handleTaskDeadlineResponse(_ response: UNNotificationResponse, userInfo: [AnyHashable: Any]) async {
        guard let taskIDString = userInfo["taskID"] as? String,
              let taskID = UUID(uuidString: taskIDString) else {
            return
        }
        
        switch response.actionIdentifier {
        case "MARK_TASK_COMPLETE":
            #if DEBUG
            print("Marking task \(taskID) as complete")
            #endif
            
        case "OPEN_TASK":
            // Отправляем уведомление для навигации к задаче
            NotificationCenter.default.post(
                name: .openTask,
                object: nil,
                userInfo: ["taskID": taskID]
            )
            
        default:
            break
        }
    }
    
    private func handleBudgetAlertResponse(_ response: UNNotificationResponse, userInfo: [AnyHashable: Any]) async {
        guard let budgetIDString = userInfo["budgetID"] as? String,
              let budgetID = UUID(uuidString: budgetIDString) else {
            return
        }
        
        switch response.actionIdentifier {
        case "VIEW_BUDGET":
            NotificationCenter.default.post(
                name: .openBudget,
                object: nil,
                userInfo: ["budgetID": budgetID]
            )
            
        default:
            break
        }
    }
    
    private func handleAchievementResponse(_ response: UNNotificationResponse, userInfo: [AnyHashable: Any]) async {
        guard let achievementIDString = userInfo["achievementID"] as? String,
              let achievementID = UUID(uuidString: achievementIDString) else {
            return
        }
        
        switch response.actionIdentifier {
        case "VIEW_ACHIEVEMENT":
            NotificationCenter.default.post(
                name: .openAchievement,
                object: nil,
                userInfo: ["achievementID": achievementID]
            )
            
        default:
            break
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Показываем уведомления даже когда приложение активно
        completionHandler([.banner, .sound, .badge])
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
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        // Открываем настройки приложения
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openTask = Notification.Name("openTask")
    static let openBudget = Notification.Name("openBudget")
    static let openAchievement = Notification.Name("openAchievement")
    static let habitCompleted = Notification.Name("habitCompleted")
    static let taskCompleted = Notification.Name("taskCompleted")
}

// MARK: - NotificationService Factory

extension NotificationService {
    
    /// Создает NotificationService для тестирования (без реальных уведомлений)
    static func testing() -> NotificationService {
        return NotificationService()
    }
} 