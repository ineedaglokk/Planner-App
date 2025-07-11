import Foundation
import SwiftData

// MARK: - Base Protocols for All Models

/// Протокол для моделей с временными метками
protocol Timestampable {
    /// Дата создания записи
    var createdAt: Date { get set }
    /// Дата последнего обновления записи
    var updatedAt: Date { get set }
}

/// Протокол для синхронизации с CloudKit
protocol CloudKitSyncable {
    /// Уникальный идентификатор записи
    var id: UUID { get set }
    /// ID записи в CloudKit
    var cloudKitRecordID: String? { get set }
    /// Флаг необходимости синхронизации
    var needsSync: Bool { get set }
    /// Дата последней синхронизации
    var lastSynced: Date? { get set }
}

/// Протокол для моделей с системой очков (геймификация)
protocol Gamifiable {
    /// Количество очков за эту модель
    var points: Int { get }
    /// Вычисление очков на основе правил
    func calculatePoints() -> Int
}

/// Протокол для моделей с категориями
protocol Categorizable {
    /// Связанная категория
    var category: Category? { get set }
}

/// Протокол для архивируемых моделей
protocol Archivable {
    /// Флаг архивации
    var isArchived: Bool { get set }
    /// Дата архивации
    var archivedAt: Date? { get set }
}

/// Протокол для моделей с приоритетом
protocol Prioritizable {
    /// Приоритет модели
    var priority: Priority { get set }
}

/// Протокол для валидации моделей
protocol Validatable {
    /// Проверка валидности модели
    func validate() throws
}

// MARK: - Common Enums

/// Общий enum для приоритетов
enum Priority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium" 
    case high = "high"
    case urgent = "urgent"
    
    var sortOrder: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
    
    var points: Int {
        switch self {
        case .low: return 5
        case .medium: return 10
        case .high: return 15
        case .urgent: return 20
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Низкий"
        case .medium: return "Средний"
        case .high: return "Высокий"
        case .urgent: return "Срочный"
        }
    }
}

/// Enum для статуса выполнения
enum CompletionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case overdue = "overdue"
    
    var displayName: String {
        switch self {
        case .pending: return "Ожидает"
        case .inProgress: return "В работе"
        case .completed: return "Выполнено"
        case .cancelled: return "Отменено"
        case .overdue: return "Просрочено"
        }
    }
    
    var isCompleted: Bool {
        return self == .completed
    }
}

// MARK: - Validation Errors

enum ModelValidationError: LocalizedError {
    case emptyName
    case invalidDate
    case negativeAmount
    case invalidFrequency
    case missingRequiredField(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Название не может быть пустым"
        case .invalidDate:
            return "Некорректная дата"
        case .negativeAmount:
            return "Сумма не может быть отрицательной"
        case .invalidFrequency:
            return "Некорректная частота"
        case .missingRequiredField(let field):
            return "Обязательное поле '\(field)' не заполнено"
        }
    }
}

// MARK: - Extensions for Base Protocols

extension Timestampable {
    /// Обновляет временную метку последнего изменения
    mutating func updateTimestamp() {
        updatedAt = Date()
    }
    
    /// Инициализирует временные метки при создании
    mutating func initializeTimestamps() {
        let now = Date()
        createdAt = now
        updatedAt = now
    }
}

extension CloudKitSyncable {
    /// Помечает модель для синхронизации
    mutating func markForSync() {
        needsSync = true
        updatedAt = Date()
    }
    
    /// Помечает модель как синхронизированную
    mutating func markSynced() {
        needsSync = false
        lastSynced = Date()
    }
}

extension Archivable {
    /// Архивирует модель
    mutating func archive() {
        isArchived = true
        archivedAt = Date()
    }
    
    /// Восстанавливает модель из архива
    mutating func unarchive() {
        isArchived = false
        archivedAt = nil
    }
} 