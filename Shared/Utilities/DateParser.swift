import Foundation

// MARK: - DateParser

/// Парсер для разбора дат на естественном языке
final class DateParser {
    
    // MARK: - Properties
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    // MARK: - Initialization
    
    init() {
        setupFormatter()
    }
    
    // MARK: - Public Methods
    
    /// Парсит строку с датой на естественном языке
    /// - Parameter input: Входная строка (например, "завтра", "через неделю", "15 мая")
    /// - Returns: Распознанная дата или nil если не удалось распарсить
    func parseDate(from input: String) -> Date? {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Пустая строка
        if cleanInput.isEmpty {
            return nil
        }
        
        // Сегодня
        if isToday(cleanInput) {
            return calendar.startOfDay(for: Date())
        }
        
        // Завтра
        if isTomorrow(cleanInput) {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        }
        
        // Послезавтра
        if isDayAfterTomorrow(cleanInput) {
            return calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))
        }
        
        // Вчера
        if isYesterday(cleanInput) {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))
        }
        
        // Дни недели
        if let weekdayDate = parseWeekday(cleanInput) {
            return weekdayDate
        }
        
        // Относительные даты ("через X дней/недель/месяцев")
        if let relativeDate = parseRelativeDate(cleanInput) {
            return relativeDate
        }
        
        // Абсолютные даты ("15 мая", "2024-05-15")
        if let absoluteDate = parseAbsoluteDate(cleanInput) {
            return absoluteDate
        }
        
        return nil
    }
    
    /// Парсит время из строки
    /// - Parameter input: Входная строка (например, "в 15:30", "в 3 дня")
    /// - Returns: Распознанное время или nil
    func parseTime(from input: String) -> DateComponents? {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Формат "15:30" или "15.30"
        if let timeComponents = parseTimeFormat(cleanInput) {
            return timeComponents
        }
        
        // Формат "в 3 дня", "в 15 часов"
        if let relativeTime = parseRelativeTime(cleanInput) {
            return relativeTime
        }
        
        return nil
    }
    
    /// Парсит полную дату и время
    /// - Parameter input: Входная строка (например, "завтра в 15:30")
    /// - Returns: Полная дата с временем
    func parseDateAndTime(from input: String) -> Date? {
        let parts = input.lowercased().components(separatedBy: " в ")
        
        if parts.count == 2 {
            let datePart = parts[0]
            let timePart = "в " + parts[1]
            
            guard let date = parseDate(from: datePart),
                  let timeComponents = parseTime(from: timePart) else {
                return nil
            }
            
            return calendar.date(bySettingTimeComponents: timeComponents, of: date)
        }
        
        // Попробуем распарсить как дату без времени
        return parseDate(from: input)
    }
    
    /// Предлагает варианты автодополнения для ввода
    /// - Parameter input: Частично введенная строка
    /// - Returns: Массив предложений
    func getSuggestions(for input: String) -> [DateSuggestion] {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if cleanInput.isEmpty {
            return getDefaultSuggestions()
        }
        
        var suggestions: [DateSuggestion] = []
        
        // Предложения для частично введенного текста
        for suggestion in getAllSuggestions() {
            if suggestion.text.lowercased().contains(cleanInput) ||
               suggestion.keywords.contains(where: { $0.lowercased().contains(cleanInput) }) {
                suggestions.append(suggestion)
            }
        }
        
        return suggestions
    }
    
    // MARK: - Private Methods
    
    private func setupFormatter() {
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.calendar = calendar
    }
    
    // MARK: - Today/Tomorrow Recognition
    
    private func isToday(_ input: String) -> Bool {
        let todayKeywords = ["сегодня", "тдн", "сейчас"]
        return todayKeywords.contains(input)
    }
    
    private func isTomorrow(_ input: String) -> Bool {
        let tomorrowKeywords = ["завтра", "зтр", "tomorrow"]
        return tomorrowKeywords.contains(input)
    }
    
    private func isDayAfterTomorrow(_ input: String) -> Bool {
        let dayAfterTomorrowKeywords = ["послезавтра", "пзтр"]
        return dayAfterTomorrowKeywords.contains(input)
    }
    
    private func isYesterday(_ input: String) -> Bool {
        let yesterdayKeywords = ["вчера", "yesterday"]
        return yesterdayKeywords.contains(input)
    }
    
    // MARK: - Weekday Recognition
    
    private func parseWeekday(_ input: String) -> Date? {
        let weekdays = [
            (["понедельник", "пн", "monday"], 2),
            (["вторник", "вт", "tuesday"], 3),
            (["среда", "ср", "wednesday"], 4),
            (["четверг", "чт", "thursday"], 5),
            (["пятница", "пт", "friday"], 6),
            (["суббота", "сб", "saturday"], 7),
            (["воскресенье", "вс", "sunday"], 1)
        ]
        
        for (keywords, weekday) in weekdays {
            if keywords.contains(input) {
                return getNextWeekday(weekday)
            }
        }
        
        // "В понедельник", "в следующий вторник"
        for (keywords, weekday) in weekdays {
            for keyword in keywords {
                if input.contains(keyword) {
                    if input.contains("следующ") {
                        return getWeekdayInNextWeek(weekday)
                    } else {
                        return getNextWeekday(weekday)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func getNextWeekday(_ targetWeekday: Int) -> Date? {
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // На следующей неделе
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: today))
    }
    
    private func getWeekdayInNextWeek(_ targetWeekday: Int) -> Date? {
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        
        let daysToAdd = (7 - currentWeekday) + targetWeekday
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: today))
    }
    
    // MARK: - Relative Date Recognition
    
    private func parseRelativeDate(_ input: String) -> Date? {
        let today = calendar.startOfDay(for: Date())
        
        // "Через X дней/недель/месяцев"
        if input.hasPrefix("через ") {
            let remaining = String(input.dropFirst(6)) // убираем "через "
            
            if let amount = extractNumber(from: remaining) {
                if remaining.contains("ден") || remaining.contains("дн") {
                    return calendar.date(byAdding: .day, value: amount, to: today)
                } else if remaining.contains("недел") || remaining.contains("нед") {
                    return calendar.date(byAdding: .weekOfYear, value: amount, to: today)
                } else if remaining.contains("месяц") || remaining.contains("мес") {
                    return calendar.date(byAdding: .month, value: amount, to: today)
                } else if remaining.contains("год") {
                    return calendar.date(byAdding: .year, value: amount, to: today)
                }
            }
        }
        
        // "На следующей неделе"
        if input.contains("следующ") && input.contains("недел") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: today)
        }
        
        // "В следующем месяце"
        if input.contains("следующ") && input.contains("месяц") {
            return calendar.date(byAdding: .month, value: 1, to: today)
        }
        
        // "В следующем году"
        if input.contains("следующ") && input.contains("год") {
            return calendar.date(byAdding: .year, value: 1, to: today)
        }
        
        return nil
    }
    
    // MARK: - Absolute Date Recognition
    
    private func parseAbsoluteDate(_ input: String) -> Date? {
        // Формат "15 мая", "15 мая 2024"
        if let monthDate = parseMonthDate(input) {
            return monthDate
        }
        
        // Формат "2024-05-15", "15.05.2024", "15/05/2024"
        if let isoDate = parseISODate(input) {
            return isoDate
        }
        
        return nil
    }
    
    private func parseMonthDate(_ input: String) -> Date? {
        let months = [
            (["январ", "янв"], 1),
            (["феврал", "фев"], 2),
            (["март", "мар"], 3),
            (["апрел", "апр"], 4),
            (["май", "мая"], 5),
            (["июн"], 6),
            (["июл"], 7),
            (["август", "авг"], 8),
            (["сентябр", "сен"], 9),
            (["октябр", "окт"], 10),
            (["ноябр", "ноя"], 11),
            (["декабр", "дек"], 12)
        ]
        
        for (keywords, monthNumber) in months {
            for keyword in keywords {
                if input.contains(keyword) {
                    if let day = extractNumber(from: input) {
                        let currentYear = calendar.component(.year, from: Date())
                        let year = extractYear(from: input) ?? currentYear
                        
                        var components = DateComponents()
                        components.year = year
                        components.month = monthNumber
                        components.day = day
                        
                        return calendar.date(from: components)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func parseISODate(_ input: String) -> Date? {
        let formats = [
            "yyyy-MM-dd",
            "dd.MM.yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "dd.MM.yy",
            "dd/MM/yy"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: input) {
                return calendar.startOfDay(for: date)
            }
        }
        
        return nil
    }
    
    // MARK: - Time Recognition
    
    private func parseTimeFormat(_ input: String) -> DateComponents? {
        // "15:30" или "15.30"
        let timePattern = #"(\d{1,2})[:.]\s*(\d{2})"#
        let regex = try? NSRegularExpression(pattern: timePattern)
        let range = NSRange(input.startIndex..., in: input)
        
        if let match = regex?.firstMatch(in: input, options: [], range: range) {
            let hourRange = Range(match.range(at: 1), in: input)!
            let minuteRange = Range(match.range(at: 2), in: input)!
            
            if let hour = Int(input[hourRange]),
               let minute = Int(input[minuteRange]),
               hour >= 0 && hour <= 23,
               minute >= 0 && minute <= 59 {
                
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                return components
            }
        }
        
        return nil
    }
    
    private func parseRelativeTime(_ input: String) -> DateComponents? {
        // "в 3 дня", "в 15 часов"
        if input.hasPrefix("в ") {
            let remaining = String(input.dropFirst(2))
            
            if let amount = extractNumber(from: remaining) {
                if remaining.contains("час") && amount <= 23 {
                    var components = DateComponents()
                    components.hour = amount
                    components.minute = 0
                    return components
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func extractNumber(from text: String) -> Int? {
        let numberPattern = #"\d+"#
        let regex = try? NSRegularExpression(pattern: numberPattern)
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            let numberRange = Range(match.range, in: text)!
            return Int(text[numberRange])
        }
        
        return nil
    }
    
    private func extractYear(from text: String) -> Int? {
        let yearPattern = #"\b(20\d{2})\b"#
        let regex = try? NSRegularExpression(pattern: yearPattern)
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range) {
            let yearRange = Range(match.range(at: 1), in: text)!
            return Int(text[yearRange])
        }
        
        return nil
    }
    
    // MARK: - Suggestions
    
    private func getDefaultSuggestions() -> [DateSuggestion] {
        return [
            DateSuggestion(text: "Сегодня", date: calendar.startOfDay(for: Date()), keywords: ["сегодня"]),
            DateSuggestion(text: "Завтра", date: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())), keywords: ["завтра"]),
            DateSuggestion(text: "Через неделю", date: calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfDay(for: Date())), keywords: ["неделя"]),
            DateSuggestion(text: "В понедельник", date: getNextWeekday(2), keywords: ["понедельник"]),
            DateSuggestion(text: "В пятницу", date: getNextWeekday(6), keywords: ["пятница"])
        ]
    }
    
    private func getAllSuggestions() -> [DateSuggestion] {
        var suggestions = getDefaultSuggestions()
        
        // Добавляем дни недели
        let weekdays = [
            ("Понедельник", 2),
            ("Вторник", 3),
            ("Среда", 4),
            ("Четверг", 5),
            ("Пятница", 6),
            ("Суббота", 7),
            ("Воскресенье", 1)
        ]
        
        for (name, weekday) in weekdays {
            if let date = getNextWeekday(weekday) {
                suggestions.append(DateSuggestion(
                    text: "В \(name.lowercased())",
                    date: date,
                    keywords: [name.lowercased()]
                ))
            }
        }
        
        // Добавляем относительные даты
        let relativeDates = [
            ("Через 3 дня", 3, Calendar.Component.day),
            ("Через неделю", 1, Calendar.Component.weekOfYear),
            ("Через месяц", 1, Calendar.Component.month)
        ]
        
        for (text, value, component) in relativeDates {
            if let date = calendar.date(byAdding: component, value: value, to: calendar.startOfDay(for: Date())) {
                suggestions.append(DateSuggestion(
                    text: text,
                    date: date,
                    keywords: [text.lowercased()]
                ))
            }
        }
        
        return suggestions
    }
}

// MARK: - Supporting Types

/// Предложение для автодополнения даты
struct DateSuggestion {
    let text: String
    let date: Date?
    let keywords: [String]
    
    init(text: String, date: Date?, keywords: [String] = []) {
        self.text = text
        self.date = date
        self.keywords = keywords
    }
}

// MARK: - Calendar Extensions

extension Calendar {
    func date(bySettingTimeComponents timeComponents: DateComponents, of date: Date) -> Date? {
        var components = dateComponents([.year, .month, .day], from: date)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        return self.date(from: components)
    }
} 