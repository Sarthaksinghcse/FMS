






import SwiftUI

struct DashboardQuickActionCard: View {
    let action: DashboardQuickAction
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(action.bgColor)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                        .foregroundColor(action.iconColor)
                }
                
                
                Text(action.label)
                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
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
