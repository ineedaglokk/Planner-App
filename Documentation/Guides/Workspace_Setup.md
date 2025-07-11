# 🛠️ Настройка Workspace и интеграция документации

Руководство по правильной настройке Xcode workspace и интеграции документации в среду разработки.

## 📁 Структура Workspace

Проект IWBB использует `.xcworkspace` для объединения многомодульного SPM проекта:

```
IWBB.xcworkspace/
├── contents.xcworkspacedata     # Основная конфигурация
└── xcshareddata/
    └── xcschemes/
        └── IWBB.xcscheme        # Схема сборки
```

## 🔧 Компоненты Workspace

### Основные группы
- **Package.swift** - SPM манифест с модулями
- **IWBB** - Основное iOS/macOS приложение  
- **Sources** - Модульные пакеты (IWBBCore, DesignSystem, etc.)
- **Tests** - Тесты всех модулей
- **Documentation** - Полная документация проекта

### Конфигурация
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
   <FileRef location = "group:Package.swift">
   </FileRef>
   <FileRef location = "group:IWBB">
   </FileRef>
   <FileRef location = "group:Sources">
   </FileRef>
   <FileRef location = "group:Tests">
   </FileRef>
   <FileRef location = "group:Documentation">
   </FileRef>
</Workspace>
```

## 📚 Интеграция документации в Xcode

### Преимущества
- **Быстрый доступ** к документации прямо в Xcode
- **Автодополнение** путей к файлам документации
- **Версионирование** документации вместе с кодом
- **Поиск** по документации через Xcode navigator

### Настройка
1. Документация уже добавлена в workspace как `group:Documentation`
2. Все `.md` файлы автоматически отображаются в Xcode
3. Используйте **Navigator → Project** для просмотра документации

### Открытие документации
- **В Xcode**: Project Navigator → Documentation → выберите файл
- **В Markdown редакторе**: Двойной клик на `.md` файле
- **В браузере**: Через GitHub/GitLab интерфейс

## 🚀 Открытие проекта

### Способ 1: Командная строка
```bash
cd "/path/to/IWBB"
open IWBB.xcworkspace
```

### Способ 2: Xcode
1. Запустите Xcode
2. File → Open Workspace
3. Выберите `IWBB.xcworkspace`

### Способ 3: Finder
Двойной клик на `IWBB.xcworkspace`

## 📋 Работа с схемами

### Текущие схемы
- **IWBB** - Основная схема приложения
  - Build: Debug/Release конфигурации
  - Test: Все модульные тесты
  - Run: iOS симулятор/устройство, macOS
  - Archive: App Store сборка

### Добавление новых схем
1. Product → Scheme → Manage Schemes
2. Нажмите "+" для добавления
3. Выберите target и настройте конфигурации
4. Сохраните в `xcshareddata` для команды

## 🔍 Навигация по проекту

### Project Navigator
```
IWBB
├── 📦 Package.swift
├── 📱 IWBB
│   ├── IWBBApp.swift
│   ├── ContentView.swift
│   ├── Info.plist
│   └── IWBB.entitlements
├── 🏗️ Sources
│   ├── IWBBCore
│   ├── DesignSystem
│   ├── DataLayer
│   └── [Other modules]
├── 🧪 Tests
└── 📚 Documentation
    ├── Architecture/
    ├── DesignSystem/
    ├── ProjectPlanning/
    └── Guides/
```

### Полезные горячие клавиши
- `⌘+1` - Project Navigator
- `⌘+2` - Source Control Navigator  
- `⌘+3` - Symbol Navigator
- `⌘+Shift+O` - Quick Open
- `⌘+Shift+F` - Find in Project

## 🛠️ Решение проблем

### Workspace не открывается
```bash
# Проверьте валидность XML
xmllint --noout IWBB.xcworkspace/contents.xcworkspacedata

# Пересоздайте workspace если нужно
rm -rf IWBB.xcworkspace
# Затем пересоздайте через создание нового workspace в Xcode
```

### Модули не отображаются
1. File → Workspace Settings
2. Build System → New Build System (по умолчанию)
3. Derived Data → Default/Custom location
4. Product → Clean Build Folder (`⌘+Shift+K`)

### SPM зависимости не разрешаются
```bash
# Очистите SPM кэш
rm -rf .build
swift package clean
swift package resolve
```

### Документация не отображается
1. Проверьте workspace configuration
2. Убедитесь что `Documentation` folder добавлена
3. File → Add Files to Workspace → выберите Documentation/

## 📝 Best Practices

### Организация workspace
1. **Всегда используйте workspace** для многомодульных проектов
2. **Включайте документацию** в workspace для легкого доступа
3. **Используйте shared schemes** для командной разработки
4. **Версионируйте workspace** настройки

### Настройки проекта
- **Build Settings** → User-Defined → добавьте кастомные переменные
- **Info.plist** → централизованные настройки через xcconfig
- **Entitlements** → правильные права доступа
- **Signing** → автоматическое подписание

### Рекомендуемые настройки Xcode
```
Preferences → Text Editing:
  ✅ Line numbers
  ✅ Code folding ribbon
  ✅ Focus follows selection
  
Preferences → Navigation:
  ✅ Open counterpart in Assistant Editor
  ✅ Uses focused editor
```

---

*Обновлено: Сегодня*  
*Автор: IWBB Team* 