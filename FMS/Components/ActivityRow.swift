//
//  ActivityRow.swift
//  FMS
//

import SwiftUI

struct DashboardActivityRow: View {
    let activity: DashboardActivity

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.iconBgColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(activity.iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text(activity.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(activity.time)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(AppTheme.Text.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack(spacing: 0) {
        DashboardActivityRow(activity: DashboardMockData.activities[0])
        Divider().padding(.leading, 60)
        DashboardActivityRow(activity: DashboardMockData.activities[1])
        Divider().padding(.leading, 60)
        DashboardActivityRow(activity: DashboardMockData.activities[2])
    }
    .background(AppTheme.Background.card)
    .cornerRadius(AppTheme.Radius.large)
    .padding()
    .background(AppTheme.Background.page)
}
