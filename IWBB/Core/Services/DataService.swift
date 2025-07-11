import Foundation
import SwiftData
import CloudKit

// MARK: - DataService Implementation
@Observable
final class DataService: DataServiceProtocol {
    
    // MARK: - Properties
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    private(set) var isInitialized: Bool = false
    private var backgroundContext: ModelContext
    private let syncQueue = DispatchQueue(label: "com.plannerapp.dataservice.sync", qos: .utility)
    
    // MARK: - Initialization
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
        self.backgroundContext = ModelContext(modelContainer)
    }
    
    convenience init() {
        self.init(modelContainer: ModelContainer.shared)
    }
    
    // MARK: - ServiceProtocol
    func initialize() async throws {
        guard !isInitialized else { return }
        
        do {
            // Настраиваем CloudKit синхронизацию
            try await setupCloudKitSync()
            
            // Проверяем целостность данных
            try await validateDataIntegrity()
            
            isInitialized = true
            
            #if DEBUG
            print("DataService initialized successfully")
            #endif
            
        } catch {
            throw AppError.from(error)
        }
    }
    
    func cleanup() async {
        // Сохраняем все несохраненные изменения
        if modelContext.hasChanges {
            try? modelContext.save()
        }
        
        if backgroundContext.hasChanges {
            try? backgroundContext.save()
        }
        
        isInitialized = false
        
        #if DEBUG
        print("DataService cleaned up")
        #endif
    }
    
    // MARK: - CRUD Operations
    
    @MainActor
    func fetch<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>? = nil) async throws -> [T] {
        do {
            let descriptor = FetchDescriptor<T>(predicate: predicate)
            return try modelContext.fetch(descriptor)
        } catch {
            throw AppError.fetchFailed("Failed to fetch \(String(describing: type)): \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func fetchOne<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) async throws -> T? {
        do {
            var descriptor = FetchDescriptor<T>(predicate: predicate)
            descriptor.fetchLimit = 1
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            throw AppError.fetchFailed("Failed to fetch one \(String(describing: type)): \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func save<T: PersistentModel>(_ model: T) async throws {
        do {
            // Обновляем временные метки если модель поддерживает их
            if var timestampable = model as? Timestampable {
                let now = Date()
                if timestampable.createdAt == Date.distantPast {
                    timestampable.createdAt = now
                }
                timestampable.updatedAt = now
            }
            
            // Помечаем для CloudKit синхронизации
            if var syncable = model as? CloudKitSyncable {
                syncable.markForSync()
            }
            
            modelContext.insert(model)
            try modelContext.save()
            
            // Планируем синхронизацию
            await scheduleSync()
            
        } catch {
            throw AppError.saveFailed("Failed to save \(String(describing: type(of: model))): \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func update<T: PersistentModel>(_ model: T) async throws {
        do {
            // Обновляем временную метку
            if var timestampable = model as? Timestampable {
                timestampable.updatedAt = Date()
            }
            
            // Помечаем для синхронизации
            if var syncable = model as? CloudKitSyncable {
                syncable.markForSync()
            }
            
            try modelContext.save()
            
            // Планируем синхронизацию
            await scheduleSync()
            
        } catch {
            throw AppError.saveFailed("Failed to update \(String(describing: type(of: model))): \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func delete<T: PersistentModel>(_ model: T) async throws {
        do {
            modelContext.delete(model)
            try modelContext.save()
            
            // Планируем синхронизацию для удаления из CloudKit
            await scheduleSync()
            
        } catch {
            throw AppError.deleteFailed("Failed to delete \(String(describing: type(of: model))): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Batch Operations
    
    func batchSave<T: PersistentModel>(_ models: [T]) async throws {
        return try await withThrowingTaskGroup(of: Void.self) { group in
            // Используем background context для batch операций
            await backgroundContext.perform {
                for model in models {
                    // Обновляем временные метки
                    if var timestampable = model as? Timestampable {
                        let now = Date()
                        if timestampable.createdAt == Date.distantPast {
                            timestampable.createdAt = now
                        }
                        timestampable.updatedAt = now
                    }
                    
                    // Помечаем для синхронизации
                    if var syncable = model as? CloudKitSyncable {
                        syncable.markForSync()
                    }
                    
                    self.backgroundContext.insert(model)
                }
                
                do {
                    try self.backgroundContext.save()
                } catch {
                    throw AppError.saveFailed("Batch save failed: \(error.localizedDescription)")
                }
            }
            
            // Планируем синхронизацию
            await scheduleSync()
        }
    }
    
    func batchDelete<T: PersistentModel>(_ models: [T]) async throws {
        return try await withThrowingTaskGroup(of: Void.self) { group in
            await backgroundContext.perform {
                for model in models {
                    // В background context нужно найти объект по ID
                    if let modelID = model.persistentModelID {
                        if let backgroundModel = self.backgroundContext.model(for: modelID) as? T {
                            self.backgroundContext.delete(backgroundModel)
                        }
                    }
                }
                
                do {
                    try self.backgroundContext.save()
                } catch {
                    throw AppError.deleteFailed("Batch delete failed: \(error.localizedDescription)")
                }
            }
            
            await scheduleSync()
        }
    }
    
    // MARK: - CloudKit Sync Operations
    
    func markForSync<T: PersistentModel>(_ model: T) async throws {
        guard var syncable = model as? CloudKitSyncable else {
            throw AppError.syncFailed("Model \(String(describing: type(of: model))) does not support CloudKit sync")
        }
        
        syncable.markForSync()
        try await update(model)
    }
    
    func performBatchSync() async throws {
        do {
            // Получаем все объекты, требующие синхронизации
            let pendingSyncModels = try await fetchPendingSyncModels()
            
            guard !pendingSyncModels.isEmpty else {
                #if DEBUG
                print("No models pending sync")
                #endif
                return
            }
            
            #if DEBUG
            print("Starting batch sync for \(pendingSyncModels.count) models")
            #endif
            
            // Синхронизируем пакетами по 10 объектов
            let batchSize = 10
            for batch in pendingSyncModels.chunked(into: batchSize) {
                try await syncBatch(batch)
                
                // Небольшая пауза между пакетами для снижения нагрузки
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
            }
            
            #if DEBUG
            print("Batch sync completed successfully")
            #endif
            
        } catch {
            throw AppError.syncFailed("Batch sync failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCloudKitSync() async throws {
        // Проверяем доступность CloudKit
        let accountStatus = try await withCheckedThrowingContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
        
        switch accountStatus {
        case .available:
            #if DEBUG
            print("CloudKit account available")
            #endif
        case .noAccount:
            throw AppError.cloudKitAccountNotAvailable
        case .restricted, .couldNotDetermine:
            throw AppError.cloudKitUnavailable
        @unknown default:
            throw AppError.cloudKitUnavailable
        }
    }
    
    private func validateDataIntegrity() async throws {
        // Здесь можно добавить проверки целостности данных
        // Например, проверить что у всех моделей есть обязательные поля
        
        do {
            // Проверяем основные модели
            let users: [User] = try await fetch(User.self)
            let habits: [Habit] = try await fetch(Habit.self)
            let tasks: [Task] = try await fetch(Task.self)
            
            #if DEBUG
            print("Data integrity check: \(users.count) users, \(habits.count) habits, \(tasks.count) tasks")
            #endif
            
        } catch {
            throw AppError.dataCorrupted("Data integrity validation failed: \(error.localizedDescription)")
        }
    }
    
    private func fetchPendingSyncModels() async throws -> [any CloudKitSyncable] {
        var pendingModels: [any CloudKitSyncable] = []
        
        // Получаем все типы моделей, которые поддерживают синхронизацию
        let users: [User] = try await fetch(User.self, predicate: #Predicate { $0.needsSync })
        let habits: [Habit] = try await fetch(Habit.self, predicate: #Predicate { $0.needsSync })
        let tasks: [Task] = try await fetch(Task.self, predicate: #Predicate { $0.needsSync })
        
        pendingModels.append(contentsOf: users)
        pendingModels.append(contentsOf: habits)
        pendingModels.append(contentsOf: tasks)
        
        return pendingModels
    }
    
    private func syncBatch(_ models: [any CloudKitSyncable]) async throws {
        // Здесь будет реальная логика синхронизации с CloudKit
        // Пока делаем заглушку
        
        for model in models {
            if var syncableModel = model as? (any CloudKitSyncable) {
                syncableModel.markSynced()
                
                // В реальной реализации здесь будет отправка в CloudKit
                #if DEBUG
                print("Synced model: \(type(of: model))")
                #endif
            }
        }
    }
    
    private func scheduleSync() async {
        // Планируем синхронизацию через небольшой интервал
        // чтобы не синхронизировать каждое изменение отдельно
        
        syncQueue.asyncAfter(deadline: .now() + 2.0) {
            Task {
                do {
                    try await self.performBatchSync()
                } catch {
                    #if DEBUG
                    print("Scheduled sync failed: \(error)")
                    #endif
                }
            }
        }
    }
}

// MARK: - Helper Extensions

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - DataService Factory

extension DataService {
    
    /// Создает DataService для тестирования
    static func testing() -> DataService {
        return DataService(modelContainer: ModelContainer.testing())
    }
    
    /// Создает DataService для превью
    static func preview() -> DataService {
        return DataService(modelContainer: ModelContainer.preview)
    }
} 