//
//  LocationService.swift
//  FMS
//
//  Created on 22/05/26.
//

import Foundation
import CoreLocation
import Combine

public final class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    public static let shared = LocationService()
    
    private let manager = CLLocationManager()
    
    @Published public var lastLocation: CLLocation?
    
    /// Flag indicating whether we should stream location updates to Supabase
    public var isTrackingActive = false
    /// Assigned vehicle ID to stream coordinates for
    public var activeVehicleId: UUID?
    
    private var lastUploadTime: Date = Date.distantPast
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10.0 // trigger updates every 10 meters
        manager.requestAlwaysAuthorization()
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
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastLocation = location
        
        // Throttling: upload at most once every 10 seconds to avoid spamming the database
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
