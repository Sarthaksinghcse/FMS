//
//  BottomTabBar.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI

struct DashboardBottomTabBar: View {
    @Binding var selectedTab: Int // 0 for Dashboard, 1 for Tracking

    var body: some View {
        HStack(spacing: 8) {
            // Tab 1: Dashboard
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Dashboard")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(selectedTab == 0 ? AppTheme.Brand.primary : AppTheme.Text.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedTab == 0 ? AppTheme.IconBg.blue : Color.clear)
                )
            }

            // Tab 2: Tracking
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .rotationEffect(.degrees(45))
                    Text("Tracking")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(selectedTab == 1 ? AppTheme.Brand.primary : AppTheme.Text.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedTab == 1 ? AppTheme.IconBg.blue : Color.clear)
                )
            }
        }
        .padding(6)
        .background(AppTheme.Background.card)
        .clipShape(Capsule())
        .shadow(color: AppTheme.Shadow.card, radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        AppTheme.Background.page
            .ignoresSafeArea()

        VStack {
            Spacer()
            DashboardBottomTabBar(selectedTab: .constant(0))
                .padding(.bottom, 20)
        }
    }
}
