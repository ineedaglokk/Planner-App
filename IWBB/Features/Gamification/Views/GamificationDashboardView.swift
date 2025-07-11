import SwiftUI

// MARK: - GamificationDashboardView

struct GamificationDashboardView: View {
    @State private var viewModel: GamificationDashboardViewModel
    @Environment(\.services) private var services
    
    init(user: User) {
        self._viewModel = State(initialValue: GamificationDashboardViewModel(
            gameService: services.gameService,
            achievementService: services.achievementService,
            challengeService: services.challengeService,
            levelService: services.levelProgressionService,
            motivationService: services.motivationService,
            errorHandlingService: services.errorHandlingService,
            user: user
        ))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with user level info
                headerView
                
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                contentView
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Геймификация")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.send(.profileTapped)
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.send(.showNotifications)
                    } label: {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.title2)
                            
                            if viewModel.unreadNotificationsCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .refreshable {
                viewModel.send(.refreshDashboard)
            }
            .onAppear {
                viewModel.send(.loadDashboard)
            }
        }
        .sheet(isPresented: .constant(viewModel.state.showingProfile)) {
            UserProfileView(user: viewModel.user)
        }
        .sheet(isPresented: .constant(viewModel.state.showingNotifications)) {
            NotificationsView(notifications: viewModel.state.recentNotifications) { notification in
                viewModel.send(.markNotificationAsRead(notification))
            }
        }
        .sheet(item: .constant(viewModel.state.showingAchievementDetail)) { achievement in
            AchievementDetailView(achievement: achievement) { achievement in
                viewModel.send(.claimReward(achievement))
            }
        }
        .sheet(item: .constant(viewModel.state.showingChallengeDetail)) { challenge in
            ChallengeDetailView(challenge: challenge) { challenge in
                viewModel.send(.joinChallenge(challenge))
            }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.state.error != nil)) {
            Button("OK") {
                viewModel.send(.dismissError)
            }
        } message: {
            if let error = viewModel.state.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // User level and XP
            HStack {
                VStack(alignment: .leading) {
                    Text("Уровень \(viewModel.currentLevel)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(viewModel.currentTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(viewModel.totalPoints)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("очков")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress to next level
            if viewModel.progressToNextLevel > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Прогресс к следующему уровню")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.progressToNextLevel * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: viewModel.progressToNextLevel)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 1.5)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.send(.tabChanged(tab))
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                            
                            Text(tab.title)
                                .font(.caption)
                        }
                        .frame(width: 80, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.state.selectedTab == tab ? Color.blue : Color.clear)
                        )
                        .foregroundColor(viewModel.state.selectedTab == tab ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch viewModel.state.selectedTab {
                case .overview:
                    overviewContent
                case .achievements:
                    achievementsContent
                case .challenges:
                    challengesContent
                case .progress:
                    progressContent
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Motivational message
            if let message = viewModel.state.dashboardData?.motivationalMessage {
                motivationalMessageCard(message)
            }
            
            // Recent achievements
            if let achievements = viewModel.state.dashboardData?.recentAchievements,
               !achievements.isEmpty {
                recentAchievementsCard(achievements)
            }
            
            // Active challenges
            if let challenges = viewModel.state.dashboardData?.activeChallenges,
               !challenges.isEmpty {
                activeChallengesCard(challenges)
            }
            
            // Points history
            if let pointsHistory = viewModel.state.dashboardData?.recentPointsHistory,
               !pointsHistory.isEmpty {
                pointsHistoryCard(pointsHistory)
            }
        }
    }
    
    // MARK: - Achievements Content
    
    private var achievementsContent: some View {
        VStack(spacing: 16) {
            if let achievements = viewModel.state.dashboardData?.recentAchievements,
               !achievements.isEmpty {
                ForEach(achievements) { achievement in
                    AchievementCardView(achievement: achievement) {
                        viewModel.send(.achievementTapped(achievement))
                    }
                }
            } else {
                emptyStateView(
                    icon: "star",
                    title: "Нет достижений",
                    subtitle: "Выполняйте привычки, чтобы получить первые достижения!"
                )
            }
        }
    }
    
    // MARK: - Challenges Content
    
    private var challengesContent: some View {
        VStack(spacing: 16) {
            // Available challenges
            if let challenges = viewModel.state.dashboardData?.availableChallenges,
               !challenges.isEmpty {
                ForEach(challenges) { challenge in
                    ChallengeCardView(challenge: challenge) {
                        viewModel.send(.challengeTapped(challenge))
                    }
                }
            } else {
                emptyStateView(
                    icon: "flag",
                    title: "Нет доступных вызовов",
                    subtitle: "Вызовы появятся здесь, когда они будут доступны"
                )
            }
        }
    }
    
    // MARK: - Progress Content
    
    private var progressContent: some View {
        VStack(spacing: 16) {
            // Level progress
            levelProgressCard
            
            // XP breakdown
            if let pointsHistory = viewModel.state.dashboardData?.recentPointsHistory,
               !pointsHistory.isEmpty {
                xpBreakdownCard(pointsHistory)
            }
        }
    }
    
    // MARK: - Card Views
    
    private func motivationalMessageCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "quote.bubble")
                    .foregroundColor(.green)
                
                Text("Мотивация дня")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func recentAchievementsCard(_ achievements: [Achievement]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                
                Text("Недавние достижения")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Все") {
                    viewModel.send(.tabChanged(.achievements))
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements) { achievement in
                        AchievementBadgeView(achievement: achievement) {
                            viewModel.send(.achievementTapped(achievement))
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func activeChallengesCard(_ challenges: [Challenge]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundColor(.red)
                
                Text("Активные вызовы")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Все") {
                    viewModel.send(.tabChanged(.challenges))
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ForEach(challenges.prefix(3)) { challenge in
                ChallengeRowView(challenge: challenge) {
                    viewModel.send(.challengeTapped(challenge))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func pointsHistoryCard(_ pointsHistory: [PointsHistory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                
                Text("Недавние очки")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ForEach(pointsHistory.prefix(5)) { points in
                PointsHistoryRowView(pointsHistory: points)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private var levelProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.green)
                
                Text("Прогресс уровня")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    viewModel.send(.levelDetailTapped)
                } label: {
                    Text("Детали")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Уровень \(viewModel.currentLevel)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(viewModel.totalPoints) XP")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if viewModel.progressToNextLevel > 0 {
                    ProgressView(value: viewModel.progressToNextLevel)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 1.5)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func xpBreakdownCard(_ pointsHistory: [PointsHistory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.orange)
                
                Text("Источники XP")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Simple breakdown by source
            let groupedPoints = Dictionary(grouping: pointsHistory, by: { $0.source })
            
            ForEach(Array(groupedPoints.keys), id: \.self) { source in
                let totalPoints = groupedPoints[source]?.reduce(0) { $0 + $1.totalPoints } ?? 0
                
                HStack {
                    Image(systemName: source.iconName)
                        .foregroundColor(.blue)
                    
                    Text(source.localizedName)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("+\(totalPoints)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - Empty State
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Загрузка...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
} 