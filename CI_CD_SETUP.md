# 🚀 CI/CD Setup - Инструкция по использованию

Этот документ описывает настроенную CI/CD систему для Planner App.

## 📋 Что настроено

### ✅ Завершенные компоненты:
- **GitHub Actions** workflow для iOS/macOS
- **SwiftLint** конфигурация для качества кода
- **Fastlane** lanes для автоматизации
- **PR template** для структурированных review
- **Branch protection** rules
- **Issue templates** для bug reports и feature requests
- **CONTRIBUTING.md** с Git workflow

### ❌ Не настроено (требует Apple Developer Program):
- TestFlight автоматический deploy
- App Store Connect API integration
- Fastlane Match для code signing

## 🛠️ Как использовать

### Локальная разработка

```bash
# Установить зависимости
bundle install
brew install swiftlint

# Проверить код
fastlane lint

# Запустить тесты
fastlane test

# Сборка debug версии
fastlane build_debug

# Полная проверка (рекомендуется перед commit)
fastlane check
```

### Git Workflow

```bash
# 1. Создать feature ветку
git checkout -b feature/новая-функция

# 2. Разработка с частыми коммитами
git add .
git commit -m "feat: добавить новую функцию"

# 3. Push в свой форк
git push origin feature/новая-функция

# 4. Создать Pull Request на GitHub
# Заполнить PR template полностью
```

### CI/CD Pipeline

#### При каждом Push/PR:
1. **SwiftLint** - проверка стиля кода
2. **Build iOS** - сборка для iPhone/iPad
3. **Build macOS** - сборка для macOS
4. **Tests** - запуск unit/integration тестов
5. **Code Coverage** - анализ покрытия кода
6. **Security Scan** - проверка безопасности

#### При merge в main:
1. Все проверки выше
2. **Archive iOS** - создание .xcarchive
3. **Archive macOS** - создание .xcarchive
4. Сохранение artifacts на 90 дней

## 📁 Структура файлов

```
.github/
├── workflows/
│   ├── ios.yml                    # Основной CI/CD pipeline
│   └── branch-protection.yml      # Настройка branch protection
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml            # Template для bug reports
│   └── feature_request.yml       # Template для feature requests
└── pull_request_template.md      # Template для PR

fastlane/
├── Fastfile                      # Lanes для автоматизации
└── Appfile                       # Конфигурация приложения

.swiftlint.yml                    # Правила SwiftLint
.gitignore                        # Игнорируемые файлы
.gitattributes                    # Настройки Git для файлов
Gemfile                          # Ruby зависимости
CONTRIBUTING.md                   # Правила разработки
CHANGELOG.md                     # История изменений
```

## ⚙️ Настройка GitHub

### 1. Secrets (при появлении Apple Developer Program)
```
Settings > Secrets and variables > Actions
```

Добавить:
- `FASTLANE_USER` - Apple ID email
- `FASTLANE_PASSWORD` - App-specific password
- `MATCH_PASSWORD` - Password для Fastlane Match
- `APP_STORE_CONNECT_API_KEY` - API ключ

### 2. Branch Protection Rules

Запустить workflow:
```
Actions > Setup Branch Protection > Run workflow
```

Или настроить вручную:
- `main` ветка защищена
- Требуется 1 approve для PR
- Все CI проверки должны пройти

## 🎯 Fastlane Commands

### Основные команды:
```bash
fastlane lint              # SwiftLint проверка
fastlane test              # Запуск тестов
fastlane build_debug       # Debug сборка
fastlane build_release     # Release сборка
fastlane bump_version      # Увеличить версию
fastlane prepare_release   # Подготовка к релизу
fastlane ci_build          # CI сборка
```

### macOS команды:
```bash
fastlane mac build_debug   # macOS debug сборка
fastlane mac build_release # macOS release сборка
fastlane mac test          # macOS тесты
```

## 🔧 Кастомизация

### SwiftLint правила
Редактировать `.swiftlint.yml`:
```yaml
# Добавить новые правила
opt_in_rules:
  - новое_правило

# Изменить настройки
identifier_name:
  min_length: 2
```

### Fastlane lanes
Добавить в `fastlane/Fastfile`:
```ruby
desc "Описание новой lane"
lane :new_lane do
  # Ваши действия
end
```

### GitHub Actions
Изменить `.github/workflows/ios.yml` для:
- Добавления новых проверок
- Изменения версий Xcode
- Настройки destinations

## 📞 Troubleshooting

### Частые проблемы:

**SwiftLint ошибки:**
```bash
# Автоисправление
swiftlint --fix --config .swiftlint.yml
```

**Сборка не проходит:**
```bash
# Очистка проекта
fastlane clean
xcodebuild clean
```

**Тесты падают:**
```bash
# Запуск конкретного теста
xcodebuild test -workspace IWBB.xcworkspace -scheme IWBB -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:IWBBTests/TestName
```

**GitHub Actions не работает:**
- Проверить статус на Actions вкладке
- Убедиться что все secrets настроены
- Проверить branch protection rules

## 🎉 Готово к использованию!

Система CI/CD полностью настроена и готова к разработке. При получении Apple Developer Program достаточно будет:

1. Добавить secrets в GitHub
2. Раскомментировать строки в `fastlane/Appfile`
3. Настроить Fastlane Match
4. Добавить TestFlight lanes

---

**Важно:** Система оптимизирована для работы без Apple Developer Program. При его появлении можно легко добавить недостающую функциональность. 