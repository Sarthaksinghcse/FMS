//
//  DriverDashboardViewModel.swift
//  FMS
//
//  Created by Sarthak Singh on 19/05/26.
//

import SwiftUI
import MapKit
import Combine

// MARK: - Driver Status

enum DriverOnlineStatus: String, CaseIterable {
    case active = "Active", idle = "Idle", maintenance = "Maintenance", offline = "Offline"

    var dot: Color {
        switch self {
        case .active:      return AppTheme.Status.success
        case .idle:        return AppTheme.Brand.amber
        case .maintenance: return AppTheme.Brand.accent
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
        case .info:    return AppTheme.Brand.primaryDeep
        case .warning: return AppTheme.Brand.accent
        case .urgent:  return AppTheme.Status.danger
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

actor DriverDashboardDataStore {
    static let shared = DriverDashboardDataStore()

    let currentUser = DashboardUser(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Naman Yadav"
    )
    private let vehicleId = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!

    func fetchTrips() async throws -> [DBTrip] {
        [
            DBTrip(id: UUID(uuidString: "A8802000-0000-0000-0000-000000000000")!, vehicleId: vehicleId, driverId: currentUser.id,
                   source: "San Francisco Dock C",
                   destination: "Los Angeles Warehouse 4",
                   startTime: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
                   endTime: Calendar.current.date(byAdding: .hour, value: 4, to: .now),
                   distance: 612.0, status: .assigned,
                   notes: "Dry Van Food Grd", createdAt: .now),
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
                model: "Swift Dzire",
                manufacturer: "Maruti Suzuki",
                year: 2023,
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

// MARK: - Completed Trip Record

struct CompletedTripRecord: Identifiable {
    let id: UUID
    let trip: DBTrip
    let completedAt: Date
    let elapsedSeconds: Int       // time taken in seconds
    let distanceKm: Double
    let inspectionPassed: Bool
    let issuesFound: Int
    let inspectionRemarks: String

    var formattedDuration: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
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
    @Published var showProfile   = false
    @Published var showSOSConfirm = false
    @Published var showSOSCountdown = false
    @Published var sosSentAlert   = false
    @Published var showNotifications = false
    @Published var notificationsList: [DBNotification] = []
    private var autoRefreshTimer: AnyCancellable?

    @Published var confirmEnd    = false
    @Published var showPostTripOnEnd = false
    @Published var showMaps      = false
    @Published var activeTrip: DBTrip?
    @Published var mapActiveTrip: DBTrip?
    @Published var completedTrips: [CompletedTripRecord] = []

    // Post-trip inspection data captured when submitting
    var lastInspectionPassed: Bool = true
    var lastIssuesFound: Int = 0
    var lastInspectionRemarks: String = ""

    private var tripTimer: Timer?
    private var tripStartDate: Date?
    private let db = DriverDashboardDataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() { 
        seedMock()
        setupAuthListener()
        startAutoRefresh()
    }

    private func setupAuthListener() {
        SupabaseManager.shared.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.load()
                }
            }
            .store(in: &cancellables)
    }

    private func startAutoRefresh() {
        autoRefreshTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.load()
                }
            }
    }

    // MARK: Driver Info
    
    var driverId: UUID {
        SupabaseManager.shared.currentUser?.id ?? db.currentUser.id
    }

    var driverName: String {
        SupabaseManager.shared.currentUser?.name ?? db.currentUser.name
    }

    // MARK: Load

    func load() async {
        isLoading = true; defer { isLoading = false }
        let uid = driverId
        do {
            let trips    = try await SupabaseManager.shared.fetchTrips()
            let vehicles = try await SupabaseManager.shared.fetchVehicles()
            let mine = trips.filter { $0.driverId == uid }
            currentTrip   = mine.first(where: { $0.status == DBTripStatus.started })
            if let current = currentTrip {
                activeTrip = current
            } else if let prevActive = activeTrip {
                let stillExists = mine.contains { $0.id == prevActive.id && ($0.status == .assigned || $0.status == .started) }
                if !stillExists {
                    activeTrip = nil
                }
            }
            upcomingTrips = mine.filter { $0.status == DBTripStatus.assigned }
            isTripActive  = currentTrip != nil
            driverStatus  = isTripActive ? .active : .idle
            let vid = currentTrip?.vehicleId ?? mine.first?.vehicleId
            assignedVehicle = vehicles.first(where: { $0.id == vid })
            
            // Load completed trips from Supabase
            let completed = mine.filter { $0.status == .completed }
            self.completedTrips = completed.map { trip in
                let elapsed = Int(trip.endTime?.timeIntervalSince(trip.startTime ?? Date()) ?? 0)
                return CompletedTripRecord(
                    id: trip.id,
                    trip: trip,
                    completedAt: trip.endTime ?? trip.createdAt,
                    elapsedSeconds: elapsed > 0 ? elapsed : 0,
                    distanceKm: trip.distance,
                    inspectionPassed: true,
                    issuesFound: 0,
                    inspectionRemarks: "System logged"
                )
            }.sorted(by: { $0.completedAt > $1.completedAt })
        } catch {
            print("Failed to fetch live driver data, using local fallback/mock: \(error.localizedDescription)")
            do {
                let trips    = try await db.fetchTrips()
                let vehicles = try await db.fetchVehicles()
                let mine = trips.filter { $0.driverId == uid }
                currentTrip   = mine.first(where: { $0.status == DBTripStatus.started })
                if let current = currentTrip {
                    activeTrip = current
                } else if let prevActive = activeTrip {
                    let stillExists = mine.contains { $0.id == prevActive.id && ($0.status == .assigned || $0.status == .started) }
                    if !stillExists {
                        activeTrip = nil
                    }
                }
                upcomingTrips = mine.filter { $0.status == DBTripStatus.assigned }
                isTripActive  = currentTrip != nil
                driverStatus  = isTripActive ? .active : .idle
                let vid = currentTrip?.vehicleId ?? mine.first?.vehicleId
                assignedVehicle = vehicles.first(where: { $0.id == vid })
                
                // Load completed trips from local DB
                let completed = mine.filter { $0.status == .completed }
                self.completedTrips = completed.map { trip in
                    let elapsed = Int(trip.endTime?.timeIntervalSince(trip.startTime ?? Date()) ?? 0)
                    return CompletedTripRecord(
                        id: trip.id,
                        trip: trip,
                        completedAt: trip.endTime ?? trip.createdAt,
                        elapsedSeconds: elapsed > 0 ? elapsed : 0,
                        distanceKm: trip.distance,
                        inspectionPassed: true,
                        issuesFound: 0,
                        inspectionRemarks: "System logged"
                    )
                }.sorted(by: { $0.completedAt > $1.completedAt })
            } catch {
                // keep mock
            }
        }

        // Global fallback: only load the mock trip if we are not connected to Supabase (offline/no user logged in)
        if SupabaseManager.shared.currentUser == nil && upcomingTrips.isEmpty && currentTrip == nil {
            upcomingTrips = [
                DBTrip(id: UUID(uuidString: "A8802000-0000-0000-0000-000000000000")!,
                       vehicleId: assignedVehicle?.id ?? UUID(),
                       driverId: uid,
                       source: "San Francisco Dock C",
                       destination: "Los Angeles Warehouse 4",
                       startTime: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
                       endTime:   Calendar.current.date(byAdding: .hour, value: 4, to: .now),
                       distance: 612.0, status: .assigned, notes: "Dry Van Food Grd", createdAt: .now)
            ]
        }
        
        // Load messages and notifications from Supabase
        await loadMessages()
        await loadNotifications()
        
        if assignedVehicle == nil {
            assignedVehicle = DBVehicle(
                id: UUID(),
                vehicleNumber: "TN-07-AB-1234",
                model: "Swift Dzire",
                manufacturer: "Maruti Suzuki",
                year: 2023,
                vin: "FMSMOCKVIN000101",
                licensePlate: "TN-07-AB-1234",
                status: .inUse,
                assignedDriverId: uid,
                lastServiceDate: nil,
                createdAt: .now
            )
        }
    }

    // MARK: Trip control

    func beginTrip(trip: DBTrip? = nil) {
        let selectedTrip = trip ?? upcomingTrips.first
        activeTrip = selectedTrip
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isTripActive = true; driverStatus = .active; tripElapsed = 0
        }
        showMaps = true
        mapActiveTrip = activeTrip
        tripStartDate = Date()   // Record exact start time
        
        // Sync trip start to Supabase in background and start location tracking
        if var dbTrip = selectedTrip {
            dbTrip.status = .started
            dbTrip.startTime = Date()
            LocationService.shared.startTracking(vehicleId: dbTrip.vehicleId)
            Task {
                try? await SupabaseManager.shared.updateTrip(dbTrip)
            }
        }
        
        tripTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tripElapsed += 1
            }
        }
    }

    func finishTrip() {
        tripTimer?.invalidate(); tripTimer = nil
        let endingId  = activeTrip?.id ?? currentTrip?.id
        let endingTrip = activeTrip ?? currentTrip

        // Calculate elapsed from start date (more reliable than timer counter)
        let elapsed: Int
        if let start = tripStartDate {
            elapsed = max(Int(Date().timeIntervalSince(start)), tripElapsed)
        } else {
            elapsed = tripElapsed
        }
        tripStartDate = nil

        // Sync trip completion to Supabase and stop location tracking
        if var dbTrip = endingTrip {
            dbTrip.status = .completed
            dbTrip.endTime = Date()
            LocationService.shared.stopTracking()
            Task {
                try? await SupabaseManager.shared.updateTrip(dbTrip)
            }
        }

        // Archive to completed list
        if let trip = endingTrip {
            let record = CompletedTripRecord(
                id: UUID(),
                trip: trip,
                completedAt: Date(),
                elapsedSeconds: elapsed,
                distanceKm: trip.distance,
                inspectionPassed: lastInspectionPassed,
                issuesFound: lastIssuesFound,
                inspectionRemarks: lastInspectionRemarks
            )
            withAnimation { completedTrips.insert(record, at: 0) }
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isTripActive = false; driverStatus = .idle
            currentTrip = nil; activeTrip = nil
            showPostTripOnEnd = false
            tripElapsed = 0
        }
        // Remove the completed trip from the assigned list
        if let id = endingId {
            upcomingTrips.removeAll { $0.id == id }
        } else {
            upcomingTrips.removeAll()
        }
        // Reset inspection capture
        lastInspectionPassed = true
        lastIssuesFound = 0
        lastInspectionRemarks = ""
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
        driverName.components(separatedBy: " ").first ?? "Driver"
    }

    var totalKm: Double { upcomingTrips.reduce(0) { $0 + $1.distance } }
    var assignedReg: String  { assignedVehicle?.vehicleNumber ?? "TN-07-AB-1234" }
    var vehicleManufacturer: String { assignedVehicle?.manufacturer ?? "Maruti Suzuki" }
    var vehicleModel: String        { assignedVehicle?.model       ?? "Swift Dzire" }
    var vehicleYear: String         { assignedVehicle.map { String($0.year) } ?? "2023" }

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

    // MARK: Messaging & Notifications
    
    func loadMessages() async {
        do {
            let dbMessages = try await SupabaseManager.shared.fetchMessages()
            let uid = driverId
            // Filter messages relevant to this driver (sent or received)
            let relevant = dbMessages.filter { $0.senderId == uid || $0.receiverId == uid }
            self.messages = relevant.map { msg in
                let isSentByMe = msg.senderId == uid
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return DriverChatMessage(
                    sender: isSentByMe ? driverName : "Fleet Manager",
                    role: isSentByMe ? "Driver" : "Fleet Manager",
                    preview: msg.message,
                    time: formatter.string(from: msg.timestamp),
                    unread: !isSentByMe,
                    initials: isSentByMe ? String(driverName.prefix(2)).uppercased() : "FM"
                )
            }
        } catch {
            print("⚠️ Failed to load messages from Supabase: \(error.localizedDescription)")
            // Keep mock messages as fallback
        }
    }
    
    func sendMessage(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let dbMessage = DBMessage(
            id: UUID(),
            senderId: driverId,
            receiverId: UUID(), // Fleet manager placeholder - in production this would be resolved
            message: trimmed,
            timestamp: Date()
        )
        
        do {
            try await SupabaseManager.shared.sendMessage(dbMessage)
            // Add to local messages list immediately
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let localMsg = DriverChatMessage(
                sender: driverName,
                role: "Driver",
                preview: trimmed,
                time: formatter.string(from: Date()),
                unread: false,
                initials: String(driverName.prefix(2)).uppercased()
            )
            messages.insert(localMsg, at: 0)
        } catch {
            print("⚠️ Failed to send message to Supabase: \(error.localizedDescription)")
        }
    }
    
    func loadNotifications() async {
        do {
            let dbNotifications = try await SupabaseManager.shared.fetchNotifications()
            let uid = driverId
            let mine = dbNotifications.filter { $0.userId == uid }
            
            // Populate full notifications list sorted newest first
            self.notificationsList = mine.sorted(by: { $0.createdAt > $1.createdAt })
            
            // Update banners from real notifications
            self.banners = mine.prefix(5).map { notif in
                let kind: DashboardBanner.BannerKind
                switch notif.type {
                case .emergency: kind = .urgent
                case .warning: kind = .warning
                default: kind = .info
                }
                return DashboardBanner(title: notif.title, body: notif.message, kind: kind)
            }
        } catch {
            print("⚠️ Failed to load notifications from Supabase: \(error.localizedDescription)")
            // Keep mock banners as fallback
        }
    }
    
    func markAllNotificationsAsRead() async {
        let unread = notificationsList.filter { !$0.isRead }
        for notif in unread {
            var updated = notif
            updated.isRead = true
            try? await SupabaseManager.shared.updateNotification(updated)
        }
        await loadNotifications()
    }
    
    // MARK: Mock seed

    private func seedMock() {
        upcomingTrips = [
            DBTrip(id: UUID(uuidString: "A8802000-0000-0000-0000-000000000000")!, vehicleId: UUID(), driverId: UUID(),
                   source: "San Francisco Dock C",
                   destination: "Los Angeles Warehouse 4",
                   startTime: Calendar.current.date(byAdding: .hour, value: 1, to: .now),
                   endTime:   Calendar.current.date(byAdding: .hour, value: 4, to: .now),
                   distance: 612.0, status: .assigned, notes: "Dry Van Food Grd", createdAt: .now),
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
