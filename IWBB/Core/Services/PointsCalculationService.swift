import Foundation
import SwiftData

// MARK: - PointsCalculationService Protocol
protocol PointsCalculationServiceProtocol: ServiceProtocol {
    func calculatePoints(for source: PointsSource, 
                        baseValue: Int, 
                        multipliers: [PointsMultiplier],
                        userLevel: Int) async throws -> Int
    func calculateXP(for source: PointsSource, 
                    baseValue: Int, 
                    multipliers: [PointsMultiplier],
                    userLevel: Int) async throws -> Int
    func awardPoints(to userID: UUID, 
                    amount: Int, 
                    source: PointsSource, 
                    sourceID: UUID?, 
                    reason: String) async throws -> PointsHistory
    func getPointsHistory(for userID: UUID, 
                         limit: Int) async throws -> [PointsHistory]
    func getTotalPoints(for userID: UUID) async throws -> Int
    func getPointsBreakdown(for userID: UUID, 
                           period: DateInterval) async throws -> [PointsBreakdown]
    func getMultipliers(for userID: UUID) async throws -> [PointsMultiplier]
    func processStreakMultiplier(for userID: UUID, 
                                streakDays: Int) async throws -> Double
    func processConsistencyMultiplier(for userID: UUID, 
                                    completionRate: Double) async throws -> Double
}

// MARK: - PointsCalculationService Implementation
final class PointsCalculationService: PointsCalculationServiceProtocol {
    
    // MARK: - Properties
    private let modelContext: ModelContext
    var isInitialized: Bool = false
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        #if DEBUG
        print("PointsCalculationService initializing...")
        #endif
        
        // Проверяем доступность ModelContext
        guard !modelContext.isMainActor else {
            throw ServiceError.initializationFailed("ModelContext is not available")
        }
        
        isInitialized = true
        
        #if DEBUG
        print("PointsCalculationService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        #if DEBUG
        print("PointsCalculationService cleaning up...")
        #endif
        
        isInitialized = false
        
        #if DEBUG
        print("PointsCalculationService cleaned up")
        #endif
    }
    
    // MARK: - Points Calculation
    func calculatePoints(for source: PointsSource, 
                        baseValue: Int, 
                        multipliers: [PointsMultiplier],
                        userLevel: Int) async throws -> Int {
        
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let basePoints = source.basePoints * baseValue
        var totalMultiplier = 1.0
        var bonusPoints = 0
        
        // Применяем множители
        for multiplier in multipliers {
            switch multiplier {
            case .level(let factor):
                totalMultiplier *= factor
                
            case .streak(let days, let bonus):
                totalMultiplier *= calculateStreakMultiplier(days: days)
                bonusPoints += bonus
                
            case .timeOfDay(let period, let bonus):
                totalMultiplier *= getTimeMultiplier(for: period)
                bonusPoints += bonus
                
            case .consistency(let rate, let bonus):
                totalMultiplier *= calculateConsistencyMultiplier(rate: rate)
                bonusPoints += bonus
                
            case .special(let factor, let bonus):
                totalMultiplier *= factor
                bonusPoints += bonus
            }
        }
        
        // Применяем бонус за уровень
        let levelBonus = calculateLevelBonus(userLevel: userLevel)
        bonusPoints += levelBonus
        
        let finalPoints = Int(Double(basePoints) * totalMultiplier) + bonusPoints
        
        #if DEBUG
        print("Points calculation: base=\(basePoints), multiplier=\(totalMultiplier), bonus=\(bonusPoints), final=\(finalPoints)")
        #endif
        
        return max(1, finalPoints) // Минимум 1 очко
    }
    
    func calculateXP(for source: PointsSource, 
                    baseValue: Int, 
                    multipliers: [PointsMultiplier],
                    userLevel: Int) async throws -> Int {
        
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        // XP обычно в 2 раза больше очков
        let points = try await calculatePoints(for: source, 
                                             baseValue: baseValue, 
                                             multipliers: multipliers, 
                                             userLevel: userLevel)
        
        return points * 2
    }
    
    func awardPoints(to userID: UUID, 
                    amount: Int, 
                    source: PointsSource, 
                    sourceID: UUID?, 
                    reason: String) async throws -> PointsHistory {
        
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let pointsHistory = PointsHistory(
            userID: userID,
            amount: amount,
            source: source,
            sourceID: sourceID,
            reason: reason
        )
        
        modelContext.insert(pointsHistory)
        
        do {
            try modelContext.save()
            
            #if DEBUG
            print("Awarded \(amount) points to user \(userID) for \(reason)")
            #endif
            
            return pointsHistory
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to save points history: \(error)")
        }
    }
    
    // MARK: - Points History
    func getPointsHistory(for userID: UUID, limit: Int = 50) async throws -> [PointsHistory] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<PointsHistory> { $0.userID == userID }
        let descriptor = FetchDescriptor<PointsHistory>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.earnedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            let history = try modelContext.fetch(descriptor)
            return history
        } catch {
            throw ServiceError.dataOperationFailed("Failed to fetch points history: \(error)")
        }
    }
    
    func getTotalPoints(for userID: UUID) async throws -> Int {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<PointsHistory> { $0.userID == userID }
        let descriptor = FetchDescriptor<PointsHistory>(predicate: predicate)
        
        do {
            let history = try modelContext.fetch(descriptor)
            return history.reduce(0) { $0 + $1.totalPoints }
        } catch {
            throw ServiceError.dataOperationFailed("Failed to calculate total points: \(error)")
        }
    }
    
    func getPointsBreakdown(for userID: UUID, period: DateInterval) async throws -> [PointsBreakdown] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        let predicate = #Predicate<PointsHistory> { 
            $0.userID == userID && 
            $0.earnedAt >= period.start && 
            $0.earnedAt <= period.end 
        }
        let descriptor = FetchDescriptor<PointsHistory>(predicate: predicate)
        
        do {
            let history = try modelContext.fetch(descriptor)
            
            // Группируем по источникам
            var breakdown: [PointsSource: Int] = [:]
            for entry in history {
                breakdown[entry.source, default: 0] += entry.totalPoints
            }
            
            return breakdown.map { source, points in
                PointsBreakdown(source: source, points: points)
            }.sorted { $0.points > $1.points }
            
        } catch {
            throw ServiceError.dataOperationFailed("Failed to get points breakdown: \(error)")
        }
    }
    
    // MARK: - Multipliers
    func getMultipliers(for userID: UUID) async throws -> [PointsMultiplier] {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        var multipliers: [PointsMultiplier] = []
        
        // Получаем уровень пользователя
        if let userLevel = try await getUserLevel(for: userID) {
            let levelMultiplier = calculateLevelMultiplier(level: userLevel.currentLevel)
            multipliers.append(.level(levelMultiplier))
        }
        
        // Получаем текущие серии
        let streakMultipliers = try await getStreakMultipliers(for: userID)
        multipliers.append(contentsOf: streakMultipliers)
        
        // Получаем множители времени
        let timeMultiplier = getCurrentTimeMultiplier()
        if timeMultiplier.factor > 1.0 {
            multipliers.append(.timeOfDay(timeMultiplier.period, timeMultiplier.bonus))
        }
        
        // Получаем множители постоянства
        let consistencyMultiplier = try await getConsistencyMultiplier(for: userID)
        if consistencyMultiplier.factor > 1.0 {
            multipliers.append(.consistency(consistencyMultiplier.rate, consistencyMultiplier.bonus))
        }
        
        return multipliers
    }
    
    func processStreakMultiplier(for userID: UUID, streakDays: Int) async throws -> Double {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        return calculateStreakMultiplier(days: streakDays)
    }
    
    func processConsistencyMultiplier(for userID: UUID, completionRate: Double) async throws -> Double {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
        
        return calculateConsistencyMultiplier(rate: completionRate)
    }
    
    // MARK: - Private Methods
    
    private func calculateStreakMultiplier(days: Int) -> Double {
        switch days {
        case 0...6: return 1.0
        case 7...13: return 1.2
        case 14...29: return 1.5
        case 30...59: return 2.0
        case 60...99: return 2.5
        case 100...199: return 3.0
        case 200...364: return 4.0
        case 365...: return 5.0
        default: return 1.0
        }
    }
    
    private func calculateConsistencyMultiplier(rate: Double) -> Double {
        switch rate {
        case 0.0..<0.5: return 1.0
        case 0.5..<0.7: return 1.1
        case 0.7..<0.8: return 1.2
        case 0.8..<0.9: return 1.3
        case 0.9..<0.95: return 1.5
        case 0.95...1.0: return 2.0
        default: return 1.0
        }
    }
    
    private func calculateLevelBonus(userLevel: Int) -> Int {
        return userLevel * 2 // 2 бонусных очка за уровень
    }
    
    private func calculateLevelMultiplier(level: Int) -> Double {
        return 1.0 + (Double(level) * 0.05) // 5% за уровень
    }
    
    private func getTimeMultiplier(for period: TimeOfDayPeriod) -> Double {
        switch period {
        case .earlyMorning: return 1.3 // 6-9 утра
        case .morning: return 1.1 // 9-12 утра
        case .afternoon: return 1.0 // 12-18 дня
        case .evening: return 1.1 // 18-21 вечера
        case .night: return 1.2 // 21-24 ночи
        case .lateNight: return 1.5 // 0-6 утра
        }
    }
    
    private func getCurrentTimeMultiplier() -> (period: TimeOfDayPeriod, factor: Double, bonus: Int) {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<9:
            return (.earlyMorning, 1.3, 5)
        case 9..<12:
            return (.morning, 1.1, 2)
        case 12..<18:
            return (.afternoon, 1.0, 0)
        case 18..<21:
            return (.evening, 1.1, 2)
        case 21..<24:
            return (.night, 1.2, 3)
        case 0..<6:
            return (.lateNight, 1.5, 10)
        default:
            return (.afternoon, 1.0, 0)
        }
    }
    
    private func getUserLevel(for userID: UUID) async throws -> UserLevel? {
        let predicate = #Predicate<UserLevel> { $0.userID == userID }
        let descriptor = FetchDescriptor<UserLevel>(predicate: predicate)
        
        do {
            let levels = try modelContext.fetch(descriptor)
            return levels.first
        } catch {
            return nil
        }
    }
    
    private func getStreakMultipliers(for userID: UUID) async throws -> [PointsMultiplier] {
        let predicate = #Predicate<StreakRecord> { $0.userID == userID }
        let descriptor = FetchDescriptor<StreakRecord>(predicate: predicate)
        
        do {
            let streaks = try modelContext.fetch(descriptor)
            return streaks.compactMap { streak in
                let multiplier = calculateStreakMultiplier(days: streak.currentStreak)
                if multiplier > 1.0 {
                    let bonus = calculateStreakBonus(days: streak.currentStreak)
                    return .streak(streak.currentStreak, bonus)
                }
                return nil
            }
        } catch {
            return []
        }
    }
    
    private func getConsistencyMultiplier(for userID: UUID) async throws -> (rate: Double, factor: Double, bonus: Int) {
        // Получаем статистику выполнения за последние 30 дней
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let predicate = #Predicate<PointsHistory> { 
            $0.userID == userID && 
            $0.earnedAt >= startDate && 
            $0.earnedAt <= endDate 
        }
        let descriptor = FetchDescriptor<PointsHistory>(predicate: predicate)
        
        do {
            let history = try modelContext.fetch(descriptor)
            
            // Группируем по дням
            let calendar = Calendar.current
            var daysSets: Set<String> = []
            for entry in history {
                let dayKey = calendar.dateComponents([.year, .month, .day], from: entry.earnedAt)
                daysSets.insert("\(dayKey.year!)-\(dayKey.month!)-\(dayKey.day!)")
            }
            
            let activeDays = daysSets.count
            let rate = Double(activeDays) / 30.0
            let factor = calculateConsistencyMultiplier(rate: rate)
            let bonus = calculateConsistencyBonus(rate: rate)
            
            return (rate, factor, bonus)
            
        } catch {
            return (0.0, 1.0, 0)
        }
    }
    
    private func calculateStreakBonus(days: Int) -> Int {
        switch days {
        case 7...13: return 10
        case 14...29: return 25
        case 30...59: return 50
        case 60...99: return 100
        case 100...199: return 200
        case 200...364: return 500
        case 365...: return 1000
        default: return 0
        }
    }
    
    private func calculateConsistencyBonus(rate: Double) -> Int {
        switch rate {
        case 0.7..<0.8: return 10
        case 0.8..<0.9: return 20
        case 0.9..<0.95: return 50
        case 0.95...1.0: return 100
        default: return 0
        }
    }
}

// MARK: - Supporting Types

enum PointsMultiplier {
    case level(Double)
    case streak(Int, Int) // days, bonus
    case timeOfDay(TimeOfDayPeriod, Int) // period, bonus
    case consistency(Double, Int) // rate, bonus
    case special(Double, Int) // factor, bonus
}

enum TimeOfDayPeriod {
    case earlyMorning
    case morning
    case afternoon
    case evening
    case night
    case lateNight
}

struct PointsBreakdown {
    let source: PointsSource
    let points: Int
    
    var percentage: Double = 0.0
    
    init(source: PointsSource, points: Int) {
        self.source = source
        self.points = points
    }
}

// MARK: - Service Error

enum ServiceError: Error, LocalizedError {
    case notInitialized
    case initializationFailed(String)
    case dataOperationFailed(String)
    case invalidParameters(String)
    case serviceUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Service not initialized"
        case .initializationFailed(let message):
            return "Service initialization failed: \(message)"
        case .dataOperationFailed(let message):
            return "Data operation failed: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .serviceUnavailable(let message):
            return "Service unavailable: \(message)"
        }
    }
} 