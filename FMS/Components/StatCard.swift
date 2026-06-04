




import SwiftUI

struct DashboardStatCard: View {
    let stat: DashboardStat

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
            HStack(spacing: 8) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(stat.iconBgColor)
                        .frame(width: 44, height: 44)
                    
                    if stat.icon == "checkmark.circle.fill" {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(stat.iconColor)
                        }
                    } else {
                        Image(systemName: stat.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(stat.iconColor)
                    }
                }
                
                // Text columns
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Text.primary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text(stat.value)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(stat.iconColor)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                // Chevron icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(stat.iconColor)
            }
            
            // Description subtitle (Full width, no divider line)
            Text(cardDescription)
                .font(.system(size: 11.5, weight: .regular))
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
                .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
        )
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
