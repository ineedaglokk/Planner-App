import SwiftUI

// MARK: - DueDateView

struct DueDateView: View {
    let dueDate: Date?
    let style: Style
    let showIcon: Bool
    
    enum Style {
        case compact
        case full
        case badge
        case minimal
    }
    
    init(
        dueDate: Date?,
        style: Style = .compact,
        showIcon: Bool = true
    ) {
        self.dueDate = dueDate
        self.style = style
        self.showIcon = showIcon
    }
    
    var body: some View {
        if let dueDate = dueDate {
            switch style {
            case .compact:
                compactView(for: dueDate)
            case .full:
                fullView(for: dueDate)
            case .badge:
                badgeView(for: dueDate)
            case .minimal:
                minimalView(for: dueDate)
            }
        } else {
            noDueDateView
        }
    }
    
    // MARK: - Style Variants
    
    @ViewBuilder
    private func compactView(for date: Date) -> some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: dueDateInfo(for: date).icon)
                    .font(.caption2)
                    .foregroundColor(dueDateInfo(for: date).color)
            }
            
            Text(dueDateInfo(for: date).text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(dueDateInfo(for: date).color)
        }
        .padding(.horizontal, showIcon ? 8 : 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(dueDateInfo(for: date).backgroundColor)
                .stroke(dueDateInfo(for: date).borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func fullView(for date: Date) -> some View {
        HStack(spacing: 8) {
            if showIcon {
                Image(systemName: dueDateInfo(for: date).icon)
                    .font(.callout)
                    .foregroundColor(dueDateInfo(for: date).color)
                    .frame(width: 20, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dueDateInfo(for: date).text)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(dueDateInfo(for: date).color)
                
                if let timeText = timeText(for: date) {
                    Text(timeText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dueDateInfo(for: date).backgroundColor)
                .stroke(dueDateInfo(for: date).borderColor, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func badgeView(for date: Date) -> some View {
        Text(dueDateInfo(for: date).shortText)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(dueDateInfo(for: date).urgencyColor)
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
    }
    
    @ViewBuilder
    private func minimalView(for date: Date) -> some View {
        Text(dueDateInfo(for: date).text)
            .font(.caption)
            .foregroundColor(dueDateInfo(for: date).color)
    }
    
    @ViewBuilder
    private var noDueDateView: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "calendar.badge.minus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text("Без дедлайна")
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
    
    // MARK: - Helper Methods
    
    private func dueDateInfo(for date: Date) -> DueDateInfo {
        let calendar = Calendar.current
        let now = Date()
        
        // Проверяем, просрочена ли дата
        let isOverdue = date < now
        
        // Вычисляем разницу в днях
        let daysDifference = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        
        if isOverdue {
            let daysOverdue = abs(daysDifference)
            return DueDateInfo(
                text: daysOverdue == 0 ? "Сегодня (просрочено)" : "Просрочено на \(daysOverdue) дн.",
                shortText: "Просрочено",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                backgroundColor: .red.opacity(0.1),
                borderColor: .red.opacity(0.3),
                urgencyColor: .red
            )
        }
        
        switch daysDifference {
        case 0:
            return DueDateInfo(
                text: "Сегодня",
                shortText: "Сегодня",
                icon: "sun.max.fill",
                color: .orange,
                backgroundColor: .orange.opacity(0.1),
                borderColor: .orange.opacity(0.3),
                urgencyColor: .orange
            )
        case 1:
            return DueDateInfo(
                text: "Завтра",
                shortText: "Завтра",
                icon: "moon.fill",
                color: .blue,
                backgroundColor: .blue.opacity(0.1),
                borderColor: .blue.opacity(0.3),
                urgencyColor: .blue
            )
        case 2...7:
            let dayName = dayOfWeekName(for: date)
            return DueDateInfo(
                text: dayName,
                shortText: "\(daysDifference)д",
                icon: "calendar",
                color: .green,
                backgroundColor: .green.opacity(0.1),
                borderColor: .green.opacity(0.3),
                urgencyColor: .green
            )
        case 8...30:
            return DueDateInfo(
                text: "Через \(daysDifference) дн.",
                shortText: "\(daysDifference)д",
                icon: "clock",
                color: .secondary,
                backgroundColor: .gray.opacity(0.1),
                borderColor: .gray.opacity(0.3),
                urgencyColor: .gray
            )
        default:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "ru_RU")
            
            return DueDateInfo(
                text: formatter.string(from: date),
                shortText: "\(daysDifference)д",
                icon: "calendar.circle",
                color: .secondary,
                backgroundColor: .gray.opacity(0.1),
                borderColor: .gray.opacity(0.3),
                urgencyColor: .gray
            )
        }
    }
    
    private func dayOfWeekName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date).capitalized
    }
    
    private func timeText(for date: Date) -> String? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Показываем время только если оно не 00:00
        if hour != 0 || minute != 0 {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter.string(from: date)
        }
        
        return nil
    }
}

// MARK: - DueDateInfo

private struct DueDateInfo {
    let text: String
    let shortText: String
    let icon: String
    let color: Color
    let backgroundColor: Color
    let borderColor: Color
    let urgencyColor: Color
}

// MARK: - DueDatePicker

struct DueDatePicker: View {
    @Binding var dueDate: Date?
    @State private var showDatePicker = false
    @State private var showQuickOptions = false
    
    private let dateParser = DateParser()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current due date display
            Button {
                showQuickOptions.toggle()
            } label: {
                HStack {
                    DueDateView(dueDate: dueDate, style: .full)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showQuickOptions ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Quick options
            if showQuickOptions {
                quickOptionsView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showQuickOptions)
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
    }
    
    @ViewBuilder
    private var quickOptionsView: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                quickOptionButton("Сегодня", date: Calendar.current.startOfDay(for: Date()))
                quickOptionButton("Завтра", date: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())))
                quickOptionButton("Через неделю", date: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.startOfDay(for: Date())))
                quickOptionButton("Выбрать дату", action: { showDatePicker = true })
            }
            
            if dueDate != nil {
                Button("Убрать дедлайн") {
                    dueDate = nil
                    showQuickOptions = false
                }
                .foregroundColor(.red)
                .font(.callout)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    @ViewBuilder
    private func quickOptionButton(_ title: String, date: Date? = nil, action: (() -> Void)? = nil) -> some View {
        Button {
            if let date = date {
                dueDate = date
                showQuickOptions = false
            } else {
                action?()
            }
        } label: {
            Text(title)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var datePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "Выберите дату",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Дедлайн")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        showDatePicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        showDatePicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    var isOverdue: Bool {
        self < Date()
    }
    
    var daysFromNow: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
    }
}

// MARK: - Previews

#if DEBUG
struct DueDateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Group {
                // Today
                DueDateView(dueDate: Date(), style: .compact)
                DueDateView(dueDate: Date(), style: .full)
                DueDateView(dueDate: Date(), style: .badge)
                
                // Tomorrow
                DueDateView(dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()), style: .compact)
                
                // Overdue
                DueDateView(dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()), style: .compact)
                
                // No due date
                DueDateView(dueDate: nil, style: .compact)
                
                Divider()
                
                // Picker
                DueDatePicker(dueDate: .constant(Date()))
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif 