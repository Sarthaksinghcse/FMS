






import Foundation
import Supabase
import Combine
import SwiftData


class InMemoryLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let queue = DispatchQueue(label: "InMemoryLocalStorageQueue")
    
    func store(key: String, value: Data) throws {
        queue.sync {
            storage[key] = value
        }
    }
    
    func retrieve(key: String) throws -> Data? {
        return queue.sync {
            storage[key]
        }
    }
    
    func remove(key: String) throws {
        queue.sync {
            _ = storage.removeValue(forKey: key)
        }
    }
}


enum AuthError: LocalizedError {
    case roleMismatch(expected: DBUserRole, actual: DBUserRole)
    case profileNotFound
    
    var errorDescription: String? {
        switch self {
        case .roleMismatch(let expected, let actual):
            return "You selected \"\(expected.displayName)\" but your account is registered as \"\(actual.displayName)\". Please choose the correct role."
        case .profileNotFound:
            return "User profile could not be found in the database."
        }
    }
}



@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    
    
    private static let supabaseURL = URL(string: "https://trkurrtlyzfsssnptdsc.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRya3VycnRseXpmc3NzbnB0ZHNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNTI0NTgsImV4cCI6MjA5NDkyODQ1OH0.380Es9QbO6ppO9bFUiFV3qmNKpgWzf3fzBKR9S9Ajuo"
    
    
    let client: SupabaseClient
    
    
    @Published var currentUser: DBUser?
    
    @Published var isLoading = false
    
    @Published var authError: String?
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
        
        
        Task {
            for await state in client.auth.authStateChanges {
                if let session = state.session, !session.isExpired {
                    await fetchProfile(userId: session.user.id)
                } else {
                    self.currentUser = nil
                }
            }
        }
    }
    
    
    
    
    
    func signUp(email: String, password: UUID, fullName: String, role: DBUserRole = .fleetManager) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            
            let response = try await client.auth.signUp(
                email: email,
                password: password.uuidString, 
                data: [
                    "name": .string(fullName),
                    "role": .string(role.rawValue)
                ]
            )
            
            let authUser = response.user

            
            
            let dbUser = DBUser(
                id: authUser.id,
                name: fullName,
                email: email,
                role: role,
                phoneNumber: nil,
                profileImage: nil,
                isActive: true,
                createdAt: Date()
            )
            
            do {
                try await client
                    .from("users")
                    .upsert(dbUser)
                    .execute()
            } catch {
                print("Failed to insert user profile: \(error)")
                
            }
                
            self.currentUser = dbUser
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    
    func signUp(email: String, passwordString: String, fullName: String, role: DBUserRole = .fleetManager) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: passwordString,
                data: [
                    "name": .string(fullName),
                    "role": .string(role.rawValue)
                ]
            )
            
            let authUser = response.user

            
            let dbUser = DBUser(
                id: authUser.id,
                name: fullName,
                email: email,
                role: role,
                phoneNumber: nil,
                profileImage: nil,
                isActive: true,
                createdAt: Date()
            )
            
            do {
                try await client
                    .from("users")
                    .upsert(dbUser)
                    .execute()
            } catch {
                print("Failed to insert user profile: \(error)")
                
            }
                
            self.currentUser = dbUser
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    
    func signIn(email: String, passwordString: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signIn(
                email: email,
                password: passwordString
            )
            
            let user = response.user
            await fetchProfile(userId: user.id)

        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    
    
    func signIn(email: String, passwordString: String, expectedRole: DBUserRole) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            
            let response = try await client.auth.signIn(
                email: email,
                password: passwordString
            )
            
            
            let userId = response.user.id
            var dbUser: DBUser
            do {
                dbUser = try await client
                    .from("users")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
            } catch {
                print("Profile fetch error: \(error)")
                
                dbUser = DBUser(
                    id: userId,
                    name: "Test User",
                    email: email,
                    role: expectedRole,
                    phoneNumber: nil,
                    profileImage: nil,
                    isActive: true,
                    createdAt: Date()
                )
            }
            
            
            
            var authMetadataRole: DBUserRole? = nil
            let metadata = response.user.userMetadata
            if let roleJSON = metadata["role"], case .string(let roleStr) = roleJSON {
                authMetadataRole = DBUserRole(rawValue: roleStr)
            }
            
            
            
            if dbUser.role != expectedRole, authMetadataRole == expectedRole {
                print("Syncing database role \(dbUser.role.rawValue) to expected role \(expectedRole.rawValue) based on Auth metadata")
                dbUser.role = expectedRole
                do {
                    try await client
                        .from("users")
                        .update(dbUser)
                        .eq("id", value: userId.uuidString)
                        .execute()
                } catch {
                    print("Failed to sync database role: \(error.localizedDescription)")
                }
            }
            
            
            guard dbUser.role == expectedRole else {
                
                try? await client.auth.signOut()
                self.currentUser = nil
                throw AuthError.roleMismatch(expected: expectedRole, actual: dbUser.role)
            }
            
            
            self.currentUser = dbUser
            
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await client.auth.signOut()
            self.currentUser = nil
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    
    func fetchProfile(userId: UUID) async {
        do {
            let dbUser: DBUser = try await client
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            self.currentUser = dbUser
        } catch {
            print("Error fetching user profile from database: \(error)")
            
            
            var resolvedRole: DBUserRole = .fleetManager
            var resolvedName: String = "Test User"
            var resolvedEmail: String = "test@fms.com"
            
            if let user = client.auth.currentUser {
                resolvedEmail = user.email ?? resolvedEmail
                let metadata = user.userMetadata
                if let nameJSON = metadata["name"], case .string(let nameStr) = nameJSON {
                    resolvedName = nameStr
                }
                if let roleJSON = metadata["role"], case .string(let roleStr) = roleJSON {
                    if let roleEnum = DBUserRole(rawValue: roleStr) {
                        resolvedRole = roleEnum
                    }
                }
            }
            
            
            self.currentUser = DBUser(
                id: userId,
                name: resolvedName,
                email: resolvedEmail,
                role: resolvedRole,
                phoneNumber: nil,
                profileImage: nil,
                isActive: true,
                createdAt: Date()
            )
        }
    }
    
    
    
    
    func fetchVehicles() async throws -> [DBVehicle] {
        return try await client
            .from("vehicles")
            .select()
            .execute()
            .value
    }
    
    
    func createVehicle(_ vehicle: DBVehicle) async throws {
        try await client
            .from("vehicles")
            .insert(vehicle)
            .execute()
    }
    
    
    func fetchTrips() async throws -> [DBTrip] {
        return try await client
            .from("trips")
            .select()
            .execute()
            .value
    }
    
    
    func createTrip(_ trip: DBTrip) async throws {
        try await client
            .from("trips")
            .insert(trip)
            .execute()
    }
    
    
    func submitInspection(_ inspection: DBVehicleInspection) async throws {
        try await client
            .from("vehicle_inspections")
            .insert(inspection)
            .execute()
    }
    
    
    
    
    func fetchDrivers() async throws -> [DBUser] {
        return try await client
            .from("users")
            .select()
            .eq("role", value: DBUserRole.driver.rawValue)
            .execute()
            .value
    }
    
    
    
    func createDriver(email: String, passwordString: String, fullName: String, phoneNumber: String, isActive: Bool) async throws -> DBUser {
        
        let tempClient = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: InMemoryLocalStorage(),
                    emitLocalSessionAsInitialSession: false
                )
            )
        )
        
        
        let authResponse = try await tempClient.auth.signUp(
            email: email,
            password: passwordString,
            data: [
                "name": .string(fullName),
                "role": .string(DBUserRole.driver.rawValue)
            ]
        )
        
        let authUserId = authResponse.user.id
        
        
        let dbUser = DBUser(
            id: authUserId,
            name: fullName,
            email: email,
            role: .driver,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            profileImage: nil,
            isActive: isActive,
            createdAt: Date()
        )
        
        do {
            try await client
                .from("users")
                .upsert(dbUser)
                .execute()
        } catch {
            print("⚠️ Profile upsert failed (possibly auto-inserted by database trigger): \(error.localizedDescription)")
            
        }
            
        return dbUser
    }
    
    func createMaintenanceStaff(email: String, passwordString: String, fullName: String, phoneNumber: String, isActive: Bool) async throws -> DBUser {
        let tempClient = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: InMemoryLocalStorage(),
                    emitLocalSessionAsInitialSession: false
                )
            )
        )
        
        let authResponse = try await tempClient.auth.signUp(
            email: email,
            password: passwordString,
            data: [
                "name": .string(fullName),
                "role": .string(DBUserRole.maintenance.rawValue)
            ]
        )
        
        let authUserId = authResponse.user.id
        
        let dbUser = DBUser(
            id: authUserId,
            name: fullName,
            email: email,
            role: .maintenance,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            profileImage: nil,
            isActive: isActive,
            createdAt: Date()
        )
        
        do {
            try await client
                .from("users")
                .upsert(dbUser)
                .execute()
        } catch {
            print("⚠️ Profile upsert failed (possibly auto-inserted by database trigger): \(error.localizedDescription)")
        }
            
        return dbUser
    }
    
    
    func updateDriver(_ driver: DBUser) async throws {
        try await client
            .from("users")
            .update(driver)
            .eq("id", value: driver.id.uuidString)
            .execute()
        
        await MainActor.run {
            if self.currentUser?.id == driver.id {
                self.currentUser = driver
            }
        }
    }
    
    
    func deleteDriver(id: UUID) async throws {
        try await client
            .from("users")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    
    
    
    func updateVehicle(_ vehicle: DBVehicle) async throws {
        try await client
            .from("vehicles")
            .update(vehicle)
            .eq("id", value: vehicle.id.uuidString)
            .execute()
    }
    
    
    func deleteVehicle(id: UUID) async throws {
        try await client
            .from("vehicles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    
    
    
    func updateTrip(_ trip: DBTrip) async throws {
        try await client
            .from("trips")
            .update(trip)
            .eq("id", value: trip.id.uuidString)
            .execute()
    }
    
    
    func deleteTrip(id: UUID) async throws {
        try await client
            .from("trips")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    
    
    
    func fetchWorkOrders() async throws -> [DBWorkOrder] {
        return try await client
            .from("work_orders")
            .select()
            .execute()
            .value
    }
    
    
    func createWorkOrder(_ workOrder: DBWorkOrder) async throws {
        try await client
            .from("work_orders")
            .insert(workOrder)
            .execute()
    }
    
    
    func updateWorkOrder(_ workOrder: DBWorkOrder) async throws {
        try await client
            .from("work_orders")
            .update(workOrder)
            .eq("id", value: workOrder.id.uuidString)
            .execute()
    }
    
    
    func deleteWorkOrder(id: UUID) async throws {
        try await client
            .from("work_orders")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    
    
    
    func fetchMaintenanceTasks() async throws -> [DBMaintenanceTask] {
        return try await client
            .from("maintenance_tasks")
            .select()
            .execute()
            .value
    }
    
    
    func createMaintenanceTask(_ task: DBMaintenanceTask) async throws {
        try await client
            .from("maintenance_tasks")
            .insert(task)
            .execute()
    }
    
    
    func updateMaintenanceTask(_ task: DBMaintenanceTask) async throws {
        try await client
            .from("maintenance_tasks")
            .update(task)
            .eq("id", value: task.id.uuidString)
            .execute()
    }
    
    
    
    
    func fetchMessages() async throws -> [DBMessage] {
        return try await client
            .from("messages")
            .select()
            .order("timestamp", ascending: true)
            .execute()
            .value
    }
    
    
    func sendMessage(_ message: DBMessage) async throws {
        try await client
            .from("messages")
            .insert(message)
            .execute()
    }
    
    
    
    
    func fetchNotifications() async throws -> [DBNotification] {
        return try await client
            .from("notifications")
            .select()
            .execute()
            .value
    }
    
    
    func createNotification(_ notification: DBNotification) async throws {
        try await client
            .from("notifications")
            .insert(notification)
            .execute()
    }
    
    
    func updateNotification(_ notification: DBNotification) async throws {
        try await client
            .from("notifications")
            .update(notification)
            .eq("id", value: notification.id.uuidString)
            .execute()
    }
    
    
    func fetchDefectReports() async throws -> [DBDefectReport] {
        return try await client
            .from("defect_reports")
            .select()
            .execute()
            .value
    }
    
    func createDefectReport(_ defect: DBDefectReport) async throws {
        try await client
            .from("defect_reports")
            .insert(defect)
            .execute()
    }
    
    func updateDefectReport(_ defect: DBDefectReport) async throws {
        try await client
            .from("defect_reports")
            .update(defect)
            .eq("id", value: defect.id.uuidString)
            .execute()
    }
    
    func fetchFleetManagers() async throws -> [DBUser] {
        return try await client
            .from("users")
            .select()
            .eq("role", value: DBUserRole.fleetManager.rawValue)
            .execute()
            .value
    }
    
    func fetchMaintenancePersonnel() async throws -> [DBUser] {
        return try await client
            .from("users")
            .select()
            .eq("role", value: DBUserRole.maintenance.rawValue)
            .execute()
            .value
    }
    
    func notifyFleetManagers(title: String, message: String, type: DBNotificationType) async {
        do {
            let managers = try await fetchFleetManagers()
            for manager in managers {
                let notif = DBNotification(
                    id: UUID(),
                    userId: manager.id,
                    title: title,
                    message: message,
                    type: type,
                    isRead: false,
                    createdAt: Date()
                )
                try await createNotification(notif)
            }
        } catch {
            print("Failed to notify fleet managers: \(error.localizedDescription)")
        }
    }
    
    
    
    
    func insertVehicleLocation(_ location: DBVehicleLocation) async throws {
        try await client
            .from("vehicle_locations")
            .insert(location)
            .execute()
    }
    
    
    func fetchLatestVehicleLocations() async throws -> [DBVehicleLocation] {
        return try await client
            .from("v_latest_vehicle_location")
            .select()
            .execute()
            .value
    }
    
    // SOS Alerts
    func fetchSOSAlerts() async throws -> [DBSOSAlert] {
        return try await client
            .from("sos_alerts")
            .select()
            .execute()
            .value
    }
    
    func createSOSAlert(_ alert: DBSOSAlert) async throws {
        try await client
            .from("sos_alerts")
            .insert(alert)
            .execute()
    }
    
    func updateSOSAlert(_ alert: DBSOSAlert) async throws {
        try await client
            .from("sos_alerts")
            .update(alert)
            .eq("id", value: alert.id.uuidString)
            .execute()
    }
    
    // Inventory
    func fetchInventory() async throws -> [DBInventoryItem] {
        return try await client
            .from("inventory")
            .select()
            .execute()
            .value
    }
    
    func createInventoryItem(_ item: DBInventoryItem) async throws {
        try await client
            .from("inventory")
            .insert(item)
            .execute()
    }
    
    func updateInventoryItem(_ item: DBInventoryItem) async throws {
        try await client
            .from("inventory")
            .update(item)
            .eq("id", value: item.id.uuidString)
            .execute()
    }
    
    func deleteInventoryItem(id: UUID) async throws {
        try await client
            .from("inventory")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Maintenance Records
    func fetchMaintenanceRecords() async throws -> [DBMaintenanceRecord] {
        return try await client
            .from("maintenance_records")
            .select()
            .execute()
            .value
    }
    
    func createMaintenanceRecord(_ record: DBMaintenanceRecord) async throws {
        try await client
            .from("maintenance_records")
            .insert(record)
            .execute()
    }
    
    func updateMaintenanceRecord(_ record: DBMaintenanceRecord) async throws {
        try await client
            .from("maintenance_records")
            .update(record)
            .eq("id", value: record.id.uuidString)
            .execute()
    }
    
    func uploadRepairImage(recordId: UUID, imageData: Data, index: Int) async throws -> String {
        let path = "\(recordId.uuidString)_\(index).jpg"
        
        _ = try await client.storage
            .from("maintenance-images")
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        
        let url = try client.storage
            .from("maintenance-images")
            .getPublicURL(path: path)
        
        return url.absoluteString
    }
    
    // Storage Avatar Upload
    func uploadAvatar(userId: UUID, imageData: Data) async throws -> String {
        let path = "\(userId.uuidString).jpg"
        
        _ = try await client.storage
            .from("avatars")
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        
        let url = try client.storage
            .from("avatars")
            .getPublicURL(path: path)
        
        return url.absoluteString
    }
    
    
    
    
    func syncAllData(context: ModelContext) async {
        guard currentUser != nil else { return }
        
        do {
            
            if let remoteVehicles = try? await fetchVehicles() {
                let descriptor = FetchDescriptor<Vehicle>()
                let localVehicles = (try? context.fetch(descriptor)) ?? []
                for rv in remoteVehicles {
                    if let local = localVehicles.first(where: { $0.id == rv.id }) {
                        local.registrationNumber = rv.vehicleNumber
                        local.vinNumber = rv.vin
                        local.make = rv.manufacturer
                        local.model = rv.model
                        local.year = rv.year
                        local.status = rv.status.toLocalStatus
                        local.assignedDriverId = rv.assignedDriverId
                        local.lastServiceDate = rv.lastServiceDate
                    } else {
                        context.insert(rv.asLocalVehicle)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteVehicles.map { $0.id })
                    for localVehicle in localVehicles {
                        if !remoteIds.contains(localVehicle.id) {
                            context.delete(localVehicle)
                        }
                    }
                }
            }
            
            
            if let remoteDrivers = try? await fetchDrivers() {
                let descriptor = FetchDescriptor<User>()
                let localUsers = (try? context.fetch(descriptor)) ?? []
                for rd in remoteDrivers {
                    if let local = localUsers.first(where: { $0.id == rd.id }) {
                        local.fullName = rd.name
                        local.email = rd.email
                        local.phoneNumber = rd.phoneNumber ?? ""
                        local.role = rd.role.asLocalRole
                        local.isActive = rd.isActive
                    } else {
                        context.insert(rd.asLocalUser)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteDrivers.map { $0.id })
                    let localDrivers = localUsers.filter { $0.role == .driver }
                    for localDriver in localDrivers {
                        if !remoteIds.contains(localDriver.id) {
                            context.delete(localDriver)
                        }
                    }
                }
            }
            
            if let remoteMaintenance = try? await fetchMaintenancePersonnel() {
                let descriptor = FetchDescriptor<User>()
                let localUsers = (try? context.fetch(descriptor)) ?? []
                for rm in remoteMaintenance {
                    if let local = localUsers.first(where: { $0.id == rm.id }) {
                        local.fullName = rm.name
                        local.email = rm.email
                        local.phoneNumber = rm.phoneNumber ?? ""
                        local.role = rm.role.asLocalRole
                        local.isActive = rm.isActive
                    } else {
                        context.insert(rm.asLocalUser)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteMaintenance.map { $0.id })
                    let localMaintenance = localUsers.filter { $0.role == .maintenance }
                    for localStaff in localMaintenance {
                        if !remoteIds.contains(localStaff.id) {
                            context.delete(localStaff)
                        }
                    }
                }
            }
            
            
            if let remoteTrips = try? await fetchTrips() {
                let descriptor = FetchDescriptor<Trip>()
                let localTrips = (try? context.fetch(descriptor)) ?? []
                for rt in remoteTrips {
                    if let local = localTrips.first(where: { $0.id == rt.id }) {
                        local.tripCode = rt.tripCode
                        local.vehicleId = rt.vehicleId
                        local.driverId = rt.driverId
                        local.startLocation = rt.source
                        local.endLocation = rt.destination
                        local.scheduledStartTime = rt.startTime ?? Date()
                        local.scheduledEndTime = rt.endTime ?? Date().addingTimeInterval(7200)
                        local.actualStartTime = rt.startTime
                        local.actualEndTime = rt.endTime
                        local.distanceKm = rt.distance
                        local.tripStatus = rt.status.toLocalStatus
                        local.notes = rt.notes
                    } else {
                        context.insert(rt.asLocalTrip)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteTrips.map { $0.id })
                    for localTrip in localTrips {
                        if !remoteIds.contains(localTrip.id) {
                            context.delete(localTrip)
                        }
                    }
                } else if currentUser?.role == .driver {
                    let remoteIds = Set(remoteTrips.map { $0.id })
                    for localTrip in localTrips {
                        if localTrip.driverId == currentUser?.id && !remoteIds.contains(localTrip.id) {
                            context.delete(localTrip)
                        }
                    }
                }
            }
            
            
            if let remoteWorkOrders = try? await fetchWorkOrders() {
                let descriptor = FetchDescriptor<WorkOrder>()
                let localWorkOrders = (try? context.fetch(descriptor)) ?? []
                for rwo in remoteWorkOrders {
                    if let local = localWorkOrders.first(where: { $0.id == rwo.id }) {
                        local.vehicleId = rwo.vehicleId
                        local.assignedTo = rwo.assignedTo
                        local.priority = rwo.priority.toLocalPriority
                        local.workDescription = rwo.issueDescription
                        local.status = rwo.status.toLocalStatus
                    } else {
                        context.insert(rwo.asLocalWorkOrder)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteWorkOrders.map { $0.id })
                    for localWorkOrder in localWorkOrders {
                        if !remoteIds.contains(localWorkOrder.id) {
                            context.delete(localWorkOrder)
                        }
                    }
                }
            }
            
            
            if let remoteNotifications = try? await fetchNotifications() {
                let descriptor = FetchDescriptor<AppNotification>()
                let localNotifications = (try? context.fetch(descriptor)) ?? []
                for rn in remoteNotifications {
                    if let local = localNotifications.first(where: { $0.id == rn.id }) {
                        local.userId = rn.userId
                        local.title = rn.title
                        local.message = rn.message
                        local.type = rn.type.toLocalType
                        local.isRead = rn.isRead
                    } else {
                        context.insert(rn.asLocalNotification)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteNotifications.map { $0.id })
                    for localNotification in localNotifications {
                        if !remoteIds.contains(localNotification.id) {
                            context.delete(localNotification)
                        }
                    }
                }
            }
            
            // Sync Defect Reports
            if let remoteDefects = try? await fetchDefectReports() {
                let descriptor = FetchDescriptor<DefectReport>()
                let localDefects = (try? context.fetch(descriptor)) ?? []
                for rd in remoteDefects {
                    if let local = localDefects.first(where: { $0.id == rd.id }) {
                        local.vehicleId = rd.vehicleId
                        local.reportedBy = rd.reportedBy
                        local.inspectionId = rd.inspectionId
                        local.title = rd.title
                        local.defectDescription = rd.defectDescription
                        local.severity = rd.severity
                        local.status = rd.status
                    } else {
                        context.insert(rd.asLocalDefectReport)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteDefects.map { $0.id })
                    for localDefect in localDefects {
                        if !remoteIds.contains(localDefect.id) {
                            context.delete(localDefect)
                        }
                    }
                }
            }
            
            // Sync SOS Alerts
            if let remoteSOS = try? await fetchSOSAlerts() {
                let descriptor = FetchDescriptor<SOSAlert>()
                let localSOS = (try? context.fetch(descriptor)) ?? []
                for rs in remoteSOS {
                    if let local = localSOS.first(where: { $0.id == rs.id }) {
                        local.driverId = rs.driverId
                        local.vehicleId = rs.vehicleId ?? UUID()
                        local.tripId = rs.tripId
                        local.latitude = rs.latitude
                        local.longitude = rs.longitude
                        local.message = rs.message
                        local.status = rs.status.toLocalStatus
                    } else {
                        context.insert(rs.asLocalSOS)
                    }
                }
                
                if currentUser?.role == .fleetManager {
                    let remoteIds = Set(remoteSOS.map { $0.id })
                    for localAlert in localSOS {
                        if !remoteIds.contains(localAlert.id) {
                            context.delete(localAlert)
                        }
                    }
                }
            }
            
            // Sync Inventory
            if let remoteInventory = try? await fetchInventory() {
                let descriptor = FetchDescriptor<InventoryItem>()
                let localInventory = (try? context.fetch(descriptor)) ?? []
                for ri in remoteInventory {
                    if let local = localInventory.first(where: { $0.id == ri.id }) {
                        local.partName = ri.partName
                        local.partNumber = ri.partNumber
                        local.quantityInStock = ri.quantityInStock
                        local.reorderThreshold = ri.reorderThreshold
                        local.unitCost = ri.unitCost
                        local.supplierName = ri.supplierName
                        local.updatedAt = ri.updatedAt
                    } else {
                        context.insert(ri.asLocalItem)
                    }
                }
                
                if currentUser?.role == .fleetManager || currentUser?.role == .maintenance {
                    let remoteIds = Set(remoteInventory.map { $0.id })
                    for localItem in localInventory {
                        if !remoteIds.contains(localItem.id) {
                            context.delete(localItem)
                        }
                    }
                }
            }
            
            // Sync Maintenance Records
            if let remoteRecords = try? await fetchMaintenanceRecords() {
                let descriptor = FetchDescriptor<MaintenanceRecord>()
                let localRecords = (try? context.fetch(descriptor)) ?? []
                for rr in remoteRecords {
                    if let local = localRecords.first(where: { $0.id == rr.id }) {
                        local.vehicleId = rr.vehicleId
                        local.workOrderId = rr.workOrderId
                        local.serviceType = rr.serviceType
                        local.serviceDate = rr.serviceDate
                        local.cost = rr.cost
                        local.notes = rr.notes
                        local.repairImages = rr.repairImages
                        local.performedBy = rr.performedBy
                    } else {
                        context.insert(rr.asLocalRecord)
                    }
                }
                
                if currentUser?.role == .fleetManager || currentUser?.role == .maintenance {
                    let remoteIds = Set(remoteRecords.map { $0.id })
                    for localRecord in localRecords {
                        if !remoteIds.contains(localRecord.id) {
                            context.delete(localRecord)
                        }
                    }
                }
            }
            
            try context.save()
            print("Successfully synchronized and deduplicated all data from Supabase to SwiftData")
        } catch {
            print("Reconciled data synchronization error: \(error.localizedDescription)")
        }
    }
}


