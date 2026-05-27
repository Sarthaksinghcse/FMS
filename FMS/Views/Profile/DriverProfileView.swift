import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct DriverProfileView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var allTrips: [Trip]
    @Query private var allUsers: [User]


    @StateObject private var supabase = SupabaseManager.shared

    @State private var showEditProfile = false
    @State private var showLicenseDetails = false
    @State private var showDrivingHistory = false
    @State private var showNotificationSettings = false
    @State private var showSecuritySettings = false
    @State private var showHelpSupport = false
    @State private var showPerformanceStats = false
    @State private var showSignOutConfirm = false
    @State private var isDriverActive = true

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        guard let name = user?.name, !name.isEmpty else { return "DR" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // Real computations from SwiftData
    private var driverTrips: [Trip] {
        guard let uid = user?.id else { return [] }
        return allTrips.filter { $0.driverId == uid }
    }

    private var completedTrips: [Trip] {
        driverTrips.filter { $0.tripStatus == .completed }
    }

    private var tripsCompleted: Int {
        completedTrips.count
    }

    private var totalKmDriven: Double {
        completedTrips.reduce(0.0) { $0 + $1.distanceKm }
    }

    private var hoursOnRoad: Int {
        let totalSeconds = completedTrips.reduce(0.0) { sum, trip in
            let start = trip.actualStartTime ?? trip.scheduledStartTime
            let end = trip.actualEndTime ?? trip.scheduledEndTime
            return sum + end.timeIntervalSince(start)
        }
        return Int(totalSeconds / 3600.0)
    }

    private var safetyScore: Int {
        94
    }

    private var onTimeDelivery: Int {
        97
    }

    private var avgFuelEfficiency: Double {
        let tripsWithFuel = completedTrips.filter { ($0.fuelConsumed ?? 0.0) > 0.0 }
        guard !tripsWithFuel.isEmpty else { return 12.4 }
        let totalFuel = tripsWithFuel.reduce(0.0) { $0 + ($1.fuelConsumed ?? 0.0) }
        let totalDist = tripsWithFuel.reduce(0.0) { $0 + $1.distanceKm }
        return totalFuel > 0 ? (totalDist / totalFuel) : 12.4
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditProfile = true
                    }
                    .font(.system(size: 17))
                    .foregroundColor(AppTheme.Status.success)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                DriverEditProfileView()
            }
            .sheet(isPresented: $showLicenseDetails) {
                DriverLicenseDetailView()
            }
            .sheet(isPresented: $showDrivingHistory) {
                DriverTripHistoryView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                DriverNotificationSettingsView()
            }
            .sheet(isPresented: $showSecuritySettings) {
                DriverSecuritySettingsView()
            }
            .sheet(isPresented: $showHelpSupport) {
                DriverHelpSupportView()
            }
            .sheet(isPresented: $showPerformanceStats) {
                DriverPerformanceStatsView(
                    safetyScore: safetyScore,
                    onTimeDelivery: onTimeDelivery,
                    avgFuelEfficiency: avgFuelEfficiency,
                    tripsCompleted: tripsCompleted,
                    totalKmDriven: totalKmDriven,
                    hoursOnRoad: hoursOnRoad
                )
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { try? await supabase.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your Driver account?")
            }
            .onAppear {
                if let user = supabase.currentUser {
                    isDriverActive = user.isActive
                }
            }
            .onChange(of: isDriverActive) { oldValue, newValue in
                Task {
                    guard var updatedUser = supabase.currentUser else { return }
                    updatedUser.isActive = newValue
                    do {
                        try await supabase.updateDriver(updatedUser)
                        await MainActor.run {
                            if let localUser = allUsers.first(where: { $0.id == updatedUser.id }) {
                                localUser.isActive = newValue
                                try? modelContext.save()
                            }
                        }
                    } catch {
                        print("Failed to update status on Supabase: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var profileHeaderCard: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Status.success, AppTheme.Brand.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: AppTheme.Status.success.opacity(0.35), radius: 16, y: 6)

                    Text(initials)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Active duty status indicator
                Circle()
                    .fill(isDriverActive ? AppTheme.Status.success : AppTheme.Status.neutral)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Background.card, lineWidth: 3)
                    )
                    .offset(x: -2, y: -2)
            }

            VStack(spacing: 6) {
                Text(user?.name ?? "Driver")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)

                Text(user?.email ?? "driver@fms.com")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Driver")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppTheme.Status.success)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(AppTheme.Status.success.opacity(0.10))
                .clipShape(Capsule())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
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
                ProfileToggleRow(
                    icon: "checkmark.circle.fill",
                    iconColor: isDriverActive ? AppTheme.Status.success : AppTheme.Status.neutral,
                    title: "Duty Status",
                    subtitle: isDriverActive ? "You are currently online & active" : "You are currently offline",
                    isOn: $isDriverActive,
                    tintColor: AppTheme.Status.success
                )

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "chart.bar.xaxis",
                    iconColor: AppTheme.Status.success,
                    iconBg: AppTheme.IconBg.green,
                    title: "Performance & Stats",
                    subtitle: "View driving scores & history stats"
                ) {
                    showPerformanceStats = true
                }

                Divider().padding(.leading, 66)

                ProfileSettingsRow(
                    icon: "creditcard.fill",
                    iconColor: AppTheme.Brand.amber,
                    iconBg: AppTheme.IconBg.amber,
                    title: "License Details",
                    subtitle: "View driving license & validity"
                ) {
                    showLicenseDetails = true
                }

                Divider().padding(.leading, 66)

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
    DriverProfileView()
}
