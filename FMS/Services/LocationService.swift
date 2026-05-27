






import Foundation
import CoreLocation
import Combine

public final class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    public static let shared = LocationService()
    
    private let manager = CLLocationManager()
    
    @Published public var lastLocation: CLLocation?
    
    
    public var isTrackingActive = false
    
    public var activeVehicleId: UUID?
    
    private var lastUploadTime: Date = Date.distantPast
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10.0 
        manager.requestWhenInUseAuthorization()
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }
    
    public func startTracking(vehicleId: UUID) {
        self.activeVehicleId = vehicleId
        self.isTrackingActive = true
        manager.startUpdatingLocation()
    }
    
    public func stopTracking() {
        self.isTrackingActive = false
        self.activeVehicleId = nil
        manager.stopUpdatingLocation()
    }
    
    
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastLocation = location
        
        
        guard isTrackingActive, let vehicleId = activeVehicleId else { return }
        let timeSinceLastUpload = Date().timeIntervalSince(lastUploadTime)
        guard timeSinceLastUpload >= 10.0 else { return }
        
        lastUploadTime = Date()
        
        let dbLocation = DBVehicleLocation(
            id: UUID(),
            vehicleId: vehicleId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date()
        )
        
        Task {
            do {
                try await SupabaseManager.shared.insertVehicleLocation(dbLocation)
                print("Uploaded live location coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            } catch {
                print("⚠️ Failed to upload vehicle location to Supabase: \(error.localizedDescription)")
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ CoreLocation Error: \(error.localizedDescription)")
    }
}
