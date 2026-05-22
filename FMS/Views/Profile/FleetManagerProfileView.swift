//
//  FleetManagerProfileView.swift
//  FMS
//
//  Profile main screen for Fleet Manager role.
//  Shows personal info, fleet overview stats, and quick-access settings.
//

import SwiftUI
import SwiftData

// MARK: - Fleet Manager Profile View

@available(iOS 26.0, *)
struct FleetManagerProfileView: View {

    @StateObject private var supabase = SupabaseManager.shared
    @State private var showEditProfile = false
    @State private var showNotificationSettings = false
    @State private var showSecuritySettings = false
    @State private var showHelpSupport = false
    @State private var showAbout = false
    @State private var showSignOutConfirm = false

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
            .sheet(isPresented: $showAbout) {
                FMAboutView()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { try? await supabase.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your Fleet Manager account?")
            }
        }
    }

    // MARK: - Profile Header Card

    private var profileHeaderCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 20) {
                // Avatar
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

                    Text(initials)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Name & Email
                VStack(spacing: 6) {
                    Text(user?.name ?? "Fleet Manager")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)

                    Text(user?.email ?? "manager@fms.com")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)

                    // Role Badge
                    HStack(spacing: 6) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Fleet Manager")
                            .font(.system(size: 12, weight: .semibold))
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

            // Edit Profile Button (Top-Right)
            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Edit")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(AppTheme.Brand.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.Brand.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
    }



    // MARK: - Account & Settings

    private var accountSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Settings")
                .font(.system(size: 18, weight: .bold))
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

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "lock.shield.fill",
                    iconColor: AppTheme.Brand.primaryDeep,
                    iconBg: AppTheme.IconBg.indigo,
                    title: "Security",
                    subtitle: "Password & authentication"
                ) {
                    showSecuritySettings = true
                }

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: AppTheme.Brand.teal,
                    iconBg: AppTheme.IconBg.teal,
                    title: "Help & Support",
                    subtitle: "FAQs, contact support"
                ) {
                    showHelpSupport = true
                }

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "info.circle.fill",
                    iconColor: AppTheme.Text.tertiary,
                    iconBg: Color.gray.opacity(0.10),
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

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    FleetManagerProfileView()
}
