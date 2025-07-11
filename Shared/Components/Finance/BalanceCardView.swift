//
//  BalanceCardView.swift
//  IWBB
//
//  Created by AI Assistant
//  Карточка баланса для финансового раздела
//

import SwiftUI

struct BalanceCardView: View {
    let balance: Decimal
    let change: Decimal
    let period: FinancePeriod
    
    @State private var animatedBalance: Double = 0
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Заголовок
            HStack {
                Text("Общий баланс")
                    .font(Typography.Body.medium)
                    .foregroundColor(ColorPalette.Text.secondary)
                
                Spacer()
                
                Text(period.title)
                    .font(Typography.Caption.medium)
                    .foregroundColor(ColorPalette.Text.tertiary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(ColorPalette.Background.tertiary)
                    .cornerRadius(CornerRadius.small)
            }
            
            // Сумма баланса
            VStack(spacing: Spacing.xs) {
                Text(balance.currencyFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ColorPalette.Text.primary)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            animatedBalance = balance.doubleValue
                        }
                    }
                
                // Изменение за период
                if change != 0 {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(change.currencyFormatted)
                            .font(Typography.Body.small)
                            .fontWeight(.medium)
                        
                        Text("за \(period.shortTitle)")
                            .font(Typography.Caption.medium)
                    }
                    .foregroundColor(change > 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense)
                }
            }
            
            // Быстрая статистика
            HStack(spacing: 0) {
                QuickStatView(
                    title: "Доходы",
                    amount: abs(change > 0 ? change : 0),
                    color: ColorPalette.Financial.income
                )
                
                Divider()
                    .frame(height: 40)
                    .foregroundColor(ColorPalette.Border.main)
                
                QuickStatView(
                    title: "Расходы",
                    amount: abs(change < 0 ? change : 0),
                    color: ColorPalette.Financial.expense
                )
            }
            .padding(.top, Spacing.md)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(ColorPalette.Background.secondary)
                .shadow(color: ColorPalette.Shadow.light, radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Quick Stat View
struct QuickStatView: View {
    let title: String
    let amount: Decimal
    let color: Color
    
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(Typography.Caption.medium)
                .foregroundColor(ColorPalette.Text.secondary)
            
            Text(amount.currencyFormatted)
                .font(Typography.Body.medium)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Extensions
extension FinancePeriod {
    var shortTitle: String {
        switch self {
        case .week:
            return "неделю"
        case .month:
            return "месяц"
        case .quarter:
            return "квартал"
        case .year:
            return "год"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Spacing.lg) {
        BalanceCardView(
            balance: 125000.50,
            change: 15000.25,
            period: .month
        )
        
        BalanceCardView(
            balance: 85000.75,
            change: -5000.00,
            period: .week
        )
    }
    .padding()
    .background(ColorPalette.Background.primary)
} 