import Foundation
import SwiftData

// MARK: - Sample Data Generator

/// Класс для создания образцов данных для тестирования и демонстрации
final class SampleData {
    
    // MARK: - Main Sample Data Creator
    
    /// Создает полный набор образцов данных для тестирования
    static func createSampleData(in context: ModelContext) {
        // Очищаем существующие данные
        clearAllData(in: context)
        
        // Создаем основные данные
        let user = createSampleUser()
        context.insert(user)
        
        let categories = createSampleCategories(for: user)
        categories.forEach { context.insert($0) }
        
        let habits = createSampleHabits(for: user, categories: categories)
        habits.forEach { context.insert($0) }
        
        let tasks = createSampleTasks(for: user, categories: categories)
        tasks.forEach { context.insert($0) }
        
        let goals = createSampleGoals(for: user, categories: categories)
        goals.forEach { context.insert($0) }
        
        let transactions = createSampleTransactions(for: user, categories: categories)
        transactions.forEach { context.insert($0) }
        
        let budgets = createSampleBudgets(for: user, categories: categories)
        budgets.forEach { context.insert($0) }
        
        let achievements = createSampleAchievements(for: user)
        achievements.forEach { context.insert($0) }
        
        // Сохраняем изменения
        do {
            try context.save()
        } catch {
            print("❌ Ошибка сохранения образцов данных: \(error)")
        }
        
        print("✅ Образцы данных успешно созданы")
    }
    
    // MARK: - Individual Data Creators
    
    /// Создает образец пользователя
    static func createSampleUser() -> User {
        let user = User(
            name: "Александр Петров",
            email: "alex.petrov@example.com"
        )
        
        // Устанавливаем прогресс геймификации
        user.level = 12
        user.totalPoints = 3450
        user.currentExperience = 750
        user.experienceToNextLevel = 1200
        
        // Статистика активности
        user.currentStreak = 15
        user.longestStreak = 42
        user.totalHabitsCompleted = 234
        user.totalTasksCompleted = 567
        user.totalDaysActive = 89
        
        return user
    }
    
    /// Создает образцы категорий
    static func createSampleCategories(for user: User) -> [Category] {
        var categories: [Category] = []
        
        // Категории привычек
        let habitCategories = [
            Category(name: "💪 Здоровье", description: "Спорт, питание, сон", icon: "heart.circle", color: "#FF3B30", type: .habit),
            Category(name: "🧠 Развитие", description: "Обучение и личностный рост", icon: "brain.head.profile", color: "#5856D6", type: .habit),
            Category(name: "💼 Работа", description: "Профессиональные привычки", icon: "briefcase.circle", color: "#007AFF", type: .habit),
            Category(name: "🏠 Дом", description: "Домашние дела и быт", icon: "house.circle", color: "#32D74B", type: .habit)
        ]
        
        // Категории задач
        let taskCategories = [
            Category(name: "🔥 Срочные", description: "Требуют немедленного внимания", icon: "exclamationmark.circle", color: "#FF3B30", type: .task),
            Category(name: "💼 Рабочие", description: "Связанные с работой", icon: "briefcase", color: "#007AFF", type: .task),
            Category(name: "👤 Личные", description: "Личные задачи", icon: "person.circle", color: "#32D74B", type: .task),
            Category(name: "🛒 Покупки", description: "Что нужно купить", icon: "cart.circle", color: "#FF9500", type: .task)
        ]
        
        // Финансовые категории
        let financeCategories = [
            Category(name: "💰 Доходы", description: "Источники доходов", icon: "arrow.up.circle", color: "#32D74B", type: .finance),
            Category(name: "🛍️ Покупки", description: "Расходы на покупки", icon: "bag.circle", color: "#FF9500", type: .finance),
            Category(name: "🍽️ Еда", description: "Питание и рестораны", icon: "fork.knife.circle", color: "#FF6B6B", type: .finance),
            Category(name: "🚗 Транспорт", description: "Транспортные расходы", icon: "car.circle", color: "#4ECDC4", type: .finance),
            Category(name: "🎯 Развлечения", description: "Отдых и хобби", icon: "gamecontroller.circle", color: "#A8E6CF", type: .finance)
        ]
        
        categories.append(contentsOf: habitCategories)
        categories.append(contentsOf: taskCategories)
        categories.append(contentsOf: financeCategories)
        
        // Устанавливаем пользователя для всех категорий
        categories.forEach { $0.user = user }
        
        return categories
    }
    
    /// Создает образцы привычек
    static func createSampleHabits(for user: User, categories: [Category]) -> [Habit] {
        let healthCategory = categories.first { $0.name.contains("Здоровье") }
        let developmentCategory = categories.first { $0.name.contains("Развитие") }
        let workCategory = categories.first { $0.name.contains("Работа") && $0.type == .habit }
        
        let sampleHabits = [
            // Здоровье
            Habit(name: "Утренняя зарядка", description: "20 минут физических упражнений", icon: "figure.walk", color: "#FF3B30", frequency: .daily, targetValue: 20, unit: "минут", category: healthCategory),
            Habit(name: "Выпить воды", description: "2 литра чистой воды в день", icon: "drop", color: "#007AFF", frequency: .daily, targetValue: 8, unit: "стаканов", category: healthCategory),
            Habit(name: "Прогулка", description: "Вечерняя прогулка на свежем воздухе", icon: "figure.walk.motion", color: "#32D74B", frequency: .daily, targetValue: 30, unit: "минут", category: healthCategory),
            
            // Развитие
            Habit(name: "Чтение", description: "Чтение художественной или развивающей литературы", icon: "book", color: "#5856D6", frequency: .daily, targetValue: 30, unit: "минут", category: developmentCategory),
            Habit(name: "Медитация", description: "Практика осознанности", icon: "leaf", color: "#32D74B", frequency: .daily, targetValue: 15, unit: "минут", category: developmentCategory),
            Habit(name: "Изучение языка", description: "Английский язык", icon: "textbook", color: "#FF9500", frequency: .daily, targetValue: 20, unit: "минут", category: developmentCategory),
            
            // Работа
            Habit(name: "Планирование дня", description: "Составление плана на день", icon: "calendar", color: "#007AFF", frequency: .daily, targetValue: 1, unit: "раз", category: workCategory),
            Habit(name: "Проверка email", description: "Обработка входящих писем", icon: "envelope", color: "#FF9500", frequency: .workdays, targetValue: 2, unit: "раза", category: workCategory)
        ]
        
        // Устанавливаем пользователя и создаем записи
        sampleHabits.forEach { habit in
            habit.user = user
            
            // Создаем записи за последние 30 дней с разной степенью выполнения
            let calendar = Calendar.current
            for i in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
                
                // Симулируем реалистичное выполнение привычек
                let shouldComplete = Bool.random() && (i < 7 || Double.random(in: 0...1) > 0.3)
                
                if shouldComplete && habit.shouldTrackForDate(date) {
                    let randomValue = Int.random(in: max(1, habit.targetValue/2)...habit.targetValue)
                    let entry = HabitEntry(habit: habit, date: date, value: randomValue)
                    habit.entries.append(entry)
                }
            }
        }
        
        return sampleHabits
    }
    
    /// Создает образцы задач
    static func createSampleTasks(for user: User, categories: [Category]) -> [Task] {
        let urgentCategory = categories.first { $0.name.contains("Срочные") }
        let workCategory = categories.first { $0.name.contains("Рабочие") }
        let personalCategory = categories.first { $0.name.contains("Личные") }
        let shoppingCategory = categories.first { $0.name.contains("Покупки") }
        
        let calendar = Calendar.current
        
        let sampleTasks = [
            // Срочные
            Task(title: "Подготовить отчет", description: "Квартальный отчет для руководства", priority: .urgent, dueDate: calendar.date(byAdding: .day, value: 1, to: Date()), category: urgentCategory),
            Task(title: "Ответить клиенту", description: "Срочный ответ по проекту", priority: .high, dueDate: calendar.date(byAdding: .hour, value: 4, to: Date()), category: urgentCategory),
            
            // Рабочие
            Task(title: "Код-ревью", description: "Проверить код коллеги", priority: .medium, dueDate: calendar.date(byAdding: .day, value: 2, to: Date()), category: workCategory),
            Task(title: "Обновить документацию", description: "Актуализировать техническую документацию", priority: .low, category: workCategory),
            Task(title: "Созвон с командой", description: "Еженедельная встреча команды", priority: .medium, dueDate: calendar.date(byAdding: .day, value: 3, to: Date()), category: workCategory),
            
            // Личные
            Task(title: "Записаться к врачу", description: "Плановый осмотр у терапевта", priority: .medium, dueDate: calendar.date(byAdding: .week, value: 1, to: Date()), category: personalCategory),
            Task(title: "Подарок маме", description: "Выбрать подарок на день рождения", priority: .high, dueDate: calendar.date(byAdding: .week, value: 2, to: Date()), category: personalCategory),
            Task(title: "Заправить машину", description: "Заехать на АЗС", priority: .low, category: personalCategory),
            
            // Покупки
            Task(title: "Продукты на неделю", description: "Молоко, хлеб, овощи, фрукты", priority: .medium, category: shoppingCategory),
            Task(title: "Новые кроссовки", description: "Для занятий спортом", priority: .low, category: shoppingCategory)
        ]
        
        // Устанавливаем пользователя и случайно отмечаем некоторые как выполненные
        sampleTasks.forEach { task in
            task.user = user
            
            // 30% шанс что задача уже выполнена
            if Double.random(in: 0...1) < 0.3 {
                task.markCompleted()
            }
        }
        
        return sampleTasks
    }
    
    /// Создает образцы целей
    static func createSampleGoals(for user: User, categories: [Category]) -> [Goal] {
        let calendar = Calendar.current
        
        let sampleGoals = [
            Goal(
                title: "Изучить SwiftUI",
                description: "Освоить разработку iOS приложений на SwiftUI",
                priority: .high,
                type: .education,
                targetDate: calendar.date(byAdding: .month, value: 4, to: Date()),
                targetValue: 100,
                progressType: .percentage
            ),
            Goal(
                title: "Сбросить 5 кг",
                description: "Привести себя в форму к лету",
                priority: .medium,
                type: .health,
                targetDate: calendar.date(byAdding: .month, value: 6, to: Date()),
                targetValue: 5,
                unit: "кг",
                progressType: .numeric
            ),
            Goal(
                title: "Накопить на отпуск",
                description: "Накопить 200,000 рублей на путешествие",
                priority: .medium,
                type: .financial,
                targetDate: calendar.date(byAdding: .month, value: 8, to: Date()),
                targetValue: 200000,
                unit: "₽",
                progressType: .numeric
            ),
            Goal(
                title: "Прочитать 12 книг",
                description: "По книге в месяц",
                priority: .low,
                type: .personal,
                targetDate: calendar.date(byAdding: .year, value: 1, to: Date()),
                targetValue: 12,
                unit: "книг",
                progressType: .numeric
            )
        ]
        
        // Устанавливаем пользователя и добавляем прогресс
        sampleGoals.forEach { goal in
            goal.user = user
            
            // Добавляем реалистичный прогресс
            switch goal.title {
            case "Изучить SwiftUI":
                goal.updateProgress(45)
                // Добавляем вехи
                let milestone1 = GoalMilestone(title: "Основы", targetProgress: 0.25)
                let milestone2 = GoalMilestone(title: "Компоненты", targetProgress: 0.5)
                let milestone3 = GoalMilestone(title: "Навигация", targetProgress: 0.75)
                goal.addMilestone(milestone1)
                goal.addMilestone(milestone2)
                goal.addMilestone(milestone3)
                milestone1.markAchieved()
                
            case "Сбросить 5 кг":
                goal.updateProgress(2)
                
            case "Накопить на отпуск":
                goal.updateProgress(75000)
                
            case "Прочитать 12 книг":
                goal.updateProgress(4)
                
            default:
                break
            }
        }
        
        return sampleGoals
    }
    
    /// Создает образцы транзакций
    static func createSampleTransactions(for user: User, categories: [Category]) -> [Transaction] {
        let incomeCategory = categories.first { $0.name.contains("Доходы") }
        let foodCategory = categories.first { $0.name.contains("Еда") }
        let shoppingCategory = categories.first { $0.name.contains("Покупки") && $0.type == .finance }
        let transportCategory = categories.first { $0.name.contains("Транспорт") }
        let entertainmentCategory = categories.first { $0.name.contains("Развлечения") }
        
        var transactions: [Transaction] = []
        let calendar = Calendar.current
        
        // Создаем транзакции за последние 30 дней
        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            // Зарплата в начале месяца
            if i == 28 {
                let salary = Transaction(
                    amount: 120000,
                    type: .income,
                    title: "Зарплата",
                    description: "Основное место работы",
                    date: date,
                    category: incomeCategory,
                    account: "Основная карта"
                )
                salary.user = user
                transactions.append(salary)
            }
            
            // Ежедневные расходы на еду
            if Bool.random() { // Не каждый день
                let foodExpenses = [
                    ("Завтрак", Decimal.random(in: 200...500)),
                    ("Обед", Decimal.random(in: 400...800)),
                    ("Ужин", Decimal.random(in: 300...700)),
                    ("Кофе", Decimal.random(in: 150...300))
                ]
                
                for (title, amount) in foodExpenses.prefix(Int.random(in: 1...3)) {
                    let transaction = Transaction(
                        amount: amount,
                        type: .expense,
                        title: title,
                        date: date,
                        category: foodCategory,
                        account: "Основная карта"
                    )
                    transaction.user = user
                    transactions.append(transaction)
                }
            }
            
            // Транспорт
            if i % 2 == 0 { // Через день
                let transport = Transaction(
                    amount: Decimal.random(in: 100...200),
                    type: .expense,
                    title: "Транспорт",
                    description: "Метро/автобус",
                    date: date,
                    category: transportCategory,
                    account: "Основная карта"
                )
                transport.user = user
                transactions.append(transport)
            }
        }
        
        // Крупные покупки
        let bigPurchases = [
            ("Продукты", Decimal(5500), "Еженедельная закупка", shoppingCategory),
            ("Одежда", Decimal(8900), "Новая куртка", shoppingCategory),
            ("Книги", Decimal(2100), "Техническая литература", entertainmentCategory),
            ("Кино", Decimal(600), "Билеты в кинотеатр", entertainmentCategory),
            ("Спортзал", Decimal(3000), "Абонемент на месяц", entertainmentCategory)
        ]
        
        for (title, amount, description, category) in bigPurchases {
            let transaction = Transaction(
                amount: amount,
                type: .expense,
                title: title,
                description: description,
                date: calendar.date(byAdding: .day, value: -Int.random(in: 1...15), to: Date()) ?? Date(),
                category: category,
                account: "Основная карта"
            )
            transaction.user = user
            transactions.append(transaction)
        }
        
        return transactions
    }
    
    /// Создает образцы бюджетов
    static func createSampleBudgets(for user: User, categories: [Category]) -> [Budget] {
        let foodCategory = categories.first { $0.name.contains("Еда") }
        let shoppingCategory = categories.first { $0.name.contains("Покупки") && $0.type == .finance }
        let entertainmentCategory = categories.first { $0.name.contains("Развлечения") }
        
        let sampleBudgets = [
            Budget(
                name: "Ежемесячный бюджет",
                description: "Основной бюджет на все расходы",
                limit: 60000,
                period: .monthly
            ),
            Budget(
                name: "Питание",
                description: "Бюджет на еду и рестораны",
                limit: 20000,
                period: .monthly,
                category: foodCategory
            ),
            Budget(
                name: "Покупки",
                description: "Одежда, техника, товары для дома",
                limit: 15000,
                period: .monthly,
                category: shoppingCategory
            ),
            Budget(
                name: "Развлечения",
                description: "Кино, спорт, хобби",
                limit: 8000,
                period: .monthly,
                category: entertainmentCategory
            )
        ]
        
        sampleBudgets.forEach { $0.user = user }
        
        return sampleBudgets
    }
    
    /// Создает образцы достижений
    static func createSampleAchievements(for user: User) -> [Achievement] {
        let achievements = Achievement.createDefaultAchievements()
        
        // Разблокируем некоторые достижения
        let unlockedTitles = [
            "Первый шаг",
            "Неделя силы воли",
            "Продуктивный день",
            "Целеустремленный",
            "Новичок",
            "Первые сбережения"
        ]
        
        achievements.forEach { achievement in
            achievement.user = user
            
            if unlockedTitles.contains(achievement.title) {
                achievement.updateProgressFromUser(user)
                if achievement.isReadyToUnlock {
                    achievement.unlock()
                }
            } else {
                // Добавляем частичный прогресс
                achievement.updateProgressFromUser(user)
            }
        }
        
        return achievements
    }
    
    // MARK: - Utility Methods
    
    /// Очищает все данные из контекста
    private static func clearAllData(in context: ModelContext) {
        do {
            // Удаляем все модели
            try context.delete(model: User.self)
            try context.delete(model: Category.self)
            try context.delete(model: Habit.self)
            try context.delete(model: HabitEntry.self)
            try context.delete(model: Task.self)
            try context.delete(model: Goal.self)
            try context.delete(model: GoalMilestone.self)
            try context.delete(model: GoalProgress.self)
            try context.delete(model: Transaction.self)
            try context.delete(model: Budget.self)
            try context.delete(model: Achievement.self)
            
            try context.save()
        } catch {
            print("❌ Ошибка очистки данных: \(error)")
        }
    }
}

// MARK: - Extensions for Random Data

private extension Decimal {
    static func random(in range: ClosedRange<Double>) -> Decimal {
        let randomDouble = Double.random(in: range)
        return Decimal(randomDouble)
    }
} 