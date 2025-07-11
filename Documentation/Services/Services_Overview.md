# 🚀 Сервисная архитектура Планнер - Этап 6

## 📋 Обзор

В рамках Этапа 6 была создана полная сервисная архитектура для приложения Планнер, включающая:

- **DataService** - управление данными и CRUD операции
- **NotificationService** - локальные уведомления и разрешения
- **UserDefaultsService** - type-safe настройки приложения
- **ErrorHandlingService** - централизованная обработка ошибок
- **ServiceContainer** - dependency injection контейнер
- **MockServices** - тестовые реализации
- **Unit Tests** - comprehensive тестирование

## 🏗️ Архитектурные принципы

### ✅ Dependency Injection
Все сервисы управляются через ServiceContainer с lazy initialization:

```swift
@Environment(\.services) private var services

// Использование в View
services.dataService.save(model)
services.notificationService.scheduleReminder()
```

### ✅ Protocol-based Design
Каждый сервис имеет протокол для тестирования и гибкости:

```swift
protocol DataServiceProtocol {
    func save<T: PersistentModel>(_ model: T) async throws
    func fetch<T: PersistentModel>(_ type: T.Type) async throws -> [T]
}
```

### ✅ Swift Concurrency
Все сервисы используют async/await:

```swift
try await dataService.save(habit)
let habits = try await dataService.fetch(Habit.self)
```

### ✅ Error Handling с Result Types
Централизованная обработка ошибок:

```swift
enum AppError: Error {
    case networkUnavailable
    case dataCorrupted(String)
    case syncFailed(String)
}
```

### ✅ Observable Pattern
Сервисы поддерживают SwiftUI @Observable:

```swift
@Observable
final class DataService: DataServiceProtocol {
    // Автоматические обновления UI
}
```

## 📦 Созданные сервисы

### 1. DataService
**Файл:** `IWBB/Core/Services/DataService.swift`

Управляет всеми CRUD операциями с SwiftData и CloudKit синхронизацией.

#### Основные возможности:
- ✅ CRUD операции для всех моделей
- ✅ Batch операции для производительности  
- ✅ CloudKit синхронизация с retry логикой
- ✅ Background context для heavy operations
- ✅ Автоматическое обновление временных меток
- ✅ Error handling с AppError типами

#### Пример использования:
```swift
// Сохранение модели
let habit = Habit(name: "Утренняя зарядка")
try await dataService.save(habit)

// Загрузка с предикатом
let activeHabits = try await dataService.fetch(
    Habit.self, 
    predicate: #Predicate { $0.isActive }
)

// Batch операции
try await dataService.batchSave(habits)
```

### 2. NotificationService
**Файл:** `IWBB/Core/Services/NotificationService.swift`

Управляет локальными уведомлениями с категориями и действиями.

#### Основные возможности:
- ✅ Запрос разрешений с provisional и critical alerts
- ✅ Категории уведомлений (привычки, задачи, бюджет)
- ✅ Интерактивные действия в уведомлениях
- ✅ Обработка ответов пользователя
- ✅ Планирование повторяющихся уведомлений

#### Пример использования:
```swift
// Запрос разрешений
let granted = await notificationService.requestPermission()

// Планирование напоминания о привычке
try await notificationService.scheduleHabitReminder(
    habitID,
    name: "Медитация",
    time: reminderTime
)

// Отмена уведомления
await notificationService.cancelNotification(for: "habit-\(habitID)")
```

### 3. UserDefaultsService
**Файл:** `IWBB/Core/Services/UserDefaultsService.swift`

Type-safe управление настройками приложения с кэшированием.

#### Основные возможности:
- ✅ Type-safe свойства для всех настроек
- ✅ Кэширование для производительности
- ✅ Поддержка Codable типов
- ✅ Экспорт/импорт настроек
- ✅ Сброс к значениям по умолчанию

#### Пример использования:
```swift
// Базовые настройки
userDefaultsService.themeMode = .dark
userDefaultsService.isCloudSyncEnabled = true

// Generic методы
struct CustomSettings: Codable {
    let feature: Bool
}
userDefaultsService.setValue(settings, for: .customKey)
let settings: CustomSettings? = userDefaultsService.getValue(CustomSettings.self, for: .customKey)
```

### 4. ErrorHandlingService
**Файл:** `IWBB/Core/Services/ErrorHandlingService.swift`

Централизованная обработка ошибок с логированием и recovery стратегиями.

#### Основные возможности:
- ✅ Централизованная обработка всех ошибок
- ✅ Автоматические recovery стратегии
- ✅ Logging с разными уровнями severity
- ✅ История ошибок для диагностики
- ✅ User-friendly сообщения
- ✅ Сбор информации об устройстве

#### Пример использования:
```swift
// Обработка ошибки
await errorHandlingService.handle(
    error, 
    context: .dataOperation("save habit")
)

// Попытка восстановления
let recovered = await errorHandlingService.attemptRecovery(for: error)

// Получение опций восстановления
let options = errorHandlingService.getRecoveryOptions(for: error)
```

## 🔧 ServiceContainer

**Файл:** `IWBB/Core/Services/ServiceContainer.swift`

Центральный контейнер для управления всеми сервисами.

### Возможности:
- ✅ Lazy initialization сервисов
- ✅ Правильный порядок инициализации
- ✅ SwiftUI Environment integration
- ✅ Factory methods для testing/preview
- ✅ Service lifecycle management

### Использование в SwiftUI:
```swift
@main
struct PlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withServices(ServiceContainer())
        }
    }
}

// В View
struct HabitsView: View {
    @Environment(\.services) private var services
    
    var body: some View {
        // Использование сервисов
    }
}
```

### Factory Methods:
```swift
// Для тестирования
let container = ServiceContainer.testing()

// Для превью
let container = ServiceContainer.preview()

// Mock сервисы
let container = ServiceContainer.mock()
```

## 🧪 Mock Services и тестирование

**Файл:** `IWBB/Core/Services/MockServices.swift`

Настраиваемые mock сервисы для тестирования различных сценариев.

### Поведения Mock сервисов:
```swift
enum MockDataServiceBehavior {
    case normal      // Нормальная работа
    case saveFails   // Ошибки сохранения
    case fetchFails  // Ошибки загрузки
    case syncFails   // Ошибки синхронизации
    case slow        // Медленные операции
}
```

### Создание тестового контейнера:
```swift
let container = MockServiceFactory.createMockServiceContainer(
    dataServiceBehavior: .saveFails,
    notificationServiceBehavior: .permissionDenied
)
```

## 📋 Unit Tests

**Файл:** `Tests/ServiceTests/ServiceTests.swift`

Comprehensive тестирование всех сервисов.

### Покрытие тестами:
- ✅ **Инициализация и cleanup** всех сервисов
- ✅ **CRUD операции** DataService
- ✅ **Notification scheduling** и management
- ✅ **UserDefaults** operations и behaviors
- ✅ **Error handling** и recovery
- ✅ **Integration тесты** между сервисами
- ✅ **Performance тесты** для slow operations
- ✅ **Edge cases** и failure scenarios

### Запуск тестов:
```bash
# Все тесты
xcodebuild test -scheme IWBB

# Конкретный класс
xcodebuild test -scheme IWBB -only-testing:ServiceTests
```

## 🎯 Интеграции

### CloudKit Sync
```swift
// Автоматическая отметка для синхронизации
if var syncable = model as? CloudKitSyncable {
    syncable.markForSync()
}

// Batch синхронизация
try await dataService.performBatchSync()
```

### Network Connectivity
```swift
// Проверка сети для recovery
private func checkNetworkConnectivity() async -> Bool {
    // Реализация проверки сети
}
```

### Background Tasks
```swift
// Background context для heavy operations
await backgroundContext.perform {
    // Тяжелые операции в background
}
```

## 📊 Производительность

### Memory Management
- ✅ **NSCache** для часто используемых данных
- ✅ **Background contexts** для batch операций
- ✅ **Lazy loading** сервисов
- ✅ **Concurrent queues** для cache operations

### Batch Operations
```swift
// Эффективные batch операции
try await dataService.batchSave(models)
try await dataService.batchDelete(models)
```

### Cache Management
```swift
// UserDefaults с кэшированием
private var cache: [String: Any] = [:]
private let cacheQueue = DispatchQueue(label: "cache", attributes: .concurrent)
```

## 🔐 Безопасность

### Error Information
- ✅ Сбор device info для диагностики
- ✅ Фильтрация sensitive данных
- ✅ Secure logging practices

### Recovery Strategies
- ✅ Automatic retry для network errors
- ✅ User-guided recovery для critical errors
- ✅ Safe fallbacks для data corruption

## 🚀 Следующие шаги

### Возможные улучшения:
1. **Network Service** - для API calls
2. **Analytics Service** - для tracking событий
3. **Biometric Service** - для authentication
4. **Export/Import Service** - для backup данных
5. **Widget Service** - для WidgetKit интеграции

### Интеграция с UI:
1. Подключение к ViewModels
2. Error presentation в UI
3. Loading states для async operations
4. Progress indicators для sync

## 📖 Документация по использованию

### Создание нового сервиса:
1. Создать протокол в `ServiceProtocols.swift`
2. Реализовать сервис наследуя `ServiceProtocol`
3. Добавить в `ServiceContainer`
4. Создать mock реализацию
5. Написать unit тесты

### Добавление новой настройки:
1. Добавить ключ в `UserDefaultsKey`
2. Добавить property в `UserDefaultsServiceProtocol`
3. Реализовать в `UserDefaultsService`
4. Обновить mock service
5. Добавить тесты

---

## ✅ Результат Этапа 6

Создана полная сервисная архитектура со всеми необходимыми компонентами:

- 🎯 **4 основных сервиса** с полной функциональностью
- 🏗️ **Dependency Injection** система
- 🧪 **Mock services** для тестирования  
- 📋 **Comprehensive unit tests**
- 📚 **Полная документация**
- 🔧 **SwiftUI интеграция**
- ⚡ **Производительные решения**
- 🛡️ **Error handling** система

Все сервисы готовы к использованию в следующих этапах разработки приложения! 