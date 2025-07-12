import SwiftUI

struct CategoryBreakdownView: View {
    
    @ObservedObject var viewModel: BudgetPlannerViewModel
    @State private var selectedTab: CategoryTab = .expenses
    
    enum CategoryTab: String, CaseIterable {
        case expenses = "Расходы"
        case payments = "Платежи"  
        case debts = "Долги"
        
        var title: String {
            return rawValue
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                // Заголовок
                headerSection
                
                // Круговая диаграмма трат по категориям
                expenseDistributionChart
                
                // Переключатель вкладок
                tabSelector
                
                // Детальные таблицы
                detailedTablesSection
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.lg)
        }
        .navigationTitle("Платежи, расходы и долги")
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
                    Text("Платежи, расходы и долги")
                        .font(Typography.Headline.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("• Распределяй свои обязательные платежи")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Анализируй, на что ты тратишь свои деньги")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Не забывай про долги, которые нависли")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                Text("3")
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
    
    // MARK: - Expense Distribution Chart
    
    private var expenseDistributionChart: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("ДОЛЯ ТРАТ ПО КАТЕГОРИЯМ")
                    .font(Typography.Headline.small)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.Text.primary)
                Spacer()
            }
            
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    // Создаем сегменты круговой диаграммы
                    ForEach(Array(viewModel.expensesByCategory.enumerated()), id: \.offset) { index, categorySummary in
                        PieSliceView(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            color: getColorForCategory(index)
                        )
                        .frame(width: size * 0.7, height: size * 0.7)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(height: 300)
            
            // Легенда с процентами
            expenseDistributionLegend
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Expense Distribution Legend
    
    private var expenseDistributionLegend: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(viewModel.expensesByCategory.enumerated()), id: \.offset) { index, categorySummary in
                HStack {
                    Rectangle()
                        .fill(getColorForCategory(index))
                        .frame(width: 16, height: 16)
                    
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(categorySummary.categoryName)
                            .font(Typography.Body.small)
                            .foregroundColor(ColorPalette.Text.primary)
                        
                        Text(String(format: "%.1f%%", categorySummary.percentage))
                            .font(Typography.Body.small)
                            .foregroundColor(ColorPalette.Text.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatCurrency(categorySummary.amount))
                        .font(Typography.Body.small)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.Text.primary)
                }
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack {
            ForEach(CategoryTab.allCases, id: \.self) { tab in
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
    
    // MARK: - Detailed Tables Section
    
    private var detailedTablesSection: some View {
        VStack(spacing: Spacing.md) {
            switch selectedTab {
            case .expenses:
                expensesTable
            case .payments:
                paymentsTable
            case .debts:
                debtsTable
            }
        }
    }
    
    // MARK: - Expenses Table
    
    private var expensesTable: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text("РАСХОДЫ")
                    .font(Typography.Headline.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                Spacer()
            }
            .background(Color.red.opacity(0.7))
            .cornerRadius(CornerRadius.small, corners: [.topLeft, .topRight])
            
            // Заголовки колонок
            HStack {
                Text("Статья расходов")
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
                ForEach(viewModel.planFactData.filter { $0.type == .expense }, id: \.id) { item in
                    CategoryTableRow(item: item)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(viewModel.totalPlannedExpenses))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(formatCurrency(viewModel.totalActualExpenses))
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
    
    // MARK: - Payments Table
    
    private var paymentsTable: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text("ПЛАТЕЖИ")
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
            
            // Строки таблицы - показываем основные платежи
            LazyVStack(spacing: 0) {
                ForEach(getPaymentItems(), id: \.id) { item in
                    CategoryTableRow(item: item)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(getPaymentItemsTotal().0))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(formatCurrency(getPaymentItemsTotal().1))
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
    
    // MARK: - Debts Table
    
    private var debtsTable: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text("ДОЛГИ")
                    .font(Typography.Headline.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                Spacer()
            }
            .background(Color.orange.opacity(0.7))
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
                ForEach(viewModel.planFactData.filter { $0.type == .debt }, id: \.id) { item in
                    CategoryTableRow(item: item)
                }
                
                // Итого
                HStack {
                    Text("Итого")
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(getDebtItemsTotal().0))
                        .font(Typography.Body.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Text(formatCurrency(getDebtItemsTotal().1))
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
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
    
    private func startAngle(for index: Int) -> Angle {
        let totalPercentage = viewModel.expensesByCategory.prefix(index).reduce(0) { $0 + $1.percentage }
        return .degrees(totalPercentage * 3.6 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let totalPercentage = viewModel.expensesByCategory.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return .degrees(totalPercentage * 3.6 - 90)
    }
    
    private func getColorForCategory(_ index: Int) -> Color {
        let colors: [Color] = [
            Color.red.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.green.opacity(0.8),
            Color.yellow.opacity(0.8),
            Color.purple.opacity(0.8),
            Color.orange.opacity(0.8),
            Color.pink.opacity(0.8),
            Color.teal.opacity(0.8)
        ]
        return colors[index % colors.count]
    }
    
    private func getPaymentItems() -> [BudgetPlanItem] {
        // Возвращаем основные платежи (жилье, связь, страхование и т.д.)
        return viewModel.planFactData.filter { item in
            item.type == .expense && 
            (item.name.contains("Жилье") || 
             item.name.contains("Связь") || 
             item.name.contains("Страхование") ||
             item.name.contains("Абонементы") ||
             item.name.contains("Подписки"))
        }
    }
    
    private func getPaymentItemsTotal() -> (Decimal, Decimal) {
        let items = getPaymentItems()
        let plannedTotal = items.reduce(0) { $0 + $1.plannedAmount }
        let actualTotal = items.reduce(0) { $0 + $1.actualAmount }
        return (plannedTotal, actualTotal)
    }
    
    private func getDebtItemsTotal() -> (Decimal, Decimal) {
        let items = viewModel.planFactData.filter { $0.type == .debt }
        let plannedTotal = items.reduce(0) { $0 + $1.plannedAmount }
        let actualTotal = items.reduce(0) { $0 + $1.actualAmount }
        return (plannedTotal, actualTotal)
    }
}

// MARK: - Category Table Row

struct CategoryTableRow: View {
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

// MARK: - Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        CategoryBreakdownView(viewModel: BudgetPlannerViewModel(
            financeService: ServiceContainer.shared.financeService,
            transactionRepository: ServiceContainer.shared.transactionRepository,
            dataService: ServiceContainer.shared.dataService
        ))
    }
} 