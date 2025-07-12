import SwiftUI

// MARK: - ValidatedAmountInputView

struct ValidatedAmountInputView: View {
    
    // MARK: - Properties
    
    @Binding var amount: String
    @State private var isValid: Bool = true
    @State private var errorMessage: String = ""
    @State private var displayAmount: String = ""
    
    let title: String
    let placeholder: String
    let currency: String
    let onValidationChange: (Bool, Decimal?) -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Initialization
    
    init(
        title: String,
        amount: Binding<String>,
        placeholder: String = "Введите сумму",
        currency: String = "₽",
        onValidationChange: @escaping (Bool, Decimal?) -> Void
    ) {
        self.title = title
        self._amount = amount
        self.placeholder = placeholder
        self.currency = currency
        self.onValidationChange = onValidationChange
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Заголовок
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Поле ввода
            HStack {
                TextField(placeholder, text: $displayAmount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onChange(of: displayAmount) { _, newValue in
                        handleTextChange(newValue)
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if !focused {
                            formatDisplayAmount()
                        }
                    }
                    .onChange(of: amount) { _, newValue in
                        if !isTextFieldFocused {
                            syncDisplayAmount(from: newValue)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                    )
                
                // Валюта
                Text(currency)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            
            // Сообщение об ошибке
            if !isValid && !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
            
            // Подсказка
            if isValid && !displayAmount.isEmpty {
                Text(formatHint())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isValid)
        .onAppear {
            syncDisplayAmount(from: amount)
            validateAmount(amount)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleTextChange(_ newValue: String) {
        // Разрешаем только цифры, точки и запятые
        let filtered = newValue.filter { char in
            return char.isNumber || char == "." || char == ","
        }
        
        // Ограничиваем количество точек/запятых
        let normalized = normalizeDecimalInput(filtered)
        
        // Обновляем отображение только если изменилось
        if normalized != displayAmount {
            displayAmount = normalized
        }
        
        // Обновляем основное значение
        amount = normalized
        
        // Валидируем только если есть значение
        if !normalized.isEmpty {
            validateAmount(normalized)
        } else {
            // Сбрасываем состояние для пустого значения
            isValid = true
            errorMessage = ""
            onValidationChange(false, nil)
        }
    }
    
    private func normalizeDecimalInput(_ input: String) -> String {
        // Заменяем запятые на точки
        let dotNormalized = input.replacingOccurrences(of: ",", with: ".")
        
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
    
    private func syncDisplayAmount(from value: String) {
        if value != displayAmount {
            displayAmount = value
        }
    }
    
    private func formatDisplayAmount() {
        // Форматируем отображение при потере фокуса
        if let decimal = parseDecimal(from: displayAmount), decimal > 0 {
            let formatted = formatDecimal(decimal)
            displayAmount = formatted
            amount = formatted
        }
    }
    
    private func validateAmount(_ input: String) {
        let validation = validateAmountInput(input)
        
        withAnimation {
            isValid = validation.isValid
            errorMessage = validation.errorMessage
        }
        
        onValidationChange(validation.isValid, validation.decimal)
    }
    
    private func validateAmountInput(_ input: String) -> (isValid: Bool, decimal: Decimal?, errorMessage: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (false, nil, "")
        }
        
        // Заменяем запятую на точку
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        
        // Проверяем недопустимые символы
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        if normalized.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return (false, nil, "Используйте только цифры и точку")
        }
        
        // Проверяем количество точек
        let dotCount = normalized.components(separatedBy: ".").count - 1
        if dotCount > 1 {
            return (false, nil, "Не более одной точки")
        }
        
        // Проверяем знаки после точки
        if let dotRange = normalized.range(of: ".") {
            let afterDot = String(normalized[dotRange.upperBound...])
            if afterDot.count > 2 {
                return (false, nil, "Максимум 2 знака после точки")
            }
        }
        
        // Пробуем преобразовать в Decimal
        guard let decimal = parseDecimal(from: normalized) else {
            return (false, nil, "Неверный формат суммы")
        }
        
        // Проверяем на ноль
        if decimal <= 0 {
            return (false, nil, "Сумма должна быть больше нуля")
        }
        
        return (true, decimal, "")
    }
    
    private func parseDecimal(from string: String) -> Decimal? {
        let normalized = string.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }
    
    private func formatDecimal(_ decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ""
        
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? decimal.description
    }
    
    private func formatHint() -> String {
        if let decimal = parseDecimal(from: displayAmount), decimal > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "RUB"
            formatter.locale = Locale(identifier: "ru_RU")
            
            if let formatted = formatter.string(from: NSDecimalNumber(decimal: decimal)) {
                return "Сумма: \(formatted)"
            }
        }
        
        return ""
    }
}

// MARK: - Extension для валидации в сервисе

extension FinanceService {
    static func validateAmount(_ amount: String) -> (isValid: Bool, decimal: Decimal?) {
        // Убираем пробелы
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return (false, nil)
        }
        
        // Заменяем запятую на точку для десятичных чисел
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        
        // Проверяем, что строка содержит только цифры, точку и максимум одну точку
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        guard normalized.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return (false, nil)
        }
        
        // Проверяем количество точек
        let dotCount = normalized.components(separatedBy: ".").count - 1
        guard dotCount <= 1 else {
            return (false, nil)
        }
        
        // Проверяем количество знаков после запятой
        if let dotRange = normalized.range(of: ".") {
            let afterDot = String(normalized[dotRange.upperBound...])
            guard afterDot.count <= 2 else {
                return (false, nil)
            }
        }
        
        // Пробуем преобразовать в Decimal
        guard let decimal = Decimal(string: normalized), decimal > 0 else {
            return (false, nil)
        }
        
        return (true, decimal)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ValidatedAmountInputView(
            title: "Сумма покупки",
            amount: .constant("1250.50"),
            placeholder: "Введите сумму",
            currency: "₽"
        ) { isValid, decimal in
            print("Validation: \(isValid), Decimal: \(decimal?.description ?? "nil")")
        }
        
        ValidatedAmountInputView(
            title: "Доход",
            amount: .constant(""),
            placeholder: "Введите сумму",
            currency: "₽"
        ) { isValid, decimal in
            print("Validation: \(isValid), Decimal: \(decimal?.description ?? "nil")")
        }
        
        ValidatedAmountInputView(
            title: "Неверная сумма",
            amount: .constant("abc.12.34"),
            placeholder: "Введите сумму",
            currency: "₽"
        ) { isValid, decimal in
            print("Validation: \(isValid), Decimal: \(decimal?.description ?? "nil")")
        }
    }
    .padding()
} 