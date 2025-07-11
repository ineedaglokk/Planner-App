//
//  Typography.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Типографская система на основе SF Pro
//

import SwiftUI

// MARK: - Typography System
extension Font {
    
    // MARK: - Display Fonts (для больших заголовков)
    /// Очень большой заголовок для splash screens
    static let displayLarge = Font.system(size: 48, weight: .bold, design: .default)
    
    /// Большой заголовок для главных экранов
    static let displayMedium = Font.system(size: 36, weight: .bold, design: .default)
    
    /// Средний заголовок для секций
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .default)
    
    // MARK: - Headline Fonts
    /// Основной заголовок
    static let headlineLarge = Font.system(size: 24, weight: .bold, design: .default)
    
    /// Средний заголовок
    static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .default)
    
    /// Малый заголовок
    static let headlineSmall = Font.system(size: 18, weight: .semibold, design: .default)
    
    // MARK: - Title Fonts
    /// Заголовок карточки
    static let titleLarge = Font.system(size: 16, weight: .semibold, design: .default)
    
    /// Подзаголовок
    static let titleMedium = Font.system(size: 14, weight: .medium, design: .default)
    
    /// Малый заголовок
    static let titleSmall = Font.system(size: 12, weight: .medium, design: .default)
    
    // MARK: - Body Fonts
    /// Основной текст
    static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    
    /// Средний текст
    static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    
    /// Малый текст
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    // MARK: - Label Fonts
    /// Большая метка
    static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    
    /// Средняя метка
    static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    
    /// Малая метка
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .default)
    
    // MARK: - Button Fonts
    /// Большая кнопка
    static let buttonLarge = Font.system(size: 16, weight: .semibold, design: .default)
    
    /// Средняя кнопка
    static let buttonMedium = Font.system(size: 14, weight: .semibold, design: .default)
    
    /// Малая кнопка
    static let buttonSmall = Font.system(size: 12, weight: .semibold, design: .default)
    
    // MARK: - Caption Fonts
    /// Подпись
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    
    /// Малая подпись
    static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)
    
    // MARK: - Special Fonts
    /// Моноширинный шрифт для чисел
    static let number = Font.system(size: 16, weight: .medium, design: .monospaced)
    
    /// Моноширинный шрифт для больших чисел
    static let numberLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    
    /// Шрифт для кода
    static let code = Font.system(size: 14, weight: .regular, design: .monospaced)
}

// MARK: - Typography Structure
struct Typography {
    
    // MARK: - Display
    struct Display {
        static let large = Font.displayLarge
        static let medium = Font.displayMedium
        static let small = Font.displaySmall
    }
    
    // MARK: - Headline
    struct Headline {
        static let large = Font.headlineLarge
        static let medium = Font.headlineMedium
        static let small = Font.headlineSmall
    }
    
    // MARK: - Title
    struct Title {
        static let large = Font.titleLarge
        static let medium = Font.titleMedium
        static let small = Font.titleSmall
    }
    
    // MARK: - Body
    struct Body {
        static let large = Font.bodyLarge
        static let medium = Font.bodyMedium
        static let small = Font.bodySmall
    }
    
    // MARK: - Label
    struct Label {
        static let large = Font.labelLarge
        static let medium = Font.labelMedium
        static let small = Font.labelSmall
    }
    
    // MARK: - Button
    struct Button {
        static let large = Font.buttonLarge
        static let medium = Font.buttonMedium
        static let small = Font.buttonSmall
    }
    
    // MARK: - Caption
    struct Caption {
        static let regular = Font.caption
        static let small = Font.captionSmall
    }
    
    // MARK: - Special
    struct Special {
        static let number = Font.number
        static let numberLarge = Font.numberLarge
        static let code = Font.code
    }
}

// MARK: - Text Styles for specific use cases
extension Text {
    
    // MARK: - Semantic Text Styles
    /// Стиль для заголовков экранов
    func screenTitle() -> some View {
        self
            .font(Typography.Headline.large)
            .foregroundColor(ColorPalette.Text.primary)
            .fontWeight(.bold)
    }
    
    /// Стиль для заголовков карточек
    func cardTitle() -> some View {
        self
            .font(Typography.Title.large)
            .foregroundColor(ColorPalette.Text.primary)
            .fontWeight(.semibold)
    }
    
    /// Стиль для подзаголовков карточек
    func cardSubtitle() -> some View {
        self
            .font(Typography.Body.medium)
            .foregroundColor(ColorPalette.Text.secondary)
    }
    
    /// Стиль для основного текста
    func bodyText() -> some View {
        self
            .font(Typography.Body.large)
            .foregroundColor(ColorPalette.Text.primary)
            .lineSpacing(4)
    }
    
    /// Стиль для вторичного текста
    func secondaryText() -> some View {
        self
            .font(Typography.Body.medium)
            .foregroundColor(ColorPalette.Text.secondary)
    }
    
    /// Стиль для подписей
    func captionText() -> some View {
        self
            .font(Typography.Caption.regular)
            .foregroundColor(ColorPalette.Text.tertiary)
    }
    
    /// Стиль для меток
    func labelText() -> some View {
        self
            .font(Typography.Label.medium)
            .foregroundColor(ColorPalette.Text.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
    
    /// Стиль для чисел
    func numberText() -> some View {
        self
            .font(Typography.Special.number)
            .foregroundColor(ColorPalette.Text.primary)
            .fontWeight(.medium)
    }
    
    /// Стиль для больших чисел (статистика)
    func statisticNumber() -> some View {
        self
            .font(Typography.Special.numberLarge)
            .foregroundColor(ColorPalette.Primary.main)
            .fontWeight(.bold)
    }
    
    /// Стиль для кнопок
    func buttonText() -> some View {
        self
            .font(Typography.Button.medium)
            .fontWeight(.semibold)
    }
    
    /// Стиль для placeholder текста
    func placeholderText() -> some View {
        self
            .font(Typography.Body.medium)
            .foregroundColor(ColorPalette.Text.placeholder)
    }
    
    /// Стиль для ошибок
    func errorText() -> some View {
        self
            .font(Typography.Body.small)
            .foregroundColor(ColorPalette.Semantic.error)
    }
    
    /// Стиль для успеха
    func successText() -> some View {
        self
            .font(Typography.Body.small)
            .foregroundColor(ColorPalette.Semantic.success)
    }
    
    /// Стиль для предупреждений
    func warningText() -> some View {
        self
            .font(Typography.Body.small)
            .foregroundColor(ColorPalette.Semantic.warning)
    }
}

// MARK: - Line Height and Spacing
struct TypographySpacing {
    
    /// Высота строки для заголовков
    static let headlineLineHeight: CGFloat = 1.2
    
    /// Высота строки для основного текста
    static let bodyLineHeight: CGFloat = 1.4
    
    /// Высота строки для подписей
    static let captionLineHeight: CGFloat = 1.3
    
    /// Межстрочный интервал для основного текста
    static let bodyLineSpacing: CGFloat = 4
    
    /// Межстрочный интервал для заголовков
    static let headlineLineSpacing: CGFloat = 2
    
    /// Отступ между параграфами
    static let paragraphSpacing: CGFloat = 16
    
    /// Отступ для отступов в тексте
    static let textIndent: CGFloat = 20
}

// MARK: - Font Weight Extensions
extension Font.Weight {
    
    /// Очень тонкий шрифт
    static let extraLight = Font.Weight.ultraLight
    
    /// Тонкий шрифт
    static let light = Font.Weight.light
    
    /// Обычный шрифт
    static let regular = Font.Weight.regular
    
    /// Средний шрифт
    static let medium = Font.Weight.medium
    
    /// Полужирный шрифт
    static let semibold = Font.Weight.semibold
    
    /// Жирный шрифт
    static let bold = Font.Weight.bold
    
    /// Очень жирный шрифт
    static let heavy = Font.Weight.heavy
    
    /// Черный шрифт
    static let black = Font.Weight.black
}

// MARK: - Text Alignment Extensions
extension Text {
    
    /// Выравнивание по левому краю с отступом
    func leadingAligned() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Выравнивание по центру
    func centerAligned() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    /// Выравнивание по правому краю
    func trailingAligned() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    /// Многострочный текст с выравниванием
    func multilineText(alignment: TextAlignment = .leading) -> some View {
        self
            .multilineTextAlignment(alignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    /// Ограничение количества строк
    func limitedLines(_ count: Int) -> some View {
        self
            .lineLimit(count)
            .truncationMode(.tail)
    }
}

// MARK: - Accessibility Typography
extension Text {
    
    /// Поддержка Dynamic Type
    func dynamicTypeSize(_ size: DynamicTypeSize) -> some View {
        self
            .dynamicTypeSize(size)
    }
    
    /// Минимальный масштаб для читаемости
    func minimumScaleFactor(_ factor: CGFloat) -> some View {
        self
            .minimumScaleFactor(factor)
    }
    
    /// Адаптивный размер шрифта
    func adaptiveFont(
        _ baseFont: Font,
        minSize: CGFloat,
        maxSize: CGFloat
    ) -> some View {
        self
            .font(baseFont)
            .minimumScaleFactor(minSize / maxSize)
    }
}

// MARK: - Typography Constants
struct TypographyConstants {
    
    /// Минимальный размер шрифта для читаемости
    static let minimumFontSize: CGFloat = 10
    
    /// Максимальный размер шрифта для крупного текста
    static let maximumFontSize: CGFloat = 72
    
    /// Стандартный коэффициент масштабирования
    static let standardScaleFactor: CGFloat = 0.8
    
    /// Минимальная высота строки
    static let minimumLineHeight: CGFloat = 1.0
    
    /// Максимальная высота строки
    static let maximumLineHeight: CGFloat = 2.0
    
    /// Стандартное отслеживание букв
    static let standardTracking: CGFloat = 0.0
    
    /// Увеличенное отслеживание для заглавных букв
    static let uppercaseTracking: CGFloat = 0.5
    
    /// Уменьшенное отслеживание для плотного текста
    static let tightTracking: CGFloat = -0.5
}

// MARK: - Preview Helper
#if DEBUG
struct TypographyPreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                
                // Display Fonts
                typographySection("Display") {
                    Text("Display Large")
                        .font(Typography.Display.large)
                    Text("Display Medium")
                        .font(Typography.Display.medium)
                    Text("Display Small")
                        .font(Typography.Display.small)
                }
                
                // Headlines
                typographySection("Headlines") {
                    Text("Headline Large")
                        .font(Typography.Headline.large)
                    Text("Headline Medium")
                        .font(Typography.Headline.medium)
                    Text("Headline Small")
                        .font(Typography.Headline.small)
                }
                
                // Titles
                typographySection("Titles") {
                    Text("Title Large")
                        .font(Typography.Title.large)
                    Text("Title Medium")
                        .font(Typography.Title.medium)
                    Text("Title Small")
                        .font(Typography.Title.small)
                }
                
                // Body Text
                typographySection("Body") {
                    Text("Body Large - Основной текст для чтения длинных текстов и описаний")
                        .font(Typography.Body.large)
                    Text("Body Medium - Средний текст для интерфейсных элементов")
                        .font(Typography.Body.medium)
                    Text("Body Small - Малый текст для дополнительной информации")
                        .font(Typography.Body.small)
                }
                
                // Labels
                typographySection("Labels") {
                    Text("LABEL LARGE")
                        .font(Typography.Label.large)
                    Text("LABEL MEDIUM")
                        .font(Typography.Label.medium)
                    Text("LABEL SMALL")
                        .font(Typography.Label.small)
                }
                
                // Semantic Styles
                typographySection("Semantic Styles") {
                    Text("Заголовок экрана").screenTitle()
                    Text("Заголовок карточки").cardTitle()
                    Text("Подзаголовок карточки").cardSubtitle()
                    Text("Основной текст").bodyText()
                    Text("Вторичный текст").secondaryText()
                    Text("Подпись").captionText()
                    Text("1,234.56").statisticNumber()
                }
            }
            .padding()
        }
        .navigationTitle("Типографика")
    }
    
    @ViewBuilder
    private func typographySection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(ColorPalette.Text.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
    }
}

#Preview {
    TypographyPreview()
}
#endif 