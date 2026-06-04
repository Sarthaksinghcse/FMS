//
//  MaintenanceQuickActionCard.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

enum QuickActionTheme {
    case purple
    case peach
    case orange
    case green

    var gradient: LinearGradient {
        switch self {
        case .purple:
            return LinearGradient(
                colors: [Theme.royalBlue.opacity(0.12), Theme.royalBlue.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .peach:
            return LinearGradient(
                colors: [Theme.darkOrange.opacity(0.12), Theme.darkOrange.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .orange:
            return LinearGradient(
                colors: [Theme.darkOrange.opacity(0.20), Theme.darkOrange.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .green:
            return LinearGradient(
                colors: [Theme.royalBlue.opacity(0.22), Theme.royalBlue.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var accentColor: Color {
        switch self {
        case .purple: return Theme.royalBlue
        case .peach:  return Theme.darkOrange
        case .orange: return Theme.darkOrange
        case .green:  return Theme.royalBlue
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let theme: QuickActionTheme
    var badgeCount: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon Row
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                        .foregroundColor(theme.accentColor)
                }
                
                Spacer()
                
                if let badge = badgeCount, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.Status.danger)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 14)

            Spacer()

            // Labels
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                    .lineLimit(1)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(.bottom, 14)
            .padding(.horizontal, 14)
        }
        .frame(height: 104)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.gradient)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: theme.accentColor.opacity(0.04), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
        )
    }
}

// Custom tactile button style
struct TactileScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
