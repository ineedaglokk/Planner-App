# 🚀 Архитектура Планнер - Краткий справочник

## 📋 Ключевые принципы

- **Offline-first** - приложение работает без интернета
- **MVVM + SwiftUI** - архитектурный паттерн 
- **SwiftData + CloudKit** - современное хранение данных
- **Protocol-Oriented** - абстракции через протоколы
- **Dependency Injection** - внедрение зависимостей

## 🏗️ Структура кода

```
📁 Features/Habits/
├── Views/          # SwiftUI экраны
├── ViewModels/     # Бизнес-логика UI
└── Components/     # Переиспользуемые UI элементы

📁 Core/
├── Models/         # SwiftData модели
├── Services/       # Бизнес-логика
├── Repositories/   # Доступ к данным
└── Utilities/      # Вспомогательные функции
```

## 🔧 Основные паттерны

### ViewModel Pattern
```swift
@Observable
final class HabitsListViewModel {
    struct State { /* состояние */ }
    enum Input { /* действия пользователя */ }
    
    func send(_ input: Input) { /* обработка */ }
}
```

### Repository Pattern
```swift
protocol HabitRepositoryProtocol {
    func fetchActiveHabits() async throws -> [Habit]
    func save(_ habit: Habit) async throws
}
```

### Service Container
```swift
@Environment(\.services) private var services
// services.habitRepository, services.gameService, etc.
```

## 📱 Модели данных

| Модель | Назначение | Ключевые поля |
|--------|------------|---------------|
| `User` | Профиль пользователя | name, level, totalPoints |
| `Habit` | Привычки | name, frequency, currentStreak |
| `Task` | Задачи | title, priority, dueDate |
| `Transaction` | Финансы | amount, type, category |
| `Goal` | Цели | title, targetDate, progress |

## 🌐 Интеграции

- **WidgetKit** - виджеты главного экрана
- **App Intents** - Siri и Shortcuts
- **HealthKit** - данные о здоровье
- **CloudKit** - синхронизация данных
- **UserNotifications** - push уведомления

## 🎨 UI Компоненты

```swift
// Основные компоненты дизайн-системы
PrimaryButton("Сохранить") { /* action */ }
CardView { /* content */ }
ProgressRingView(progress: 0.75)
```

## 🔐 Безопасность

- Biometric authentication для доступа
- Data encryption для sensitive данных
- Privacy-first подход к данным
- Secure CloudKit синхронизация

## 📊 State Management

```swift
// Реактивное обновление UI
@Observable class AppState {
    var user: User?
    var isAuthenticated: Bool = false
    var habitsState = HabitsState()
}
```

## 🧪 Тестирование

```swift
// Структура тестов
BaseTestCase           # Базовый класс для всех тестов
MockServiceContainer   # Mock сервисы для тестирования
XCTestCase extensions  # Вспомогательные методы
```

## 📦 Зависимости

| Технология | Использование |
|------------|---------------|
| SwiftUI 5.0 | Пользовательский интерфейс |
| SwiftData | Локальная база данных |
| CloudKit | Синхронизация в облаке |
| Swift Charts | Графики и диаграммы |
| WidgetKit | Виджеты |

## 🚀 Quick Start для разработки

1. **Создать новую фичу:**
   ```
   📁 Features/NewFeature/
   ├── Views/NewFeatureView.swift
   ├── ViewModels/NewFeatureViewModel.swift
   └── Components/NewFeatureCard.swift
   ```

2. **Добавить новую модель:**
   ```swift
   @Model
   final class NewModel: CloudKitSyncable, Timestampable {
       // реализация
   }
   ```

3. **Создать сервис:**
   ```swift
   protocol NewServiceProtocol { }
   final class NewService: NewServiceProtocol { }
   ```

4. **Добавить в ServiceContainer:**
   ```swift
   lazy var newService: NewServiceProtocol = NewService()
   ```

## 🎯 Checklist для каждой фичи

- [ ] ✅ ViewModel с Observable pattern
- [ ] 🎨 UI компоненты следуют дизайн-системе
- [ ] 💾 Repository для доступа к данным
- [ ] 🧪 Unit тесты для бизнес-логики
- [ ] 📱 Адаптивность для iPad/Mac
- [ ] ♿ Accessibility поддержка
- [ ] 🔄 CloudKit синхронизация
- [ ] 📊 Analytics tracking

---

💡 **Совет:** Всегда начинайте с простой MVP версии функции, затем добавляйте сложность.

📖 **Полная документация:** См. `planner_app_architecture.md` для детального описания. 