




import SwiftUI

struct DashboardStatCard: View {
    let stat: DashboardStat
    @ObservedObject private var accessibility = AccessibilityManager.shared

    private var cardDescription: String {
        switch stat.label {
        case "Total Vehicles":
            return "All vehicles in your fleet"
        case "Ready Vehicles":
            return "Vehicles ready to assign"
        case "Drivers Online":
            return "Active drivers right now"
        case "Live Trips":
            return "Trips in progress"
        default:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) { // Reduced spacing to give text more room
                // Icon circle
                ZStack {
                    Circle()
                        .fill(stat.iconBgColor)
                        .frame(width: 40, height: 40) // Slightly smaller icon container
                    
                    if stat.icon == "checkmark.circle.fill" {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                .foregroundColor(stat.iconColor)
                        }
                    } else {
                        Image(systemName: stat.icon)
                            .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                            .foregroundColor(stat.iconColor)
                    }
                }
                
                // Text columns
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.label)
                        .font(.system(size: 12.5 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                        .foregroundColor(AppTheme.Text.primary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9) // Higher scale factor to ensure uniformity
                    
                    Text(stat.value)
                        .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                        .foregroundColor(stat.iconColor)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // Chevron icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                    .foregroundColor(stat.iconColor)
            }
            
            // Description subtitle (Full width, no divider line)
            Text(cardDescription)
                .font(.system(size: 11.5 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .regular))
                .foregroundColor(AppTheme.Text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(AppTheme.Background.card)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.015), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.05), lineWidth: 0.8)
        )
        .applyHighContrastBorder(cornerRadius: 16)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        DashboardStatCard(stat: DashboardMockData.stats[0])
        DashboardStatCard(stat: DashboardMockData.stats[3])
    }
    .padding()
    .background(AppTheme.Background.page)
}
