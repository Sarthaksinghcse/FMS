import SwiftUI
import SwiftData
import MapKit

struct FleetDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // Live data from SwiftData (synced from Supabase every 15 s)
    @Query private var vehicles:      [Vehicle]
    @Query private var allUsers:      [User]
    @Query(sort: \Trip.createdAt,         order: .reverse) private var trips:         [Trip]
    @Query(sort: \SOSAlert.createdAt,     order: .reverse) private var sosAlerts:     [SOSAlert]
    @Query(sort: \DefectReport.createdAt, order: .reverse) private var defectReports: [DefectReport]
    @Query(sort: \WorkOrder.createdAt,    order: .reverse) private var workOrders:    [WorkOrder]

    @State private var viewModel    = FleetDashboardViewModel()
    @State private var showProfile  = false

    // Compute the full activity list once per body eval
    private var recentActivities: [DashboardActivity] {
        viewModel.buildActivities(
            trips: trips,
            users: allUsers,
            vehicles: vehicles,
            sosAlerts: sosAlerts,
            defectReports: defectReports,
            workOrders: workOrders
        )
    }

    // Show only 5 on the dashboard card
    private var dashboardActivities: [DashboardActivity] {
        Array(recentActivities.prefix(5))
    }

    private var badgeCount: Int {
        viewModel.recentBadgeCount(activities: recentActivities)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {

                        // ── Greeting ──────────────────────────────
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.getGreetingTime() + ",")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Text("Manager")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            HStack(spacing: 16) {
                                Button {
                                    viewModel.activeQuickAction = .alerts
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Color(UIColor.label))
                                            .frame(width: 40, height: 40)
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
                                            .clipShape(Circle())
                                        
                                        if !sosAlerts.filter({ $0.status == .active }).isEmpty {
                                            Circle()
                                                .fill(AppTheme.Status.danger)
                                                .frame(width: 10, height: 10)
                                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showProfile = true
                                } label: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.Brand.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // ── Stats grid ────────────────────────────
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12),
                                      GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(viewModel.getDynamicStats(
                                vehicles: vehicles,
                                allUsers: allUsers,
                                trips: trips
                            )) { stat in
                                DashboardStatCard(stat: stat)
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Quick Actions ─────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Actions")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            HStack(spacing: 10) {
                                ForEach(DashboardMockData.quickActions) { action in
                                    DashboardQuickActionCard(action: action) {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        switch action.label {
                                        case "Add Vehicle":    viewModel.activeQuickAction = .addVehicle
                                        case "Assign Driver":  viewModel.activeQuickAction = .assignDriver
                                        case "Reports":        viewModel.activeQuickAction = .reports
                                        case "Alerts":         viewModel.activeQuickAction = .alerts
                                        case "Maintenance":    viewModel.activeQuickAction = .maintenance
                                        default: break
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }

                        // ── Fleet Utilization ─────────────────────
                        let totalVehiclesCount  = vehicles.count
                        let activeVehiclesCount = vehicles.filter { $0.status == .active }.count
                        let progress            = viewModel.getFleetUtilizationProgress(vehicles: vehicles)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 16) {
                                FleetCircularProgressView(progress: progress)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fleet Utilization")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                    Text("\(activeVehiclesCount) of \(totalVehiclesCount) vehicles active today")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)

                        // ── Recent Activity ───────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 8) {
                                Text("Recent Activity")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)

                                // Live badge count (events in last 24 h)
                                if badgeCount > 0 {
                                    Text("\(min(badgeCount, 99))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(AppTheme.Text.onDark)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .padding(.horizontal, 4)
                                        .background(AppTheme.Status.danger)
                                        .clipShape(Capsule())
                                }

                                Spacer()

                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    viewModel.showAllActivities = true
                                } label: {
                                    Text("See All")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Brand.primary)
                                }
                            }
                            .padding(.horizontal, 16)

                            if dashboardActivities.isEmpty {
                                // Empty state card
                                HStack {
                                    Spacer()
                                    VStack(spacing: 10) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 32))
                                            .foregroundColor(AppTheme.Text.tertiary.opacity(0.4))
                                        Text("No activity yet")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(AppTheme.Text.secondary)
                                        Text("Trips, alerts and maintenance events will appear here.")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(AppTheme.Text.tertiary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 20)
                                    }
                                    .padding(.vertical, 28)
                                    Spacer()
                                }
                                .background(AppTheme.Background.card)
                                .cornerRadius(AppTheme.Radius.card)
                                .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 16)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(
                                        Array(dashboardActivities.enumerated()),
                                        id: \.element.id
                                    ) { index, activity in
                                        DashboardActivityRow(activity: activity)

                                        if index < dashboardActivities.count - 1 {
                                            Divider().padding(.leading, 66)
                                        }
                                    }
                                }
                                .background(AppTheme.Background.card)
                                .cornerRadius(AppTheme.Radius.card)
                                .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            // Quick action sheets
            .sheet(item: $viewModel.activeQuickAction) { action in
                Group {
                    switch action {
                    case .addVehicle:   AddVehicleFormView()
                    case .assignDriver: AddTripFormView()
                    case .reports:      ReportsView()
                    case .alerts:       AlertsFeedView()
                    case .maintenance:  MaintenanceManagementView()
                    }
                }
                .environment(\.modelContext, modelContext)
            }
            // See All sheet
            .sheet(isPresented: $viewModel.showAllActivities) {
                AllActivitiesView()
                    .environment(\.modelContext, modelContext)
            }
            // Profile sheet
            .sheet(isPresented: $showProfile) {
                FleetManagerProfileView()
                    .environment(\.modelContext, modelContext)
            }
            .task {
                DatabaseSeeder.seedIfEmpty(context: modelContext)
                await SupabaseManager.shared.syncAllData(context: modelContext)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(15))
                    await SupabaseManager.shared.syncAllData(context: modelContext)
                }
            }

        }
    }
//    private var initials: String {
//        let parts = vm.driverName.components(separatedBy: " ")
//        if parts.count >= 2 {
//            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
//        }
//        return String(vm.driverName.prefix(2)).uppercased()
//    }
}



// MARK: - Circular progress

struct FleetCircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Glass.ringTrack, lineWidth: 6)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AppTheme.Brand.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))

            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Brand.primary)
        }
        .frame(width: 52, height: 52)
    }
}

#Preview {
    FleetDashboardView()
}
