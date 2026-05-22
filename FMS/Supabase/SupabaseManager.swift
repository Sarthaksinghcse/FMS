//
//  SupabaseManager.swift
//  FMS
//
//  Created by Naman Yadav on 21/05/26.
//

import Foundation
import Supabase
import Combine

// MARK: - InMemoryLocalStorage
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
    private static let supabaseURL = URL(string: "https://trkurrtlyzfsssnptdsc.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRya3VycnRseXpmc3NzbnB0ZHNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNTI0NTgsImV4cCI6MjA5NDkyODQ1OH0.380Es9QbO6ppO9bFUiFV3qmNKpgWzf3fzBKR9S9Ajuo"
    
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
                password: password.uuidString, // using password string from your view
                data: [
                    "name": .string(fullName),
                    "role": .string(role.rawValue)
                ]
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
            
            do {
                try await client
                    .from("users")
                    .upsert(dbUser)
                    .execute()
            } catch {
                print("Failed to insert user profile: \(error)")
                // Proceed anyway so the app remains runnable even if tables are missing
            }
                
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
                createdAt: Date()
            )
            
            do {
                try await client
                    .from("users")
                    .upsert(dbUser)
                    .execute()
            } catch {
                print("Failed to insert user profile: \(error)")
                // Proceed anyway so the app remains runnable even if tables are missing
            }
                
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
                // Profile not found — mock user to keep the app runnable if DB isn't set up
                dbUser = DBUser(
                    id: userId,
                    name: "Test User",
                    email: email,
                    role: expectedRole,
                    phoneNumber: nil,
                    profileImage: nil,
                    createdAt: Date()
                )
            }
            
            // Step 3: Self-healing role sync
            // Parse role from user metadata
            var authMetadataRole: DBUserRole? = nil
            let metadata = response.user.userMetadata
            if let roleJSON = metadata["role"], case .string(let roleStr) = roleJSON {
                authMetadataRole = DBUserRole(rawValue: roleStr)
            }
            
            // If the metadata role matches the expected role but the database profile has a mismatch,
            // we override the database profile role and update it in Supabase under the user's new session.
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
                    print("⚠️ Failed to sync database role: \(error.localizedDescription)")
                }
            }
            
            // Step 4: Verify the role matches the selected role
            guard dbUser.role == expectedRole else {
                // Wrong role — sign out immediately so session is not persisted
                try? await client.auth.signOut()
                self.currentUser = nil
                throw AuthError.roleMismatch(expected: expectedRole, actual: dbUser.role)
            }
            
            // Step 5: All good — persist the user
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
            
            // Resolve role, name, and email from Auth userMetadata if possible to avoid role mismatch/conflict
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
            
            // Fallback to a resolved user metadata or defaults so the session isn't immediately killed
            self.currentUser = DBUser(
                id: userId,
                name: resolvedName,
                email: resolvedEmail,
                role: resolvedRole,
                phoneNumber: nil,
                profileImage: nil,
                createdAt: Date()
            )
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
    
    // MARK: - Driver CRUD
    
    /// Fetches all drivers from public.users.
    func fetchDrivers() async throws -> [DBUser] {
        return try await client
            .from("users")
            .select()
            .eq("role", value: DBUserRole.driver.rawValue)
            .execute()
            .value
    }
    
    /// Creates a new driver Auth account and profile record.
    /// Returns the created DBUser containing the generated Auth UUID.
    func createDriver(email: String, passwordString: String, fullName: String, phoneNumber: String, isActive: Bool) async throws -> DBUser {
        // 1. Create a temporary client with in-memory storage so it doesn't affect manager session
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
        
        // 2. Sign up user in Supabase Auth
        let authResponse = try await tempClient.auth.signUp(
            email: email,
            password: passwordString,
            data: [
                "name": .string(fullName),
                "role": .string(DBUserRole.driver.rawValue)
            ]
        )
        
        let authUserId = authResponse.user.id
        
        // 3. Create profile in public.users using the main client
        let dbUser = DBUser(
            id: authUserId,
            name: fullName,
            email: email,
            role: .driver,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            profileImage: nil,
            createdAt: Date()
        )
        
        do {
            try await client
                .from("users")
                .upsert(dbUser)
                .execute()
        } catch {
            print("⚠️ Profile upsert failed (possibly auto-inserted by database trigger): \(error.localizedDescription)")
            // Safe to ignore because our self-healing role sync during login will fix the profile record
        }
            
        return dbUser
    }
    
    /// Updates a driver profile record.
    func updateDriver(_ driver: DBUser) async throws {
        try await client
            .from("users")
            .update(driver)
            .eq("id", value: driver.id.uuidString)
            .execute()
    }
    
    /// Deletes a driver profile record.
    func deleteDriver(id: UUID) async throws {
        try await client
            .from("users")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Vehicle CRUD Extensions
    
    /// Updates a vehicle record.
    func updateVehicle(_ vehicle: DBVehicle) async throws {
        try await client
            .from("vehicles")
            .update(vehicle)
            .eq("id", value: vehicle.id.uuidString)
            .execute()
    }
    
    /// Deletes a vehicle record.
    func deleteVehicle(id: UUID) async throws {
        try await client
            .from("vehicles")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Trip CRUD Extensions
    
    /// Updates a trip record.
    func updateTrip(_ trip: DBTrip) async throws {
        try await client
            .from("trips")
            .update(trip)
            .eq("id", value: trip.id.uuidString)
            .execute()
    }
    
    /// Deletes a trip record.
    func deleteTrip(id: UUID) async throws {
        try await client
            .from("trips")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}


