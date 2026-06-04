import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct FleetManagerProfileView: View {

    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss
    @State private var showEditProfile = false
    @State private var showNotificationSettings = false
    @State private var showSecuritySettings = false
    @State private var showAccessibilitySettings = false
    @State private var showHelpSupport = false
    @State private var showAbout = false
    @State private var showSignOutConfirm = false
    @State private var signOutError: String?
    @State private var isSigningOut = false

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        guard let name = user?.name else { return "FM" }
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
                        accountSettingsSection
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
                FleetManagerEditProfileView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                FMNotificationSettingsView()
            }
            .sheet(isPresented: $showSecuritySettings) {
                FMSecuritySettingsView()
            }
            .sheet(isPresented: $showHelpSupport) {
                FMHelpSupportView()
            }
            .sheet(isPresented: $showAccessibilitySettings) {
                AccessibilitySettingsView(role: .fleetManager)
            }
            .sheet(isPresented: $showAbout) {
                FMAboutView()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    isSigningOut = true
                    // Dismiss the sheet FIRST, then sign out.
                    // This prevents SwiftUI from getting stuck trying to
                    // tear down a view that has an active presented sheet.
                    dismiss()
                    Task {
                        // Small delay to let the sheet dismiss animation complete
                        try? await Task.sleep(for: .milliseconds(350))
                        do {
                            try await supabase.signOut()
                        } catch {
                            await MainActor.run {
                                signOutError = error.localizedDescription
                                isSigningOut = false
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your Fleet Manager account?")
            }
            .alert("Sign Out Failed", isPresented: Binding(
                get: { signOutError != nil },
                set: { if !$0 { signOutError = nil } }
            )) {
                Button("OK", role: .cancel) { signOutError = nil }
            } message: {
                Text(signOutError ?? "")
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
                                colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: AppTheme.Brand.primary.opacity(0.35), radius: 16, y: 6)

                    if let imageURLString = user?.profileImage, let imageURL = URL(string: imageURLString) {
                        CachedAsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Text(initials)
                                .font(.system(size: 32 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 90, height: 90, alignment: .center)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                    } else {
                        Text(initials)
                            .font(.system(size: 32 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 90, height: 90, alignment: .center)
                    }
                }

                VStack(spacing: 6) {
                    Text(user?.name ?? "Fleet Manager")
                        .font(.system(size: 22 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)

                    Text(user?.email ?? "manager@fms.com")
                        .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                        Text("Fleet Manager")
                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppTheme.Brand.primary.opacity(0.10))
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
                    .font(.system(size: 28 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(AppTheme.Brand.primary)
            }
            .padding(12)
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
    }

    // MARK: - Account Settings

    private var accountSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Settings")
                .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ProfileSettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: AppTheme.Status.danger,
                    iconBg: AppTheme.IconBg.red,
                    title: "Notifications",
                    subtitle: "Manage alert preferences"
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

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "info.circle.fill",
                    iconColor: AppTheme.Text.tertiary,
                    iconBg: AppTheme.IconBg.gray,
                    title: "About",
                    subtitle: "App version & legal"
                ) {
                    showAbout = true
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
                    .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
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
    FleetManagerProfileView()
        .environment(SupabaseManager.shared)
}
