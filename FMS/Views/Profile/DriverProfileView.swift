








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
    private let licenseNumber = "DL-1234567890"
    private let licenseExpiry = "15 Mar 2028"

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileHeaderCard
                        performanceSection
                        drivingStatsSection
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

    

    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            
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

            
            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 13, weight: .medium))
                    Text("Edit Profile")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppTheme.Brand.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AppTheme.Brand.primary.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
    }

    

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Performance")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                DriverPerformanceRing(
                    value: Double(safetyScore),
                    maxValue: 100,
                    label: "Safety",
                    color: AppTheme.Status.success
                )
                DriverPerformanceRing(
                    value: Double(onTimeDelivery),
                    maxValue: 100,
                    label: "On-Time",
                    color: AppTheme.Brand.primary
                )
                DriverPerformanceRing(
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
    }

    

    private var drivingStatsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Driving Stats")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Text.primary)

                Spacer()

                Button {
                    showDrivingHistory = true
                } label: {
                    Text("View History")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
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
                    value: String(format: "%.0f km", totalKmDriven),
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

    

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ProfileToggleRow(
                    icon: "checkmark.circle.fill",
                    iconColor: isDriverActive ? AppTheme.Status.success : .gray,
                    title: "Duty Status",
                    subtitle: isDriverActive ? "You are currently online & active" : "You are currently offline",
                    isOn: $isDriverActive
                )

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "creditcard.fill",
                    iconColor: AppTheme.Brand.amber,
                    iconBg: AppTheme.IconBg.amber,
                    title: "License Details",
                    subtitle: "View driving license & validity"
                ) {
                    showLicenseDetails = true
                }

                Divider().padding(.leading, 68)

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
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        }
    }

    

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
private struct DriverPerformanceRing: View {
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
#Preview {
    DriverProfileView()
}
