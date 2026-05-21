//
//  DriverDashboardView.swift
//  FMS
//
//  Created for Fleet Management System
//  Target: iOS 26+
//  Architecture: MVVM with async/await
//

import SwiftUI

// MARK: - Design System

private extension Color {
    /// Primary brand accent — Deep Indigo
    static let accentIndigo = Color(red: 0.2, green: 0.2, blue: 0.6)
    /// Lighter tint of the accent for backgrounds / badges
    static let accentIndigoLight = Color(red: 0.2, green: 0.2, blue: 0.6).opacity(0.12)
    /// Card surface colour
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    /// Screen background
    static let screenBackground = Color(UIColor.systemBackground)
}

// MARK: - Driver Status

enum DriverStatus: String, CaseIterable {
    case active      = "Active"
    case idle        = "Idle"
    case maintenance = "Maintenance"
    case offline     = "Offline"

    var color: Color {
        switch self {
        case .active:      return .green
        case .idle:        return .yellow
        case .maintenance: return Color.orange
        case .offline:     return Color(UIColor.systemGray3)
        }
    }

    var icon: String {
        switch self {
        case .active:      return "checkmark.circle.fill"
        case .idle:        return "pause.circle.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .offline:     return "xmark.circle.fill"
        }
    }
}

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let accentColor: Color
    let destination: DriverNavDestination
}

// MARK: - Navigation Destinations

enum DriverNavDestination: Hashable {
    case tripDetail
    case routeNavigation
    case voiceLog
    case reportIssue
    case preTrip
    case postTrip
    case defectReport
    case messaging
}

// MARK: - Message Model (Mock)

struct DriverMessage: Identifiable {
    let id = UUID()
    let sender: String
    let senderRole: String
    let preview: String
    let time: String
    let isUnread: Bool
    let avatarInitials: String
}

// MARK: - Notification Banner Model

struct DashboardNotification: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let type: NotificationType
    enum NotificationType { case info, warning, urgent }
    var color: Color {
        switch type {
        case .info:    return .accentIndigo
        case .warning: return Color.orange
        case .urgent:  return .red
        }
    }
    var icon: String {
        switch type {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .urgent:  return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class DriverDashboardViewModel: ObservableObject {

    // MARK: Published State

    @Published var driverStatus: DriverStatus = .idle
    @Published var currentTrip: DBTrip?
    @Published var assignedVehicle: DBVehicle?
    @Published var upcomingTrips: [DBTrip] = []
    @Published var messages: [DriverMessage] = []
    @Published var notifications: [DashboardNotification] = []
    @Published var isTripActive: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var tripElapsedSeconds: Int = 0
    @Published var estimatedDistanceKm: Double = 0
    @Published var fuelLevelPercent: Double = 0.72
    @Published var showVoiceLogSheet: Bool = false
    @Published var showIssueSheet: Bool = false
    @Published var showPreTripSheet: Bool = false
    @Published var showPostTripSheet: Bool = false
    @Published var showDefectSheet: Bool = false
    @Published var showMessagingSheet: Bool = false
    @Published var tripStartConfirmPresented: Bool = false
    @Published var tripEndConfirmPresented: Bool = false

    // MARK: Private

    private var tripTimer: Timer?
    private let supabaseManager = SupabaseManager.shared

    // MARK: Init

    init() {
        loadMockData()
    }

    // MARK: - Data Loading

    func loadDashboardData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let trips = try await supabaseManager.fetchTrips()
            let vehicles = try await supabaseManager.fetchVehicles()

            // Filter for current driver
            if let driverId = supabaseManager.currentUser?.id {
                let driverTrips = trips.filter { $0.driverId == driverId }
                currentTrip = driverTrips.first(where: { $0.status == .started })
                upcomingTrips = driverTrips.filter { $0.status == .assigned }
                isTripActive = currentTrip != nil
                driverStatus = isTripActive ? .active : .idle

                if let vehicleId = currentTrip?.vehicleId {
                    assignedVehicle = vehicles.first(where: { $0.id == vehicleId })
                } else if let vid = driverTrips.first?.vehicleId {
                    assignedVehicle = vehicles.first(where: { $0.id == vid })
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to mock data so UI is never empty
            loadMockData()
        }
    }

    // MARK: - Trip Actions

    func startTrip() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isTripActive = true
            driverStatus = .active
            tripElapsedSeconds = 0
            estimatedDistanceKm = upcomingTrips.first?.distance ?? 42.5
        }
        tripTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tripElapsedSeconds += 1
            }
        }
    }

    func endTrip() {
        tripTimer?.invalidate()
        tripTimer = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            isTripActive = false
            driverStatus = .idle
            currentTrip = nil
        }
    }

    // MARK: - Helpers

    var formattedElapsedTime: String {
        let h = tripElapsedSeconds / 3600
        let m = (tripElapsedSeconds % 3600) / 60
        let s = tripElapsedSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var driverName: String {
        supabaseManager.currentUser?.name.components(separatedBy: " ").first ?? "Driver"
    }

    // MARK: - Mock Data

    private func loadMockData() {
        upcomingTrips = [
            DBTrip(
                id: UUID(),
                vehicleId: UUID(),
                driverId: UUID(),
                source: "Warehouse A – Sector 17",
                destination: "Distribution Hub – Phase 5",
                startTime: Calendar.current.date(byAdding: .hour, value: 1, to: Date()),
                endTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date()),
                distance: 48.2,
                status: .assigned,
                notes: "Priority delivery — handle with care",
                createdAt: Date()
            ),
            DBTrip(
                id: UUID(),
                vehicleId: UUID(),
                driverId: UUID(),
                source: "Distribution Hub – Phase 5",
                destination: "Client Site – Noida",
                startTime: Calendar.current.date(byAdding: .hour, value: 6, to: Date()),
                endTime: Calendar.current.date(byAdding: .hour, value: 9, to: Date()),
                distance: 31.0,
                status: .assigned,
                notes: nil,
                createdAt: Date()
            )
        ]

        messages = [
            DriverMessage(
                sender: "Rajiv Sharma",
                senderRole: "Fleet Manager",
                preview: "Please confirm ETA for Route 2 delivery.",
                time: "10:32 AM",
                isUnread: true,
                avatarInitials: "RS"
            ),
            DriverMessage(
                sender: "Maintenance Desk",
                senderRole: "Maintenance",
                preview: "Vehicle TN-07-AB-1234 serviced. Ready for dispatch.",
                time: "9:15 AM",
                isUnread: true,
                avatarInitials: "MD"
            ),
            DriverMessage(
                sender: "Priya Menon",
                senderRole: "Fleet Manager",
                preview: "Updated route file sent. Check route nav.",
                time: "Yesterday",
                isUnread: false,
                avatarInitials: "PM"
            )
        ]

        notifications = [
            DashboardNotification(
                title: "Trip Assigned",
                body: "New trip #TRP-2240 assigned for 12:30 PM",
                type: .info
            ),
            DashboardNotification(
                title: "Pre-Trip Due",
                body: "Complete vehicle inspection before departure",
                type: .warning
            )
        ]
    }
}

// MARK: - Main Dashboard View

@available(iOS 26.0, *)
struct DriverDashboardView: View {

    @StateObject private var viewModel = DriverDashboardViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: Int = 0

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                Color.screenBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Header ──────────────────────────────────────────
                        headerSection

                        VStack(spacing: 20) {
                            // ── Notification Banners ────────────────────────
                            if !viewModel.notifications.isEmpty {
                                notificationBanners
                            }

                            // ── Trip Control Card ───────────────────────────
                            tripControlCard

                            // ── Quick Actions Grid ──────────────────────────
                            quickActionsGrid

                            // ── Assigned Routes ─────────────────────────────
                            upcomingTripsSection

                            // ── Vehicle Status ──────────────────────────────
                            vehicleStatusCard

                            // ── Messages Preview ────────────────────────────
                            messagesSection

                            Spacer(minLength: 32)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await viewModel.loadDashboardData() }
            // ── Sheets ──────────────────────────────────────────────────────
            .sheet(isPresented: $viewModel.showVoiceLogSheet)         { VoiceTripLogSheet() }
            .sheet(isPresented: $viewModel.showIssueSheet)            { ReportIssueSheet() }
            .sheet(isPresented: $viewModel.showPreTripSheet)          { VehicleInspectionSheet(type: .preTrip) }
            .sheet(isPresented: $viewModel.showPostTripSheet)         { VehicleInspectionSheet(type: .postTrip) }
            .sheet(isPresented: $viewModel.showDefectSheet)           { DefectReportSheet() }
            .sheet(isPresented: $viewModel.showMessagingSheet)        { MessagingSheet(messages: viewModel.messages) }
            // ── Confirmations ────────────────────────────────────────────────
            .confirmationDialog("Start Trip", isPresented: $viewModel.tripStartConfirmPresented, titleVisibility: .visible) {
                Button("Start Trip Now") { viewModel.startTrip() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will begin the trip timer and record your location. Ensure you have completed the pre-trip inspection.")
            }
            .confirmationDialog("End Trip", isPresented: $viewModel.tripEndConfirmPresented, titleVisibility: .visible) {
                Button("End Trip", role: .destructive) { viewModel.endTrip() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Confirm that you have completed all deliveries and are ready to end this trip.")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [Color.accentIndigo, Color(red: 0.15, green: 0.15, blue: 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.greeting)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(viewModel.driverName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Status pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.driverStatus.color)
                            .frame(width: 8, height: 8)
                            .shadow(color: viewModel.driverStatus.color.opacity(0.8), radius: 4)
                        Text(viewModel.driverStatus.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())

                    // Avatar
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Text(viewModel.driverName.prefix(1))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Driver profile avatar")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Stats row
                HStack(spacing: 0) {
                    headerStat(value: "\(viewModel.upcomingTrips.count)", label: "Trips Today")
                    Divider().frame(width: 1, height: 30).background(.white.opacity(0.3))
                    headerStat(value: String(format: "%.0f km", viewModel.upcomingTrips.reduce(0) { $0 + $1.distance }), label: "Est. Distance")
                    Divider().frame(width: 1, height: 30).background(.white.opacity(0.3))
                    headerStat(value: String(format: "%.0f%%", viewModel.fuelLevelPercent * 100), label: "Fuel Level")
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func headerStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Notification Banners

    private var notificationBanners: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.notifications) { notif in
                HStack(spacing: 12) {
                    Image(systemName: notif.icon)
                        .foregroundStyle(notif.color)
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notif.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(notif.body)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(notif.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(notif.color.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Trip Control Card

    private var tripControlCard: some View {
        VStack(spacing: 0) {
            // Card header
            HStack {
                Label("Trip Management", systemImage: "car.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentIndigo)
                Spacer()
                if viewModel.isTripActive {
                    // Live indicator
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.red)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(.red.opacity(0.4), lineWidth: 4))
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            if viewModel.isTripActive {
                // Active trip info
                activeTripView
            } else {
                // Next trip preview
                idleTripView
            }

            // Start / End button
            Button {
                if viewModel.isTripActive {
                    viewModel.tripEndConfirmPresented = true
                } else {
                    viewModel.tripStartConfirmPresented = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isTripActive ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(viewModel.isTripActive ? "End Trip" : "Start Trip")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    viewModel.isTripActive
                        ? Color.red
                        : Color.accentIndigo
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 12)
            .accessibilityLabel(viewModel.isTripActive ? "End current trip" : "Start assigned trip")
            .accessibilityHint("Double-tap to confirm action")
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private var activeTripView: some View {
        VStack(spacing: 14) {
            // Timer
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Elapsed Time")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(viewModel.formattedElapsedTime)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentIndigo)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Distance")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f km", viewModel.estimatedDistanceKm))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Route summary
            if let trip = viewModel.currentTrip ?? viewModel.upcomingTrips.first {
                routeRow(from: trip.source, to: trip.destination)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var idleTripView: some View {
        VStack(spacing: 14) {
            if let trip = viewModel.upcomingTrips.first {
                VStack(spacing: 10) {
                    routeRow(from: trip.source, to: trip.destination)
                    HStack(spacing: 16) {
                        tripMeta(icon: "arrow.left.arrow.right", label: String(format: "%.1f km", trip.distance))
                        if let start = trip.startTime {
                            tripMeta(icon: "clock", label: start.formatted(.dateTime.hour().minute()))
                        }
                        tripMeta(icon: "shippingbox", label: trip.notes != nil ? "Priority" : "Standard")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                Text("No trips assigned for today")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private func routeRow(from source: String, to destination: String) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Circle().fill(Color.accentIndigo).frame(width: 10, height: 10)
                Rectangle().fill(Color.accentIndigo.opacity(0.3)).frame(width: 2, height: 24)
                Circle().fill(Color.green).frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(source)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(destination)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentIndigo)
        }
    }

    private func tripMeta(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentIndigo)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick Actions Grid

    private var quickActionsData: [QuickAction] {
        [
            QuickAction(title: "Route Nav", subtitle: "Smart navigation", systemImage: "location.fill.viewfinder", accentColor: Color.accentIndigo, destination: .routeNavigation),
            QuickAction(title: "Voice Log", subtitle: "Log by speaking", systemImage: "mic.fill", accentColor: Color(red: 0.2, green: 0.55, blue: 0.8), destination: .voiceLog),
            QuickAction(title: "Report Issue", subtitle: "Delays & problems", systemImage: "exclamationmark.bubble.fill", accentColor: Color.orange, destination: .reportIssue),
            QuickAction(title: "Pre-Trip", subtitle: "Inspection form", systemImage: "checklist", accentColor: Color(red: 0.12, green: 0.6, blue: 0.45), destination: .preTrip),
            QuickAction(title: "Post-Trip", subtitle: "End inspection", systemImage: "checkmark.seal.fill", accentColor: Color(red: 0.12, green: 0.6, blue: 0.45), destination: .postTrip),
            QuickAction(title: "Defect", subtitle: "Report damage", systemImage: "wrench.and.screwdriver.fill", accentColor: Color.red, destination: .defectReport),
        ]
    }

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(quickActionsData) { action in
                    QuickActionTile(action: action) {
                        handleQuickAction(action.destination)
                    }
                }
            }
        }
    }

    private func handleQuickAction(_ destination: DriverNavDestination) {
        switch destination {
        case .routeNavigation: navigationPath.append(destination)
        case .voiceLog:        viewModel.showVoiceLogSheet = true
        case .reportIssue:     viewModel.showIssueSheet = true
        case .preTrip:         viewModel.showPreTripSheet = true
        case .postTrip:        viewModel.showPostTripSheet = true
        case .defectReport:    viewModel.showDefectSheet = true
        case .tripDetail:      navigationPath.append(destination)
        case .messaging:       viewModel.showMessagingSheet = true
        }
    }

    // MARK: - Upcoming Trips Section

    private var upcomingTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Assigned Routes")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("See All") { navigationPath.append(DriverNavDestination.tripDetail) }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentIndigo)
            }
            .padding(.horizontal, 4)

            if viewModel.upcomingTrips.isEmpty {
                emptyStateView(icon: "mappin.slash", message: "No routes assigned")
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.upcomingTrips.prefix(2).enumerated()), id: \.offset) { index, trip in
                        AssignedRouteTile(trip: trip, index: index)
                    }
                }
            }
        }
    }

    // MARK: - Vehicle Status Card

    private var vehicleStatusCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Assigned Vehicle", systemImage: "car.rear.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentIndigo)
                Spacer()
                Button {
                    viewModel.showDefectSheet = true
                } label: {
                    Text("Report Defect")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 20) {
                VehicleStatCell(label: "Vehicle", value: "TN-07-AB-1234", icon: "number")
                VehicleStatCell(label: "Fuel", value: String(format: "%.0f%%", viewModel.fuelLevelPercent * 100), icon: "fuelpump.fill")
                VehicleStatCell(label: "Odometer", value: "12,430 km", icon: "gauge")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Fuel bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Fuel Level")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.fuelLevelPercent * 100))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewModel.fuelLevelPercent < 0.25 ? .red : Color.accentIndigo)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentIndigo.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: viewModel.fuelLevelPercent < 0.25
                                        ? [.red, .orange]
                                        : [Color.accentIndigo, Color(red: 0.35, green: 0.35, blue: 0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * viewModel.fuelLevelPercent, height: 8)
                            .animation(.easeInOut(duration: 0.6), value: viewModel.fuelLevelPercent)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Messages")
                    .font(.system(size: 17, weight: .semibold))
                if viewModel.messages.filter(\.isUnread).count > 0 {
                    Text("\(viewModel.messages.filter { $0.isUnread }.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                Spacer()
                Button("Open") { viewModel.showMessagingSheet = true }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentIndigo)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.messages.prefix(3).enumerated()), id: \.offset) { index, msg in
                    MessagePreviewRow(message: msg)
                    if index < 2 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            .onTapGesture { viewModel.showMessagingSheet = true }
        }
    }

    // MARK: - Helpers

    private func emptyStateView(icon: String, message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentIndigo.opacity(0.4))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Quick Action Tile

private struct QuickActionTile: View {
    let action: QuickAction
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(action.accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: action.systemImage)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(action.accentColor)
                }
                VStack(spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(action.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { isPressed = false } }
        )
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }
}

// MARK: - Assigned Route Tile

private struct AssignedRouteTile: View {
    let trip: DBTrip
    let index: Int

    private var statusColor: Color {
        switch trip.status {
        case .assigned:  return Color.accentIndigo
        case .started:   return .green
        case .completed: return Color(UIColor.systemGray)
        case .cancelled: return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Index badge
            Text("#\(index + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentIndigo.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(trip.source) → \(trip.destination)")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 10) {
                    if let start = trip.startTime {
                        Label(start.formatted(.dateTime.hour().minute()), systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Label(String(format: "%.1f km", trip.distance), systemImage: "road.lanes")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status badge
            Text(trip.status.rawValue.capitalized)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Vehicle Stat Cell

private struct VehicleStatCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.accentIndigo)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message Preview Row

private struct MessagePreviewRow: View {
    let message: DriverMessage

    private var roleColor: Color {
        switch message.senderRole {
        case "Fleet Manager":  return Color.accentIndigo
        case "Maintenance":    return Color.orange
        default:               return Color(UIColor.systemGray)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(message.avatarInitials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(roleColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(message.sender)
                        .font(.system(size: 13, weight: message.isUnread ? .semibold : .regular))
                    Spacer()
                    Text(message.time)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text(message.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if message.isUnread {
                Circle()
                    .fill(Color.accentIndigo)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.sender): \(message.preview)")
    }
}

// MARK: - Voice Trip Log Sheet

struct VoiceTripLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var transcript = ""
    @State private var recordingSeconds = 0
    @State private var timer: Timer?
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Waveform animation area
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.accentIndigo.opacity(isRecording ? 0.15 : 0), lineWidth: 1.5)
                            .frame(width: CGFloat(110 + i * 40), height: CGFloat(110 + i * 40))
                            .scaleEffect(isRecording ? 1 : 0.85)
                            .animation(
                                isRecording
                                    ? .easeInOut(duration: 1.2).repeatForever().delay(Double(i) * 0.3)
                                    : .default,
                                value: isRecording
                            )
                    }
                    ZStack {
                        Circle()
                            .fill(
                                isRecording
                                    ? LinearGradient(colors: [.red, Color(red: 0.9, green: 0.2, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.accentIndigo, Color(red: 0.35, green: 0.35, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: (isRecording ? Color.red : Color.accentIndigo).opacity(0.4), radius: 20)
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .onTapGesture { toggleRecording() }
                }
                .frame(height: 220)

                // Timer + status
                VStack(spacing: 6) {
                    Text(isRecording ? String(format: "%02d:%02d", recordingSeconds / 60, recordingSeconds % 60) : "Tap to Record")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(isRecording ? .red : Color.accentIndigo)
                    Text(isRecording ? "Recording voice log…" : "Speak your trip notes, delays, or mileage updates")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Transcript area
                if !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Transcript", systemImage: "text.quote")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentIndigo)
                        Text(transcript)
                            .font(.system(size: 14))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.accentIndigoLight)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Submit
                if !transcript.isEmpty {
                    Button {
                        showConfirmation = true
                    } label: {
                        Label("Save Voice Log", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.accentIndigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Voice Trip Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentIndigo)
                }
            }
            .alert("Log Saved", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your voice log has been saved successfully.")
            }
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            recordingSeconds = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                recordingSeconds += 1
            }
        } else {
            timer?.invalidate()
            timer = nil
            // Simulate transcript
            transcript = "Trip log recorded at \(Date().formatted(.dateTime.hour().minute())). Departed Warehouse A on time. Minor traffic on NH-8 near sector 14. ETA revised to 2:45 PM."
        }
    }
}

// MARK: - Report Issue Sheet

struct ReportIssueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssue: IssueType = .delay
    @State private var description = ""
    @State private var severity: IssueSeverity = .medium
    @State private var submitted = false

    enum IssueType: String, CaseIterable {
        case delay      = "Trip Delay"
        case accident   = "Accident / Incident"
        case traffic    = "Heavy Traffic"
        case roadblock  = "Road Block"
        case breakdown  = "Vehicle Breakdown"
        case other      = "Other"
        var icon: String {
            switch self {
            case .delay:     return "clock.badge.exclamationmark"
            case .accident:  return "car.side.arrowtriangle.up"
            case .traffic:   return "road.lanes"
            case .roadblock: return "xmark.octagon"
            case .breakdown: return "wrench.adjustable"
            case .other:     return "ellipsis.bubble"
            }
        }
    }

    enum IssueSeverity: String, CaseIterable {
        case low = "Low", medium = "Medium", high = "High"
        var color: Color {
            switch self {
            case .low:    return .green
            case .medium: return .orange
            case .high:   return .red
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(IssueType.allCases, id: \.self) { type in
                            Button {
                                withAnimation { selectedIssue = type }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedIssue == type ? Color.accentIndigo : Color(UIColor.systemGray))
                                    Text(type.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selectedIssue == type ? Color.accentIndigo : .secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedIssue == type ? Color.accentIndigoLight : Color(UIColor.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedIssue == type ? Color.accentIndigo : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Issue Type")
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(IssueSeverity.allCases, id: \.self) { s in
                            Label(s.rawValue, systemImage: "circle.fill")
                                .foregroundStyle(s.color)
                                .tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section("Description") {
                    TextField("Describe the issue in detail…", text: $description, axis: .vertical)
                        .lineLimit(4...8)
                        .font(.system(size: 14))
                }

                Section {
                    Button {
                        submitted = true
                    } label: {
                        Label("Submit Report", systemImage: "paperplane.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .background(Color.accentIndigo)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accentIndigo)
                }
            }
            .alert("Report Submitted", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your issue report has been sent to the fleet manager.")
            }
        }
    }
}

// MARK: - Vehicle Inspection Sheet

struct VehicleInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let type: InspectionType

    enum InspectionType { case preTrip, postTrip }

    @State private var checks: [InspectionCheck] = InspectionCheck.defaultChecks
    @State private var remarks = ""
    @State private var defectFound = false
    @State private var isSubmitting = false
    @State private var submitted = false

    var title: String { type == .preTrip ? "Pre-Trip Inspection" : "Post-Trip Inspection" }
    var allPassed: Bool { checks.allSatisfy { $0.passed } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill((type == .preTrip ? Color.accentIndigo : Color.green).opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: type == .preTrip ? "car.side.fill" : "flag.checkered")
                                .font(.system(size: 24))
                                .foregroundStyle(type == .preTrip ? Color.accentIndigo : .green)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Vehicle TN-07-AB-1234")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text(Date().formatted(.dateTime.day().month().year().hour().minute()))
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Checklist") {
                    ForEach($checks) { $check in
                        HStack {
                            Image(systemName: check.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(check.passed ? .green : Color(UIColor.systemGray3))
                                .frame(width: 28)
                            Text(check.label)
                                .font(.system(size: 14))
                            Spacer()
                            Toggle("", isOn: $check.passed)
                                .labelsHidden()
                                .tint(Color.accentIndigo)
                        }
                    }
                }

                Section("Defect Found?") {
                    Toggle(isOn: $defectFound) {
                        Label("Report a Defect", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(defectFound ? .red : .secondary)
                    }
                    .tint(.red)
                }

                Section("Remarks (Optional)") {
                    TextField("Any additional notes…", text: $remarks, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 14))
                }

                Section {
                    Button {
                        Task { await submitInspection() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label(
                                    allPassed ? "Submit — All Passed ✓" : "Submit Inspection",
                                    systemImage: "checkmark.seal.fill"
                                )
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 44)
                        .background(allPassed ? Color.green : Color.accentIndigo)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.accentIndigo)
                }
            }
            .alert(allPassed ? "Inspection Passed" : "Inspection Submitted", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text(allPassed
                     ? "All checklist items passed. You are cleared for departure."
                     : "Inspection recorded. Issues flagged for maintenance review.")
            }
        }
    }

    @MainActor
    private func submitInspection() async {
        isSubmitting = true
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isSubmitting = false
        submitted = true
    }
}

// MARK: - Inspection Check Model

struct InspectionCheck: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    var passed: Bool = false

    static let defaultChecks: [InspectionCheck] = [
        InspectionCheck(label: "Brakes & Brake Lights",  icon: "hand.raised.fill"),
        InspectionCheck(label: "Tyres & Tyre Pressure",  icon: "circle.dashed"),
        InspectionCheck(label: "Engine & Oil Level",     icon: "gearshape.fill"),
        InspectionCheck(label: "Headlights & Indicators",icon: "lightbulb.fill"),
        InspectionCheck(label: "Windshield & Wipers",    icon: "cloud.drizzle.fill"),
        InspectionCheck(label: "Seat Belts",             icon: "figure.walk.circle.fill"),
        InspectionCheck(label: "Mirrors",                icon: "arrow.left.and.right"),
        InspectionCheck(label: "Horn",                   icon: "megaphone.fill"),
        InspectionCheck(label: "First Aid Kit",          icon: "cross.case.fill"),
        InspectionCheck(label: "Documents & Permits",    icon: "doc.text.fill"),
    ]
}

// MARK: - Defect Report Sheet

struct DefectReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var severity: DefectSeverityLevel = .medium
    @State private var selectedPart: VehiclePart = .engine
    @State private var submitted = false
    @State private var isSubmitting = false

    enum DefectSeverityLevel: String, CaseIterable {
        case low = "Low", medium = "Medium", high = "High"
        var color: Color {
            switch self { case .low: return .green; case .medium: return .orange; case .high: return .red }
        }
    }

    enum VehiclePart: String, CaseIterable {
        case engine = "Engine", brakes = "Brakes", tyres = "Tyres"
        case lights = "Lights", bodywork = "Bodywork", other = "Other"
        var icon: String {
            switch self {
            case .engine:   return "gearshape.fill"
            case .brakes:   return "hand.raised.fill"
            case .tyres:    return "circle.dashed"
            case .lights:   return "lightbulb.fill"
            case .bodywork: return "car.fill"
            case .other:    return "wrench.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Part selector
                Section("Affected Component") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(VehiclePart.allCases, id: \.self) { part in
                            Button { withAnimation { selectedPart = part } } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: part.icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedPart == part ? Color.accentIndigo : .secondary)
                                    Text(part.rawValue)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(selectedPart == part ? Color.accentIndigo : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedPart == part ? Color.accentIndigoLight : Color(UIColor.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedPart == part ? Color.accentIndigo : .clear, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Defect Title") {
                    TextField("e.g. Oil leak near rear axle", text: $title)
                        .font(.system(size: 14))
                }

                Section("Description") {
                    TextField("Describe the defect in detail…", text: $description, axis: .vertical)
                        .lineLimit(4...8)
                        .font(.system(size: 14))
                }

                Section("Severity") {
                    Picker("Severity", selection: $severity) {
                        ForEach(DefectSeverityLevel.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        Task { await submitDefect() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Label("Submit Defect Report", systemImage: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 44)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(title.isEmpty || description.isEmpty)
                    .opacity(title.isEmpty || description.isEmpty ? 0.5 : 1)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle("Report Defect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.accentIndigo)
                }
            }
            .alert("Defect Reported", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text("The defect has been reported and flagged for immediate maintenance review.")
            }
        }
    }

    @MainActor
    private func submitDefect() async {
        isSubmitting = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        isSubmitting = false
        submitted = true
    }
}

// MARK: - Messaging Sheet

struct MessagingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [DriverMessage]
    @State private var newMessage = ""
    @State private var selectedThread: DriverMessage?
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            List {
                if showCompose {
                    Section("New Message") {
                        HStack(spacing: 10) {
                            TextField("Type a message…", text: $newMessage)
                                .font(.system(size: 14))
                                .textFieldStyle(.plain)
                            Button {
                                withAnimation { newMessage = "" ; showCompose = false }
                            } label: {
                                Image(systemName: "paperplane.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.accentIndigo)
                            }
                            .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Conversations") {
                    ForEach(messages) { msg in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentIndigo.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Text(msg.avatarInitials)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.accentIndigo)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(msg.sender)
                                        .font(.system(size: 14, weight: msg.isUnread ? .semibold : .regular))
                                    Spacer()
                                    Text(msg.time)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }
                                Text(msg.senderRole)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.accentIndigo)
                                Text(msg.preview)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if msg.isUnread {
                                Circle().fill(Color.accentIndigo).frame(width: 9, height: 9)
                            }
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.accentIndigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showCompose.toggle() }
                    } label: {
                        Image(systemName: showCompose ? "xmark" : "square.and.pencil")
                            .foregroundStyle(Color.accentIndigo)
                    }
                    .accessibilityLabel(showCompose ? "Close compose" : "Compose new message")
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Driver Dashboard") {
    DriverDashboardView()
}
