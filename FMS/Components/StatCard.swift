




import SwiftUI

struct DashboardStatCard: View {
    let stat: DashboardStat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle()
                    .fill(stat.iconBgColor)
                    .frame(width: 36, height: 36)
                Image(systemName: stat.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(stat.iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text(stat.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
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
