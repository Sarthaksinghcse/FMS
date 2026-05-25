import SwiftUI

struct DashboardActivityRow: View {
    let activity: DashboardActivity

    // Source badge color
    private var sourceColor: Color {
        switch activity.source {
        case "Driver":        return AppTheme.Brand.teal
        case "Fleet Manager": return AppTheme.Brand.violet
        default:              return AppTheme.Brand.accent
        }
    }

    private var sourceIcon: String {
        switch activity.source {
        case "Driver":        return "person.fill"
        case "Fleet Manager": return "briefcase.fill"
        default:              return "gear"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon bubble
            ZStack {
                Circle()
                    .fill(activity.iconBgColor)
                    .frame(width: 38, height: 38)
                Image(systemName: activity.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(activity.iconColor)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(1)

                Text(activity.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)

                // Source badge
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon)
                        .font(.system(size: 8, weight: .bold))
                    Text(activity.source)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(sourceColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(sourceColor.opacity(0.10))
                .clipShape(Capsule())
            }

            Spacer()

            Text(activity.time)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppTheme.Text.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 0) {
        DashboardActivityRow(activity: DashboardActivity(
            title: "Trip TRIP-1842 Started",
            subtitle: "Priyanshu Namdev → Nehru Place",
            time: "2m ago",
            icon: "arrow.turn.up.right",
            iconColor: AppTheme.Brand.primary,
            iconBgColor: AppTheme.IconBg.blue,
            source: "Driver",
            date: Date()
        ))
        Divider().padding(.leading, 66)
        DashboardActivityRow(activity: DashboardActivity(
            title: "Work Order: Brake Pad Replacement",
            subtitle: "Tata Ace Gold • In Progress",
            time: "1h ago",
            icon: "wrench.and.screwdriver.fill",
            iconColor: AppTheme.Brand.violet,
            iconBgColor: AppTheme.IconBg.violet,
            source: "Fleet Manager",
            date: Date().addingTimeInterval(-3600)
        ))
    }
    .background(AppTheme.Background.card)
    .cornerRadius(AppTheme.Radius.large)
    .padding()
    .background(AppTheme.Background.page)
}
