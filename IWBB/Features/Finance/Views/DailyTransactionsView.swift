import SwiftUI

struct DailyTransactionsView: View {
    
    @ObservedObject var viewModel: BudgetPlannerViewModel
    @State private var selectedTab: TransactionTab = .expenses
    @State private var showingAddTransaction = false
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    enum TransactionTab: String, CaseIterable {
        case expenses = "Ежедневные траты"
        case income = "Ежедневные поступления"
        
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
                
                // Фильтр по дате
                dateFilterSection
                
                // Таблица транзакций
                transactionsTableSection
                
                // Кнопка добавления новой транзакции
                addTransactionButton
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.lg)
        }
        .navigationTitle("Ежедневные операции")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddDailyTransactionView(viewModel: viewModel, selectedDate: selectedDate)
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerView(selectedDate: $selectedDate)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Ежедневные траты и поступления")
                        .font(Typography.Headline.medium)
                        .fontWeight(.bold)
                        .foregroundColor(ColorPalette.Text.primary)
                    
                    Text("• Отслеживай, на что ты тратишь деньги\n  каждый день")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                    
                    Text("• Фиксируй свою поступления каждый день")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.secondary)
                }
                
                Spacer()
                
                Text("5")
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
            ForEach(TransactionTab.allCases, id: \.self) { tab in
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
    
    // MARK: - Date Filter Section
    
    private var dateFilterSection: some View {
        HStack {
            Button(action: {
                showingDatePicker = true
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(ColorPalette.Primary.main)
                    
                    Text(formatDate(selectedDate))
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
            
            Spacer()
            
            Text(getTransactionsSummary())
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Transactions Table Section
    
    private var transactionsTableSection: some View {
        VStack(spacing: 0) {
            // Заголовок таблицы
            HStack {
                Text(selectedTab.title.uppercased())
                    .font(Typography.Headline.small)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                Spacer()
            }
            .background(getTabColor())
            .cornerRadius(CornerRadius.small, corners: [.topLeft, .topRight])
            
            // Заголовки колонок
            HStack {
                Text("Дата")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 80, alignment: .leading)
                
                Text("Статья " + (selectedTab == .expenses ? "расходов" : "поступлений"))
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Сумма")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                Text("Примечание")
                    .font(Typography.Body.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.secondary)
                    .frame(width: 100, alignment: .leading)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorPalette.Background.secondary)
            
            // Строки таблицы
            LazyVStack(spacing: 0) {
                ForEach(getFilteredTransactions(), id: \.id) { transaction in
                    DailyTransactionRow(transaction: transaction)
                }
                
                if getFilteredTransactions().isEmpty {
                    emptyStateRow
                }
            }
        }
        .background(ColorPalette.Background.primary)
        .cornerRadius(CornerRadius.medium)
        .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Empty State Row
    
    private var emptyStateRow: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: selectedTab == .expenses ? "minus.circle" : "plus.circle")
                .font(.system(size: 40))
                .foregroundColor(ColorPalette.Text.tertiary)
            
            Text("Нет записей за выбранный день")
                .font(Typography.Body.medium)
                .foregroundColor(ColorPalette.Text.secondary)
            
            Text("Добавьте первую " + (selectedTab == .expenses ? "трату" : "поступление"))
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.tertiary)
        }
        .padding(.all, Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(ColorPalette.Background.primary)
    }
    
    // MARK: - Add Transaction Button
    
    private var addTransactionButton: some View {
        Button(action: {
            showingAddTransaction = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text("Добавить " + (selectedTab == .expenses ? "трату" : "поступление"))
                    .font(Typography.Body.medium)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(ColorPalette.Primary.main)
            .cornerRadius(CornerRadius.medium)
            .shadow(color: ColorPalette.Shadow.light, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func getTabColor() -> Color {
        switch selectedTab {
        case .expenses:
            return Color.red.opacity(0.7)
        case .income:
            return Color.green.opacity(0.7)
        }
    }
    
    private func getFilteredTransactions() -> [DailyTransaction] {
        let transactions = selectedTab == .expenses ? viewModel.dailyExpenses : viewModel.dailyIncome
        let calendar = Calendar.current
        
        return transactions.filter { transaction in
            calendar.isDate(transaction.date, inSameDayAs: selectedDate)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
    
    private func getTransactionsSummary() -> String {
        let transactions = getFilteredTransactions()
        let total = transactions.reduce(0) { $0 + $1.amount }
        let count = transactions.count
        
        if count == 0 {
            return "Нет операций"
        }
        
        return "\(count) операций • \(formatCurrency(total))"
    }
}

// MARK: - Daily Transaction Row

struct DailyTransactionRow: View {
    let transaction: DailyTransaction
    
    var body: some View {
        HStack {
            Text(formatDate(transaction.date))
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(width: 80, alignment: .leading)
            
            Text(transaction.category)
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(formatCurrency(transaction.amount))
                .font(Typography.Body.small)
                .fontWeight(.medium)
                .foregroundColor(transaction.type == .expense ? ColorPalette.Financial.expense : ColorPalette.Financial.income)
                .frame(width: 80, alignment: .trailing)
            
            Text(transaction.description ?? "")
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Text.secondary)
                .frame(width: 100, alignment: .leading)
                .lineLimit(2)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
    }
}

// MARK: - Date Picker View

struct DatePickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Выберите дату",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding()
                
                Spacer()
                
                Button("Готово") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(PrimaryButton())
                .padding()
            }
            .navigationTitle("Выбор даты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Add Daily Transaction View

struct AddDailyTransactionView: View {
    @ObservedObject var viewModel: BudgetPlannerViewModel
    let selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: String = ""
    @State private var category: String = ""
    @State private var description: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var selectedCategories: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Тип операции")) {
                    Picker("Тип", selection: $transactionType) {
                        Text("Расход").tag(TransactionType.expense)
                        Text("Доход").tag(TransactionType.income)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Сумма")) {
                    TextField("Введите сумму", text: $amount)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Категория")) {
                    TextField("Введите категорию", text: $category)
                    
                    if !selectedCategories.isEmpty {
                        ForEach(selectedCategories, id: \.self) { cat in
                            Button(cat) {
                                category = cat
                            }
                        }
                    }
                }
                
                Section(header: Text("Описание")) {
                    TextField("Примечание (необязательно)", text: $description)
                }
                
                Section(header: Text("Дата")) {
                    HStack {
                        Text("Дата операции")
                        Spacer()
                        Text(formatDate(selectedDate))
                            .foregroundColor(ColorPalette.Text.secondary)
                    }
                }
            }
            .navigationTitle("Добавить операцию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveTransaction()
                    }
                    .disabled(amount.isEmpty || category.isEmpty)
                }
            }
        }
        .onAppear {
            setupCategories()
        }
    }
    
    private func setupCategories() {
        if transactionType == .expense {
            selectedCategories = [
                "Еда и напитки",
                "Транспорт",
                "Развлечения",
                "Жилье",
                "Здоровье",
                "Одежда",
                "Образование",
                "Прочее"
            ]
        } else {
            selectedCategories = [
                "Зарплата",
                "Фриланс",
                "Подарки",
                "Возврат",
                "Прочее"
            ]
        }
    }
    
    private func saveTransaction() {
        guard let decimalAmount = Decimal(string: amount) else { return }
        
        Task {
            await viewModel.addDailyTransaction(
                date: selectedDate,
                category: category,
                amount: decimalAmount,
                description: description.isEmpty ? nil : description,
                type: transactionType
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        DailyTransactionsView(viewModel: BudgetPlannerViewModel(
            financeService: ServiceContainer.shared.financeService,
            transactionRepository: ServiceContainer.shared.transactionRepository,
            dataService: ServiceContainer.shared.dataService
        ))
    }
} 