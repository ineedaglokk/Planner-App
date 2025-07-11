import Foundation
import SwiftData
import HealthKit

// MARK: - HealthData Model

@Model
final class HealthData: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: HealthDataType
    var value: Double
    var unit: String
    var source: String? // Источник данных (iPhone, Apple Watch, etc.)
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var user: User?
    var correlatedHabits: [Habit] = []
    
    // MARK: - Initializers
    
    init(
        date: Date = Date(),
        type: HealthDataType,
        value: Double,
        unit: String,
        source: String? = nil
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type
        self.value = value
        self.unit = unit
        self.source = source
        
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

// MARK: - HealthDataType

enum HealthDataType: String, Codable, CaseIterable {
    case steps = "steps"
    case sleepDuration = "sleep_duration"
    case heartRate = "heart_rate"
    case activeEnergyBurned = "active_energy"
    case exerciseTime = "exercise_time"
    case mindfulMinutes = "mindful_minutes"
    case weight = "weight"
    case mood = "mood"
    case waterIntake = "water_intake"
    case screenTime = "screen_time"
    
    var displayName: String {
        switch self {
        case .steps:
            return "Шаги"
        case .sleepDuration:
            return "Продолжительность сна"
        case .heartRate:
            return "Пульс"
        case .activeEnergyBurned:
            return "Активные калории"
        case .exerciseTime:
            return "Время тренировки"
        case .mindfulMinutes:
            return "Минуты медитации"
        case .weight:
            return "Вес"
        case .mood:
            return "Настроение"
        case .waterIntake:
            return "Потребление воды"
        case .screenTime:
            return "Экранное время"
        }
    }
    
    var icon: String {
        switch self {
        case .steps:
            return "figure.walk"
        case .sleepDuration:
            return "bed.double.fill"
        case .heartRate:
            return "heart.fill"
        case .activeEnergyBurned:
            return "flame.fill"
        case .exerciseTime:
            return "dumbbell.fill"
        case .mindfulMinutes:
            return "brain.head.profile"
        case .weight:
            return "scalemass.fill"
        case .mood:
            return "face.smiling.fill"
        case .waterIntake:
            return "drop.fill"
        case .screenTime:
            return "iphone"
        }
    }
    
    var defaultUnit: String {
        switch self {
        case .steps:
            return "шагов"
        case .sleepDuration:
            return "часов"
        case .heartRate:
            return "уд/мин"
        case .activeEnergyBurned:
            return "ккал"
        case .exerciseTime:
            return "минут"
        case .mindfulMinutes:
            return "минут"
        case .weight:
            return "кг"
        case .mood:
            return "балл"
        case .waterIntake:
            return "мл"
        case .screenTime:
            return "часов"
        }
    }
    
    var healthKitIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .steps:
            return .stepCount
        case .sleepDuration:
            return nil // Используем HKCategoryTypeIdentifier.sleepAnalysis
        case .heartRate:
            return .heartRate
        case .activeEnergyBurned:
            return .activeEnergyBurned
        case .exerciseTime:
            return .appleExerciseTime
        case .mindfulMinutes:
            return .mindfulSession
        case .weight:
            return .bodyMass
        case .waterIntake:
            return .dietaryWater
        case .mood, .screenTime:
            return nil // Custom tracking
        }
    }
}

// MARK: - HabitHealthCorrelation Model

@Model
final class HabitHealthCorrelation: CloudKitSyncable, Timestampable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var correlationScore: Double // -1.0 to 1.0
    var confidenceLevel: Double // 0.0 to 1.0
    var dataPoints: Int // Количество данных для анализа
    var lastCalculated: Date
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    var habit: Habit?
    var healthDataType: HealthDataType
    
    // MARK: - Initializers
    
    init(
        habit: Habit,
        healthDataType: HealthDataType,
        correlationScore: Double = 0.0,
        confidenceLevel: Double = 0.0,
        dataPoints: Int = 0
    ) {
        self.id = UUID()
        self.habit = habit
        self.healthDataType = healthDataType
        self.correlationScore = correlationScore
        self.confidenceLevel = confidenceLevel
        self.dataPoints = dataPoints
        self.lastCalculated = Date()
        
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

// MARK: - HealthData Extensions

extension HealthData: Validatable {
    func validate() throws {
        if value < 0 {
            throw ModelValidationError.negativeAmount
        }
    }
}

extension HealthData {
    
    /// Форматированное значение с единицей измерения
    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = type == .weight ? 1 : 0
        
        guard let formattedNumber = formatter.string(from: NSNumber(value: value)) else {
            return "\(value) \(unit)"
        }
        
        return "\(formattedNumber) \(unit)"
    }
    
    /// Проверяет, являются ли данные нормальными для типа
    var isWithinNormalRange: Bool {
        switch type {
        case .steps:
            return value >= 0 && value <= 50000
        case .sleepDuration:
            return value >= 0 && value <= 24
        case .heartRate:
            return value >= 30 && value <= 220
        case .activeEnergyBurned:
            return value >= 0 && value <= 5000
        case .exerciseTime:
            return value >= 0 && value <= 1440 // 24 часа в минутах
        case .mindfulMinutes:
            return value >= 0 && value <= 1440
        case .weight:
            return value >= 30 && value <= 300 // кг
        case .mood:
            return value >= 1 && value <= 10
        case .waterIntake:
            return value >= 0 && value <= 10000 // мл
        case .screenTime:
            return value >= 0 && value <= 24
        }
    }
}

extension HabitHealthCorrelation {
    
    /// Интерпретация силы корреляции
    var correlationStrength: CorrelationStrength {
        let absScore = abs(correlationScore)
        
        switch absScore {
        case 0.0..<0.1:
            return .negligible
        case 0.1..<0.3:
            return .weak
        case 0.3..<0.5:
            return .moderate
        case 0.5..<0.7:
            return .strong
        case 0.7...1.0:
            return .veryStrong
        default:
            return .negligible
        }
    }
    
    /// Направление корреляции
    var correlationDirection: CorrelationDirection {
        if correlationScore > 0.1 {
            return .positive
        } else if correlationScore < -0.1 {
            return .negative
        } else {
            return .none
        }
    }
    
    /// Описание корреляции
    var correlationDescription: String {
        let direction = correlationDirection == .positive ? "положительная" : 
                       correlationDirection == .negative ? "отрицательная" : "отсутствует"
        let strength = correlationStrength.displayName.lowercased()
        
        return "\(direction.capitalized) \(strength) связь"
    }
}

// MARK: - Supporting Types

enum CorrelationStrength: CaseIterable {
    case negligible
    case weak
    case moderate
    case strong
    case veryStrong
    
    var displayName: String {
        switch self {
        case .negligible:
            return "Незначительная"
        case .weak:
            return "Слабая"
        case .moderate:
            return "Умеренная"
        case .strong:
            return "Сильная"
        case .veryStrong:
            return "Очень сильная"
        }
    }
    
    var color: String {
        switch self {
        case .negligible:
            return "#8E8E93"
        case .weak:
            return "#FF9500"
        case .moderate:
            return "#FFCC00"
        case .strong:
            return "#34C759"
        case .veryStrong:
            return "#007AFF"
        }
    }
}

enum CorrelationDirection {
    case positive
    case negative
    case none
    
    var icon: String {
        switch self {
        case .positive:
            return "arrow.up.right"
        case .negative:
            return "arrow.down.right"
        case .none:
            return "minus"
        }
    }
} 