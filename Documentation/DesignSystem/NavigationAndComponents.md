# 🧭 Навигация и Дизайн-система

## 📋 Обзор

Навигационная система и компоненты дизайн-системы приложения IWBB созданы для обеспечения единообразного и интуитивного пользовательского опыта на всех платформах.

## 🏗️ Навигационная структура

### TabView с 5 основными разделами

```swift
enum TabItem: String, CaseIterable {
    case dashboard = "dashboard"    // Дашборд (обзор всего)
    case habits = "habits"          // Привычки
    case tasks = "tasks"            // Задачи & Цели
    case finance = "finance"        // Финансы
    case settings = "settings"      // Профиль & Настройки
}
```

#### 📱 Адаптивная навигация
- **iPhone**: TabView с 5 вкладками
- **iPad**: TabView или NavigationSplitView (в зависимости от контекста)
- **Mac**: NavigationSplitView с боковой панелью

### NavigationManager

Централизованный менеджер навигации с поддержкой:
- Навигационных стеков для каждой вкладки
- Deep links
- Программной навигации
- Состояния навигации

```swift
@Observable
final class NavigationManager {
    var selectedTab: TabItem = .dashboard
    var dashboardPath = NavigationPath()
    var habitsPath = NavigationPath()
    // ... другие пути
    
    func navigate(to destination: NavigationDestination, in tab: TabItem)
    func handleDeepLink(_ url: URL)
}
```

## 🎨 Дизайн-система

### 🌈 Цветовая палитра

#### Основные цвета
- **Primary**: Мотивирующий синий (#007AFF)
- **Secondary**: Теплый фиолетовый (#5856D6)
- **Success**: Свежий зеленый (#34C759)
- **Warning**: Энергичный оранжевый (#FF9500)
- **Error**: Мягкий красный (#FF3B30)

#### Семантические цвета
```swift
struct ColorPalette {
    struct Habits {
        static let health = Color.habitHealth
        static let productivity = Color.habitProductivity
        static let learning = Color.habitLearning
        static let social = Color.habitSocial
    }
    
    struct Financial {
        static let income = Color.income
        static let expense = Color.expense
        static let savings = Color.savings
    }
    
    struct Priority {
        static let low = Color.priorityLow
        static let medium = Color.priorityMedium
        static let high = Color.priorityHigh
        static let urgent = Color.priorityUrgent
    }
}
```

### 📝 Типографика

Использует SF Pro с семантическими стилями:

```swift
struct Typography {
    struct Title {
        static let large = Font.system(size: 34, weight: .bold)
        static let medium = Font.system(size: 28, weight: .bold)
        static let small = Font.system(size: 22, weight: .bold)
    }
    
    struct Headline {
        static let large = Font.system(size: 20, weight: .semibold)
        static let medium = Font.system(size: 18, weight: .semibold)
    }
    
    struct Body {
        static let large = Font.system(size: 18, weight: .regular)
        static let medium = Font.system(size: 16, weight: .regular)
        static let small = Font.system(size: 14, weight: .regular)
    }
}
```

### 📏 Система отступов (8pt grid)

```swift
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}
```

### 🔘 Система кнопок

#### Основные типы кнопок
- **PrimaryButton**: Основные действия
- **SecondaryButton**: Вторичные действия
- **TertiaryButton**: Третичные действия
- **DestructiveButton**: Удаление/опасные действия
- **OutlineButton**: Действия с обводкой
- **IconButton**: Иконки с действиями
- **FloatingActionButton**: Плавающая кнопка действия
- **ToggleButton**: Переключатели
- **LinkButton**: Ссылки

#### Размеры кнопок
```swift
enum ButtonSize {
    case small     // 36pt height
    case medium    // 44pt height  
    case large     // 52pt height
}
```

### 🃏 Система карточек

#### CardView - базовый компонент
```swift
enum CardStyle {
    case standard   // Обычная карточка
    case elevated   // Поднятая карточка
    case outlined   // С обводкой
    case filled     // Заполненная
    case compact    // Компактная
}
```

#### Специализированные карточки
- **HabitCard**: Для отображения привычек
- **TaskCard**: Для задач
- **StatisticCard**: Для статистики
- **ActionCard**: Для действий

### 📊 Компоненты форм

#### Текстовые поля
- **PlannerTextField**: Основное поле ввода
- **PlannerTextEditor**: Многострочный ввод
- Поддержка состояний: normal, focused, error, disabled, success
- Встроенная поддержка Accessibility

#### Селекторы
- **PlannerPicker**: Выпадающий список
- **PlannerSegmentedPicker**: Сегментированный контрол
- **PlannerMultiSelectionPicker**: Множественный выбор

#### Переключатели
- **PlannerToggle**: Переключатель с тремя стилями
  - `.default`: Стандартный
  - `.card`: В виде карточки
  - `.compact`: Компактный

### 📈 Компоненты графиков

Обертки над Swift Charts:
- **ProgressRingChart**: Кольцевой прогресс
- **PlannerBarChart**: Столбчатая диаграмма
- **PlannerLineChart**: Линейный график
- **PlannerPieChart**: Круговая диаграмма
- **HabitStreakChart**: Календарь привычек

### ⚡ Компоненты прогресса

- **PlannerProgressBar**: Линейный прогресс
- **SegmentedProgressBar**: Сегментированный прогресс
- **CircularProgress**: Круговой прогресс
- **StepProgressIndicator**: Пошаговый индикатор
- **LoadingProgress**: Индикаторы загрузки
- **AchievementProgress**: Прогресс достижений

### 🔄 Состояния пустых экранов

```swift
struct EmptyStateConfiguration {
    enum EmptyStateStyle {
        case minimal      // Минимальный
        case detailed     // Детальный
        case illustration // С иллюстрацией
    }
    
    enum EmptyStateAnimation {
        case none, bounce, pulse, float, rotate
    }
}
```

#### Предустановленные состояния
- `.noHabits`: Нет привычек
- `.noTasks`: Нет задач
- `.noGoals`: Нет целей
- `.noTransactions`: Нет транзакций
- `.networkError`: Ошибка сети
- `.noSearchResults`: Нет результатов поиска

## 📱 Адаптивность

### Система адаптивности
```swift
enum DeviceType {
    case iPhone, iPad, mac
}

enum ScreenSizeCategory {
    case compact        // iPhone mini, SE
    case regular        // iPhone standard
    case large          // iPhone Pro Max
    case extraLarge     // iPad, Mac
}
```

### Адаптивные модификаторы
```swift
extension View {
    func adaptivePadding(_ base: CGFloat = 16) -> some View
    func adaptiveMargin(_ base: CGFloat = 20) -> some View
    func adaptiveContentWidth() -> some View
    func adaptiveCornerRadius(_ size: AdaptiveCornerRadiusSize = .medium) -> some View
}
```

### ResponsiveGrid
Автоматически адаптируется под размер экрана:
- iPhone: 1-2 колонки
- iPad: 3 колонки
- Mac: 4 колонки

## ♿ Accessibility

### Поддержка VoiceOver
Все компоненты включают:
- `accessibilityLabel`
- `accessibilityHint`
- `accessibilityValue`
- `accessibilityTraits`

### Поддержка Dynamic Type
- Адаптивная типографика
- Масштабирование интерфейса
- Увеличенные размеры для accessibility

## 🎭 Анимации и переходы

### Предустановленные анимации
```swift
extension Animation {
    static let appDefault = Animation.easeInOut(duration: 0.3)
    static let quickResponse = Animation.easeOut(duration: 0.1)
    static let smoothTransition = Animation.easeInOut(duration: 0.5)
    static let interactive = Animation.spring(response: 0.4, dampingFraction: 0.8)
}
```

### Haptic Feedback
- Тактильная обратная связь для всех интерактивных элементов
- Различные типы в зависимости от действия

## 🔧 Инструменты разработки

### Preview Helpers
```swift
// Быстрый preview для разных устройств
view.previewWithCommonDevices()
view.previewWithDarkMode()
view.previewWithAccessibility()

// Preview с состояниями
view.previewWithStates(states) { state in
    ComponentView(state: state)
}
```

### Mock Data
Готовые моки для всех типов данных:
- `MockDataProvider.mockHabits`
- `MockDataProvider.mockTasks`
- `MockDataProvider.mockTransactions`
- `MockDataProvider.mockChartData`

## 🏃‍♂️ Performance оптимизация

### ViewBuilder оптимизация
- Использование `@ViewBuilder` для условного рендеринга
- Ленивые контейнеры (`LazyVStack`, `LazyHStack`)
- Эффективное обновление только необходимых компонентов

### Анимации
- Оптимизированные анимации с минимальным влиянием на производительность
- Использование `@State` для локального состояния анимаций

## 📋 Checklist использования

При создании нового экрана убедитесь:

- [ ] ✅ Используются компоненты дизайн-системы
- [ ] 🎨 Соблюдается цветовая палитра
- [ ] 📝 Применяется семантическая типографика  
- [ ] 📏 Используется система отступов (8pt grid)
- [ ] 📱 Интерфейс адаптивен для всех устройств
- [ ] ♿ Поддерживается Accessibility
- [ ] 🔄 Реализованы состояния загрузки и ошибок
- [ ] 🎭 Добавлены соответствующие анимации
- [ ] 🔧 Созданы Preview с разными состояниями

## 📖 Дополнительные ресурсы

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Swift Charts](https://developer.apple.com/documentation/charts/)

---

💡 **Совет**: Всегда начинайте с использования существующих компонентов дизайн-системы. Если нужного компонента нет, создайте его по образцу существующих и добавьте в систему.

✨ **Помните**: Консистентность дизайна - залог отличного пользовательского опыта! 