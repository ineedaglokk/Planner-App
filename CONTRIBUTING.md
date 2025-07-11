# Руководство по вкладу в проект

Добро пожаловать в проект **Planner App**! Мы рады, что вы хотите внести свой вклад. 

## 📋 Содержание

- [Кодекс поведения](#кодекс-поведения)
- [Как начать](#как-начать)
- [Git Workflow](#git-workflow)
- [Стандарты кода](#стандарты-кода)
- [Тестирование](#тестирование)
- [Pull Request процесс](#pull-request-процесс)
- [Issue Guidelines](#issue-guidelines)
- [Настройка окружения](#настройка-окружения)

## 🤝 Кодекс поведения

Участвуя в этом проекте, вы соглашаетесь соблюдать наш кодекс поведения. Будьте уважительны, конструктивны и профессиональны.

## 🚀 Как начать

### Форк и клонирование
```bash
# 1. Сделайте форк репозитория на GitHub
# 2. Клонируйте ваш форк
git clone https://github.com/YOUR_USERNAME/Planner-App.git
cd Planner-App

# 3. Добавьте оригинальный репозиторий как upstream
git remote add upstream https://github.com/ineedaglokk/Planner-App.git

# 4. Убедитесь, что у вас настроен upstream
git remote -v
```

### Настройка проекта
```bash
# Установите зависимости
bundle install # Fastlane
brew install swiftlint

# Откройте проект
open IWBB.xcworkspace
```

## 🔄 Git Workflow

Мы используем **GitHub Flow** - простой и эффективный workflow для совместной разработки.

### Ветки

- **`main`** - основная ветка, всегда готова к продакшену
- **`develop`** - ветка разработки для интеграции фич
- **`feature/название-фичи`** - ветки для новых функций
- **`bugfix/описание-бага`** - ветки для исправления ошибок  
- **`hotfix/критический-баг`** - ветки для критических исправлений

### Workflow

#### 1. Создание новой ветки
```bash
# Всегда начинайте с актуальной main ветки
git checkout main
git pull upstream main

# Создайте новую ветку
git checkout -b feature/добавить-новую-привычку
# или
git checkout -b bugfix/исправить-краш-при-сохранении
```

#### 2. Работа с изменениями
```bash
# Делайте частые коммиты с осмысленными сообщениями
git add .
git commit -m "feat: добавить экран создания привычки"

# Пушите изменения в свой форк
git push origin feature/добавить-новую-привычку
```

#### 3. Синхронизация с upstream
```bash
# Регулярно синхронизируйте с основным репозиторием
git fetch upstream
git rebase upstream/main

# Если есть конфликты - разрешите их и продолжите
git rebase --continue
```

#### 4. Создание Pull Request
1. Перейдите на GitHub
2. Создайте Pull Request из вашей ветки в `main`
3. Заполните PR template полностью
4. Дождитесь ревью и исправьте замечания

### Commit Message Guidelines

Используем [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Типы коммитов:
- `feat:` новая функциональность
- `fix:` исправление ошибки
- `docs:` изменения в документации
- `style:` форматирование, отсутствуют изменения кода
- `refactor:` рефакторинг кода
- `test:` добавление тестов
- `chore:` обновление сборки или вспомогательных инструментов

#### Примеры:
```bash
feat(habits): добавить создание привычки с повторениями
fix(core): исправить краш при сохранении SwiftData
docs(readme): обновить инструкции по установке
refactor(ui): упростить логику HabitCardView
test(habits): добавить тесты для HabitRepository
chore(deps): обновить зависимости SwiftLint
```

## 💻 Стандарты кода

### Swift Style Guide

Мы следуем [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) и используем SwiftLint для проверки стиля.

#### Основные принципы:
1. **Читаемость** - код должен быть понятен без комментариев
2. **Consistency** - следуйте установленным паттернам
3. **Simplicity** - предпочитайте простые решения сложным

#### Примеры кода:

```swift
// ✅ Правильно
struct HabitCardView: View {
    let habit: Habit
    let onToggle: (Habit) -> Void
    
    var body: some View {
        Card {
            VStack(alignment: .leading) {
                Text(habit.name)
                    .font(.headline)
                ProgressView(value: habit.completionRate)
            }
        }
        .onTapGesture { onToggle(habit) }
    }
}

// ❌ Неправильно
struct habitCardView: View {
    var h: Habit
    var action: (Habit)->Void
    var body: some View {
        // Плохая структура...
    }
}
```

### Архитектурные требования

1. **MVVM Pattern** - используйте для всех Views
2. **Repository Pattern** - для доступа к данным
3. **Dependency Injection** - через Environment
4. **SwiftData Models** - с CloudKit sync
5. **Protocols** - для абстракций

## 🧪 Тестирование

### Перед коммитом
```bash
# Запустите линтер
swiftlint

# Запустите тесты
fastlane test

# Или через Xcode
⌘ + U
```

### Требования к тестам
- **Unit Tests** - для бизнес-логики (ViewModels, Services)
- **Integration Tests** - для Repository слоя
- **UI Tests** - для критических пользовательских сценариев
- **Code Coverage** - минимум 80% для новых функций

### Примеры тестов:

```swift
// Unit Test
final class HabitViewModelTests: XCTestCase {
    func testCreateHabit_ShouldAddToRepository() async {
        // Given
        let mockRepository = MockHabitRepository()
        let viewModel = HabitViewModel(repository: mockRepository)
        
        // When
        await viewModel.createHabit(name: "Test Habit")
        
        // Then
        XCTAssertEqual(mockRepository.savedHabits.count, 1)
    }
}
```

## 🔍 Pull Request процесс

### Checklist перед созданием PR:
- [ ] Код соответствует стандартам проекта
- [ ] SwiftLint проходит без ошибок
- [ ] Все тесты проходят
- [ ] Добавлены новые тесты (если необходимо)
- [ ] Документация обновлена
- [ ] PR template заполнен полностью

### Процесс ревью:
1. **Автоматические проверки** - CI должен пройти зеленым
2. **Code Review** - минимум 1 approve от maintainer
3. **Testing** - ручное тестирование (если необходимо)
4. **Merge** - squash merge в main

### После approve:
```bash
# Обновите main ветку
git checkout main
git pull upstream main

# Удалите feature ветку
git branch -d feature/ваша-ветка
git push origin --delete feature/ваша-ветка
```

## 🐛 Issue Guidelines

### Создание Issue

#### Bug Report
```markdown
**Описание:**
Краткое описание бага

**Шаги для воспроизведения:**
1. Перейти в...
2. Нажать на...
3. Увидеть ошибку

**Ожидаемое поведение:**
Что должно происходить

**Актуальное поведение:**
Что происходит на самом деле

**Окружение:**
- iOS версия:
- Устройство:
- Версия приложения:
```

#### Feature Request
```markdown
**Проблема:**
Какую проблему решает новая функция?

**Решение:**
Описание предлагаемого решения

**Альтернативы:**
Другие варианты решения

**Дополнительно:**
Скриншоты, макеты, примеры
```

## ⚙️ Настройка окружения

### Требования
- **Xcode 15.2+**
- **iOS 17.0+ SDK**
- **macOS 14.0+ SDK**
- **Swift 5.9+**

### Инструменты разработки
```bash
# Fastlane для автоматизации
gem install fastlane

# SwiftLint для code style
brew install swiftlint

# SwiftFormat (опционально)
brew install swiftformat
```

### Настройки Xcode
1. **Editor > Default Line Endings** → LF
2. **Editor > Tab Width** → 2 spaces
3. **Editor > Indent Width** → 2 spaces
4. **Text Editing > Show line numbers** ✅

### Полезные команды

```bash
# Проверка качества кода
fastlane lint

# Запуск тестов
fastlane test

# Сборка проекта
fastlane build_debug

# Очистка проекта
fastlane clean

# Полная проверка (lint + test)
fastlane check
```

## 📞 Вопросы?

- Создайте **Issue** с меткой `question`
- Напишите в **Discussions** для общих вопросов
- Проверьте **Wiki** для дополнительной документации

## 🎉 Благодарности

Спасибо всем участникам, которые делают этот проект лучше! Ваш вклад ценится.

---

**Помните:** качество важнее скорости. Лучше потратить больше времени на правильное решение, чем быстро создать плохой код. 