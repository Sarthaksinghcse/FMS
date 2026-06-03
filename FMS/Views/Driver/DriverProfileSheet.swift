import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct DriverProfileSheet: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Environment(SupabaseManager.self) private var supabase
    @State private var showEditProfile = false
    @State private var showLicenseDetails = false
    @State private var showNotificationSettings = false
    @State private var showSecuritySettings = false
    @State private var showHelpSupport = false
    @State private var showPerformanceStats = false
    @State private var showSignOutConfirm = false
    @State private var signOutError: String?
    @State private var isSigningOut = false

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        let name = user?.name ?? vm.driverName
        guard !name.isEmpty else { return "DR" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var totalTrips: Int {
        vm.completedTrips.count
    }

    private var totalKmDriven: Double {
        vm.completedTrips.reduce(0.0) { $0 + $1.distanceKm }
    }

    private var hoursOnRoad: Int {
        let totalSeconds = vm.completedTrips.reduce(0) { $0 + $1.elapsedSeconds }
        return totalSeconds / 3600
    }

    private var safetyScore: Int {
        94
    }

    private var onTimeDelivery: Int {
        97
    }

    private var avgFuelEfficiency: Double {
        12.4
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileHeaderCard
                        statsSection
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
                            .foregroundColor(AppTheme.Status.success)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                DriverEditProfileView()
            }
            .sheet(isPresented: $showLicenseDetails) {
                DriverLicenseDetailView()
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
                    tripsCompleted: totalTrips,
                    totalKmDriven: totalKmDriven,
                    hoursOnRoad: hoursOnRoad
                )
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    isSigningOut = true
                    dismiss()
                    Task {
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
                Text("Are you sure you want to sign out of your Driver account?")
            }
            .alert("Sign Out Failed", isPresented: Binding(
                get: { signOutError != nil },
                set: { if !$0 { signOutError = nil } }
            )) {
                Button("OK", role: .cancel) { signOutError = nil }
            } message: {
                Text(signOutError ?? "")
            }
            .task {
                await vm.load(context: modelContext)
            }
        }
    }

    // MARK: - Header Card
    private var profileHeaderCard: some View {
        ZStack(alignment: .topTrailing) {
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

                        if let imageURLString = user?.profileImage, let imageURL = URL(string: imageURLString) {
                            CachedAsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Text(initials)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(
                                        LinearGradient(
                                            colors: [AppTheme.Status.success, AppTheme.Brand.teal],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                        } else {
                            Text(initials)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }

                    // Active status badge
                    Circle()
                        .fill(vm.driverStatus != .offline ? AppTheme.Status.success : AppTheme.Status.neutral)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Background.card, lineWidth: 3)
                        )
                }

                VStack(spacing: 6) {
                    Text(user?.name ?? vm.driverName)
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

            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(AppTheme.Status.success)
            }
            .padding(12)
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        HStack(spacing: 12) {
            ProfileStatCard(
                icon: "road.lanes",
                iconColor: AppTheme.Brand.primary,
                iconBg: AppTheme.IconBg.blue,
                title: "Total Distance",
                value: String(format: "%.1f km", totalKmDriven),
                subtitle: "Accumulated travel"
            )
            ProfileStatCard(
                icon: "map.fill",
                iconColor: AppTheme.Status.success,
                iconBg: AppTheme.IconBg.green,
                title: "Trips",
                value: "\(totalTrips)",
                subtitle: "Completed jobs"
            )
        }
    }

    // MARK: - Account & Settings
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ProfileToggleRow(
                    icon: "checkmark.circle.fill",
                    iconColor: vm.driverStatus != .offline ? AppTheme.Status.success : AppTheme.Status.neutral,
                    title: "Duty Status",
                    subtitle: vm.driverStatus != .offline ? "You are online & active" : "You are currently offline",
                    isOn: Binding(
                        get: { vm.driverStatus != .offline },
                        set: { newValue in
                            withAnimation {
                                vm.driverStatus = newValue ? .idle : .offline
                            }
                            Task {
                                await vm.updateDriverActiveStatus(isActive: newValue)
                            }
                        }
                    ),
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

    // MARK: - Sign Out Section
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
#Preview("Driver Profile") {
    DriverProfileSheet(vm: DriverDashboardViewModel())
        .environment(SupabaseManager.shared)
}
