//
//  AddTransactionView.swift
//  IWBB
//
//  Created by AI Assistant
//  Экран добавления новой транзакции
//

import SwiftUI

struct AddTransactionView: View {
    
    @StateObject private var viewModel = AddTransactionViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationManager.self) private var navigationManager
    
    var body: some View {
        NavigationView {
            Form {
                // Тип транзакции
                Section {
                    Picker("Тип", selection: $viewModel.input.transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                } header: {
                    Text("Тип операции")
                }
                
                // Сумма
                Section {
                    AmountInputView(
                        amount: $viewModel.input.amount,
                        currency: $viewModel.input.currency,
                        style: .default
                    )
                } header: {
                    Text("Сумма")
                }
                
                // Категория
                Section {
                    HStack {
                        Text("Категория")
                        Spacer()
                        
                        if let category = viewModel.input.selectedCategory {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                Text(category.name)
                                    .foregroundColor(ColorPalette.Text.primary)
                            }
                        } else {
                            Text("Выберите категорию")
                                .foregroundColor(ColorPalette.Text.secondary)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ColorPalette.Text.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Открыть выбор категории
                        viewModel.showCategoryPicker = true
                    }
                }
                
                // Описание
                Section {
                    TextField("Описание (необязательно)", text: $viewModel.input.description)
                        .textFieldStyle(PlainTextFieldStyle())
                } header: {
                    Text("Описание")
                }
                
                // Дата
                Section {
                    DatePicker("Дата", selection: $viewModel.input.date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(CompactDatePickerStyle())
                } header: {
                    Text("Дата и время")
                }
                
                // Дополнительные настройки
                Section {
                    // Повторяющаяся транзакция
                    Toggle("Повторяющаяся", isOn: $viewModel.input.isRecurring)
                    
                    if viewModel.input.isRecurring {
                        Picker("Частота", selection: $viewModel.input.recurringPattern) {
                            ForEach(RecurringPattern.allCases, id: \.self) { pattern in
                                Text(pattern.title).tag(pattern)
                            }
                        }
                    }
                    
                    // Теги
                    if !viewModel.input.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.input.tags, id: \.self) { tag in
                                    TagView(tag: tag) {
                                        viewModel.input.tags.removeAll { $0 == tag }
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                    
                    HStack {
                        TextField("Добавить тег", text: $viewModel.newTag)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                viewModel.addTag()
                            }
                        
                        Button("Добавить") {
                            viewModel.addTag()
                        }
                        .disabled(viewModel.newTag.isEmpty)
                    }
                } header: {
                    Text("Дополнительно")
                }
            }
            .navigationTitle("Новая операция")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Сохранить") {
                        Task {
                            await viewModel.saveTransaction()
                            if viewModel.state.isSaved {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.state.isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("Ошибка", isPresented: $viewModel.state.showError) {
                Button("OK") { }
            } message: {
                if let error = viewModel.state.error {
                    Text(error.localizedDescription)
                }
            }
            .sheet(isPresented: $viewModel.showCategoryPicker) {
                CategoryPickerView(
                    transactionType: viewModel.input.transactionType,
                    selectedCategory: $viewModel.input.selectedCategory
                )
            }
        }
        .task {
            await viewModel.loadCategories()
        }
    }
}

// MARK: - Tag View
struct TagView: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(tag)
                .font(Typography.Caption.medium)
                .foregroundColor(ColorPalette.Primary.main)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(ColorPalette.Primary.main)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorPalette.Primary.main.opacity(0.1))
        .cornerRadius(CornerRadius.small)
    }
}

// MARK: - Category Picker View
struct CategoryPickerView: View {
    let transactionType: TransactionType
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    
    @State private var categories: [Category] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Загрузка категорий...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredCategories) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.color))
                                    .frame(width: 24, height: 24)
                                
                                Text(category.name)
                                    .font(Typography.Body.medium)
                                
                                Spacer()
                                
                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ColorPalette.Primary.main)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCategory = category
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Выбор категории")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadCategories()
        }
    }
    
    private var filteredCategories: [Category] {
        categories.filter { category in
            switch transactionType {
            case .income:
                return category.type == .income
            case .expense:
                return category.type == .expense
            case .transfer:
                return true // Переводы могут использовать любые категории
            }
        }
    }
    
    private func loadCategories() async {
        // Здесь загружаем категории из сервиса
        // Пока используем моковые данные
        await MainActor.run {
            // Временные данные для демонстрации
            categories = Category.sampleCategories
            isLoading = false
        }
    }
}

// MARK: - Preview
#Preview {
    AddTransactionView()
        .environment(NavigationManager.preview)
} 