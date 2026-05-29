












import SwiftUI
import PhotosUI



@available(iOS 26.0, *)
struct MaintenanceEditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared

    @State private var fullName = ""
    @State private var phoneNumber = ""
    @State private var specialization = ""
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

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
                        
                        VStack(spacing: 14) {
                            ZStack {
                                if isUploadingPhoto {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80, height: 80)
                                    ProgressView()
                                } else {
                                    if let profileImage = user?.profileImage, let url = URL(string: profileImage) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            } else if phase.error != nil {
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
                                            } else {
                                                ProgressView()
                                            }
                                        }
                                    } else {
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
                                }
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Brand.amber)
                            }
                            .onChange(of: selectedPhotoItem) { _, newItem in
                                uploadProfilePhoto(item: newItem)
                            }
                        }
                        .padding(.top, 8)

                        
                        VStack(spacing: 0) {
                            ProfileFormField(icon: "person.fill", label: "Full Name", text: $fullName, placeholder: "Enter your name", iconColor: AppTheme.Brand.amber)
                            Divider().padding(.leading, 56)
                            ProfileFormField(icon: "phone.fill", label: "Phone Number", text: $phoneNumber, placeholder: "+91 XXXXX XXXXX", keyboardType: .phonePad, iconColor: AppTheme.Brand.amber)
                            Divider().padding(.leading, 56)
                            ProfileFormField(icon: "wrench.and.screwdriver.fill", label: "Specialization", text: $specialization, placeholder: "e.g. Engine Repair, Brake Systems", iconColor: AppTheme.Brand.amber)
                            Divider().padding(.leading, 56)

                            
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

                        
                        Button {
                            saveProfileChanges()
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
                        .foregroundColor(AppTheme.Brand.amber)
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
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveProfileChanges() {
        guard var currentUser = user else { return }
        isSaving = true
        
        currentUser.name = fullName
        currentUser.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
        
        Task {
            do {
                try await supabase.updateDriver(currentUser)
                await MainActor.run {
                    isSaving = false
                    showSaved = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func uploadProfilePhoto(item: PhotosPickerItem?) {
        guard let item = item, let userId = user?.id else { return }
        
        isUploadingPhoto = true
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                do {
                    let url = try await supabase.uploadAvatar(userId: userId, imageData: data)
                    
                    if var currentUser = user {
                        let timestamp = Int(Date().timeIntervalSince1970)
                        currentUser.profileImage = "\(url)?t=\(timestamp)"
                        try await supabase.updateDriver(currentUser)
                    }
                    
                    await MainActor.run {
                        isUploadingPhoto = false
                        selectedPhotoItem = nil
                    }
                } catch {
                    await MainActor.run {
                        isUploadingPhoto = false
                        selectedPhotoItem = nil
                        errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                        showError = true
                    }
                }
            } else {
                await MainActor.run {
                    isUploadingPhoto = false
                    selectedPhotoItem = nil
                }
            }
        }
    }
}



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
                                        .foregroundColor(AppTheme.Brand.amber)

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
                        .foregroundColor(AppTheme.Brand.amber)
                }
            }
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "Urgent": return AppTheme.Status.danger
        case "High": return AppTheme.Status.warning
        case "Medium": return AppTheme.Brand.amber
        default: return AppTheme.Text.tertiary
        }
    }
}



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
                                                .fill(AppTheme.IconBg.amber)
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "book.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(AppTheme.Brand.amber)
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
                                            .foregroundColor(AppTheme.Brand.amber)
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
                        .foregroundColor(AppTheme.Brand.amber)
                }
            }
        }
    }
}



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
                                ProfileToggleRow(icon: "doc.text.fill", iconColor: AppTheme.Brand.amber, title: "New Work Orders", subtitle: "When a work order is assigned", isOn: $workOrderAlerts, tintColor: AppTheme.Brand.amber)
                                Divider().padding(.leading, 66)
                                ProfileToggleRow(icon: "exclamationmark.octagon.fill", iconColor: AppTheme.Status.danger, title: "Urgent Orders", subtitle: "High priority / urgent assignments", isOn: $urgentWorkOrders, tintColor: AppTheme.Brand.amber)
                                Divider().padding(.leading, 66)
                                ProfileToggleRow(icon: "calendar.badge.clock", iconColor: AppTheme.Brand.amber, title: "Schedule Reminders", subtitle: "Upcoming maintenance due dates", isOn: $scheduleReminders, tintColor: AppTheme.Brand.amber)
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
                                ProfileToggleRow(icon: "shippingbox.fill", iconColor: AppTheme.Status.purple, title: "Low Stock Alerts", subtitle: "Parts below reorder threshold", isOn: $inventoryAlerts, tintColor: AppTheme.Brand.amber)
                                Divider().padding(.leading, 66)
                                ProfileToggleRow(icon: "speaker.wave.2.fill", iconColor: AppTheme.Text.tertiary, title: "Sounds", subtitle: "Play notification sounds", isOn: $soundEnabled, tintColor: AppTheme.Brand.amber)
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
                        .foregroundColor(AppTheme.Brand.amber)
                }
            }
        }
    }
}



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
                            iconColor: AppTheme.Brand.amber,
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
                            ProfileToggleRow(icon: "faceid", iconColor: AppTheme.Brand.amber, title: "Face ID / Touch ID", subtitle: "Use biometrics to unlock", isOn: $biometricEnabled, tintColor: AppTheme.Brand.amber)
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
                            .background(AppTheme.Brand.amber)
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
                        .foregroundColor(AppTheme.Brand.amber)
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
                                .tint(AppTheme.Brand.amber)

                                if i < faqs.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        VStack(spacing: 0) {
                            ProfileInfoRow(label: "Email", value: "support@fms.app", valueColor: AppTheme.Brand.amber)
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Phone", value: "+91 1800-FMS-HELP", valueColor: AppTheme.Brand.amber)
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
                        .foregroundColor(AppTheme.Brand.amber)
                }
            }
        }
    }
}



@available(iOS 26.0, *)
#Preview("Edit Profile") { MaintenanceEditProfileView() }

@available(iOS 26.0, *)
struct MaintenanceSpecializationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showCertifications = false

    private let specializations = ["Engine Repair", "Brake Systems", "Electrical", "Oil & Fluids"]

    private func iconForSpecialization(_ spec: String) -> String {
        switch spec {
        case "Engine Repair": return "wrench.and.screwdriver.fill"
        case "Brake Systems": return "slowmo"
        case "Electrical": return "bolt.fill"
        case "Oil & Fluids": return "drop.fill"
        default: return "gearshape.fill"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "wrench.and.screwdriver.fill",
                            iconColor: AppTheme.Brand.amber,
                            title: "Specializations",
                            subtitle: "Your technical specialties and certifications"
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Technical Specialties")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                                .padding(.leading, 4)

                            FlowLayout(spacing: 8) {
                                ForEach(specializations, id: \.self) { spec in
                                    HStack(spacing: 5) {
                                        Image(systemName: iconForSpecialization(spec))
                                            .font(.system(size: 10))
                                        Text(spec)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(AppTheme.Brand.amber)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(AppTheme.Brand.amber.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Certifications")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                                .padding(.leading, 4)

                            Button {
                                showCertifications = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "rosette")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Brand.amber)
                                        .frame(width: 36, height: 36)
                                        .background(AppTheme.IconBg.amber)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Certifications & Training")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Text.primary)
                                        Text("View certificates and training records")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }

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
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Specializations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Brand.amber)
                }
            }
            .sheet(isPresented: $showCertifications) {
                MaintenanceCertificationsView()
            }
        }
    }
}

@available(iOS 26.0, *)
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentY += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

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

@available(iOS 26.0, *)
#Preview("Specializations") { MaintenanceSpecializationsView() }
