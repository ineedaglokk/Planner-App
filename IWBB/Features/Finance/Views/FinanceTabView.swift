//
//  FinanceTabView.swift
//  IWBB
//
//  Created by AI Assistant
//  Основной экран финансов
//

import SwiftUI

struct FinanceTabView: View {
    
    @StateObject private var viewModel = FinanceOverviewViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    // Балансовая карточка
                    BalanceCardView(
                        balance: viewModel.state.currentBalance,
                        change: viewModel.state.balanceChange,
                        period: viewModel.input.selectedPeriod
                    )
                    .padding(.horizontal, Spacing.screenPadding)
                    
                    // Быстрые действия
                    QuickActionsSection()
                        .padding(.horizontal, Spacing.screenPadding)
                    
                    // Последние транзакции
                    if !viewModel.state.recentTransactions.isEmpty {
                        RecentTransactionsSection(transactions: viewModel.state.recentTransactions)
                            .padding(.horizontal, Spacing.screenPadding)
                    }
                    
                    // Статистика по категориям
                    if !viewModel.state.categoryStats.isEmpty {
                        CategoryStatsSection(stats: viewModel.state.categoryStats)
                            .padding(.horizontal, Spacing.screenPadding)
                    }
                }
                .padding(.top, Spacing.lg)
            }
            .navigationTitle("Финансы")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Spacing.md) {
                        // Период выбора
                        Menu {
                            ForEach(FinancePeriod.allCases, id: \.self) { period in
                                Button(period.title) {
                                    viewModel.input.selectedPeriod = period
                                }
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Text(viewModel.input.selectedPeriod.title)
                                    .font(Typography.Body.small)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(ColorPalette.Primary.main)
                        }
                        
                        // Добавить транзакцию
                        Button {
                            // TODO: Navigate to add transaction
                        } label {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(ColorPalette.Primary.main)
                        }
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
        .onChange(of: viewModel.input.selectedPeriod) { _, _ in
            Task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Быстрые действия")
                .font(Typography.Headline.small)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.Text.primary)
            
            HStack(spacing: Spacing.md) {
                QuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Доход",
                    color: ColorPalette.Financial.income
                ) {
                    // TODO: Navigate to add income
                }
                
                QuickActionButton(
                    icon: "minus.circle.fill",
                    title: "Расход",
                    color: ColorPalette.Financial.expense
                ) {
                    // TODO: Navigate to add expense
                }
                
                QuickActionButton(
                    icon: "arrow.left.arrow.right.circle.fill",
                    title: "Перевод",
                    color: ColorPalette.Primary.main
                ) {
                    // TODO: Navigate to transfer
                }
                
                QuickActionButton(
                    icon: "chart.bar.fill",
                    title: "Отчеты",
                    color: ColorPalette.Secondary.main
                ) {
                    // TODO: Navigate to reports
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(Typography.Caption.medium)
                    .foregroundColor(ColorPalette.Text.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(ColorPalette.Background.secondary)
            .cornerRadius(CornerRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Transactions Section
struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Последние операции")
                    .font(Typography.Headline.small)
                    .fontWeight(.semibold)
                    .foregroundColor(ColorPalette.Text.primary)
                
                Spacer()
                
                Button("Все") {
                    // TODO: Navigate to all transactions
                }
                .font(Typography.Body.small)
                .foregroundColor(ColorPalette.Primary.main)
            }
            
            LazyVStack(spacing: Spacing.sm) {
                ForEach(transactions.prefix(5)) { transaction in
                    TransactionRowView(transaction: transaction)
                        .onTapGesture {
                            // TODO: Navigate to transaction detail
                        }
                }
            }
        }
    }
}

// MARK: - Category Stats Section
struct CategoryStatsSection: View {
    let stats: [CategoryStatistic]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Расходы по категориям")
                .font(Typography.Headline.small)
                .fontWeight(.semibold)
                .foregroundColor(ColorPalette.Text.primary)
            
            LazyVStack(spacing: Spacing.sm) {
                ForEach(stats.prefix(5)) { stat in
                    CategoryStatRowView(stat: stat)
                }
            }
        }
    }
}

struct CategoryStatRowView: View {
    let stat: CategoryStatistic
    
    var body: some View {
        HStack {
            // Иконка категории
            Image(systemName: stat.category.icon)
                .font(.title3)
                .foregroundColor(Color(hex: stat.category.color))
                .frame(width: 24, height: 24)
            
            // Название категории
            Text(stat.category.name)
                .font(Typography.Body.medium)
                .foregroundColor(ColorPalette.Text.primary)
            
            Spacer()
            
            // Сумма
            Text(stat.amount.currencyFormatted)
                .font(Typography.Body.medium)
                .fontWeight(.medium)
                .foregroundColor(ColorPalette.Text.primary)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Preview
#Preview {
    FinanceTabView()
} 