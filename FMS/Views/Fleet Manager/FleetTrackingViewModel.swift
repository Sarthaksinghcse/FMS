//
//  FleetTrackingViewModel.swift
//  FMS
//
//  Created by Priyanshu Namdev on 21/05/26.
//

import Foundation
import MapKit
import SwiftUI
import Combine

/// A struct to hold the vehicle along with its mocked coordinate for the map
struct MappedVehicle: Identifiable, Hashable {
    let id = UUID()
    let vehicle: DBVehicle
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: MappedVehicle, rhs: MappedVehicle) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var statusColor: Color {
        switch vehicle.status {
        case .available: return .green
        case .inUse: return .blue
        case .maintenance: return .orange
        case .inactive: return .gray
        }
    }
}

@MainActor
@available(iOS 26.0, *)
final class FleetTrackingViewModel: ObservableObject {
    @Published var mappedVehicles: [MappedVehicle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Default center for the map and geofence (e.g., Apple Park)
    let hubCoordinate = CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020)
    let geofenceRadius: CLLocationDistance = 5000 // 5 km radius
    
    private let supabaseManager = SupabaseManager.shared
    
    func loadVehicles() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedVehicles = try await supabaseManager.fetchVehicles()
            
            // Assign random coordinates around the hub
            self.mappedVehicles = fetchedVehicles.map { vehicle in
                let randomLatOffset = Double.random(in: -0.04...0.04)
                let randomLonOffset = Double.random(in: -0.04...0.04)
                
                let coordinate = CLLocationCoordinate2D(
                    latitude: hubCoordinate.latitude + randomLatOffset,
                    longitude: hubCoordinate.longitude + randomLonOffset
                )
                
                return MappedVehicle(vehicle: vehicle, coordinate: coordinate)
            }
        } catch {
            self.errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
