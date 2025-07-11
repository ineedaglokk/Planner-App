import XCTest
import SwiftData
@testable import IWBB

final class UserModelTests: BaseModelTests {
    
    // MARK: - Initialization Tests
    
    func testUserInitialization() {
        // Given
        let name = "John Doe"
        let email = "john@example.com"
        
        // When
        let user = User(name: name, email: email)
        
        // Then
        XCTAssertEqual(user.name, name)
        XCTAssertEqual(user.email, email)
        XCTAssertNotNil(user.id)
        XCTAssertEqual(user.level, 1)
        XCTAssertEqual(user.totalPoints, 0)
        XCTAssertEqual(user.currentExperience, 0)
        XCTAssertEqual(user.experienceToNextLevel, 100)
        XCTAssertEqual(user.currentStreak, 0)
        XCTAssertEqual(user.longestStreak, 0)
        XCTAssertEqual(user.totalHabitsCompleted, 0)
        XCTAssertEqual(user.totalTasksCompleted, 0)
        XCTAssertEqual(user.totalDaysActive, 0)
        XCTAssertTrue(user.needsSync)
        assertTimestamps(user)
    }
    
    func testUserWithDefaultPreferences() {
        // Given & When
        let user = createTestUser()
        
        // Then
        XCTAssertEqual(user.preferences.theme, .system)
        XCTAssertEqual(user.preferences.language, "ru")
        XCTAssertEqual(user.preferences.currency, "RUB")
        XCTAssertTrue(user.preferences.isGameModeEnabled)
        XCTAssertTrue(user.preferences.notificationSettings.isEnabled)
    }
    
    // MARK: - Validation Tests
    
    func testValidUserValidation() {
        // Given
        let user = createTestUser(name: "Valid User", email: "valid@example.com")
        
        // When & Then
        assertValidation(user, shouldBeValid: true)
    }
    
    func testInvalidUserWithEmptyName() {
        // Given
        let user = createTestUser(name: "", email: "test@example.com")
        
        // When & Then
        assertValidation(user, shouldBeValid: false)
    }
    
    func testInvalidUserWithInvalidEmail() {
        // Given
        let user = createTestUser(name: "Test User", email: "invalid-email")
        
        // When & Then
        assertValidation(user, shouldBeValid: false)
    }
    
    func testValidUserWithNilEmail() {
        // Given
        let user = createTestUser(name: "Test User", email: "")
        user.email = nil
        
        // When & Then
        assertValidation(user, shouldBeValid: true)
    }
    
    // MARK: - Experience and Level Tests
    
    func testAddExperience() {
        // Given
        let user = createTestUser()
        let initialLevel = user.level
        let experienceToAdd = 50
        
        // When
        user.addExperience(experienceToAdd)
        
        // Then
        XCTAssertEqual(user.currentExperience, experienceToAdd)
        XCTAssertEqual(user.totalPoints, experienceToAdd)
        XCTAssertEqual(user.level, initialLevel) // Не должен повыситься
    }
    
    func testLevelUpOnExperienceGain() {
        // Given
        let user = createTestUser()
        let experienceForLevelUp = 150 // Больше чем нужно для 2 уровня
        
        // When
        user.addExperience(experienceForLevelUp)
        
        // Then
        XCTAssertEqual(user.level, 2)
        XCTAssertEqual(user.currentExperience, 50) // 150 - 100 для уровня 2
        XCTAssertEqual(user.totalPoints, 150)
        XCTAssertTrue(user.experienceToNextLevel > 100) // Растет с уровнем
    }
    
    func testMultipleLevelUps() {
        // Given
        let user = createTestUser()
        let massiveExperience = 500
        
        // When
        user.addExperience(massiveExperience)
        
        // Then
        XCTAssertGreaterThan(user.level, 2)
        XCTAssertEqual(user.totalPoints, massiveExperience)
    }
    
    func testProgressToNextLevel() {
        // Given
        let user = createTestUser()
        user.addExperience(50) // Половина от 100 до следующего уровня
        
        // When
        let progress = user.progressToNextLevel
        
        // Then
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }
    
    // MARK: - Statistics Tests
    
    func testIncrementHabitsCompleted() {
        // Given
        let user = createTestUser()
        let initialCount = user.totalHabitsCompleted
        
        // When
        user.incrementHabitsCompleted()
        
        // Then
        XCTAssertEqual(user.totalHabitsCompleted, initialCount + 1)
        assertNeedsSync(user)
    }
    
    func testIncrementTasksCompleted() {
        // Given
        let user = createTestUser()
        let initialCount = user.totalTasksCompleted
        
        // When
        user.incrementTasksCompleted()
        
        // Then
        XCTAssertEqual(user.totalTasksCompleted, initialCount + 1)
        assertNeedsSync(user)
    }
    
    func testUpdateStreak() {
        // Given
        let user = createTestUser()
        let newStreak = 15
        let evenLongerStreak = 20
        
        // When
        user.updateStreak(newStreak)
        
        // Then
        XCTAssertEqual(user.currentStreak, newStreak)
        XCTAssertEqual(user.longestStreak, newStreak)
        
        // When - Updating with longer streak
        user.updateStreak(evenLongerStreak)
        
        // Then
        XCTAssertEqual(user.currentStreak, evenLongerStreak)
        XCTAssertEqual(user.longestStreak, evenLongerStreak)
        
        // When - Updating with shorter streak
        user.updateStreak(10)
        
        // Then
        XCTAssertEqual(user.currentStreak, 10)
        XCTAssertEqual(user.longestStreak, evenLongerStreak) // Должен остаться максимальным
    }
    
    func testIncrementActiveDays() {
        // Given
        let user = createTestUser()
        let initialDays = user.totalDaysActive
        
        // When
        user.incrementActiveDays()
        
        // Then
        XCTAssertEqual(user.totalDaysActive, initialDays + 1)
    }
    
    // MARK: - Relationships Tests
    
    func testUserHabitsRelationship() throws {
        // Given
        let user = createTestUser()
        let habit1 = createTestHabit(name: "Exercise", user: user)
        let habit2 = createTestHabit(name: "Read", user: user)
        
        // When
        try saveContext()
        
        // Then
        XCTAssertEqual(user.habits.count, 2)
        XCTAssertTrue(user.habits.contains(habit1))
        XCTAssertTrue(user.habits.contains(habit2))
        XCTAssertEqual(habit1.user?.id, user.id)
        XCTAssertEqual(habit2.user?.id, user.id)
    }
    
    func testUserTasksRelationship() throws {
        // Given
        let user = createTestUser()
        let task1 = createTestTask(title: "Task 1", user: user)
        let task2 = createTestTask(title: "Task 2", user: user)
        
        // When
        try saveContext()
        
        // Then
        XCTAssertEqual(user.tasks.count, 2)
        XCTAssertTrue(user.tasks.contains(task1))
        XCTAssertTrue(user.tasks.contains(task2))
    }
    
    func testUserGoalsRelationship() throws {
        // Given
        let user = createTestUser()
        let goal1 = createTestGoal(title: "Goal 1", user: user)
        let goal2 = createTestGoal(title: "Goal 2", user: user)
        
        // When
        try saveContext()
        
        // Then
        XCTAssertEqual(user.goals.count, 2)
        XCTAssertTrue(user.goals.contains(goal1))
        XCTAssertTrue(user.goals.contains(goal2))
    }
    
    // MARK: - Computed Properties Tests
    
    func testActiveHabits() {
        // Given
        let user = createTestUser()
        let activeHabit = createTestHabit(name: "Active", user: user)
        let inactiveHabit = createTestHabit(name: "Inactive", user: user)
        let archivedHabit = createTestHabit(name: "Archived", user: user)
        
        inactiveHabit.isActive = false
        archivedHabit.isArchived = true
        
        // When
        let activeHabits = user.activeHabits
        
        // Then
        XCTAssertEqual(activeHabits.count, 1)
        XCTAssertTrue(activeHabits.contains(activeHabit))
        XCTAssertFalse(activeHabits.contains(inactiveHabit))
        XCTAssertFalse(activeHabits.contains(archivedHabit))
    }
    
    func testPendingTasks() {
        // Given
        let user = createTestUser()
        let pendingTask = createTestTask(title: "Pending", user: user)
        let inProgressTask = createTestTask(title: "In Progress", user: user)
        let completedTask = createTestTask(title: "Completed", user: user)
        
        inProgressTask.status = .inProgress
        completedTask.markCompleted()
        
        // When
        let pendingTasks = user.pendingTasks
        
        // Then
        XCTAssertEqual(pendingTasks.count, 2)
        XCTAssertTrue(pendingTasks.contains(pendingTask))
        XCTAssertTrue(pendingTasks.contains(inProgressTask))
        XCTAssertFalse(pendingTasks.contains(completedTask))
    }
    
    func testActiveGoals() {
        // Given
        let user = createTestUser()
        let activeGoal = createTestGoal(title: "Active", user: user)
        let completedGoal = createTestGoal(title: "Completed", user: user)
        let archivedGoal = createTestGoal(title: "Archived", user: user)
        
        completedGoal.markCompleted()
        archivedGoal.archive()
        
        // When
        let activeGoals = user.activeGoals
        
        // Then
        XCTAssertEqual(activeGoals.count, 1)
        XCTAssertTrue(activeGoals.contains(activeGoal))
        XCTAssertFalse(activeGoals.contains(completedGoal))
        XCTAssertFalse(activeGoals.contains(archivedGoal))
    }
    
    // MARK: - CloudKit Sync Tests
    
    func testCloudKitSyncMarking() {
        // Given
        let user = createTestUser()
        user.needsSync = false
        
        // When
        user.markForSync()
        
        // Then
        XCTAssertTrue(user.needsSync)
    }
    
    func testCloudKitSyncCompletion() {
        // Given
        let user = createTestUser()
        user.needsSync = true
        user.lastSynced = nil
        
        // When
        user.markSynced()
        
        // Then
        XCTAssertFalse(user.needsSync)
        XCTAssertNotNil(user.lastSynced)
    }
    
    // MARK: - Performance Tests
    
    func testUserCreationPerformance() {
        measureModelCreation(count: 1000) {
            User(name: "Performance Test User", email: "perf@test.com")
        }
    }
    
    func testExperienceCalculationPerformance() {
        // Given
        let users = (0..<100).map { i in
            createTestUser(name: "User \(i)")
        }
        
        // When & Then
        measure {
            for user in users {
                user.addExperience(100)
            }
        }
    }
} 