//
//  Theme.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Главная тема, объединяющая все компоненты
//

import SwiftUI

// MARK: - Theme Protocol
protocol ThemeProtocol {
    var colors: ColorPalette.Type { get }
    var typography: Typography.Type { get }
    var spacing: Spacing.Type { get }
    var cornerRadius: CornerRadius.Type { get }
    var iconSize: IconSize.Type { get }
    var animations: AnimationSpacing.Type { get }
}

// MARK: - Default Theme
struct DefaultTheme: ThemeProtocol {
    let colors = ColorPalette.self
    let typography = Typography.self
    let spacing = Spacing.self
    let cornerRadius = CornerRadius.self
    let iconSize = IconSize.self
    let animations = AnimationSpacing.self
}

// MARK: - Theme Manager
@Observable
final class ThemeManager {
    
    // MARK: - Properties
    private(set) var currentTheme: ThemeProtocol = DefaultTheme()
    private(set) var colorScheme: ColorScheme = .light
    
    // MARK: - Singleton
    static let shared = ThemeManager()
    
    private init() {
        // Инициализация с системной темой
        detectSystemColorScheme()
    }
    
    // MARK: - Theme Management
    func setTheme(_ theme: ThemeProtocol) {
        currentTheme = theme
    }
    
    func setColorScheme(_ scheme: ColorScheme) {
        colorScheme = scheme
    }
    
    private func detectSystemColorScheme() {
        // В реальном приложении здесь была бы логика определения системной темы
        colorScheme = .light
    }
}

// MARK: - Global Theme Access
enum Theme {
    static var colors: ColorPalette.Type { ThemeManager.shared.currentTheme.colors }
    static var typography: Typography.Type { ThemeManager.shared.currentTheme.typography }
    static var spacing: Spacing.Type { ThemeManager.shared.currentTheme.spacing }
    static var cornerRadius: CornerRadius.Type { ThemeManager.shared.currentTheme.cornerRadius }
    static var iconSize: IconSize.Type { ThemeManager.shared.currentTheme.iconSize }
    static var animations: AnimationSpacing.Type { ThemeManager.shared.currentTheme.animations }
}

// MARK: - Theme Environment Key
struct ThemeKey: EnvironmentKey {
    static let defaultValue: ThemeProtocol = DefaultTheme()
}

extension EnvironmentValues {
    var theme: ThemeProtocol {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Shadow Styles
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    
    // MARK: - Predefined Shadows
    /// Мягкая тень для карточек
    static let card = ShadowStyle(
        color: Color.black.opacity(ColorConstants.shadowOpacity),
        radius: ColorConstants.shadowRadius,
        x: ColorConstants.shadowOffset.width,
        y: ColorConstants.shadowOffset.height
    )
    
    /// Тень для поднятых элементов
    static let elevated = ShadowStyle(
        color: Color.black.opacity(0.15),
        radius: 12,
        x: 0,
        y: 4
    )
    
    /// Тень для модальных окон
    static let modal = ShadowStyle(
        color: Color.black.opacity(0.25),
        radius: 20,
        x: 0,
        y: 8
    )
    
    /// Тень для кнопок при нажатии
    static let pressed = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 4,
        x: 0,
        y: 1
    )
    
    /// Отсутствие тени
    static let none = ShadowStyle(
        color: Color.clear,
        radius: 0,
        x: 0,
        y: 0
    )
}

// MARK: - View Extension for Shadow
extension View {
    func applyShadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
    
    func cardShadow() -> some View {
        self.applyShadow(.card)
    }
    
    func elevatedShadow() -> some View {
        self.applyShadow(.elevated)
    }
    
    func modalShadow() -> some View {
        self.applyShadow(.modal)
    }
}

// MARK: - Icon Style
struct IconStyle {
    let size: CGFloat
    let color: Color
    let weight: Font.Weight
    
    // MARK: - Predefined Icon Styles
    /// Стиль иконки для навигации
    static let navigation = IconStyle(
        size: IconSize.navigation,
        color: ColorPalette.Primary.main,
        weight: .medium
    )
    
    /// Стиль иконки для кнопки
    static let button = IconStyle(
        size: IconSize.button,
        color: ColorPalette.Text.onColor,
        weight: .semibold
    )
    
    /// Стиль иконки для списка
    static let listItem = IconStyle(
        size: IconSize.listItem,
        color: ColorPalette.Text.secondary,
        weight: .regular
    )
    
    /// Стиль иконки для карточки
    static let card = IconStyle(
        size: IconSize.card,
        color: ColorPalette.Primary.main,
        weight: .medium
    )
    
    /// Стиль иконки для статуса
    static let status = IconStyle(
        size: IconSize.sm,
        color: ColorPalette.Semantic.success,
        weight: .bold
    )
}

// MARK: - Icon View Helper
struct IconView: View {
    let systemName: String
    let style: IconStyle
    
    init(_ systemName: String, style: IconStyle = .listItem) {
        self.systemName = systemName
        self.style = style
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: style.size, weight: style.weight))
            .foregroundColor(style.color)
    }
}

// MARK: - Animation Presets
extension Animation {
    
    /// Стандартная анимация приложения
    static let appDefault = Animation.easeInOut(duration: AnimationSpacing.duration)
    
    /// Быстрая анимация для UI ответов
    static let quickResponse = Animation.easeOut(duration: AnimationSpacing.fast)
    
    /// Плавная анимация для переходов
    static let smoothTransition = Animation.easeInOut(duration: AnimationSpacing.slow)
    
    /// Анимация с пружиной для интерактивных элементов
    static let interactive = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
    
    /// Анимация для появления элементов
    static let entrance = Animation.easeOut(duration: 0.6).delay(0.1)
    
    /// Анимация для исчезновения элементов
    static let exit = Animation.easeIn(duration: 0.3)
}

// MARK: - Theme Utilities
struct ThemeUtils {
    
    /// Определяет контрастный цвет текста для фона
    static func contrastingTextColor(for backgroundColor: Color) -> Color {
        // Упрощенная логика, в реальном приложении нужна более сложная
        return ColorPalette.Text.onColor
    }
    
    /// Возвращает цвет в зависимости от приоритета
    static func priorityColor(for priority: TaskPriority) -> Color {
        return ColorPalette.Priority.color(for: priority)
    }
    
    /// Возвращает цвет для категории привычки
    static func habitCategoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "здоровье", "health":
            return ColorPalette.Habits.health
        case "продуктивность", "productivity":
            return ColorPalette.Habits.productivity
        case "обучение", "learning":
            return ColorPalette.Habits.learning
        case "социальное", "social":
            return ColorPalette.Habits.social
        default:
            return ColorPalette.Primary.main
        }
    }
    
    /// Возвращает цвет для финансовой категории
    static func financialColor(for type: String) -> Color {
        switch type.lowercased() {
        case "доход", "income":
            return ColorPalette.Financial.income
        case "расход", "expense":
            return ColorPalette.Financial.expense
        case "сбережения", "savings":
            return ColorPalette.Financial.savings
        default:
            return ColorPalette.Text.secondary
        }
    }
}

// MARK: - Responsive Design Helpers
struct ResponsiveDesign {
    
    /// Определяет размер экрана
    enum ScreenSize {
        case compact    // iPhone SE, iPhone 12 mini
        case regular    // iPhone 12, iPhone 12 Pro
        case large      // iPhone 12 Pro Max
        case extraLarge // iPad
        
        static var current: ScreenSize {
            let screenWidth = UIScreen.main.bounds.width
            switch screenWidth {
            case 0..<375:
                return .compact
            case 375..<414:
                return .regular
            case 414..<500:
                return .large
            default:
                return .extraLarge
            }
        }
    }
    
    /// Адаптивные значения в зависимости от размера экрана
    static func adaptive<T>(
        compact: T,
        regular: T,
        large: T? = nil,
        extraLarge: T? = nil
    ) -> T {
        let screenSize = ScreenSize.current
        
        switch screenSize {
        case .compact:
            return compact
        case .regular:
            return regular
        case .large:
            return large ?? regular
        case .extraLarge:
            return extraLarge ?? large ?? regular
        }
    }
    
    /// Адаптивный spacing
    static var spacing: CGFloat {
        adaptive(
            compact: Spacing.md,
            regular: Spacing.lg,
            large: Spacing.xl,
            extraLarge: Spacing.xxl
        )
    }
    
    /// Адаптивный размер шрифта
    static var fontSize: CGFloat {
        adaptive(
            compact: 14,
            regular: 16,
            large: 18,
            extraLarge: 20
        )
    }
}

// MARK: - Accessibility Helpers
struct AccessibilityTheme {
    
    /// Увеличенные размеры для лучшей доступности
    static let enhancedTouchTargetSize: CGFloat = 44
    
    /// Минимальный контраст для текста
    static let minimumContrastRatio: Double = 4.5
    
    /// Увеличенные отступы для accessibility
    static let accessibilitySpacing = Spacing.lg * 1.5
    
    /// Увеличенные размеры шрифтов
    static let accessibilityFontScale: CGFloat = 1.2
}

// MARK: - Theme Extensions for Common Patterns
extension View {
    
    /// Применяет стандартное форматирование карточки
    func cardStyle() -> some View {
        self
            .padding(.card)
            .background(ColorPalette.Background.surface)
            .cardCornerRadius()
            .cardShadow()
    }
    
    /// Применяет стиль для главного контента экрана
    func screenContentStyle() -> some View {
        self
            .background(ColorPalette.Background.primary)
            .screenPadding()
    }
    
    /// Применяет стиль для секции
    func sectionStyle() -> some View {
        self
            .padding(.vertical, Spacing.sectionSpacing)
    }
    
    /// Применяет стиль интерактивного элемента
    func interactiveStyle() -> some View {
        self
            .scaleEffect(1.0)
            .animation(.interactive, value: UUID())
    }
    
    /// Применяет стиль для списка
    func listStyle() -> some View {
        self
            .listItemSpacing()
            .background(ColorPalette.Background.surface)
    }
}

// MARK: - View Modifiers
extension View {
    
    // MARK: - Content Style Modifiers
    /// Стиль контента экрана
    func screenContentStyle() -> some View {
        self
            .background(ColorPalette.Background.primary)
            .foregroundColor(ColorPalette.Text.primary)
    }
    
    /// Стиль группированного контента
    func groupedContentStyle() -> some View {
        self
            .background(ColorPalette.Background.grouped)
            .foregroundColor(ColorPalette.Text.primary)
    }
    
    /// Стиль карточки
    func cardStyle() -> some View {
        self
            .background(ColorPalette.Background.surface)
            .cornerRadius(CornerRadius.card)
            .cardShadow()
    }
    
    /// Стиль поверхности
    func surfaceStyle() -> some View {
        self
            .background(ColorPalette.Background.surface)
            .cornerRadius(CornerRadius.md)
    }
    
    /// Адаптивное скругление
    func adaptiveCornerRadius(_ size: AdaptiveCornerRadiusSize = .medium) -> some View {
        let radius: CGFloat
        switch size {
        case .small: return self.cornerRadius(CornerRadius.sm)
        case .medium: return self.cornerRadius(CornerRadius.md)
        case .large: return self.cornerRadius(CornerRadius.lg)
        }
    }
    
    /// Адаптивные отступы
    func adaptivePadding(_ base: CGFloat = 16) -> some View {
        let padding = AdaptiveSpacing.padding(base)
        return self.padding(padding)
    }
    
    // MARK: - Shadow Modifiers
    /// Тень для карточек
    func cardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 2
        )
    }
    
    /// Тень для поднятых элементов
    func elevatedShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.15),
            radius: 12,
            x: 0,
            y: 4
        )
    }
    
    /// Тень для модальных окон
    func modalShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(0.2),
            radius: 20,
            x: 0,
            y: 10
        )
    }
    
    /// Применить тень по типу
    func applyShadow(_ type: ShadowType) -> some View {
        switch type {
        case .card: return AnyView(self.cardShadow())
        case .elevated: return AnyView(self.elevatedShadow())
        case .modal: return AnyView(self.modalShadow())
        case .pressed: return AnyView(self.shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1))
        }
    }
}

// MARK: - Supporting Types
enum AdaptiveCornerRadiusSize {
    case small
    case medium
    case large
}

enum ShadowType {
    case card
    case elevated
    case modal
    case pressed
}

// MARK: - Preview Theme
#if DEBUG
struct ThemePreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sectionSpacing) {
                
                // Color Palette Preview
                themeSection("Colors") {
                    HStack(spacing: Spacing.md) {
                        colorSample("Primary", ColorPalette.Primary.main)
                        colorSample("Secondary", ColorPalette.Secondary.main)
                        colorSample("Success", ColorPalette.Semantic.success)
                        colorSample("Warning", ColorPalette.Semantic.warning)
                        colorSample("Error", ColorPalette.Semantic.error)
                    }
                }
                
                // Typography Preview
                themeSection("Typography") {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Display Large").font(Typography.Display.large)
                        Text("Headline Medium").font(Typography.Headline.medium)
                        Text("Body Large").font(Typography.Body.large)
                        Text("Caption").font(Typography.Caption.regular)
                    }
                }
                
                // Components Preview
                themeSection("Components") {
                    VStack(spacing: Spacing.md) {
                        // Card Example
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Карточка примера")
                                .cardTitle()
                            Text("Описание карточки с примером текста")
                                .cardSubtitle()
                        }
                        .cardStyle()
                        
                        // Icon Examples
                        HStack(spacing: Spacing.lg) {
                            IconView("star.fill", style: .navigation)
                            IconView("heart.fill", style: .button)
                            IconView("checkmark.circle", style: .card)
                            IconView("bell.fill", style: .status)
                        }
                    }
                }
                
                // Shadow Examples
                themeSection("Shadows") {
                    HStack(spacing: Spacing.lg) {
                        Rectangle()
                            .fill(ColorPalette.Background.surface)
                            .frame(width: 60, height: 60)
                            .cardCornerRadius()
                            .applyShadow(.card)
                        
                        Rectangle()
                            .fill(ColorPalette.Background.surface)
                            .frame(width: 60, height: 60)
                            .cardCornerRadius()
                            .applyShadow(.elevated)
                        
                        Rectangle()
                            .fill(ColorPalette.Background.surface)
                            .frame(width: 60, height: 60)
                            .cardCornerRadius()
                            .applyShadow(.modal)
                    }
                }
            }
            .screenPadding()
        }
        .background(ColorPalette.Background.primary)
        .navigationTitle("Design System")
    }
    
    @ViewBuilder
    private func themeSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .font(Typography.Headline.medium)
                .foregroundColor(ColorPalette.Text.primary)
            
            content()
        }
    }
    
    private func colorSample(_ name: String, _ color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
            
            Text(name)
                .font(Typography.Caption.regular)
                .foregroundColor(ColorPalette.Text.secondary)
        }
    }
}

#Preview {
    ThemePreview()
}
#endif 