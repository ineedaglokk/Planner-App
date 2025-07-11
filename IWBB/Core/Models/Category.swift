import Foundation
import SwiftData

// MARK: - Category Model

@Model
final class Category: CloudKitSyncable, Timestampable, Archivable {
    
    // MARK: - Properties
    
    @Attribute(.unique) var id: UUID
    var name: String
    var description: String?
    var icon: String // SF Symbol name
    var color: String // Hex color
    var type: CategoryType
    var sortOrder: Int
    
    // Архивация
    var isArchived: Bool
    var archivedAt: Date?
    
    // Метаданные
    var createdAt: Date
    var updatedAt: Date
    
    // CloudKit синхронизация
    var cloudKitRecordID: String?
    var needsSync: Bool
    var lastSynced: Date?
    
    // MARK: - Relationships
    
    // Иерархия категорий
    var parentCategory: Category?
    @Relationship(deleteRule: .cascade, inverse: \Category.parentCategory) 
    var subcategories: [Category]
    
    // Связи с другими моделями
    var user: User?
    @Relationship(inverse: \Habit.category) var habits: [Habit]
    @Relationship(inverse: \Task.category) var tasks: [Task]
    @Relationship(inverse: \Goal.category) var goals: [Goal]
    @Relationship(inverse: \Transaction.category) var transactions: [Transaction]
    @Relationship(inverse: \Budget.category) var budgets: [Budget]
    
    // MARK: - Initializers
    
    init(
        name: String,
        description: String? = nil,
        icon: String = "folder",
        color: String = "#007AFF",
        type: CategoryType,
        sortOrder: Int = 0,
        parentCategory: Category? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.color = color
        self.type = type
        self.sortOrder = sortOrder
        self.parentCategory = parentCategory
        
        // Архивация
        self.isArchived = false
        self.archivedAt = nil
        
        // Метаданные
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // CloudKit
        self.cloudKitRecordID = nil
        self.needsSync = true
        self.lastSynced = nil
        
        // Relationships
        self.subcategories = []
        self.habits = []
        self.tasks = []
        self.goals = []
        self.transactions = []
        self.budgets = []
    }
}

// MARK: - Category Extensions

extension Category: Validatable {
    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ModelValidationError.emptyName
        }
        
        // Проверяем, что категория не является родителем самой себя
        if let parent = parentCategory, parent.id == self.id {
            throw ModelValidationError.missingRequiredField("Категория не может быть родителем самой себя")
        }
    }
}

extension Category {
    
    // MARK: - Computed Properties
    
    /// Полный путь к категории (включая родительские)
    var fullPath: String {
        if let parent = parentCategory {
            return "\(parent.fullPath) > \(name)"
        }
        return name
    }
    
    /// Уровень вложенности категории
    var depth: Int {
        if let parent = parentCategory {
            return parent.depth + 1
        }
        return 0
    }
    
    /// Все дочерние категории (включая вложенные)
    var allSubcategories: [Category] {
        var result: [Category] = []
        for subcategory in subcategories where !subcategory.isArchived {
            result.append(subcategory)
            result.append(contentsOf: subcategory.allSubcategories)
        }
        return result
    }
    
    /// Является ли категория корневой (без родителя)
    var isRootCategory: Bool {
        return parentCategory == nil
    }
    
    /// Количество элементов в категории
    var itemsCount: Int {
        let habitsCount = habits.filter { !$0.isArchived }.count
        let tasksCount = tasks.filter { !$0.isArchived }.count
        let goalsCount = goals.filter { !$0.isArchived }.count
        let transactionsCount = transactions.count
        let budgetsCount = budgets.filter { !$0.isArchived }.count
        
        return habitsCount + tasksCount + goalsCount + transactionsCount + budgetsCount
    }
    
    /// Общее количество элементов (включая подкатегории)
    var totalItemsCount: Int {
        let currentCount = itemsCount
        let subcategoriesCount = allSubcategories.reduce(0) { $0 + $1.itemsCount }
        return currentCount + subcategoriesCount
    }
    
    // MARK: - Category Management
    
    /// Добавляет подкатегорию
    func addSubcategory(_ subcategory: Category) {
        subcategory.parentCategory = self
        subcategory.type = self.type // Наследуем тип от родителя
        subcategories.append(subcategory)
        updateTimestamp()
        markForSync()
    }
    
    /// Удаляет подкатегорию
    func removeSubcategory(_ subcategory: Category) {
        subcategory.parentCategory = nil
        subcategories.removeAll { $0.id == subcategory.id }
        updateTimestamp()
        markForSync()
    }
    
    /// Перемещает категорию в другую родительскую категорию
    func moveTo(parent: Category?) {
        // Проверяем, что не создается циклическая зависимость
        if let newParent = parent {
            var current: Category? = newParent
            while current != nil {
                if current?.id == self.id {
                    return // Предотвращаем циклическую зависимость
                }
                current = current?.parentCategory
            }
        }
        
        // Удаляем из старого родителя
        parentCategory?.subcategories.removeAll { $0.id == self.id }
        
        // Добавляем к новому родителю
        self.parentCategory = parent
        parent?.subcategories.append(self)
        
        updateTimestamp()
        markForSync()
    }
    
    /// Обновляет порядок сортировки
    func updateSortOrder(_ newOrder: Int) {
        sortOrder = newOrder
        updateTimestamp()
        markForSync()
    }
}

// MARK: - Category Type

enum CategoryType: String, Codable, CaseIterable {
    case habit = "habit"
    case task = "task"
    case goal = "goal"
    case finance = "finance"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .habit: return "Привычки"
        case .task: return "Задачи"
        case .goal: return "Цели"
        case .finance: return "Финансы"
        case .general: return "Общее"
        }
    }
    
    var defaultIcon: String {
        switch self {
        case .habit: return "repeat.circle"
        case .task: return "checkmark.circle"
        case .goal: return "target"
        case .finance: return "dollarsign.circle"
        case .general: return "folder"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .habit: return "#32D74B" // Green
        case .task: return "#007AFF" // Blue
        case .goal: return "#FF9500" // Orange
        case .finance: return "#34C759" // Green
        case .general: return "#8E8E93" // Gray
        }
    }
}

// MARK: - Predefined Categories

extension Category {
    
    /// Создает набор предустановленных категорий для пользователя
    static func createDefaultCategories(for user: User) -> [Category] {
        var categories: [Category] = []
        
        // Категории привычек
        let healthHabits = Category(
            name: "Здоровье",
            description: "Привычки связанные со здоровьем",
            icon: "heart.circle",
            color: "#FF3B30",
            type: .habit
        )
        
        let workHabits = Category(
            name: "Работа",
            description: "Рабочие привычки и продуктивность",
            icon: "briefcase.circle",
            color: "#007AFF",
            type: .habit
        )
        
        let personalHabits = Category(
            name: "Личное развитие",
            description: "Привычки для личного роста",
            icon: "brain.head.profile",
            color: "#5856D6",
            type: .habit
        )
        
        categories.append(contentsOf: [healthHabits, workHabits, personalHabits])
        
        // Категории задач
        let urgentTasks = Category(
            name: "Срочные",
            description: "Срочные задачи",
            icon: "exclamationmark.circle",
            color: "#FF3B30",
            type: .task
        )
        
        let workTasks = Category(
            name: "Работа",
            description: "Рабочие задачи",
            icon: "briefcase",
            color: "#007AFF",
            type: .task
        )
        
        let personalTasks = Category(
            name: "Личные",
            description: "Личные задачи",
            icon: "person.circle",
            color: "#32D74B",
            type: .task
        )
        
        categories.append(contentsOf: [urgentTasks, workTasks, personalTasks])
        
        // Категории финансов
        let incomeFinance = Category(
            name: "Доходы",
            description: "Источники доходов",
            icon: "arrow.up.circle",
            color: "#32D74B",
            type: .finance
        )
        
        let expenseFinance = Category(
            name: "Расходы",
            description: "Основные расходы",
            icon: "arrow.down.circle",
            color: "#FF3B30",
            type: .finance
        )
        
        let savingsFinance = Category(
            name: "Накопления",
            description: "Сбережения и инвестиции",
            icon: "banknote.circle",
            color: "#FF9500",
            type: .finance
        )
        
        categories.append(contentsOf: [incomeFinance, expenseFinance, savingsFinance])
        
        // Устанавливаем пользователя для всех категорий
        for category in categories {
            category.user = user
        }
        
        return categories
    }
} 