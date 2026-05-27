//
//  MaintenanceHeaderView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI

struct MaintenanceHeaderView: View {
    let title: String
    let subtitle: String
    var initials: String = ""
    var avatarColor: Color = .gray
    var notificationCount: Int = 0
    var showProfileAndNotification: Bool = true
    var showActions: Bool = false

    var body: some View {
        HStack {
            // Leading Header Title
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            
            Spacer()
            
            if showProfileAndNotification {
                // Right Pill Container (Bell and Avatar)
                HStack(spacing: 12) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Text.primary)
                        
                        if notificationCount > 0 {
                            Text("\(notificationCount)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppTheme.Text.onDark)
                                .frame(width: 14, height: 14)
                                .background(AppTheme.Status.danger)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [avatarColor, avatarColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 30, height: 30)
                        Text(initials)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.onDark)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Background.card)
                .clipShape(Capsule())
                .shadow(color: AppTheme.Text.primary.opacity(0.04), radius: 6, x: 0, y: 3)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Text.primary.opacity(0.05), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

#Preview {
    MaintenanceHeaderView(
        title: "Inventory",
        subtitle: "Manage spare parts and monitor stock levels.",
        initials: "RK",
        avatarColor: AppTheme.Brand.violet,
        notificationCount: 3,
        showProfileAndNotification: true,
        showActions: false
    )
    .background(AppTheme.Background.page)
}
