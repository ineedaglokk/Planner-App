# 📚 Документация проекта IWBB

Добро пожаловать в центр документации проекта **IWBB - Intelligent Work-Life Balance Planner**!

## 📋 Оглавление

### 🏗️ Архитектура
- **[📖 Полная техническая архитектура](Architecture/Complete_Architecture.md)** - Детальное описание архитектуры (1,416 строк)
  - SwiftData модели с готовым кодом
  - MVVM + Repository pattern
  - Модульная структура пакетов
  - Интеграции с Apple ecosystem

- **[⚡ Быстрый справочник](Architecture/Quick_Reference.md)** - Краткий обзор архитектурных решений
  - Основные принципы
  - Структура модулей  
  - Ключевые паттерны

### 🎨 Дизайн-система
- **[🎨 Документация дизайн-системы](DesignSystem/README.md)** - Полное руководство по UI/UX (643 строки)
  - Цветовая палитра и темы
  - Типографика и spacing
  - Компоненты и навигация
  - Accessibility и Dark Mode

### 📋 Планирование проекта
- **[🚀 План разработки](ProjectPlanning/Development_Plan.md)** - Полный план проекта (1,553 строки)
  - 18 этапов разработки
  - Технологический стек
  - Временные рамки
  - Приоритизация фичей

### 📘 Руководства разработчика
- **[🛠️ Настройка Workspace](Guides/Workspace_Setup.md)** - Настройка Xcode workspace и интеграция документации
- **[🧪 Руководство по тестированию](Guides/Testing_Guide.md)** - Best practices тестирования *(готовится)*
- **[🚀 Руководство по деплою](Guides/Deployment_Guide.md)** - CI/CD и App Store *(готовится)*
- **[🎯 API Documentation](Guides/API_Reference.md)** - Документация модулей *(готовится)*

## 🎯 Быстрая навигация

### Для новых разработчиков:
1. **Начните с** → [Быстрый справочник архитектуры](Architecture/Quick_Reference.md)
2. **Изучите** → [Дизайн-систему](DesignSystem/README.md)  
3. **Ознакомьтесь** → [План разработки](ProjectPlanning/Development_Plan.md)

### Для архитекторов:
1. **Полная архитектура** → [Complete_Architecture.md](Architecture/Complete_Architecture.md)
2. **Модульная структура** → Раздел "Архитектурные принципы"
3. **Интеграции** → Разделы WidgetKit, CloudKit, HealthKit

### Для дизайнеров:
1. **UI Kit** → [Дизайн-система](DesignSystem/README.md)
2. **Компоненты** → Раздел "Shared Components"
3. **Темы** → Разделы Colors, Typography, Spacing

## 📊 Статистика документации

| Документ | Строки | Статус | Обновлено |
|----------|--------|--------|-----------|
| Complete_Architecture.md | 1,416 | ✅ Готов | Сегодня |
| Quick_Reference.md | 161 | ✅ Готов | Сегодня |
| DesignSystem/README.md | 643 | ✅ Готов | Сегодня |
| Development_Plan.md | 1,553 | ✅ Готов | Сегодня |
| Workspace_Setup.md | 185 | ✅ Готов | Сегодня |
| Testing_Guide.md | - | 🚧 В разработке | - |
| Deployment_Guide.md | - | 🚧 В разработке | - |
| API_Reference.md | - | 🚧 В разработке | - |

**Общий объем готовой документации: 3,958+ строк**

## 🔍 Поиск по документации

### По темам:
- **SwiftUI** → Architecture/Complete_Architecture.md, DesignSystem/README.md
- **SwiftData** → Architecture/Complete_Architecture.md (модели данных)
- **CloudKit** → Architecture/Complete_Architecture.md (синхронизация)  
- **MVVM** → Architecture/Complete_Architecture.md (паттерны)
- **Тестирование** → Architecture/Complete_Architecture.md, Development_Plan.md
- **Дизайн** → DesignSystem/README.md (полное руководство)

### По технологиям:
- **WidgetKit** → Architecture/Complete_Architecture.md
- **App Intents** → Architecture/Complete_Architecture.md  
- **HealthKit** → Architecture/Complete_Architecture.md
- **Swift Charts** → DesignSystem/README.md
- **NavigationStack** → Architecture/Complete_Architecture.md

## 📝 Как обновлять документацию

### Правила:
1. **Всегда обновляйте** этот индексный файл при добавлении нового документа
2. **Используйте** согласованное форматирование Markdown
3. **Добавляйте** дату обновления в таблицу статистики  
4. **Проверяйте** ссылки на актуальность

### Структура новых документов:
```markdown
# Заголовок документа

## Краткое описание
Что содержит этот документ...

## Оглавление
- Раздел 1
- Раздел 2

## Содержание
...

---
*Обновлено: [дата]*
*Автор: [имя]*
```

## 🤝 Вклад в документацию

Если вы нашли ошибку или хотите улучшить документацию:

1. **Создайте** issue с описанием проблемы
2. **Предложите** изменения через Pull Request
3. **Следуйте** стилю существующей документации
4. **Обновите** индексный файл при необходимости

## 📞 Поддержка

**Вопросы по документации:**
- 📧 docs@iwbb.app
- 💬 #documentation в Discord
- 📝 GitHub Issues с тегом `documentation`

---

**📚 Создано командой IWBB для эффективной разработки и поддержки проекта**

*Обновлено: $(date)* 