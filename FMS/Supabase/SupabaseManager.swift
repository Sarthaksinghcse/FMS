//
//  SupabaseManager.swift
//  FMS
//
//  Created by Naman Yadav on 21/05/26.
//

import Foundation
import Supabase
internal import Combine

// MARK: - Auth Errors
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

// MARK: - Supabase Manager
/// A singleton manager to coordinate all Supabase authentication and database interactions.
@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    // MARK: - Configuration
    // TODO: Replace these with your actual Supabase project credentials from Settings > API
    private static let supabaseURL = URL(string: "https://bwhprdxqfpdaohvbadij.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3aHByZHhxZnBkYW9odmJhZGlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyOTU2NTEsImV4cCI6MjA5NDg3MTY1MX0.b57Ykm7u8roOA20uJlteTvOfyvJISaZIFavpJ5vYUMI"
    
    /// The underlying Supabase client instance.
    let client: SupabaseClient
    
    /// The currently logged-in user profile, if any.
    @Published var currentUser: DBUser?
    /// Published loading state indicator.
    @Published var isLoading = false
    /// Any error message to be displayed.
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
        
        // Listen to auth state changes to keep session updated
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
    
    // MARK: - Authentication API
    
    /// Signs up a new administrator (Fleet Manager) account.
    /// In accordance with `supabase_schema.sql`, they must be inserted into the public.users table as 'fleet_manager'.
    func signUp(email: String, password: UUID, fullName: String, role: DBUserRole = .fleetManager) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            // 1. Sign up with Supabase Auth
            let response = try await client.auth.signUp(
                email: email,
                password: password.uuidString // using password string from your view
            )
            
            let authUser = response.user

            
            // 2. Insert profile record into public.users table
            let dbUser = DBUser(
                id: authUser.id,
                name: fullName,
                email: email,
                role: role,
                phoneNumber: nil,
                profileImage: nil,
                createdAt: Date()
            )
            
            try await client
                .from("users")
                .insert(dbUser)
                .execute()
                
            self.currentUser = dbUser
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    /// Overloaded helper for SignUp with simple password String
    func signUp(email: String, passwordString: String, fullName: String, role: DBUserRole = .fleetManager) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: passwordString
            )
            
            let authUser = response.user

            
            let dbUser = DBUser(
                id: authUser.id,
                name: fullName,
                email: email,
                role: role,
                phoneNumber: nil,
                profileImage: nil,
                createdAt: Date()
            )
            
            try await client
                .from("users")
                .insert(dbUser)
                .execute()
                
            self.currentUser = dbUser
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    /// Signs in an existing user using email and password.
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
    
    /// Signs in and validates that the user's DB role matches the expected role.
    /// Automatically signs out and throws `AuthError.roleMismatch` on mismatch.
    func signIn(email: String, passwordString: String, expectedRole: DBUserRole) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        
        do {
            // Step 1: Authenticate with Supabase Auth
            let response = try await client.auth.signIn(
                email: email,
                password: passwordString
            )
            
            // Step 2: Fetch the user's profile from the DB
            let userId = response.user.id
            let dbUser: DBUser
            do {
                dbUser = try await client
                    .from("users")
                    .select()
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
            } catch {
                // Profile not found — sign out and surface error
                try? await client.auth.signOut()
                self.currentUser = nil
                throw AuthError.profileNotFound
            }
            
            // Step 3: Verify the role matches the selected role
            guard dbUser.role == expectedRole else {
                // Wrong role — sign out immediately so session is not persisted
                try? await client.auth.signOut()
                self.currentUser = nil
                throw AuthError.roleMismatch(expected: expectedRole, actual: dbUser.role)
            }
            
            // Step 4: All good — persist the user
            self.currentUser = dbUser
            
        } catch {
            self.authError = error.localizedDescription
            throw error
        }
    }
    
    /// Signs out the current user session.
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
    
    /// Refreshes the local user profile from public.users.
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
        }
    }
    
    // MARK: - Database API (Examples matching schema)
    
    /// Fetches all vehicles from public.vehicles.
    func fetchVehicles() async throws -> [DBVehicle] {
        return try await client
            .from("vehicles")
            .select()
            .execute()
            .value
    }
    
    /// Creates a new vehicle record.
    func createVehicle(_ vehicle: DBVehicle) async throws {
        try await client
            .from("vehicles")
            .insert(vehicle)
            .execute()
    }
    
    /// Fetches all active trips for the current driver, or all trips if manager.
    func fetchTrips() async throws -> [DBTrip] {
        return try await client
            .from("trips")
            .select()
            .execute()
            .value
    }
    
    /// Creates a new trip.
    func createTrip(_ trip: DBTrip) async throws {
        try await client
            .from("trips")
            .insert(trip)
            .execute()
    }
    
    /// Submits a vehicle inspection.
    func submitInspection(_ inspection: DBVehicleInspection) async throws {
        try await client
            .from("vehicle_inspections")
            .insert(inspection)
            .execute()
    }
}

// MARK: - Codable Swift Database Models (Matching public schema in supabase_schema.sql)

enum DBUserRole: String, Codable {
    case fleetManager = "fleet_manager"
    case driver = "driver"
    case maintenance = "maintenance"
    
    var displayName: String {
        switch self {
        case .fleetManager: return "Fleet Manager"
        case .driver: return "Driver"
        case .maintenance: return "Maintenance Personnel"
        }
    }

    /// Converts to the SwiftData `UserRole` used by local model views.
    var asLocalRole: UserRole {
        switch self {
        case .fleetManager: return .fleetManager
        case .driver: return .driver
        case .maintenance: return .maintenance
        }
    }
}

struct DBUser: Codable, Identifiable {
    let id: UUID
    var name: String
    let email: String
    var role: DBUserRole
    var phoneNumber: String?
    var profileImage: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case phoneNumber = "phone_number"
        case profileImage = "profile_image"
        case createdAt = "created_at"
    }

    /// Bridges this Supabase DB user to the SwiftData `User` model
    /// used by views such as `MaintenanceDashboardView`.
    var asLocalUser: User {
        User(
            id: id,
            fullName: name,
            email: email,
            phoneNumber: phoneNumber ?? "",
            passwordHash: "",
            role: role.asLocalRole
        )
    }
}

enum DBVehicleStatus: String, Codable {
    case available
    case inUse = "in_use"
    case maintenance
    case inactive
}

struct DBVehicle: Codable, Identifiable {
    let id: UUID
    var vehicleNumber: String
    var model: String
    var manufacturer: String
    var year: Int
    var vin: String
    var licensePlate: String
    var status: DBVehicleStatus
    var assignedDriverId: UUID?
    var lastServiceDate: Date?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleNumber = "vehicle_number"
        case model
        case manufacturer
        case year
        case vin
        case licensePlate = "license_plate"
        case status
        case assignedDriverId = "assigned_driver_id"
        case lastServiceDate = "last_service_date"
        case createdAt = "created_at"
    }
}

enum DBTripStatus: String, Codable {
    case assigned
    case started
    case completed
    case cancelled
}

struct DBTrip: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var source: String
    var destination: String
    var startTime: Date?
    var endTime: Date?
    var distance: Double
    var status: DBTripStatus
    var notes: String?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case source
        case destination
        case startTime = "start_time"
        case endTime = "end_time"
        case distance
        case status
        case notes
        case createdAt = "created_at"
    }
}

enum DBInspectionStatus: String, Codable {
    case passed
    case failed
    case needsRepair = "needs_repair"
}

struct DBVehicleInspection: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var checklist: [String]
    var defects: String?
    var inspectionDate: Date
    var status: DBInspectionStatus
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case checklist
        case defects
        case inspectionDate = "inspection_date"
        case status
    }
}
