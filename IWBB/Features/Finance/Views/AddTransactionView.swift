//
//  AddTransactionView.swift
//  IWBB
//
//  Created by AI Assistant
//  Экран добавления новой транзакции
//

import SwiftUI

struct AddTransactionView: View {
    @ObservedObject var viewModel: BudgetPlannerViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: String = ""
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var selectedCategory: String = ""
    @State private var transactionDate = Date()
    @State private var selectedAccount: String = "Основной"
    @State private var paymentMethod: PaymentMethod = .card
    
    private let accounts = ["Основной", "Сбережения", "Наличные", "Карта"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Тип операции")) {
                    Picker("Тип", selection: $transactionType) {
                        Text("Расход").tag(TransactionType.expense)
                        Text("Доход").tag(TransactionType.income)
                        Text("Перевод").tag(TransactionType.transfer)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Основная информация")) {
                    TextField("Название операции", text: $title)
                    
                    HStack {
                        Text("Сумма")
                        Spacer()
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(viewModel.selectedCurrency)
                            .foregroundColor(ColorPalette.Text.secondary)
                    }
                    
                    TextField("Описание (необязательно)", text: $description)
                }
                
                Section(header: Text("Категория")) {
                    Menu {
                        ForEach(getAvailableCategories(), id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Text("Категория")
                            Spacer()
                            Text(selectedCategory.isEmpty ? "Выберите категорию" : selectedCategory)
                                .foregroundColor(selectedCategory.isEmpty ? ColorPalette.Text.tertiary : ColorPalette.Text.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                }
                
                Section(header: Text("Дополнительная информация")) {
                    DatePicker("Дата операции", selection: $transactionDate, displayedComponents: .date)
                    
                    Menu {
                        ForEach(accounts, id: \.self) { account in
                            Button(account) {
                                selectedAccount = account
                            }
                        }
                    } label: {
                        HStack {
                            Text("Счет")
                            Spacer()
                            Text(selectedAccount)
                                .foregroundColor(ColorPalette.Text.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                    }
                    
                    Picker("Способ оплаты", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                }
                
                if !amount.isEmpty, let amountDecimal = Decimal(string: amount) {
                    Section(header: Text("Предварительный просмотр")) {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(title.isEmpty ? "Новая операция" : title)
                                    .font(Typography.Body.medium)
                                    .foregroundColor(ColorPalette.Text.primary)
                                
                                Text(selectedCategory.isEmpty ? "Без категории" : selectedCategory)
                                    .font(Typography.Body.small)
                                    .foregroundColor(ColorPalette.Text.secondary)
                                
                                Text(formatDate(transactionDate))
                                    .font(Typography.Body.small)
                                    .foregroundColor(ColorPalette.Text.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatAmount(amountDecimal))
                                .font(Typography.Body.medium)
                                .fontWeight(.semibold)
                                .foregroundColor(getAmountColor())
                        }
                        .padding(.vertical, Spacing.xs)
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
                    .disabled(!isValidTransaction())
                }
            }
        }
        .onAppear {
            setupDefaultCategory()
        }
        .onChange(of: transactionType) { _, _ in
            setupDefaultCategory()
        }
    }
    
    private func getAvailableCategories() -> [String] {
        switch transactionType {
        case .income:
            return [
                "Зарплата",
                "Фриланс",
                "Бизнес",
                "Дивиденды",
                "Подарки",
                "Возврат",
                "Продажа",
                "Прочие доходы"
            ]
        case .expense:
            return [
                "Продукты",
                "Транспорт",
                "Жилье",
                "Коммунальные услуги",
                "Связь",
                "Развлечения",
                "Одежда",
                "Здоровье",
                "Образование",
                "Кафе и рестораны",
                "Покупки",
                "Прочие расходы"
            ]
        case .transfer:
            return [
                "Перевод между счетами",
                "Пополнение счета",
                "Снятие наличных",
                "Инвестиции"
            ]
        }
    }
    
    private func setupDefaultCategory() {
        let categories = getAvailableCategories()
        selectedCategory = categories.first ?? ""
    }
    
    private func isValidTransaction() -> Bool {
        return !title.isEmpty && 
               !amount.isEmpty && 
               Decimal(string: amount) != nil &&
               !selectedCategory.isEmpty
    }
    
    private func saveTransaction() {
        guard let amountDecimal = Decimal(string: amount) else { return }
        
        Task {
            await viewModel.addDailyTransaction(
                date: transactionDate,
                category: selectedCategory,
                amount: amountDecimal,
                description: description.isEmpty ? title : description,
                type: transactionType
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func getAmountColor() -> Color {
        switch transactionType {
        case .income:
            return ColorPalette.Financial.income
        case .expense:
            return ColorPalette.Financial.expense
        case .transfer:
            return ColorPalette.Primary.main
        }
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        
        let formattedAmount = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0 ₽"
        
        switch transactionType {
        case .income:
            return "+\(formattedAmount)"
        case .expense:
            return "-\(formattedAmount)"
        case .transfer:
            return formattedAmount
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
    AddTransactionView(viewModel: BudgetPlannerViewModel(
        financeService: ServiceContainer.shared.financeService,
        transactionRepository: ServiceContainer.shared.transactionRepository,
        dataService: ServiceContainer.shared.dataService
    ))
} 