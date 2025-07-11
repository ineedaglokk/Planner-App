# 🎮 Система геймификации - Документация

## Обзор

Система геймификации предназначена для повышения мотивации и вовлеченности пользователей в процесс формирования привычек и достижения целей. Система построена на принципах психологии мотивации и использует современные игровые механики.

## 🏗️ Архитектура

### Структура компонентов

```
📁 Gamification System/
├── 📁 Models/                      # Модели данных
│   ├── Achievement.swift           # Достижения и значки
│   ├── Challenge.swift            # Вызовы и соревнования
│   └── Badge.swift               # Система значков и наград
├── 📁 Services/                   # Бизнес-логика
│   ├── PointsCalculationService.swift
│   ├── AchievementService.swift
│   ├── ChallengeService.swift
│   ├── LevelProgressionService.swift
│   ├── MotivationService.swift
│   └── GameService.swift         # Главный координатор
├── 📁 ViewModels/                # MVVM слой (планируется)
└── 📁 Views/                     # UI компоненты (планируется)
```

## 📊 Модели данных

### 1. Achievement (Достижения)
```swift
@Model
final class Achievement: CloudKitSyncable, Timestampable {
    var name: String
    var description: String
    var iconName: String
    var category: AchievementCategory
    var rarity: AchievementRarity
    var points: Int
    var requirements: AchievementRequirements
    var isSecret: Bool
    var isUnlocked: Bool
    var progress: Double // 0.0 - 1.0
}
```

**Категории достижений:**
- `habits` - Привычки
- `tasks` - Задачи
- `finance` - Финансы
- `health` - Здоровье
- `social` - Социальные
- `milestones` - Этапы
- `special` - Особые
- `seasonal` - Сезонные

**Уровни редкости:**
- `common` - Обычное (серый)
- `uncommon` - Необычное (зеленый)
- `rare` - Редкое (синий)
- `epic` - Эпическое (фиолетовый)
- `legendary` - Легендарное (оранжевый)
- `mythical` - Мифическое (красный)

### 2. Challenge (Вызовы)
```swift
@Model
final class Challenge: CloudKitSyncable, Timestampable {
    var name: String
    var description: String
    var category: ChallengeCategory
    var difficulty: ChallengeDifficulty
    var type: ChallengeType
    var duration: ChallengeDuration
    var requirements: ChallengeRequirements
    var rewards: ChallengeRewards
    var startDate: Date
    var endDate: Date
    var isGlobal: Bool
}
```

**Типы вызовов:**
- `personal` - Личный
- `community` - Сообщество
- `competitive` - Соревновательный
- `collaborative` - Совместный
- `timed` - На время
- `milestone` - Достижение
- `streak` - Серия
- `exploration` - Исследование

### 3. UserLevel (Уровни пользователя)
```swift
@Model
final class UserLevel: CloudKitSyncable, Timestampable {
    var currentLevel: Int
    var currentXP: Int
    var totalXP: Int
    var prestigeLevel: Int
    var title: String?
    var perks: [String]
}
```

### 4. PointsHistory (История очков)
```swift
@Model
final class PointsHistory: CloudKitSyncable, Timestampable {
    var points: Int
    var xp: Int
    var source: PointsSource
    var multiplier: Double
    var bonus: Int
    var description: String
}
```

## 🔧 Сервисы

### 1. PointsCalculationService
**Назначение:** Расчет очков и XP за действия пользователя

**Основные методы:**
```swift
func calculatePoints(for action: GameAction, context: ActionContext) async -> PointsResult
func calculateMultiplier(for user: User, action: GameAction) async -> Double
func awardPoints(_ result: PointsResult, to user: User) async throws
```

**Факторы расчета:**
- **Базовые очки** - зависят от типа действия
- **Мультипликатор уровня** - от 1.0 до 1.7
- **Мультипликатор серии** - от 1.0 до 2.0
- **Временной мультипликатор** - за выполнение в срок
- **Бонусы за постоянство** - от 1.0 до 1.25

### 2. AchievementService
**Назначение:** Управление достижениями и их разблокировка

**Основные методы:**
```swift
func checkAchievements(for user: User) async throws
func unlockAchievement(_ achievement: Achievement, for user: User) async throws
func getUnlockedAchievements(for user: User) async throws -> [Achievement]
func createDefaultAchievements() async throws
```

**Типы достижений:**
- **Серии** - за поддержание привычек (7, 30, 365 дней)
- **Объем** - за количество выполнений
- **Время** - за выполнение в определенное время
- **Категории** - за мастерство в категориях
- **Особые** - за уникальные достижения

### 3. ChallengeService
**Назначение:** Управление вызовами и соревнованиями

**Основные методы:**
```swift
func getActiveChallenge(for user: User) async throws -> [Challenge]
func joinChallenge(_ challenge: Challenge, user: User) async throws
func updateChallengeProgress(_ challenge: Challenge, user: User, value: Double) async throws
func createDailyChallenge() async throws -> Challenge
```

**Предустановленные вызовы:**
- **Ежедневные** - простые задачи на день
- **Еженедельные** - цели на неделю
- **Месячные** - долгосрочные цели
- **Сезонные** - тематические вызовы

### 4. LevelProgressionService
**Назначение:** Управление уровнями и прогрессом пользователя

**Система уровней:**
```swift
// Формула XP: 100 * (level^1.5)
Level 1:    100 XP
Level 5:    559 XP
Level 10:  1,581 XP
Level 25:  6,251 XP
Level 50: 17,677 XP
```

**Система престижа:**
- Доступна с 50 уровня
- Сброс уровня с сохранением общего XP
- Престижные мультипликаторы и привилегии
- Особые титулы и значки

### 5. MotivationService
**Назначение:** Персонализированная мотивация пользователей

**Типы мотивации:**
- `encouragement` - Поддержка в трудные моменты
- `celebration` - Празднование успехов
- `challenge` - Предложение новых вызовов
- `support` - Помощь при неудачах
- `inspiration` - Вдохновляющие сообщения

**Персонализированные советы:**
- Анализ слабых мест пользователя
- Рекомендации по улучшению
- Пошаговые инструкции
- Адаптивные напоминания

### 6. GameService (Главный координатор)
**Назначение:** Координация всей системы геймификации

**Основные функции:**
```swift
func processUserAction(_ action: UserAction, for user: User) async throws
func getDashboardData(for user: User) async throws -> GamificationDashboard
func initializeGamificationForUser(_ user: User) async throws
func dailyUpdate(for user: User) async throws
```

## 🎯 Игровые механики

### 1. Очки и опыт
- **Очки (Points)** - за конкретные действия
- **Опыт (XP)** - для повышения уровня
- **Мультипликаторы** - увеличивают награды
- **Бонусы** - за особые условия

### 2. Уровни и титулы
```swift
1-5:    "Новичок"
6-10:   "Ученик"
11-20:  "Мастер"
21-35:  "Эксперт"
36-50:  "Профессионал"
51-75:  "Виртуоз"
76-100: "Гроссмейстер"
100+:   "Легенда"
```

### 3. Достижения и значки
- **Прогрессивные** - увеличивающиеся цели
- **Скрытые** - секретные достижения
- **Сезонные** - ограниченные по времени
- **Социальные** - для взаимодействия

### 4. Вызовы и соревнования
- **Личные вызовы** - индивидуальные цели
- **Глобальные** - для всех пользователей
- **Командные** - совместные цели
- **Рейтинговые** - с таблицей лидеров

## 🔄 Интеграция с основным приложением

### События системы
```swift
enum UserAction {
    case habitCompleted(Habit)
    case taskCompleted(Task)
    case goalAchieved(Goal)
    case challengeJoined(Challenge)
    case dailyLogin
    case perfectDay
    case comeback
}
```

### Автоматические триггеры
- **При выполнении привычки** - начисление очков, проверка достижений
- **При завершении задачи** - обновление прогресса вызовов
- **При входе в приложение** - ежедневные бонусы
- **При идеальном дне** - специальные награды
- **При возвращении** - мотивационные сообщения

### Уведомления
- **Разблокировка достижений** - с анимацией
- **Повышение уровня** - с эффектами
- **Завершение вызовов** - с наградами
- **Мотивационные сообщения** - персонализированные
- **Напоминания** - адаптивные

## 📱 Пользовательский интерфейс (планируется)

### GamificationDashboardView
- Текущий уровень и прогресс
- Недавние достижения
- Активные вызовы
- Мотивационное сообщение дня

### UserProfileView
- Детальная информация об уровне
- Коллекция значков
- История достижений
- Статистика прогресса

### AchievementsGalleryView
- Сетка всех достижений
- Фильтрация по категориям
- Прогресс незавершенных
- Детальная информация

### ChallengesListView
- Доступные вызовы
- Активные участия
- Завершенные вызовы
- Таблица лидеров

## 🧪 Тестирование

### Unit Tests
- Расчет очков и мультипликаторов
- Логика разблокировки достижений
- Прогресс вызовов
- Повышение уровней

### Integration Tests
- Взаимодействие сервисов
- Обработка событий
- Синхронизация данных
- Уведомления

### A/B Tests (планируется)
- Эффективность мотивационных сообщений
- Оптимальная частота наград
- Влияние на удержание пользователей
- Баланс сложности вызовов

## 🔐 Конфиденциальность и безопасность

### Защита данных
- Все игровые данные синхронизируются через CloudKit
- Шифрование чувствительной информации
- Локальное хранение для offline-режима
- Соблюдение GDPR и других требований

### Анонимизация
- Опциональная социальная функциональность
- Псевдонимы для таблиц лидеров
- Контроль видимости достижений
- Настройки приватности

## 📈 Аналитика и метрики

### Ключевые показатели
- **Retention Rate** - удержание пользователей
- **Engagement** - вовлеченность в игровые элементы
- **Progression Rate** - скорость прогресса
- **Feature Usage** - использование функций геймификации

### Отслеживаемые события
- Разблокировка достижений
- Участие в вызовах
- Повышение уровней
- Взаимодействие с мотивационными сообщениями

## 🚀 Планы развития

### Фаза 1 (MVP) ✅
- [x] Базовая система очков и уровней
- [x] Простые достижения
- [x] Основные вызовы
- [x] Мотивационные сообщения

### Фаза 2 (Enhanced)
- [ ] Социальные функции
- [ ] Персонализированные вызовы
- [ ] Продвинутая аналитика
- [ ] A/B тестирование

### Фаза 3 (Advanced)
- [ ] Машинное обучение для персонализации
- [ ] Интеграция с внешними сервисами
- [ ] Расширенные социальные функции
- [ ] Пользовательский контент

## 💡 Лучшие практики использования

### Для разработчиков
1. **Всегда используйте GameService** как точку входа
2. **Обрабатывайте ошибки** gracefully
3. **Тестируйте игровую логику** тщательно
4. **Используйте ServiceContainer** для DI
5. **Следуйте принципам MVVM**

### Для дизайнеров
1. **Визуальная обратная связь** критически важна
2. **Анимации** должны быть деликатными
3. **Прогресс** должен быть понятным
4. **Награды** должны ощущаться ценными
5. **Уведомления** не должны раздражать

### Для продукт-менеджеров
1. **Мониторьте метрики** постоянно
2. **Балансируйте сложность** регулярно
3. **Собирайте обратную связь** от пользователей
4. **Тестируйте новые механики** осторожно
5. **Адаптируйтесь** к поведению пользователей

---

*Эта документация будет обновляться по мере развития системы геймификации.* 