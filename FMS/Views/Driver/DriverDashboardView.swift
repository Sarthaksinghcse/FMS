//
//  DriverDashboardView.swift
//  FMS
//
//  Root entry point for the Driver experience.
//  Hosts the two-tab layout and owns the shared ViewModel.
//  Target: iOS 26+ — uses Liquid Glass materials throughout.
//

import SwiftUI
import MapKit
import Combine


// MARK: - Design Tokens

extension Color {
    static let fmsIndigo      = Color(red: 0.20, green: 0.20, blue: 0.60)
    static let fmsIndigoLight = Color(red: 0.20, green: 0.20, blue: 0.60).opacity(0.10)
    static let fmsCard        = Color(UIColor.secondarySystemBackground)
    static let fmsBackground  = Color(UIColor.systemBackground)
}

// MARK: - Driver Status

enum DriverOnlineStatus: String, CaseIterable {
    case active = "Active", idle = "Idle", maintenance = "Maintenance", offline = "Offline"

    var dot: Color {
        switch self {
        case .active:      return Color(red: 0.2, green: 0.78, blue: 0.35)
        case .idle:        return Color(red: 0.98, green: 0.78, blue: 0.10)
        case .maintenance: return Color(red: 0.95, green: 0.50, blue: 0.15)
        case .offline:     return Color(UIColor.systemGray3)
        }
    }
}

// MARK: - Dashboard Action

enum DashboardAction {
    case voiceLog, reportIssue, preTrip, postTrip, defect, messaging
}

// MARK: - Local UI Models

struct DriverQuickAction: Identifiable {
    let id   = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: DashboardAction
}

struct DriverChatMessage: Identifiable {
    let id       = UUID()
    let sender: String
    let role: String
    let preview: String
    let time: String
    let unread: Bool
    let initials: String
}

struct DashboardBanner: Identifiable {
    let id    = UUID()
    let title: String
    let body: String
    let kind: BannerKind

    enum BannerKind { case info, warning, urgent }

    var tint: Color {
        switch kind {
        case .info:    return .fmsIndigo
        case .warning: return Color(red: 0.95, green: 0.50, blue: 0.15)
        case .urgent:  return Color(red: 0.85, green: 0.15, blue: 0.15)
        }
    }
    var icon: String {
        switch kind {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .urgent:  return "exclamationmark.octagon.fill"
        }
    }
}

struct DashboardUser {
    let id: UUID
    let name: String
}



private actor DriverDashboardDataStore {
    static let shared = DriverDashboardDataStore()

    let currentUser = DashboardUser(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Naman Yadav"
    )
    private let vehicleId = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!

    func fetchTrips() async throws -> [DBTrip] {
        [
            DBTrip(id: UUID(), vehicleId: vehicleId, driverId: currentUser.id,
                   source: "Warehouse A - Sector 17",
                   destination: "Distribution Hub - Phase 5",
                   startTime: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
                   endTime: Calendar.current.date(byAdding: .hour, value: 4, to: .now),
                   distance: 48.2, status: .assigned,
                   notes: "Priority delivery", createdAt: .now),
            DBTrip(id: UUID(), vehicleId: vehicleId, driverId: currentUser.id,
                   source: "Distribution Hub - Phase 5",
                   destination: "Client Site - Noida",
                   startTime: Calendar.current.date(byAdding: .hour, value: 6, to: .now),
                   endTime: Calendar.current.date(byAdding: .hour, value: 9, to: .now),
                   distance: 31.0, status: .assigned,
                   notes: nil, createdAt: .now)
        ]
    }

    func fetchVehicles() async throws -> [DBVehicle] {
        [
            DBVehicle(
                id: vehicleId,
                vehicleNumber: "TN-07-AB-1234",
                model: "Transit",
                manufacturer: "Ford",
                year: 2024,
                vin: "FMSMOCKVIN000101",
                licensePlate: "TN-07-AB-1234",
                status: .inUse,
                assignedDriverId: currentUser.id,
                lastServiceDate: nil,
                createdAt: .now
            )
        ]
    }
}

// MARK: - ViewModel

@MainActor
final class DriverDashboardViewModel: ObservableObject {

    // MARK: State

    @Published var driverStatus: DriverOnlineStatus = .idle
    @Published var currentTrip: DBTrip?
    @Published var upcomingTrips: [DBTrip] = []
    @Published var assignedVehicle: DBVehicle?
    @Published var messages: [DriverChatMessage] = []
    @Published var banners: [DashboardBanner] = []
    @Published var isTripActive  = false
    @Published var tripElapsed   = 0
    @Published var fuelLevel: Double = 0.72
    @Published var isLoading     = false

    // Sheet visibility
    @Published var showVoiceLog  = false
    @Published var showIssue     = false
    @Published var showPreTrip   = false
    @Published var showPostTrip  = false
    @Published var showDefect    = false
    @Published var showMessaging = false

    @Published var confirmEnd    = false
    @Published var showMaps      = false
    @Published var activeTrip: DBTrip?
    @Published var mapActiveTrip: DBTrip?

    private var tripTimer: Timer?
    private let db = DriverDashboardDataStore.shared

    init() { seedMock() }

    // MARK: Load

    func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            let trips    = try await db.fetchTrips()
            let vehicles = try await db.fetchVehicles()
            let uid = db.currentUser.id
            let mine = trips.filter { $0.driverId == uid }
            currentTrip   = mine.first(where: { $0.status == DBTripStatus.started })
            activeTrip    = currentTrip ?? activeTrip
            upcomingTrips = mine.filter { $0.status == DBTripStatus.assigned }
            isTripActive  = currentTrip != nil
            driverStatus  = isTripActive ? .active : .idle
            let vid = currentTrip?.vehicleId ?? mine.first?.vehicleId
            assignedVehicle = vehicles.first(where: { $0.id == vid })
        } catch { /* keep mock */ }
    }

    // MARK: Trip control

    func beginTrip(trip: DBTrip? = nil) {
        activeTrip = trip ?? upcomingTrips.first
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isTripActive = true; driverStatus = .active; tripElapsed = 0
        }
        showMaps = true
        mapActiveTrip = activeTrip
        tripTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tripElapsed += 1
            }
        }
    }

    func finishTrip() {
        tripTimer?.invalidate(); tripTimer = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isTripActive = false; driverStatus = .idle
            currentTrip = nil; activeTrip = nil
        }
    }

    // MARK: Helpers

    var elapsedFormatted: String {
        let h = tripElapsed / 3600; let m = (tripElapsed % 3600) / 60; let s = tripElapsed % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    var driverFirstName: String {
        db.currentUser.name.components(separatedBy: " ").first ?? "Driver"
    }

    var totalKm: Double { upcomingTrips.reduce(0) { $0 + $1.distance } }
    var assignedReg: String { assignedVehicle?.vehicleNumber ?? "TN-07-AB-1234" }

    func fire(_ action: DashboardAction) {
        switch action {
        case .voiceLog:    showVoiceLog  = true
        case .reportIssue: showIssue     = true
        case .preTrip:     showPreTrip   = true
        case .postTrip:    showPostTrip  = true
        case .defect:      showDefect    = true
        case .messaging:   showMessaging = true
        }
    }

    // MARK: Mock seed

    private func seedMock() {
        upcomingTrips = [
            DBTrip(id: UUID(), vehicleId: UUID(), driverId: UUID(),
                   source: "Warehouse A – Sector 17",
                   destination: "Distribution Hub – Phase 5",
                   startTime: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
                   endTime:   Calendar.current.date(byAdding: .hour, value: 4, to: .now),
                   distance: 48.2, status: .assigned, notes: "Priority delivery", createdAt: .now),
            DBTrip(id: UUID(), vehicleId: UUID(), driverId: UUID(),
                   source: "Distribution Hub – Phase 5",
                   destination: "Client Site – Noida",
                   startTime: Calendar.current.date(byAdding: .hour, value: 6, to: .now),
                   endTime:   Calendar.current.date(byAdding: .hour, value: 9, to: .now),
                   distance: 31.0, status: .assigned, notes: nil, createdAt: .now)
        ]
        messages = [
            DriverChatMessage(sender: "Rajiv Sharma",     role: "Fleet Manager",
                              preview: "Confirm ETA for Route 2.",    time: "10:32 AM", unread: true,  initials: "RS"),
            DriverChatMessage(sender: "Maintenance Desk", role: "Maintenance",
                              preview: "TN-07-AB-1234 ready for dispatch.", time: "9:15 AM",  unread: true,  initials: "MD"),
            DriverChatMessage(sender: "Priya Menon",      role: "Fleet Manager",
                              preview: "Updated route file sent.",    time: "Yesterday", unread: false, initials: "PM")
        ]
        banners = [
            DashboardBanner(title: "Trip Assigned",
                            body: "New trip #TRP-2240 at 12:30 PM", kind: .info),
            DashboardBanner(title: "Pre-Trip Due",
                            body: "Complete inspection before departure", kind: .warning)
        ]
    }
}

// MARK: - Root View

@available(iOS 26.0, *)
struct DriverDashboardView: View {

    @StateObject private var vm = DriverDashboardViewModel()

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2") {
                DriverHomeTab(vm: vm)
            }
            Tab("Trips", systemImage: "map") {
                DriverTripsTab(vm: vm)
            }
        }
        .task { await vm.load() }
        // ─── Global Sheets ─────────────────────────────────────
        .sheet(isPresented: $vm.showVoiceLog)  { VoiceLogSheet() }
        .sheet(isPresented: $vm.showIssue)     { IssueReportSheet() }
        .sheet(isPresented: $vm.showPreTrip)   { InspectionFormSheet(isPreTrip: true) }
        .sheet(isPresented: $vm.showPostTrip)  { InspectionFormSheet(isPreTrip: false) }
        .sheet(isPresented: $vm.showDefect)    { DefectReportSheet() }
        .sheet(isPresented: $vm.showMessaging) { ChatSheet(messages: vm.messages) }
        .sheet(item: $vm.mapActiveTrip) { trip in
            TripNavigationView(trip: trip, vm: vm)
        }
        // ─── Confirmations ──────────────────────────────────────
        .confirmationDialog("End Trip", isPresented: $vm.confirmEnd, titleVisibility: .visible) {
            Button("End Trip", role: .destructive) { vm.finishTrip() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Confirm you have completed all deliveries.")
        }
    }
}

// MARK: - Shared Subcomponents

// ── Route Visual Row ───────────────────────────────────────────────────────────
struct FMSRouteRow: View {
    let source: String
    let destination: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.fmsIndigo)
                    .frame(width: 9, height: 9)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fmsIndigo.opacity(0.5), Color.green.opacity(0.5)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 28)
                Circle()
                    .fill(Color(red: 0.2, green: 0.78, blue: 0.35))
                    .frame(width: 9, height: 9)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(source)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(destination)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

// ── Trip Meta Stat Cell ────────────────────────────────────────────────────────
struct TripMetaCell: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.fmsIndigo)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// ── Message Row ────────────────────────────────────────────────────────────────
struct FMSMsgRow: View {
    let msg: DriverChatMessage

    private var roleColor: Color {
        switch msg.role {
        case "Fleet Manager": return .fmsIndigo
        case "Maintenance":   return Color(red: 0.95, green: 0.50, blue: 0.15)
        default:              return Color(UIColor.systemGray)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(msg.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(roleColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(msg.sender)
                        .font(.system(size: 13, weight: msg.unread ? .semibold : .regular))
                    Spacer()
                    Text(msg.time)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text(msg.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if msg.unread {
                Circle()
                    .fill(Color.fmsIndigo)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(msg.sender): \(msg.preview)")
    }
}

// ── Quick Action Tile ──────────────────────────────────────────────────────────
struct ActionTile: View {
    let qa: DriverQuickAction
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 11) {
                Image(systemName: qa.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(qa.color)
                    .frame(width: 44, height: 44)
                    .background(qa.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 2) {
                    Text(qa.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(qa.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(pressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.08)) { pressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.3))  { pressed = false } }
        )
        .accessibilityLabel(qa.title)
        .accessibilityHint(qa.subtitle)
    }
}

// MARK: - Voice Log Sheet

struct VoiceLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recording  = false
    @State private var elapsed    = 0
    @State private var timer: Timer?
    @State private var transcript = ""
    @State private var saved      = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(UIColor.systemBackground), Color.fmsIndigo.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 36) {
                    // Mic button
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(
                                    recording ? Color.red.opacity(0.12) : Color.clear,
                                    lineWidth: 1.5
                                )
                                .frame(
                                    width: CGFloat(100 + i * 36),
                                    height: CGFloat(100 + i * 36)
                                )
                                .scaleEffect(recording ? 1.0 : 0.85)
                                .animation(
                                    recording
                                    ? .easeInOut(duration: 1.4).repeatForever().delay(Double(i) * 0.28)
                                    : .default,
                                    value: recording
                                )
                        }
                        Button(action: toggleRec) {
                            ZStack {
                                Circle()
                                    .fill(
                                        recording
                                        ? AnyShapeStyle(Color.red.gradient)
                                        : AnyShapeStyle(Color.fmsIndigo.gradient)
                                    )
                                    .frame(width: 88, height: 88)
                                    .shadow(
                                        color: (recording ? Color.red : Color.fmsIndigo).opacity(0.35),
                                        radius: 20, y: 6
                                    )
                                Image(systemName: recording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(height: 200)

                    VStack(spacing: 8) {
                        Text(
                            recording
                            ? String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
                            : "Tap to Record"
                        )
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(recording ? Color.red : Color.fmsIndigo)
                        .contentTransition(.numericText())

                        Text(
                            recording
                            ? "Listening…"
                            : "Voice-log your trip notes, delays, or ETA"
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    }

                    if !transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Transcript", systemImage: "text.quote")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fmsIndigo)
                            Text(transcript)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                    }

                    Spacer()

                    if !transcript.isEmpty {
                        Button { saved = true } label: {
                            Text("Save Log")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.fmsIndigo.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .padding(.top, 48)
            }
            .navigationTitle("Voice Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert("Log Saved", isPresented: $saved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your voice log has been saved successfully.")
            }
        }
    }

    private func toggleRec() {
        recording.toggle()
        if recording {
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsed += 1 }
        } else {
            timer?.invalidate(); timer = nil
            transcript = "Log at \(Date().formatted(.dateTime.hour().minute())). Departed on schedule. Minor traffic on NH-8 near Sector 14. ETA revised to 2:45 PM."
        }
    }
}

// MARK: - Issue Report Sheet

struct IssueReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum IssueKind: String, CaseIterable {
        case delay = "Delay", accident = "Accident", traffic = "Traffic"
        case roadblock = "Road Block", breakdown = "Breakdown", other = "Other"
        var icon: String {
            switch self {
            case .delay:     return "clock.badge.exclamationmark"
            case .accident:  return "car.side.fill"
            case .traffic:   return "road.lanes"
            case .roadblock: return "xmark.octagon"
            case .breakdown: return "wrench.adjustable"
            case .other:     return "ellipsis.bubble"
            }
        }
    }
    enum SeverityLevel: String, CaseIterable { case low = "Low", medium = "Medium", high = "High" }

    @State private var kind     = IssueKind.delay
    @State private var severity = SeverityLevel.medium
    @State private var desc     = ""
    @State private var done     = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Issue type picker
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Issue Type")
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(IssueKind.allCases, id: \.self) { k in
                                Button { withAnimation(.spring(response: 0.3)) { kind = k } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: k.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(kind == k ? Color.fmsIndigo : .secondary)
                                        Text(k.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(kind == k ? Color.fmsIndigo : .secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .glassEffect(
                                        kind == k
                                        ? .regular.tint(Color.fmsIndigo.opacity(0.12))
                                        : .regular,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                kind == k ? Color.fmsIndigo.opacity(0.5) : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Severity
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Severity")
                        Picker("Severity", selection: $severity) {
                            ForEach(SeverityLevel.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Description")
                        TextField("What's happening? Add any relevant details…", text: $desc, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(4...8)
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button { done = true } label: {
                        Text("Submit Report")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.fmsIndigo.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert("Report Submitted", isPresented: $done) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your issue report has been sent to the fleet manager.")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

// MARK: - Inspection Sheet

struct InspectionFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let isPreTrip: Bool

    struct CheckItem: Identifiable {
        let id    = UUID()
        let label: String
        let icon: String
        var passed = false

        static let all: [CheckItem] = [
            .init(label: "Brakes & Brake Lights",   icon: "hand.raised.fill"),
            .init(label: "Tyres & Tyre Pressure",   icon: "circle.dashed"),
            .init(label: "Engine & Oil Level",      icon: "gearshape.fill"),
            .init(label: "Headlights & Indicators", icon: "lightbulb.fill"),
            .init(label: "Windshield & Wipers",     icon: "cloud.drizzle.fill"),
            .init(label: "Seat Belts",              icon: "figure.walk.circle.fill"),
            .init(label: "Mirrors",                 icon: "arrow.left.and.right"),
            .init(label: "Horn",                    icon: "megaphone.fill"),
            .init(label: "First Aid Kit",           icon: "cross.case.fill"),
            .init(label: "Documents & Permits",     icon: "doc.text.fill"),
        ]
    }

    @State private var items      = CheckItem.all
    @State private var remarks    = ""
    @State private var hasDefect  = false
    @State private var submitting = false
    @State private var submitted  = false

    private var title: String { isPreTrip ? "Pre-Trip Inspection" : "Post-Trip Inspection" }
    private var allPass: Bool { items.allSatisfy(\.passed) }
    private var passCount: Int { items.filter(\.passed).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Progress ring summary
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.fmsIndigo.opacity(0.12), lineWidth: 6)
                                .frame(width: 80, height: 80)
                            Circle()
                                .trim(from: 0, to: CGFloat(passCount) / CGFloat(items.count))
                                .stroke(
                                    allPass ? Color(red:0.2,green:0.78,blue:0.35) : Color.fmsIndigo,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 80)
                                .animation(.spring(response: 0.4), value: passCount)
                            Text("\(passCount)/\(items.count)")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(title).font(.system(size: 15, weight: .semibold))
                        Text("Vehicle \(isPreTrip ? "TN-07-AB-1234" : "TN-07-AB-1234")")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

                    // Checklist
                    VStack(spacing: 0) {
                        ForEach($items) { $item in
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(item.passed ? Color(red:0.2,green:0.78,blue:0.35) : .secondary)
                                    .frame(width: 26)
                                Text(item.label)
                                    .font(.system(size: 14))
                                    .foregroundStyle(item.passed ? .primary : .secondary)
                                Spacer()
                                Toggle("", isOn: $item.passed)
                                    .labelsHidden()
                                    .tint(Color.fmsIndigo)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .animation(.easeOut(duration: 0.2), value: item.passed)

                            if item.id != items.last?.id {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

                    // Defect toggle
                    HStack {
                        Label("Defect Found", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(hasDefect ? Color(red:0.85,green:0.15,blue:0.15) : .secondary)
                        Spacer()
                        Toggle("", isOn: $hasDefect).tint(Color(red:0.85,green:0.15,blue:0.15))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

                    // Remarks
                    TextField("Remarks or additional notes…", text: $remarks, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(3...6)
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        Task { await doSubmit() }
                    } label: {
                        Group {
                            if submitting {
                                ProgressView().tint(.white)
                            } else {
                                Text(allPass ? "Submit  ✓ All Passed" : "Submit Inspection")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background((allPass ? Color(red:0.2,green:0.78,blue:0.35) : Color.fmsIndigo).gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert(allPass ? "Inspection Passed" : "Inspection Submitted", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text(allPass
                     ? "All items passed. You are cleared for departure."
                     : "Recorded. Any issues have been flagged for maintenance.")
            }
        }
    }

    @MainActor
    private func doSubmit() async {
        submitting = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        submitting = false; submitted = true
    }
}

// MARK: - Defect Report Sheet

struct DefectReportSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum Part: String, CaseIterable {
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
    enum SevPick: String, CaseIterable { case low = "Low", medium = "Medium", high = "High" }

    @State private var part       = Part.engine
    @State private var titleStr   = ""
    @State private var desc       = ""
    @State private var sev        = SevPick.medium
    @State private var submitting = false
    @State private var submitted  = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Component picker
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Affected Component")
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(Part.allCases, id: \.self) { p in
                                Button { withAnimation(.spring(response: 0.3)) { part = p } } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: p.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(part == p ? Color.fmsIndigo : .secondary)
                                        Text(p.rawValue)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(part == p ? Color.fmsIndigo : .secondary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .glassEffect(
                                        part == p
                                        ? .regular.tint(Color.fmsIndigo.opacity(0.12))
                                        : .regular,
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(part == p ? Color.fmsIndigo.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Defect Title")
                        TextField("e.g. Oil leak near rear axle", text: $titleStr)
                            .font(.system(size: 14)).padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Description")
                        TextField("Describe the defect in detail…", text: $desc, axis: .vertical)
                            .font(.system(size: 14)).lineLimit(4...8).padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("Severity")
                        Picker("Severity", selection: $sev) {
                            ForEach(SevPick.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        Task { await doSubmit() }
                    } label: {
                        Group {
                            if submitting { ProgressView().tint(.white) }
                            else {
                                Text("Submit Defect Report")
                                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color(red:0.85,green:0.15,blue:0.15).gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(titleStr.isEmpty || desc.isEmpty)
                    .opacity(titleStr.isEmpty || desc.isEmpty ? 0.45 : 1)
                }
                .padding(20)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Report Defect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
            }
            .alert("Defect Reported", isPresented: $submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text("Flagged for immediate maintenance review.")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    @MainActor
    private func doSubmit() async {
        submitting = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        submitting = false; submitted = true
    }
}

// MARK: - Chat Sheet

struct ChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [DriverChatMessage]
    @State private var compose     = ""
    @State private var showCompose = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if showCompose {
                        HStack(spacing: 12) {
                            TextField("Message fleet manager…", text: $compose)
                                .font(.system(size: 14))
                            Button {
                                withAnimation { compose = ""; showCompose = false }
                            } label: {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.fmsIndigo)
                            }
                            .disabled(compose.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { i, m in
                            FMSMsgRow(msg: m).padding(.horizontal, 16).padding(.vertical, 12)
                            if i < messages.count - 1 { Divider().padding(.leading, 64) }
                        }
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 32)
                }
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.fmsIndigo)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showCompose.toggle() }
                    } label: {
                        Image(systemName: showCompose ? "xmark" : "square.and.pencil")
                            .foregroundStyle(Color.fmsIndigo)
                    }
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
