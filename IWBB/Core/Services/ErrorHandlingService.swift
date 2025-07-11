import Foundation
import OSLog
import UIKit

// MARK: - ErrorHandlingService Implementation
@Observable
final class ErrorHandlingService: ErrorHandlingServiceProtocol {
    
    // MARK: - Properties
    private(set) var isInitialized: Bool = false
    
    // Logging
    private let logger = Logger(subsystem: "com.plannerapp.error", category: "ErrorHandling")
    private let errorQueue = DispatchQueue(label: "com.plannerapp.error.queue", qos: .utility)
    
    // Error Tracking
    private var errorHistory: [ErrorEntry] = []
    private let maxErrorHistoryCount = 100
    
    // Recovery Handlers
    private var recoveryHandlers: [String: () async -> Bool] = [:]
    
    // Error Presentation Delegate
    weak var presentationDelegate: ErrorPresentationDelegate?
    
    // MARK: - Initialization
    init() {
        setupDefaultRecoveryHandlers()
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Настраиваем обработчики восстановления
        setupDefaultRecoveryHandlers()
        
        // Очищаем старую историю ошибок
        cleanupErrorHistory()
        
        isInitialized = true
        
        #if DEBUG
        print("ErrorHandlingService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        // Сохраняем критически важные ошибки перед очисткой
        await saveErrorHistory()
        
        // Очищаем обработчики
        recoveryHandlers.removeAll()
        errorHistory.removeAll()
        
        isInitialized = false
        
        #if DEBUG
        print("ErrorHandlingService cleaned up")
        #endif
    }
    
    // MARK: - Error Processing
    
    func handle(_ error: Error, context: ErrorContext? = nil) async {
        let appError = AppError.from(error)
        await handle(appError, context: context)
    }
    
    func handle(_ error: AppError, context: ErrorContext? = nil) async {
        // Создаем запись об ошибке
        let errorEntry = ErrorEntry(
            error: error,
            context: context,
            timestamp: Date(),
            deviceInfo: collectDeviceInfo()
        )
        
        // Добавляем в историю
        await addToErrorHistory(errorEntry)
        
        // Логируем ошибку
        logError(error, context: context)
        
        // Логируем критические ошибки
        if error.severity == .critical {
            logCriticalError(error, context: context)
        }
        
        // Пытаемся восстановиться автоматически
        let recovered = await attemptRecovery(for: error)
        
        if !recovered {
            // Если автоматическое восстановление не удалось, показываем пользователю
            await presentError(error, in: .alert)
        }
    }
    
    // MARK: - Error Presentation
    
    func presentError(_ error: AppError, in view: ErrorPresentationView) async {
        await MainActor.run {
            switch view {
            case .alert:
                presentErrorAlert(error) { }
            case .banner:
                presentErrorBanner(error)
            case .toast:
                presentErrorToast(error)
            case .modal:
                presentErrorModal(error)
            }
        }
    }
    
    func presentErrorAlert(_ error: AppError, completion: @escaping () -> Void) async {
        await MainActor.run {
            guard let presentationDelegate = presentationDelegate else {
                #if DEBUG
                print("No presentation delegate set for error: \(error.localizedDescription)")
                #endif
                completion()
                return
            }
            
            let recoveryOptions = getRecoveryOptions(for: error)
            presentationDelegate.presentAlert(
                title: "Ошибка",
                message: error.localizedDescription,
                recoveryOptions: recoveryOptions,
                completion: completion
            )
        }
    }
    
    // MARK: - Error Logging
    
    func logError(_ error: Error, context: ErrorContext? = nil) {
        let appError = AppError.from(error)
        
        errorQueue.async {
            switch appError.severity {
            case .low:
                self.logger.info("Low severity error: \(appError.localizedDescription ?? "Unknown")")
            case .medium:
                self.logger.notice("Medium severity error: \(appError.localizedDescription ?? "Unknown")")
            case .high:
                self.logger.error("High severity error: \(appError.localizedDescription ?? "Unknown")")
            case .critical:
                self.logger.fault("Critical error: \(appError.localizedDescription ?? "Unknown")")
            }
            
            if let context = context {
                self.logger.info("Error context: \(context)")
            }
        }
    }
    
    func logCriticalError(_ error: Error, context: ErrorContext? = nil) {
        let appError = AppError.from(error)
        
        errorQueue.async {
            self.logger.fault("CRITICAL ERROR: \(appError.localizedDescription ?? "Unknown")")
            
            if let context = context {
                self.logger.fault("Critical error context: \(context)")
            }
            
            // В production здесь можно отправлять в Crashlytics или другой сервис
            #if DEBUG
            print("🚨 CRITICAL ERROR: \(appError.localizedDescription ?? "Unknown")")
            if let context = context {
                print("Context: \(context)")
            }
            #endif
        }
    }
    
    // MARK: - Recovery Operations
    
    func attemptRecovery(for error: AppError) async -> Bool {
        // Проверяем, можно ли восстановиться автоматически
        guard error.canRetry else {
            return false
        }
        
        let recoveryKey = String(describing: type(of: error))
        
        if let recoveryHandler = recoveryHandlers[recoveryKey] {
            do {
                let success = await recoveryHandler()
                
                if success {
                    logger.info("Successfully recovered from error: \(error.localizedDescription ?? "Unknown")")
                }
                
                return success
            } catch {
                logger.error("Recovery failed for error: \(error.localizedDescription ?? "Unknown")")
                return false
            }
        }
        
        return false
    }
    
    func getRecoveryOptions(for error: AppError) -> [RecoveryOption] {
        var options: [RecoveryOption] = []
        
        // Базовые опции восстановления
        if error.canRetry {
            options.append(RecoveryOption(
                title: "Повторить",
                description: "Попробовать выполнить операцию снова",
                action: .retry
            ))
        }
        
        // Специфичные опции в зависимости от типа ошибки
        switch error {
        case .networkUnavailable:
            options.append(RecoveryOption(
                title: "Повторить через 5 сек",
                description: "Автоматически повторить когда появится соединение",
                action: .retryWithDelay(5.0)
            ))
            
        case .cloudKitAccountNotAvailable:
            options.append(RecoveryOption(
                title: "Открыть настройки",
                description: "Перейти в настройки для входа в iCloud",
                action: .openSettings
            ))
            
        case .notificationPermissionDenied:
            options.append(RecoveryOption(
                title: "Разрешить уведомления",
                description: "Открыть настройки приложения",
                action: .openSettings
            ))
            
        case .dataCorrupted, .migrationFailed:
            options.append(RecoveryOption(
                title: "Сбросить данные",
                description: "Удалить поврежденные данные и начать заново",
                action: .resetData,
                isDestructive: true
            ))
            
        default:
            break
        }
        
        // Всегда добавляем опцию связи с поддержкой для критических ошибок
        if error.severity == .critical || error.severity == .high {
            options.append(RecoveryOption(
                title: "Связаться с поддержкой",
                description: "Отправить отчет об ошибке разработчикам",
                action: .contact_support
            ))
        }
        
        // Опция закрытия
        options.append(RecoveryOption(
            title: "Закрыть",
            description: "Закрыть это сообщение",
            action: .dismissError
        ))
        
        return options
    }
    
    // MARK: - Error History Management
    
    private func addToErrorHistory(_ entry: ErrorEntry) async {
        errorQueue.async {
            self.errorHistory.append(entry)
            
            // Ограничиваем размер истории
            if self.errorHistory.count > self.maxErrorHistoryCount {
                self.errorHistory.removeFirst(self.errorHistory.count - self.maxErrorHistoryCount)
            }
        }
    }
    
    private func cleanupErrorHistory() {
        errorQueue.async {
            // Удаляем ошибки старше 7 дней
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            self.errorHistory.removeAll { $0.timestamp < cutoffDate }
        }
    }
    
    private func saveErrorHistory() async {
        // В production здесь можно сохранять историю ошибок
        // для анализа или отправки в службу поддержки
        
        errorQueue.async {
            let criticalErrors = self.errorHistory.filter { $0.error.severity == .critical }
            
            if !criticalErrors.isEmpty {
                #if DEBUG
                print("Found \(criticalErrors.count) critical errors in history")
                #endif
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultRecoveryHandlers() {
        // Обработчик для сетевых ошибок
        recoveryHandlers["networkUnavailable"] = {
            // Проверяем доступность сети
            return await self.checkNetworkConnectivity()
        }
        
        // Обработчик для ошибок CloudKit
        recoveryHandlers["cloudKitUnavailable"] = {
            // Пытаемся переподключиться к CloudKit
            return await self.retryCloudKitConnection()
        }
        
        // Обработчик для ошибок данных
        recoveryHandlers["dataCorrupted"] = {
            // Пытаемся восстановить данные из резервной копии
            return await self.attemptDataRecovery()
        }
    }
    
    private func checkNetworkConnectivity() async -> Bool {
        // Здесь будет реальная проверка сетевого соединения
        // Пока возвращаем false для демонстрации
        return false
    }
    
    private func retryCloudKitConnection() async -> Bool {
        // Здесь будет попытка переподключения к CloudKit
        return false
    }
    
    private func attemptDataRecovery() async -> Bool {
        // Здесь будет попытка восстановления данных
        return false
    }
    
    private func collectDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            memoryUsage: getMemoryUsage(),
            diskSpace: getDiskSpace()
        )
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
        
        return 0.0
    }
    
    private func getDiskSpace() -> Double {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSpace.doubleValue / 1024.0 / 1024.0 / 1024.0 // GB
            }
        } catch {
            // Ignore errors
        }
        
        return 0.0
    }
    
    // MARK: - Error Presentation Methods
    
    private func presentErrorBanner(_ error: AppError) {
        // Здесь будет показ баннера с ошибкой
        #if DEBUG
        print("🟡 Banner Error: \(error.localizedDescription ?? "Unknown")")
        #endif
    }
    
    private func presentErrorToast(_ error: AppError) {
        // Здесь будет показ toast с ошибкой
        #if DEBUG
        print("🟤 Toast Error: \(error.localizedDescription ?? "Unknown")")
        #endif
    }
    
    private func presentErrorModal(_ error: AppError) {
        // Здесь будет показ модального окна с ошибкой
        #if DEBUG
        print("🔴 Modal Error: \(error.localizedDescription ?? "Unknown")")
        #endif
    }
}

// MARK: - Supporting Types

struct ErrorEntry {
    let error: AppError
    let context: ErrorContext?
    let timestamp: Date
    let deviceInfo: DeviceInfo
}

struct DeviceInfo {
    let model: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
    let memoryUsage: Double // MB
    let diskSpace: Double // GB
}

// MARK: - Error Presentation Delegate

protocol ErrorPresentationDelegate: AnyObject {
    func presentAlert(
        title: String,
        message: String,
        recoveryOptions: [RecoveryOption],
        completion: @escaping () -> Void
    )
}

// MARK: - ErrorHandlingService Extensions

extension ErrorHandlingService {
    
    // MARK: - Convenience Methods
    
    /// Обрабатывает Result с ошибкой
    func handleResult<T>(_ result: Result<T, AppError>, context: ErrorContext? = nil) async -> T? {
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            await handle(error, context: context)
            return nil
        }
    }
    
    /// Выполняет операцию с обработкой ошибок
    func performWithErrorHandling<T>(
        context: ErrorContext? = nil,
        operation: () async throws -> T
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            await handle(error, context: context)
            return nil
        }
    }
    
    /// Возвращает количество ошибок в истории
    var errorHistoryCount: Int {
        return errorQueue.sync {
            return errorHistory.count
        }
    }
    
    /// Возвращает критические ошибки из истории
    func getCriticalErrors() async -> [ErrorEntry] {
        return await withCheckedContinuation { continuation in
            errorQueue.async {
                let criticalErrors = self.errorHistory.filter { $0.error.severity == .critical }
                continuation.resume(returning: criticalErrors)
            }
        }
    }
    
    /// Экспортирует историю ошибок для отправки в поддержку
    func exportErrorHistory() async -> String {
        return await withCheckedContinuation { continuation in
            errorQueue.async {
                let errorReport = self.errorHistory.map { entry in
                    """
                    Timestamp: \(entry.timestamp)
                    Error: \(entry.error.localizedDescription ?? "Unknown")
                    Severity: \(entry.error.severity.description)
                    Context: \(entry.context?.description ?? "None")
                    Device: \(entry.deviceInfo.model) \(entry.deviceInfo.systemVersion)
                    App: \(entry.deviceInfo.appVersion) (\(entry.deviceInfo.buildNumber))
                    Memory: \(String(format: "%.2f", entry.deviceInfo.memoryUsage)) MB
                    ---
                    """
                }.joined(separator: "\n")
                
                continuation.resume(returning: errorReport)
            }
        }
    }
}

// MARK: - ErrorHandlingService Factory

extension ErrorHandlingService {
    
    /// Создает ErrorHandlingService для тестирования
    static func testing() -> ErrorHandlingService {
        return ErrorHandlingService()
    }
}

// MARK: - Extensions

extension ErrorContext {
    var description: String {
        switch self {
        case .dataOperation(let details):
            return "Data Operation: \(details)"
        case .networkOperation(let details):
            return "Network Operation: \(details)"
        case .userAction(let details):
            return "User Action: \(details)"
        case .backgroundTask(let details):
            return "Background Task: \(details)"
        case .initialization(let details):
            return "Initialization: \(details)"
        }
    }
} 