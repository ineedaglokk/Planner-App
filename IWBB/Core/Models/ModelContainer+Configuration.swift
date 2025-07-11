import Foundation
import SwiftData
import CloudKit

// MARK: - ModelContainer Configuration

extension ModelContainer {
    
    /// Основной ModelContainer для приложения с CloudKit синхронизацией
    static let shared: ModelContainer = {
        let schema = Schema([
            // Основные модели
            User.self,
            Category.self,
            
            // Модели привычек
            Habit.self,
            HabitEntry.self,
            
            // Модели задач
            Task.self,
            
            // Модели целей
            Goal.self,
            GoalMilestone.self,
            GoalProgress.self,
            
            // Финансовые модели
            Transaction.self,
            Budget.self,
            
            // Модели геймификации
            Achievement.self
        ])
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    // Основная конфигурация с CloudKit
                    ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: false,
                        allowsSave: true,
                        groupContainer: .identifier("group.com.plannerapp.shared"),
                        cloudKitDatabase: .private("iCloud.com.plannerapp.data")
                    )
                ]
            )
            
            // Настраиваем CloudKit синхронизацию
            configureCloudKitSync(for: container)
            
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }()
    
    /// Контейнер для предварительного просмотра (в памяти)
    static let preview: ModelContainer = {
        let schema = Schema([
            User.self, Category.self, Habit.self, HabitEntry.self,
            Task.self, Goal.self, GoalMilestone.self, GoalProgress.self,
            Transaction.self, Budget.self, Achievement.self
        ])
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                ]
            )
            
            // Заполняем тестовыми данными
            populatePreviewData(container: container)
            
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error.localizedDescription)")
        }
    }()
    
    /// Контейнер для тестирования (в памяти)
    static func testing() -> ModelContainer {
        let schema = Schema([
            User.self, Category.self, Habit.self, HabitEntry.self,
            Task.self, Goal.self, GoalMilestone.self, GoalProgress.self,
            Transaction.self, Budget.self, Achievement.self
        ])
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true
                    )
                ]
            )
            
            return container
        } catch {
            fatalError("Failed to create testing ModelContainer: \(error.localizedDescription)")
        }
    }
}

// MARK: - CloudKit Configuration

private extension ModelContainer {
    
    /// Настраивает CloudKit синхронизацию
    static func configureCloudKitSync(for container: ModelContainer) {
        // Здесь можно добавить дополнительную настройку CloudKit
        // например, настройка уведомлений о изменениях в CloudKit
        
        #if DEBUG
        print("CloudKit синхронизация настроена для ModelContainer")
        #endif
    }
}

// MARK: - Preview Data Population

private extension ModelContainer {
    
    /// Заполняет контейнер тестовыми данными для превью
    static func populatePreviewData(container: ModelContainer) {
        let context = container.mainContext
        
        // Создаем тестового пользователя
        let testUser = User(name: "Тестовый пользователь", email: "test@example.com")
        testUser.level = 5
        testUser.totalPoints = 1250
        testUser.currentExperience = 50
        testUser.experienceToNextLevel = 150
        testUser.currentStreak = 7
        testUser.longestStreak = 15
        testUser.totalHabitsCompleted = 45
        testUser.totalTasksCompleted = 123
        testUser.totalDaysActive = 30
        
        context.insert(testUser)
        
        // Создаем категории
        let categories = Category.createDefaultCategories(for: testUser)
        for category in categories {
            context.insert(category)
        }
        
        // Создаем тестовые привычки
        let habits = createPreviewHabits(for: testUser, categories: categories)
        for habit in habits {
            context.insert(habit)
        }
        
        // Создаем тестовые задачи
        let tasks = createPreviewTasks(for: testUser, categories: categories)
        for task in tasks {
            context.insert(task)
        }
        
        // Создаем тестовые цели
        let goals = createPreviewGoals(for: testUser, categories: categories)
        for goal in goals {
            context.insert(goal)
        }
        
        // Создаем тестовые транзакции
        let transactions = createPreviewTransactions(for: testUser, categories: categories)
        for transaction in transactions {
            context.insert(transaction)
        }
        
        // Создаем тестовые бюджеты
        let budgets = createPreviewBudgets(for: testUser, categories: categories)
        for budget in budgets {
            context.insert(budget)
        }
        
        // Создаем достижения
        let achievements = Achievement.createDefaultAchievements()
        for achievement in achievements {
            achievement.user = testUser
            // Разблокируем несколько достижений для демонстрации
            if ["Первый шаг", "Неделя силы воли", "Продуктивный день"].contains(achievement.title) {
                achievement.unlock()
            }
            context.insert(achievement)
        }
        
        // Сохраняем контекст
        do {
            try context.save()
        } catch {
            print("Failed to save preview data: \(error)")
        }
    }
    
    // MARK: - Preview Data Creators
    
    static func createPreviewHabits(for user: User, categories: [Category]) -> [Habit] {
        let healthCategory = categories.first { $0.name == "Здоровье" && $0.type == .habit }
        let workCategory = categories.first { $0.name == "Работа" && $0.type == .habit }
        
        return [
            Habit(
                name: "Утренняя зарядка",
                description: "15 минут физических упражнений каждое утро",
                icon: "figure.walk",
                color: "#FF3B30",
                frequency: .daily,
                targetValue: 1,
                unit: "раз",
                category: healthCategory
            ),
            Habit(
                name: "Чтение книг",
                description: "Читать минимум 30 минут в день",
                icon: "book",
                color: "#5856D6",
                frequency: .daily,
                targetValue: 30,
                unit: "минут"
            ),
            Habit(
                name: "Медитация",
                description: "10 минут осознанности",
                icon: "leaf",
                color: "#32D74B",
                frequency: .daily,
                targetValue: 10,
                unit: "минут",
                category: healthCategory
            ),
            Habit(
                name: "Планирование дня",
                description: "Составление плана на день",
                icon: "calendar",
                color: "#007AFF",
                frequency: .daily,
                targetValue: 1,
                unit: "раз",
                category: workCategory
            )
        ].map { habit in
            habit.user = user
            
            // Добавляем немного записей для демонстрации
            let calendar = Calendar.current
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    let entry = HabitEntry(habit: habit, date: date, value: habit.targetValue)
                    habit.entries.append(entry)
                }
            }
            
            return habit
        }
    }
    
    static func createPreviewTasks(for user: User, categories: [Category]) -> [Task] {
        let workCategory = categories.first { $0.name == "Работа" && $0.type == .task }
        let personalCategory = categories.first { $0.name == "Личные" && $0.type == .task }
        
        return [
            Task(
                title: "Подготовить презентацию",
                description: "Создать презентацию для клиента на завтра",
                priority: .high,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                category: workCategory
            ),
            Task(
                title: "Купить продукты",
                description: "Молоко, хлеб, яйца, овощи",
                priority: .medium,
                category: personalCategory
            ),
            Task(
                title: "Записаться к врачу",
                description: "Плановый осмотр",
                priority: .low,
                dueDate: Calendar.current.date(byAdding: .week, value: 1, to: Date()),
                category: personalCategory
            ),
            Task(
                title: "Ответить на email",
                description: "Проверить и ответить на важные письма",
                priority: .medium,
                category: workCategory
            )
        ].map { task in
            task.user = user
            
            // Несколько задач отмечаем как выполненные
            if ["Купить продукты", "Ответить на email"].contains(task.title) {
                task.markCompleted()
            }
            
            return task
        }
    }
    
    static func createPreviewGoals(for user: User, categories: [Category]) -> [Goal] {
        return [
            Goal(
                title: "Изучить SwiftUI",
                description: "Освоить основы SwiftUI для разработки iOS приложений",
                priority: .high,
                type: .education,
                targetDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()),
                targetValue: 100,
                progressType: .percentage
            ),
            Goal(
                title: "Накопить на отпуск",
                description: "Накопить 150,000 рублей на летний отпуск",
                priority: .medium,
                type: .financial,
                targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
                targetValue: 150000,
                unit: "₽",
                progressType: .numeric
            ),
            Goal(
                title: "Прочитать 24 книги за год",
                description: "Читать по 2 книги в месяц",
                priority: .medium,
                type: .personal,
                targetDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
                targetValue: 24,
                unit: "книг",
                progressType: .numeric
            )
        ].map { goal in
            goal.user = user
            
            // Добавляем прогресс
            switch goal.title {
            case "Изучить SwiftUI":
                goal.updateProgress(35)
            case "Накопить на отпуск":
                goal.updateProgress(45000)
            case "Прочитать 24 книги за год":
                goal.updateProgress(8)
            default:
                break
            }
            
            return goal
        }
    }
    
    static func createPreviewTransactions(for user: User, categories: [Category]) -> [Transaction] {
        let incomeCategory = categories.first { $0.name == "Доходы" && $0.type == .finance }
        let expenseCategory = categories.first { $0.name == "Расходы" && $0.type == .finance }
        
        let calendar = Calendar.current
        var transactions: [Transaction] = []
        
        // Создаем транзакции за последнюю неделю
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            // Доходы (зарплата в начале недели)
            if i == 6 {
                let salary = Transaction(
                    amount: 80000,
                    type: .income,
                    title: "Зарплата",
                    description: "Ежемесячная зарплата",
                    date: date,
                    category: incomeCategory,
                    account: "Основная карта"
                )
                salary.user = user
                transactions.append(salary)
            }
            
            // Ежедневные расходы
            let dailyExpenses = [
                ("Обед", Decimal(450), "Обед в кафе"),
                ("Транспорт", Decimal(120), "Метро"),
                ("Кофе", Decimal(200), "Утренний кофе")
            ]
            
            for (title, amount, description) in dailyExpenses {
                let expense = Transaction(
                    amount: amount,
                    type: .expense,
                    title: title,
                    description: description,
                    date: date,
                    category: expenseCategory,
                    account: "Основная карта"
                )
                expense.user = user
                transactions.append(expense)
            }
        }
        
        // Крупные покупки
        let bigExpenses = [
            ("Продукты", Decimal(3500), "Еженедельная закупка продуктов"),
            ("Интернет", Decimal(800), "Ежемесячная оплата интернета"),
            ("Телефон", Decimal(500), "Мобильная связь")
        ]
        
        for (title, amount, description) in bigExpenses {
            let expense = Transaction(
                amount: amount,
                type: .expense,
                title: title,
                description: description,
                date: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                category: expenseCategory,
                account: "Основная карта"
            )
            expense.user = user
            transactions.append(expense)
        }
        
        return transactions
    }
    
    static func createPreviewBudgets(for user: User, categories: [Category]) -> [Budget] {
        let expenseCategory = categories.first { $0.name == "Расходы" && $0.type == .finance }
        
        return [
            Budget(
                name: "Ежемесячные расходы",
                description: "Основной бюджет на месяц",
                limit: 50000,
                period: .monthly,
                category: expenseCategory
            ),
            Budget(
                name: "Развлечения",
                description: "Кино, рестораны, хобби",
                limit: 15000,
                period: .monthly
            ),
            Budget(
                name: "Продукты",
                description: "Еженедельный бюджет на продукты",
                limit: 5000,
                period: .weekly
            )
        ].map { budget in
            budget.user = user
            return budget
        }
    }
}

// MARK: - Migration Support

extension ModelContainer {
    
    /// Подготавливает миграции для будущих версий схемы
    static func prepareMigrations() {
        // Здесь будут описаны миграции при изменении схемы данных
        // Пока оставляем пустым, но структура готова для будущих изменений
        
        #if DEBUG
        print("Migration preparations completed")
        #endif
    }
} 