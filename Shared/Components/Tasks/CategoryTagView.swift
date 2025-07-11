import SwiftUI

// MARK: - CategoryTagView

struct CategoryTagView: View {
    let category: Category?
    let style: Style
    let showIcon: Bool
    
    enum Style {
        case compact
        case full
        case minimal
        case badge
    }
    
    init(
        category: Category?,
        style: Style = .compact,
        showIcon: Bool = true
    ) {
        self.category = category
        self.style = style
        self.showIcon = showIcon
    }
    
    var body: some View {
        if let category = category {
            switch style {
            case .compact:
                compactView(for: category)
            case .full:
                fullView(for: category)
            case .minimal:
                minimalView(for: category)
            case .badge:
                badgeView(for: category)
            }
        } else {
            noCategoryView
        }
    }
    
    // MARK: - Style Variants
    
    @ViewBuilder
    private func compactView(for category: Category) -> some View {
        HStack(spacing: 6) {
            if showIcon {
                Image(systemName: category.icon)
                    .font(.caption2)
                    .foregroundColor(category.color)
            }
            
            Text(category.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(category.textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(category.backgroundColor)
                .stroke(category.borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func fullView(for category: Category) -> some View {
        HStack(spacing: 8) {
            if showIcon {
                ZStack {
                    Circle()
                        .fill(category.backgroundColor)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: category.icon)
                        .font(.caption)
                        .foregroundColor(category.color)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if !category.description.isEmpty {
                    Text(category.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(category.backgroundColor)
                .stroke(category.borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func minimalView(for category: Category) -> some View {
        Text(category.name)
            .font(.caption2)
            .foregroundColor(category.color)
    }
    
    @ViewBuilder
    private func badgeView(for category: Category) -> some View {
        Text(category.name)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(category.color)
            )
    }
    
    @ViewBuilder
    private var noCategoryView: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "folder.badge.minus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("Без категории")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Category Extensions

extension Category {
    var color: Color {
        // Parse the color from hex string
        Color(hex: self.colorHex) ?? .blue
    }
    
    var backgroundColor: Color {
        color.opacity(0.1)
    }
    
    var borderColor: Color {
        color.opacity(0.3)
    }
    
    var textColor: Color {
        color
    }
    
    var icon: String {
        self.iconName.isEmpty ? "folder" : self.iconName
    }
    
    var description: String {
        self.taskDescription ?? ""
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
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
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var hexString: String {
        let uic = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uic.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        
        return String(format: "#%06x", rgb)
    }
}

// MARK: - TagsView

struct TagsView: View {
    let tags: [String]
    let maxDisplayCount: Int
    let style: TagStyle
    let onTagTap: ((String) -> Void)?
    
    enum TagStyle {
        case compact
        case rounded
        case minimal
    }
    
    init(
        tags: [String],
        maxDisplayCount: Int = 3,
        style: TagStyle = .compact,
        onTagTap: ((String) -> Void)? = nil
    ) {
        self.tags = tags
        self.maxDisplayCount = maxDisplayCount
        self.style = style
        self.onTagTap = onTagTap
    }
    
    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(tags.prefix(maxDisplayCount).enumerated()), id: \.offset) { _, tag in
                    tagView(for: tag)
                }
                
                if tags.count > maxDisplayCount {
                    Text("+\(tags.count - maxDisplayCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private func tagView(for tag: String) -> some View {
        let view = Group {
            switch style {
            case .compact:
                compactTag(tag)
            case .rounded:
                roundedTag(tag)
            case .minimal:
                minimalTag(tag)
            }
        }
        
        if let onTagTap = onTagTap {
            Button {
                onTagTap(tag)
            } label: {
                view
            }
            .buttonStyle(.plain)
        } else {
            view
        }
    }
    
    @ViewBuilder
    private func compactTag(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption2)
            .foregroundColor(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private func roundedTag(_ tag: String) -> some View {
        Text(tag)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
            )
    }
    
    @ViewBuilder
    private func minimalTag(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

// MARK: - CategoryPicker

struct CategoryPicker: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    let style: PickerStyle
    
    enum PickerStyle {
        case horizontal
        case grid
        case list
        case menu
    }
    
    init(
        selectedCategory: Binding<Category?>,
        categories: [Category],
        style: PickerStyle = .horizontal
    ) {
        self._selectedCategory = selectedCategory
        self.categories = categories
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .horizontal:
            horizontalPicker
        case .grid:
            gridPicker
        case .list:
            listPicker
        case .menu:
            menuPicker
        }
    }
    
    @ViewBuilder
    private var horizontalPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // No category option
                noCategoryButton
                
                ForEach(categories, id: \.id) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    @ViewBuilder
    private var gridPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            noCategoryButton
            
            ForEach(categories, id: \.id) { category in
                categoryButton(category)
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var listPicker: some View {
        VStack(spacing: 8) {
            Button {
                selectedCategory = nil
            } label: {
                HStack {
                    CategoryTagView(category: nil, style: .full)
                    
                    Spacer()
                    
                    if selectedCategory == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedCategory == nil ? Color.blue.opacity(0.1) : Color.clear)
                        .stroke(selectedCategory == nil ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            ForEach(categories, id: \.id) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack {
                        CategoryTagView(category: category, style: .full)
                        
                        Spacer()
                        
                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedCategory?.id == category.id ? Color.blue.opacity(0.1) : Color.clear)
                            .stroke(selectedCategory?.id == category.id ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var menuPicker: some View {
        Menu {
            Button("Без категории") {
                selectedCategory = nil
            }
            
            ForEach(categories, id: \.id) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack {
                        Image(systemName: category.icon)
                        Text(category.name)
                        
                        if selectedCategory?.id == category.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                CategoryTagView(category: selectedCategory, style: .compact)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray6))
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var noCategoryButton: some View {
        Button {
            selectedCategory = nil
        } label: {
            CategoryTagView(category: nil, style: .compact)
                .scaleEffect(selectedCategory == nil ? 1.0 : 0.9)
                .opacity(selectedCategory == nil ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func categoryButton(_ category: Category) -> some View {
        Button {
            selectedCategory = category
        } label: {
            CategoryTagView(category: category, style: .compact)
                .scaleEffect(selectedCategory?.id == category.id ? 1.0 : 0.9)
                .opacity(selectedCategory?.id == category.id ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TagInputView

struct TagInputView: View {
    @Binding var tags: [String]
    @State private var currentTag = ""
    @State private var showSuggestions = false
    
    let suggestions: [String]
    let placeholder: String
    
    init(
        tags: Binding<[String]>,
        suggestions: [String] = [],
        placeholder: String = "Добавить тег..."
    ) {
        self._tags = tags
        self.suggestions = suggestions
        self.placeholder = placeholder
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current tags
            if !tags.isEmpty {
                TagsView(tags: tags, style: .compact) { tag in
                    removeTag(tag)
                }
            }
            
            // Input field
            HStack {
                TextField(placeholder, text: $currentTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addCurrentTag()
                    }
                    .onChange(of: currentTag) { oldValue, newValue in
                        showSuggestions = !newValue.isEmpty && !suggestions.isEmpty
                    }
                
                if !currentTag.isEmpty {
                    Button("Добавить") {
                        addCurrentTag()
                    }
                    .font(.callout)
                    .fontWeight(.medium)
                }
            }
            
            // Suggestions
            if showSuggestions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                addTag(suggestion)
                                currentTag = ""
                                showSuggestions = false
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private var filteredSuggestions: [String] {
        suggestions.filter { suggestion in
            suggestion.localizedCaseInsensitiveContains(currentTag) &&
            !tags.contains(suggestion)
        }
    }
    
    private func addCurrentTag() {
        let cleanTag = currentTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTag.isEmpty {
            addTag(cleanTag)
            currentTag = ""
        }
    }
    
    private func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Previews

#if DEBUG
struct CategoryTagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Category views
            VStack(spacing: 12) {
                CategoryTagView(category: sampleCategory, style: .compact)
                CategoryTagView(category: sampleCategory, style: .full)
                CategoryTagView(category: sampleCategory, style: .badge)
                CategoryTagView(category: nil, style: .compact)
            }
            
            Divider()
            
            // Tags view
            TagsView(
                tags: ["важное", "проект", "дом"],
                style: .compact
            )
            
            Divider()
            
            // Category picker
            CategoryPicker(
                selectedCategory: .constant(sampleCategory),
                categories: [sampleCategory],
                style: .horizontal
            )
            
            Divider()
            
            // Tag input
            TagInputView(
                tags: .constant(["тест"]),
                suggestions: ["работа", "дом", "важное"]
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
    
    private static var sampleCategory: Category {
        let category = Category(name: "Работа", iconName: "briefcase", colorHex: "#007AFF")
        return category
    }
}
#endif 