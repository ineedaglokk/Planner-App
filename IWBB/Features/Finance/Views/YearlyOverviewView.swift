import SwiftUI

struct YearlyOverviewView: View {
    
    @ObservedObject var viewModel: BudgetPlannerViewModel
    @State private var selectedTab: YearlyTab = .overview
    
    enum YearlyTab: String, CaseIterable {
        case overview = "Годовой обзор"
        case monthly = "Помесячно"
        case categories = "По категориям"
        
        var title: String {
            return rawValue
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                // Заголовок
                headerSection
                
                // Переключатель вкладок
                tabSelector
                
                // Контент в зависимости от выбранной вкладки
                switch selectedTab {
                case .overview:
                    yearlyOverviewSection
                case .monthly:
                    monthlyBreakdownSection
                case .categories:
                    categoryBreakdownSection
                }
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.lg)
        }
        .navigationTitle("Обзор")
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
                    Text("Годовой обзор")
                        .font(Typography.Headline.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("• Следи за своими годовыми поступлениями и\n  расходами")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Отслеживай, на что ты тратишь больше всего денег")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Узнай, сколько получилось накопить за год")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                Text("1")
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
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack {
            ForEach(YearlyTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.title)
                        .font(Typography.Body.medium)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == tab ? .white : ColorPalette.Text.primary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(selectedTab == tab ? ColorPalette.Primary.main : ColorPalette.Background.secondary)
                        .cornerRadius(CornerRadius.small)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Yearly Overview Section
    
    private var yearlyOverviewSection: some View {
        VStack(spacing: Spacing.lg) {
            // Заголовок года
            yearHeaderSection
            
            // Основные показатели
            yearlyStatsSection
            
            // Помесячные таблицы
            yearlyTablesSection
        }
    }
    
    // MARK: - Year Header Section
    
    private var yearHeaderSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("\(viewModel.selectedYear) год")
                    .font(Typography.Headline.large)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.Text.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("Идеальный баланс")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("Всего")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                        .padding(.trailing, 40)
                }
            }
            
            // Годовые диаграммы (упрощенные круговые диаграммы)
            HStack(spacing: Spacing.lg) {
                YearlyPieChart(title: "Доходы", color: .green)
                YearlyPieChart(title: "Расходы", color: .red)
                YearlyPieChart(title: "Накопления", color: .blue)
            }
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Yearly Stats Section
    
    private var yearlyStatsSection: some View {
        HStack(spacing: Spacing.md) {
            YearlyStatCard(
                title: "Годовые платежи, расходы и долги",
                subtitle: "Отследи, сколько денег ты тратишь в год\nПроанализируй свои траты\nУзнай итог потраченных средств",
                number: "2"
            )
            
            YearlyStatCard(
                title: "Годовые поступления и накопления",
                subtitle: "Отследи свои поступления по всем месяцам\nУзнай, какой месяц принес больше всего\nнакоплений",
                number: "3"
            )
        }
    }
    
    // MARK: - Yearly Tables Section
    
    private var yearlyTablesSection: some View {
        HStack(spacing: Spacing.md) {
            // Платежи
            YearlyTable(
                title: "ПЛАТЕЖИ",
                color: Color.red.opacity(0.7),
                items: getYearlyPayments()
            )
            
            // Расходы
            YearlyTable(
                title: "РАСХОДЫ",
                color: Color.orange.opacity(0.7),
                items: getYearlyExpenses()
            )
            
            // Долги
            YearlyTable(
                title: "ДОЛГИ",
                color: Color.yellow.opacity(0.7),
                items: getYearlyDebts()
            )
        }
    }
    
    // MARK: - Monthly Breakdown Section
    
    private var monthlyBreakdownSection: some View {
        VStack(spacing: Spacing.lg) {
            // Поступления и накопления
            monthlyIncomeAndSavingsSection
            
            // Траты и поступления
            monthlyExpensesAndIncomeSection
        }
    }
    
    // MARK: - Monthly Income and Savings
    
    private var monthlyIncomeAndSavingsSection: some View {
        HStack(spacing: Spacing.md) {
            MonthlyTable(
                title: "ПОСТУПЛЕНИЯ",
                color: Color.green.opacity(0.7),
                items: getMonthlyIncome(),
                total: viewModel.totalActualIncome
            )
            
            MonthlyTable(
                title: "НАКОПЛЕНИЯ",
                color: Color.blue.opacity(0.7),
                items: getMonthlySavings(),
                total: viewModel.capitalAndSavings
            )
        }
    }
    
    // MARK: - Monthly Expenses and Income
    
    private var monthlyExpensesAndIncomeSection: some View {
        HStack(spacing: Spacing.md) {
            MonthlyTable(
                title: "ТРАТЫ",
                color: Color.red.opacity(0.7),
                items: getMonthlyExpenses(),
                total: viewModel.totalActualExpenses
            )
            
            MonthlyTable(
                title: "ПОСТУПЛЕНИЯ",
                color: Color.green.opacity(0.7),
                items: getMonthlyIncome(),
                total: viewModel.totalActualIncome
            )
        }
    }
    
    // MARK: - Category Breakdown Section
    
    private var categoryBreakdownSection: some View {
        VStack(spacing: Spacing.lg) {
            CategoryBreakdownTable(
                title: "Годовые траты и поступления",
                subtitle: "Определи, на что ты тратил больше\nвсего денег за год\nОтследи, что принесло тебе\nнаибольшую прибыль в году",
                number: "4",
                expenseCategories: viewModel.expensesByCategory,
                incomeCategories: viewModel.incomeByCategory
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getYearlyPayments() -> [YearlyItem] {
        return [
            YearlyItem(name: "Январь", amount: 13928),
            YearlyItem(name: "Февраль", amount: 10000),
            YearlyItem(name: "Март", amount: 0),
            YearlyItem(name: "Апрель", amount: 0),
            YearlyItem(name: "Май", amount: 0),
            YearlyItem(name: "Июнь", amount: 0),
            YearlyItem(name: "Июль", amount: 0),
            YearlyItem(name: "Август", amount: 0),
            YearlyItem(name: "Сентябрь", amount: 0),
            YearlyItem(name: "Октябрь", amount: 0),
            YearlyItem(name: "Ноябрь", amount: 0),
            YearlyItem(name: "Декабрь", amount: 0)
        ]
    }
    
    private func getYearlyExpenses() -> [YearlyItem] {
        return [
            YearlyItem(name: "Январь", amount: 145889),
            YearlyItem(name: "Февраль", amount: 20000),
            YearlyItem(name: "Март", amount: 2000),
            YearlyItem(name: "Апрель", amount: 0),
            YearlyItem(name: "Май", amount: 0),
            YearlyItem(name: "Июнь", amount: 0),
            YearlyItem(name: "Июль", amount: 0),
            YearlyItem(name: "Август", amount: 0),
            YearlyItem(name: "Сентябрь", amount: 0),
            YearlyItem(name: "Октябрь", amount: 0),
            YearlyItem(name: "Ноябрь", amount: 0),
            YearlyItem(name: "Декабрь", amount: 0)
        ]
    }
    
    private func getYearlyDebts() -> [YearlyItem] {
        return [
            YearlyItem(name: "Январь", amount: 25465),
            YearlyItem(name: "Февраль", amount: 0),
            YearlyItem(name: "Март", amount: 0),
            YearlyItem(name: "Апрель", amount: 0),
            YearlyItem(name: "Май", amount: 0),
            YearlyItem(name: "Июнь", amount: 0),
            YearlyItem(name: "Июль", amount: 0),
            YearlyItem(name: "Август", amount: 0),
            YearlyItem(name: "Сентябрь", amount: 0),
            YearlyItem(name: "Октябрь", amount: 0),
            YearlyItem(name: "Ноябрь", amount: 0),
            YearlyItem(name: "Декабрь", amount: 0)
        ]
    }
    
    private func getMonthlyIncome() -> [YearlyItem] {
        return [
            YearlyItem(name: "Январь", amount: Decimal(viewModel.totalActualIncome)),
            YearlyItem(name: "Февраль", amount: 0),
            YearlyItem(name: "Март", amount: 0),
            YearlyItem(name: "Апрель", amount: 200000),
            YearlyItem(name: "Май", amount: 0),
            YearlyItem(name: "Июнь", amount: 0),
            YearlyItem(name: "Июль", amount: 0),
            YearlyItem(name: "Август", amount: 0),
            YearlyItem(name: "Сентябрь", amount: 0),
            YearlyItem(name: "Октябрь", amount: 0),
            YearlyItem(name: "Ноябрь", amount: 0),
            YearlyItem(name: "Декабрь", amount: 0)
        ]
    }
    
    private func getMonthlySavings() -> [YearlyItem] {
        return [
            YearlyItem(name: "Январь", amount: 100000),
            YearlyItem(name: "Февраль", amount: 2000),
            YearlyItem(name: "Март", amount: 0),
            YearlyItem(name: "Апрель", amount: 0),
            YearlyItem(name: "Май", amount: 0),
            YearlyItem(name: "Июнь", amount: 0),
            YearlyItem(name: "Июль", amount: 0),
            YearlyItem(name: "Август", amount: 0),
            YearlyItem(name: "Сентябрь", amount: 0),
            YearlyItem(name: "Октябрь", amount: 0),
            YearlyItem(name: "Ноябрь", amount: 0),
            YearlyItem(name: "Декабрь", amount: 0)
        ]
    }
    
    private func getMonthlyExpenses() -> [YearlyItem] {
        return [
            YearlyItem(name: "Январь", amount: Decimal(viewModel.totalActualExpenses)),
            YearlyItem(name: "Февраль", amount: 0),
            YearlyItem(name: "Март", amount: 0),
            YearlyItem(name: "Апрель", amount: 0),
            YearlyItem(name: "Май", amount: 0),
            YearlyItem(name: "Июнь", amount: 0),
            YearlyItem(name: "Июль", amount: 0),
            YearlyItem(name: "Август", amount: 0),
            YearlyItem(name: "Сентябрь", amount: 0),
            YearlyItem(name: "Октябрь", amount: 0),
            YearlyItem(name: "Ноябрь", amount: 0),
            YearlyItem(name: "Декабрь", amount: 0)
        ]
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

// MARK: - Supporting Views

struct YearlyPieChart: View {
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 60, height: 60)
                .overlay(
                    Text("100%")
                        .font(Typography.Body.small)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            Text(title)
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
        }
    }
}

struct YearlyStatCard: View {
    let title: String
    let subtitle: String
    let number: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.Headline.small)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text(subtitle)
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Text(number)
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
}

struct YearlyTable: View {
    let title: String
    let color: Color
    let items: [YearlyItem]
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text(title)
                    .font(Typography.Body.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(color)
            
            // Заголовки колонок
            HStack {
                Text("Месяц")
                    .font(Typography.Caption.medium)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Сумма")
                    .font(Typography.Caption.medium)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorPalette.Background.secondary)
            
            // Строки
            LazyVStack(spacing: 0) {
                ForEach(items, id: \.name) { item in
                    YearlyTableRow(item: item)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Caption.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatTotal())
                        .font(Typography.Caption.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(ColorPalette.Background.secondary)
            }
        }
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.small)
    }
    
    private func formatTotal() -> String {
        let total = items.reduce(0) { $0 + $1.amount }
        return formatAmount(total)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
    }
}

struct YearlyTableRow: View {
    let item: YearlyItem
    
    var body: some View {
        HStack {
            Text(item.name)
                .font(Typography.Caption.medium)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatAmount(item.amount))
                .font(Typography.Caption.medium)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorPalette.Background.primary)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(ColorPalette.Border.light),
            alignment: .bottom
        )
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        if amount == 0 {
            return "0,0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
    }
}

struct MonthlyTable: View {
    let title: String
    let color: Color
    let items: [YearlyItem]
    let total: Decimal
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text(title)
                    .font(Typography.Body.medium)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(color)
            
            // Заголовки колонок
            HStack {
                Text("Месяц")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Сумма")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.Background.secondary)
            
            // Строки
            LazyVStack(spacing: 0) {
                ForEach(items, id: \.name) { item in
                    MonthlyTableRow(item: item)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(total))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
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
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

struct MonthlyTableRow: View {
    let item: YearlyItem
    
    var body: some View {
        HStack {
            Text(item.name)
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatCurrency(item.amount))
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
        if amount == 0 {
            return "0,0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

struct CategoryBreakdownTable: View {
    let title: String
    let subtitle: String
    let number: String
    let expenseCategories: [CategorySummary]
    let incomeCategories: [CategorySummary]
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.Headline.small)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text(subtitle)
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Text(number)
                    .font(Typography.Headline.large)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Таблицы трат и поступлений
            HStack(spacing: Spacing.md) {
                CategoryTable(
                    title: "ТРАТЫ",
                    color: Color.red.opacity(0.7),
                    categories: expenseCategories
                )
                
                CategoryTable(
                    title: "ПОСТУПЛЕНИЯ",
                    color: Color.green.opacity(0.7),
                    categories: incomeCategories
                )
            }
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
}

struct CategoryTable: View {
    let title: String
    let color: Color
    let categories: [CategorySummary]
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Text(title)
                    .font(Typography.Body.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(color)
            
            // Заголовки колонок
            HStack {
                Text("Статья расходов")
                    .font(Typography.Caption.medium)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Сумма")
                    .font(Typography.Caption.medium)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(ColorPalette.Background.secondary)
            
            // Строки
            LazyVStack(spacing: 0) {
                ForEach(categories.prefix(10), id: \.categoryName) { category in
                    CategoryTableRow(category: category)
                }
            }
        }
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.small)
    }
}

struct CategoryTableRow: View {
    let category: CategorySummary
    
    var body: some View {
        HStack {
            Text(category.categoryName)
                .font(Typography.Caption.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatAmount(category.amount))
                .font(Typography.Caption.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorPalette.Background.primary)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(ColorPalette.Border.light),
            alignment: .bottom
        )
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
    }
}

// MARK: - Supporting Types

struct YearlyItem {
    let name: String
    let amount: Decimal
}

// MARK: - Preview
#Preview {
    NavigationView {
        YearlyOverviewView(viewModel: BudgetPlannerViewModel(
            financeService: ServiceContainer.shared.financeService,
            transactionRepository: ServiceContainer.shared.transactionRepository,
            dataService: ServiceContainer.shared.dataService
        ))
    }
} 