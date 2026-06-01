




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
    
    private var isLiveTracking = false
    private var trackingTask: Task<Void, Never>?
    
    func startLiveTracking() {
        guard !isLiveTracking else { return }
        isLiveTracking = true
        trackingTask = Task {
            while isLiveTracking {
                await loadVehicles(isBackgroundRefresh: true)
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }
    
    func stopLiveTracking() {
        isLiveTracking = false
        trackingTask?.cancel()
        trackingTask = nil
    }
    
    func loadVehicles(isBackgroundRefresh: Bool = false) async {
        if !isBackgroundRefresh && mappedVehicles.isEmpty {
            isLoading = true
        }
        
        do {
            let fetchedVehicles = try await supabaseManager.fetchVehicles()
            
            var locationMap: [UUID: DBVehicleLocation] = [:]
            do {
                let latestLocations = try await supabaseManager.fetchLatestVehicleLocations()
                let oneDayAgo = Date().addingTimeInterval(-86400)
                for loc in latestLocations {
                    if loc.timestamp > oneDayAgo {
                        locationMap[loc.vehicleId] = loc
                    }
                }
            } catch {
                throw error
            }
            
            self.mappedVehicles = fetchedVehicles.compactMap { vehicle in
                guard let loc = locationMap[vehicle.id] else {
                    return nil
                }
                return MappedVehicle(
                    vehicle: vehicle,
                    coordinate: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude),
                    lastUpdated: loc.timestamp
                )
            }
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
        }
        
        if !isBackgroundRefresh {
            isLoading = false
        }
    }
}
