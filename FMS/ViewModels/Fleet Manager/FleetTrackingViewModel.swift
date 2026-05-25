//
//  FleetTrackingViewModel.swift
//  FMS
//

import Foundation
import MapKit
import SwiftUI
import Combine


@MainActor
@Observable
final class FleetTrackingViewModel {
    var mappedVehicles: [MappedVehicle] = []
    var isLoading = false
    var errorMessage: String?
    
    let hubCoordinate = CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020)
    let geofenceRadius: CLLocationDistance = 5000
    
    private let supabaseManager = SupabaseManager.shared
    
    func loadVehicles() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedVehicles = try await supabaseManager.fetchVehicles()
            
            // Fetch real-time GPS coordinates from Supabase vehicle_locations
            var locationMap: [UUID: CLLocationCoordinate2D] = [:]
            do {
                let latestLocations = try await supabaseManager.fetchLatestVehicleLocations()
                for loc in latestLocations {
                    locationMap[loc.vehicleId] = CLLocationCoordinate2D(
                        latitude: loc.latitude,
                        longitude: loc.longitude
                    )
                }
            } catch {
                print("⚠️ Could not fetch live vehicle locations, falling back to defaults: \(error.localizedDescription)")
            }
            
            self.mappedVehicles = fetchedVehicles.map { vehicle in
                // Use real GPS coordinates if available, otherwise fall back to random offset
                let coordinate: CLLocationCoordinate2D
                if let realCoord = locationMap[vehicle.id] {
                    coordinate = realCoord
                } else {
                    let randomLatOffset = Double.random(in: -0.04...0.04)
                    let randomLonOffset = Double.random(in: -0.04...0.04)
                    coordinate = CLLocationCoordinate2D(
                        latitude: hubCoordinate.latitude + randomLatOffset,
                        longitude: hubCoordinate.longitude + randomLonOffset
                    )
                }
                
                return MappedVehicle(vehicle: vehicle, coordinate: coordinate)
            }
        } catch {
            self.errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
