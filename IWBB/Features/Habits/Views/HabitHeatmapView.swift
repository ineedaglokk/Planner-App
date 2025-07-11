import SwiftUI
import Charts

// MARK: - HabitHeatmapView

struct HabitHeatmapView: View {
    
    // MARK: - Properties
    
    let heatmapData: HabitHeatmapData
    let onDateSelected: (Date) -> Void
    
    @State private var selectedDate: Date?
    @State private var hoveredDate: Date?
    @State private var showingMonthLabels = true
    @State private var showingTooltip = false
    @State private var tooltipText = ""
    @State private var tooltipPosition = CGPoint.zero
    
    // Layout constants
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    private let monthSpacing: CGFloat = 20
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if showingMonthLabels {
                        monthLabelsView
                    }
                    
                    heatmapGridView
                    
                    weekdayLabelsView
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            
            legendView
            
            if let selectedDate = selectedDate {
                selectedDateInfoView(for: selectedDate)
            }
        }
        .overlay(
            tooltipView,
            alignment: .topLeading
        )
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(heatmapData.year) год")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(heatmapData.completedDays) из \(heatmapData.trackedDays) дней")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(heatmapData.completionRate * 100))%")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(completionRateColor)
                
                Text("выполнено")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: toggleMonthLabels) {
                Image(systemName: showingMonthLabels ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Month Labels View
    
    private var monthLabelsView: some View {
        HStack(spacing: 0) {
            ForEach(monthsWithWeeks, id: \.month) { monthInfo in
                Text(monthInfo.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: CGFloat(monthInfo.weeks) * (cellSize + cellSpacing), alignment: .leading)
                    .padding(.leading, monthInfo.weeks > 0 ? 0 : cellSpacing)
            }
        }
        .padding(.leading, 20) // Offset for weekday labels
    }
    
    // MARK: - Heatmap Grid View
    
    private var heatmapGridView: some View {
        HStack(spacing: 0) {
            // Weekday labels column
            VStack(alignment: .trailing, spacing: cellSpacing) {
                ForEach(0..<7, id: \.self) { weekday in
                    Text(weekdayLabels[weekday])
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 15, height: cellSize, alignment: .trailing)
                }
            }
            .padding(.trailing, 5)
            
            // Main heatmap grid
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: 7), spacing: cellSpacing) {
                ForEach(yearDates, id: \.self) { date in
                    heatmapCell(for: date)
                }
            }
        }
    }
    
    // MARK: - Weekday Labels View
    
    private var weekdayLabelsView: some View {
        HStack(spacing: cellSpacing) {
            Text("")
                .frame(width: 20) // Spacer for alignment
            
            ForEach(0..<weeksInYear, id: \.self) { week in
                if week % 4 == 0 {
                    Text("w\(week + 1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: cellSize)
                } else {
                    Text("")
                        .frame(width: cellSize)
                }
            }
        }
    }
    
    // MARK: - Heatmap Cell
    
    private func heatmapCell(for date: Date) -> some View {
        let heatmapValue = heatmapData.data[date]
        let isSelected = selectedDate != nil && Calendar.current.isDate(date, inSameDayAs: selectedDate!)
        let isHovered = hoveredDate != nil && Calendar.current.isDate(date, inSameDayAs: hoveredDate!)
        
        return RoundedRectangle(cornerRadius: 2)
            .fill(cellColor(for: heatmapValue))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onTapGesture {
                selectedDate = date
                onDateSelected(date)
            }
            .onHover { hovering in
                if hovering {
                    hoveredDate = date
                    showTooltip(for: date, heatmapValue: heatmapValue)
                } else {
                    hoveredDate = nil
                    hideTooltip()
                }
            }
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        HStack {
            Text("Меньше")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(legendColor(for: level))
                        .frame(width: cellSize, height: cellSize)
                }
            }
            
            Text("Больше")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                legendItem(color: .gray.opacity(0.3), label: "Не отслеживается")
                legendItem(color: .red.opacity(0.6), label: "Пропущено")
                legendItem(color: .green, label: "Выполнено")
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Legend Item
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: cellSize, height: cellSize)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Selected Date Info View
    
    private func selectedDateInfoView(for date: Date) -> some View {
        let heatmapValue = heatmapData.data[date]
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        
        return VStack(alignment: .leading, spacing: 8) {
            Text(formatter.string(from: date))
                .font(.headline)
            
            if let value = heatmapValue {
                HStack {
                    Circle()
                        .fill(cellColor(for: value))
                        .frame(width: 12, height: 12)
                    
                    if value.completion < 0 {
                        Text("День не отслеживался")
                            .foregroundColor(.secondary)
                    } else if value.isCompleted {
                        Text("Привычка выполнена (\(value.value))")
                            .foregroundColor(.primary)
                    } else if value.value > 0 {
                        Text("Частично выполнено (\(value.value))")
                            .foregroundColor(.orange)
                    } else {
                        Text("Привычка пропущена")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tooltip View
    
    private var tooltipView: some View {
        if showingTooltip {
            Text(tooltipText)
                .font(.caption)
                .padding(8)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(6)
                .position(tooltipPosition)
                .animation(.easeInOut(duration: 0.2), value: showingTooltip)
        }
    }
    
    // MARK: - Helper Methods
    
    private func cellColor(for heatmapValue: HeatmapValue?) -> Color {
        guard let value = heatmapValue else {
            return .gray.opacity(0.1)
        }
        
        if value.completion < 0 {
            // День не отслеживается
            return .gray.opacity(0.3)
        } else if value.isCompleted {
            // Полностью выполнено
            return .green.opacity(0.3 + value.completion * 0.7)
        } else if value.value > 0 {
            // Частично выполнено
            return .orange.opacity(0.3 + value.completion * 0.7)
        } else {
            // Не выполнено
            return .red.opacity(0.6)
        }
    }
    
    private func legendColor(for level: Int) -> Color {
        let intensity = Double(level) / 4.0
        return .green.opacity(0.2 + intensity * 0.8)
    }
    
    private var completionRateColor: Color {
        let rate = heatmapData.completionRate
        if rate >= 0.8 {
            return .green
        } else if rate >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func toggleMonthLabels() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showingMonthLabels.toggle()
        }
    }
    
    private func showTooltip(for date: Date, heatmapValue: HeatmapValue?) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if let value = heatmapValue {
            if value.completion < 0 {
                tooltipText = "\(formatter.string(from: date)): Не отслеживается"
            } else if value.isCompleted {
                tooltipText = "\(formatter.string(from: date)): Выполнено (\(value.value))"
            } else if value.value > 0 {
                tooltipText = "\(formatter.string(from: date)): Частично (\(value.value))"
            } else {
                tooltipText = "\(formatter.string(from: date)): Пропущено"
            }
        } else {
            tooltipText = "\(formatter.string(from: date)): Нет данных"
        }
        
        showingTooltip = true
    }
    
    private func hideTooltip() {
        showingTooltip = false
    }
    
    // MARK: - Computed Properties
    
    private var yearDates: [Date] {
        let calendar = Calendar.current
        guard let startOfYear = calendar.date(from: DateComponents(year: heatmapData.year, month: 1, day: 1)) else {
            return []
        }
        
        var dates: [Date] = []
        var currentDate = startOfYear
        
        // Добавляем дни до начала первой недели
        let firstWeekday = calendar.component(.weekday, from: startOfYear)
        let daysToAdd = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        for i in 0..<daysToAdd {
            if let date = calendar.date(byAdding: .day, value: -daysToAdd + i, to: startOfYear) {
                dates.append(date)
            }
        }
        
        // Добавляем все дни года
        while calendar.component(.year, from: currentDate) == heatmapData.year {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Добавляем дни до конца последней недели
        let lastWeekday = calendar.component(.weekday, from: dates.last ?? startOfYear)
        let remainingDays = (7 - ((lastWeekday - calendar.firstWeekday + 7) % 7)) % 7
        
        for i in 1...remainingDays {
            if let date = calendar.date(byAdding: .day, value: i, to: dates.last ?? startOfYear) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    private var weeksInYear: Int {
        return yearDates.count / 7
    }
    
    private var weekdayLabels: [String] {
        return ["П", "В", "С", "Ч", "П", "С", "В"]
    }
    
    private var monthsWithWeeks: [(month: Int, name: String, weeks: Int)] {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        
        var monthsInfo: [(month: Int, name: String, weeks: Int)] = []
        var currentMonth = 1
        var weekCount = 0
        
        for (index, date) in yearDates.enumerated() {
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            
            if year == heatmapData.year {
                if month != currentMonth {
                    if currentMonth <= 12 {
                        let monthName = monthFormatter.string(from: date)
                        monthsInfo.append((month: currentMonth, name: monthName, weeks: weekCount))
                    }
                    currentMonth = month
                    weekCount = 0
                }
                
                if index % 7 == 6 { // End of week
                    weekCount += 1
                }
            }
        }
        
        return monthsInfo
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let currentYear = calendar.component(.year, from: Date())
    
    // Создаем тестовые данные
    var testData: [Date: HeatmapValue] = [:]
    
    for day in 1...365 {
        if let date = calendar.date(from: DateComponents(year: currentYear, month: (day - 1) / 30 + 1, day: (day - 1) % 30 + 1)) {
            let completion = Double.random(in: 0...1)
            let value = Int.random(in: 0...3)
            
            testData[date] = HeatmapValue(
                completion: completion,
                value: value,
                isCompleted: completion >= 0.8
            )
        }
    }
    
    let heatmapData = HabitHeatmapData(
        year: currentYear,
        data: testData,
        totalDays: 365,
        completedDays: 250,
        trackedDays: 300
    )
    
    return HabitHeatmapView(heatmapData: heatmapData) { date in
        print("Selected date: \(date)")
    }
    .padding()
} 