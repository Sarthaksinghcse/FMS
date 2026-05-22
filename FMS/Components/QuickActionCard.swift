//
//  QuickActionCard.swift
//  FMS
//
//  Created by Priyanshu Namdev on 21/05/26.
//

import SwiftUI

struct DashboardQuickActionCard: View {
    let action: DashboardQuickAction
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Rounded square pastel icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(action.bgColor)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(action.iconColor)
                }
                
                // Label Text below
                Text(action.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 70) // Fixed width to ensure even spacing and wrapped text alignment
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack(spacing: 12) {
        DashboardQuickActionCard(action: DashboardMockData.quickActions[0])
        DashboardQuickActionCard(action: DashboardMockData.quickActions[1])
        DashboardQuickActionCard(action: DashboardMockData.quickActions[2])
    }
    .padding()
}
