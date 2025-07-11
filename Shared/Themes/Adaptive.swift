//
//  Adaptive.swift
//  PlannerApp
//
//  Created by AI Assistant
//  Дизайн-система: Адаптивность для разных устройств и размеров экранов
//

import SwiftUI

// MARK: - Device Types
enum DeviceType {
    case iPhone
    case iPad
    case mac
    
    static var current: DeviceType {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #elseif os(macOS)
        return .mac
        #else
        return .iPhone
        #endif
    }
}

// MARK: - Screen Size Categories
enum ScreenSizeCategory {
    case compact        // iPhone mini, SE
    case regular        // iPhone standard
    case large          // iPhone Pro Max
    case extraLarge     // iPad, Mac
    
    static var current: ScreenSizeCategory {
        let screen = getCurrentScreenSize()
        
        switch DeviceType.current {
        case .iPhone:
            if screen.width <= 375 {
                return .compact
            } else if screen.width <= 414 {
                return .regular
            } else {
                return .large
            }
        case .iPad, .mac:
            return .extraLarge
        }
    }
    
    private static func getCurrentScreenSize() -> CGSize {
        #if os(iOS)
        return UIScreen.main.bounds.size
        #elseif os(macOS)
        return NSScreen.main?.frame.size ?? CGSize(width: 1440, height: 900)
        #else
        return CGSize(width: 375, height: 812)
        #endif
    }
}

// MARK: - Adaptive Spacing
struct AdaptiveSpacing {
    static func padding(_ base: CGFloat = 16) -> CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return base * 0.75
        case .regular:
            return base
        case .large:
            return base * 1.25
        case .extraLarge:
            return base * 1.5
        }
    }
    
    static func margin(_ base: CGFloat = 20) -> CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return base * 0.8
        case .regular:
            return base
        case .large:
            return base * 1.2
        case .extraLarge:
            return base * 2.0
        }
    }
    
    static func cardSpacing(_ base: CGFloat = 12) -> CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return base * 0.75
        case .regular:
            return base
        case .large:
            return base * 1.25
        case .extraLarge:
            return base * 1.5
        }
    }
}

// MARK: - Adaptive Typography
struct AdaptiveTypography {
    static func title(_ base: CGFloat = 28) -> CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return base * 0.85
        case .regular:
            return base
        case .large:
            return base * 1.15
        case .extraLarge:
            return base * 1.3
        }
    }
    
    static func headline(_ base: CGFloat = 22) -> CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return base * 0.9
        case .regular:
            return base
        case .large:
            return base * 1.1
        case .extraLarge:
            return base * 1.2
        }
    }
    
    static func body(_ base: CGFloat = 16) -> CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return base * 0.9
        case .regular:
            return base
        case .large:
            return base * 1.05
        case .extraLarge:
            return base * 1.1
        }
    }
}

// MARK: - Adaptive Layout
struct AdaptiveLayout {
    
    // Количество колонок для сеток
    static var gridColumns: Int {
        switch DeviceType.current {
        case .iPhone:
            switch ScreenSizeCategory.current {
            case .compact:
                return 1
            case .regular, .large:
                return 2
            case .extraLarge:
                return 2
            }
        case .iPad:
            return 3
        case .mac:
            return 4
        }
    }
    
    // Максимальная ширина контента
    static var maxContentWidth: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return .infinity
        case .iPad:
            return 700
        case .mac:
            return 900
        }
    }
    
    // Высота карточек
    static var cardHeight: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 120
        case .regular:
            return 140
        case .large:
            return 160
        case .extraLarge:
            return 180
        }
    }
    
    // Высота кнопок
    static var buttonHeight: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 40
        case .regular:
            return 44
        case .large:
            return 48
        case .extraLarge:
            return 52
        }
    }
    
    // Минимальная ширина для боковых панелей
    static var sidebarMinWidth: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 0 // Нет боковой панели на iPhone
        case .iPad:
            return 250
        case .mac:
            return 280
        }
    }
}

// MARK: - Adaptive Corner Radius
struct AdaptiveCornerRadius {
    static var small: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 6
        case .regular:
            return 8
        case .large:
            return 10
        case .extraLarge:
            return 12
        }
    }
    
    static var medium: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 10
        case .regular:
            return 12
        case .large:
            return 14
        case .extraLarge:
            return 16
        }
    }
    
    static var large: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 16
        case .regular:
            return 20
        case .large:
            return 24
        case .extraLarge:
            return 28
        }
    }
}

// MARK: - Adaptive Icons
struct AdaptiveIcons {
    static var small: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 14
        case .regular:
            return 16
        case .large:
            return 18
        case .extraLarge:
            return 20
        }
    }
    
    static var medium: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 20
        case .regular:
            return 24
        case .large:
            return 28
        case .extraLarge:
            return 32
        }
    }
    
    static var large: CGFloat {
        switch ScreenSizeCategory.current {
        case .compact:
            return 32
        case .regular:
            return 40
        case .large:
            return 48
        case .extraLarge:
            return 56
        }
    }
}

// MARK: - View Extensions для адаптивности
extension View {
    /// Адаптивный padding
    func adaptivePadding(_ base: CGFloat = 16) -> some View {
        self.padding(AdaptiveSpacing.padding(base))
    }
    
    /// Адаптивные отступы
    func adaptiveMargin(_ base: CGFloat = 20) -> some View {
        self.padding(.horizontal, AdaptiveSpacing.margin(base))
    }
    
    /// Ограничение максимальной ширины контента
    func adaptiveContentWidth() -> some View {
        self.frame(maxWidth: AdaptiveLayout.maxContentWidth)
    }
    
    /// Адаптивная высота карточки
    func adaptiveCardHeight() -> some View {
        self.frame(height: AdaptiveLayout.cardHeight)
    }
    
    /// Адаптивный corner radius
    func adaptiveCornerRadius(_ size: AdaptiveCornerRadiusSize = .medium) -> some View {
        let radius: CGFloat
        switch size {
        case .small:
            radius = AdaptiveCornerRadius.small
        case .medium:
            radius = AdaptiveCornerRadius.medium
        case .large:
            radius = AdaptiveCornerRadius.large
        }
        return self.clipShape(RoundedRectangle(cornerRadius: radius))
    }
    
    /// Условное отображение для разных устройств
    func deviceSpecific<iPhone: View, iPad: View, Mac: View>(
        iPhone: () -> iPhone,
        iPad: () -> iPad,
        Mac: () -> Mac
    ) -> some View {
        Group {
            switch DeviceType.current {
            case .iPhone:
                iPhone()
            case .iPad:
                iPad()
            case .mac:
                Mac()
            }
        }
    }
    
    /// Адаптивная навигация для разных устройств
    func adaptiveNavigation() -> some View {
        self.deviceSpecific(
            iPhone: {
                // iPhone использует TabView
                self
            },
            iPad: {
                // iPad может использовать SplitView или TabView
                self
            },
            Mac: {
                // Mac использует NavigationSplitView
                NavigationSplitView {
                    MacSidebar()
                } detail: {
                    self
                }
            }
        )
    }
}

// MARK: - Supporting Types
enum AdaptiveCornerRadiusSize {
    case small
    case medium
    case large
}

// MARK: - Mac Sidebar
struct MacSidebar: View {
    @Environment(NavigationManager.self) private var navigationManager
    
    var body: some View {
        List(selection: Binding(
            get: { navigationManager.selectedTab },
            set: { navigationManager.selectedTab = $0 }
        )) {
            Section("Основное") {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .foregroundColor(tab.color)
                                .frame(width: 20)
                            
                            Text(tab.title)
                                .font(.system(size: AdaptiveTypography.body()))
                        }
                    }
                    .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: AdaptiveLayout.sidebarMinWidth)
    }
}

// MARK: - Responsive Grid
struct ResponsiveGrid<Content: View>: View {
    let content: Content
    let spacing: CGFloat
    
    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: AdaptiveLayout.gridColumns),
            spacing: AdaptiveSpacing.cardSpacing(spacing),
            content: { content }
        )
    }
}

// MARK: - Adaptive Container
struct AdaptiveContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .adaptiveContentWidth()
            .adaptivePadding()
            .adaptiveMargin()
    }
}

// MARK: - Preview Helpers для разных устройств
#if DEBUG
struct AdaptivePreviewHelper: View {
    let content: AnyView
    
    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }
    
    var body: some View {
        Group {
            // iPhone
            content
                .previewDevice("iPhone 15")
                .previewDisplayName("iPhone")
            
            // iPhone Pro Max
            content
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone Pro Max")
            
            // iPad
            content
                .previewDevice("iPad Pro (12.9-inch)")
                .previewDisplayName("iPad")
        }
    }
}

extension View {
    func adaptivePreviews() -> some View {
        AdaptivePreviewHelper {
            self
        }
    }
}
#endif 