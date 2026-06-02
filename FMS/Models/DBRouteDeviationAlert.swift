import Foundation
import CoreLocation

public struct DBRouteDeviationAlert: Identifiable, Codable {
    public let id: UUID
    public let driverId: UUID
    public let vehicleId: UUID
    public let latitude: Double
    public let longitude: Double
    public let deviationDistanceMeters: Double
    public let createdAt: Date
    public var status: AlertStatus
    
    public enum AlertStatus: String, Codable {
        case active
        case resolved
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case latitude
        case longitude
        case deviationDistanceMeters = "deviation_distance_meters"
        case createdAt = "created_at"
        case status
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
