import Foundation
import SwiftData
import CloudKit

// MARK: - App Error Types
enum AppError: Error, LocalizedError, Equatable {
    // Data Errors
    case dataCorrupted(String)
    case modelNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    case fetchFailed(String)
    case migrationFailed(String)
    
    // CloudKit Sync Errors
    case cloudKitUnavailable
    case cloudKitQuotaExceeded
    case cloudKitAccountNotAvailable
    case syncFailed(String)
    case networkUnavailable
    
    // Authentication Errors
    case authenticationFailed(String)
    case biometricAuthenticationFailed
    case permissionDenied(String)
    
    // Notification Errors
    case notificationPermissionDenied
    case notificationSchedulingFailed(String)
    
    // Validation Errors
    case invalidInput(String)
    case validationFailed([ValidationError])
    
    // System Errors
    case fileSystemError(String)
    case memoryWarning
    case backgroundTaskExpired
    
    // Business Logic Errors
    case habitLimitExceeded(Int)
    case taskDeadlinePassed
    case budgetExceeded(Decimal)
    case goalAlreadyCompleted
    
    // Generic Errors
    case unknown(Error)
    case serviceUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        // Data Errors
        case .dataCorrupted(let details):
            return "Данные повреждены: \(details)"
        case .modelNotFound(let model):
            return "Объект \(model) не найден"
        case .saveFailed(let reason):
            return "Не удалось сохранить: \(reason)"
        case .deleteFailed(let reason):
            return "Не удалось удалить: \(reason)"
        case .fetchFailed(let reason):
            return "Не удалось загрузить данные: \(reason)"
        case .migrationFailed(let reason):
            return "Ошибка миграции данных: \(reason)"
            
        // CloudKit Sync Errors
        case .cloudKitUnavailable:
            return "iCloud недоступен. Проверьте подключение к интернету и настройки iCloud"
        case .cloudKitQuotaExceeded:
            return "Превышена квота хранилища iCloud"
        case .cloudKitAccountNotAvailable:
            return "Аккаунт iCloud недоступен. Войдите в iCloud в настройках устройства"
        case .syncFailed(let reason):
            return "Ошибка синхронизации: \(reason)"
        case .networkUnavailable:
            return "Нет подключения к интернету"
            
        // Authentication Errors
        case .authenticationFailed(let reason):
            return "Ошибка аутентификации: \(reason)"
        case .biometricAuthenticationFailed:
            return "Не удалось пройти биометрическую аутентификацию"
        case .permissionDenied(let permission):
            return "Доступ запрещен: \(permission)"
            
        // Notification Errors
        case .notificationPermissionDenied:
            return "Разрешение на уведомления не предоставлено"
        case .notificationSchedulingFailed(let reason):
            return "Не удалось запланировать уведомление: \(reason)"
            
        // Validation Errors
        case .invalidInput(let field):
            return "Некорректные данные в поле: \(field)"
        case .validationFailed(let errors):
            return "Ошибки валидации: \(errors.map { $0.message }.joined(separator: ", "))"
            
        // System Errors
        case .fileSystemError(let reason):
            return "Ошибка файловой системы: \(reason)"
        case .memoryWarning:
            return "Недостаточно памяти"
        case .backgroundTaskExpired:
            return "Время выполнения фоновой задачи истекло"
            
        // Business Logic Errors
        case .habitLimitExceeded(let limit):
            return "Превышен лимит привычек (\(limit))"
        case .taskDeadlinePassed:
            return "Срок выполнения задачи уже прошел"
        case .budgetExceeded(let amount):
            return "Превышен бюджет на \(amount) ₽"
        case .goalAlreadyCompleted:
            return "Цель уже достигнута"
            
        // Generic Errors
        case .unknown(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        case .serviceUnavailable(let service):
            return "Сервис \(service) недоступен"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Проверьте подключение к интернету и повторите попытку"
        case .cloudKitAccountNotAvailable:
            return "Войдите в iCloud в настройках устройства"
        case .notificationPermissionDenied:
            return "Разрешите уведомления в настройках приложения"
        case .memoryWarning:
            return "Закройте другие приложения и повторите попытку"
        case .biometricAuthenticationFailed:
            return "Используйте пароль для входа"
        default:
            return "Попробуйте еще раз или обратитесь в поддержку"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .dataCorrupted, .migrationFailed, .memoryWarning:
            return .critical
        case .saveFailed, .deleteFailed, .syncFailed, .authenticationFailed:
            return .high
        case .fetchFailed, .networkUnavailable, .validationFailed:
            return .medium
        case .invalidInput, .notificationSchedulingFailed:
            return .low
        default:
            return .medium
        }
    }
    
    // Helper method to create AppError from system errors
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Map system errors to AppError
        if let ckError = error as? CKError {
            return mapCloudKitError(ckError)
        }
        
        return .unknown(error)
    }
    
    private static func mapCloudKitError(_ error: CKError) -> AppError {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .quotaExceeded:
            return .cloudKitQuotaExceeded
        case .notAuthenticated:
            return .cloudKitAccountNotAvailable
        case .serviceUnavailable:
            return .cloudKitUnavailable
        default:
            return .syncFailed(error.localizedDescription)
        }
    }
}

// MARK: - Error Severity
enum ErrorSeverity: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var description: String {
        switch self {
        case .low: return "Низкая"
        case .medium: return "Средняя"
        case .high: return "Высокая"
        case .critical: return "Критическая"
        }
    }
}

// MARK: - Validation Error
struct ValidationError: Error, Equatable {
    let field: String
    let message: String
    let code: ValidationErrorCode
    
    init(field: String, message: String, code: ValidationErrorCode = .invalid) {
        self.field = field
        self.message = message
        self.code = code
    }
}

enum ValidationErrorCode: String, CaseIterable {
    case required = "required"
    case invalid = "invalid"
    case tooShort = "too_short"
    case tooLong = "too_long"
    case outOfRange = "out_of_range"
    case duplicateValue = "duplicate_value"
}

// MARK: - Recovery Options
struct RecoveryOption {
    let title: String
    let description: String
    let action: RecoveryAction
    let isDestructive: Bool
    
    init(title: String, description: String, action: RecoveryAction, isDestructive: Bool = false) {
        self.title = title
        self.description = description
        self.action = action
        self.isDestructive = isDestructive
    }
}

enum RecoveryAction {
    case retry
    case retryWithDelay(TimeInterval)
    case openSettings
    case resetData
    case contact_support
    case dismissError
    case custom(() async -> Void)
}

// MARK: - Error Extensions
extension AppError {
    var canRetry: Bool {
        switch self {
        case .networkUnavailable, .cloudKitUnavailable, .syncFailed, .fetchFailed:
            return true
        case .dataCorrupted, .authenticationFailed, .permissionDenied:
            return false
        default:
            return true
        }
    }
    
    var shouldLogToCrashlytics: Bool {
        return severity == .critical || severity == .high
    }
    
    var requiresUserAction: Bool {
        switch self {
        case .cloudKitAccountNotAvailable, .notificationPermissionDenied, .biometricAuthenticationFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Result Type Extensions
extension Result where Failure == AppError {
    static func from<T>(_ operation: () throws -> T) -> Result<T, AppError> {
        do {
            let value = try operation()
            return .success(value)
        } catch {
            return .failure(AppError.from(error))
        }
    }
    
    static func fromAsync<T>(_ operation: () async throws -> T) async -> Result<T, AppError> {
        do {
            let value = try await operation()
            return .success(value)
        } catch {
            return .failure(AppError.from(error))
        }
    }
} 