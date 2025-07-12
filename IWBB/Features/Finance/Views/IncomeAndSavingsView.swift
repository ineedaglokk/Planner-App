import SwiftUI

struct IncomeAndSavingsView: View {
    
    @ObservedObject var viewModel: BudgetPlannerViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                // Заголовок
                headerSection
                
                // Таблица поступлений
                incomeTableSection
                
                // Таблица накоплений
                savingsTableSection
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.lg)
        }
        .navigationTitle("Поступления и накопления")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Поступления и накопления")
                        .font(Typography.Headline.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("• Отслеживай все поступления,\n  которые были у тебя за месяц")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Следи за своими счетами, вкладами\n  и дивидендами")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                Text("4")
                    .font(Typography.Headline.large)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Income Table Section
    
    private var incomeTableSection: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text("ПОСТУПЛЕНИЯ")
                    .font(Typography.Headline.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                Spacer()
            }
            .background(Color.green.opacity(0.7))
            .cornerRadius(CornerRadius.small, corners: [.topLeft, .topRight])
            
            // Заголовки колонок
            HStack {
                Text("Наименование")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("План")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                Text("Факт")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.Background.secondary)
            
            // Строки таблицы
            LazyVStack(spacing: 0) {
                ForEach(getIncomeItems(), id: \.id) { item in
                    IncomeTableRow(item: item)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(viewModel.totalPlannedIncome))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Financial.income)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(formatCurrency(viewModel.totalActualIncome))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Financial.income)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(ColorPalette.Background.secondary)
            }
        }
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Savings Table Section
    
    private var savingsTableSection: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text("НАКОПЛЕНИЯ")
                    .font(Typography.Headline.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                Spacer()
            }
            .background(Color.blue.opacity(0.7))
            .cornerRadius(CornerRadius.small, corners: [.topLeft, .topRight])
            
            // Заголовки колонок
            HStack {
                Text("Наименование")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Факт")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.Background.secondary)
            
            // Строки таблицы накоплений
            LazyVStack(spacing: 0) {
                // Основные накопления
                SavingsTableRow(
                    title: "Поступления расходы",
                    amount: viewModel.totalActualBalance
                )
                
                SavingsTableRow(
                    title: "Накопления предыдущий месяц",
                    amount: 100000 // TODO: Получить из предыдущего месяца
                )
                
                SavingsTableRow(
                    title: "Накопления текущий месяц",
                    amount: 75000 // TODO: Рассчитать текущие накопления
                )
                
                SavingsTableRow(
                    title: "Подушка безопасности",
                    amount: 0
                )
                
                SavingsTableRow(
                    title: "Вклады",
                    amount: 0
                )
                
                SavingsTableRow(
                    title: "Дивиденды",
                    amount: 0
                )
                
                SavingsTableRow(
                    title: "Криптовалюта",
                    amount: 15000
                )
                
                // Пустые строки для заполнения
                ForEach(0..<4, id: \.self) { _ in
                    SavingsTableRow(title: "", amount: 0)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(getSavingsTotal()))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Primary.main)
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(ColorPalette.Background.secondary)
            }
        }
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Methods
    
    private func getIncomeItems() -> [BudgetPlanItem] {
        var items: [BudgetPlanItem] = []
        
        // Добавляем основную категорию доходов
        if let currentPlan = viewModel.currentBudgetPlan {
            items.append(currentPlan.income)
            items.append(contentsOf: currentPlan.incomeItems)
        }
        
        return items
    }
    
    private func getSavingsTotal() -> Decimal {
        // TODO: Рассчитать реальную сумму накоплений
        return viewModel.totalActualBalance + 100000 + 75000 + 15000
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

// MARK: - Income Table Row

struct IncomeTableRow: View {
    let item: BudgetPlanItem
    
    var body: some View {
        HStack {
            Text(item.name)
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatCurrency(item.plannedAmount))
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(width: 80, alignment: .trailing)
            
            Text(formatCurrency(item.actualAmount))
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(ColorPalette.Background.primary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ColorPalette.Border.light),
            alignment: .bottom
        )
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

// MARK: - Savings Table Row

struct SavingsTableRow: View {
    let title: String
    let amount: Decimal
    
    var body: some View {
        HStack {
            Text(title)
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if amount > 0 {
                Text(formatCurrency(amount))
                    .font(Typography.Body.small)
                    .foregroundColor(ColorPalette.Text.primary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("")
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(ColorPalette.Background.primary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ColorPalette.Border.light),
            alignment: .bottom
        )
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        IncomeAndSavingsView(viewModel: BudgetPlannerViewModel(
            financeService: ServiceContainer.shared.financeService,
            transactionRepository: ServiceContainer.shared.transactionRepository,
            dataService: ServiceContainer.shared.dataService
        ))
    }
} 