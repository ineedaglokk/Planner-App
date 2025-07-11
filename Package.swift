// swift-tools-version: 5.9
// Package.swift для модульной архитектуры IWBB

import PackageDescription

let package = Package(
    name: "IWBBCore",
    defaultLocalization: "ru",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        // Основные модули
        .library(name: "IWBBCore", targets: ["IWBBCore"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "NetworkLayer", targets: ["NetworkLayer"]),
        
        // Фичи
        .library(name: "HabitsFeature", targets: ["HabitsFeature"]),
        .library(name: "TasksFeature", targets: ["TasksFeature"]),
        .library(name: "FinanceFeature", targets: ["FinanceFeature"]),
        .library(name: "DashboardFeature", targets: ["DashboardFeature"]),
        .library(name: "SettingsFeature", targets: ["SettingsFeature"]),
        
        // Утилиты
        .library(name: "SharedUtilities", targets: ["SharedUtilities"]),
        .library(name: "Extensions", targets: ["Extensions"]),
        
        // Тестовые утилиты
        .library(name: "TestUtilities", targets: ["TestUtilities"])
    ],
    dependencies: [
        // Внешние зависимости (пока нет, но могут понадобиться)
        // .package(url: "https://github.com/realm/SwiftLint", from: "0.52.0"),
        // .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        // .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0")
    ],
    targets: [
        // MARK: - Core Module
        .target(
            name: "IWBBCore",
            dependencies: [
                "DesignSystem",
                "DataLayer",
                "NetworkLayer",
                "SharedUtilities",
                "Extensions"
            ],
            path: "Sources/IWBBCore",
            resources: [
                .process("Resources")
            ]
        ),
        
        // MARK: - Design System
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Sources/DesignSystem",
            resources: [
                .process("Resources/Colors.xcassets"),
                .process("Resources/Images.xcassets")
            ]
        ),
        
        // MARK: - Data Layer
        .target(
            name: "DataLayer",
            dependencies: [
                "SharedUtilities"
            ],
            path: "Sources/DataLayer",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Network Layer
        .target(
            name: "NetworkLayer",
            dependencies: [
                "SharedUtilities"
            ],
            path: "Sources/NetworkLayer",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // MARK: - Features
        .target(
            name: "HabitsFeature",
            dependencies: [
                "IWBBCore",
                "DesignSystem",
                "DataLayer",
                "SharedUtilities"
            ],
            path: "Sources/Features/HabitsFeature",
            resources: [
                .process("Resources")
            ]
        ),
        
        .target(
            name: "TasksFeature",
            dependencies: [
                "IWBBCore",
                "DesignSystem", 
                "DataLayer",
                "SharedUtilities"
            ],
            path: "Sources/Features/TasksFeature",
            resources: [
                .process("Resources")
            ]
        ),
        
        .target(
            name: "FinanceFeature",
            dependencies: [
                "IWBBCore",
                "DesignSystem",
                "DataLayer",
                "SharedUtilities"
            ],
            path: "Sources/Features/FinanceFeature",
            resources: [
                .process("Resources")
            ]
        ),
        
        .target(
            name: "DashboardFeature",
            dependencies: [
                "IWBBCore",
                "DesignSystem",
                "DataLayer",
                "HabitsFeature",
                "TasksFeature", 
                "FinanceFeature",
                "SharedUtilities"
            ],
            path: "Sources/Features/DashboardFeature"
        ),
        
        .target(
            name: "SettingsFeature",
            dependencies: [
                "IWBBCore",
                "DesignSystem",
                "DataLayer",
                "SharedUtilities"
            ],
            path: "Sources/Features/SettingsFeature",
            resources: [
                .process("Resources")
            ]
        ),
        
        // MARK: - Utilities
        .target(
            name: "SharedUtilities",
            dependencies: [],
            path: "Sources/SharedUtilities",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        .target(
            name: "Extensions",
            dependencies: [],
            path: "Sources/Extensions"
        ),
        
        // MARK: - Test Utilities
        .target(
            name: "TestUtilities",
            dependencies: [
                "IWBBCore",
                "DataLayer",
                "SharedUtilities"
            ],
            path: "Sources/TestUtilities"
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "IWBBCoreTests",
            dependencies: [
                "IWBBCore",
                "TestUtilities"
            ],
            path: "Tests/IWBBCoreTests"
        ),
        
        .testTarget(
            name: "DesignSystemTests",
            dependencies: [
                "DesignSystem",
                "TestUtilities"
            ],
            path: "Tests/DesignSystemTests"
        ),
        
        .testTarget(
            name: "DataLayerTests",
            dependencies: [
                "DataLayer",
                "TestUtilities"
            ],
            path: "Tests/DataLayerTests"
        ),
        
        .testTarget(
            name: "NetworkLayerTests",
            dependencies: [
                "NetworkLayer",
                "TestUtilities"
            ],
            path: "Tests/NetworkLayerTests"
        ),
        
        .testTarget(
            name: "HabitsFeatureTests",
            dependencies: [
                "HabitsFeature",
                "TestUtilities"
            ],
            path: "Tests/Features/HabitsFeatureTests"
        ),
        
        .testTarget(
            name: "TasksFeatureTests",
            dependencies: [
                "TasksFeature", 
                "TestUtilities"
            ],
            path: "Tests/Features/TasksFeatureTests"
        ),
        
        .testTarget(
            name: "FinanceFeatureTests",
            dependencies: [
                "FinanceFeature",
                "TestUtilities"
            ],
            path: "Tests/Features/FinanceFeatureTests"
        ),
        
        .testTarget(
            name: "SharedUtilitiesTests",
            dependencies: [
                "SharedUtilities",
                "TestUtilities"
            ],
            path: "Tests/SharedUtilitiesTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)

// MARK: - Compiler Settings
#if swift(>=5.9)
// Включаем строгую проверку concurrency для Swift 5.9+
package.targets.forEach { target in
    if target.type == .regular || target.type == .executable {
        target.swiftSettings = target.swiftSettings ?? []
        target.swiftSettings?.append(.enableUpcomingFeature("BareSlashRegexLiterals"))
        target.swiftSettings?.append(.enableUpcomingFeature("ConciseMagicFile"))
        target.swiftSettings?.append(.enableUpcomingFeature("ForwardTrailingClosures"))
        target.swiftSettings?.append(.enableUpcomingFeature("DisableOutwardActorInference"))
        target.swiftSettings?.append(.enableUpcomingFeature("ExistentialAny"))
        target.swiftSettings?.append(.enableUpcomingFeature("GlobalConcurrency"))
        target.swiftSettings?.append(.enableUpcomingFeature("IsolatedDefaultValues"))
        
        // Предупреждения как ошибки в Release
        #if RELEASE
        target.swiftSettings?.append(.unsafeFlags(["-warnings-as-errors"]))
        #endif
    }
}
#endif

// MARK: - Platform Specific Configuration
#if os(iOS)
// iOS specific settings
#elseif os(macOS)
// macOS specific settings  
#elseif os(watchOS)
// watchOS specific settings
#elseif os(tvOS)
// tvOS specific settings
#endif 