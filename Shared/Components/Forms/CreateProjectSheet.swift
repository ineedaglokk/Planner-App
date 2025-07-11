import SwiftUI

// MARK: - Create Project Sheet

struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    
    // Form State
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var selectedTemplate: ProjectTemplate?
    @State private var selectedColor: ProjectColor = .blue
    @State private var selectedIcon: String = "folder.fill"
    @State private var targetStartDate = Date()
    @State private var targetEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedPriority: Priority = .medium
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    // Template State
    @State private var useTemplate = false
    @State private var availableTemplates: [ProjectTemplate] = []
    @State private var templateTasks: [ProjectTask] = []
    
    // UI State
    @State private var showingTemplates = false
    @State private var isLoading = false
    @State private var error: Error?
    
    // Validation
    private var isValid: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        targetEndDate > targetStartDate
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Template Selection
                    TemplateSelectionSection()
                    
                    // Basic Information
                    BasicInformationSection()
                    
                    // Visual Customization
                    VisualCustomizationSection()
                    
                    // Timeline
                    TimelineSection()
                    
                    // Additional Settings
                    AdditionalSettingsSection()
                    
                    // Template Tasks Preview
                    if useTemplate && !templateTasks.isEmpty {
                        TemplateTasksPreview()
                    }
                }
                .padding()
            }
            .navigationTitle("Новый проект")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        Task { await createProject() }
                    }
                    .disabled(!isValid || isLoading)
                }
            }
            .task {
                await loadTemplates()
            }
            .alert("Ошибка", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Template Selection Section
    
    @ViewBuilder
    private func TemplateSelectionSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Шаблон проекта")
                .font(.headline)
                .fontWeight(.semibold)
            
            Toggle("Использовать шаблон", isOn: $useTemplate)
                .onChange(of: useTemplate) { _, newValue in
                    if !newValue {
                        selectedTemplate = nil
                        templateTasks = []
                    }
                }
            
            if useTemplate {
                if availableTemplates.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Загрузка шаблонов...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(availableTemplates.prefix(4)) { template in
                            TemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id
                            ) {
                                selectedTemplate = template
                                applyTemplate(template)
                            }
                        }
                    }
                    
                    if availableTemplates.count > 4 {
                        Button("Показать все шаблоны") {
                            showingTemplates = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
        .sheet(isPresented: $showingTemplates) {
            TemplateSelectionSheet(
                templates: availableTemplates,
                selectedTemplate: $selectedTemplate
            ) { template in
                applyTemplate(template)
            }
        }
    }
    
    // MARK: - Basic Information Section
    
    @ViewBuilder
    private func BasicInformationSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Основная информация")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                TextField("Название проекта", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Описание (необязательно)", text: $projectDescription, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                
                // Priority Picker
                HStack {
                    Text("Приоритет:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Picker("Приоритет", selection: $selectedPriority) {
                        ForEach(Priority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 8, height: 8)
                                Text(priority.displayName)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Tags
                TagsInputView()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Visual Customization Section
    
    @ViewBuilder
    private func VisualCustomizationSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Оформление")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Color Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Цвет проекта")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(ProjectColor.allCases, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Icon Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Иконка проекта")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(ProjectIcon.allCases, id: \.self) { icon in
                            Button(action: { selectedIcon = icon.systemName }) {
                                Image(systemName: icon.systemName)
                                    .font(.title3)
                                    .frame(width: 30, height: 30)
                                    .background(
                                        Circle()
                                            .fill(selectedIcon == icon.systemName ? selectedColor.color.opacity(0.2) : Color(.systemGray6))
                                    )
                                    .foregroundStyle(selectedIcon == icon.systemName ? selectedColor.color : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Timeline Section
    
    @ViewBuilder
    private func TimelineSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Временные рамки")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DatePicker("Дата начала", selection: $targetStartDate, displayedComponents: .date)
                
                DatePicker("Дата окончания", selection: $targetEndDate, displayedComponents: .date)
                
                if targetEndDate <= targetStartDate {
                    Text("Дата окончания должна быть позже даты начала")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Additional Settings Section
    
    @ViewBuilder
    private func AdditionalSettingsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Дополнительные настройки")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Toggle("Создать начальные задачи", isOn: .constant(useTemplate && selectedTemplate != nil))
                    .disabled(true)
                
                Toggle("Отправить уведомления команде", isOn: .constant(false))
                    .disabled(true)
                
                Toggle("Добавить в календарь", isOn: .constant(false))
                    .disabled(true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Tags Input View
    
    @ViewBuilder
    private func TagsInputView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Теги")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                TextField("Добавить тег", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit {
                        addTag()
                    }
                
                Button("Добавить") {
                    addTag()
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Template Tasks Preview
    
    @ViewBuilder
    private func TemplateTasksPreview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Задачи из шаблона (\(templateTasks.count))")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(templateTasks.prefix(5)) { task in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        
                        Text(task.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        PriorityIndicator(priority: task.priority)
                    }
                    .padding(.vertical, 4)
                }
                
                if templateTasks.count > 5 {
                    Text("и еще \(templateTasks.count - 5) задач...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGroupedBackground))
        )
    }
    
    // MARK: - Helper Methods
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty && !tags.contains(trimmedTag) else { return }
        
        tags.append(trimmedTag)
        newTag = ""
    }
    
    private func loadTemplates() async {
        do {
            availableTemplates = try await services.templateService.getAvailableTemplates()
        } catch {
            self.error = error
        }
    }
    
    private func applyTemplate(_ template: ProjectTemplate) {
        if projectName.isEmpty {
            projectName = template.name
        }
        if projectDescription.isEmpty {
            projectDescription = template.description ?? ""
        }
        
        selectedColor = template.defaultColor ?? .blue
        selectedIcon = template.defaultIcon ?? "folder.fill"
        selectedPriority = template.defaultPriority ?? .medium
        
        Task {
            do {
                templateTasks = try await services.templateService.getTasksForTemplate(template.id)
            } catch {
                self.error = error
            }
        }
    }
    
    private func createProject() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let project = Project(
                name: projectName,
                description: projectDescription.isEmpty ? nil : projectDescription,
                targetStartDate: targetStartDate,
                targetEndDate: targetEndDate,
                priority: selectedPriority,
                color: selectedColor,
                icon: selectedIcon,
                tags: tags,
                templateId: selectedTemplate?.id
            )
            
            try await services.projectManagementService.createProject(project)
            
            // Create tasks from template if selected
            if let template = selectedTemplate, !templateTasks.isEmpty {
                try await services.templateService.createProjectFromTemplate(
                    template: template,
                    project: project
                )
            }
            
            dismiss()
        } catch {
            self.error = error
        }
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: ProjectTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.defaultIcon ?? "folder.fill")
                        .foregroundStyle(template.defaultColor?.color ?? .blue)
                        .font(.title3)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let description = template.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Text("\(template.estimatedTaskCount) задач")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Components

private struct TagChip: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemGray5))
        )
        .foregroundStyle(.primary)
    }
}

private struct PriorityIndicator: View {
    let priority: Priority
    
    var body: some View {
        Circle()
            .fill(priority.color)
            .frame(width: 8, height: 8)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(),
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
}

private struct FlowResult {
    let bounds: CGSize
    let positions: [CGPoint]
    
    init(in bounds: CGSize, subviews: LayoutSubviews, spacing: CGFloat) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        self.bounds = CGSize(width: bounds.width, height: currentY + lineHeight)
        self.positions = positions
    }
}

// MARK: - Project Enums

enum ProjectColor: String, CaseIterable {
    case blue, green, orange, red, purple, pink, yellow, gray
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .pink: return .pink
        case .yellow: return .yellow
        case .gray: return .gray
        }
    }
}

enum ProjectIcon: String, CaseIterable {
    case folder = "folder.fill"
    case doc = "doc.fill"
    case gear = "gear"
    case heart = "heart.fill"
    case star = "star.fill"
    case flag = "flag.fill"
    
    var systemName: String {
        return rawValue
    }
}

// MARK: - Preview

#Preview {
    CreateProjectSheet()
        .environment(\.services, ServiceContainer.preview())
} 