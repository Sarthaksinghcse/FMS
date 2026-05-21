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
                .foregroundColor(selectedTab == 0 ? Color(red: 0.2, green: 0.5, blue: 1.0) : Color.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedTab == 0 ? Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.1) : Color.clear)
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
                        .rotationEffect(.degrees(45)) // Align diagonal arrow
                    Text("Tracking")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(selectedTab == 1 ? Color(red: 0.2, green: 0.5, blue: 1.0) : Color.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(selectedTab == 1 ? Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.1) : Color.clear)
                )
            }
        }
        .padding(6)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color(red: 0.97, green: 0.98, blue: 1.0)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            DashboardBottomTabBar(selectedTab: .constant(0))
                .padding(.bottom, 20)
        }
    }
}
