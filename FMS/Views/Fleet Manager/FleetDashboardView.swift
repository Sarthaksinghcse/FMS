import SwiftUI
import SwiftData
import MapKit
import Supabase

@available(iOS 26.0, *)
struct FleetDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // Live data from SwiftData (synced from Supabase every 15 s)
    @Query private var vehicles:      [Vehicle]
    @Query private var allUsers:      [User]
    @Query(sort: \Trip.createdAt,         order: .reverse) private var trips:         [Trip]
    @Query(sort: \SOSAlert.createdAt,     order: .reverse) private var sosAlerts:     [SOSAlert]
    @Query(sort: \DefectReport.createdAt, order: .reverse) private var defectReports: [DefectReport]
    @Query(sort: \WorkOrder.createdAt,    order: .reverse) private var workOrders:    [WorkOrder]
    @Query private var complianceAlerts: [ComplianceAlert]

    @Binding var selectedTab: Int
    @State private var viewModel    = FleetDashboardViewModel()
    @State private var complianceVM = ComplianceAlertsViewModel()
    @State private var showProfile  = false
    @State private var showChat     = false
    @State private var showTracking = false
    @State private var realtimeChannel: RealtimeChannelV2? = nil

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

    private var managerFirstName: String {
        guard let name = SupabaseManager.shared.currentUser?.name, !name.isEmpty else { return "Manager" }
        return name.components(separatedBy: " ").first ?? name
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
                                Text(managerFirstName)
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
                                    ZStack {
                                        if let imageURLString = SupabaseManager.shared.currentUser?.profileImage,
                                           let imageURL = URL(string: imageURLString) {
                                            CachedAsyncImage(url: imageURL) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                            } placeholder: {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(AppTheme.Brand.primary)
                                            }
                                            .frame(width: 32, height: 32)
                                            .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(AppTheme.Brand.primary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Text("Overview")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)

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
                                NavigationLink(value: destinationFor(stat: stat)) {
                                    DashboardStatCard(stat: stat)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)

                        // ── Quick Actions ─────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Actions")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.quickActions) { action in
                                        DashboardQuickActionCard(action: action) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            switch action.label {
                                            case "Assign Driver":  viewModel.activeQuickAction = .assignDriver
                                            case "Alerts":         viewModel.activeQuickAction = .alerts
                                            case "Maintenance":    viewModel.activeQuickAction = .maintenance
                                            case "Tracking":       showTracking = true
                                            case "Chat":           showChat = true
                                            default: break
                                            }
                                        }
                                        .frame(width: 80)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 4)
                        }



                        // ── Compliance & Renewal Alerts ───────────
                        complianceAlertsSummary

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
                                        Button {
                                            handleActivityTap(activity)
                                        } label: {
                                            DashboardActivityRow(activity: activity)
                                        }
                                        .buttonStyle(PlainButtonStyle())

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
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    await SupabaseManager.shared.syncAllData(context: modelContext)
                }
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
                AllActivitiesView { activity in
                    handleActivityTap(activity)
                }
                .environment(\.modelContext, modelContext)
            }
            // Profile sheet
            .sheet(isPresented: $showProfile) {
                FleetManagerProfileView()
                    .environment(\.modelContext, modelContext)
            }
            // Chat sheet
            .sheet(isPresented: $showChat) {
                FleetManagerChatListView()
            }
            .task {
                await SupabaseManager.shared.syncAllData(context: modelContext)
                startRealtimeListener()
            }
            .onDisappear {
                if let activeChannel = realtimeChannel {
                    let client = SupabaseManager.shared.client
                    Task {
                        await client.removeChannel(activeChannel)
                    }
                    realtimeChannel = nil
                }
            }
            .navigationDestination(for: DashboardNavigationDestination.self) { destination in
                switch destination {
                case .totalVehicles:
                    VehicleListView(initialFilter: .all)
                        .environment(\.modelContext, modelContext)
                case .activeNow:
                    VehicleListView(initialFilter: .active)
                        .environment(\.modelContext, modelContext)
                case .driversOnline:
                    DriverListView(initialFilter: .online)
                        .environment(\.modelContext, modelContext)
                case .liveTrips:
                    TripListView(initialFilter: .active)
                        .environment(\.modelContext, modelContext)
                }
            }
            // Tracking navigation push
            .navigationDestination(isPresented: $showTracking) {
                FleetTrackingView()
                    .environment(\.modelContext, modelContext)
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

    // MARK: - Compliance Summary Card

    private var complianceAlertsSummary: some View {
        let allItems = complianceVM.generateAlerts(vehicles: vehicles, persistedAlerts: complianceAlerts)
        let overdueCount = complianceVM.overdueCount(from: allItems)
        let upcomingCount = complianceVM.upcomingCount(from: allItems)
        let totalActive = overdueCount + upcomingCount

        return NavigationLink(destination: ComplianceAlertsView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                overdueCount > 0
                                    ? ComplianceAlertStatus.overdue.color.opacity(0.12)
                                    : AppTheme.Brand.primary.opacity(0.08)
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 18))
                            .foregroundColor(
                                overdueCount > 0
                                    ? ComplianceAlertStatus.overdue.color
                                    : AppTheme.Brand.primary
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compliance & Renewals")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)

                        Text(complianceSummaryText(overdue: overdueCount, upcoming: upcomingCount))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if totalActive > 0 {
                        Text("\(totalActive)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(
                                overdueCount > 0
                                    ? ComplianceAlertStatus.overdue.color
                                    : ComplianceAlertStatus.upcoming.color
                            )
                            .clipShape(Circle())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
                }
            }
            .padding(14)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .stroke(
                        overdueCount > 0
                            ? ComplianceAlertStatus.overdue.color.opacity(0.25)
                            : AppTheme.Glass.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func complianceSummaryText(overdue: Int, upcoming: Int) -> String {
        if overdue == 0 && upcoming == 0 {
            return "All vehicles within compliance limits"
        } else if overdue > 0 {
            return "\(overdue) alert\(overdue == 1 ? "" : "s") require immediate attention"
        } else {
            return "\(upcoming) renewal\(upcoming == 1 ? "" : "s") due soon"
        }
    }

    private func destinationFor(stat: DashboardStat) -> DashboardNavigationDestination {
        switch stat.label {
        case "Total Vehicles": return .totalVehicles
        case "Available Now":  return .activeNow
        case "Drivers Online": return .driversOnline
        case "Live Trips":     return .liveTrips
        default:               return .totalVehicles
        }
    }
    
    private func handleActivityTap(_ activity: DashboardActivity) {
        if activity.title.contains("Defect") || activity.title.contains("SOS") {
            viewModel.activeQuickAction = .alerts
        } else if activity.title.contains("Work Order") {
            viewModel.activeQuickAction = .maintenance
        } else if activity.title.contains("Trip") {
            selectedTab = 1
        }
    }

    private func startRealtimeListener() {
        guard realtimeChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("fleet_manager_realtime_channel")
        self.realtimeChannel = channel
        
        Task {
            let tripsStream = channel.postgresChange(AnyAction.self, schema: "public", table: "trips")
            let sosStream = channel.postgresChange(AnyAction.self, schema: "public", table: "sos_alerts")
            let defectStream = channel.postgresChange(AnyAction.self, schema: "public", table: "defect_reports")
            let workOrderStream = channel.postgresChange(AnyAction.self, schema: "public", table: "work_orders")
            let notifStream = channel.postgresChange(AnyAction.self, schema: "public", table: "notifications")
            let taskStream = channel.postgresChange(AnyAction.self, schema: "public", table: "maintenance_tasks")
            let vehicleStream = channel.postgresChange(AnyAction.self, schema: "public", table: "vehicles")
            let fuelStream = channel.postgresChange(AnyAction.self, schema: "public", table: "fuel_logs")
            let complianceStream = channel.postgresChange(AnyAction.self, schema: "public", table: "compliance_alerts")
            
            try? await channel.subscribeWithError()
            
            async let _ : () = handleStream(tripsStream)
            async let _ : () = handleStream(sosStream)
            async let _ : () = handleStream(defectStream)
            async let _ : () = handleStream(workOrderStream)
            async let _ : () = handleStream(notifStream)
            async let _ : () = handleStream(taskStream)
            async let _ : () = handleStream(vehicleStream)
            async let _ : () = handleStream(fuelStream)
            async let _ : () = handleStream(complianceStream)
        }
    }
    
    private func handleStream<S: AsyncSequence>(_ stream: S) async {
        do {
            for try await _ in stream {
                await SupabaseManager.shared.syncAllData(context: modelContext)
            }
        } catch {
            print("Stream error: \(error)")
        }
    }
}

@available(iOS 26.0, *)
enum DashboardNavigationDestination: Hashable {
    case totalVehicles
    case activeNow
    case driversOnline
    case liveTrips
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
    FleetDashboardView(selectedTab: .constant(0))
}
