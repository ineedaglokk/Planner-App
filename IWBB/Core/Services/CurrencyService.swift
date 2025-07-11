import Foundation
import SwiftData

// MARK: - Currency Service Protocol

protocol CurrencyServiceProtocol {
    // MARK: - Currency Management
    func getBaseCurrency() async throws -> Currency
    func setBaseCurrency(_ currency: Currency) async throws
    func getAllCurrencies() async throws -> [Currency]
    func getSupportedCurrencies() async throws -> [Currency]
    func addCustomCurrency(_ currency: Currency) async throws
    
    // MARK: - Exchange Rates
    func getAllExchangeRates() async throws -> [String: Decimal]
    func getExchangeRate(from: String, to: String) async throws -> Decimal
    func updateExchangeRates() async throws
    func getLastUpdateTime() async throws -> Date?
    
    // MARK: - Currency Conversion
    func convertAmount(_ amount: Decimal, from: String, to: String) async throws -> Decimal
    func convertToBaseCurrency(_ amount: Decimal, from currency: String) async throws -> Decimal
    func convertFromBaseCurrency(_ amount: Decimal, to currency: String) async throws -> Decimal
    
    // MARK: - Currency Formatting
    func formatAmount(_ amount: Decimal, in currency: String) -> String
    func formatAmountWithSymbol(_ amount: Decimal, currency: String) -> String
    func getCurrencySymbol(for code: String) -> String?
    
    // MARK: - Historical Data
    func getHistoricalRates(for currency: String, days: Int) async throws -> [HistoricalRate]
    func getCurrencyTrend(for currency: String, period: DateInterval) async throws -> CurrencyTrend
    
    // MARK: - Notifications
    func subscribeToRateUpdates(for currency: String) async throws
    func unsubscribeFromRateUpdates(for currency: String) async throws
    func getSignificantRateChanges() async throws -> [RateChange]
}

// MARK: - Supporting Data Structures

struct HistoricalRate {
    let date: Date
    let currency: String
    let rate: Decimal
    let change: Decimal?
    let changePercentage: Double?
}

struct CurrencyTrend {
    let currency: String
    let period: DateInterval
    let startRate: Decimal
    let endRate: Decimal
    let highestRate: Decimal
    let lowestRate: Decimal
    let averageRate: Decimal
    let volatility: Double
    let trendDirection: TrendDirection
    let changePercentage: Double
    
    enum TrendDirection {
        case rising
        case falling
        case stable
    }
}

struct RateChange {
    let currency: String
    let oldRate: Decimal
    let newRate: Decimal
    let changePercentage: Double
    let timestamp: Date
    let isSignificant: Bool
}

struct ExchangeRateResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

// MARK: - Currency Service Implementation

final class CurrencyService: CurrencyServiceProtocol {
    
    // MARK: - Properties
    
    private let dataService: DataServiceProtocol
    private let userDefaultsService: UserDefaultsServiceProtocol
    private let notificationService: NotificationServiceProtocol
    
    // Exchange rate API configuration
    private let exchangeRateAPIKey = "your_api_key_here" // В реальном приложении из конфига
    private let exchangeRateBaseURL = "https://api.exchangerate-api.com/v4/latest/"
    
    // Caching
    private var cachedRates: [String: Decimal] = [:]
    private var lastUpdateTime: Date?
    private let cacheExpiryTime: TimeInterval = 3600 // 1 hour
    
    // Constants
    private let defaultBaseCurrency = "RUB"
    private let significantChangeThreshold = 5.0 // 5% change is considered significant
    
    // MARK: - Initialization
    
    init(
        dataService: DataServiceProtocol,
        userDefaultsService: UserDefaultsServiceProtocol,
        notificationService: NotificationServiceProtocol
    ) {
        self.dataService = dataService
        self.userDefaultsService = userDefaultsService
        self.notificationService = notificationService
        
        Task {
            await initializeDefaultCurrencies()
        }
    }
    
    // MARK: - Currency Management
    
    func getBaseCurrency() async throws -> Currency {
        let baseCurrencyCode = userDefaultsService.string(forKey: "baseCurrency") ?? defaultBaseCurrency
        
        if let currency = try await getCurrency(by: baseCurrencyCode) {
            return currency
        }
        
        // Fallback to RUB if base currency not found
        return try await getCurrency(by: defaultBaseCurrency) ?? 
               Currency(code: defaultBaseCurrency, name: "Российский рубль", symbol: "₽", isBase: true)
    }
    
    func setBaseCurrency(_ currency: Currency) async throws {
        // Update current base currency
        let currentBase = try await getBaseCurrency()
        currentBase.removeBaseStatus()
        try await dataService.save(currentBase)
        
        // Set new base currency
        currency.setAsBase()
        try await dataService.save(currency)
        
        // Save to UserDefaults
        userDefaultsService.set(currency.code, forKey: "baseCurrency")
        
        // Update all exchange rates relative to new base
        try await updateExchangeRates()
    }
    
    func getAllCurrencies() async throws -> [Currency] {
        return try await dataService.fetch(Currency.self, predicate: nil)
    }
    
    func getSupportedCurrencies() async throws -> [Currency] {
        return try await dataService.fetch(Currency.self, predicate: #Predicate { $0.isSupported })
    }
    
    func addCustomCurrency(_ currency: Currency) async throws {
        try currency.validate()
        currency.isSupported = true
        try await dataService.save(currency)
    }
    
    // MARK: - Exchange Rates
    
    func getAllExchangeRates() async throws -> [String: Decimal] {
        // Check if cached rates are still valid
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < cacheExpiryTime,
           !cachedRates.isEmpty {
            return cachedRates
        }
        
        // Fetch fresh rates
        try await updateExchangeRates()
        return cachedRates
    }
    
    func getExchangeRate(from: String, to: String) async throws -> Decimal {
        // Same currency
        if from == to {
            return 1.0
        }
        
        let rates = try await getAllExchangeRates()
        let baseCurrency = try await getBaseCurrency()
        
        // Convert through base currency
        let fromRate = from == baseCurrency.code ? 1.0 : (rates[from] ?? 1.0)
        let toRate = to == baseCurrency.code ? 1.0 : (rates[to] ?? 1.0)
        
        return toRate / fromRate
    }
    
    func updateExchangeRates() async throws {
        let baseCurrency = try await getBaseCurrency()
        
        do {
            // Fetch rates from API
            let freshRates = try await fetchExchangeRatesFromAPI(base: baseCurrency.code)
            
            // Update cached rates
            cachedRates = freshRates
            lastUpdateTime = Date()
            
            // Update currency objects in database
            for (currencyCode, rate) in freshRates {
                if let currency = try await getCurrency(by: currencyCode) {
                    let oldRate = currency.exchangeRate
                    currency.updateExchangeRate(rate)
                    try await dataService.save(currency)
                    
                    // Check for significant changes
                    let changePercentage = oldRate > 0 ? Double((rate - oldRate) / oldRate) * 100 : 0
                    if abs(changePercentage) >= significantChangeThreshold {
                        await notifySignificantRateChange(
                            currency: currencyCode,
                            oldRate: oldRate,
                            newRate: rate,
                            changePercentage: changePercentage
                        )
                    }
                }
            }
            
            // Save last update time
            userDefaultsService.set(Date(), forKey: "lastExchangeRateUpdate")
            
        } catch {
            print("Failed to update exchange rates: \(error)")
            // Use fallback rates or cached data
            throw AppError.exchangeRateUpdateFailed(error.localizedDescription)
        }
    }
    
    func getLastUpdateTime() async throws -> Date? {
        return userDefaultsService.date(forKey: "lastExchangeRateUpdate")
    }
    
    // MARK: - Currency Conversion
    
    func convertAmount(_ amount: Decimal, from: String, to: String) async throws -> Decimal {
        let rate = try await getExchangeRate(from: from, to: to)
        return amount * rate
    }
    
    func convertToBaseCurrency(_ amount: Decimal, from currency: String) async throws -> Decimal {
        let baseCurrency = try await getBaseCurrency()
        return try await convertAmount(amount, from: currency, to: baseCurrency.code)
    }
    
    func convertFromBaseCurrency(_ amount: Decimal, to currency: String) async throws -> Decimal {
        let baseCurrency = try await getBaseCurrency()
        return try await convertAmount(amount, from: baseCurrency.code, to: currency)
    }
    
    // MARK: - Currency Formatting
    
    func formatAmount(_ amount: Decimal, in currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        // Set locale based on currency
        if currency == "RUB" {
            formatter.locale = Locale(identifier: "ru_RU")
        } else if currency == "USD" {
            formatter.locale = Locale(identifier: "en_US")
        } else if currency == "EUR" {
            formatter.locale = Locale(identifier: "en_EU")
        } else {
            formatter.locale = Locale.current
        }
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount) \(currency)"
    }
    
    func formatAmountWithSymbol(_ amount: Decimal, currency: String) -> String {
        guard let symbol = getCurrencySymbol(for: currency) else {
            return formatAmount(amount, in: currency)
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","
        
        let formattedNumber = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
        
        // Different symbol placement for different currencies
        switch currency {
        case "USD", "EUR", "GBP":
            return "\(symbol)\(formattedNumber)"
        case "RUB", "KZT", "BYN":
            return "\(formattedNumber) \(symbol)"
        default:
            return "\(formattedNumber) \(symbol)"
        }
    }
    
    func getCurrencySymbol(for code: String) -> String? {
        let currencySymbols: [String: String] = [
            "RUB": "₽",
            "USD": "$",
            "EUR": "€",
            "GBP": "£",
            "JPY": "¥",
            "CNY": "¥",
            "KZT": "₸",
            "BYN": "Br",
            "UAH": "₴",
            "CHF": "₣",
            "CAD": "C$",
            "AUD": "A$"
        ]
        
        return currencySymbols[code]
    }
    
    // MARK: - Historical Data
    
    func getHistoricalRates(for currency: String, days: Int) async throws -> [HistoricalRate] {
        // In a real app, this would fetch from a historical data API
        // For now, we'll generate mock historical data
        
        var historicalRates: [HistoricalRate] = []
        let calendar = Calendar.current
        let currentRate = cachedRates[currency] ?? 1.0
        
        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            // Generate mock rate with some variance
            let variance = Decimal(Double.random(in: -0.05...0.05)) // ±5% variance
            let historicalRate = currentRate * (1 + variance)
            
            let previousRate = i < days - 1 ? historicalRates.last?.rate : nil
            let change = previousRate.map { historicalRate - $0 }
            let changePercentage = change.flatMap { change in
                previousRate.map { prev in
                    prev > 0 ? Double(change / prev) * 100 : 0
                }
            }
            
            let historical = HistoricalRate(
                date: date,
                currency: currency,
                rate: historicalRate,
                change: change,
                changePercentage: changePercentage
            )
            
            historicalRates.append(historical)
        }
        
        return historicalRates
    }
    
    func getCurrencyTrend(for currency: String, period: DateInterval) async throws -> CurrencyTrend {
        let days = Int(period.duration / 86400)
        let historicalRates = try await getHistoricalRates(for: currency, days: days)
        
        guard !historicalRates.isEmpty else {
            throw AppError.insufficientData
        }
        
        let rates = historicalRates.map { $0.rate }
        let startRate = rates.first!
        let endRate = rates.last!
        let highestRate = rates.max()!
        let lowestRate = rates.min()!
        let averageRate = rates.reduce(0, +) / Decimal(rates.count)
        
        // Calculate volatility (standard deviation)
        let mean = Double(truncating: averageRate as NSNumber)
        let variance = rates.map { rate in
            let diff = Double(truncating: rate as NSNumber) - mean
            return diff * diff
        }.reduce(0, +) / Double(rates.count)
        let volatility = sqrt(variance)
        
        // Determine trend direction
        let changePercentage = startRate > 0 ? Double((endRate - startRate) / startRate) * 100 : 0
        let trendDirection: CurrencyTrend.TrendDirection
        
        if abs(changePercentage) < 2 {
            trendDirection = .stable
        } else if changePercentage > 0 {
            trendDirection = .rising
        } else {
            trendDirection = .falling
        }
        
        return CurrencyTrend(
            currency: currency,
            period: period,
            startRate: startRate,
            endRate: endRate,
            highestRate: highestRate,
            lowestRate: lowestRate,
            averageRate: averageRate,
            volatility: volatility,
            trendDirection: trendDirection,
            changePercentage: abs(changePercentage)
        )
    }
    
    // MARK: - Notifications
    
    func subscribeToRateUpdates(for currency: String) async throws {
        var subscribedCurrencies = userDefaultsService.stringArray(forKey: "subscribedCurrencies") ?? []
        
        if !subscribedCurrencies.contains(currency) {
            subscribedCurrencies.append(currency)
            userDefaultsService.set(subscribedCurrencies, forKey: "subscribedCurrencies")
        }
    }
    
    func unsubscribeFromRateUpdates(for currency: String) async throws {
        var subscribedCurrencies = userDefaultsService.stringArray(forKey: "subscribedCurrencies") ?? []
        subscribedCurrencies.removeAll { $0 == currency }
        userDefaultsService.set(subscribedCurrencies, forKey: "subscribedCurrencies")
    }
    
    func getSignificantRateChanges() async throws -> [RateChange] {
        // This would typically be stored in database or fetched from a service
        // For now, return empty array
        return []
    }
}

// MARK: - Private Helper Methods

private extension CurrencyService {
    
    func initializeDefaultCurrencies() async {
        do {
            let existingCurrencies = try await getAllCurrencies()
            
            if existingCurrencies.isEmpty {
                let defaultCurrencies = Currency.createDefaultCurrencies()
                
                for currency in defaultCurrencies {
                    try await dataService.save(currency)
                }
                
                print("✅ Default currencies initialized")
            }
        } catch {
            print("❌ Failed to initialize default currencies: \(error)")
        }
    }
    
    func getCurrency(by code: String) async throws -> Currency? {
        let currencies = try await dataService.fetch(Currency.self, predicate: #Predicate { $0.code == code })
        return currencies.first
    }
    
    func fetchExchangeRatesFromAPI(base: String) async throws -> [String: Decimal] {
        // In a real app, this would make HTTP request to exchange rate API
        // For demo purposes, we'll return mock data
        
        let mockRates: [String: Decimal] = [
            "USD": 0.011,
            "EUR": 0.010,
            "GBP": 0.008,
            "JPY": 1.6,
            "CNY": 0.08,
            "KZT": 4.5,
            "BYN": 0.03,
            "UAH": 0.4
        ]
        
        // Add some random variance to simulate real exchange rates
        var updatedRates: [String: Decimal] = [:]
        
        for (currency, baseRate) in mockRates {
            let variance = Decimal(Double.random(in: -0.02...0.02)) // ±2% variance
            updatedRates[currency] = baseRate * (1 + variance)
        }
        
        // Base currency always has rate of 1
        updatedRates[base] = 1.0
        
        return updatedRates
    }
    
    func notifySignificantRateChange(
        currency: String,
        oldRate: Decimal,
        newRate: Decimal,
        changePercentage: Double
    ) async {
        let subscribedCurrencies = userDefaultsService.stringArray(forKey: "subscribedCurrencies") ?? []
        
        guard subscribedCurrencies.contains(currency) else { return }
        
        let direction = changePercentage > 0 ? "выросла" : "упала"
        let percentage = String(format: "%.1f", abs(changePercentage))
        
        let title = "Изменение курса валют"
        let body = "Валюта \(currency) \(direction) на \(percentage)%"
        
        await notificationService.scheduleNotification(
            title: title,
            body: body,
            identifier: "currency_change_\(currency)_\(Date().timeIntervalSince1970)",
            category: "CURRENCY_ALERT"
        )
    }
}

// MARK: - Currency Service Extensions

extension CurrencyService {
    
    /// Получает курсы валют для конкретного списка валют
    func getExchangeRates(for currencies: [String]) async throws -> [String: Decimal] {
        let allRates = try await getAllExchangeRates()
        
        var filteredRates: [String: Decimal] = [:]
        for currency in currencies {
            filteredRates[currency] = allRates[currency]
        }
        
        return filteredRates
    }
    
    /// Конвертирует массив сумм
    func convertAmounts(_ amounts: [Decimal], from: String, to: String) async throws -> [Decimal] {
        let rate = try await getExchangeRate(from: from, to: to)
        return amounts.map { $0 * rate }
    }
    
    /// Получает информацию о валюте по коду
    func getCurrencyInfo(for code: String) async throws -> (name: String, symbol: String, rate: Decimal)? {
        guard let currency = try await getCurrency(by: code) else { return nil }
        
        let rate = try await getExchangeRate(from: currency.code, to: (try await getBaseCurrency()).code)
        
        return (
            name: currency.name,
            symbol: currency.symbol,
            rate: rate
        )
    }
    
    /// Проверяет нужно ли обновить курсы
    func shouldUpdateRates() async -> Bool {
        guard let lastUpdate = lastUpdateTime else { return true }
        return Date().timeIntervalSince(lastUpdate) >= cacheExpiryTime
    }
    
    /// Форматирует сумму с автоматическим выбором валюты
    func formatAmountInUserCurrency(_ amount: Decimal) async -> String {
        do {
            let baseCurrency = try await getBaseCurrency()
            return formatAmount(amount, in: baseCurrency.code)
        } catch {
            return formatAmount(amount, in: defaultBaseCurrency)
        }
    }
    
    /// Получает топ популярных валют
    func getPopularCurrencies() -> [String] {
        return ["USD", "EUR", "GBP", "JPY", "CNY", "KZT", "BYN", "UAH"]
    }
    
    /// Валидирует код валюты
    func isValidCurrencyCode(_ code: String) -> Bool {
        return code.count == 3 && code.allSatisfy { $0.isLetter }
    }
    
    /// Экспортирует данные о валютах
    func exportCurrencyData() async throws -> Data {
        let currencies = try await getAllCurrencies()
        let rates = try await getAllExchangeRates()
        
        let exportData = [
            "currencies": currencies.map { currency in
                [
                    "code": currency.code,
                    "name": currency.name,
                    "symbol": currency.symbol,
                    "isBase": currency.isBase,
                    "rate": rates[currency.code] ?? 1.0
                ]
            },
            "lastUpdate": lastUpdateTime?.ISO8601String() ?? "",
            "baseCurrency": (try? await getBaseCurrency().code) ?? defaultBaseCurrency
        ]
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
} 