import SwiftUI
import Charts

struct BudgetChartsView: View {
    
    @ObservedObject var viewModel: BudgetPlannerViewModel
    @State private var selectedChartType: ChartType = .planVsActual
    
    enum ChartType: String, CaseIterable {
        case planVsActual = "План/Факт"
        case expenseDistribution = "Распределение трат"
        case incomeDistribution = "Распределение доходов"
        
        var title: String {
            return rawValue
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                // Заголовок
                headerSection
                
                // Переключатель типа графика
                chartTypeSelector
                
                // Основной график
                mainChartSection
                
                // Дополнительная информация
                chartInfoSection
                
                // Детальная статистика
                detailedStatsSection
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.lg)
        }
        .navigationTitle("Графики и статистика")
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
                    Text("Графики и статистика")
                        .font(Typography.Headline.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("• Отслеживай свои поступления, платежи,\n  расходы и долги")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Следи за остатком каждый месяц")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Определи, по каким категориям своей жизни ты\n  тратишь больше всего денег")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                Text("2")
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
    
    // MARK: - Chart Type Selector
    
    private var chartTypeSelector: some View {
        HStack {
            ForEach(ChartType.allCases, id: \.self) { type in
                Button(action: {
                    selectedChartType = type
                }) {
                    Text(type.title)
                        .font(Typography.Body.small)
                        .fontWeight(.medium)
                        .foregroundColor(selectedChartType == type ? .white : ColorPalette.Text.primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(selectedChartType == type ? ColorPalette.Primary.main : ColorPalette.Background.secondary)
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
    
    // MARK: - Main Chart Section
    
    private var mainChartSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text(selectedChartType.title)
                    .font(Typography.Headline.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.primary)
                Spacer()
            }
            
            // График в зависимости от выбранного типа
            switch selectedChartType {
            case .planVsActual:
                planVsActualChart
            case .expenseDistribution:
                expenseDistributionChart
            case .incomeDistribution:
                incomeDistributionChart
            }
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Plan vs Actual Chart
    
    private var planVsActualChart: some View {
        Chart {
            ForEach(viewModel.planVsActualChartData, id: \.0) { category, plannedAmount, actualAmount in
                // Столбец для плана
                BarMark(
                    x: .value("Категория", category),
                    y: .value("Сумма", plannedAmount)
                )
                .foregroundStyle(Color.blue.opacity(0.7))
                .position(by: .value("Тип", "План"))
                
                // Столбец для факта
                BarMark(
                    x: .value("Категория", category),
                    y: .value("Сумма", actualAmount)
                )
                .foregroundStyle(Color.red.opacity(0.7))
                .position(by: .value("Тип", "Факт"))
            }
        }
        .frame(height: 300)
        .chartXAxis {
            AxisMarks(preset: .extended, values: .automatic) { value in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(ColorPalette.Text.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended, values: .automatic) { value in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(ColorPalette.Text.secondary)
            }
        }
        .chartLegend(position: .bottom) {
            HStack {
                HStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: 12, height: 12)
                    Text("План")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                HStack {
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 12, height: 12)
                    Text("Факт")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
            }
        }
    }
    
    // MARK: - Expense Distribution Chart
    
    private var expenseDistributionChart: some View {
        VStack(spacing: Spacing.md) {
            // Круговая диаграмма
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
                        .frame(width: size * 0.8, height: size * 0.8)
                    }
                    
                    // Центральный текст
                    VStack {
                        Text("Остаток")
                            .font(Typography.Body.medium)
                            .foregroundColor(ColorPalette.Text.secondary)
                        
                        Text("77,5%")
                            .font(Typography.Headline.medium)
                            .fontWeight(.bold)
                            .foregroundColor(ColorPalette.Text.primary)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(height: 250)
            
            // Легенда
            expenseDistributionLegend
        }
    }
    
    // MARK: - Income Distribution Chart
    
    private var incomeDistributionChart: some View {
        VStack(spacing: Spacing.md) {
            // Круговая диаграмма доходов
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                
                ZStack {
                    // Создаем сегменты круговой диаграммы
                    ForEach(Array(viewModel.incomeByCategory.enumerated()), id: \.offset) { index, categorySummary in
                        PieSliceView(
                            startAngle: startAngle(for: index, isIncome: true),
                            endAngle: endAngle(for: index, isIncome: true),
                            color: getColorForIncomeCategory(index)
                        )
                        .frame(width: size * 0.8, height: size * 0.8)
                    }
                    
                    // Центральный текст
                    VStack {
                        Text("Доходы")
                            .font(Typography.Body.medium)
                            .foregroundColor(ColorPalette.Text.secondary)
                        
                        Text("100%")
                            .font(Typography.Headline.medium)
                            .fontWeight(.bold)
                            .foregroundColor(ColorPalette.Text.primary)
                    }
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .frame(height: 250)
            
            // Легенда доходов
            incomeDistributionLegend
        }
    }
    
    // MARK: - Expense Distribution Legend
    
    private var expenseDistributionLegend: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(viewModel.expensesByCategory.prefix(5).enumerated()), id: \.offset) { index, categorySummary in
                HStack {
                    Rectangle()
                        .fill(getColorForCategory(index))
                        .frame(width: 12, height: 12)
                    
                    Text(categorySummary.categoryName)
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", categorySummary.percentage))
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
            }
        }
    }
    
    // MARK: - Income Distribution Legend
    
    private var incomeDistributionLegend: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(Array(viewModel.incomeByCategory.prefix(5).enumerated()), id: \.offset) { index, categorySummary in
                HStack {
                    Rectangle()
                        .fill(getColorForIncomeCategory(index))
                        .frame(width: 12, height: 12)
                    
                    Text(categorySummary.categoryName)
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", categorySummary.percentage))
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
            }
        }
    }
    
    // MARK: - Chart Info Section
    
    private var chartInfoSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                StatCard(
                    title: "Общий доход",
                    value: formatCurrency(viewModel.totalActualIncome),
                    color: ColorPalette.Financial.income
                )
                
                StatCard(
                    title: "Общие расходы",
                    value: formatCurrency(viewModel.totalActualExpenses),
                    color: ColorPalette.Financial.expense
                )
            }
            
            HStack {
                StatCard(
                    title: "Остаток",
                    value: formatCurrency(viewModel.totalActualBalance),
                    color: viewModel.totalActualBalance >= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense
                )
                
                StatCard(
                    title: "Накопления",
                    value: formatCurrency(viewModel.capitalAndSavings),
                    color: ColorPalette.Primary.main
                )
            }
        }
    }
    
    // MARK: - Detailed Stats Section
    
    private var detailedStatsSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Детальная статистика")
                    .font(Typography.Headline.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.primary)
                Spacer()
            }
            
            VStack(spacing: Spacing.sm) {
                DetailedStatRow(
                    title: "Доля расходов от доходов",
                    value: "\(Int(viewModel.expenseToIncomeRatio))%",
                    color: viewModel.expenseToIncomeRatio > 80 ? ColorPalette.Financial.expense : ColorPalette.Financial.income
                )
                
                DetailedStatRow(
                    title: "Норма сбережений",
                    value: "\(Int(viewModel.savingsRate))%",
                    color: viewModel.savingsRate > 20 ? ColorPalette.Financial.income : ColorPalette.Financial.expense
                )
                
                DetailedStatRow(
                    title: "Топ категория расходов",
                    value: viewModel.topExpenseCategory,
                    color: ColorPalette.Text.secondary
                )
            }
        }
        .padding(.all, Spacing.md)
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
    
    private func startAngle(for index: Int, isIncome: Bool = false) -> Angle {
        let categories = isIncome ? viewModel.incomeByCategory : viewModel.expensesByCategory
        let totalPercentage = categories.prefix(index).reduce(0) { $0 + $1.percentage }
        return .degrees(totalPercentage * 3.6 - 90) // -90 чтобы начинать сверху
    }
    
    private func endAngle(for index: Int, isIncome: Bool = false) -> Angle {
        let categories = isIncome ? viewModel.incomeByCategory : viewModel.expensesByCategory
        let totalPercentage = categories.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return .degrees(totalPercentage * 3.6 - 90)
    }
    
    private func getColorForCategory(_ index: Int) -> Color {
        let colors: [Color] = [
            Color.red.opacity(0.8),
            Color.green.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.yellow.opacity(0.8),
            Color.purple.opacity(0.8),
            Color.orange.opacity(0.8)
        ]
        return colors[index % colors.count]
    }
    
    private func getColorForIncomeCategory(_ index: Int) -> Color {
        let colors: [Color] = [
            Color.green.opacity(0.8),
            Color.blue.opacity(0.8),
            Color.teal.opacity(0.8),
            Color.mint.opacity(0.8),
            Color.cyan.opacity(0.8)
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Pie Slice View

struct PieSliceView: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        Path { path in
            let center = CGPoint(x: 100, y: 100)
            let radius: CGFloat = 80
            
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
        }
        .fill(color)
        .overlay(
            Path { path in
                let center = CGPoint(x: 100, y: 100)
                let radius: CGFloat = 80
                
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
            }
            .stroke(Color.white, lineWidth: 2)
        )
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
            
            Text(value)
                .font(Typography.Headline.small)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 1, x: 0, y: 1)
    }
}

// MARK: - Detailed Stat Row

struct DetailedStatRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(Typography.Body.medium)
                .foregroundColor(ColorPalette.Text.primary)
            
            Spacer()
            
            Text(value)
                .font(Typography.Body.medium)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        BudgetChartsView(viewModel: BudgetPlannerViewModel(
            financeService: ServiceContainer.shared.financeService,
            transactionRepository: ServiceContainer.shared.transactionRepository,
            dataService: ServiceContainer.shared.dataService
        ))
    }
} 