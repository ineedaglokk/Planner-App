import SwiftUI

// MARK: - Amount Input View

struct AmountInputView: View {
    
    // MARK: - Properties
    
    @Binding var amount: Decimal
    let quickAmounts: [Decimal]
    let currency: String
    let onAmountChanged: ((Decimal) -> Void)?
    
    @State private var amountText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isAmountFocused: Bool
    
    // Styling
    let style: AmountInputStyle
    
    // MARK: - Initialization
    
    init(
        amount: Binding<Decimal>,
        quickAmounts: [Decimal] = [100, 500, 1000, 2000, 5000],
        currency: String = "RUB",
        style: AmountInputStyle = .default,
        onAmountChanged: ((Decimal) -> Void)? = nil
    ) {
        self._amount = amount
        self.quickAmounts = quickAmounts
        self.currency = currency
        self.style = style
        self.onAmountChanged = onAmountChanged
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: style.spacing) {
            // Header
            headerView
            
            // Main amount input
            mainAmountInput
            
            // Quick amount buttons
            if style.showQuickAmounts && !quickAmounts.isEmpty {
                quickAmountButtons
            }
            
            // Helper text
            if let helperText = style.helperText {
                helperTextView(helperText)
            }
        }
        .onAppear {
            updateAmountText()
        }
        .onChange(of: amount) { _, newValue in
            if !isEditing {
                updateAmountText()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            if let title = style.title {
                Text(title)
                    .font(style.titleFont)
                    .foregroundColor(Theme.colors.textPrimary)
            }
            
            Spacer()
            
            if style.showCurrency {
                currencyBadge
            }
        }
    }
    
    private var currencyBadge: some View {
        Text(currency)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(Theme.colors.primary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.colors.primary.opacity(0.1))
            )
    }
    
    // MARK: - Main Amount Input
    
    private var mainAmountInput: some View {
        HStack(spacing: Spacing.sm) {
            // Amount text field
            TextField(style.placeholder, text: $amountText)
                .textFieldStyle(AmountTextFieldStyle(style: style))
                .keyboardType(.numberPad)
                .focused($isAmountFocused)
                .multilineTextAlignment(style.textAlignment)
                .onChange(of: amountText) { _, newValue in
                    handleAmountTextChange(newValue)
                }
                .onChange(of: isAmountFocused) { _, focused in
                    isEditing = focused
                    if !focused {
                        formatAmountText()
                    }
                }
            
            // Currency symbol (if inline)
            if style.currencyPosition == .inline {
                Text(getCurrencySymbol())
                    .font(style.amountFont)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.colors.textSecondary)
            }
        }
    }
    
    // MARK: - Quick Amount Buttons
    
    private var quickAmountButtons: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if style.showQuickAmountsTitle {
                Text("Быстрый выбор")
                    .font(.caption)
                    .foregroundColor(Theme.colors.textSecondary)
            }
            
            quickAmountGrid
        }
    }
    
    private var quickAmountGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: style.quickAmountColumns),
            spacing: Spacing.xs
        ) {
            ForEach(quickAmounts, id: \.self) { quickAmount in
                quickAmountButton(quickAmount)
            }
        }
    }
    
    private func quickAmountButton(_ quickAmount: Decimal) -> some View {
        Button {
            selectQuickAmount(quickAmount)
        } label: {
            Text(formatQuickAmount(quickAmount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(amount == quickAmount ? .white : Theme.colors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(amount == quickAmount ? Theme.colors.primary : Theme.colors.primary.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Text
    
    private func helperTextView(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(Theme.colors.textTertiary)
    }
    
    // MARK: - Private Methods
    
    private func handleAmountTextChange(_ newValue: String) {
        let cleanValue = cleanAmountText(newValue)
        
        // Обновляем текст только если он изменился
        if cleanValue != amountText {
            amountText = cleanValue
        }
        
        if let decimal = Decimal(string: cleanValue) {
            amount = decimal
            onAmountChanged?(decimal)
        } else if cleanValue.isEmpty {
            amount = 0
            onAmountChanged?(0)
        }
    }
    
    private func cleanAmountText(_ text: String) -> String {
        // Разрешаем только цифры, точки и запятые
        let filtered = text.filter { char in
            return char.isNumber || char == "." || char == ","
        }
        
        // Заменяем запятые на точки
        let dotNormalized = filtered.replacingOccurrences(of: ",", with: ".")
        
        // Убираем дублирующиеся точки
        let components = dotNormalized.components(separatedBy: ".")
        if components.count > 2 {
            return components[0] + "." + components[1]
        }
        
        // Ограничиваем количество знаков после точки
        if components.count == 2 {
            let beforeDot = components[0]
            let afterDot = String(components[1].prefix(2))
            return beforeDot + "." + afterDot
        }
        
        return dotNormalized
    }
    
    private func updateAmountText() {
        if amount == 0 {
            amountText = ""
        } else {
            amountText = formatAmount(amount)
        }
    }
    
    private func formatAmountText() {
        guard amount > 0 else {
            amountText = ""
            return
        }
        
        amountText = formatAmount(amount)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = style.useGroupingSeparator ? " " : ""
        formatter.decimalSeparator = ","
        
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
    }
    
    private func formatQuickAmount(_ amount: Decimal) -> String {
        if amount >= 1000 {
            let thousands = amount / 1000
            return "\(Int(thousands))K"
        } else {
            return "\(Int(amount))"
        }
    }
    
    private func selectQuickAmount(_ quickAmount: Decimal) {
        amount = quickAmount
        amountText = formatAmount(quickAmount)
        isAmountFocused = false
        onAmountChanged?(quickAmount)
    }
    
    private func getCurrencySymbol() -> String {
        switch currency {
        case "RUB": return "₽"
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return currency
        }
    }
}

// MARK: - Amount Text Field Style

struct AmountTextFieldStyle: TextFieldStyle {
    let style: AmountInputStyle
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(style.amountFont)
            .foregroundColor(Theme.colors.textPrimary)
            .padding(style.inputPadding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .stroke(style.borderColor, lineWidth: style.borderWidth)
                    )
            )
    }
}

// MARK: - Amount Input Style

struct AmountInputStyle {
    let title: String?
    let placeholder: String
    let titleFont: Font
    let amountFont: Font
    let textAlignment: TextAlignment
    let spacing: CGFloat
    let inputPadding: EdgeInsets
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: Color
    let backgroundColor: Color
    let showQuickAmounts: Bool
    let showQuickAmountsTitle: Bool
    let quickAmountColumns: Int
    let showCurrency: Bool
    let currencyPosition: CurrencyPosition
    let useGroupingSeparator: Bool
    let helperText: String?
    
    enum CurrencyPosition {
        case inline
        case badge
        case hidden
    }
    
    static let `default` = AmountInputStyle(
        title: "Сумма",
        placeholder: "0",
        titleFont: .headline,
        amountFont: .title2,
        textAlignment: .trailing,
        spacing: Spacing.md,
        inputPadding: EdgeInsets(top: Spacing.md, leading: Spacing.md, bottom: Spacing.md, trailing: Spacing.md),
        cornerRadius: 12,
        borderWidth: 1,
        borderColor: Theme.colors.surface,
        backgroundColor: Theme.colors.background,
        showQuickAmounts: true,
        showQuickAmountsTitle: true,
        quickAmountColumns: 5,
        showCurrency: true,
        currencyPosition: .badge,
        useGroupingSeparator: true,
        helperText: nil
    )
    
    static let compact = AmountInputStyle(
        title: nil,
        placeholder: "Сумма",
        titleFont: .subheadline,
        amountFont: .headline,
        textAlignment: .trailing,
        spacing: Spacing.sm,
        inputPadding: EdgeInsets(top: Spacing.sm, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm),
        cornerRadius: 8,
        borderWidth: 1,
        borderColor: Theme.colors.surface,
        backgroundColor: Theme.colors.background,
        showQuickAmounts: false,
        showQuickAmountsTitle: false,
        quickAmountColumns: 3,
        showCurrency: true,
        currencyPosition: .inline,
        useGroupingSeparator: false,
        helperText: nil
    )
    
    static let large = AmountInputStyle(
        title: "Введите сумму",
        placeholder: "0,00",
        titleFont: .title3,
        amountFont: .largeTitle,
        textAlignment: .center,
        spacing: Spacing.lg,
        inputPadding: EdgeInsets(top: Spacing.lg, leading: Spacing.lg, bottom: Spacing.lg, trailing: Spacing.lg),
        cornerRadius: 16,
        borderWidth: 2,
        borderColor: Theme.colors.primary.opacity(0.3),
        backgroundColor: Theme.colors.background,
        showQuickAmounts: true,
        showQuickAmountsTitle: true,
        quickAmountColumns: 5,
        showCurrency: true,
        currencyPosition: .badge,
        useGroupingSeparator: true,
        helperText: "Нажмите на кнопки для быстрого выбора суммы"
    )
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.xl) {
        // Default style
        AmountInputView(
            amount: .constant(1500),
            quickAmounts: [100, 500, 1000, 2000, 5000],
            currency: "RUB"
        )
        
        Divider()
        
        // Compact style
        AmountInputView(
            amount: .constant(250),
            style: .compact
        )
        
        Divider()
        
        // Large style
        AmountInputView(
            amount: .constant(0),
            style: .large
        )
    }
    .padding()
    .background(Theme.colors.background)
}

// MARK: - View Extensions

extension AmountInputView {
    
    /// Создает компактную версию для использования в формах
    static func compact(
        amount: Binding<Decimal>,
        currency: String = "RUB",
        onAmountChanged: ((Decimal) -> Void)? = nil
    ) -> some View {
        AmountInputView(
            amount: amount,
            currency: currency,
            style: .compact,
            onAmountChanged: onAmountChanged
        )
    }
    
    /// Создает крупную версию для главных экранов
    static func large(
        amount: Binding<Decimal>,
        quickAmounts: [Decimal] = [100, 500, 1000, 2000, 5000],
        currency: String = "RUB",
        onAmountChanged: ((Decimal) -> Void)? = nil
    ) -> some View {
        AmountInputView(
            amount: amount,
            quickAmounts: quickAmounts,
            currency: currency,
            style: .large,
            onAmountChanged: onAmountChanged
        )
    }
} 