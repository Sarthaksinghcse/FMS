//
//  ActivityRow.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI

struct DashboardActivityRow: View {
    let activity: DashboardActivity

    var body: some View {
        HStack(spacing: 12) {
            // Left Side: Colored Circle Icon
            ZStack {
                Circle()
                    .fill(activity.iconBgColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: activity.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(activity.iconColor)
            }
            
            // Center Stack: Title and Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(activity.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right Side: Timestamp
            Text(activity.time)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
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
