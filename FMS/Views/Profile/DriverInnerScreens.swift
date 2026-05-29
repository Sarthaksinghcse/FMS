












import SwiftUI
import PhotosUI



@available(iOS 26.0, *)
struct DriverEditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared

    @State private var fullName = ""
    @State private var phoneNumber = ""
    @State private var emergencyContact = ""
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

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
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Status.success, AppTheme.Brand.teal],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppTheme.Status.success.opacity(0.30), radius: 12, y: 4)

                                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else if let imageURLString = user?.profileImage, let imageURL = URL(string: imageURLString) {
                                    AsyncImage(url: imageURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        default:
                                            Text(initials.isEmpty ? "DR" : initials)
                                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Text(initials.isEmpty ? "DR" : initials)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }

                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Status.success)
                            }
                        }
                        .padding(.top, 8)

                        
                        VStack(spacing: 0) {
                            ProfileFormField(icon: "person.fill", label: "Full Name", text: $fullName, placeholder: "Enter your name", iconColor: AppTheme.Status.success)
                            Divider().padding(.leading, 56)
                            ProfileFormField(icon: "phone.fill", label: "Phone Number", text: $phoneNumber, placeholder: "+91 XXXXX XXXXX", keyboardType: .phonePad, iconColor: AppTheme.Status.success)
                            Divider().padding(.leading, 56)
                            ProfileFormField(icon: "phone.arrow.up.right.fill", label: "Emergency Contact", text: $emergencyContact, placeholder: "+91 XXXXX XXXXX", keyboardType: .phonePad, iconColor: AppTheme.Status.success)
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
                                    Text(user?.email ?? "driver@fms.com")
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
                            let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
                            guard trimmedPhone.isValidPhoneNumber else {
                                errorAlertMessage = "Please enter a valid 10-digit phone number."
                                showErrorAlert = true
                                return
                            }
                            
                            let trimmedEmergency = emergencyContact.trimmingCharacters(in: .whitespaces)
                            if !trimmedEmergency.isEmpty && !trimmedEmergency.isValidPhoneNumber {
                                errorAlertMessage = "Please enter a valid 10-digit emergency contact number."
                                showErrorAlert = true
                                return
                            }
                            
                            isSaving = true
                            
                            Task {
                                guard var updatedUser = user else {
                                    await MainActor.run { isSaving = false }
                                    return
                                }
                                
                                updatedUser.name = fullName
                                updatedUser.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
                                
                                do {
                                    if let imgData = selectedImageData {
                                        let urlString = try await supabase.uploadAvatar(userId: updatedUser.id, imageData: imgData)
                                        let timestamp = Int(Date().timeIntervalSince1970)
                                        updatedUser.profileImage = "\(urlString)?t=\(timestamp)"
                                    }
                                    
                                    try await supabase.updateDriver(updatedUser)
                                    
                                    await MainActor.run {
                                        isSaving = false
                                        showSaved = true
                                    }
                                } catch {
                                    await MainActor.run {
                                        isSaving = false
                                        errorAlertMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
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
                                    colors: [AppTheme.Status.success, AppTheme.Brand.teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: AppTheme.Status.success.opacity(0.30), radius: 12, y: 4)
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
                        .foregroundColor(AppTheme.Status.success)
                }
            }
            .onAppear {
                fullName = user?.name ?? ""
                phoneNumber = user?.phoneNumber ?? ""
            }
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.selectedImageData = data
                            self.selectedItem = nil
                        }
                    }
                }
            }
            .alert("Profile Updated", isPresented: $showSaved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been saved successfully.")
            }
            .alert("Validation Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorAlertMessage)
            }
        }
    }
}



@available(iOS 26.0, *)
struct DriverLicenseDetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DRIVING LICENSE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                        .tracking(1.2)
                                    Text("DL-1234567890")
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppTheme.Brand.amber)
                            }

                            Divider().background(Color.white.opacity(0.15))

                            HStack(spacing: 24) {
                                DriverLicenseInfo(label: "Category", value: "HMV")
                                DriverLicenseInfo(label: "Issued", value: "15 Mar 2020")
                                DriverLicenseInfo(label: "Expires", value: "15 Mar 2028")
                            }

                            Divider().background(Color.white.opacity(0.15))

                            HStack(spacing: 24) {
                                DriverLicenseInfo(label: "State", value: "Tamil Nadu")
                                DriverLicenseInfo(label: "Blood Group", value: "B+")
                                DriverLicenseInfo(label: "Status", value: "Valid")
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: AppTheme.Brand.primary.opacity(0.3), radius: 12, y: 6)

                        
                        VStack(spacing: 0) {
                            ProfileInfoRow(label: "Full Name", value: "Test Driver")
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Date of Birth", value: "01 Jan 1995")
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Address", value: "Chennai, Tamil Nadu")
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Endorsements", value: "None")
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Violations", value: "0", valueColor: AppTheme.Status.success)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("License Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Status.success)
                }
            }
        }
    }
}

private struct DriverLicenseInfo: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}



@available(iOS 26.0, *)
struct DriverTripHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    private let mockTrips: [(code: String, from: String, to: String, date: String, distance: String, status: String)] = [
        ("TRP-2240", "Warehouse A – Sector 17", "Distribution Hub – Phase 5", "22 May 2026", "48.2 km", "Completed"),
        ("TRP-2238", "Distribution Hub – Phase 5", "Client Site – Noida", "21 May 2026", "31.0 km", "Completed"),
        ("TRP-2235", "Depot – Gurugram", "Mall Road – Delhi", "20 May 2026", "52.7 km", "Completed"),
        ("TRP-2230", "Warehouse B – Faridabad", "Corporate Office – Cyber City", "19 May 2026", "38.5 km", "Completed"),
        ("TRP-2225", "Depot – Gurugram", "Warehouse A – Sector 17", "18 May 2026", "22.1 km", "Cancelled"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(mockTrips.enumerated()), id: \.offset) { _, trip in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(trip.code)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.Text.primary)
                                    Spacer()
                                    Text(trip.status)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(trip.status == "Completed" ? AppTheme.Status.success : AppTheme.Text.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((trip.status == "Completed" ? AppTheme.Status.success : AppTheme.Text.secondary).opacity(0.10))
                                        .clipShape(Capsule())
                                }

                                HStack(spacing: 10) {
                                    VStack(spacing: 0) {
                                        Circle().fill(AppTheme.Brand.primary).frame(width: 7, height: 7)
                                        Rectangle()
                                            .fill(LinearGradient(colors: [AppTheme.Brand.primary.opacity(0.5), AppTheme.Status.success.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 1.5, height: 20)
                                        Circle().fill(AppTheme.Status.success).frame(width: 7, height: 7)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(trip.from)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .lineLimit(1)
                                        Text(trip.to)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                HStack {
                                    Label(trip.date, systemImage: "calendar")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.Text.tertiary)
                                    Spacer()
                                    Label(trip.distance, systemImage: "road.lanes")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
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
            .navigationTitle("Trip History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Status.success)
                }
            }
        }
    }
}



@available(iOS 26.0, *)
struct DriverNotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tripAssigned = true
    @State private var tripReminders = true
    @State private var inspectionDue = true
    @State private var sosConfirm = true
    @State private var messageAlerts = true
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
                            subtitle: "Manage your alert preferences"
                        )

                        VStack(spacing: 0) {
                            ProfileToggleRow(icon: "arrow.triangle.swap", iconColor: AppTheme.Brand.teal, title: "Trip Assigned", subtitle: "New trip assignments", isOn: $tripAssigned, tintColor: AppTheme.Status.success)
                            Divider().padding(.leading, 66)
                            ProfileToggleRow(icon: "clock.badge.exclamationmark", iconColor: AppTheme.Brand.amber, title: "Trip Reminders", subtitle: "Departure time reminders", isOn: $tripReminders, tintColor: AppTheme.Status.success)
                            Divider().padding(.leading, 66)
                            ProfileToggleRow(icon: "checklist", iconColor: AppTheme.Brand.primary, title: "Inspection Due", subtitle: "Pre/post trip inspection alerts", isOn: $inspectionDue, tintColor: AppTheme.Status.success)
                            Divider().padding(.leading, 66)
                            ProfileToggleRow(icon: "exclamationmark.octagon.fill", iconColor: AppTheme.Status.danger, title: "SOS Confirmation", subtitle: "SOS alert acknowledgements", isOn: $sosConfirm, tintColor: AppTheme.Status.success)
                            Divider().padding(.leading, 66)
                            ProfileToggleRow(icon: "message.fill", iconColor: AppTheme.Brand.violet, title: "Messages", subtitle: "Chat from fleet manager", isOn: $messageAlerts, tintColor: AppTheme.Status.success)
                            Divider().padding(.leading, 66)
                            ProfileToggleRow(icon: "speaker.wave.2.fill", iconColor: AppTheme.Text.secondary, title: "Sounds", subtitle: "Play notification sounds", isOn: $soundEnabled, tintColor: AppTheme.Status.success)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(AppTheme.Status.success)
                }
            }
        }
    }
}



@available(iOS 26.0, *)
struct DriverSecuritySettingsView: View {
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
                            iconColor: AppTheme.Status.success,
                            title: "Security",
                            subtitle: "Password & authentication"
                        )

                        VStack(spacing: 0) {
                            ProfileSecureField(label: "Current Password", text: $currentPassword)
                            Divider().padding(.leading, 16)
                            ProfileSecureField(label: "New Password", text: $newPassword)
                            Divider().padding(.leading, 16)
                            ProfileSecureField(label: "Confirm Password", text: $confirmPassword)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)

                        VStack(spacing: 0) {
                            ProfileToggleRow(icon: "faceid", iconColor: AppTheme.Status.success, title: "Face ID / Touch ID", subtitle: "Use biometrics to unlock", isOn: $biometricEnabled, tintColor: AppTheme.Status.success)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)

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
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(AppTheme.Status.success)
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
                    Button("Done") { dismiss() }.foregroundColor(AppTheme.Status.success)
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

private struct ProfileSecureField: View {
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
struct DriverHelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    private let faqs: [(q: String, a: String)] = [
        ("How do I start a trip?", "Go to Trips tab > select an assigned trip > tap 'Start Trip'. Ensure you've completed the pre-trip inspection first."),
        ("How to complete a pre-trip inspection?", "From Dashboard > Quick Actions > Pre-Trip Inspection. Check each item and submit the report."),
        ("How to report a defect?", "Use Dashboard > Quick Actions > Report Defect. Select the defect type, severity, and add a description."),
        ("How to trigger an SOS alert?", "During an active trip, tap the SOS button. This sends your GPS location to the fleet manager immediately."),
        ("How to contact fleet manager?", "Use Dashboard > Quick Actions > Messaging to send a direct message to your fleet manager.")
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
                            subtitle: "FAQs and contact"
                        )

                        VStack(spacing: 0) {
                            ForEach(Array(faqs.enumerated()), id: \.offset) { i, faq in
                                DisclosureGroup {
                                    Text(faq.a)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.Text.secondary)
                                        .padding(.top, 4).padding(.bottom, 8)
                                } label: {
                                    Text(faq.q)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.Text.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .tint(AppTheme.Status.success)
                                if i < faqs.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)

                        VStack(spacing: 0) {
                            ProfileInfoRow(label: "Email", value: "support@fms.app", valueColor: AppTheme.Status.success)
                            Divider().padding(.leading, 16)
                            ProfileInfoRow(label: "Phone", value: "+91 1800-FMS-HELP", valueColor: AppTheme.Status.success)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(AppTheme.Status.success)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct DriverPerformanceStatsView: View {
    @Environment(\.dismiss) private var dismiss

    let safetyScore: Int
    let onTimeDelivery: Int
    let avgFuelEfficiency: Double
    let tripsCompleted: Int
    let totalKmDriven: Double
    let hoursOnRoad: Int

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "chart.bar.xaxis",
                            iconColor: AppTheme.Status.success,
                            title: "Performance & Stats",
                            subtitle: "Your safety scores and driving statistics"
                        )

                        // Performance Rings
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Performance")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                                .padding(.leading, 4)

                            HStack(spacing: 12) {
                                DriverPerformanceStatsRing(
                                    value: Double(safetyScore),
                                    maxValue: 100,
                                    label: "Safety",
                                    color: AppTheme.Status.success
                                )
                                DriverPerformanceStatsRing(
                                    value: Double(onTimeDelivery),
                                    maxValue: 100,
                                    label: "On-Time",
                                    color: AppTheme.Brand.primary
                                )
                                DriverPerformanceStatsRing(
                                    value: avgFuelEfficiency,
                                    maxValue: 20,
                                    label: "km/L",
                                    color: AppTheme.Brand.teal
                                )
                            }
                            .padding(18)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        }

                        // Driving Stats Grid
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Driving Stats")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                                .padding(.leading, 4)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                spacing: 12
                            ) {
                                ProfileStatCard(
                                    icon: "checkmark.circle.fill",
                                    iconColor: AppTheme.Status.success,
                                    iconBg: AppTheme.IconBg.green,
                                    title: "Trips Completed",
                                    value: "\(tripsCompleted)",
                                    subtitle: "Total history"
                                )
                                ProfileStatCard(
                                    icon: "road.lanes",
                                    iconColor: AppTheme.Brand.primary,
                                    iconBg: AppTheme.IconBg.blue,
                                    title: "Distance Driven",
                                    value: String(format: "%.1f km", totalKmDriven),
                                    subtitle: "Accumulated"
                                )
                                ProfileStatCard(
                                    icon: "clock.fill",
                                    iconColor: AppTheme.Brand.amber,
                                    iconBg: AppTheme.IconBg.amber,
                                    title: "Hours on Road",
                                    value: "\(hoursOnRoad) hrs",
                                    subtitle: "Time active"
                                )
                                ProfileStatCard(
                                    icon: "fuelpump.fill",
                                    iconColor: AppTheme.Brand.teal,
                                    iconBg: AppTheme.IconBg.teal,
                                    title: "Avg Fuel Efficiency",
                                    value: String(format: "%.1f km/L", avgFuelEfficiency),
                                    subtitle: "Average consumption"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Performance & Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.Status.success)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
private struct DriverPerformanceStatsRing: View {
    let value: Double
    let maxValue: Double
    let label: String
    let color: Color

    private var progress: Double { min(value / maxValue, 1.0) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(AppTheme.Glass.ringTrack, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(maxValue == 100 ? "\(Int(value))%" : String(format: "%.1f", value))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


@available(iOS 26.0, *)
#Preview("Edit Profile") { DriverEditProfileView() }

@available(iOS 26.0, *)
#Preview("License") { DriverLicenseDetailView() }

@available(iOS 26.0, *)
#Preview("Trip History") { DriverTripHistoryView() }

@available(iOS 26.0, *)
#Preview("Notifications") { DriverNotificationSettingsView() }

@available(iOS 26.0, *)
#Preview("Security") { DriverSecuritySettingsView() }

@available(iOS 26.0, *)
#Preview("Help") { DriverHelpSupportView() }

@available(iOS 26.0, *)
#Preview("Performance & Stats") {
    DriverPerformanceStatsView(safetyScore: 94, onTimeDelivery: 97, avgFuelEfficiency: 12.4, tripsCompleted: 12, totalKmDriven: 350.0, hoursOnRoad: 18)
}
