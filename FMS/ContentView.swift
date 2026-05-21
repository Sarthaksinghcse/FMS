//
//  ContentView.swift
//  FMS
//
//  Created by Sarthak Singh on 19/05/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct ContentView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared

    var body: some View {
        Group {
            if let user = supabaseManager.currentUser {
                switch user.role {
                case .fleetManager:
                    FleetDashboardView()
                case .maintenance:
                    // Bridge DBUser → the SwiftData User the MaintenanceDashboardView expects
                    MaintenanceDashboardView(currentUser: user.asLocalUser)
                case .driver:
                    DriverPlaceholderView(user: user)
                }
            } else {
                AuthView()
            }
        }
    }
}


@available(iOS 26.0, *)
struct DashboardView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var vehicles: [DBVehicle] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("User Profile")) {
                    if let user = supabaseManager.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("Role: \(user.role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)")
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Vehicles (Supabase DB)")) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading vehicles...")
                            Spacer()
                        }
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    } else if vehicles.isEmpty {
                        Text("No vehicles found in database.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vehicles) { vehicle in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.vehicleNumber)
                                    .font(.headline)
                                Text("\(vehicle.manufacturer) \(vehicle.model) (\(String(vehicle.year)))")
                                    .font(.subheadline)
                                HStack {
                                    Text("Plate: \(vehicle.licensePlate)")
                                    Spacer()
                                    Text(vehicle.status.rawValue.uppercased())
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(vehicle.status == .available ? .green : .orange)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await supabaseManager.signOut()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("FMS Dashboard")
            .refreshable {
                await loadVehicles()
            }
            .task {
                await loadVehicles()
            }
        }
    }
    
    private func loadVehicles() async {
        isLoading = true
        errorMessage = nil
        do {
            vehicles = try await supabaseManager.fetchVehicles()
        } catch {
            errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

@available(iOS 26.0, *)
#Preview {
    ContentView()
}

// MARK: - Driver Placeholder Dashboard
/// Shown when a Driver logs in. Replace with the full DriverDashboardView when ready.
@available(iOS 26.0, *)
struct DriverPlaceholderView: View {
    let user: DBUser
    @StateObject private var supabaseManager = SupabaseManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Background.driverStart, AppTheme.Background.driverEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 110, height: 110)
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Welcome, \(user.name)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Driver Dashboard")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Text("Your full dashboard is coming soon.\nYou are securely logged in as a Driver.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    Button {
                        Task { try? await supabaseManager.signOut() }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.bottom, 48)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
