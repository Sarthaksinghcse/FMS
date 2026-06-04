
import Foundation
import SwiftData
import SwiftUI

enum UserRole: String, Codable, CaseIterable {
    case fleetManager
    case driver
    case maintenance

    var displayName: String {
        switch self {
        case .fleetManager: return "Fleet Manager"
        case .driver: return "Driver"
        case .maintenance: return "Maintenance Personnel"
        }
    }

    static let allRoles: [UserRole] = [.fleetManager, .driver, .maintenance]
}


enum VehicleType: String, Codable, CaseIterable {
    case truck
    case van
    case car
    case bike

    public static var allCases: [VehicleType] { [.truck, .van, .car, .bike] }

    var displayName: String {
        switch self {
        case .truck: return "Truck"
        case .van:   return "Van"
        case .car:   return "Car"
        case .bike:  return "Bike"
        }
    }
    var icon: String {
        switch self {
        case .truck: return "truck.box.fill"
        case .van:   return "bus.fill"
        case .car:   return "car.fill"
        case .bike:  return "bicycle"
        }
    }
    var iconColor: Color {
        switch self {
        case .truck: return Theme.royalBlue
        case .van:   return Theme.royalBlue.opacity(0.70)
        case .car:   return Theme.royalBlue.opacity(0.85)
        case .bike:  return Theme.darkOrange
        }
    }
}


enum FuelType: String, Codable, CaseIterable {
    case petrol
    case diesel
    case electric
    case hybrid

    public static var allCases: [FuelType] { [.diesel, .petrol, .electric, .hybrid] }

    var displayName: String {
        switch self {
        case .petrol:   return "Petrol"
        case .diesel:   return "Diesel"
        case .electric: return "Electric"
        case .hybrid:   return "Hybrid"
        }
    }
    var icon: String {
        switch self {
        case .petrol, .diesel: return "fuelpump.fill"
        case .electric:        return "bolt.fill"
        case .hybrid:          return "leaf.fill"
        }
    }
}


enum VehicleStatus: String, Codable {
    case active
    case inactive
    case inMaintenance

    var displayName: String {
        switch self {
        case .active:        return "Available"
        case .inactive:      return "On Trip"
        case .inMaintenance: return "Maintenance"
        }
    }
    var statusColor: Color {
        if AccessibilityManager.shared.isHighContrastEnabled {
            return Color.primary
        }
        switch AccessibilityManager.shared.colorBlindMode {
        case .deuteranopia, .protanopia:
            switch self {
            case .active: return Color.blue
            case .inactive, .inMaintenance: return Color.orange
            }
        case .tritanopia:
            switch self {
            case .active: return Color.red
            case .inactive, .inMaintenance: return Color.teal
            }
        case .none:
            switch self {
            case .active:        return Theme.royalBlue
            case .inactive:      return Theme.darkOrange
            case .inMaintenance: return Theme.darkOrange.opacity(0.80)
            }
        }
    }
    var statusIcon: String {
        switch self {
        case .active:        return "checkmark.circle.fill"
        case .inactive:      return "pause.circle.fill"
        case .inMaintenance: return "wrench.and.screwdriver.fill"
        }
    }
}


enum TripStatus: String, Codable {
    case assigned
    case started
    case inProgress
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .assigned:   return "Assigned"
        case .started:    return "Started"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }
    var badgeColor: Color {
        if AccessibilityManager.shared.isHighContrastEnabled {
            return Color.primary
        }
        
        switch AccessibilityManager.shared.colorBlindMode {
        case .deuteranopia, .protanopia:
            switch self {
            case .assigned: return Color.blue.opacity(0.6)
            case .started, .inProgress: return Color.blue
            case .completed: return Color.blue.opacity(0.8)
            case .cancelled: return Color.orange
            }
        case .tritanopia:
            switch self {
            case .assigned: return Color.red.opacity(0.6)
            case .started, .inProgress: return Color.red
            case .completed: return Color.red.opacity(0.8)
            case .cancelled: return Color.teal
            }
        case .none:
            if AccessibilityManager.shared.fleetColorFilterStatus {
                switch self {
                case .assigned: return Color.blue.opacity(0.6)
                case .started, .inProgress: return Color.blue
                case .completed: return Color.blue.opacity(0.8)
                case .cancelled: return Color.orange
                }
            }
            switch self {
            case .assigned:   return Theme.royalBlue.opacity(0.60)
            case .started:    return Theme.royalBlue.opacity(0.85)
            case .inProgress: return Theme.royalBlue
            case .completed:  return Theme.royalBlue.opacity(0.75)
            case .cancelled:  return Theme.darkOrange
            }
        }
    }
    var badgeIcon: String {
        switch self {
        case .assigned:   return "person.badge.clock.fill"
        case .started:    return "play.circle.fill"
        case .inProgress: return "truck.box.fill"
        case .completed:  return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }
}


enum InspectionType: String, Codable {
    case preTrip
    case postTrip
}


enum DefectSeverity: String, Codable {
    case low
    case medium
    case high
}


enum DefectStatus: String, Codable {
    case open
    case inProgress
    case resolved
}


enum WorkOrderPriority: String, Codable {
    case low
    case medium
    case high
    case urgent
}


enum WorkOrderStatus: String, Codable {
    case open
    case inProgress
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .open:       return "Open"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }
}


enum SOSStatus: String, Codable {
    case active
    case resolved
}


enum NotificationType: String, Codable {
    case tripAssigned
    case maintenanceAlert
    case defectAlert
    case sosAlert
    case general
}


enum ComplianceAlertType: String, Codable, CaseIterable {
    case insurance
    case permit
    case servicing

    var displayName: String {
        switch self {
        case .insurance: return "Insurance"
        case .permit:    return "Permit"
        case .servicing: return "Servicing"
        }
    }

    var icon: String {
        switch self {
        case .insurance: return "shield.checkered"
        case .permit:    return "doc.text.fill"
        case .servicing: return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .insurance: return Theme.royalBlue
        case .permit:    return Theme.royalBlue.opacity(0.70)
        case .servicing: return Theme.darkOrange
        }
    }
}


enum ComplianceAlertStatus: String, Codable {
    case upcoming
    case overdue
    case resolved

    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .overdue:  return "Overdue"
        case .resolved: return "Resolved"
        }
    }

    var color: Color {
        switch self {
        case .upcoming: return Theme.darkOrange.opacity(0.70)
        case .overdue:  return Theme.darkOrange
        case .resolved: return Theme.royalBlue
        }
    }
}






enum VehicleStatusFilter: String, CaseIterable, Identifiable {
    case all          = "All"
    case active       = "Available"
    case inactive     = "On Trip"
    case inMaintenance = "In Maintenance"

    var id: String { rawValue }

    var vehicleStatus: VehicleStatus? {
        switch self {
        case .all:           return nil
        case .active:        return .active
        case .inactive:      return .inactive
        case .inMaintenance: return .inMaintenance
        }
    }
    var chipColor: Color {
        switch self {
        case .all:           return Theme.darkOrange
        case .active:        return Theme.royalBlue
        case .inactive:      return Theme.darkOrange.opacity(0.80)
        case .inMaintenance: return Theme.darkOrange
        }
    }
}


enum TripStatusFilter: String, CaseIterable, Identifiable {
    case all        = "All"
    case assigned   = "Assigned"
    case started    = "Started"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"

    var id: String { rawValue }

    var tripStatus: TripStatus? {
        switch self {
        case .all:        return nil
        case .assigned:   return .assigned
        case .started:    return .started
        case .inProgress: return .inProgress
        case .completed:  return .completed
        case .cancelled:  return .cancelled
        }
    }
}





struct DashboardStat: Identifiable {
    var id: String { label }
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    let value: String
    let label: String
    let trend: String
    let isTrendPositive: Bool
    let graphData: [Double]
}

struct DashboardQuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let bgColor: Color
    let label: String
}

struct DashboardActivity: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let time: String
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    /// Who triggered this event: "Fleet Manager", "Driver", or "System"
    let source: String
    /// Actual date for sorting
    let date: Date

    init(
        title: String,
        subtitle: String,
        time: String,
        icon: String,
        iconColor: Color,
        iconBgColor: Color,
        source: String = "System",
        date: Date = Date()
    ) {
        self.title      = title
        self.subtitle   = subtitle
        self.time       = time
        self.icon       = icon
        self.iconColor  = iconColor
        self.iconBgColor = iconBgColor
        self.source     = source
        self.date       = date
    }
}





import MapKit

struct MappedVehicle: Identifiable, Hashable {
    var id: UUID { vehicle.id }
    let vehicle: DBVehicle
    let coordinate: CLLocationCoordinate2D?
    let lastUpdated: Date?
    var trip: DBTrip?
    var driver: DBUser?

    static func == (lhs: MappedVehicle, rhs: MappedVehicle) -> Bool {
        lhs.id == rhs.id &&
        lhs.lastUpdated == rhs.lastUpdated &&
        lhs.coordinate?.latitude == rhs.coordinate?.latitude &&
        lhs.coordinate?.longitude == rhs.coordinate?.longitude
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(lastUpdated)
        hasher.combine(coordinate?.latitude)
        hasher.combine(coordinate?.longitude)
    }
    var statusColor: Color {
        switch vehicle.status {
        case .available:   return AppTheme.Status.success
        case .inUse:       return AppTheme.Brand.primary
        case .maintenance: return AppTheme.Status.warning
        case .inactive:    return AppTheme.Text.secondary
        }
    }
}






enum DBUserRole: String, Codable {
    case fleetManager = "fleet_manager"
    case driver       = "driver"
    case maintenance  = "maintenance"

    var displayName: String {
        switch self {
        case .fleetManager: return "Fleet Manager"
        case .driver:       return "Driver"
        case .maintenance:  return "Maintenance Personnel"
        }
    }
    
    var asLocalRole: UserRole {
        switch self {
        case .fleetManager: return .fleetManager
        case .driver:       return .driver
        case .maintenance:  return .maintenance
        }
    }
}


struct DBUser: Codable, Identifiable {
    let id: UUID
    var name: String
    let email: String
    var role: DBUserRole
    var phoneNumber: String?
    var profileImage: String?
    var isActive: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case phoneNumber  = "phone_number"
        case profileImage = "profile_image"
        case isActive     = "is_active"
        case createdAt    = "created_at"
    }

    
    var asLocalUser: User {
        User(
            id: id,
            fullName: name,
            email: email,
            phoneNumber: phoneNumber ?? "",
            passwordHash: "",
            role: role.asLocalRole,
            profileImageURL: profileImage,
            isActive: isActive
        )
    }
}


extension UserRole {
    var toDBUserRole: DBUserRole {
        switch self {
        case .fleetManager: return .fleetManager
        case .driver: return .driver
        case .maintenance: return .maintenance
        }
    }
}

extension User {
    var asDBUser: DBUser {
        DBUser(
            id: id,
            name: fullName,
            email: email,
            role: role.toDBUserRole,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            profileImage: profileImageURL,
            isActive: isActive,
            createdAt: createdAt
        )
    }
}


enum DBVehicleStatus: String, Codable {
    case available
    case inUse        = "in_use"
    case maintenance
    case inactive
}


struct DBVehicle: Codable, Identifiable {
    let id: UUID
    var vehicleNumber: String
    var model: String
    var manufacturer: String
    var year: Int
    var vin: String
    var licensePlate: String
    var status: DBVehicleStatus
    var assignedDriverId: UUID?
    var lastServiceDate: Date?
    var vehicleType: String?
    var fuelType: String?
    var odometerReading: Double?
    var insuranceExpiryDate: Date?
    var permitExpiryDate: Date?
    var nextServiceDate: Date?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleNumber       = "vehicle_number"
        case model
        case manufacturer
        case year
        case vin
        case licensePlate        = "license_plate"
        case status
        case assignedDriverId    = "assigned_driver_id"
        case lastServiceDate     = "last_service_date"
        case vehicleType         = "vehicle_type"
        case fuelType            = "fuel_type"
        case odometerReading     = "odometer_reading"
        case insuranceExpiryDate = "insurance_expiry_date"
        case permitExpiryDate    = "permit_expiry_date"
        case nextServiceDate     = "next_service_date"
        case createdAt           = "created_at"
    }
}


extension VehicleStatus {
    var toDBStatus: DBVehicleStatus {
        switch self {
        case .active: return .available
        case .inactive: return .inactive
        case .inMaintenance: return .maintenance
        }
    }
}

extension DBVehicleStatus {
    var toLocalStatus: VehicleStatus {
        switch self {
        case .available, .inUse: return .active
        case .inactive: return .inactive
        case .maintenance: return .inMaintenance
        }
    }
}

extension DBVehicle {
    var asLocalVehicle: Vehicle {
        Vehicle(
            id: id,
            registrationNumber: vehicleNumber,
            vinNumber: vin,
            make: manufacturer,
            model: model,
            year: year,
            vehicleType: VehicleType(rawValue: vehicleType ?? "") ?? .car, 
            fuelType: FuelType(rawValue: fuelType ?? "") ?? .petrol, 
            odometerReading: odometerReading ?? 0.0,
            status: status.toLocalStatus,
            assignedDriverId: assignedDriverId,
            lastServiceDate: lastServiceDate,
            nextServiceDate: nextServiceDate,
            insuranceExpiryDate: insuranceExpiryDate,
            permitExpiryDate: permitExpiryDate,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

extension Vehicle {
    var asDBVehicle: DBVehicle {
        DBVehicle(
            id: id,
            vehicleNumber: registrationNumber,
            model: model,
            manufacturer: make,
            year: year,
            vin: vinNumber,
            licensePlate: registrationNumber,
            status: status.toDBStatus,
            assignedDriverId: assignedDriverId,
            lastServiceDate: lastServiceDate,
            vehicleType: vehicleType.rawValue,
            fuelType: fuelType.rawValue,
            odometerReading: odometerReading,
            insuranceExpiryDate: insuranceExpiryDate,
            permitExpiryDate: permitExpiryDate,
            nextServiceDate: nextServiceDate,
            createdAt: createdAt
        )
    }
}

extension Trip {
    var asDBTrip: DBTrip {
        DBTrip(
            id: id,
            vehicleId: vehicleId,
            driverId: driverId,
            source: startLocation,
            destination: endLocation,
            startTime: scheduledStartTime,
            endTime: scheduledEndTime,
            distance: distanceKm,
            status: tripStatus.toDBStatus,
            notes: notes,
            createdAt: createdAt
        )
    }
}


extension TripStatus {
    var toDBStatus: DBTripStatus {
        switch self {
        case .assigned: return .assigned
        case .started, .inProgress: return .started
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }
}

extension DBTripStatus {
    var toLocalStatus: TripStatus {
        switch self {
        case .assigned: return .assigned
        case .started: return .started
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }
}

extension DBTrip {
    var asLocalTrip: Trip {
        Trip(
            id: id,
            tripCode: "TRP-\(id.uuidString.prefix(4).uppercased())",
            vehicleId: vehicleId,
            driverId: driverId,
            startLocation: source,
            endLocation: destination,
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            endLatitude: 37.3382,
            endLongitude: -121.8863,
            scheduledStartTime: startTime ?? Date(),
            scheduledEndTime: endTime ?? Date().addingTimeInterval(7200),
            actualStartTime: startTime,
            actualEndTime: endTime,
            distanceKm: distance,
            fuelConsumed: nil,
            tripStatus: status.toLocalStatus,
            notes: notes,
            createdAt: createdAt
        )
    }
}


enum DBTripStatus: String, Codable {
    case assigned
    case started
    case completed
    case cancelled
}


struct DBTrip: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var source: String
    var destination: String
    var startTime: Date?
    var endTime: Date?
    var distance: Double
    var status: DBTripStatus
    var notes: String?
    var createdAt: Date

    var tripCode: String {
        "TRP-\(id.uuidString.prefix(4).uppercased())"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId   = "vehicle_id"
        case driverId    = "driver_id"
        case source
        case destination
        case startTime   = "start_time"
        case endTime     = "end_time"
        case distance
        case status
        case notes
        case createdAt   = "created_at"
    }

    /// Provide a default tripCode when the backend column is absent
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        vehicleId   = try c.decode(UUID.self,   forKey: .vehicleId)
        driverId    = try c.decode(UUID.self,   forKey: .driverId)
        source      = try c.decode(String.self, forKey: .source)
        destination = try c.decode(String.self, forKey: .destination)
        startTime   = try c.decodeIfPresent(Date.self, forKey: .startTime)
        endTime     = try c.decodeIfPresent(Date.self, forKey: .endTime)
        distance    = try c.decode(Double.self, forKey: .distance)
        status      = try c.decode(DBTripStatus.self, forKey: .status)
        notes       = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt   = try c.decode(Date.self,   forKey: .createdAt)
    }

    /// Custom encoder — excludes tripCode so Supabase won't reject
    /// the payload when the trips table lacks a trip_code column.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        // tripCode is intentionally omitted — column may not exist in Supabase
        try c.encode(vehicleId,   forKey: .vehicleId)
        try c.encode(driverId,    forKey: .driverId)
        try c.encode(source,      forKey: .source)
        try c.encode(destination, forKey: .destination)
        try c.encodeIfPresent(startTime,  forKey: .startTime)
        try c.encodeIfPresent(endTime,    forKey: .endTime)
        try c.encode(distance,    forKey: .distance)
        try c.encode(status,      forKey: .status)
        try c.encodeIfPresent(notes,      forKey: .notes)
        try c.encode(createdAt,   forKey: .createdAt)
    }

    /// Memberwise init used throughout the app
    nonisolated init(
        id: UUID = UUID(),
        tripCode: String = "",
        vehicleId: UUID,
        driverId: UUID,
        source: String,
        destination: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        distance: Double,
        status: DBTripStatus,
        notes: String? = nil,
        createdAt: Date
    ) {
        self.id          = id
        self.vehicleId   = vehicleId
        self.driverId    = driverId
        self.source      = source
        self.destination = destination
        self.startTime   = startTime
        self.endTime     = endTime
        self.distance    = distance
        self.status      = status
        self.notes       = notes
        self.createdAt   = createdAt
    }
}


enum DBInspectionStatus: String, Codable {
    case passed
    case failed
    case needsRepair = "needs_repair"
}


struct DBVehicleInspection: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var checklist: [String]
    var defects: String?
    var inspectionDate: Date
    var status: DBInspectionStatus

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId      = "vehicle_id"
        case driverId       = "driver_id"
        case checklist
        case defects
        case inspectionDate = "inspection_date"
        case status
    }
}

extension DBVehicleInspection {
    var asLocalInspection: VehicleInspection {
        var brake = true
        var tire = true
        var engine = true
        var lights = true
        var oil = true
        
        for item in checklist {
            let parts = item.components(separatedBy: ": ")
            guard parts.count == 2 else { continue }
            let label = parts[0]
            let passed = parts[1] == "passed"
            
            if label.contains("Brakes") {
                brake = passed
            } else if label.contains("Tyres") {
                tire = passed
            } else if label.contains("Engine") {
                engine = passed
            } else if label.contains("Headlights") || label.contains("Indicators") {
                lights = passed
            } else if label.contains("Windshield") || label.contains("Wipers") {
                oil = passed
            }
        }
        
        return VehicleInspection(
            id: id,
            vehicleId: vehicleId,
            driverId: driverId,
            tripId: nil,
            inspectionType: .preTrip,
            brakeCondition: brake,
            tireCondition: tire,
            engineCondition: engine,
            lightsCondition: lights,
            oilLevelOk: oil,
            remarks: defects,
            defectReported: status == .failed,
            createdAt: inspectionDate
        )
    }
}

extension VehicleInspection {
    var asDBInspection: DBVehicleInspection {
        var checklistArray: [String] = []
        checklistArray.append("Brakes & Brake Lights: \(brakeCondition ? "passed" : "failed")")
        checklistArray.append("Tyres & Tyre Pressure: \(tireCondition ? "passed" : "failed")")
        checklistArray.append("Engine & Oil Level: \(engineCondition ? "passed" : "failed")")
        checklistArray.append("Headlights & Indicators: \(lightsCondition ? "passed" : "failed")")
        checklistArray.append("Windshield & Wipers: \(oilLevelOk ? "passed" : "failed")")
        checklistArray.append("Seat Belts: passed")
        checklistArray.append("Mirrors: passed")
        checklistArray.append("Horn: passed")
        checklistArray.append("First Aid Kit: passed")
        checklistArray.append("Documents & Permits: passed")
        
        return DBVehicleInspection(
            id: id,
            vehicleId: vehicleId,
            driverId: driverId,
            checklist: checklistArray,
            defects: remarks,
            inspectionDate: createdAt,
            status: defectReported ? .failed : .passed
        )
    }
}


enum DBMaintenanceStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
}


struct DBMaintenanceTask: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var assignedTo: UUID
    var serviceType: String
    var dueDate: Date
    var status: DBMaintenanceStatus
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case assignedTo = "assigned_to"
        case serviceType = "service_type"
        case dueDate = "due_date"
        case status
        case notes
        case createdAt = "created_at"
    }
}


enum DBWorkOrderPriority: String, Codable {
    case low
    case medium
    case high
    case urgent
}


enum DBWorkOrderStatus: String, Codable {
    case open
    case inProgress = "in_progress"
    case completed
    case closed
}


struct DBWorkOrder: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var createdBy: UUID
    var assignedTo: UUID
    var priority: DBWorkOrderPriority
    var issueDescription: String
    var status: DBWorkOrderStatus
    var estimatedCost: Double? = nil
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case createdBy = "created_by"
        case assignedTo = "assigned_to"
        case priority
        case issueDescription = "issue_description"
        case status
        case estimatedCost = "estimated_cost"
        case createdAt = "created_at"
    }
}


struct DBMessage: Codable, Identifiable {
    let id: UUID
    var senderId: UUID
    var receiverId: UUID
    var message: String
    var timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case message
        case timestamp
    }
}


enum DBNotificationType: String, Codable {
    case info
    case warning
    case maintenance
    case trip
    case emergency
    case general
    case defectAlert
    case maintenanceAlert
    case tripAssigned
    case sosAlert
}


struct DateParser {
    static func parse(_ dateStr: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateStr) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) {
            return date
        }
        
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSZZZZZ",
            "yyyy-MM-dd'T'HH:mm:ss.SZZZZZ",
            "yyyy-MM-dd HH:mm:ss.SSSSSS",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        for format in fallbackFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
}

struct DBNotification: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var title: String
    var message: String
    var type: DBNotificationType
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case message
        case type
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    init(id: UUID = UUID(), userId: UUID, title: String, message: String, type: DBNotificationType, isRead: Bool, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.title = title
        self.message = message
        self.type = type
        self.isRead = isRead
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.title = try container.decode(String.self, forKey: .title)
        self.message = try container.decode(String.self, forKey: .message)
        self.type = try container.decode(DBNotificationType.self, forKey: .type)
        self.isRead = try container.decode(Bool.self, forKey: .isRead)
        
        if let date = try? container.decode(Date.self, forKey: .createdAt) {
            self.createdAt = date
        } else {
            let dateStr = try container.decode(String.self, forKey: .createdAt)
            if let date = DateParser.parse(dateStr) {
                self.createdAt = date
            } else {
                throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid date format: \(dateStr)")
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(type, forKey: .type)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(createdAt, forKey: .createdAt)
    }
}


struct DBDefectReport: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var reportedBy: UUID
    var inspectionId: UUID?
    var title: String
    var defectDescription: String
    var severity: DefectSeverity
    var status: DefectStatus
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId         = "vehicle_id"
        case reportedBy        = "reported_by"
        case inspectionId      = "inspection_id"
        case title
        case defectDescription = "defect_description"
        case severity
        case status
        case createdAt         = "created_at"
    }
}


struct DBVehicleLocation: Codable, Identifiable, Hashable {
    let id: UUID
    let vehicleId: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case latitude, longitude, timestamp
    }
}



extension WorkOrder {
    @MainActor
    var asDBWorkOrder: DBWorkOrder {
        DBWorkOrder(
            id: id,
            vehicleId: vehicleId,
            createdBy: SupabaseManager.shared.currentUser?.id ?? UUID(),
            assignedTo: assignedTo,
            priority: priority.toDBPriority,
            issueDescription: workDescription.isEmpty ? title : workDescription,
            status: status.toDBStatus,
            estimatedCost: estimatedCost,
            createdAt: createdAt
        )
    }
}

extension WorkOrderPriority {
    var toDBPriority: DBWorkOrderPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .urgent
        }
    }
}

extension DBWorkOrderPriority {
    var toLocalPriority: WorkOrderPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .urgent: return .urgent
        }
    }
}

extension WorkOrderStatus {
    var toDBStatus: DBWorkOrderStatus {
        switch self {
        case .open: return .open
        case .inProgress: return .inProgress
        case .completed: return .completed
        case .cancelled: return .closed
        }
    }
}

extension DBWorkOrderStatus {
    var toLocalStatus: WorkOrderStatus {
        switch self {
        case .open: return .open
        case .inProgress: return .inProgress
        case .completed: return .completed
        case .closed: return .cancelled
        }
    }
}

extension DBWorkOrder {
    var asLocalWorkOrder: WorkOrder {
        WorkOrder(
            id: id,
            vehicleId: vehicleId,
            defectReportId: nil,
            assignedTo: assignedTo,
            title: "Work Order - " + String(id.uuidString.prefix(4)),
            workDescription: issueDescription,
            priority: priority.toLocalPriority,
            status: status.toLocalStatus,
            estimatedCost: estimatedCost,
            completedAt: status == .completed ? Date() : nil,
            createdAt: createdAt
        )
    }
}

extension DBNotificationType {
    var toLocalType: NotificationType {
        switch self {
        case .info, .general: return .general
        case .warning, .defectAlert: return .defectAlert
        case .maintenance, .maintenanceAlert: return .maintenanceAlert
        case .trip, .tripAssigned: return .tripAssigned
        case .emergency, .sosAlert: return .sosAlert
        }
    }
}

extension NotificationType {
    var toDBType: DBNotificationType {
        switch self {
        case .general: return .info
        case .defectAlert: return .warning
        case .maintenanceAlert: return .maintenance
        case .tripAssigned: return .trip
        case .sosAlert: return .emergency
        }
    }
}

extension DBNotification {
    var asLocalNotification: AppNotification {
        AppNotification(
            id: id,
            userId: userId,
            title: title,
            message: message,
            type: type.toLocalType,
            isRead: isRead,
            createdAt: createdAt
        )
    }
}

extension AppNotification {
    var asDBNotification: DBNotification {
        DBNotification(
            id: id,
            userId: userId,
            title: title,
            message: message,
            type: type.toDBType,
            isRead: isRead,
            createdAt: createdAt
        )
    }
}


extension DBDefectReport {
    var asLocalDefectReport: DefectReport {
        DefectReport(
            id: id,
            vehicleId: vehicleId,
            reportedBy: reportedBy,
            inspectionId: inspectionId,
            title: title,
            defectDescription: defectDescription,
            severity: severity,
            status: status,
            createdAt: createdAt
        )
    }
}

extension DefectReport {
    @MainActor
    var asDBDefectReport: DBDefectReport {
        DBDefectReport(
            id: id,
            vehicleId: vehicleId,
            reportedBy: reportedBy,
            inspectionId: inspectionId,
            title: title,
            defectDescription: defectDescription,
            severity: severity,
            status: status,
            createdAt: createdAt
        )
    }
}


enum DBSOSStatus: String, Codable {
    case active
    case resolved
}

struct DBSOSAlert: Codable, Identifiable {
    let id: UUID
    var driverId: UUID
    var vehicleId: UUID?
    var tripId: UUID?
    var latitude: Double
    var longitude: Double
    var message: String?
    var status: DBSOSStatus
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case latitude
        case longitude
        case message
        case status
        case createdAt = "created_at"
    }
}

extension SOSStatus {
    var toDBStatus: DBSOSStatus {
        switch self {
        case .active: return .active
        case .resolved: return .resolved
        }
    }
}

extension DBSOSStatus {
    var toLocalStatus: SOSStatus {
        switch self {
        case .active: return .active
        case .resolved: return .resolved
        }
    }
}

extension DBSOSAlert {
    var asLocalSOS: SOSAlert {
        SOSAlert(
            id: id,
            driverId: driverId,
            vehicleId: vehicleId,
            tripId: tripId,
            latitude: latitude,
            longitude: longitude,
            message: message,
            status: status.toLocalStatus,
            createdAt: createdAt
        )
    }
}

extension SOSAlert {
    var asDBSOSAlert: DBSOSAlert {
        DBSOSAlert(
            id: id,
            driverId: driverId,
            vehicleId: vehicleId,
            tripId: tripId,
            latitude: latitude,
            longitude: longitude,
            message: message,
            status: status.toDBStatus,
            createdAt: createdAt
        )
    }
}

struct DBInventoryItem: Codable, Identifiable {
    let id: UUID
    var partName: String
    var partNumber: String
    var quantityInStock: Int
    var reorderThreshold: Int
    var unitCost: Double
    var supplierName: String?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case partName = "part_name"
        case partNumber = "part_number"
        case quantityInStock = "quantity_in_stock"
        case reorderThreshold = "reorder_threshold"
        case unitCost = "unit_cost"
        case supplierName = "supplier_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension DBInventoryItem {
    var asLocalItem: InventoryItem {
        InventoryItem(
            id: id,
            partName: partName,
            partNumber: partNumber,
            quantityInStock: quantityInStock,
            reorderThreshold: reorderThreshold,
            unitCost: unitCost,
            supplierName: supplierName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension InventoryItem {
    var asDBItem: DBInventoryItem {
        DBInventoryItem(
            id: id,
            partName: partName,
            partNumber: partNumber,
            quantityInStock: quantityInStock,
            reorderThreshold: reorderThreshold,
            unitCost: unitCost,
            supplierName: supplierName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct DBMaintenanceRecord: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var workOrderId: UUID?
    var serviceType: String
    var serviceDate: Date
    var cost: Double
    var notes: String?
    var repairImages: [String]?
    var performedBy: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        workOrderId: UUID? = nil,
        serviceType: String,
        serviceDate: Date = Date(),
        cost: Double,
        notes: String? = nil,
        repairImages: [String]? = nil,
        performedBy: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.workOrderId = workOrderId
        self.serviceType = serviceType
        self.serviceDate = serviceDate
        self.cost = cost
        self.notes = notes
        self.repairImages = repairImages
        self.performedBy = performedBy
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case workOrderId = "work_order_id"
        case serviceType = "service_type"
        case serviceDate = "service_date"
        case cost
        case notes
        case repairImages = "repair_images"
        case performedBy = "performed_by"
        case createdAt = "created_at"
    }
}

extension DBMaintenanceRecord {
    var asLocalRecord: MaintenanceRecord {
        MaintenanceRecord(
            id: id,
            vehicleId: vehicleId,
            workOrderId: workOrderId,
            serviceType: serviceType,
            serviceDate: serviceDate,
            cost: cost,
            notes: notes,
            repairImages: repairImages,
            performedBy: performedBy,
            createdAt: createdAt
        )
    }
}

extension MaintenanceRecord {
    var asDBRecord: DBMaintenanceRecord {
        DBMaintenanceRecord(
            id: id,
            vehicleId: vehicleId,
            workOrderId: workOrderId,
            serviceType: serviceType,
            serviceDate: serviceDate,
            cost: cost,
            notes: notes,
            repairImages: repairImages,
            performedBy: performedBy,
            createdAt: createdAt
        )
    }
}


@Model
final class User {
    @Attribute(.unique) var id: UUID
    var fullName: String
    var email: String
    var phoneNumber: String
    var passwordHash: String
    var role: UserRole
    var profileImageURL: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String,
        email: String,
        phoneNumber: String,
        passwordHash: String,
        role: UserRole,
        profileImageURL: String? = nil,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phoneNumber = phoneNumber
        self.passwordHash = passwordHash
        self.role = role
        self.profileImageURL = profileImageURL
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


@Model
final class Vehicle {
    @Attribute(.unique) var id: UUID
    var registrationNumber: String
    var vinNumber: String
    var make: String
    var model: String
    var year: Int
    var vehicleType: VehicleType
    var fuelType: FuelType
    var odometerReading: Double
    var status: VehicleStatus
    var assignedDriverId: UUID?
    var lastServiceDate: Date?
    var nextServiceDate: Date?
    var insuranceExpiryDate: Date?
    var permitExpiryDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        registrationNumber: String,
        vinNumber: String,
        make: String,
        model: String,
        year: Int,
        vehicleType: VehicleType,
        fuelType: FuelType,
        odometerReading: Double,
        status: VehicleStatus = .active,
        assignedDriverId: UUID? = nil,
        lastServiceDate: Date? = nil,
        nextServiceDate: Date? = nil,
        insuranceExpiryDate: Date? = nil,
        permitExpiryDate: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.registrationNumber = registrationNumber
        self.vinNumber = vinNumber
        self.make = make
        self.model = model
        self.year = year
        self.vehicleType = vehicleType
        self.fuelType = fuelType
        self.odometerReading = odometerReading
        self.status = status
        self.assignedDriverId = assignedDriverId
        self.lastServiceDate = lastServiceDate
        self.nextServiceDate = nextServiceDate
        self.insuranceExpiryDate = insuranceExpiryDate
        self.permitExpiryDate = permitExpiryDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var tripCode: String
    var vehicleId: UUID
    var driverId: UUID
    var startLocation: String
    var endLocation: String
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double
    var endLongitude: Double
    var scheduledStartTime: Date
    var scheduledEndTime: Date
    var actualStartTime: Date?
    var actualEndTime: Date?
    var distanceKm: Double
    var fuelConsumed: Double?
    var tripStatus: TripStatus
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        tripCode: String,
        vehicleId: UUID,
        driverId: UUID,
        startLocation: String,
        endLocation: String,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        scheduledStartTime: Date,
        scheduledEndTime: Date,
        actualStartTime: Date? = nil,
        actualEndTime: Date? = nil,
        distanceKm: Double,
        fuelConsumed: Double? = nil,
        tripStatus: TripStatus = .assigned,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.tripCode = tripCode
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.startLocation = startLocation
        self.endLocation = endLocation
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.scheduledStartTime = scheduledStartTime
        self.scheduledEndTime = scheduledEndTime
        self.actualStartTime = actualStartTime
        self.actualEndTime = actualEndTime
        self.distanceKm = distanceKm
        self.fuelConsumed = fuelConsumed
        self.tripStatus = tripStatus
        self.notes = notes
        self.createdAt = createdAt
    }
}


@Model
final class VehicleInspection {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var tripId: UUID?
    var inspectionType: InspectionType
    var brakeCondition: Bool
    var tireCondition: Bool
    var engineCondition: Bool
    var lightsCondition: Bool
    var oilLevelOk: Bool
    var remarks: String?
    var defectReported: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        driverId: UUID,
        tripId: UUID? = nil,
        inspectionType: InspectionType,
        brakeCondition: Bool,
        tireCondition: Bool,
        engineCondition: Bool,
        lightsCondition: Bool,
        oilLevelOk: Bool,
        remarks: String? = nil,
        defectReported: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.tripId = tripId
        self.inspectionType = inspectionType
        self.brakeCondition = brakeCondition
        self.tireCondition = tireCondition
        self.engineCondition = engineCondition
        self.lightsCondition = lightsCondition
        self.oilLevelOk = oilLevelOk
        self.remarks = remarks
        self.defectReported = defectReported
        self.createdAt = createdAt
    }
}


@Model
final class DefectReport {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var reportedBy: UUID
    var inspectionId: UUID?
    var title: String
    var defectDescription: String
    var severity: DefectSeverity
    var status: DefectStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        reportedBy: UUID,
        inspectionId: UUID? = nil,
        title: String,
        defectDescription: String,
        severity: DefectSeverity,
        status: DefectStatus = .open,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.reportedBy = reportedBy
        self.inspectionId = inspectionId
        self.title = title
        self.defectDescription = defectDescription
        self.severity = severity
        self.status = status
        self.createdAt = createdAt
    }
}


@Model
final class WorkOrder {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var defectReportId: UUID?
    var assignedTo: UUID
    var title: String
    var workDescription: String
    var priority: WorkOrderPriority
    var status: WorkOrderStatus
    var estimatedCost: Double?
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        defectReportId: UUID? = nil,
        assignedTo: UUID,
        title: String,
        workDescription: String,
        priority: WorkOrderPriority,
        status: WorkOrderStatus = .open,
        estimatedCost: Double? = nil,
        completedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.defectReportId = defectReportId
        self.assignedTo = assignedTo
        self.title = title
        self.workDescription = workDescription
        self.priority = priority
        self.status = status
        self.estimatedCost = estimatedCost
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}


@Model
final class MaintenanceRecord {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var workOrderId: UUID?
    var serviceType: String
    var serviceDate: Date
    var cost: Double
    var notes: String?
    var repairImages: [String]?
    var replacedParts: [String]
    var performedBy: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        workOrderId: UUID? = nil,
        serviceType: String,
        serviceDate: Date,
        cost: Double,
        notes: String? = nil,
        repairImages: [String]? = nil,
        replacedParts: [String] = [],
        performedBy: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.workOrderId = workOrderId
        self.serviceType = serviceType
        self.serviceDate = serviceDate
        self.cost = cost
        self.notes = notes
        self.repairImages = repairImages
        self.replacedParts = replacedParts
        self.performedBy = performedBy
        self.createdAt = createdAt
    }
}


@Model
final class SOSAlert {
    @Attribute(.unique) var id: UUID
    var driverId: UUID
    var vehicleId: UUID?
    var tripId: UUID?
    var latitude: Double
    var longitude: Double
    var message: String?
    var status: SOSStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        driverId: UUID,
        vehicleId: UUID? = nil,
        tripId: UUID? = nil,
        latitude: Double,
        longitude: Double,
        message: String? = nil,
        status: SOSStatus = .active,
        createdAt: Date = .now
    ) {
        self.id = id
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.latitude = latitude
        self.longitude = longitude
        self.message = message
        self.status = status
        self.createdAt = createdAt
    }
}


@Model
final class AppNotification {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var title: String
    var message: String
    var type: NotificationType
    var isRead: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        message: String,
        type: NotificationType,
        isRead: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.message = message
        self.type = type
        self.isRead = isRead
        self.createdAt = createdAt
    }
}


@Model
final class InventoryItem {
    @Attribute(.unique) var id: UUID
    var partName: String
    var partNumber: String
    var quantityInStock: Int
    var reorderThreshold: Int
    var unitCost: Double
    var supplierName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        partName: String,
        partNumber: String,
        quantityInStock: Int,
        reorderThreshold: Int,
        unitCost: Double,
        supplierName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.partName = partName
        self.partNumber = partNumber
        self.quantityInStock = quantityInStock
        self.reorderThreshold = reorderThreshold
        self.unitCost = unitCost
        self.supplierName = supplierName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}


// MARK: - Fuel Log

/// Local SwiftData model – persisted on device
@Model
final class FuelLog {
    @Attribute(.unique) var id: UUID
    var driverId: UUID
    var vehicleId: UUID?
    var tripId: UUID?
    var fuelType: String          // "petrol" | "diesel" | "electric" | "hybrid"
    var litres: Double            // quantity filled
    var amountPaid: Double        // cost in local currency
    var odometer: Double?
    var receiptImageData: Data?   // local receipt photo cache
    var notes: String?
    var loggedAt: Date

    init(
        id: UUID = UUID(),
        driverId: UUID,
        vehicleId: UUID? = nil,
        tripId: UUID? = nil,
        fuelType: String = "petrol",
        litres: Double,
        amountPaid: Double,
        odometer: Double? = nil,
        receiptImageData: Data? = nil,
        notes: String? = nil,
        loggedAt: Date = .now
    ) {
        self.id = id
        self.driverId = driverId
        self.vehicleId = vehicleId
        self.tripId = tripId
        self.fuelType = fuelType
        self.litres = litres
        self.amountPaid = amountPaid
        self.odometer = odometer
        self.receiptImageData = receiptImageData
        self.notes = notes
        self.loggedAt = loggedAt
    }
}


@Model
final class ComplianceAlert {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var alertType: ComplianceAlertType
    var status: ComplianceAlertStatus
    var deadlineDate: Date
    var resolvedAt: Date?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        alertType: ComplianceAlertType,
        status: ComplianceAlertStatus,
        deadlineDate: Date,
        resolvedAt: Date? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.alertType = alertType
        self.status = status
        self.deadlineDate = deadlineDate
        self.resolvedAt = resolvedAt
        self.notes = notes
        self.createdAt = createdAt
    }
}


// MARK: - Fuel Log DB Mappings
struct DBFuelLog: Codable, Identifiable {
    let id: UUID
    var driverId: UUID
    var vehicleId: UUID?
    var tripId: UUID?
    var fuelType: String
    var litres: Double
    var amountPaid: Double
    var odometer: Double?
    var receiptUrl: String?
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case driverId   = "driver_id"
        case vehicleId  = "vehicle_id"
        case tripId     = "trip_id"
        case fuelType   = "fuel_type"
        case litres
        case amountPaid = "amount_paid"
        case odometer
        case receiptUrl = "receipt_url"
        case notes
        case createdAt  = "created_at"
    }

    var asLocalLog: FuelLog {
        FuelLog(
            id: id,
            driverId: driverId,
            vehicleId: vehicleId,
            tripId: tripId,
            fuelType: fuelType,
            litres: litres,
            amountPaid: amountPaid,
            odometer: odometer,
            receiptImageData: nil,
            notes: notes,
            loggedAt: createdAt
        )
    }
}

extension FuelLog {
    var asDBLog: DBFuelLog {
        DBFuelLog(
            id: id,
            driverId: driverId,
            vehicleId: vehicleId,
            tripId: tripId,
            fuelType: fuelType,
            litres: litres,
            amountPaid: amountPaid,
            odometer: odometer,
            receiptUrl: nil,
            notes: notes,
            createdAt: loggedAt
        )
    }
}


// MARK: - Compliance Alert DB Mappings
struct DBComplianceAlert: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var alertType: String
    var status: String
    var deadlineDate: Date
    var resolvedAt: Date?
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case alertType = "alert_type"
        case status
        case deadlineDate = "deadline_date"
        case resolvedAt = "resolved_at"
        case notes
        case createdAt = "created_at"
    }

    var asLocalAlert: ComplianceAlert {
        ComplianceAlert(
            id: id,
            vehicleId: vehicleId,
            alertType: ComplianceAlertType(rawValue: alertType) ?? .insurance,
            status: ComplianceAlertStatus(rawValue: status) ?? .upcoming,
            deadlineDate: deadlineDate,
            resolvedAt: resolvedAt,
            notes: notes,
            createdAt: createdAt
        )
    }
}

extension ComplianceAlert {
    var asDBAlert: DBComplianceAlert {
        DBComplianceAlert(
            id: id,
            vehicleId: vehicleId,
            alertType: alertType.rawValue,
            status: status.rawValue,
            deadlineDate: deadlineDate,
            resolvedAt: resolvedAt,
            notes: notes,
            createdAt: createdAt
        )
    }
}

// MARK: - AI Feature Models

struct DBPredictiveAlert: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var riskLevel: String           // "low" | "medium" | "high" | "critical"
    var riskScore: Double
    var triggeredReasons: [String]?
    var suggestedAction: String?
    var llmExplanation: String?
    var createdAt: Date
    var resolvedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId       = "vehicle_id"
        case riskLevel       = "risk_level"
        case riskScore       = "risk_score"
        case triggeredReasons = "triggered_reasons"
        case suggestedAction = "suggested_action"
        case llmExplanation  = "llm_explanation"
        case createdAt       = "created_at"
        case resolvedAt      = "resolved_at"
    }
}

struct DBVehicleHealthScore: Codable, Identifiable {
    let id: UUID
    var vehicleId: UUID
    var healthScore: Int
    var healthGrade: String          // "excellent" | "good" | "fair" | "poor" | "critical"
    var issueFlags: [String]?
    var suggestedTasks: [String]?
    var llmSummary: String?
    var analyzedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId       = "vehicle_id"
        case healthScore     = "health_score"
        case healthGrade     = "health_grade"
        case issueFlags      = "issue_flags"
        case suggestedTasks  = "suggested_tasks"
        case llmSummary      = "llm_summary"
        case analyzedAt      = "analyzed_at"
    }
}



struct AIAnalyticsReport: Codable, Identifiable {
    let id: UUID
    let reportText: String
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reportText  = "report_text"
        case generatedAt = "generated_at"
    }
}


// MARK: - Trip Log (Voice Log Persistence)

struct DBTripLog: Codable, Identifiable {
    let id: UUID
    var driverId: UUID
    var tripId: UUID?
    var transcript: String
    var startLocation: String?
    var endLocation: String?
    var startTime: String?
    var endTime: String?
    var mileage: Double?
    var createdAt: Date
    var isEdited: Bool?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case driverId       = "driver_id"
        case tripId         = "trip_id"
        case transcript
        case startLocation  = "start_location"
        case endLocation    = "end_location"
        case startTime      = "start_time"
        case endTime        = "end_time"
        case mileage
        case createdAt      = "created_at"
        case isEdited       = "is_edited"
        case updatedAt      = "updated_at"
    }
}
