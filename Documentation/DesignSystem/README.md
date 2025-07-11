# 🎨 Дизайн-система PlannerApp

Полная дизайн-система для iOS/macOS планнер приложения, следующая Apple Human Interface Guidelines и современным практикам SwiftUI.

## 📁 Структура файлов

```
Shared/
├── Themes/
│   ├── Colors.swift          # Цветовая палитра с Dark Mode
│   ├── Typography.swift      # Типографская система SF Pro
│   ├── Spacing.swift         # 8pt grid система отступов
│   └── Theme.swift           # Главная тема и утилиты
├── Components/
│   ├── Buttons/
│   │   └── PrimaryButton.swift    # Все типы кнопок
│   └── Cards/
│       └── CardView.swift         # Карточки для контента
└── Navigation/
    └── AppNavigation.swift        # Навигационная система
```

## 🎨 Цветовая палитра

### Основные цвета
```swift
// Использование цветов
ColorPalette.Primary.main       // Основной синий
ColorPalette.Secondary.main     // Вторичный фиолетовый
ColorPalette.Semantic.success   // Зеленый успеха
ColorPalette.Semantic.error     // Красный ошибки
```

### Семантические цвета
```swift
// Для привычек
ColorPalette.Habits.health      // Здоровье
ColorPalette.Habits.productivity // Продуктивность
ColorPalette.Habits.learning    // Обучение
ColorPalette.Habits.social      // Социальное

// Для финансов
ColorPalette.Financial.income   // Доходы
ColorPalette.Financial.expense  // Расходы
ColorPalette.Financial.savings  // Сбережения

// Для приоритетов
ColorPalette.Priority.low       // Низкий
ColorPalette.Priority.medium    // Средний
ColorPalette.Priority.high      // Высокий
ColorPalette.Priority.urgent    // Срочный
```

### Фоновые цвета
```swift
ColorPalette.Background.primary    // Основной фон
ColorPalette.Background.surface    // Поверхности
ColorPalette.Background.elevated   // Поднятые элементы
```

### Текстовые цвета
```swift
ColorPalette.Text.primary      // Основной текст
ColorPalette.Text.secondary    // Вторичный текст
ColorPalette.Text.tertiary     // Третичный текст
ColorPalette.Text.onColor      // Текст на цветном фоне
```

### Поддержка Dark Mode
Все цвета автоматически адаптируются к светлой/темной теме через Color Assets или динамические цвета:

```swift
Color.dynamic(
    light: .white,
    dark: .black
)
```

## ✍️ Типографика

### Базовые размеры
```swift
Typography.Display.large        // 48pt, bold - Splash screens
Typography.Display.medium       // 36pt, bold - Главные экраны
Typography.Headline.large       // 24pt, bold - Основные заголовки
Typography.Title.large          // 16pt, semibold - Заголовки карточек
Typography.Body.large           // 16pt, regular - Основной текст
Typography.Caption.regular      // 11pt, regular - Подписи
```

### Семантические стили
```swift
Text("Заголовок экрана").screenTitle()
Text("Заголовок карточки").cardTitle()
Text("Подзаголовок").cardSubtitle()
Text("Основной текст").bodyText()
Text("1,234.56").statisticNumber()
Text("Подпись").captionText()
Text("МЕТКА").labelText()
```

### Специальные шрифты
```swift
Typography.Special.number       // Моноширинный для чисел
Typography.Special.numberLarge  // Крупные числа для статистики
Typography.Special.code         // Моноширинный для кода
```

## 📏 Система отступов (8pt Grid)

### Базовые значения
```swift
Spacing.xs    // 4pt
Spacing.sm    // 8pt
Spacing.md    // 12pt
Spacing.lg    // 16pt
Spacing.xl    // 20pt
Spacing.xxl   // 24pt
Spacing.xxxl  // 32pt
```

### Семантические отступы
```swift
Spacing.screenPadding   // 16pt - Отступы экрана
Spacing.cardPadding     // 16pt - Отступы карточек
Spacing.sectionSpacing  // 24pt - Между секциями
Spacing.buttonPadding   // 12pt - В кнопках
```

### Готовые EdgeInsets
```swift
.padding(.card)              // Отступы карточки
.padding(.screen)            // Отступы экрана
.padding(.buttonLarge)       // Отступы большой кнопки
.padding(.field)             // Отступы полей ввода
```

### View модификаторы
```swift
.screenPadding()             // Отступы экрана
.cardPadding()               // Отступы карточки
.sectionSpacing()            // Между секциями
.horizontalScreenPadding()   // Только горизонтальные
```

### Скругления
```swift
CornerRadius.xs     // 4pt
CornerRadius.sm     // 6pt
CornerRadius.md     // 8pt
CornerRadius.lg     // 12pt
CornerRadius.xl     // 16pt
CornerRadius.card   // 12pt - Для карточек
CornerRadius.button // 8pt - Для кнопок
CornerRadius.full   // 1000pt - Круглое
```

### Размеры иконок
```swift
IconSize.xs      // 12pt
IconSize.sm      // 16pt
IconSize.md      // 20pt
IconSize.lg      // 24pt
IconSize.xl      // 32pt
IconSize.tabBar  // 24pt - Таб бар
IconSize.button  // 20pt - Кнопки
IconSize.avatar  // 48pt - Аватары
```

## 🔘 Кнопки

### Основные кнопки
```swift
// Primary кнопка
PrimaryButton("Сохранить", icon: "checkmark") {
    // действие
}

// Secondary кнопка
SecondaryButton("Отмена") {
    // действие
}

// Destructive кнопка
DestructiveButton("Удалить", icon: "trash") {
    // действие
}

// Outline кнопка
OutlineButton("Подробнее") {
    // действие
}
```

### Размеры кнопок
```swift
PrimaryButton("Текст", size: .small)   // 36pt высота
PrimaryButton("Текст", size: .medium)  // 44pt высота (по умолчанию)
PrimaryButton("Текст", size: .large)   // 52pt высота
```

### Состояния кнопок
```swift
PrimaryButton("Загрузка", isLoading: true) { }
PrimaryButton("Отключена", isDisabled: true) { }
```

### Иконочные кнопки
```swift
IconButton(icon: "heart", style: .primary) { }
IconButton(icon: "star", style: .tertiary) { }
```

### Floating Action Button
```swift
FloatingActionButton(icon: "plus") {
    // действие создания
}
```

### Tag кнопки
```swift
TagButton("Категория", isSelected: true) {
    // переключение состояния
}
```

## 🃏 Карточки

### Базовая карточка
```swift
CardView {
    VStack {
        Text("Содержимое")
        Text("Подробности")
    }
}
```

### Стили карточек
```swift
CardView(style: .standard) { content }    // Обычная с тенью
CardView(style: .elevated) { content }    // Поднятая
CardView(style: .outlined) { content }    // С границей
CardView(style: .filled) { content }      // Залитая цветом
CardView(style: .compact) { content }     // Компактная
```

### Состояния карточек
```swift
CardView(state: .selected) { content }    // Выбранная
CardView(state: .disabled) { content }    // Отключенная
CardView(state: .loading) { content }     // Загрузка
```

### Готовые карточки

#### Info Card
```swift
InfoCard(
    title: "Привычки",
    subtitle: "Выполнено сегодня", 
    icon: "repeat.circle",
    value: "5/8"
) {
    // действие при нажатии
}
```

#### Statistic Card
```swift
StatisticCard(
    title: "Доходы",
    value: "₽50,000",
    change: "+12%",
    changeType: .positive,
    icon: "arrow.up.circle",
    color: ColorPalette.Financial.income
)
```

#### Action Card
```swift
ActionCard(
    title: "Создать привычку",
    description: "Добавить новую полезную привычку",
    icon: "plus.circle"
) {
    // действие
}
```

#### Progress Card
```swift
ProgressCard(
    title: "Прогресс за месяц",
    subtitle: "Выполнено привычек",
    progress: 0.7,
    total: "21 из 30 дней",
    color: ColorPalette.Semantic.success
)
```

#### Empty State Card
```swift
EmptyStateCard(
    title: "Нет данных",
    description: "Здесь будут отображаться записи",
    icon: "tray",
    actionTitle: "Добавить первую запись"
) {
    // действие
}
```

## 🧭 Навигация

### Tab структура
```swift
enum TabItem {
    case dashboard  // Обзор
    case habits     // Привычки  
    case tasks      // Задачи
    case finance    // Финансы
    case settings   // Настройки
}
```

### Навигация между экранами
```swift
// Переход к созданию привычки
NavigationManager.shared.navigate(to: .createHabit, in: .habits)

// Переход к деталям задачи
NavigationManager.shared.navigate(to: .taskDetail("task-id"), in: .tasks)

// Возврат к корню
NavigationManager.shared.popToRoot(in: .habits)
```

### Deep Links
```swift
// Поддержка URL схем
// planner://habits/create
// planner://tasks/detail/task-id
// planner://finance/budget
```

### Кастомная навигационная панель
```swift
.customNavigationBar(
    title: "Привычки",
    trailingAction: { /* создать */ },
    trailingIcon: "plus"
)
```

## 🎭 Тени и эффекты

### Готовые стили теней
```swift
.applyShadow(.card)      // Мягкая тень для карточек
.applyShadow(.elevated)  // Тень для поднятых элементов
.applyShadow(.modal)     // Тень для модальных окон
.applyShadow(.pressed)   // Тень при нажатии

// Или через модификаторы
.cardShadow()
.elevatedShadow()
.modalShadow()
```

### Градиенты
```swift
LinearGradient.primaryGradient    // Основной градиент
LinearGradient.successGradient    // Градиент успеха
LinearGradient.cardGradient       // Градиент для карточек
LinearGradient.achievementGradient // Градиент достижений
```

## 🎨 Иконки

### SF Symbols
```swift
IconView("star.fill", style: .navigation)  // Навигация
IconView("heart", style: .button)          // Кнопка
IconView("bell", style: .card)             // Карточка
IconView("checkmark", style: .status)      // Статус
```

### Стили иконок
```swift
IconStyle.navigation    // Для навигации
IconStyle.button        // Для кнопок
IconStyle.listItem      // Для списков
IconStyle.card          // Для карточек
IconStyle.status        // Для статуса
```

## 🎬 Анимации

### Готовые анимации
```swift
.animation(.appDefault, value: someValue)      // Стандартная
.animation(.quickResponse, value: someValue)   // Быстрая
.animation(.smoothTransition, value: someValue) // Плавная
.animation(.interactive, value: someValue)     // Интерактивная
.animation(.entrance, value: someValue)        // Появление
.animation(.exit, value: someValue)           // Исчезновение
```

### Константы времени
```swift
AnimationSpacing.fast      // 0.15s
AnimationSpacing.duration  // 0.3s (стандарт)
AnimationSpacing.slow      // 0.5s
```

## 📱 Адаптивность

### Responsive Design
```swift
ResponsiveDesign.adaptive(
    compact: 16,    // iPhone SE
    regular: 20,    // iPhone 12
    large: 24,      // iPhone 12 Pro Max
    extraLarge: 28  // iPad
)
```

### Accessibility
```swift
AccessibilityTheme.enhancedTouchTargetSize    // 44pt мин. размер
AccessibilityTheme.accessibilitySpacing      // Увеличенные отступы
AccessibilityTheme.accessibilityFontScale    // Масштаб шрифтов
```

## 🎨 Комплексные стили

### Применение стилей к View
```swift
someView
    .cardStyle()              // Стиль карточки
    .screenContentStyle()     // Стиль экранного контента
    .sectionStyle()           // Стиль секции
    .interactiveStyle()       // Интерактивный стиль
```

## 📖 Примеры использования

### Экран с карточками
```swift
ScrollView {
    LazyVStack(spacing: Spacing.sectionSpacing) {
        InfoCard(
            title: "Привычки сегодня",
            subtitle: "Выполнено",
            icon: "repeat.circle",
            value: "5/8"
        )
        
        StatisticCard(
            title: "Прогресс",
            value: "85%",
            change: "+12%",
            changeType: .positive
        )
        
        ActionCard(
            title: "Добавить привычку",
            icon: "plus.circle"
        ) {
            // действие
        }
    }
    .screenPadding()
}
.screenContentStyle()
```

### Форма с кнопками
```swift
VStack(spacing: Spacing.fieldSpacing) {
    // Поля формы
    
    HStack(spacing: Spacing.buttonSpacing) {
        SecondaryButton("Отмена") {
            // отмена
        }
        
        PrimaryButton("Сохранить", icon: "checkmark") {
            // сохранение
        }
    }
}
.cardPadding()
```

## 🔧 Кастомизация

### Создание собственной темы
```swift
struct CustomTheme: ThemeProtocol {
    let colors = ColorPalette.self
    let typography = Typography.self
    let spacing = Spacing.self
    let cornerRadius = CornerRadius.self
    let iconSize = IconSize.self
    let animations = AnimationSpacing.self
}

// Применение
ThemeManager.shared.setTheme(CustomTheme())
```

### Переопределение цветов
```swift
extension ColorPalette {
    struct Custom {
        static let brandColor = Color("CustomBrand")
        static let accentColor = Color("CustomAccent")
    }
}
```

## 📝 Best Practices

### 1. Консистентность
- Всегда используйте дизайн-систему вместо хардкода
- Придерживайтесь семантических названий цветов
- Используйте готовые компоненты

### 2. Отступы
- Следуйте 8pt grid системе
- Используйте семантические названия
- Применяйте готовые модификаторы

### 3. Типографика
- Используйте семантические стили текста
- Учитывайте иерархию информации
- Поддерживайте Dynamic Type

### 4. Цвета
- Проверяйте контрастность для accessibility
- Используйте семантические цвета по назначению
- Тестируйте в Dark Mode

### 5. Компоненты
- Комбинируйте базовые компоненты для сложных UI
- Используйте состояния компонентов (loading, disabled)
- Добавляйте haptic feedback для интерактивности

### 6. Анимации
- Используйте готовые предустановки
- Добавляйте анимации для улучшения UX
- Не переусердствуйте с эффектами

## 🚀 Быстрый старт

1. **Импорт дизайн-системы:**
```swift
import SwiftUI
// Все файлы дизайн-системы доступны автоматически
```

2. **Создание экрана:**
```swift
struct NewScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.sectionSpacing) {
                InfoCard(
                    title: "Заголовок",
                    subtitle: "Описание",
                    icon: "star"
                )
                
                PrimaryButton("Действие") {
                    // логика
                }
            }
            .screenPadding()
        }
        .customNavigationBar(title: "Экран")
    }
}
```

3. **Применение темы:**
```swift
@main
struct PlannerApp: App {
    var body: some Scene {
        WindowGroup {
            AppNavigationView()
                .environment(\.theme, DefaultTheme())
        }
    }
}
```

## 📊 Файлы для Color Assets

Создайте следующие Color Assets в Xcode:

**Primary Colors:**
- PrimaryBlue
- PrimaryBlueLight  
- PrimaryBlueDark

**Secondary Colors:**
- SecondaryPurple
- SecondaryPurpleLight
- SecondaryPurpleDark

**Semantic Colors:**
- Success, Warning, Error, Info

**Background Colors:**
- Background, Surface, SurfaceElevated, GroupedBackground

**Text Colors:**
- TextPrimary, TextSecondary, TextTertiary, TextPlaceholder, TextOnColor

**Border Colors:**
- Border, Separator, Focus

И остальные цвета согласно Colors.swift файлу.

---

## 🎯 Заключение

Эта дизайн-система обеспечивает:
- ✅ Консистентный пользовательский интерфейс
- ✅ Быструю разработку новых экранов
- ✅ Легкую поддержку и обновления
- ✅ Соответствие Apple HIG
- ✅ Полную поддержку Dark Mode
- ✅ Accessibility готовность
- ✅ Масштабируемость и гибкость

Используйте компоненты дизайн-системы для создания красивого и функционального планнер приложения! 🚀 