import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct MaintenanceProfileView: View {

    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var showEditProfile = false
    @State private var showWorkHistory = false
    @State private var showSpecializations = false
    @State private var showNotificationSettings = false
    @State private var showSecuritySettings = false
    @State private var showAccessibilitySettings = false
    @State private var showHelpSupport = false
    @State private var showSignOutConfirm = false

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        guard let name = user?.name, !name.isEmpty else { return "MP" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }



    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileHeaderCard
                        accountSection
                        signOutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                MaintenanceEditProfileView()
            }
            .sheet(isPresented: $showWorkHistory) {
                MaintenanceWorkHistoryView()
            }
            .sheet(isPresented: $showSpecializations) {
                MaintenanceSpecializationsView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                MaintenanceNotificationSettingsView()
            }
            .sheet(isPresented: $showSecuritySettings) {
                MaintenanceSecuritySettingsView()
            }
            .sheet(isPresented: $showHelpSupport) {
                MaintenanceHelpSupportView()
            }
            .sheet(isPresented: $showAccessibilitySettings) {
                AccessibilitySettingsView(role: .maintenance)
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        try? await supabase.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your Maintenance account?")
            }
        }
    }

    // MARK: - Header

    private var profileHeaderCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Brand.amber, Color(red: 0.95, green: 0.50, blue: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: AppTheme.Brand.amber.opacity(0.35), radius: 16, y: 6)

                    if let profileImage = user?.profileImage, let url = URL(string: profileImage) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 90, height: 90)
                                    .clipShape(Circle())
                            } else if phase.error != nil {
                                Text(initials)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            } else {
                                ProgressView()
                            }
                        }
                    } else {
                        Text(initials)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: 6) {
                    Text(user?.name ?? "Maintenance Personnel")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)

                    Text(user?.email ?? "maintenance@fms.com")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)

                    if let phone = user?.phoneNumber, !phone.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 10))
                            Text(phone)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Text.tertiary)
                        .padding(.top, 2)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Maintenance Personnel")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Brand.amber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppTheme.Brand.amber.opacity(0.10))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)

            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(AppTheme.Brand.amber)
            }
            .padding(12)
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
    }



    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ProfileSettingsRow(
                    icon: "wrench.and.screwdriver.fill",
                    iconColor: AppTheme.Brand.amber,
                    iconBg: AppTheme.IconBg.amber,
                    title: "Specializations",
                    subtitle: "View skills & certifications"
                ) {
                    showSpecializations = true
                }

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: AppTheme.Brand.primary,
                    iconBg: AppTheme.IconBg.blue,
                    title: "Work History",
                    subtitle: "View completed work orders & history"
                ) {
                    showWorkHistory = true
                }

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: AppTheme.Status.danger,
                    iconBg: AppTheme.IconBg.red,
                    title: "Notifications",
                    subtitle: "Work order & inventory alerts"
                ) {
                    showNotificationSettings = true
                }

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "lock.shield.fill",
                    iconColor: AppTheme.Brand.primaryDeep,
                    iconBg: AppTheme.IconBg.indigo,
                    title: "Security",
                    subtitle: "Password & authentication"
                ) {
                    showSecuritySettings = true
                }

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "accessibility.fill",
                    iconColor: AppTheme.Brand.primary,
                    iconBg: AppTheme.Brand.primary.opacity(0.12),
                    title: "Accessibility",
                    subtitle: "Speech, Contrast, Layout settings"
                ) {
                    showAccessibilitySettings = true
                }

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: AppTheme.Brand.teal,
                    iconBg: AppTheme.IconBg.teal,
                    title: "Help & Support",
                    subtitle: "FAQs, contact support"
                ) {
                    showHelpSupport = true
                }
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AppTheme.Status.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Status.danger.opacity(0.08))
            .cornerRadius(AppTheme.Radius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}



@available(iOS 26.0, *)
#Preview {
    MaintenanceProfileView()
        .environment(SupabaseManager.shared)
}
