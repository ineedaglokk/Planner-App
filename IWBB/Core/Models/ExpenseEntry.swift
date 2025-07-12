import Foundation
import SwiftData

// MARK: - ExpenseEntry Model

@Model
final class ExpenseEntry: CloudKitSyncable, Timestampable, Identifiable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String // Название траты
    var amount: Decimal // Сумма
    var date: Date // Дата создания записи
    var month: String // Месяц в формате "YYYY-MM"
    var currency: String // Валюта
    var notes: String? // Дополнительные заметки
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var category: Category?
    
    // MARK: - Initializers
    
    init(
        name: String,
        amount: Decimal,
        date: Date = Date(),
        currency: String = "RUB",
        notes: String? = nil,
        category: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.date = date
        self.currency = currency
        self.notes = notes
        self.category = category
        
        // Автоматически определяем месяц
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.month = formatter.string(from: date)
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
    }
}

// MARK: - ExpenseEntry Extensions

extension ExpenseEntry: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if amount <= 0 {
            throw ModelValidationError.negativeAmount
        }
        
        if currency.isEmpty {
            throw ModelValidationError.missingRequiredField("Валюта обязательна")
        }
    }
}

extension ExpenseEntry {
    
    // MARK: - Computed Properties
    
    /// Форматированная сумма с валютой
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "ru_RU")
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(currency)"
    }
    
    /// Форматированная дата
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    /// Название месяца для отображения
    var monthDisplayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).capitalized
    }
    
    // MARK: - Helper Methods
    
    /// Обновляет месяц при изменении даты
    func updateMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        self.month = formatter.string(from: date)
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет сумму
    func updateAmount(_ newAmount: Decimal) {
        amount = newAmount
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет название
    func updateName(_ newName: String) {
        name = newName
        updateTimestamp()
        markForSync()
    }
} 