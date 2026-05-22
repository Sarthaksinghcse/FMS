//
//  BottomTabBar.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI

struct DashboardBottomTabBar: View {
    /// 0 = Dashboard  |  1 = Tracking  |  2 = Manage
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 8) {
            tabButton(index: 0, icon: "square.grid.2x2.fill", label: "Dashboard")
            tabButton(index: 1, icon: "location.fill", label: "Tracking", rotateIcon: true)
            tabButton(index: 2, icon: "slider.horizontal.3", label: "Manage")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Glassmorphic background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Brand.primary.opacity(0.05),
                                AppTheme.Brand.primary.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: AppTheme.Shadow.card.opacity(0.15), radius: 20, x: 0, y: 10)
        .shadow(color: AppTheme.Shadow.card.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func tabButton(index: Int, icon: String, label: String, rotateIcon: Bool = false) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Background circle for selected state
                    if selectedTab == index {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppTheme.Brand.primary.opacity(0.15),
                                        AppTheme.Brand.primary.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Brand.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: selectedTab == index ? 20 : 18, weight: .semibold))
                        .rotationEffect(rotateIcon ? .degrees(45) : .zero)
                        .foregroundColor(selectedTab == index ? AppTheme.Brand.primary : AppTheme.Text.secondary)
                }
                .frame(height: 48)
                
                Text(label)
                    .font(.system(size: 11, weight: selectedTab == index ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedTab == index ? AppTheme.Brand.primary : AppTheme.Text.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        AppTheme.Background.page.ignoresSafeArea()
        VStack {
            Spacer()
            DashboardBottomTabBar(selectedTab: .constant(0))
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
    }
}
