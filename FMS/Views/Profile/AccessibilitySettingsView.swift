import SwiftUI

@available(iOS 26.0, *)
struct AccessibilitySettingsView: View {
    let role: UserRole
    @ObservedObject var manager = AccessibilityManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "accessibility.fill",
                            iconColor: AppTheme.Brand.primary,
                            title: "Accessibility Settings",
                            subtitle: "Enable features tailored to your workflow"
                        )
                        
                        // ── 1. Global Accessibility Section ─────────────────────────────
                        globalSettingsSection
                        
                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Accessibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Global Settings Section
    private var globalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GLOBAL SETTINGS")
                .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                .foregroundColor(AppTheme.Text.secondary)
                .tracking(0.6)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                ProfileToggleRow(
                    icon: "textformat.size",
                    iconColor: AppTheme.Brand.primary,
                    title: "Large Text",
                    subtitle: "Increases font size across the app",
                    isOn: $manager.isLargeTextEnabled,
                    tintColor: AppTheme.Brand.primary
                )
                
                Divider().padding(.leading, 66)
                
                ProfileToggleRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: AppTheme.Brand.violet,
                    title: "High Contrast",
                    subtitle: "Stark colors and outlines for controls",
                    isOn: $manager.isHighContrastEnabled,
                    tintColor: AppTheme.Brand.primary
                )
                
                Divider().padding(.leading, 66)
                
                colorBlindModeRow
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
    }
    
    private var colorBlindModeRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "eye.fill")
                .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(AppTheme.Brand.teal)
                .frame(width: 36, height: 36)
                .background(AppTheme.Brand.teal.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Color Correction")
                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                    .foregroundColor(AppTheme.Text.primary)
                Text("Adjust status badges colors")
                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            
            Spacer()
            
            Picker("Mode", selection: $manager.colorBlindMode) {
                ForEach(ColorBlindType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .accentColor(AppTheme.Brand.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
