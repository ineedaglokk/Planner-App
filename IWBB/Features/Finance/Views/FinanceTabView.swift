//
//  FinanceTabView.swift
//  IWBB
//
//  Created by AI Assistant
//  Основной экран финансов
//

import SwiftUI

struct FinanceTabView: View {
    
    @State private var viewModel = FinanceOverviewViewModel()
    @Environment(\.services) private var services
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Основные показатели
                    currentMonthSummarySection
                    
                    // Подробные таблицы записей
                    detailedTablesSection
                    
                    // Сводные месячные таблицы
                    monthlySummaryTablesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationTitle("Финансы")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Меню действий (если нужно для разработки)
                        #if DEBUG
                        Menu {
                            Button("Очистить все данные", systemImage: "trash", role: .destructive) {
                                Task {
                                    await viewModel.clearAllData()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        #endif
                        
                        // Кнопка добавления
                        Menu {
                            Button("Добавить расход", systemImage: "minus.circle") {
                                viewModel.clearExpenseForm()
                                viewModel.showAddExpenseSheet = true
                            }
                            
                            Button("Добавить доход", systemImage: "plus.circle") {
                                viewModel.clearIncomeForm()
                                viewModel.showAddIncomeSheet = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $viewModel.showAddExpenseSheet) {
                AddExpenseSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAddIncomeSheet) {
                AddIncomeSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showEditExpenseSheet) {
                EditExpenseSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showEditIncomeSheet) {
                EditIncomeSheet(viewModel: viewModel)
            }
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "Произошла неизвестная ошибка")
            }
        }
        .task {
            // Инициализируем сервис при первом запуске
            viewModel = FinanceOverviewViewModel(financeService: services.financeService)
            await viewModel.loadData()
        }
    }
    
    // MARK: - Current Month Summary Section
    
    private var currentMonthSummarySection: some View {
        VStack(spacing: 16) {
            // Заголовок
            HStack {
                Text("Текущий месяц")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(viewModel.currentMonthSummary?.monthDisplayName ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Карточки с суммами
            HStack(spacing: 12) {
                FinanceSummaryCard(
                    title: "Доходы",
                    amount: viewModel.formattedTotalIncome,
                    color: .green,
                    icon: "arrow.up.circle.fill"
                )
                
                FinanceSummaryCard(
                    title: "Расходы",
                    amount: viewModel.formattedTotalExpenses,
                    color: .red,
                    icon: "arrow.down.circle.fill"
                )
                
                FinanceSummaryCard(
                    title: "Накопления",
                    amount: viewModel.formattedTotalSavings,
                    color: viewModel.totalSavings >= 0 ? .green : .red,
                    icon: "banknote.circle.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Detailed Tables Section
    
    private var detailedTablesSection: some View {
        VStack(spacing: 20) {
            // Таблица расходов
            DetailedExpenseTableView(
                expenses: viewModel.expenseEntries,
                onDelete: { expense in
                    Task {
                        await viewModel.deleteExpenseEntry(expense)
                    }
                },
                onEdit: { expense in
                    viewModel.startEditingExpenseEntry(expense)
                }
            )
            
            // Таблица доходов
            DetailedIncomeTableView(
                incomes: viewModel.incomeEntries,
                onDelete: { income in
                    Task {
                        await viewModel.deleteIncomeEntry(income)
                    }
                },
                onEdit: { income in
                    viewModel.startEditingIncomeEntry(income)
                }
            )
        }
    }
    
    // MARK: - Monthly Summary Tables Section
    
    private var monthlySummaryTablesSection: some View {
        VStack(spacing: 20) {
            // Расходы по месяцам
            MonthlySummaryTableView(
                summaries: viewModel.monthlySummaries,
                tableType: .expenses
            )
            
            // Доходы по месяцам
            MonthlySummaryTableView(
                summaries: viewModel.monthlySummaries,
                tableType: .income
            )
            
            // Накопления по месяцам
            MonthlySummaryTableView(
                summaries: viewModel.monthlySummaries,
                tableType: .savings
            )
        }
    }
    

}

// MARK: - Finance Summary Card

struct FinanceSummaryCard: View {
    let title: String
    let amount: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(amount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Add Expense Sheet

struct AddExpenseSheet: View {
    @ObservedObject var viewModel: FinanceOverviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("Новый расход")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Название траты
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название траты")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Например: Продукты, Кафе, Транспорт", text: $viewModel.expenseEntryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Сумма
                    ValidatedAmountInputView(
                        title: "Сумма",
                        amount: $viewModel.expenseEntryAmount,
                        placeholder: "Введите сумму",
                        currency: "₽",
                        onValidationChange: viewModel.onExpenseAmountValidationChange
                    )
                    
                    // Заметки (опционально)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки (по желанию)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Дополнительная информация", text: $viewModel.expenseEntryNotes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Кнопки
                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Добавить расход",
                        icon: "plus.circle.fill",
                        action: {
                            Task {
                                await viewModel.addExpenseEntry()
                            }
                        }
                    )
                    .disabled(!viewModel.canAddExpense)
                    .foregroundColor(.white)
                    .background(viewModel.canAddExpense ? .red : .gray)
                    
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Add Income Sheet

struct AddIncomeSheet: View {
    @ObservedObject var viewModel: FinanceOverviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("Новое поступление")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Название поступления
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название поступления")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Например: Зарплата, Фриланс, Возврат", text: $viewModel.incomeEntryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Сумма
                    ValidatedAmountInputView(
                        title: "Сумма",
                        amount: $viewModel.incomeEntryAmount,
                        placeholder: "Введите сумму",
                        currency: "₽",
                        onValidationChange: viewModel.onIncomeAmountValidationChange
                    )
                    
                    // Заметки (опционально)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки (по желанию)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Дополнительная информация", text: $viewModel.incomeEntryNotes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Кнопки
                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Добавить поступление",
                        icon: "plus.circle.fill",
                        action: {
                            Task {
                                await viewModel.addIncomeEntry()
                            }
                        }
                    )
                    .disabled(!viewModel.canAddIncome)
                    .foregroundColor(.white)
                    .background(viewModel.canAddIncome ? .green : .gray)
                    
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Edit Expense Sheet

struct EditExpenseSheet: View {
    @ObservedObject var viewModel: FinanceOverviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("Редактировать расход")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Название траты
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название траты")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Например: Продукты, Кафе, Транспорт", text: $viewModel.expenseEntryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Сумма
                    ValidatedAmountInputView(
                        title: "Сумма",
                        amount: $viewModel.expenseEntryAmount,
                        placeholder: "Введите сумму",
                        currency: "₽",
                        onValidationChange: viewModel.onExpenseAmountValidationChange
                    )
                    
                    // Заметки
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Дополнительная информация", text: $viewModel.expenseEntryNotes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Кнопки
                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Сохранить изменения",
                        icon: "checkmark.circle.fill",
                        action: {
                            Task {
                                await viewModel.updateExpenseEntry()
                            }
                        }
                    )
                    .disabled(!viewModel.canAddExpense)
                    .foregroundColor(.white)
                    .background(viewModel.canAddExpense ? .blue : .gray)
                    
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Edit Income Sheet

struct EditIncomeSheet: View {
    @ObservedObject var viewModel: FinanceOverviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Заголовок
                Text("Редактировать поступление")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // Название поступления
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название поступления")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Например: Зарплата, Фриланс, Возврат", text: $viewModel.incomeEntryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Сумма
                    ValidatedAmountInputView(
                        title: "Сумма",
                        amount: $viewModel.incomeEntryAmount,
                        placeholder: "Введите сумму",
                        currency: "₽",
                        onValidationChange: viewModel.onIncomeAmountValidationChange
                    )
                    
                    // Заметки
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Заметки")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Дополнительная информация", text: $viewModel.incomeEntryNotes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(2...4)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Кнопки
                VStack(spacing: 12) {
                    PrimaryButton(
                        title: "Сохранить изменения",
                        icon: "checkmark.circle.fill",
                        action: {
                            Task {
                                await viewModel.updateIncomeEntry()
                            }
                        }
                    )
                    .disabled(!viewModel.canAddIncome)
                    .foregroundColor(.white)
                    .background(viewModel.canAddIncome ? .blue : .gray)
                    
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Preview

#Preview {
    FinanceTabView()
        .environment(\.services, ServiceContainer())
} 