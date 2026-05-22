//
//  MaintenanceInnerScreens.swift
//  FMS
//
//  Inner screens for Maintenance Personnel profile:
//  - Edit Profile
//  - Work History
//  - Certifications & Training
//  - Notification Settings
//  - Security Settings
//  - Help & Support
//

import SwiftUI

// MARK: - Maintenance Edit Profile

@available(iOS 26.0, *)
struct MaintenanceEditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared

    @State private var fullName = ""
    @State private var phoneNumber = ""
    @State private var specialization = ""
    @State private var isSaving = false
    @State private var showSaved = false

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        let parts = fullName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Avatar
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Brand.amber, Color(red: 0.95, green: 0.50, blue: 0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppTheme.Brand.amber.opacity(0.30), radius: 12, y: 4)

                                Text(initials.isEmpty ? "MP" : initials)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            Button { } label: {
                                Text("Change Photo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Brand.amber)
                            }
                        }
                        .padding(.top, 8)

                        // Form
                        VStack(spacing: 0) {
                            ProfileFormField(icon: "person.fill", label: "Full Name", text: $fullName, placeholder: "Enter your name")
                            Divider().padding(.leading, 56)
                            ProfileFormField(icon: "phone.fill", label: "Phone Number", text: $phoneNumber, placeholder: "+91 XXXXX XXXXX", keyboardType: .phonePad)
                            Divider().padding(.leading, 56)
                            ProfileFormField(icon: "wrench.and.screwdriver.fill", label: "Specialization", text: $specialization, placeholder: "e.g. Engine Repair, Brake Systems")
                            Divider().padding(.leading, 56)

                            // Email (read-only)
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Text.tertiary)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Email")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.Text.tertiary)
                                    Text(user?.email ?? "maintenance@fms.com")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Text.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 56)

                            // Role (read-only)
                            HStack(spacing: 12) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Text.tertiary)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Role")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.Text.tertiary)
                                    Text("Maintenance Personnel")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Text.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)

                        // Save
                        Button {
                            isSaving = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isSaving = false
                                showSaved = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving { ProgressView().tint(.white) }
                                Text(isSaving ? "Saving..." : "Save Changes")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Brand.amber, Color(red: 0.95, green: 0.50, blue: 0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: AppTheme.Brand.amber.opacity(0.30), radius: 12, y: 4)
                        }
                        .disabled(isSaving)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .onAppear {
                fullName = user?.name ?? ""
                phoneNumber = user?.phoneNumber ?? ""
            }
            .alert("Profile Updated", isPresented: $showSaved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been saved successfully.")
            }
        }
    }
}

// MARK: - Work History

@available(iOS 26.0, *)
struct MaintenanceWorkHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    private let mockOrders: [(id: String, title: String, vehicle: String, priority: String, status: String, date: String)] = [
        ("WO-1024", "Brake Pad Replacement", "VH-001 (Ford Transit)", "High", "Completed", "22 May 2026"),
        ("WO-1021", "Oil Change & Filter", "VH-003 (Tata Ace)", "Medium", "Completed", "21 May 2026"),
        ("WO-1018", "Tire Rotation", "VH-005 (Mahindra Bolero)", "Low", "Completed", "20 May 2026"),
        ("WO-1015", "AC Compressor Fix", "VH-002 (Ashok Leyland)", "High", "Completed", "19 May 2026"),
        ("WO-1010", "Battery Replacement", "VH-001 (Ford Transit)", "Urgent", "Completed", "18 May 2026"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(mockOrders.enumerated()), id: \.offset) { _, order in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(order.id)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.Brand.primary)

                                    Spacer()

                                    Text(order.priority)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(priorityColor(order.priority))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(priorityColor(order.priority).opacity(0.10))
                                        .clipShape(Capsule())
                                }

                                Text(order.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.primary)

                                HStack(spacing: 16) {
                                    Label(order.vehicle, systemImage: "truck.box.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Text.secondary)

                                    Spacer()

                                    Label(order.date, systemImage: "calendar")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.Text.tertiary)
                                }

                                HStack {
                                    Spacer()
                                    Text(order.status)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(AppTheme.Status.success)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.Status.success.opacity(0.10))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(16)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Work History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "Urgent": return AppTheme.Status.danger
        case "High": return AppTheme.Status.warning
        case "Medium": return AppTheme.Brand.primary
        default: return AppTheme.Text.tertiary
        }
    }
}

// MARK: - Certifications & Training

@available(iOS 26.0, *)
struct MaintenanceCertificationsView: View {
    @Environment(\.dismiss) private var dismiss

    private let certifications: [(name: String, issuer: String, date: String, status: String)] = [
        ("Heavy Vehicle Maintenance", "ASME India", "Jan 2024", "Valid"),
        ("Brake Systems Specialist", "Bosch Automotive", "Mar 2023", "Valid"),
        ("Electrical Diagnostics", "FMS Training Academy", "Jun 2023", "Valid"),
        ("Safety & Compliance", "ARAI", "Sep 2022", "Renewal Due"),
    ]

    private let training: [(name: String, provider: String, date: String, hours: String)] = [
        ("EV Battery Maintenance", "FMS Academy", "Apr 2026", "16 hrs"),
        ("Advanced Engine Diagnostics", "Tata Motors", "Feb 2026", "24 hrs"),
        ("Hydraulic Systems", "FMS Academy", "Nov 2025", "12 hrs"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "rosette",
                            iconColor: AppTheme.Brand.amber,
                            title: "Certifications & Training",
                            subtitle: "Your professional qualifications"
                        )

                        // Certifications
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CERTIFICATIONS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ForEach(Array(certifications.enumerated()), id: \.offset) { i, cert in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 9)
                                                .fill(cert.status == "Valid" ? AppTheme.IconBg.green : AppTheme.IconBg.orange)
                                                .frame(width: 40, height: 40)
                                            Image(systemName: cert.status == "Valid" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(cert.status == "Valid" ? AppTheme.Status.success : AppTheme.Status.warning)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(cert.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.Text.primary)
                                            Text("\(cert.issuer) • \(cert.date)")
                                                .font(.system(size: 12))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        }

                                        Spacer()

                                        Text(cert.status)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(cert.status == "Valid" ? AppTheme.Status.success : AppTheme.Status.warning)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if i < certifications.count - 1 {
                                        Divider().padding(.leading, 68)
                                    }
                                }
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        // Training
                        VStack(alignment: .leading, spacing: 0) {
                            Text("TRAINING RECORDS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ForEach(Array(training.enumerated()), id: \.offset) { i, tr in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 9)
                                                .fill(AppTheme.IconBg.blue)
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "book.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(AppTheme.Brand.primary)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(tr.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(AppTheme.Text.primary)
                                            Text("\(tr.provider) • \(tr.date)")
                                                .font(.system(size: 12))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        }

                                        Spacer()

                                        Text(tr.hours)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppTheme.Brand.primary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if i < training.count - 1 {
                                        Divider().padding(.leading, 68)
                                    }
                                }
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
            .navigationTitle("Certifications")
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

// MARK: - Maintenance Notification Settings

@available(iOS 26.0, *)
struct MaintenanceNotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var workOrderAlerts = true
    @State private var inventoryAlerts = true
    @State private var urgentWorkOrders = true
    @State private var scheduleReminders = true
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
                            subtitle: "Manage work order & inventory alerts"
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            Text("WORK ORDERS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ProfileToggleRow(icon: "doc.text.fill", iconColor: AppTheme.Brand.primary, title: "New Work Orders", subtitle: "When a work order is assigned", isOn: $workOrderAlerts)
                                Divider().padding(.leading, 66)
                                ProfileToggleRow(icon: "exclamationmark.octagon.fill", iconColor: AppTheme.Status.danger, title: "Urgent Orders", subtitle: "High priority / urgent assignments", isOn: $urgentWorkOrders)
                                Divider().padding(.leading, 66)
                                ProfileToggleRow(icon: "calendar.badge.clock", iconColor: AppTheme.Brand.amber, title: "Schedule Reminders", subtitle: "Upcoming maintenance due dates", isOn: $scheduleReminders)
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("INVENTORY & GENERAL")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                ProfileToggleRow(icon: "shippingbox.fill", iconColor: AppTheme.Status.purple, title: "Low Stock Alerts", subtitle: "Parts below reorder threshold", isOn: $inventoryAlerts)
                                Divider().padding(.leading, 66)
                                ProfileToggleRow(icon: "speaker.wave.2.fill", iconColor: AppTheme.Text.tertiary, title: "Sounds", subtitle: "Play notification sounds", isOn: $soundEnabled)
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

// MARK: - Maintenance Security Settings

@available(iOS 26.0, *)
struct MaintenanceSecuritySettingsView: View {
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
                            subtitle: "Password & authentication"
                        )

                        VStack(alignment: .leading, spacing: 0) {
                            Text("CHANGE PASSWORD")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            VStack(spacing: 0) {
                                MaintSecureField(label: "Current Password", text: $currentPassword)
                                Divider().padding(.leading, 16)
                                MaintSecureField(label: "New Password", text: $newPassword)
                                Divider().padding(.leading, 16)
                                MaintSecureField(label: "Confirm Password", text: $confirmPassword)
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        VStack(spacing: 0) {
                            ProfileToggleRow(icon: "faceid", iconColor: AppTheme.Brand.primary, title: "Face ID / Touch ID", subtitle: "Use biometrics to unlock", isOn: $biometricEnabled)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        Button {
                            isSaving = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { isSaving = false; showSaved = true }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving { ProgressView().tint(.white) }
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

private struct MaintSecureField: View {
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

// MARK: - Maintenance Help & Support

@available(iOS 26.0, *)
struct MaintenanceHelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqs: [(q: String, a: String)] = [
        ("How do I view assigned work orders?", "Your Dashboard shows all pending and in-progress work orders. Tap any order to see full details and update its status."),
        ("How to update a work order status?", "Open a work order > tap 'Start Work' to move it to In Progress, or 'Complete' when finished. Add repair notes before completing."),
        ("How to check inventory levels?", "Go to the Inventory tab. Parts below reorder threshold are highlighted in the 'Low Stock' section."),
        ("How to request parts?", "When viewing a work order, tap 'Request Parts' to submit a parts requisition to the fleet manager."),
        ("How to log repair notes?", "Open an active work order > scroll to 'Repair Notes' section > add your notes and photos of the repair.")
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
                            subtitle: "FAQs and contact information"
                        )

                        VStack(spacing: 0) {
                            ForEach(Array(faqs.enumerated()), id: \.offset) { i, faq in
                                DisclosureGroup {
                                    Text(faq.a)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.Text.secondary)
                                        .padding(.top, 4)
                                        .padding(.bottom, 8)
                                } label: {
                                    Text(faq.q)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.Text.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .tint(AppTheme.Brand.primary)

                                if i < faqs.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

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

// MARK: - Previews

@available(iOS 26.0, *)
#Preview("Edit Profile") { MaintenanceEditProfileView() }

@available(iOS 26.0, *)
#Preview("Work History") { MaintenanceWorkHistoryView() }

@available(iOS 26.0, *)
#Preview("Certifications") { MaintenanceCertificationsView() }

@available(iOS 26.0, *)
#Preview("Notifications") { MaintenanceNotificationSettingsView() }

@available(iOS 26.0, *)
#Preview("Security") { MaintenanceSecuritySettingsView() }

@available(iOS 26.0, *)
#Preview("Help") { MaintenanceHelpSupportView() }
