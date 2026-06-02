




import Foundation
import MapKit
import SwiftUI
import Combine
import Supabase


@MainActor
@Observable
final class FleetTrackingViewModel {
    var mappedVehicles: [MappedVehicle] = []
    var isLoading = false
    var errorMessage: String?
    
    // Changed from Cupertino to New Delhi to align with the rest of the app's mock data
    let hubCoordinate = CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090)
    let geofenceRadius: CLLocationDistance = 5000
    
    private let supabaseManager = SupabaseManager.shared
    
    private var isLiveTracking = false
    private var realtimeChannel: RealtimeChannelV2? = nil
    
    func startLiveTracking() {
        guard !isLiveTracking else { return }
        isLiveTracking = true
        
        Task {
            await loadVehicles(isBackgroundRefresh: true)
        }
        
        let client = supabaseManager.client
        let channel = client.channel("fleet_tracking_realtime")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "vehicle_locations")
        
        Task {
            try? await channel.subscribeWithError()
            self.realtimeChannel = channel
            
            for await _ in changes {
                await loadVehicles(isBackgroundRefresh: true)
            }
        }
    }
    
    func stopLiveTracking() {
        isLiveTracking = false
        if let active = realtimeChannel {
            let client = supabaseManager.client
            Task {
                await client.removeChannel(active)
            }
            realtimeChannel = nil
        }
    }
    
    func loadVehicles(isBackgroundRefresh: Bool = false) async {
        if !isBackgroundRefresh && mappedVehicles.isEmpty {
            isLoading = true
        }
        
        do {
            let fetchedVehicles = try await supabaseManager.fetchVehicles()
            let fetchedTrips = try await supabaseManager.fetchTrips()
            
            // Only include vehicles that are assigned to an active trip
            let activeTrips = fetchedTrips.filter { $0.status == .assigned || $0.status == .started }
            let activeVehicleIds = Set(activeTrips.map { $0.vehicleId })
            
            let assignedVehicles = fetchedVehicles.filter { activeVehicleIds.contains($0.id) }
            
            var locationMap: [UUID: DBVehicleLocation] = [:]
            do {
                let latestLocations = try await supabaseManager.fetchLatestVehicleLocations()
                let oneDayAgo = Date().addingTimeInterval(-86400)
                for loc in latestLocations {
                    if loc.timestamp > oneDayAgo && locationMap[loc.vehicleId] == nil {
                        locationMap[loc.vehicleId] = loc
                    }
                }
            } catch {
                throw error
            }
            
            self.mappedVehicles = assignedVehicles.map { vehicle in
                let coordinate: CLLocationCoordinate2D?
                let lastUpdated: Date?
                
                if let loc = locationMap[vehicle.id] {
                    coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
                    lastUpdated = loc.timestamp
                } else {
                    coordinate = nil
                    lastUpdated = nil
                }
                
                return MappedVehicle(
                    vehicle: vehicle,
                    coordinate: coordinate,
                    lastUpdated: lastUpdated
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
