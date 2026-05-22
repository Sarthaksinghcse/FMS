//
//  StatCard.swift
//  FMS
//

import SwiftUI

struct DashboardStatCard: View {
    let stat: DashboardStat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(stat.iconBgColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: stat.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(stat.iconColor)
            }
            
            Spacer()
                .frame(height: 2)
            
            Text(stat.value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)
            
            Text(stat.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
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
