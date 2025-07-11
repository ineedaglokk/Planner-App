# IWBB - Intelligent Work-Life Balance Planner

![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-green.svg)
![SwiftData](https://img.shields.io/badge/SwiftData-Latest-purple.svg)

Современное многофункциональное планнер приложение для iOS и macOS, разработанное с использованием новейших технологий Apple ecosystem.

## 🎯 Основные функции

### 📋 Управление задачами
- **Smart Scheduling** - умное планирование с учетом приоритетов
- **GTD методология** - полная поддержка Getting Things Done
- **Временные блоки** - time blocking для продуктивности
- **Подзадачи и зависимости** - сложная иерархия задач

### 🔄 Трекер привычек
- **Streak tracking** - отслеживание серий выполнения
- **Визуальная статистика** - красивые графики прогресса
- **Гибкая настройка** - ежедневные, еженедельные, кастомные привычки
- **Напоминания** - умные уведомления

### 💰 Финансовый планнер
- **Бюджетирование** - создание и контроль бюджетов
- **Трекинг расходов** - категоризация трат
- **Финансовые цели** - планирование крупных покупок
- **Аналитика** - детальные отчеты и прогнозы

### 🎮 Геймификация
- **Система достижений** - unlock новых возможностей
- **Прогресс-бары** - визуальная мотивация
- **Рейтинги** - соревновательный элемент
- **Награды** - виртуальные призы за выполнение целей

## 🏗️ Архитектура

### Технологический стек
- **🍎 SwiftUI 5.0** - современный декларативный UI
- **📊 SwiftData** - Core Data нового поколения
- **☁️ CloudKit** - синхронизация между устройствами
- **🔄 Swift Concurrency** - async/await для производительности
- **📱 WidgetKit** - интерактивные виджеты
- **🗣️ App Intents** - интеграция с Siri Shortcuts
- **📈 Swift Charts** - нативная визуализация данных
- **💚 HealthKit** - интеграция с данными здоровья

### Архитектурные принципы
```
📦 Modular Package Architecture
├── 🎯 IWBBCore - Основная бизнес-логика
├── 🎨 DesignSystem - UI компоненты и темы
├── 💾 DataLayer - SwiftData модели и репозитории
├── 🌐 NetworkLayer - CloudKit и API интеграции
├── 📋 TasksFeature - Модуль задач
├── 🔄 HabitsFeature - Модуль привычек
├── 💰 FinanceFeature - Финансовый модуль
├── 📊 DashboardFeature - Главный экран
└── ⚙️ SettingsFeature - Настройки приложения
```

### MVVM + Repository Pattern
- **ViewModels** - бизнес-логика и состояние UI
- **Repositories** - абстракция доступа к данным
- **Services** - внешние интеграции и утилиты
- **Dependency Injection** - ServiceContainer для модульности

## 📚 Документация

Проект имеет обширную документацию, организованную в **[Центре документации](Documentation/README.md)**:

- **🏗️ [Архитектура](Documentation/Architecture/)** - Техническая архитектура и паттерны
- **🎨 [Дизайн-система](Documentation/DesignSystem/)** - UI/UX компоненты и руководства  
- **📋 [Планирование](Documentation/ProjectPlanning/)** - План разработки и roadmap
- **📘 [Руководства](Documentation/Guides/)** - Guides для разработчиков

## 🚀 Начало работы

### Требования
- **Xcode 15.0+**
- **iOS 17.0+ / macOS 14.0+**
- **Swift 5.9+**
- **SwiftLint** (рекомендуется)

### Установка
```bash
# Клонирование репозитория
git clone https://github.com/your-username/IWBB.git
cd IWBB

# Установка зависимостей
swift package resolve

# Открытие в Xcode
open IWBB.xcworkspace
```

### Первый запуск
1. Откройте `IWBB.xcworkspace` в Xcode
2. Выберите симулятор или устройство
3. Нажмите `⌘+R` для запуска
4. Пройдите onboarding и настройте профиль

## 🧪 Тестирование

### Запуск тестов
```bash
# Все тесты
swift test

# Конкретный модуль
swift test --filter IWBBCoreTests

# UI тесты
xcodebuild test -workspace IWBB.xcworkspace -scheme IWBB -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Test Coverage
Проект настроен на сбор code coverage метрик:
- **Unit Tests** - для бизнес-логики
- **Integration Tests** - для взаимодействия модулей
- **UI Tests** - для пользовательских сценариев
- **Performance Tests** - для оптимизации

## 📁 Структура проекта

```
IWBB/
├── 📱 IWBB/                    # Основное приложение
│   ├── IWBBApp.swift          # Точка входа
│   ├── ContentView.swift      # Главный экран
│   ├── Info.plist             # Настройки приложения
│   └── IWBB.entitlements      # Права доступа
├── 🏗️ Sources/                # Модули приложения
│   ├── IWBBCore/              # Основная логика
│   ├── DesignSystem/          # UI система
│   ├── DataLayer/             # Модели данных
│   ├── Features/              # Функциональные модули
│   └── Utilities/             # Вспомогательные утилиты
├── 🧪 Tests/                  # Тесты
│   ├── Unit/                  # Юнит тесты
│   ├── Integration/           # Интеграционные тесты
│   └── UI/                    # UI тесты
├── ⚙️ Configurations/         # Build конфигурации
│   ├── Debug.xcconfig         # Debug настройки
│   └── Release.xcconfig       # Release настройки
├── 📚 Documentation/          # Полная документация проекта
│   ├── README.md              # Индекс документации (этот файл)
│   ├── Architecture/          # Архитектурная документация
│   │   ├── Complete_Architecture.md  # Полная техническая архитектура
│   │   └── Quick_Reference.md        # Быстрый справочник
│   ├── DesignSystem/          # Документация дизайн-системы
│   │   └── README.md          # UI/UX руководство
│   ├── ProjectPlanning/       # Планирование и roadmap
│   │   └── Development_Plan.md # План разработки проекта
│   └── Guides/                # Руководства разработчика
│       ├── Setup_Guide.md     # Настройка среды (готовится)
│       ├── Testing_Guide.md   # Руководство по тестированию
│       └── API_Reference.md   # API документация
└── 🔧 Инструменты разработки
    ├── .swiftlint.yml         # SwiftLint конфигурация
    ├── Package.swift          # SPM конфигурация
    ├── IWBB.xcworkspace/      # Xcode workspace
    └── IWBB.xctestplan        # План тестирования
```

## 🎨 Design System

### Цветовая палитра
- **Primary** - Основной цвет приложения
- **Secondary** - Вторичные элементы
- **Semantic** - Функциональные цвета (success, warning, error)
- **Habits** - Специальные цвета для привычек
- **Finance** - Финансовые индикаторы

### Компоненты
- **Buttons** - 7+ типов кнопок
- **Cards** - Информационные карточки
- **Navigation** - Навигационная система
- **Forms** - Элементы ввода
- **Charts** - Графики и диаграммы

### Типографика
- **SF Pro** - системный шрифт Apple
- **Семантические стили** - заголовки, подзаголовки, body текст
- **Accessibility** - поддержка Dynamic Type

## 🔄 CI/CD

### GitHub Actions
```yaml
# Пример workflow
- Build and Test
- SwiftLint Check
- Test Coverage Report
- Archive and Export
- TestFlight Upload
```

### Quality Gates
- **Code Coverage** - минимум 80%
- **SwiftLint** - zero warnings policy
- **Performance Tests** - регрессионное тестирование
- **Security Scan** - проверка уязвимостей

## 📊 Мониторинг

### Analytics
- **App Performance** - время запуска, memory usage
- **User Engagement** - активность пользователей
- **Feature Usage** - популярность функций
- **Crash Reporting** - отслеживание ошибок

### Metrics Dashboard
- **Daily Active Users**
- **Retention Rates**
- **Feature Adoption**
- **Performance KPIs**

## 🤝 Вклад в проект

### Workflow разработки
1. **Fork** репозитория
2. Создайте **feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit** изменения (`git commit -m 'Add amazing feature'`)
4. **Push** в branch (`git push origin feature/amazing-feature`)
5. Откройте **Pull Request**

### Code Style
- Следуйте **SwiftLint** правилам
- Используйте **SwiftUI** best practices
- Покрывайте код **тестами**
- Документируйте **public API**

### Code Review Process
- **2 approvals** required
- **CI checks** must pass
- **Test coverage** maintained
- **Documentation** updated

## 📄 Лицензия

Этот проект лицензирован под MIT License - детали в файле [LICENSE](LICENSE).

## 👥 Команда

- **Product Owner** - Стратегия продукта
- **iOS Developers** - Разработка приложения
- **UI/UX Designer** - Дизайн интерфейса
- **QA Engineers** - Тестирование качества
- **DevOps** - CI/CD и инфраструктура

## 📞 Поддержка

### Документация
- 📚 **[Центр документации](Documentation/README.md)** - Полный индекс всей документации
- 📖 [Wiki](https://github.com/your-username/IWBB/wiki)
- 🎥 [Video Tutorials](https://youtube.com/iwbb-tutorials)
- 💬 [Discord Community](https://discord.gg/iwbb)

### Контакты
- 📧 **Email**: support@iwbb.app
- 🐦 **Twitter**: [@IWBB_App](https://twitter.com/iwbb_app)
- 🌐 **Website**: [iwbb.app](https://iwbb.app)

---

**Создано с ❤️ командой IWBB для повышения продуктивности и качества жизни** 