import Foundation
import SwiftUI

// MARK: - Finance Overview ViewModel

@MainActor
final class FinanceOverviewViewModel: ObservableObject {
    
    // MARK: - State
    @Published var state = State()
    @Published var input = Input()
    
    // MARK: - State Structure
    struct State {
        var currentBalance: Decimal = 0
        var balanceChange: Decimal = 0
        var recentTransactions: [Transaction] = []
        var categoryStats: [CategoryStatistic] = []
        var isLoading = false
        var error: Error?
    }
    
    struct Input {
        var selectedPeriod: FinancePeriod = .month
    }
    
    // MARK: - Methods
    
    func loadData() async {
        state.isLoading = true
        state.error = nil
        
        do {
            // Симуляция загрузки данных
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
            
            // Генерируем тестовые данные
            state.currentBalance = generateRandomBalance()
            state.balanceChange = generateRandomChange()
            state.recentTransactions = generateRecentTransactions()
            state.categoryStats = generateCategoryStats()
            
        } catch {
            state.error = error
        }
        
        state.isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Private Methods
    
    private func generateRandomBalance() -> Decimal {
        return Decimal(Double.random(in: 50000...200000))
    }
    
    private func generateRandomChange() -> Decimal {
        return Decimal(Double.random(in: -10000...10000))
    }
    
    private func generateRecentTransactions() -> [Transaction] {
        let titles = ["Продукты", "Зарплата", "Кафе", "Транспорт", "Покупки", "Коммунальные", "Развлечения"]
        let descriptions = ["Покупка в магазине", "Основная работа", "Обед с коллегами", "Проезд", "Одежда", "Счета за месяц", "Кино"]
        
        return (0..<5).compactMap { index in
            let title = titles[index % titles.count]
            let description = descriptions[index % descriptions.count]
            let amount = Decimal(Double.random(in: 100...5000))
            let type: TransactionType = index == 1 ? .income : .expense
            
            return Transaction(
                amount: amount,
                type: type,
                title: title,
                description: description,
                date: Calendar.current.date(byAdding: .day, value: -index, to: Date()) ?? Date()
            )
        }
    }
    
    private func generateCategoryStats() -> [CategoryStatistic] {
        let categories = [
            ("Продукты", "cart.fill", "#FF6B6B"),
            ("Транспорт", "car.fill", "#4ECDC4"),
            ("Развлечения", "gamecontroller.fill", "#45B7D1"),
            ("Коммунальные", "house.fill", "#96CEB4"),
            ("Здоровье", "heart.fill", "#FFEAA7")
        ]
        
        return categories.map { (name, icon, color) in
            CategoryStatistic(
                category: MockCategory(name: name, icon: icon, color: color),
                amount: Decimal(Double.random(in: 1000...10000))
            )
        }
    }
}

// MARK: - Category Statistic

struct CategoryStatistic: Identifiable {
    let id = UUID()
    let category: MockCategory
    let amount: Decimal
}

// MARK: - Mock Category

struct MockCategory {
    let name: String
    let icon: String
    let color: String
}

// MARK: - Preview Helper

extension FinanceOverviewViewModel {
    static var preview: FinanceOverviewViewModel {
        let viewModel = FinanceOverviewViewModel()
        viewModel.state.currentBalance = 125000
        viewModel.state.balanceChange = 5000
        viewModel.state.recentTransactions = [
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
            )
        ]
        return viewModel
    }
} 