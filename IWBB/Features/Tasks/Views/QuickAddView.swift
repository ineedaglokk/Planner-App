import SwiftUI

struct QuickAddView: View {
    let taskService: TaskService
    let onTaskCreated: (Task) -> Void
    
    @State private var inputText = ""
    @State private var isCreating = false
    @State private var showFullForm = false
    @State private var parsedTask: ParsedTask?
    @State private var showError = false
    @State private var errorMessage = ""
    
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    private let dateParser = DateParser()
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            // Input field
            inputSection
            
            // Parsed components
            if let parsed = parsedTask {
                parsedComponentsSection(parsed)
            }
            
            // Quick suggestions
            quickSuggestionsSection
            
            // Action buttons
            actionButtonsSection
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            isInputFocused = true
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showFullForm) {
            if let parsed = parsedTask {
                CreateTaskView(
                    taskService: taskService,
                    taskToEdit: createTaskFromParsed(parsed)
                )
            }
        }
        .onChange(of: inputText) { _, newValue in
            parseInput(newValue)
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Быстрое добавление")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Опишите задачу естественным языком")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Закрыть") {
                dismiss()
            }
            .font(.caption)
        }
    }
    
    private var inputSection: some View {
        VStack(spacing: 8) {
            TextField(
                "Например: 'Купить молоко завтра в 15:00 высокий приоритет'",
                text: $inputText,
                axis: .vertical
            )
            .focused($isInputFocused)
            .lineLimit(2...4)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            
            HStack {
                Text("Распознавание: \(inputText.isEmpty ? "ожидание" : "активно")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !inputText.isEmpty {
                    Button("Очистить") {
                        inputText = ""
                        parsedTask = nil
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func parsedComponentsSection(_ parsed: ParsedTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Распознано:")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Title
                ComponentRow(
                    icon: "text.alignleft",
                    label: "Название",
                    value: parsed.title,
                    color: .blue
                )
                
                // Due date
                if let dueDate = parsed.dueDate {
                    ComponentRow(
                        icon: "calendar",
                        label: "Дедлайн",
                        value: DateFormatter.natural.string(from: dueDate),
                        color: .green
                    )
                }
                
                // Priority
                if parsed.priority != .normal {
                    ComponentRow(
                        icon: "exclamationmark.triangle",
                        label: "Приоритет",
                        value: parsed.priority.displayName,
                        color: priorityColor(parsed.priority)
                    )
                }
                
                // Category
                if let category = parsed.category {
                    ComponentRow(
                        icon: "tag",
                        label: "Категория",
                        value: category,
                        color: .purple
                    )
                }
                
                // Location
                if let location = parsed.location {
                    ComponentRow(
                        icon: "location",
                        label: "Место",
                        value: location,
                        color: .orange
                    )
                }
                
                // Notes
                if let notes = parsed.notes, !notes.isEmpty {
                    ComponentRow(
                        icon: "note.text",
                        label: "Заметки",
                        value: notes,
                        color: .gray
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .animation(.easeInOut, value: parsed.id)
    }
    
    private var quickSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Быстрые шаблоны:")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                QuickSuggestionCard(
                    icon: "cart",
                    title: "Покупки",
                    example: "Купить хлеб сегодня",
                    color: .green
                ) {
                    inputText = "Купить "
                    isInputFocused = true
                }
                
                QuickSuggestionCard(
                    icon: "briefcase",
                    title: "Работа",
                    example: "Встреча завтра в 14:00",
                    color: .blue
                ) {
                    inputText = "Встреча завтра в "
                    isInputFocused = true
                }
                
                QuickSuggestionCard(
                    icon: "house",
                    title: "Дом",
                    example: "Убрать квартиру в выходные",
                    color: .orange
                ) {
                    inputText = "Убрать "
                    isInputFocused = true
                }
                
                QuickSuggestionCard(
                    icon: "heart",
                    title: "Здоровье",
                    example: "Записаться к врачу на следующей неделе",
                    color: .red
                ) {
                    inputText = "Записаться к врачу "
                    isInputFocused = true
                }
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button("Подробнее") {
                showFullForm = true
            }
            .buttonStyle(.bordered)
            .disabled(parsedTask == nil)
            
            Button {
                Task {
                    await createQuickTask()
                }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus")
                    }
                    Text("Создать задачу")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(parsedTask == nil || isCreating)
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseInput(_ input: String) {
        guard !input.isEmpty else {
            parsedTask = nil
            return
        }
        
        // Parse the input using DateParser and our NLP logic
        let components = dateParser.parseNaturalLanguage(input)
        
        // Extract title (remove parsed components)
        var cleanTitle = input
        
        // Remove date/time phrases
        if let dateInfo = components.first(where: { $0.type == .date || $0.type == .time }) {
            cleanTitle = cleanTitle.replacingOccurrences(of: dateInfo.originalText, with: "")
        }
        
        // Extract priority keywords
        let priority = extractPriority(from: input)
        if priority != .normal {
            let priorityKeywords = ["важно", "срочно", "высокий", "низкий", "высокая", "низкая", "приоритет"]
            for keyword in priorityKeywords {
                cleanTitle = cleanTitle.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
            }
        }
        
        // Extract category
        let category = extractCategory(from: input)
        if let cat = category {
            let categoryKeywords = ["работа", "дом", "покупки", "здоровье", "спорт", "учеба"]
            for keyword in categoryKeywords {
                if cat.lowercased().contains(keyword) {
                    cleanTitle = cleanTitle.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
                }
            }
        }
        
        // Extract location
        let location = extractLocation(from: input)
        
        // Clean up title
        cleanTitle = cleanTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
        
        // Create parsed task
        parsedTask = ParsedTask(
            title: cleanTitle.isEmpty ? "Новая задача" : cleanTitle,
            dueDate: components.first(where: { $0.type == .date })?.date,
            priority: priority,
            category: category,
            location: location,
            notes: extractNotes(from: input)
        )
    }
    
    private func extractPriority(from text: String) -> TaskPriority {
        let lowercased = text.lowercased()
        
        if lowercased.contains("срочно") || lowercased.contains("критично") {
            return .urgent
        } else if lowercased.contains("важно") || lowercased.contains("высокий приоритет") || lowercased.contains("высокая важность") {
            return .high
        } else if lowercased.contains("низкий приоритет") || lowercased.contains("низкая важность") || lowercased.contains("неважно") {
            return .low
        }
        
        return .normal
    }
    
    private func extractCategory(from text: String) -> String? {
        let lowercased = text.lowercased()
        
        if lowercased.contains("работа") || lowercased.contains("офис") || lowercased.contains("встреча") {
            return "Работа"
        } else if lowercased.contains("дом") || lowercased.contains("убрать") || lowercased.contains("почистить") {
            return "Дом"
        } else if lowercased.contains("купить") || lowercased.contains("магазин") || lowercased.contains("покупки") {
            return "Покупки"
        } else if lowercased.contains("врач") || lowercased.contains("здоровье") || lowercased.contains("больница") {
            return "Здоровье"
        } else if lowercased.contains("спорт") || lowercased.contains("тренировка") || lowercased.contains("зал") {
            return "Спорт"
        } else if lowercased.contains("учеба") || lowercased.contains("урок") || lowercased.contains("экзамен") {
            return "Учеба"
        }
        
        return nil
    }
    
    private func extractLocation(from text: String) -> String? {
        let patterns = [
            "в ([а-яё]+(?:\\s+[а-яё]+)*)",
            "на ([а-яё]+(?:\\s+[а-яё]+)*)",
            "у ([а-яё]+(?:\\s+[а-яё]+)*)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        return nil
    }
    
    private func extractNotes(from text: String) -> String? {
        // Extract additional notes or context
        if text.count > 100 {
            return "Подробности из исходного текста"
        }
        return nil
    }
    
    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return .green
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    private func createTaskFromParsed(_ parsed: ParsedTask) -> Task {
        let task = Task(
            title: parsed.title,
            description: parsed.notes ?? "",
            priority: parsed.priority
        )
        
        task.dueDate = parsed.dueDate
        task.category = parsed.category
        
        return task
    }
    
    private func createQuickTask() async {
        guard let parsed = parsedTask else { return }
        
        isCreating = true
        defer { isCreating = false }
        
        do {
            let task = createTaskFromParsed(parsed)
            let createdTask = try await taskService.createTask(task)
            
            DispatchQueue.main.async {
                self.onTaskCreated(createdTask)
                self.dismiss()
            }
        } catch {
            errorMessage = "Не удалось создать задачу: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Supporting Types

struct ParsedTask: Identifiable {
    let id = UUID()
    let title: String
    let dueDate: Date?
    let priority: TaskPriority
    let category: String?
    let location: String?
    let notes: String?
}

// MARK: - Supporting Views

struct ComponentRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct QuickSuggestionCard: View {
    let icon: String
    let title: String
    let example: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(example)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let natural: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    QuickAddView(
        taskService: MockTaskService(),
        onTaskCreated: { _ in }
    )
} 