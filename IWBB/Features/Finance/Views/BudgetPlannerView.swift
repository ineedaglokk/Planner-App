import SwiftUI

struct BudgetPlannerView: View {
    
    @StateObject private var viewModel = BudgetPlannerViewModel(
        financeService: ServiceContainer.shared.financeService,
        transactionRepository: ServiceContainer.shared.transactionRepository,
        dataService: ServiceContainer.shared.dataService
    )
    
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false
    @State private var showingAddTransaction = false
    @State private var selectedItemToEdit: BudgetPlanItem?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    // Заголовок с селекторами
                    headerSection
                    
                    // Основная таблица план/факт
                    if viewModel.hasData() {
                        mainPlanFactTable
                        
                        // Быстрая сводка
                        financialSummaryCard
                        
                        // Навигация к другим разделам
                        navigationSection
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.lg)
            }
            .navigationTitle("Основной планер")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(ColorPalette.Primary.main)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView(viewModel: viewModel)
        }
        .sheet(item: $selectedItemToEdit) { item in
            EditBudgetItemView(item: item, viewModel: viewModel)
        }
        .alert("Ошибка", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // Заголовок ОБЗОР
            HStack {
                Text("ОБЗОР")
                    .font(Typography.Headline.medium)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.Text.primary)
                Spacer()
                
                // Номер (как на скриншоте)
                Text("1")
                    .font(Typography.Headline.large)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Селекторы
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Валюта")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Menu {
                        Button("RUB (₽)") { viewModel.selectedCurrency = "RUB" }
                        Button("USD ($)") { viewModel.selectedCurrency = "USD" }
                        Button("EUR (€)") { viewModel.selectedCurrency = "EUR" }
                    } label: {
                        HStack {
                            Text(viewModel.selectedCurrency)
                                .font(Typography.Body.medium)
                                .foregroundColor(ColorPalette.Text.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorPalette.Background.secondary)
                        .cornerRadius(CornerRadius.small)
                    }
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Выберите год")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Menu {
                        ForEach(viewModel.getAvailableYears(), id: \.self) { year in
                            Button("\(year)") {
                                Task {
                                    await viewModel.changeSelectedPeriod(year: year, month: viewModel.selectedMonth)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("\(viewModel.selectedYear)")
                                .font(Typography.Body.medium)
                                .foregroundColor(ColorPalette.Text.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorPalette.Background.secondary)
                        .cornerRadius(CornerRadius.small)
                    }
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Выберите месяц")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Menu {
                        ForEach(viewModel.getAvailableMonths(), id: \.0) { month, name in
                            Button(name) {
                                Task {
                                    await viewModel.changeSelectedPeriod(year: viewModel.selectedYear, month: month)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.monthName)
                                .font(Typography.Body.medium)
                                .foregroundColor(ColorPalette.Text.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorPalette.Background.secondary)
                        .cornerRadius(CornerRadius.small)
                    }
                }
                
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Начало")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("1")
                        .font(Typography.Body.medium)
                        .foregroundColor(ColorPalette.Text.primary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorPalette.Background.secondary)
                        .cornerRadius(CornerRadius.small)
                }
            }
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Main Plan Fact Table
    
    private var mainPlanFactTable: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text("ПОСТУПЛЕНИЯ & РАСХОДЫ")
                    .font(Typography.Headline.medium)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.Text.primary)
                Spacer()
            }
            .padding(.bottom, Spacing.md)
            
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
                    .frame(width: 100, alignment: .trailing)
                
                Text("Факт")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.Background.secondary)
            
            // Строки таблицы
            LazyVStack(spacing: 0) {
                ForEach(viewModel.planFactData.filter { $0.type != .savings }, id: \.id) { item in
                    PlanFactTableRow(item: item) {
                        selectedItemToEdit = item
                    }
                }
                
                // Остаток
                HStack {
                    Text("Остаток")
                        .font(Typography.Body.medium)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(formatCurrency(viewModel.totalPlannedBalance))
                        .font(Typography.Body.medium)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.totalPlannedBalance >= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense)
                        .frame(width: 100, alignment: .trailing)
                    
                    Text(formatCurrency(viewModel.totalActualBalance))
                        .font(Typography.Body.medium)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.totalActualBalance >= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(ColorPalette.Background.primary)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(ColorPalette.Border.light),
                    alignment: .bottom
                )
                
                // Капитал и накопления
                HStack {
                    Text("Капитал и накопления")
                        .font(Typography.Body.medium)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("")
                        .frame(width: 100, alignment: .trailing)
                    
                    Text(formatCurrency(viewModel.capitalAndSavings))
                        .font(Typography.Body.medium)
                        .foregroundColor(ColorPalette.Text.primary)
                        .frame(width: 100, alignment: .trailing)
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
    
    // MARK: - Financial Summary Card
    
    private var financialSummaryCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Финансы в месяц")
                        .font(Typography.Headline.small)
                        .fontWeight(.semibold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("• Быстрый обзор за определенный месяц")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Шкала поступлений и расходов")
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
            
            // Финансовая шкала
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Доходы")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    Spacer()
                    Text(formatCurrency(viewModel.totalActualIncome))
                        .font(Typography.Body.small)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.Financial.income)
                }
                
                ProgressView(value: Double(viewModel.totalActualIncome), total: Double(max(viewModel.totalActualIncome, viewModel.totalActualExpenses)))
                    .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.Financial.income))
                
                HStack {
                    Text("Расходы")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    Spacer()
                    Text(formatCurrency(viewModel.totalActualExpenses))
                        .font(Typography.Body.small)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.Financial.expense)
                }
                
                ProgressView(value: Double(viewModel.totalActualExpenses), total: Double(max(viewModel.totalActualIncome, viewModel.totalActualExpenses)))
                    .progressViewStyle(LinearProgressViewStyle(tint: ColorPalette.Financial.expense))
            }
        }
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(spacing: Spacing.md) {
            NavigationLink(destination: BudgetChartsView(viewModel: viewModel)) {
                NavigationCard(
                    title: "Графики и статистика",
                    description: "• Отслеживай свои поступления, платежи,\n  расходы и долги\n• Следи за остатком каждый месяц\n• Определи, по каким категориям своей жизни ты\n  тратишь больше всего денег",
                    number: "2"
                )
            }
            
            NavigationLink(destination: CategoryBreakdownView(viewModel: viewModel)) {
                NavigationCard(
                    title: "Платежи, расходы и долги",
                    description: "• Распределяй свои обязательные платежи\n• Анализируй, на что ты тратишь свои деньги\n• Не забывай про долги, которые нависли",
                    number: "3"
                )
            }
            
            NavigationLink(destination: IncomeAndSavingsView(viewModel: viewModel)) {
                NavigationCard(
                    title: "Поступления и накопления",
                    description: "• Отслеживай все поступления,\n  которые были у тебя за месяц\n• Следи за своими счетами, вкладами\n  и дивидендами",
                    number: "4"
                )
            }
            
            NavigationLink(destination: DailyTransactionsView(viewModel: viewModel)) {
                NavigationCard(
                    title: "Ежедневные траты и поступления",
                    description: "• Отслеживай, на что ты тратишь деньги\n  каждый день\n• Фиксируй свою поступления каждый день",
                    number: "5"
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.Text.tertiary)
            
            Text("Нет данных для отображения")
                .font(Typography.Headline.medium)
                .foregroundColor(ColorPalette.Text.secondary)
            
            Text("Создайте новый бюджетный план для начала работы")
                .font(Typography.Body.medium)
                .foregroundColor(ColorPalette.Text.tertiary)
                .multilineTextAlignment(.center)
            
            Button("Создать план") {
                Task {
                    await viewModel.createNewBudgetPlan()
                }
            }
            .buttonStyle(PrimaryButton())
        }
        .padding(.all, Spacing.xl)
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

// MARK: - Plan Fact Table Row

struct PlanFactTableRow: View {
    let item: BudgetPlanItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(item.name)
                    .font(Typography.Body.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(item.formattedPlannedAmount)
                    .font(Typography.Body.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                    .frame(width: 100, alignment: .trailing)
                
                Text(item.formattedActualAmount)
                    .font(Typography.Body.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.Background.primary)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(ColorPalette.Border.light),
                alignment: .bottom
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Navigation Card

struct NavigationCard: View {
    let title: String
    let description: String
    let number: String
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.Headline.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.primary)
                
                Text(description)
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
        .padding(.all, Spacing.md)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview
#Preview {
    BudgetPlannerView()
} 