import Foundation
import SwiftData

// MARK: - Currency Model

@Model
final class Currency: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var code: String // ISO 4217 код валюты (USD, EUR, RUB)
    var name: String // Полное название валюты
    var symbol: String // Символ валюты ($, €, ₽)
    var exchangeRate: Decimal // Курс к базовой валюте
    var isBase: Bool // Является ли базовой валютой
    var isSupported: Bool // Поддерживается ли в приложении
    var lastUpdated: Date // Дата последнего обновления курса
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    
    // MARK: - Initializers
    
    init(
        code: String,
        name: String,
        symbol: String,
        exchangeRate: Decimal = 1.0,
        isBase: Bool = false
    ) {
        self.id = UUID()
        self.code = code.uppercased()
        self.name = name
        self.symbol = symbol
        self.exchangeRate = exchangeRate
        self.isBase = isBase
        self.isSupported = true
        self.lastUpdated = Date()
        
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

// MARK: - Currency Extensions

extension Currency: Validatable {
    func validate() throws {
        if code.isEmpty || code.count != 3 {
            throw ModelValidationError.missingRequiredField("Код валюты должен состоять из 3 символов")
        }
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        if symbol.isEmpty {
            throw ModelValidationError.missingRequiredField("Символ валюты обязателен")
        }
        
        if exchangeRate <= 0 {
            throw ModelValidationError.missingRequiredField("Курс валюты должен быть больше 0")
        }
    }
}

extension Currency {
    
    // MARK: - Computed Properties
    
    /// Форматированное отображение валюты
    var displayName: String {
        return "\(name) (\(code))"
    }
    
    /// Форматирует сумму в данной валюте
    func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.currencySymbol = symbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        // Для российского рубля используем русскую локаль
        if code == "RUB" {
            formatter.locale = Locale(identifier: "ru_RU")
        }
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(symbol)"
    }
    
    /// Создает предустановленные валюты
    static func createDefaultCurrencies() -> [Currency] {
        return [
            Currency(
                code: "RUB",
                name: "Российский рубль",
                symbol: "₽",
                exchangeRate: 1.0,
                isBase: true
            ),
            Currency(
                code: "USD",
                name: "Доллар США",
                symbol: "$",
                exchangeRate: 0.011
            ),
            Currency(
                code: "EUR",
                name: "Евро",
                symbol: "€",
                exchangeRate: 0.010
            )
        ]
    }
}

// MARK: - Cloudkit and Timestampable Extensions

extension Currency {
    func updateTimestamp() {
        updatedAt = Date()
    }
    
    func markForSync() {
        needsSync = true
        lastSynced = nil
    }
} 