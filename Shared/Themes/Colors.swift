//
//  Colors.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Цветовая палитра с поддержкой Dark/Light Mode
//

import SwiftUI

// MARK: - Color Palette
extension Color {
    
    // MARK: - Primary Colors
    /// Основной цвет приложения - мотивирующий синий
    static let primaryBlue = Color("PrimaryBlue", bundle: .main)
    
    /// Светлый оттенок основного цвета
    static let primaryBlueLight = Color("PrimaryBlueLight", bundle: .main)
    
    /// Темный оттенок основного цвета
    static let primaryBlueDark = Color("PrimaryBlueDark", bundle: .main)
    
    // MARK: - Secondary Colors
    /// Вторичный цвет - теплый фиолетовый
    static let secondaryPurple = Color("SecondaryPurple", bundle: .main)
    
    /// Светлый оттенок вторичного цвета
    static let secondaryPurpleLight = Color("SecondaryPurpleLight", bundle: .main)
    
    /// Темный оттенок вторичного цвета
    static let secondaryPurpleDark = Color("SecondaryPurpleDark", bundle: .main)
    
    // MARK: - Accent Colors
    /// Цвет успеха - свежий зеленый
    static let success = Color("Success", bundle: .main)
    
    /// Цвет предупреждения - энергичный оранжевый
    static let warning = Color("Warning", bundle: .main)
    
    /// Цвет ошибки - мягкий красный
    static let error = Color("Error", bundle: .main)
    
    /// Информационный цвет - спокойный голубой
    static let info = Color("Info", bundle: .main)
    
    // MARK: - Semantic Colors для привычек
    /// Цвет для здоровых привычек
    static let habitHealth = Color("HabitHealth", bundle: .main)
    
    /// Цвет для продуктивных привычек
    static let habitProductivity = Color("HabitProductivity", bundle: .main)
    
    /// Цвет для обучающих привычек
    static let habitLearning = Color("HabitLearning", bundle: .main)
    
    /// Цвет для социальных привычек
    static let habitSocial = Color("HabitSocial", bundle: .main)
    
    // MARK: - Financial Colors
    /// Цвет для доходов - позитивный зеленый
    static let income = Color("Income", bundle: .main)
    
    /// Цвет для расходов - нейтральный красный
    static let expense = Color("Expense", bundle: .main)
    
    /// Цвет для сбережений - мудрый синий
    static let savings = Color("Savings", bundle: .main)
    
    // MARK: - Priority Colors
    /// Низкий приоритет - серый
    static let priorityLow = Color("PriorityLow", bundle: .main)
    
    /// Средний приоритет - желтый
    static let priorityMedium = Color("PriorityMedium", bundle: .main)
    
    /// Высокий приоритет - оранжевый
    static let priorityHigh = Color("PriorityHigh", bundle: .main)
    
    /// Срочный приоритет - красный
    static let priorityUrgent = Color("PriorityUrgent", bundle: .main)
    
    // MARK: - Background Colors
    /// Основной фон приложения
    static let background = Color("Background", bundle: .main)
    
    /// Фон для карточек и поверхностей
    static let surface = Color("Surface", bundle: .main)
    
    /// Фон для поднятых элементов
    static let surfaceElevated = Color("SurfaceElevated", bundle: .main)
    
    /// Фон для группированных списков
    static let groupedBackground = Color("GroupedBackground", bundle: .main)
    
    // MARK: - Text Colors
    /// Основной цвет текста
    static let textPrimary = Color("TextPrimary", bundle: .main)
    
    /// Вторичный цвет текста
    static let textSecondary = Color("TextSecondary", bundle: .main)
    
    /// Третичный цвет текста
    static let textTertiary = Color("TextTertiary", bundle: .main)
    
    /// Цвет placeholder текста
    static let textPlaceholder = Color("TextPlaceholder", bundle: .main)
    
    /// Цвет текста на цветном фоне
    static let textOnColor = Color("TextOnColor", bundle: .main)
    
    // MARK: - Border Colors
    /// Основной цвет границ
    static let border = Color("Border", bundle: .main)
    
    /// Цвет разделителей
    static let separator = Color("Separator", bundle: .main)
    
    /// Цвет фокуса для полей ввода
    static let focus = Color("Focus", bundle: .main)
}

// MARK: - Color Palette Structure
struct ColorPalette {
    
    // MARK: - Primary
    struct Primary {
        static let main = Color.primaryBlue
        static let light = Color.primaryBlueLight
        static let dark = Color.primaryBlueDark
    }
    
    // MARK: - Secondary
    struct Secondary {
        static let main = Color.secondaryPurple
        static let light = Color.secondaryPurpleLight
        static let dark = Color.secondaryPurpleDark
    }
    
    // MARK: - Semantic
    struct Semantic {
        static let success = Color.success
        static let warning = Color.warning
        static let error = Color.error
        static let info = Color.info
    }
    
    // MARK: - Background
    struct Background {
        static let primary = Color.background
        static let surface = Color.surface
        static let elevated = Color.surfaceElevated
        static let grouped = Color.groupedBackground
    }
    
    // MARK: - Text
    struct Text {
        static let primary = Color.textPrimary
        static let secondary = Color.textSecondary
        static let tertiary = Color.textTertiary
        static let placeholder = Color.textPlaceholder
        static let onColor = Color.textOnColor
    }
    
    // MARK: - Border
    struct Border {
        static let main = Color.border
        static let separator = Color.separator
        static let focus = Color.focus
    }
    
    // MARK: - Habit Categories
    struct Habits {
        static let health = Color.habitHealth
        static let productivity = Color.habitProductivity
        static let learning = Color.habitLearning
        static let social = Color.habitSocial
    }
    
    // MARK: - Financial
    struct Financial {
        static let income = Color.income
        static let expense = Color.expense
        static let savings = Color.savings
    }
    
    // MARK: - Priority
    struct Priority {
        static let low = Color.priorityLow
        static let medium = Color.priorityMedium
        static let high = Color.priorityHigh
        static let urgent = Color.priorityUrgent
        
        static func color(for priority: TaskPriority) -> Color {
            switch priority {
            case .low: return low
            case .medium: return medium
            case .high: return high
            case .urgent: return urgent
            }
        }
    }
}

// MARK: - Dynamic Color Helpers
extension Color {
    
    /// Создает динамический цвет для Light/Dark режимов
    static func dynamic(
        light: Color,
        dark: Color
    ) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
    
    /// Создает цвет с прозрачностью
    func withOpacity(_ opacity: Double) -> Color {
        self.opacity(opacity)
    }
    
    /// Возвращает цвет для состояния disabled
    var disabled: Color {
        self.opacity(0.6)
    }
    
    /// Возвращает цвет для состояния pressed
    var pressed: Color {
        self.opacity(0.8)
    }
}

// MARK: - Gradient Definitions
extension LinearGradient {
    
    /// Основной градиент приложения
    static let primaryGradient = LinearGradient(
        colors: [ColorPalette.Primary.light, ColorPalette.Primary.main],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Градиент для успеха
    static let successGradient = LinearGradient(
        colors: [ColorPalette.Semantic.success.opacity(0.8), ColorPalette.Semantic.success],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Градиент для карточек
    static let cardGradient = LinearGradient(
        colors: [
            ColorPalette.Background.surface,
            ColorPalette.Background.elevated
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Градиент для геймификации
    static let achievementGradient = LinearGradient(
        colors: [
            Color.yellow.opacity(0.8),
            Color.orange.opacity(0.9),
            Color.red.opacity(0.7)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extensions for TaskPriority
enum TaskPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

// MARK: - Color Constants
struct ColorConstants {
    
    /// Стандартная прозрачность для overlay
    static let overlayOpacity: Double = 0.1
    
    /// Прозрачность для hover состояния
    static let hoverOpacity: Double = 0.05
    
    /// Прозрачность для pressed состояния
    static let pressedOpacity: Double = 0.2
    
    /// Прозрачность для disabled состояния
    static let disabledOpacity: Double = 0.6
    
    /// Радиус размытия для теней
    static let shadowRadius: CGFloat = 8
    
    /// Смещение тени
    static let shadowOffset: CGSize = CGSize(width: 0, height: 2)
    
    /// Прозрачность тени
    static let shadowOpacity: Double = 0.1
}

// MARK: - Preview Helper
#if DEBUG
struct ColorsPreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                
                // Primary Colors
                colorSection("Primary Colors") {
                    colorCard("Primary", ColorPalette.Primary.main)
                    colorCard("Primary Light", ColorPalette.Primary.light)
                    colorCard("Primary Dark", ColorPalette.Primary.dark)
                }
                
                // Semantic Colors
                colorSection("Semantic Colors") {
                    colorCard("Success", ColorPalette.Semantic.success)
                    colorCard("Warning", ColorPalette.Semantic.warning)
                    colorCard("Error", ColorPalette.Semantic.error)
                    colorCard("Info", ColorPalette.Semantic.info)
                }
                
                // Priority Colors
                colorSection("Priority Colors") {
                    colorCard("Low", ColorPalette.Priority.low)
                    colorCard("Medium", ColorPalette.Priority.medium)
                    colorCard("High", ColorPalette.Priority.high)
                    colorCard("Urgent", ColorPalette.Priority.urgent)
                }
                
                // Financial Colors
                colorSection("Financial Colors") {
                    colorCard("Income", ColorPalette.Financial.income)
                    colorCard("Expense", ColorPalette.Financial.expense)
                    colorCard("Savings", ColorPalette.Financial.savings)
                }
            }
            .padding()
        }
        .navigationTitle("Цветовая палитра")
    }
    
    @ViewBuilder
    private func colorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(ColorPalette.Text.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                content()
            }
        }
    }
    
    private func colorCard(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(height: 60)
            
            Text(name)
                .font(.caption)
                .foregroundColor(ColorPalette.Text.secondary)
        }
    }
}

#Preview {
    ColorsPreview()
}
#endif 