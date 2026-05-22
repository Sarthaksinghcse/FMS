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
