//
//  Spacing.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Система отступов на основе 8pt grid
//

import SwiftUI

// MARK: - Spacing System (8pt Grid)
struct Spacing {
    
    // MARK: - Core Spacing Values
    /// Базовая единица spacing (8pt)
    static let unit: CGFloat = 8
    
    /// Минимальный отступ (2pt)
    static let xxs: CGFloat = 2
    
    /// Очень малый отступ (4pt)
    static let xs: CGFloat = 4
    
    /// Малый отступ (8pt)
    static let sm: CGFloat = 8
    
    /// Средний отступ (12pt)
    static let md: CGFloat = 12
    
    /// Стандартный отступ (16pt)
    static let lg: CGFloat = 16
    
    /// Большой отступ (20pt)
    static let xl: CGFloat = 20
    
    /// Очень большой отступ (24pt)
    static let xxl: CGFloat = 24
    
    /// Экстра большой отступ (32pt)
    static let xxxl: CGFloat = 32
    
    /// Огромный отступ (48pt)
    static let huge: CGFloat = 48
    
    /// Максимальный отступ (64pt)
    static let massive: CGFloat = 64
    
    // MARK: - Semantic Spacing
    /// Отступ между элементами в карточке
    static let cardPadding: CGFloat = lg
    
    /// Отступ между карточками
    static let cardSpacing: CGFloat = md
    
    /// Отступ от краев экрана
    static let screenPadding: CGFloat = lg
    
    /// Отступ между секциями
    static let sectionSpacing: CGFloat = xxl
    
    /// Отступ в списках
    static let listItemSpacing: CGFloat = sm
    
    /// Отступ для кнопок
    static let buttonPadding: CGFloat = md
    
    /// Отступ между кнопками
    static let buttonSpacing: CGFloat = sm
    
    /// Отступ для полей ввода
    static let fieldPadding: CGFloat = md
    
    /// Отступ между полями
    static let fieldSpacing: CGFloat = lg
    
    /// Отступ для иконок
    static let iconSpacing: CGFloat = sm
    
    /// Отступ для аватаров
    static let avatarSpacing: CGFloat = md
}

// MARK: - Insets
extension EdgeInsets {
    
    // MARK: - Uniform Insets
    /// Равномерные отступы
    static func all(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
    
    /// Малые равномерные отступы
    static let allSmall = EdgeInsets.all(Spacing.sm)
    
    /// Средние равномерные отступы
    static let allMedium = EdgeInsets.all(Spacing.md)
    
    /// Стандартные равномерные отступы
    static let allLarge = EdgeInsets.all(Spacing.lg)
    
    /// Большие равномерные отступы
    static let allExtraLarge = EdgeInsets.all(Spacing.xl)
    
    // MARK: - Horizontal/Vertical Insets
    /// Горизонтальные отступы
    static func horizontal(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: 0, leading: value, bottom: 0, trailing: value)
    }
    
    /// Вертикальные отступы
    static func vertical(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(top: value, leading: 0, bottom: value, trailing: 0)
    }
    
    /// Стандартные горизонтальные отступы
    static let horizontalStandard = EdgeInsets.horizontal(Spacing.lg)
    
    /// Стандартные вертикальные отступы
    static let verticalStandard = EdgeInsets.vertical(Spacing.lg)
    
    // MARK: - Card Insets
    /// Отступы для карточек
    static let card = EdgeInsets(
        top: Spacing.cardPadding,
        leading: Spacing.cardPadding,
        bottom: Spacing.cardPadding,
        trailing: Spacing.cardPadding
    )
    
    /// Отступы для компактных карточек
    static let cardCompact = EdgeInsets(
        top: Spacing.md,
        leading: Spacing.md,
        bottom: Spacing.md,
        trailing: Spacing.md
    )
    
    /// Отступы для расширенных карточек
    static let cardExpanded = EdgeInsets(
        top: Spacing.xl,
        leading: Spacing.xl,
        bottom: Spacing.xl,
        trailing: Spacing.xl
    )
    
    // MARK: - Screen Insets
    /// Отступы экрана
    static let screen = EdgeInsets(
        top: Spacing.screenPadding,
        leading: Spacing.screenPadding,
        bottom: Spacing.screenPadding,
        trailing: Spacing.screenPadding
    )
    
    /// Отступы экрана без верха (для навигации)
    static let screenNoTop = EdgeInsets(
        top: 0,
        leading: Spacing.screenPadding,
        bottom: Spacing.screenPadding,
        trailing: Spacing.screenPadding
    )
    
    /// Отступы экрана без низа (для таб бара)
    static let screenNoBottom = EdgeInsets(
        top: Spacing.screenPadding,
        leading: Spacing.screenPadding,
        bottom: 0,
        trailing: Spacing.screenPadding
    )
    
    // MARK: - Button Insets
    /// Отступы для больших кнопок
    static let buttonLarge = EdgeInsets(
        top: Spacing.lg,
        leading: Spacing.xxl,
        bottom: Spacing.lg,
        trailing: Spacing.xxl
    )
    
    /// Отступы для средних кнопок
    static let buttonMedium = EdgeInsets(
        top: Spacing.md,
        leading: Spacing.xl,
        bottom: Spacing.md,
        trailing: Spacing.xl
    )
    
    /// Отступы для малых кнопок
    static let buttonSmall = EdgeInsets(
        top: Spacing.sm,
        leading: Spacing.lg,
        bottom: Spacing.sm,
        trailing: Spacing.lg
    )
    
    // MARK: - Form Insets
    /// Отступы для полей формы
    static let field = EdgeInsets(
        top: Spacing.fieldPadding,
        leading: Spacing.fieldPadding,
        bottom: Spacing.fieldPadding,
        trailing: Spacing.fieldPadding
    )
    
    /// Отступы для групп полей
    static let fieldGroup = EdgeInsets(
        top: Spacing.lg,
        leading: Spacing.lg,
        bottom: Spacing.lg,
        trailing: Spacing.lg
    )
}

// MARK: - Corner Radius
struct CornerRadius {
    
    /// Отсутствие скругления
    static let none: CGFloat = 0
    
    /// Минимальное скругление
    static let xs: CGFloat = 4
    
    /// Малое скругление
    static let sm: CGFloat = 6
    
    /// Стандартное скругление
    static let md: CGFloat = 8
    
    /// Среднее скругление
    static let lg: CGFloat = 12
    
    /// Большое скругление
    static let xl: CGFloat = 16
    
    /// Очень большое скругление
    static let xxl: CGFloat = 20
    
    /// Максимальное скругление
    static let full: CGFloat = 1000
    
    // MARK: - Semantic Corner Radius
    /// Скругление для кнопок
    static let button: CGFloat = md
    
    /// Скругление для карточек
    static let card: CGFloat = lg
    
    /// Скругление для полей ввода
    static let field: CGFloat = sm
    
    /// Скругление для модальных окон
    static let modal: CGFloat = xl
    
    /// Скругление для аватаров
    static let avatar: CGFloat = full
    
    /// Скругление для индикаторов
    static let indicator: CGFloat = xs
    
    /// Скругление для чипов
    static let chip: CGFloat = full
}

// MARK: - Icon Sizes
struct IconSize {
    
    /// Очень малая иконка
    static let xs: CGFloat = 12
    
    /// Малая иконка
    static let sm: CGFloat = 16
    
    /// Стандартная иконка
    static let md: CGFloat = 20
    
    /// Средняя иконка
    static let lg: CGFloat = 24
    
    /// Большая иконка
    static let xl: CGFloat = 32
    
    /// Очень большая иконка
    static let xxl: CGFloat = 48
    
    /// Огромная иконка
    static let huge: CGFloat = 64
    
    // MARK: - Semantic Icon Sizes
    /// Размер иконки в кнопке
    static let button: CGFloat = md
    
    /// Размер иконки в таб баре
    static let tabBar: CGFloat = lg
    
    /// Размер иконки в навигации
    static let navigation: CGFloat = lg
    
    /// Размер иконки в списке
    static let listItem: CGFloat = md
    
    /// Размер иконки в карточке
    static let card: CGFloat = xl
    
    /// Размер аватара
    static let avatar: CGFloat = xxl
    
    /// Размер логотипа
    static let logo: CGFloat = huge
}

// MARK: - Line Heights
struct LineHeight {
    
    /// Плотная высота строки
    static let tight: CGFloat = 1.1
    
    /// Стандартная высота строки
    static let normal: CGFloat = 1.4
    
    /// Свободная высота строки
    static let relaxed: CGFloat = 1.6
    
    /// Очень свободная высота строки
    static let loose: CGFloat = 2.0
    
    // MARK: - Semantic Line Heights
    /// Высота строки для заголовков
    static let headline: CGFloat = tight
    
    /// Высота строки для основного текста
    static let body: CGFloat = normal
    
    /// Высота строки для подписей
    static let caption: CGFloat = normal
    
    /// Высота строки для кнопок
    static let button: CGFloat = tight
}

// MARK: - View Modifiers for Spacing
extension View {
    
    // MARK: - Padding Modifiers
    /// Стандартные отступы экрана
    func screenPadding() -> some View {
        self.padding(.screen)
    }
    
    /// Отступы карточки
    func cardPadding() -> some View {
        self.padding(.card)
    }
    
    /// Горизонтальные отступы экрана
    func horizontalScreenPadding() -> some View {
        self.padding(.horizontal, Spacing.screenPadding)
    }
    
    /// Вертикальные отступы экрана
    func verticalScreenPadding() -> some View {
        self.padding(.vertical, Spacing.screenPadding)
    }
    
    /// Отступы между секциями
    func sectionSpacing() -> some View {
        self.padding(.vertical, Spacing.sectionSpacing)
    }
    
    // MARK: - Corner Radius Modifiers
    /// Стандартное скругление карточки
    func cardCornerRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))
    }
    
    /// Скругление кнопки
    func buttonCornerRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: CornerRadius.button))
    }
    
    /// Скругление поля ввода
    func fieldCornerRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: CornerRadius.field))
    }
    
    /// Круглое скругление
    func circularClip() -> some View {
        self.clipShape(Circle())
    }
    
    // MARK: - Spacing Between Elements
    /// Отступы между элементами списка
    func listItemSpacing() -> some View {
        self.padding(.vertical, Spacing.listItemSpacing)
    }
    
    /// Отступы между кнопками
    func buttonSpacing() -> some View {
        self.padding(.horizontal, Spacing.buttonSpacing)
    }
    
    /// Отступы между полями
    func fieldSpacing() -> some View {
        self.padding(.vertical, Spacing.fieldSpacing)
    }
}

// MARK: - Layout Helpers
struct LayoutSpacing {
    
    // MARK: - Grid Spacing
    /// Отступы в сетке
    static let gridSpacing: CGFloat = Spacing.md
    
    /// Отступы в компактной сетке
    static let gridCompactSpacing: CGFloat = Spacing.sm
    
    /// Отступы в расширенной сетке
    static let gridExpandedSpacing: CGFloat = Spacing.lg
    
    // MARK: - Stack Spacing
    /// Отступы в стеке
    static let stackSpacing: CGFloat = Spacing.md
    
    /// Отступы в компактном стеке
    static let stackCompactSpacing: CGFloat = Spacing.sm
    
    /// Отступы в расширенном стеке
    static let stackExpandedSpacing: CGFloat = Spacing.lg
    
    // MARK: - Scroll View Spacing
    /// Отступы в скролл вью
    static let scrollViewSpacing: CGFloat = Spacing.lg
    
    /// Отступы контента в скролл вью
    static let scrollContentSpacing: CGFloat = Spacing.screenPadding
}

// MARK: - Responsive Spacing
struct ResponsiveSpacing {
    
    /// Адаптивные отступы для разных размеров экрана
    static func adaptive(
        compact: CGFloat,
        regular: CGFloat
    ) -> CGFloat {
        // В реальном приложении здесь была бы логика определения размера экрана
        return regular
    }
    
    /// Адаптивные отступы экрана
    static var screenPadding: CGFloat {
        adaptive(compact: Spacing.md, regular: Spacing.lg)
    }
    
    /// Адаптивные отступы карточек
    static var cardPadding: CGFloat {
        adaptive(compact: Spacing.sm, regular: Spacing.lg)
    }
    
    /// Адаптивные отступы между секциями
    static var sectionSpacing: CGFloat {
        adaptive(compact: Spacing.lg, regular: Spacing.xxl)
    }
}

// MARK: - Animation Constants
struct AnimationSpacing {
    
    /// Стандартная длительность анимации
    static let duration: TimeInterval = 0.3
    
    /// Быстрая анимация
    static let fast: TimeInterval = 0.15
    
    /// Медленная анимация
    static let slow: TimeInterval = 0.5
    
    /// Стандартная анимация с easing
    static let standard = Animation.easeInOut(duration: duration)
    
    /// Быстрая анимация
    static let fastAnimation = Animation.easeInOut(duration: fast)
    
    /// Плавная анимация
    static let smooth = Animation.easeOut(duration: duration)
    
    /// Анимация с пружиной
    static let spring = Animation.spring(
        response: 0.5,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
}

// MARK: - Preview Helper
#if DEBUG
struct SpacingPreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sectionSpacing) {
                
                // Spacing Values
                spacingSection("Core Spacing") {
                    spacingRow("XXS", Spacing.xxs)
                    spacingRow("XS", Spacing.xs)
                    spacingRow("SM", Spacing.sm)
                    spacingRow("MD", Spacing.md)
                    spacingRow("LG", Spacing.lg)
                    spacingRow("XL", Spacing.xl)
                    spacingRow("XXL", Spacing.xxl)
                    spacingRow("XXXL", Spacing.xxxl)
                }
                
                // Corner Radius
                spacingSection("Corner Radius") {
                    cornerRadiusRow("XS", CornerRadius.xs)
                    cornerRadiusRow("SM", CornerRadius.sm)
                    cornerRadiusRow("MD", CornerRadius.md)
                    cornerRadiusRow("LG", CornerRadius.lg)
                    cornerRadiusRow("XL", CornerRadius.xl)
                    cornerRadiusRow("XXL", CornerRadius.xxl)
                }
                
                // Icon Sizes
                spacingSection("Icon Sizes") {
                    iconSizeRow("XS", IconSize.xs)
                    iconSizeRow("SM", IconSize.sm)
                    iconSizeRow("MD", IconSize.md)
                    iconSizeRow("LG", IconSize.lg)
                    iconSizeRow("XL", IconSize.xl)
                    iconSizeRow("XXL", IconSize.xxl)
                }
            }
            .screenPadding()
        }
        .navigationTitle("Spacing System")
    }
    
    @ViewBuilder
    private func spacingSection<Content: View>(
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
    
    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack {
            Text(name)
                .font(Typography.Body.medium)
                .frame(width: 60, alignment: .leading)
            
            Text("\(Int(value))pt")
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
                .frame(width: 40, alignment: .leading)
            
            Rectangle()
                .fill(ColorPalette.Primary.main)
                .frame(width: value, height: 20)
            
            Spacer()
        }
    }
    
    private func cornerRadiusRow(_ name: String, _ value: CGFloat) -> some View {
        HStack {
            Text(name)
                .font(Typography.Body.medium)
                .frame(width: 60, alignment: .leading)
            
            Text("\(Int(value))pt")
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
                .frame(width: 40, alignment: .leading)
            
            RoundedRectangle(cornerRadius: value)
                .fill(ColorPalette.Primary.main)
                .frame(width: 60, height: 40)
            
            Spacer()
        }
    }
    
    private func iconSizeRow(_ name: String, _ value: CGFloat) -> some View {
        HStack {
            Text(name)
                .font(Typography.Body.medium)
                .frame(width: 60, alignment: .leading)
            
            Text("\(Int(value))pt")
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
                .frame(width: 40, alignment: .leading)
            
            Image(systemName: "star.fill")
                .font(.system(size: value))
                .foregroundColor(ColorPalette.Primary.main)
            
            Spacer()
        }
    }
}

#Preview {
    SpacingPreview()
}
#endif 