






import SwiftUI
import MapKit
import Combine
import SwiftData
import Observation



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

    /// Human-readable label — shows "Driving" when on an active trip.
    var displayLabel: String {
        switch self {
        case .active: return "Driving"
        default:      return rawValue
        }
    }
}



enum DashboardAction {
    case voiceLog, reportIssue, preTrip, postTrip, defect, messaging
}



struct DriverQuickAction: Identifiable {
    let id   = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: DashboardAction
}

struct DriverChatMessage: Identifiable {
    let id: UUID
    let sender: String
    let role: String
    let preview: String
    let time: String
    let unread: Bool
    let initials: String
    let isMe: Bool
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



struct CompletedTripRecord: Identifiable {
    let id: UUID
    let trip: DBTrip
    let completedAt: Date
    let elapsedSeconds: Int       
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



@MainActor
final class DriverDashboardViewModel: ObservableObject {

    

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
    @Published var allVehicles: [DBVehicle] = []
    @Published var allLocalVehicles: [Vehicle] = []

    
    @Published var showVoiceLog  = false
    @Published var showIssue     = false
    @Published var showPreTrip   = false
    @Published var showPostTrip  = false
    @Published var showDefect    = false
    @Published var showMessaging = false
    @Published var selectedMessageIndex: Int?
    
    // Geofencing Properties
    @Published var showGeofenceAlert: Bool = false
    @Published var geofenceAlertMessage: String = ""
    
    @Published var tripStartDate: Date?
    @Published var showRaiseQuery = false
    @Published var queryTrip: DBTrip?
    @Published var showProfile   = false
    @Published var showSOSConfirm = false
    @Published var showSOSCountdown = false
    @Published var sosSentAlert   = false
    @Published var showNotifications = false
    @Published var notificationsList: [DBNotification] = []
    @Published var showFuelLog   = false   // Fuel refuel sheet
    private var autoRefreshTimer: AnyCancellable?

    @Published var confirmEnd    = false
    @Published var showPostTripOnEnd = false
    @Published var showMaps      = false
    @Published var activeTrip: DBTrip?
    @Published var mapActiveTrip: DBTrip?
    @Published var viewRouteTrip: DBTrip?   // opens map in route-view mode (no pre-inspection)
    @Published var completedTrips: [CompletedTripRecord] = []

    
    var lastInspectionPassed: Bool = true
    var lastIssuesFound: Int = 0
    var lastInspectionRemarks: String = ""

    private var modelContext: ModelContext?
    private var tripTimer: Timer?
    private let db = DriverDashboardDataStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() { 
        setupAuthListener()
        startAutoRefresh()
    }

    private func setupAuthListener() {
        withObservationTracking {
            _ = SupabaseManager.shared.currentUser
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let context = self.modelContext {
                    await self.load(context: context)
                } else {
                    await self.load()
                }
                self.setupAuthListener()
            }
        }
    }

    private func startAutoRefresh() {
        autoRefreshTimer = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    if let context = self.modelContext {
                        await self.load(context: context)
                    } else {
                        await self.load()
                    }
                }
            }
    }

    
    
    var driverId: UUID {
        SupabaseManager.shared.currentUser?.id ?? db.currentUser.id
    }

    var driverName: String {
        SupabaseManager.shared.currentUser?.name ?? db.currentUser.name
    }

    
    // MARK: - Geofencing Validation
    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = address
        let item = try? await MKLocalSearch(request: req).start()
        return item?.mapItems.first?.placemark.coordinate
    }

    func validateCanStartTrip(_ trip: DBTrip?, startCoord: CLLocationCoordinate2D? = nil, userLocation: CLLocation? = nil) async -> (isValid: Bool, message: String?) {
        guard let trip = trip ?? upcomingTrips.first else { return (false, "No upcoming trip selected.") }
        guard let currentLocation = userLocation ?? LocationService.shared.lastLocation else {
            return (false, "Acquiring GPS location, please wait a moment...")
        }
        
        var coord = startCoord
        if coord == nil {
            coord = await geocodeAddress(trip.source)
        }
        guard let coord = coord else {
            return (false, "Could not determine starting location coordinates.")
        }
        
        let startLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let distance = currentLocation.distance(from: startLocation)
        
        if distance <= 2000 {
            return (true, nil)
        } else {
            let distanceStr = String(format: "%.1f", distance / 1000.0)
            return (false, "You must be within 2km of the starting location to begin the trip. (Currently \(distanceStr)km away)")
        }
    }

    func validateCanEndTrip(_ trip: DBTrip?, endCoord: CLLocationCoordinate2D? = nil, userLocation: CLLocation? = nil) async -> (isValid: Bool, message: String?) {
        guard let trip = trip ?? activeTrip ?? currentTrip else { return (false, "No active trip to end.") }
        guard let currentLocation = userLocation ?? LocationService.shared.lastLocation else {
            return (false, "Acquiring GPS location, please wait a moment...")
        }
        
        var coord = endCoord
        if coord == nil {
            coord = await geocodeAddress(trip.destination)
        }
        guard let coord = coord else {
            return (false, "Could not determine destination coordinates.")
        }
        
        let endLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let distance = currentLocation.distance(from: endLocation)
        
        if distance <= 2000 {
            return (true, nil)
        } else {
            let distanceStr = String(format: "%.1f", distance / 1000.0)
            return (false, "You must be within 2km of the destination to end the trip. (Currently \(distanceStr)km away)")
        }
    }

    func load(context: ModelContext? = nil) async {
        if let context = context {
            self.modelContext = context
        }
        isLoading = true; defer { isLoading = false }
        let uid = driverId
        
        if let context = modelContext {
            
            await SupabaseManager.shared.syncAllData(context: context)
            
            
            let descriptor = FetchDescriptor<Trip>()
            let localTrips = (try? context.fetch(descriptor)) ?? []
            let trips = localTrips.map { $0.asDBTrip }
            
            let vehicleDescriptor = FetchDescriptor<Vehicle>()
            let localVehicles = (try? context.fetch(vehicleDescriptor)) ?? []
            let vehicles = localVehicles.map { $0.asDBVehicle }
            allLocalVehicles = localVehicles
            
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
            updateLocalDriverStatusState()
            let vid = currentTrip?.vehicleId ?? mine.first?.vehicleId
            assignedVehicle = vehicles.first(where: { $0.id == vid })
            allVehicles = vehicles
            
            
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
        } else {
            
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
                updateLocalDriverStatusState()
                let vid = currentTrip?.vehicleId ?? mine.first?.vehicleId
                assignedVehicle = vehicles.first(where: { $0.id == vid })
                allVehicles = vehicles
                
                
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
                print("Failed to fetch live driver data: \(error.localizedDescription)")
            }
        }

        await loadMessages()
        await loadNotifications()
    }

    

    func beginTrip(trip: DBTrip? = nil, startCoord: CLLocationCoordinate2D? = nil, userLocation: CLLocation? = nil, triggerGlobalAlert: Bool = true) async -> (success: Bool, message: String?) {
        let validation = await validateCanStartTrip(trip, startCoord: startCoord, userLocation: userLocation)
        if !validation.isValid {
            if triggerGlobalAlert {
                await MainActor.run {
                    self.geofenceAlertMessage = validation.message ?? "Cannot start trip."
                    self.showGeofenceAlert = true
                }
            }
            return (false, validation.message)
        }
        
        await MainActor.run {
            let selectedTrip = trip ?? upcomingTrips.first
            activeTrip = selectedTrip
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            isTripActive = true; driverStatus = .active; tripElapsed = 0
        }
        showMaps = true
        mapActiveTrip = activeTrip
        tripStartDate = Date()   
        
        
        if var dbTrip = selectedTrip {
            dbTrip.status = .started
            dbTrip.startTime = Date()
            LocationService.shared.startTracking(vehicleId: dbTrip.vehicleId)
            Task {
                try? await SupabaseManager.shared.updateTrip(dbTrip)
                await updateDriverActiveStatus(isActive: true)
            }
        }
        
            tripTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tripElapsed += 1
                }
            }
        }
        return (true, nil)
    }

    func requestEndTrip(endCoord: CLLocationCoordinate2D? = nil, userLocation: CLLocation? = nil, triggerGlobalAlert: Bool = true) async -> (success: Bool, message: String?) {
        let endingTrip = activeTrip ?? currentTrip
        let validation = await validateCanEndTrip(endingTrip, endCoord: endCoord, userLocation: userLocation)
        if !validation.isValid {
            if triggerGlobalAlert {
                await MainActor.run {
                    self.geofenceAlertMessage = validation.message ?? "Cannot end trip."
                    self.showGeofenceAlert = true
                }
            }
            return (false, validation.message)
        }
        
        await MainActor.run {
            self.showPostTripOnEnd = true
            self.showPostTrip = true
        }
        return (true, nil)
    }

    func finishTrip() {
        let endingTrip = activeTrip ?? currentTrip
        
        tripTimer?.invalidate(); tripTimer = nil
        let endingId  = endingTrip?.id

        
        let elapsed: Int
        if let start = tripStartDate {
            elapsed = max(Int(Date().timeIntervalSince(start)), tripElapsed)
        } else {
            elapsed = tripElapsed
        }
        tripStartDate = nil

        
        if var dbTrip = endingTrip {
            dbTrip.status = .completed
            dbTrip.endTime = Date()
            LocationService.shared.stopTracking()
            Task {
                try? await SupabaseManager.shared.updateTrip(dbTrip)
            }
        }

        
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
            isTripActive = false
            currentTrip = nil; activeTrip = nil
            showPostTripOnEnd = false
            tripElapsed = 0
        }
        updateLocalDriverStatusState()
        
        if let id = endingId {
            upcomingTrips.removeAll { $0.id == id }
        } else {
            upcomingTrips.removeAll()
        }
        
        lastInspectionPassed = true
        lastIssuesFound = 0
        lastInspectionRemarks = ""
    }

    

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

    /// Look up the vehicle assigned to a specific trip
    func vehicleForTrip(_ trip: DBTrip) -> DBVehicle? {
        allVehicles.first(where: { $0.id == trip.vehicleId }) ?? assignedVehicle
    }

    /// Look up the full local Vehicle (with vehicleType, fuelType, insuranceExpiryDate)
    func localVehicleForTrip(_ trip: DBTrip) -> Vehicle? {
        allLocalVehicles.first(where: { $0.id == trip.vehicleId })
    }

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

    
    
    func loadMessages() async {
        do {
            let dbMessages = try await SupabaseManager.shared.fetchMessages()
            let uid = driverId
            
            let relevant = dbMessages.filter { $0.senderId == uid || $0.receiverId == uid }
            self.messages = relevant.map { msg in
                let isSentByMe = msg.senderId == uid
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return DriverChatMessage(
                    id: msg.id,
                    sender: isSentByMe ? driverName : "Fleet Manager",
                    role: isSentByMe ? "Driver" : "Fleet Manager",
                    preview: msg.message,
                    time: formatter.string(from: msg.timestamp),
                    unread: !isSentByMe,
                    initials: isSentByMe ? String(driverName.prefix(2)).uppercased() : "FM",
                    isMe: isSentByMe
                )
            }
        } catch {
            print("⚠️ Failed to load messages from Supabase: \(error.localizedDescription)")
            
        }
    }
    
    private func updateLocalDriverStatusState() {
        if isTripActive {
            driverStatus = .active
        } else if let currentUser = SupabaseManager.shared.currentUser {
            driverStatus = currentUser.isActive ? .idle : .offline
        } else {
            driverStatus = .idle
        }
    }

    func updateDriverActiveStatus(isActive: Bool) async {
        guard var updatedUser = SupabaseManager.shared.currentUser else { return }
        updatedUser.isActive = isActive
        do {
            try await SupabaseManager.shared.updateDriver(updatedUser)
            await MainActor.run {
                if let context = self.modelContext {
                    let descriptor = FetchDescriptor<User>()
                    if let localUsers = try? context.fetch(descriptor),
                       let localUser = localUsers.first(where: { $0.id == updatedUser.id }) {
                        localUser.isActive = isActive
                        try? context.save()
                    }
                }
                self.updateLocalDriverStatusState()
            }
        } catch {
            print("Failed to update status on Supabase: \(error)")
        }
    }

    func sendMessage(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var managerId: UUID? = nil
        
        // Find the last message received from any fleet manager
        do {
            let dbMessages = try await SupabaseManager.shared.fetchMessages()
            let uid = driverId
            let managers = try await SupabaseManager.shared.fetchFleetManagers()
            let managerIds = Set(managers.map { $0.id })
            
            // Check messages where we were the receiver, and the sender was a manager
            if let lastIncoming = dbMessages.last(where: { $0.receiverId == uid && managerIds.contains($0.senderId) }) {
                managerId = lastIncoming.senderId
            }
        } catch {
            print("Failed to find last manager sender: \(error)")
        }
        
        // Fallback to first manager if no previous messages found
        if managerId == nil {
            do {
                let managers = try await SupabaseManager.shared.fetchFleetManagers()
                if let firstManager = managers.first {
                    managerId = firstManager.id
                }
            } catch {
                print("Failed to fetch manager ID for messaging: \(error)")
            }
        }
        
        let finalManagerId = managerId ?? UUID()
        
        let dbMessage = DBMessage(
            id: UUID(),
            senderId: driverId,
            receiverId: finalManagerId,
            message: trimmed,
            timestamp: Date()
        )
        
        do {
            try await SupabaseManager.shared.sendMessage(dbMessage)
            await loadMessages()
        } catch {
            print("⚠️ Failed to send message to Supabase: \(error.localizedDescription)")
        }
    }
    
    func triggerSOS(context: ModelContext) {
        sosSentAlert = true
        let driverId = SupabaseManager.shared.currentUser?.id ?? UUID()
        let notif = DBNotification(
            id: UUID(),
            userId: driverId,
            title: "🚨 EMERGENCY SOS SIGNAL TRIGGERED",
            message: "Driver \(SupabaseManager.shared.currentUser?.name ?? "Naman Yadav") has triggered a panic alarm. Assistance is required immediately.",
            type: .emergency,
            isRead: false,
            createdAt: Date()
        )
        Task {
            do {
                try await SupabaseManager.shared.createNotification(notif)
                print("✅ [Supabase] SOS Notification inserted successfully.")
            } catch {
                print("❌ [Supabase] Failed to insert SOS Notification: \(error.localizedDescription)")
            }
            
            let localSOS = SOSAlert(
                id: notif.id,
                driverId: driverId,
                vehicleId: assignedVehicle?.id,
                tripId: activeTrip?.id,
                latitude: 28.5450,
                longitude: 77.2600,
                message: notif.message,
                status: .active,
                createdAt: notif.createdAt
            )
            
            do {
                try await SupabaseManager.shared.createSOSAlert(localSOS.asDBSOSAlert)
                print("✅ [Supabase] SOS Alert inserted successfully.")
            } catch {
                print("❌ [Supabase] Failed to insert SOS Alert: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                context.insert(notif.asLocalNotification)
                context.insert(localSOS)
                try? context.save()
            }
        }
    }
    
    func loadNotifications() async {
        do {
            let dbNotifications = try await SupabaseManager.shared.fetchNotifications()
            let uid = driverId
            let mine = dbNotifications.filter { $0.userId == uid }
            
            
            self.notificationsList = mine.sorted(by: { $0.createdAt > $1.createdAt })
            
            
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
            
        }
    }
    
    func markAllNotificationsAsRead() async {
        // 1. Instantly update local state so UI reflects immediately (no reload needed)
        notificationsList = notificationsList.map { notif in
            var updated = notif
            updated.isRead = true
            return updated
        }
        // 2. Persist to Supabase in the background
        let unread = notificationsList  // all now have isRead = true
        for notif in unread {
            try? await SupabaseManager.shared.updateNotification(notif)
        }
    }
    
    

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
            DriverChatMessage(id: UUID(), sender: "Rajiv Sharma",     role: "Fleet Manager",
                              preview: "Confirm ETA for Route 2.",    time: "10:32 AM", unread: true,  initials: "RS", isMe: false),
            DriverChatMessage(id: UUID(), sender: "Maintenance Desk", role: "Maintenance",
                              preview: "TN-07-AB-1234 ready for dispatch.", time: "9:15 AM",  unread: true,  initials: "MD", isMe: false),
            DriverChatMessage(id: UUID(), sender: "Priya Menon",      role: "Fleet Manager",
                              preview: "Updated route file sent.",    time: "Yesterday", unread: false, initials: "PM", isMe: false)
        ]
        banners = [
            DashboardBanner(title: "Trip Assigned",
                            body: "New trip #TRP-2240 at 12:30 PM", kind: .info),
            DashboardBanner(title: "Pre-Trip Due",
                            body: "Complete inspection before departure", kind: .warning)
        ]
    }
}
