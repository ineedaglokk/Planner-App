import Foundation

// MARK: - UserDefaultsService Implementation
@Observable
final class UserDefaultsService: UserDefaultsServiceProtocol {
    
    // MARK: - Properties
    private let userDefaults: UserDefaults
    private(set) var isInitialized: Bool = false
    
    // Cache для часто используемых значений
    private var cache: [String: Any] = [:]
    private let cacheQueue = DispatchQueue(label: "com.plannerapp.userdefaults.cache", attributes: .concurrent)
    
    // MARK: - Initialization
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        guard !isInitialized else { return }
        
        // Устанавливаем значения по умолчанию при первом запуске
        setupDefaultValues()
        
        // Загружаем кэш
        loadCache()
        
        isInitialized = true
        
        #if DEBUG
        print("UserDefaultsService initialized successfully")
        #endif
    }
    
    func cleanup() async {
        // Сохраняем все изменения
        userDefaults.synchronize()
        
        // Очищаем кэш
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
        
        isInitialized = false
        
        #if DEBUG
        print("UserDefaultsService cleaned up")
        #endif
    }
    
    // MARK: - Theme Settings
    
    var themeMode: ThemeMode {
        get {
            return getCachedValue(for: .themeMode, default: .system) { key in
                guard let rawValue = userDefaults.string(forKey: key.rawValue) else { return .system }
                return ThemeMode(rawValue: rawValue) ?? .system
            }
        }
        set {
            setCachedValue(newValue, for: .themeMode) { key, value in
                userDefaults.set(value.rawValue, forKey: key.rawValue)
            }
        }
    }
    
    var accentColor: String {
        get {
            return getCachedValue(for: .accentColor, default: "#007AFF") { key in
                return userDefaults.string(forKey: key.rawValue) ?? "#007AFF"
            }
        }
        set {
            setCachedValue(newValue, for: .accentColor) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    // MARK: - Onboarding & First Launch
    
    var isFirstLaunch: Bool {
        get {
            return getCachedValue(for: .isFirstLaunch, default: true) { key in
                return userDefaults.bool(forKey: key.rawValue)
            }
        }
        set {
            setCachedValue(newValue, for: .isFirstLaunch) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    var hasCompletedOnboarding: Bool {
        get {
            return getCachedValue(for: .hasCompletedOnboarding, default: false) { key in
                return userDefaults.bool(forKey: key.rawValue)
            }
        }
        set {
            setCachedValue(newValue, for: .hasCompletedOnboarding) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    var onboardingVersion: String {
        get {
            return getCachedValue(for: .onboardingVersion, default: "1.0") { key in
                return userDefaults.string(forKey: key.rawValue) ?? "1.0"
            }
        }
        set {
            setCachedValue(newValue, for: .onboardingVersion) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    // MARK: - Feature Flags
    
    var isCloudSyncEnabled: Bool {
        get {
            return getCachedValue(for: .isCloudSyncEnabled, default: true) { key in
                return userDefaults.bool(forKey: key.rawValue)
            }
        }
        set {
            setCachedValue(newValue, for: .isCloudSyncEnabled) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    var isAnalyticsEnabled: Bool {
        get {
            return getCachedValue(for: .isAnalyticsEnabled, default: true) { key in
                return userDefaults.bool(forKey: key.rawValue)
            }
        }
        set {
            setCachedValue(newValue, for: .isAnalyticsEnabled) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    var isNotificationsEnabled: Bool {
        get {
            return getCachedValue(for: .isNotificationsEnabled, default: true) { key in
                return userDefaults.bool(forKey: key.rawValue)
            }
        }
        set {
            setCachedValue(newValue, for: .isNotificationsEnabled) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    // MARK: - User Preferences
    
    var defaultHabitReminderTime: Date {
        get {
            return getCachedValue(for: .defaultHabitReminderTime, default: defaultReminderTime()) { key in
                return userDefaults.object(forKey: key.rawValue) as? Date ?? defaultReminderTime()
            }
        }
        set {
            setCachedValue(newValue, for: .defaultHabitReminderTime) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    var weekStartsOn: WeekDay {
        get {
            return getCachedValue(for: .weekStartsOn, default: .monday) { key in
                let rawValue = userDefaults.integer(forKey: key.rawValue)
                return WeekDay(rawValue: rawValue == 0 ? 2 : rawValue) ?? .monday
            }
        }
        set {
            setCachedValue(newValue, for: .weekStartsOn) { key, value in
                userDefaults.set(value.rawValue, forKey: key.rawValue)
            }
        }
    }
    
    var preferredLanguage: String {
        get {
            return getCachedValue(for: .preferredLanguage, default: "ru") { key in
                return userDefaults.string(forKey: key.rawValue) ?? 
                       Locale.current.language.languageCode?.identifier ?? "ru"
            }
        }
        set {
            setCachedValue(newValue, for: .preferredLanguage) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    // MARK: - Privacy Settings
    
    var isBiometricEnabled: Bool {
        get {
            return getCachedValue(for: .isBiometricEnabled, default: false) { key in
                return userDefaults.bool(forKey: key.rawValue)
            }
        }
        set {
            setCachedValue(newValue, for: .isBiometricEnabled) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    var autoLockTimeout: TimeInterval {
        get {
            return getCachedValue(for: .autoLockTimeout, default: 300) { key in // 5 минут по умолчанию
                let timeout = userDefaults.double(forKey: key.rawValue)
                return timeout == 0 ? 300 : timeout
            }
        }
        set {
            setCachedValue(newValue, for: .autoLockTimeout) { key, value in
                userDefaults.set(value, forKey: key.rawValue)
            }
        }
    }
    
    // MARK: - Advanced Settings
    
    func setValue<T>(_ value: T, for key: UserDefaultsKey) where T: Codable {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key.rawValue)
            
            // Обновляем кэш
            cacheQueue.async(flags: .barrier) {
                self.cache[key.rawValue] = value
            }
            
            #if DEBUG
            print("Set value for key \(key.rawValue): \(value)")
            #endif
            
        } catch {
            #if DEBUG
            print("Failed to encode value for key \(key.rawValue): \(error)")
            #endif
        }
    }
    
    func getValue<T>(_ type: T.Type, for key: UserDefaultsKey) -> T? where T: Codable {
        // Проверяем кэш
        let cacheValue: T? = cacheQueue.sync {
            return cache[key.rawValue] as? T
        }
        
        if let cachedValue = cacheValue {
            return cachedValue
        }
        
        // Загружаем из UserDefaults
        guard let data = userDefaults.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            let value = try JSONDecoder().decode(type, from: data)
            
            // Кэшируем значение
            cacheQueue.async(flags: .barrier) {
                self.cache[key.rawValue] = value
            }
            
            return value
        } catch {
            #if DEBUG
            print("Failed to decode value for key \(key.rawValue): \(error)")
            #endif
            return nil
        }
    }
    
    func removeValue(for key: UserDefaultsKey) {
        userDefaults.removeObject(forKey: key.rawValue)
        
        // Удаляем из кэша
        cacheQueue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key.rawValue)
        }
        
        #if DEBUG
        print("Removed value for key \(key.rawValue)")
        #endif
    }
    
    func reset() {
        // Сохраняем некоторые критически важные настройки
        let preservedKeys: [UserDefaultsKey] = [
            .hasCompletedOnboarding,
            .onboardingVersion
        ]
        
        var preservedValues: [UserDefaultsKey: Any] = [:]
        for key in preservedKeys {
            if let value = userDefaults.object(forKey: key.rawValue) {
                preservedValues[key] = value
            }
        }
        
        // Удаляем все настройки приложения
        for key in UserDefaultsKey.allCases {
            userDefaults.removeObject(forKey: key.rawValue)
        }
        
        // Восстанавливаем сохраненные настройки
        for (key, value) in preservedValues {
            userDefaults.set(value, forKey: key.rawValue)
        }
        
        // Очищаем кэш и перезагружаем значения по умолчанию
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
        
        setupDefaultValues()
        loadCache()
        
        userDefaults.synchronize()
        
        #if DEBUG
        print("UserDefaults reset to default values")
        #endif
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultValues() {
        // Устанавливаем значения по умолчанию только при первом запуске
        let defaults: [String: Any] = [
            UserDefaultsKey.themeMode.rawValue: ThemeMode.system.rawValue,
            UserDefaultsKey.accentColor.rawValue: "#007AFF",
            UserDefaultsKey.isFirstLaunch.rawValue: true,
            UserDefaultsKey.hasCompletedOnboarding.rawValue: false,
            UserDefaultsKey.onboardingVersion.rawValue: "1.0",
            UserDefaultsKey.isCloudSyncEnabled.rawValue: true,
            UserDefaultsKey.isAnalyticsEnabled.rawValue: true,
            UserDefaultsKey.isNotificationsEnabled.rawValue: true,
            UserDefaultsKey.defaultHabitReminderTime.rawValue: defaultReminderTime(),
            UserDefaultsKey.weekStartsOn.rawValue: WeekDay.monday.rawValue,
            UserDefaultsKey.preferredLanguage.rawValue: Locale.current.language.languageCode?.identifier ?? "ru",
            UserDefaultsKey.isBiometricEnabled.rawValue: false,
            UserDefaultsKey.autoLockTimeout.rawValue: 300.0
        ]
        
        userDefaults.register(defaults: defaults)
    }
    
    private func loadCache() {
        cacheQueue.async(flags: .barrier) {
            // Загружаем часто используемые значения в кэш
            for key in UserDefaultsKey.allCases {
                if let value = self.userDefaults.object(forKey: key.rawValue) {
                    self.cache[key.rawValue] = value
                }
            }
        }
    }
    
    private func getCachedValue<T>(
        for key: UserDefaultsKey,
        default defaultValue: T,
        loader: (UserDefaultsKey) -> T
    ) -> T {
        let cachedValue: T? = cacheQueue.sync {
            return cache[key.rawValue] as? T
        }
        
        if let cached = cachedValue {
            return cached
        }
        
        let value = loader(key)
        
        // Кэшируем значение
        cacheQueue.async(flags: .barrier) {
            self.cache[key.rawValue] = value
        }
        
        return value
    }
    
    private func setCachedValue<T>(
        _ value: T,
        for key: UserDefaultsKey,
        setter: (UserDefaultsKey, T) -> Void
    ) {
        setter(key, value)
        
        // Обновляем кэш
        cacheQueue.async(flags: .barrier) {
            self.cache[key.rawValue] = value
        }
        
        // Синхронизируем изменения
        userDefaults.synchronize()
    }
    
    private func defaultReminderTime() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }
}

// MARK: - UserDefaultsService Extensions

extension UserDefaultsService {
    
    // MARK: - Convenience Properties
    
    /// Возвращает true, если это первый запуск приложения
    var isFirstAppLaunch: Bool {
        return isFirstLaunch
    }
    
    /// Возвращает true, если пользователь завершил онбординг
    var shouldShowOnboarding: Bool {
        return !hasCompletedOnboarding
    }
    
    /// Возвращает true, если нужно показать What's New экран
    var shouldShowWhatsNew: Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return onboardingVersion != currentVersion
    }
    
    // MARK: - Helper Methods
    
    /// Отмечает первый запуск как завершенный
    func markFirstLaunchCompleted() {
        isFirstLaunch = false
    }
    
    /// Отмечает онбординг как завершенный
    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        onboardingVersion = currentVersion
    }
    
    /// Обновляет версию онбординга
    func updateOnboardingVersion() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        onboardingVersion = currentVersion
    }
    
    /// Возвращает все настройки как словарь для экспорта
    func exportSettings() -> [String: Any] {
        var settings: [String: Any] = [:]
        
        for key in UserDefaultsKey.allCases {
            if let value = userDefaults.object(forKey: key.rawValue) {
                settings[key.rawValue] = value
            }
        }
        
        return settings
    }
    
    /// Импортирует настройки из словаря
    func importSettings(_ settings: [String: Any]) {
        for (key, value) in settings {
            userDefaults.set(value, forKey: key)
        }
        
        // Перезагружаем кэш
        loadCache()
        userDefaults.synchronize()
        
        #if DEBUG
        print("Imported \(settings.count) settings")
        #endif
    }
}

// MARK: - UserDefaultsService Factory

extension UserDefaultsService {
    
    /// Создает UserDefaultsService для тестирования с отдельным UserDefaults
    static func testing() -> UserDefaultsService {
        let suiteName = "com.plannerapp.testing.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        return UserDefaultsService(userDefaults: testDefaults)
    }
    
    /// Создает UserDefaultsService для превью
    static func preview() -> UserDefaultsService {
        let service = testing()
        // Устанавливаем тестовые значения для превью
        service.hasCompletedOnboarding = true
        service.themeMode = .system
        service.isCloudSyncEnabled = true
        return service
    }
} 