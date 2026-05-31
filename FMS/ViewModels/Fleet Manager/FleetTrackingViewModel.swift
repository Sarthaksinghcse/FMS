




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
    
    let hubCoordinate = CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020)
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
            
            self.mappedVehicles = fetchedVehicles.compactMap { vehicle in
                guard let realCoord = locationMap[vehicle.id] else {
                    return nil
                }
                return MappedVehicle(vehicle: vehicle, coordinate: realCoord)
            }
            if !isBackgroundRefresh {
                self.errorMessage = nil
            }
        } catch {
            if !isBackgroundRefresh {
                self.errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
            }
        }
        
        if !isBackgroundRefresh {
            isLoading = false
        }
    }
}
