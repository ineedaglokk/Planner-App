import SwiftUI

// MARK: - AchievementCardView

struct AchievementCardView: View {
    let achievement: Achievement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Achievement icon
                ZStack {
                    Circle()
                        .fill(Color(hex: achievement.colorHex) ?? .blue)
                        .frame(width: 60, height: 60)
                        .opacity(achievement.isUnlocked ? 1.0 : 0.3)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .opacity(achievement.isUnlocked ? 1.0 : 0.5)
                    
                    // Lock overlay for locked achievements
                    if !achievement.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 20, height: 20)
                            )
                            .offset(x: 20, y: 20)
                    }
                }
                
                // Achievement info
                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        // Rarity badge
                        rarityBadge
                        
                        Spacer()
                        
                        // Points
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text("\(achievement.points)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Progress indicator
                if let progress = achievement.progressForUser(achievement.userID) {
                    VStack(spacing: 4) {
                        CircularProgressView(progress: progress.progressPercentage)
                            .frame(width: 40, height: 40)
                        
                        Text(progress.progressString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(achievement.isUnlocked ? Color(hex: achievement.colorHex) ?? .blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var rarityBadge: some View {
        Text(achievement.rarity.localizedName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: achievement.rarity.colorHex) ?? .gray)
            )
            .foregroundColor(.white)
    }
}

// MARK: - AchievementBadgeView

struct AchievementBadgeView: View {
    let achievement: Achievement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Achievement icon
                ZStack {
                    Circle()
                        .fill(Color(hex: achievement.colorHex) ?? .blue)
                        .frame(width: 50, height: 50)
                        .opacity(achievement.isUnlocked ? 1.0 : 0.3)
                    
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .opacity(achievement.isUnlocked ? 1.0 : 0.5)
                    
                    // Lock overlay for locked achievements
                    if !achievement.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 16, height: 16)
                            )
                            .offset(x: 15, y: 15)
                    }
                }
                
                // Achievement title
                Text(achievement.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
                
                // Points
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    
                    Text("\(achievement.points)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - CircularProgressView

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.2)
                .foregroundColor(.gray)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
        }
    }
}

// MARK: - Color Extension

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