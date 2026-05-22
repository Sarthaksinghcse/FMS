//
//  FleetManagerInnerScreens.swift
//  FMS
//
//  Inner screens for Fleet Manager profile:
//  - Notification Settings
//  - Security Settings
//  - Help & Support
//  - About
//

import SwiftUI

// MARK: - Notification Settings

@available(iOS 26.0, *)
struct FMNotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tripAlerts = true
    @State private var maintenanceAlerts = true
    @State private var driverAlerts = true
    @State private var sosAlerts = true
    @State private var dailySummary = false
    @State private var soundEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "bell.badge.fill",
                            iconColor: AppTheme.Status.danger,
                            title: "Notifications",
                            subtitle: "Choose which alerts you receive"
                        )

                        // Fleet Alerts
                        VStack(alignment: .leading, spacing: 0) {
                            Text("FLEET ALERTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ProfileToggleRow(
                                    icon: "arrow.triangle.swap",
                                    iconColor: AppTheme.Brand.teal,
                                    title: "Trip Assignments",
                                    subtitle: "New trips and schedule changes",
                                    isOn: $tripAlerts
                                )
                                Divider().padding(.leading, 66)

                                ProfileToggleRow(
                                    icon: "wrench.fill",
                                    iconColor: AppTheme.Brand.amber,
                                    title: "Maintenance Alerts",
                                    subtitle: "Service due, work order updates",
                                    isOn: $maintenanceAlerts
                                )
                                Divider().padding(.leading, 66)

                                ProfileToggleRow(
                                    icon: "person.2.fill",
                                    iconColor: AppTheme.Brand.violet,
                                    title: "Driver Updates",
                                    subtitle: "Driver status and inspection reports",
                                    isOn: $driverAlerts
                                )
                                Divider().padding(.leading, 66)

                                ProfileToggleRow(
                                    icon: "exclamationmark.octagon.fill",
                                    iconColor: AppTheme.Status.danger,
                                    title: "SOS Alerts",
                                    subtitle: "Emergency signals from drivers",
                                    isOn: $sosAlerts
                                )
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        // General
                        VStack(alignment: .leading, spacing: 0) {
                            Text("GENERAL")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ProfileToggleRow(
                                    icon: "chart.bar.fill",
                                    iconColor: AppTheme.Brand.primary,
                                    title: "Daily Summary",
                                    subtitle: "Fleet performance digest at 8 PM",
                                    isOn: $dailySummary
                                )
                                Divider().padding(.leading, 66)

                                ProfileToggleRow(
                                    icon: "speaker.wave.2.fill",
                                    iconColor: AppTheme.Text.tertiary,
                                    title: "Sounds",
                                    subtitle: "Play notification sounds",
                                    isOn: $soundEnabled
                                )
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
}

// MARK: - Security Settings

@available(iOS 26.0, *)
struct FMSecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var biometricEnabled = true
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "lock.shield.fill",
                            iconColor: AppTheme.Brand.primaryDeep,
                            title: "Security",
                            subtitle: "Manage password & authentication"
                        )

                        // Change Password
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CHANGE PASSWORD")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                SecureFormField(label: "Current Password", text: $currentPassword)
                                Divider().padding(.leading, 16)
                                SecureFormField(label: "New Password", text: $newPassword)
                                Divider().padding(.leading, 16)
                                SecureFormField(label: "Confirm New Password", text: $confirmPassword)
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        // Authentication
                        VStack(alignment: .leading, spacing: 0) {
                            Text("AUTHENTICATION")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ProfileToggleRow(
                                    icon: "faceid",
                                    iconColor: AppTheme.Brand.primary,
                                    title: "Face ID / Touch ID",
                                    subtitle: "Use biometrics to unlock",
                                    isOn: $biometricEnabled
                                )
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        // Update Button
                        Button {
                            isSaving = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isSaving = false
                                showSaved = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.white)
                                }
                                Text(isSaving ? "Updating..." : "Update Password")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.Brand.primary)
                            .cornerRadius(AppTheme.Radius.medium)
                        }
                        .disabled(isSaving || newPassword.isEmpty)
                        .opacity(newPassword.isEmpty ? 0.5 : 1)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .alert("Password Updated", isPresented: $showSaved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your password has been changed successfully.")
            }
        }
    }
}

// MARK: - Secure Form Field

private struct SecureFormField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Text.tertiary)
            SecureField(label, text: $text)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Text.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Help & Support

@available(iOS 26.0, *)
struct FMHelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqs: [(question: String, answer: String)] = [
        ("How do I add a new vehicle?", "Go to Dashboard > Quick Actions > Add Vehicle. Fill in the registration details, model, and assign a driver."),
        ("How to assign a driver to a vehicle?", "Navigate to Manage tab > Vehicles > Select vehicle > Assign Driver. Choose from available drivers."),
        ("How to create a maintenance task?", "Go to Quick Actions > Maintenance > Create Work Order. Set the priority, assign to a technician, and describe the issue."),
        ("How do I track active trips?", "Use the Tracking tab to see real-time GPS locations of all active fleet vehicles on the map."),
        ("How to generate reports?", "Go to Quick Actions > Reports. Select the report type (fleet, trip, maintenance) and date range.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "questionmark.circle.fill",
                            iconColor: AppTheme.Brand.teal,
                            title: "Help & Support",
                            subtitle: "Frequently asked questions and contact"
                        )

                        // FAQs
                        VStack(alignment: .leading, spacing: 0) {
                            Text("FREQUENTLY ASKED QUESTIONS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                                    DisclosureGroup {
                                        Text(faq.answer)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .padding(.top, 4)
                                            .padding(.bottom, 8)
                                    } label: {
                                        Text(faq.question)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Text.primary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .tint(AppTheme.Brand.primary)

                                    if index < faqs.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        // Contact
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CONTACT SUPPORT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ProfileInfoRow(label: "Email", value: "support@fms.app", valueColor: AppTheme.Brand.primary)
                                Divider().padding(.leading, 16)
                                ProfileInfoRow(label: "Phone", value: "+91 1800-FMS-HELP", valueColor: AppTheme.Brand.primary)
                                Divider().padding(.leading, 16)
                                ProfileInfoRow(label: "Hours", value: "Mon-Fri 9 AM – 6 PM")
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
}

// MARK: - About

@available(iOS 26.0, *)
struct FMAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // App logo & name
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 72, height: 72)
                                    .shadow(color: AppTheme.Brand.primary.opacity(0.30), radius: 12, y: 4)

                                Image(systemName: "bus.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.white)
                            }

                            Text("Fleet Management System")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)

                            Text("Version 1.0.0 (Build 1)")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                        .padding(.vertical, 24)

                        // App info
                        VStack(spacing: 0) {
                            ProfileInfoRow(label: "Developer", value: "FMS Team")
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Platform", value: "iOS 26+")
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "License", value: "Proprietary")
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        // Legal
                        VStack(spacing: 0) {
                            Button { } label: {
                                HStack {
                                    Text("Terms of Service")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppTheme.Text.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                            Divider().padding(.leading, 16)

                            Button { } label: {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(AppTheme.Text.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.7))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        Text("© 2026 FMS. All rights reserved.")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Text.tertiary)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
}

// MARK: - Previews

@available(iOS 26.0, *)
#Preview("Notification Settings") {
    FMNotificationSettingsView()
}

@available(iOS 26.0, *)
#Preview("Security") {
    FMSecuritySettingsView()
}

@available(iOS 26.0, *)
#Preview("Help") {
    FMHelpSupportView()
}

@available(iOS 26.0, *)
#Preview("About") {
    FMAboutView()
}
