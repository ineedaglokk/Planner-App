//
//  BalanceCardView.swift
//  IWBB
//
//  Created by AI Assistant
//  Карточка баланса для финансового раздела
//

import SwiftUI

// MARK: - Balance Card View

struct BalanceCardView: View {
    let balance: Decimal
    let change: Decimal
    let period: FinancePeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Заголовок
            HStack {
                Text("Баланс")
                    .font(Typography.Title.medium)
                    .foregroundColor(ColorPalette.Text.secondary)
                
                Spacer()
                
                Text(period.title)
                    .font(Typography.Caption.regular)
                    .foregroundColor(ColorPalette.Text.tertiary)
            }
            
            // Основная сумма
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(formatCurrency(balance))
                    .font(Typography.Display.small)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.Text.primary)
                
                // Изменение
                HStack(spacing: Spacing.xs) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundColor(change >= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense)
                    
                    Text(formatCurrency(abs(change)))
                        .font(Typography.Body.small)
                        .foregroundColor(change >= 0 ? ColorPalette.Financial.income : ColorPalette.Financial.expense)
                    
                    Text("за период")
                        .font(Typography.Body.small)
                        .foregroundColor(ColorPalette.Text.tertiary)
                }
            }
        }
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [ColorPalette.Primary.main, ColorPalette.Primary.dark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(CornerRadius.xl)
        .shadow(color: ColorPalette.Primary.main.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₽0"
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Иконка категории
            Circle()
                .fill(ColorPalette.Background.surface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: transaction.category?.icon ?? "dollarsign.circle")
                        .font(.title3)
                        .foregroundColor(ColorPalette.Primary.main)
                )
            
            // Информация о транзакции
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(transaction.title)
                    .font(Typography.Body.medium)
                    .foregroundColor(ColorPalette.Text.primary)
                    .lineLimit(1)
                
                if let description = transaction.description {
                    Text(description)
                        .font(Typography.Caption.regular)
                        .foregroundColor(ColorPalette.Text.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Сумма
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(transaction.signedFormattedAmount)
                    .font(Typography.Body.medium)
                    .fontWeight(.medium)
                    .foregroundColor(
                        transaction.type == .income ? ColorPalette.Financial.income : ColorPalette.Financial.expense
                    )
                
                Text(DateFormatter.shortDate.string(from: transaction.date))
                    .font(Typography.Caption.regular)
                    .foregroundColor(ColorPalette.Text.tertiary)
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Supporting Types

enum FinancePeriod: String, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    
    var title: String {
        switch self {
        case .week: return "Неделя"
        case .month: return "Месяц"
        case .year: return "Год"
        }
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

// MARK: - Decimal Extension

extension Decimal {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "₽0"
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        BalanceCardView(
            balance: 125000,
            change: 5000,
            period: .month
        )
        
        TransactionRowView(
            transaction: Transaction(
                amount: 1250,
                type: .expense,
                title: "Продукты",
                description: "Покупка в магазине"
            )
        )
    }
    .padding()
    .background(ColorPalette.Background.primary)
} 