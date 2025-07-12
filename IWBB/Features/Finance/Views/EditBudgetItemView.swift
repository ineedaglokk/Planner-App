import SwiftUI

struct EditBudgetItemView: View {
    let item: BudgetPlanItem
    @ObservedObject var viewModel: BudgetPlannerViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var plannedAmount: String = ""
    @State private var actualAmount: String = ""
    @State private var itemName: String = ""
    @State private var itemDescription: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Информация о статье")) {
                    TextField("Название", text: $itemName)
                    TextField("Описание (необязательно)", text: $itemDescription)
                }
                
                Section(header: Text("Суммы")) {
                    HStack {
                        Text("Плановая сумма")
                        Spacer()
                        TextField("0", text: $plannedAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Фактическая сумма")
                        Spacer()
                        TextField("0", text: $actualAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Статистика")) {
                    HStack {
                        Text("Тип")
                        Spacer()
                        Text(item.type.displayName)
                            .foregroundColor(ColorPalette.Text.secondary)
                    }
                    
                    if let plannedDecimal = Decimal(string: plannedAmount),
                       let actualDecimal = Decimal(string: actualAmount),
                       plannedDecimal > 0 {
                        HStack {
                            Text("Выполнение")
                            Spacer()
                            Text("\(Int((actualDecimal / plannedDecimal) * 100))%")
                                .foregroundColor(getCompletionColor(actual: actualDecimal, planned: plannedDecimal))
                        }
                        
                        HStack {
                            Text("Отклонение")
                            Spacer()
                            Text(formatVariance(actual: actualDecimal, planned: plannedDecimal))
                                .foregroundColor(getVarianceColor(actual: actualDecimal, planned: plannedDecimal))
                        }
                    }
                }
            }
            .navigationTitle("Редактировать статью")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        saveChanges()
                    }
                    .disabled(itemName.isEmpty)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        itemName = item.name
        itemDescription = item.description ?? ""
        plannedAmount = item.plannedAmount.description
        actualAmount = item.actualAmount.description
    }
    
    private func saveChanges() {
        guard let plannedDecimal = Decimal(string: plannedAmount),
              let actualDecimal = Decimal(string: actualAmount) else { return }
        
        Task {
            await viewModel.updateBudgetPlanItem(
                item,
                plannedAmount: plannedDecimal,
                actualAmount: actualDecimal
            )
            
            await MainActor.run {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func getCompletionColor(actual: Decimal, planned: Decimal) -> Color {
        let percentage = Double(actual / planned) * 100
        
        if percentage >= 100 {
            return ColorPalette.Financial.income
        } else if percentage >= 80 {
            return .blue
        } else if percentage >= 50 {
            return .orange
        } else {
            return ColorPalette.Financial.expense
        }
    }
    
    private func getVarianceColor(actual: Decimal, planned: Decimal) -> Color {
        let variance = actual - planned
        
        if item.type == .income {
            return variance >= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense
        } else {
            return variance <= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense
        }
    }
    
    private func formatVariance(actual: Decimal, planned: Decimal) -> String {
        let variance = actual - planned
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = viewModel.selectedCurrency
        formatter.locale = Locale(identifier: "ru_RU")
        
        let formattedAmount = formatter.string(from: NSDecimalNumber(decimal: abs(variance))) ?? "0 ₽"
        return variance >= 0 ? "+\(formattedAmount)" : "-\(formattedAmount)"
    }
}

// MARK: - Preview
#Preview {
    EditBudgetItemView(
        item: BudgetPlanItem(name: "Зарплата", type: .income, plannedAmount: 100000, actualAmount: 95000),
        viewModel: BudgetPlannerViewModel(
            financeService: ServiceContainer.shared.financeService,
            transactionRepository: ServiceContainer.shared.transactionRepository,
            dataService: ServiceContainer.shared.dataService
        )
    )
} 