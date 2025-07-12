import SwiftUI

// MARK: - MonthlySummaryTableView

struct MonthlySummaryTableView: View {
    let summaries: [MonthlySummary]
    let tableType: TableType
    
    enum TableType {
        case expenses
        case income
        case savings
        
        var title: String {
            switch self {
            case .expenses: return "Расходы по месяцам"
            case .income: return "Доходы по месяцам"
            case .savings: return "Накопления по месяцам"
            }
        }
        
        var emptyMessage: String {
            switch self {
            case .expenses: return "Записей о расходах пока нет"
            case .income: return "Записей о доходах пока нет"
            case .savings: return "Данных о накоплениях пока нет"
            }
        }
        
        var icon: String {
            switch self {
            case .expenses: return "arrow.down.circle"
            case .income: return "arrow.up.circle"
            case .savings: return "banknote.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .expenses: return .red
            case .income: return .green
            case .savings: return .blue
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок таблицы
            HStack {
                Image(systemName: tableType.icon)
                    .font(.title2)
                    .foregroundColor(tableType.color)
                
                Text(tableType.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !summaries.isEmpty {
                    Text("\(summaries.count) месяцев")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Таблица или пустое состояние
            if summaries.isEmpty {
                EmptyTableView(
                    message: tableType.emptyMessage,
                    icon: tableType.icon,
                    color: tableType.color
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(summaries) { summary in
                        MonthlySummaryRowView(
                            summary: summary,
                            tableType: tableType
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - MonthlySummaryRowView

struct MonthlySummaryRowView: View {
    let summary: MonthlySummary
    let tableType: MonthlySummaryTableView.TableType
    
    var body: some View {
        HStack {
            // Месяц
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.monthDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(summary.month)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Сумма
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(amountColor)
                
                // Дополнительная информация для накоплений
                if tableType == .savings {
                    Text(summary.formattedSavingsRate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var formattedAmount: String {
        switch tableType {
        case .expenses:
            return summary.formattedTotalExpenses
        case .income:
            return summary.formattedTotalIncome
        case .savings:
            return summary.formattedTotalSavings
        }
    }
    
    private var amountColor: Color {
        switch tableType {
        case .expenses:
            return .red
        case .income:
            return .green
        case .savings:
            return summary.totalSavings >= 0 ? .green : .red
        }
    }
}

// MARK: - EmptyTableView

struct EmptyTableView: View {
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(color.opacity(0.3))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Добавьте первую запись, чтобы увидеть данные")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DetailedExpenseTableView

struct DetailedExpenseTableView: View {
    let expenses: [ExpenseEntry]
    let onDelete: (ExpenseEntry) -> Void
    let onEdit: (ExpenseEntry) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text("Записи расходов")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !expenses.isEmpty {
                    Text("\(expenses.count) записей")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Таблица
            if expenses.isEmpty {
                EmptyTableView(
                    message: "Записей о расходах пока нет",
                    icon: "list.bullet",
                    color: .red
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(expenses) { expense in
                        ExpenseRowView(
                            expense: expense,
                            onDelete: { onDelete(expense) },
                            onEdit: { onEdit(expense) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - DetailedIncomeTableView

struct DetailedIncomeTableView: View {
    let incomes: [IncomeEntry]
    let onDelete: (IncomeEntry) -> Void
    let onEdit: (IncomeEntry) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Записи поступлений")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !incomes.isEmpty {
                    Text("\(incomes.count) записей")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Таблица
            if incomes.isEmpty {
                EmptyTableView(
                    message: "Записей о поступлениях пока нет",
                    icon: "list.bullet",
                    color: .green
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(incomes) { income in
                        IncomeRowView(
                            income: income,
                            onDelete: { onDelete(income) },
                            onEdit: { onEdit(income) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - ExpenseRowView

struct ExpenseRowView: View {
    let expense: ExpenseEntry
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(expense.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = expense.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - IncomeRowView

struct IncomeRowView: View {
    let income: IncomeEntry
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(income.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(income.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = income.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(income.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Previews

#Preview("Monthly Tables") {
    ScrollView {
        VStack(spacing: 20) {
            MonthlySummaryTableView(
                summaries: [
                    MonthlySummary(month: "2024-01"),
                    MonthlySummary(month: "2024-02"),
                    MonthlySummary(month: "2024-03")
                ],
                tableType: .expenses
            )
            
            MonthlySummaryTableView(
                summaries: [],
                tableType: .income
            )
            
            MonthlySummaryTableView(
                summaries: [
                    MonthlySummary(month: "2024-01"),
                    MonthlySummary(month: "2024-02")
                ],
                tableType: .savings
            )
        }
        .padding()
    }
}

#Preview("Detailed Tables") {
    ScrollView {
        VStack(spacing: 20) {
            DetailedExpenseTableView(
                expenses: [],
                onDelete: { _ in },
                onEdit: { _ in }
            )
            
            DetailedIncomeTableView(
                incomes: [],
                onDelete: { _ in },
                onEdit: { _ in }
            )
        }
        .padding()
    }
} 