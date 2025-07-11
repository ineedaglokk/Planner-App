import Foundation

// MARK: - Preview Data

struct PreviewData {
    
    // MARK: - Sample Transactions
    static let sampleTransactions: [Transaction] = [
        Transaction(
            amount: 3500,
            type: .expense,
            title: "Продукты",
            description: "Покупка в магазине",
            date: Date()
        ),
        Transaction(
            amount: 80000,
            type: .income,
            title: "Зарплата",
            description: "Основная работа",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        ),
        Transaction(
            amount: 1200,
            type: .expense,
            title: "Кафе",
            description: "Обед с коллегами",
            date: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        ),
        Transaction(
            amount: 500,
            type: .expense,
            title: "Транспорт",
            description: "Проезд в метро",
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        )
    ]
    
    // MARK: - Sample Category Statistics
    static let sampleCategoryStats: [CategoryStatistic] = [
        CategoryStatistic(
            category: MockCategory(name: "Продукты", icon: "cart.fill", color: "#FF6B6B"),
            amount: 12500
        ),
        CategoryStatistic(
            category: MockCategory(name: "Транспорт", icon: "car.fill", color: "#4ECDC4"),
            amount: 8000
        ),
        CategoryStatistic(
            category: MockCategory(name: "Развлечения", icon: "gamecontroller.fill", color: "#45B7D1"),
            amount: 5500
        ),
        CategoryStatistic(
            category: MockCategory(name: "Коммунальные", icon: "house.fill", color: "#96CEB4"),
            amount: 7200
        )
    ]
    
    // MARK: - Sample Balances
    static let sampleBalance: Decimal = 125000
    static let sampleChange: Decimal = 5000
}

// MARK: - Extensions for Transaction

extension Transaction {
    static var preview: Transaction {
        Transaction(
            amount: 1250,
            type: .expense,
            title: "Продукты",
            description: "Покупка в магазине"
        )
    }
} 