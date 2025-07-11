import SwiftUI
import Charts

// MARK: - InteractiveHeatmap

struct InteractiveHeatmap: View {
    
    // MARK: - Properties
    
    let data: [HeatmapDataPoint]
    let title: String
    let onDateSelected: (Date) -> Void
    
    @State private var selectedDataPoint: HeatmapDataPoint?
    @State private var hoveredDataPoint: HeatmapDataPoint?
    @State private var showingTooltip = false
    
    // Layout
    private let cellSize: CGFloat = 16
    private let spacing: CGFloat = 2
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            ScrollView(.horizontal, showsIndicators: false) {
                heatmapGrid
                    .padding(.horizontal, 20)
            }
            
            legendView
            
            if let selectedDataPoint = selectedDataPoint {
                selectedDataInfoView(dataPoint: selectedDataPoint)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(data.count) точек данных")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let averageValue = data.reduce(0.0) { $0 + $1.value } / Double(data.count)
                Text("\(averageValue, specifier: "%.1f")")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("среднее")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Heatmap Grid
    
    private var heatmapGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(data.indices, id: \.self) { index in
                heatmapCell(dataPoint: data[index])
            }
        }
    }
    
    // MARK: - Heatmap Cell
    
    private func heatmapCell(dataPoint: HeatmapDataPoint) -> some View {
        let isSelected = selectedDataPoint?.id == dataPoint.id
        let isHovered = hoveredDataPoint?.id == dataPoint.id
        
        return RoundedRectangle(cornerRadius: 3)
            .fill(colorForValue(dataPoint.value))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onTapGesture {
                selectedDataPoint = dataPoint
                onDateSelected(dataPoint.date)
            }
            .onHover { hovering in
                hoveredDataPoint = hovering ? dataPoint : nil
                showingTooltip = hovering
            }
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        HStack {
            Text("Низкие значения")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 12, height: 12)
                }
            }
            
            Text("Высокие значения")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Selected Data Info View
    
    private func selectedDataInfoView(dataPoint: HeatmapDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDate(dataPoint.date))
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Circle()
                    .fill(colorForValue(dataPoint.value))
                    .frame(width: 12, height: 12)
                
                Text("Значение: \(dataPoint.value, specifier: "%.1f")")
                    .font(.body)
                
                Spacer()
            }
            
            if let description = dataPoint.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helper Methods
    
    private var gridColumns: [GridItem] {
        let weeksInView = min(53, (data.count + 6) / 7)
        return Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 7)
    }
    
    private func colorForValue(_ value: Double) -> Color {
        let maxValue = data.max(by: { $0.value < $1.value })?.value ?? 1.0
        let minValue = data.min(by: { $0.value < $1.value })?.value ?? 0.0
        let normalizedValue = maxValue > minValue ? (value - minValue) / (maxValue - minValue) : 0.0
        
        return Color.blue.opacity(0.2 + normalizedValue * 0.8)
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        let intensity = Double(level) / 4.0
        return Color.blue.opacity(0.2 + intensity * 0.8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - TrendLineChart

struct TrendLineChart: View {
    
    // MARK: - Properties
    
    let data: [TrendChartData]
    let title: String
    let xAxisLabel: String
    let yAxisLabel: String
    let showPrediction: Bool
    
    @State private var selectedDataPoint: TrendDataPoint?
    @State private var animateChart = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            chartView
                .frame(height: 300)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        animateChart = true
                    }
                }
            
            legendView
            
            if let selectedDataPoint = selectedDataPoint {
                selectedPointInfoView
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            if !data.isEmpty {
                let overallTrend = calculateOverallTrend()
                HStack {
                    Image(systemName: overallTrend.icon)
                        .foregroundColor(overallTrend.color)
                    
                    Text(overallTrend.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(data.count) серий данных")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        Chart {
            ForEach(data, id: \.id) { chartData in
                ForEach(chartData.dataPoints, id: \.date) { dataPoint in
                    LineMark(
                        x: .value(xAxisLabel, dataPoint.date),
                        y: .value(yAxisLabel, dataPoint.value)
                    )
                    .foregroundStyle(chartData.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    .opacity(animateChart ? 1.0 : 0.0)
                    
                    if selectedDataPoint?.date == dataPoint.date {
                        PointMark(
                            x: .value(xAxisLabel, dataPoint.date),
                            y: .value(yAxisLabel, dataPoint.value)
                        )
                        .foregroundStyle(chartData.color)
                        .symbolSize(100)
                    }
                }
                
                // Добавляем область под линией для лучшей визуализации
                ForEach(chartData.dataPoints, id: \.date) { dataPoint in
                    AreaMark(
                        x: .value(xAxisLabel, dataPoint.date),
                        y: .value(yAxisLabel, dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartData.color.opacity(0.3), chartData.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(animateChart ? 1.0 : 0.0)
                }
                
                // Prediction line if enabled
                if showPrediction && chartData.trend != .stable {
                    let predictionPoints = generatePredictionPoints(for: chartData)
                    ForEach(predictionPoints, id: \.date) { point in
                        LineMark(
                            x: .value(xAxisLabel, point.date),
                            y: .value(yAxisLabel, point.value)
                        )
                        .foregroundStyle(chartData.color.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .opacity(animateChart ? 1.0 : 0.0)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatAxisDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text("\(doubleValue, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartAngleSelection(value: .constant(nil))
        .chartBackground { _ in
            Rectangle()
                .fill(Color(.systemGray6).opacity(0.3))
        }
    }
    
    // MARK: - Legend View
    
    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(data, id: \.id) { chartData in
                    legendItem(for: chartData)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Legend Item
    
    private func legendItem(for chartData: TrendChartData) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(chartData.color)
                .frame(width: 16, height: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chartData.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: chartData.trend.icon)
                        .font(.caption2)
                        .foregroundColor(Color(hex: chartData.trend.color))
                    
                    Text("\(Int(chartData.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Selected Point Info View
    
    private var selectedPointInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Выбранная точка")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text(formatDate(selectedDataPoint!.date))
                    .font(.body)
                
                Spacer()
                
                Text("\(selectedDataPoint!.value, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallTrend() -> (icon: String, color: Color, description: String) {
        let improvingCount = data.filter { $0.trend == .improving }.count
        let decliningCount = data.filter { $0.trend == .declining }.count
        
        if improvingCount > decliningCount {
            return ("arrow.up.right", .green, "Общий тренд: улучшение")
        } else if decliningCount > improvingCount {
            return ("arrow.down.right", .red, "Общий тренд: снижение")
        } else {
            return ("arrow.right", .orange, "Общий тренд: стабильно")
        }
    }
    
    private func generatePredictionPoints(for chartData: TrendChartData) -> [TrendDataPoint] {
        guard !chartData.dataPoints.isEmpty else { return [] }
        
        let lastPoint = chartData.dataPoints.last!
        let calendar = Calendar.current
        
        var predictionPoints: [TrendDataPoint] = []
        
        // Простое линейное предсказание
        let trend = chartData.trend == .improving ? 1.1 : chartData.trend == .declining ? 0.9 : 1.0
        
        for i in 1...7 { // Предсказание на 7 дней вперед
            if let futureDate = calendar.date(byAdding: .day, value: i, to: lastPoint.date) {
                let futureValue = lastPoint.value * pow(trend, Double(i))
                predictionPoints.append(TrendDataPoint(date: futureDate, value: futureValue))
            }
        }
        
        return predictionPoints
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - CorrelationGraphView

struct CorrelationGraphView: View {
    
    // MARK: - Properties
    
    let correlations: [HabitCorrelation]
    let title: String
    
    @State private var selectedCorrelation: HabitCorrelation?
    @State private var animateNodes = false
    
    // Layout
    private let nodeRadius: CGFloat = 30
    private let graphSize: CGSize = CGSize(width: 300, height: 300)
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 1)
                    .frame(width: graphSize.width, height: graphSize.height)
                
                // Correlation lines
                ForEach(correlations.indices, id: \.self) { index in
                    correlationLine(correlation: correlations[index])
                }
                
                // Habit nodes
                ForEach(Array(habitNodes.enumerated()), id: \.offset) { index, habit in
                    habitNode(habit: habit, index: index)
                }
            }
            .frame(width: graphSize.width, height: graphSize.height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0)) {
                    animateNodes = true
                }
            }
            
            correlationLegendView
            
            if let selectedCorrelation = selectedCorrelation {
                correlationInfoView(correlation: selectedCorrelation)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("\(correlations.count) корреляций")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let strongCorrelations = correlations.filter { abs($0.score) > 0.5 }.count
                Text("\(strongCorrelations) сильных")
                    .font(.caption)
                    .foregroundColor(strongCorrelations > 0 ? .green : .secondary)
            }
        }
    }
    
    // MARK: - Correlation Line
    
    private func correlationLine(correlation: HabitCorrelation) -> some View {
        let startPosition = nodePosition(for: correlation.habit1)
        let endPosition = nodePosition(for: correlation.habit2)
        
        return Path { path in
            path.move(to: startPosition)
            path.addLine(to: endPosition)
        }
        .stroke(
            correlationColor(correlation.score),
            style: StrokeStyle(
                lineWidth: CGFloat(abs(correlation.score) * 4 + 1),
                lineCap: .round
            )
        )
        .opacity(animateNodes ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 1.0).delay(0.5), value: animateNodes)
        .onTapGesture {
            selectedCorrelation = correlation
        }
    }
    
    // MARK: - Habit Node
    
    private func habitNode(habit: Habit, index: Int) -> some View {
        let position = nodePosition(for: habit)
        let isSelected = selectedCorrelation?.habit1.id == habit.id || selectedCorrelation?.habit2.id == habit.id
        
        return Circle()
            .fill(Color(hex: habit.color) ?? .blue)
            .frame(width: nodeRadius * 2, height: nodeRadius * 2)
            .overlay(
                Text(String(habit.name.prefix(2)).uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
            )
            .scaleEffect(animateNodes ? 1.0 : 0.0)
            .animation(.spring(dampingFraction: 0.6).delay(Double(index) * 0.1), value: animateNodes)
            .position(position)
            .onTapGesture {
                if let correlation = correlations.first(where: { $0.habit1.id == habit.id || $0.habit2.id == habit.id }) {
                    selectedCorrelation = correlation
                }
            }
    }
    
    // MARK: - Correlation Legend View
    
    private var correlationLegendView: some View {
        HStack {
            legendItem(color: .red, label: "Отрицательная", score: -0.8)
            Spacer()
            legendItem(color: .gray, label: "Слабая", score: 0.2)
            Spacer()
            legendItem(color: .green, label: "Положительная", score: 0.8)
        }
    }
    
    // MARK: - Legend Item
    
    private func legendItem(color: Color, label: String, score: Double) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 16, height: 3)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                Text("\(score, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Correlation Info View
    
    private func correlationInfoView(correlation: HabitCorrelation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Корреляция")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(correlation.score, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(correlationColor(correlation.score))
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(correlation.habit1.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("и")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(correlation.habit2.name)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Уверенность")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(correlation.confidence * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("\(correlation.dataPoints) точек")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(correlationDescription(correlation.score))
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private var habitNodes: [Habit] {
        var habits: Set<Habit> = []
        for correlation in correlations {
            habits.insert(correlation.habit1)
            habits.insert(correlation.habit2)
        }
        return Array(habits)
    }
    
    private func nodePosition(for habit: Habit) -> CGPoint {
        guard let index = habitNodes.firstIndex(where: { $0.id == habit.id }) else {
            return CGPoint(x: graphSize.width / 2, y: graphSize.height / 2)
        }
        
        let angle = (Double(index) / Double(habitNodes.count)) * 2 * .pi
        let radius = (graphSize.width / 2) - nodeRadius - 10
        
        let x = (graphSize.width / 2) + cos(angle) * radius
        let y = (graphSize.height / 2) + sin(angle) * radius
        
        return CGPoint(x: x, y: y)
    }
    
    private func correlationColor(_ score: Double) -> Color {
        if score > 0.1 {
            return .green.opacity(min(1.0, abs(score)))
        } else if score < -0.1 {
            return .red.opacity(min(1.0, abs(score)))
        } else {
            return .gray.opacity(0.5)
        }
    }
    
    private func correlationDescription(_ score: Double) -> String {
        let absScore = abs(score)
        let strength: String
        
        switch absScore {
        case 0.8...1.0:
            strength = "очень сильная"
        case 0.6..<0.8:
            strength = "сильная"
        case 0.4..<0.6:
            strength = "умеренная"
        case 0.2..<0.4:
            strength = "слабая"
        default:
            strength = "очень слабая"
        }
        
        let direction = score > 0 ? "положительная" : score < 0 ? "отрицательная" : "отсутствует"
        
        return "\(direction.capitalized) \(strength) корреляция"
    }
}

// MARK: - Supporting Types

struct HeatmapDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let description: String?
    
    init(date: Date, value: Double, description: String? = nil) {
        self.date = date
        self.value = value
        self.description = description
    }
}

// MARK: - Extensions

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
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Heatmap preview
            InteractiveHeatmap(
                data: generateSampleHeatmapData(),
                title: "Активность за год",
                onDateSelected: { _ in }
            )
            
            // Trend chart preview
            TrendLineChart(
                data: generateSampleTrendData(),
                title: "Тренды привычек",
                xAxisLabel: "Дата",
                yAxisLabel: "Значение",
                showPrediction: true
            )
            
            // Correlation graph preview
            CorrelationGraphView(
                correlations: generateSampleCorrelations(),
                title: "Корреляции между привычками"
            )
        }
        .padding()
    }
}

// Sample data generators for preview
private func generateSampleHeatmapData() -> [HeatmapDataPoint] {
    var data: [HeatmapDataPoint] = []
    let calendar = Calendar.current
    
    for i in 0..<365 {
        if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
            data.append(HeatmapDataPoint(
                date: date,
                value: Double.random(in: 0...1),
                description: "День \(i + 1)"
            ))
        }
    }
    
    return data
}

private func generateSampleTrendData() -> [TrendChartData] {
    let dates = (0..<30).compactMap { 
        Calendar.current.date(byAdding: .day, value: -$0, to: Date()) 
    }.reversed()
    
    let dataPoints = dates.map { date in
        TrendDataPoint(date: date, value: Double.random(in: 0...10))
    }
    
    return [
        TrendChartData(
            id: "habit1",
            name: "Медитация",
            color: .blue,
            dataPoints: dataPoints,
            trend: .improving,
            confidence: 0.8
        )
    ]
}

private func generateSampleCorrelations() -> [HabitCorrelation] {
    // Здесь будут тестовые данные корреляций
    return []
} 