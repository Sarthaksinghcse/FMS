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
                            subtitle: "Enable features tailored to your workflow as a \(role.displayName)"
                        )
                        
                        // ── 1. Global Accessibility Section ─────────────────────────────
                        globalSettingsSection
                        
                        // ── 2. Role-Specific Accessibility Section ───────────────────────
                        roleSpecificSection
                        
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
                            .font(.system(size: 15, weight: .bold))
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
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Text.secondary)
                .tracking(0.6)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                ProfileToggleRow(
                    icon: "textformat.size",
                    iconColor: AppTheme.Brand.primary,
                    title: "Large Text",
                    subtitle: "Scale font sizes up for improved legibility",
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
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Brand.teal)
                .frame(width: 36, height: 36)
                .background(AppTheme.Brand.teal.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Color Correction")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Text.primary)
                Text("Adjust status badges colors")
                    .font(.system(size: 12))
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
    
    // MARK: - Role-Specific Section
    private var roleSpecificSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(role.displayName.uppercased()) FEATURES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Text.secondary)
                .tracking(0.6)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                switch role {
                case .driver:
                    ProfileToggleRow(
                        icon: "hand.tap.fill",
                        iconColor: AppTheme.Status.success,
                        title: "Large Tap Targets",
                        subtitle: "Increase size of buttons on active trip cards",
                        isOn: $manager.driverLargeTapTargets,
                        tintColor: AppTheme.Status.success
                    )
                    
                    Divider().padding(.leading, 66)
                    
                    ProfileToggleRow(
                        icon: "speaker.wave.3.fill",
                        iconColor: AppTheme.Brand.amber,
                        title: "Voice Assistance",
                        subtitle: "Announce navigation and geofence alerts",
                        isOn: $manager.driverAudioPrompts,
                        tintColor: AppTheme.Status.success
                    )
                    
                    Divider().padding(.leading, 66)
                    
                    ProfileToggleRow(
                        icon: "light.beacon.max.fill",
                        iconColor: AppTheme.Status.danger,
                        title: "Screen Flash Alerts",
                        subtitle: "Flashes the screen on urgent alerts",
                        isOn: $manager.driverScreenFlashAlerts,
                        tintColor: AppTheme.Status.success
                    )
                    
                case .fleetManager:
                    ProfileToggleRow(
                        icon: "eyes",
                        iconColor: AppTheme.Brand.primary,
                        title: "Color Blind Badges",
                        subtitle: "Add text labels & strict filters to status symbols",
                        isOn: $manager.fleetColorFilterStatus,
                        tintColor: AppTheme.Brand.primary
                    )
                    
                    Divider().padding(.leading, 66)
                    
                    ProfileToggleRow(
                        icon: "quote.bubble.fill",
                        iconColor: AppTheme.Brand.teal,
                        title: "Speak Voice Logs",
                        subtitle: "Reads aloud transcript text when clicked",
                        isOn: $manager.fleetSpeakLogs,
                        tintColor: AppTheme.Brand.primary
                    )
                    
                case .maintenance:
                    ProfileToggleRow(
                        icon: "sun.max.fill",
                        iconColor: AppTheme.Brand.amber,
                        title: "Outdoor Contrast",
                        subtitle: "High contrast outline cells for direct sunlight",
                        isOn: $manager.maintenanceOutdoorContrast,
                        tintColor: AppTheme.Brand.amber
                    )
                    
                    Divider().padding(.leading, 66)
                    
                    ProfileToggleRow(
                        icon: "list.bullet.rectangle.portrait",
                        iconColor: AppTheme.Brand.violet,
                        title: "Speak Checklist Tasks",
                        subtitle: "Reads aloud work order items",
                        isOn: $manager.maintenanceSpeakTasks,
                        tintColor: AppTheme.Brand.amber
                    )
                }
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
    }
}
