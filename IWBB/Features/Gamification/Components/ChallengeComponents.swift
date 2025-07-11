import SwiftUI

// MARK: - ChallengeCardView

struct ChallengeCardView: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(challenge.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Difficulty badge
                    difficultyBadge
                }
                
                // Challenge details
                HStack {
                    // Duration
                    Label {
                        Text("\(challenge.duration.days) дней")
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Participants
                    Label {
                        Text("\(challenge.participantCount)")
                    } icon: {
                        Image(systemName: "person.2")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Rewards
                    Label {
                        Text("\(challenge.rewards.points)")
                    } icon: {
                        Image(systemName: "star.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.yellow)
                }
                
                // Progress bar or end date
                if challenge.isActive {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Прогресс")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(challenge.progress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        ProgressView(value: challenge.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .scaleEffect(y: 1.2)
                    }
                } else {
                    HStack {
                        Text("Заканчивается:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(challenge.endDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(challenge.isActive ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var difficultyBadge: some View {
        Text(challenge.difficulty.localizedName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(challenge.difficulty.color)
            )
            .foregroundColor(.white)
    }
}

// MARK: - ChallengeRowView

struct ChallengeRowView: View {
    let challenge: Challenge
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Challenge icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(challenge.difficulty.color)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: challenge.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                
                // Challenge info
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(challenge.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack {
                        Text("\(challenge.duration.days)д")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(challenge.rewards.points) очков")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Progress or status
                if challenge.isActive {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(challenge.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        ProgressView(value: challenge.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .frame(width: 40)
                            .scaleEffect(y: 0.8)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - PointsHistoryRowView

struct PointsHistoryRowView: View {
    let pointsHistory: PointsHistory
    
    var body: some View {
        HStack(spacing: 12) {
            // Source icon
            Image(systemName: pointsHistory.source.iconName)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            // Points info
            VStack(alignment: .leading, spacing: 2) {
                Text(pointsHistory.reason)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(pointsHistory.source.localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Points and date
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(pointsHistory.totalPoints)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(pointsHistory.earnedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - NotificationsView

struct NotificationsView: View {
    let notifications: [GamificationNotification]
    let onMarkAsRead: (GamificationNotification) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(notifications) { notification in
                    NotificationRowView(notification: notification) {
                        onMarkAsRead(notification)
                    }
                }
            }
            .navigationTitle("Уведомления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        // Dismiss handled by parent
                    }
                }
            }
        }
    }
}

// MARK: - NotificationRowView

struct NotificationRowView: View {
    let notification: GamificationNotification
    let onMarkAsRead: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Notification icon
            ZStack {
                Circle()
                    .fill(notification.type.color)
                    .frame(width: 36, height: 36)
                
                Image(systemName: notification.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            
            // Notification content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Read indicator
            if !notification.isRead {
                Button(action: onMarkAsRead) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
        .background(notification.isRead ? Color.clear : Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Supporting Extensions

extension ChallengeDifficulty {
    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        case .expert: return .purple
        }
    }
    
    var localizedName: String {
        switch self {
        case .easy: return "Легко"
        case .medium: return "Средне"
        case .hard: return "Сложно"
        case .expert: return "Эксперт"
        }
    }
}

extension GamificationNotification.NotificationType {
    var color: Color {
        switch self {
        case .achievement: return .yellow
        case .levelUp: return .green
        case .challenge: return .blue
        case .streak: return .orange
        case .motivation: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .achievement: return "star.fill"
        case .levelUp: return "arrow.up.circle.fill"
        case .challenge: return "flag.fill"
        case .streak: return "flame.fill"
        case .motivation: return "heart.fill"
        }
    }
}

// MARK: - Placeholder Detail Views

struct AchievementDetailView: View {
    let achievement: Achievement
    let onClaimReward: (Achievement) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Large achievement icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: achievement.colorHex) ?? .blue)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: achievement.iconName)
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    
                    // Achievement details
                    VStack(spacing: 8) {
                        Text(achievement.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(achievement.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Text(achievement.rarity.localizedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: achievement.rarity.colorHex) ?? .gray)
                                )
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(achievement.points) очков")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    
                    if achievement.isUnlocked {
                        Button {
                            onClaimReward(achievement)
                        } label: {
                            Text("Получить награду")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Достижение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        // Dismiss handled by parent
                    }
                }
            }
        }
    }
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    let onJoinChallenge: (Challenge) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Challenge header
                    VStack(spacing: 12) {
                        Text(challenge.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(challenge.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Text(challenge.difficulty.localizedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(challenge.difficulty.color)
                                )
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(challenge.duration.days) дней")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Challenge stats
                    HStack {
                        VStack {
                            Text("\(challenge.participantCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Участников")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("\(challenge.rewards.points)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                            Text("Очков")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 1)
                    
                    // Join button
                    Button {
                        onJoinChallenge(challenge)
                    } label: {
                        Text("Присоединиться")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Вызов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        // Dismiss handled by parent
                    }
                }
            }
        }
    }
}

// MARK: - UserProfileView Placeholder

struct UserProfileView: View {
    let user: User
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Профиль пользователя")
                    .font(.title)
                Text(user.name)
                    .font(.headline)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        // Dismiss handled by parent
                    }
                }
            }
        }
    }
} 