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
            if supabaseManager.currentUser == nil {
                AuthView()
            } else {
                DashboardView()
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
