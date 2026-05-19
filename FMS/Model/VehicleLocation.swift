//
//  VehicleLocation.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//
import Foundation
import CoreLocation

struct VehicleLocation: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleId: UUID
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        latitude: Double,
        longitude: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
}
