import XCTest
import SwiftData
@testable import IWBB

// MARK: - Base Model Test Class

/// Базовый класс для тестирования SwiftData моделей
class BaseModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupTestContainer()
    }
    
    override func tearDown() {
        cleanupTestData()
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - Test Container Setup
    
    /// Настраивает тестовый контейнер в памяти
    private func setupTestContainer() {
        modelContainer = ModelContainer.testing()
        modelContext = modelContainer.mainContext
    }
    
    /// Очищает тестовые данные
    private func cleanupTestData() {
        guard let context = modelContext else { return }
        
        do {
            // Удаляем все тестовые данные
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
            XCTFail("Failed to clean up test data: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Создает тестового пользователя
    func createTestUser(name: String = "Test User", email: String = "test@example.com") -> User {
        let user = User(name: name, email: email)
        modelContext.insert(user)
        return user
    }
    
    /// Создает тестовую категорию
    func createTestCategory(
        name: String = "Test Category",
        type: CategoryType = .general,
        user: User? = nil
    ) -> Category {
        let category = Category(name: name, type: type)
        if let user = user {
            category.user = user
        }
        modelContext.insert(category)
        return category
    }
    
    /// Создает тестовую привычку
    func createTestHabit(
        name: String = "Test Habit",
        user: User? = nil,
        category: Category? = nil
    ) -> Habit {
        let habit = Habit(name: name, category: category)
        if let user = user {
            habit.user = user
        }
        modelContext.insert(habit)
        return habit
    }
    
    /// Создает тестовую задачу
    func createTestTask(
        title: String = "Test Task",
        user: User? = nil,
        category: Category? = nil
    ) -> Task {
        let task = Task(title: title, category: category)
        if let user = user {
            task.user = user
        }
        modelContext.insert(task)
        return task
    }
    
    /// Создает тестовую цель
    func createTestGoal(
        title: String = "Test Goal",
        user: User? = nil
    ) -> Goal {
        let goal = Goal(title: title, targetValue: 100, progressType: .percentage)
        if let user = user {
            goal.user = user
        }
        modelContext.insert(goal)
        return goal
    }
    
    /// Создает тестовую транзакцию
    func createTestTransaction(
        amount: Decimal = 100,
        type: TransactionType = .expense,
        title: String = "Test Transaction",
        user: User? = nil
    ) -> Transaction {
        let transaction = Transaction(amount: amount, type: type, title: title)
        if let user = user {
            transaction.user = user
        }
        modelContext.insert(transaction)
        return transaction
    }
    
    /// Создает тестовый бюджет
    func createTestBudget(
        name: String = "Test Budget",
        limit: Decimal = 10000,
        user: User? = nil
    ) -> Budget {
        let budget = Budget(name: name, limit: limit, period: .monthly)
        if let user = user {
            budget.user = user
        }
        modelContext.insert(budget)
        return budget
    }
    
    /// Создает тестовое достижение
    func createTestAchievement(
        title: String = "Test Achievement",
        targetValue: Double = 10,
        user: User? = nil
    ) -> Achievement {
        let achievement = Achievement(
            title: title,
            description: "Test description",
            type: .habit,
            criteria: .completedHabits,
            targetValue: targetValue
        )
        if let user = user {
            achievement.user = user
        }
        modelContext.insert(achievement)
        return achievement
    }
    
    /// Сохраняет изменения в контексте
    func saveContext() throws {
        try modelContext.save()
    }
    
    /// Выполняет блок кода с автосохранением
    func withAutoSave<T>(_ block: () throws -> T) throws -> T {
        let result = try block()
        try saveContext()
        return result
    }
    
    // MARK: - Assertion Helpers
    
    /// Проверяет, что модель корректно сохранена
    func assertModelSaved<T: PersistentModel>(_ model: T, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(model.persistentModelID, "Model should be saved", file: file, line: line)
    }
    
    /// Проверяет CloudKit синхронизацию
    func assertNeedsSync<T: CloudKitSyncable>(_ model: T, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(model.needsSync, "Model should be marked for sync", file: file, line: line)
    }
    
    /// Проверяет временные метки
    func assertTimestamps<T: Timestampable>(_ model: T, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(model.createdAt, "createdAt should be set", file: file, line: line)
        XCTAssertNotNil(model.updatedAt, "updatedAt should be set", file: file, line: line)
        XCTAssertTrue(model.updatedAt >= model.createdAt, "updatedAt should be >= createdAt", file: file, line: line)
    }
    
    /// Проверяет валидацию модели
    func assertValidation<T: Validatable>(_ model: T, shouldBeValid: Bool = true, file: StaticString = #file, line: UInt = #line) {
        do {
            try model.validate()
            if !shouldBeValid {
                XCTFail("Model validation should have failed", file: file, line: line)
            }
        } catch {
            if shouldBeValid {
                XCTFail("Model validation failed: \(error)", file: file, line: line)
            }
        }
    }
}

// MARK: - Test Data Factories

extension BaseModelTests {
    
    /// Фабрика для создания полного набора связанных тестовых данных
    func createFullTestDataSet() -> (user: User, categories: [Category], habits: [Habit], tasks: [Task], goals: [Goal]) {
        let user = createTestUser()
        
        let categories = [
            createTestCategory(name: "Health", type: .habit, user: user),
            createTestCategory(name: "Work", type: .task, user: user),
            createTestCategory(name: "Finance", type: .finance, user: user)
        ]
        
        let habits = [
            createTestHabit(name: "Exercise", user: user, category: categories[0]),
            createTestHabit(name: "Read", user: user, category: categories[0])
        ]
        
        let tasks = [
            createTestTask(title: "Project Review", user: user, category: categories[1]),
            createTestTask(title: "Email Check", user: user, category: categories[1])
        ]
        
        let goals = [
            createTestGoal(title: "Learn SwiftUI", user: user),
            createTestGoal(title: "Save Money", user: user)
        ]
        
        return (user, categories, habits, tasks, goals)
    }
}

// MARK: - Performance Testing Helpers

extension BaseModelTests {
    
    /// Измеряет производительность создания моделей
    func measureModelCreation<T>(
        count: Int = 1000,
        factory: () -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        measure {
            for _ in 0..<count {
                _ = factory()
            }
        }
    }
    
    /// Измеряет производительность запросов
    func measureQuery<T: PersistentModel>(
        type: T.Type,
        iterations: Int = 100,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Создаем тестовые данные
        for i in 0..<1000 {
            let model = type.init() as? T
            if let model = model {
                modelContext.insert(model)
            }
        }
        
        do {
            try saveContext()
        } catch {
            XCTFail("Failed to save test data: \(error)", file: file, line: line)
        }
        
        // Измеряем запросы
        measure {
            for _ in 0..<iterations {
                do {
                    let descriptor = FetchDescriptor<T>()
                    _ = try modelContext.fetch(descriptor)
                } catch {
                    XCTFail("Query failed: \(error)", file: file, line: line)
                }
            }
        }
    }
} 