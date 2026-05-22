//
//  DataModel.swift
//  FMS
//
//  Created by Naman Yadav on 21/05/26.
//

import Foundation
import SwiftData
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 1 ▸ Core Enums (Local / SwiftData)
// ─────────────────────────────────────────────────────────────────────────────

// MARK: User Role
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

// MARK: Vehicle Type
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
        case .truck: return AppTheme.Brand.royalBlue
        case .van:   return Color(red: 0.58, green: 0.39, blue: 0.87)
        case .car:   return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .bike:  return AppTheme.Brand.accent
        }
    }
}

// MARK: Fuel Type
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

// MARK: Vehicle Status
enum VehicleStatus: String, Codable {
    case active
    case inactive
    case inMaintenance

    var displayName: String {
        switch self {
        case .active:        return "Active"
        case .inactive:      return "Inactive"
        case .inMaintenance: return "Maintenance"
        }
    }
    var statusColor: Color {
        switch self {
        case .active:        return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .inactive:      return AppTheme.Brand.accent
        case .inMaintenance: return Color(red: 0.85, green: 0.25, blue: 0.25)
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

// MARK: Trip Status
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
        switch self {
        case .assigned:   return Color(red: 0.15, green: 0.38, blue: 0.90)
        case .started:    return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .inProgress: return AppTheme.Brand.accent
        case .completed:  return Color.gray
        case .cancelled:  return Color.red
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

// MARK: Inspection Type
enum InspectionType: String, Codable {
    case preTrip
    case postTrip
}

// MARK: Defect Severity
enum DefectSeverity: String, Codable {
    case low
    case medium
    case high
}

// MARK: Defect Status
enum DefectStatus: String, Codable {
    case open
    case inProgress
    case resolved
}

// MARK: Work Order Priority
enum WorkOrderPriority: String, Codable {
    case low
    case medium
    case high
    case urgent
}

// MARK: Work Order Status
enum WorkOrderStatus: String, Codable {
    case open
    case inProgress
    case completed
    case cancelled
}

// MARK: SOS Status
enum SOSStatus: String, Codable {
    case active
    case resolved
}

// MARK: Notification Type
enum NotificationType: String, Codable {
    case tripAssigned
    case maintenanceAlert
    case defectAlert
    case sosAlert
    case general
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 2 ▸ UI Filter Enums
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Vehicle Status Filter (for VehicleListView)
enum VehicleStatusFilter: String, CaseIterable, Identifiable {
    case all          = "All"
    case active       = "Active"
    case inactive     = "Inactive"
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
        case .all:           return AppTheme.Brand.royalBlue
        case .active:        return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .inactive:      return AppTheme.Brand.accent
        case .inMaintenance: return Color(red: 0.85, green: 0.25, blue: 0.25)
        }
    }
}

// MARK: Trip Status Filter (for TripListView)
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 3 ▸ Dashboard UI Models
// ─────────────────────────────────────────────────────────────────────────────

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
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 4 ▸ Tracking Model
// ─────────────────────────────────────────────────────────────────────────────

import MapKit

struct MappedVehicle: Identifiable, Hashable {
    let id = UUID()
    let vehicle: DBVehicle
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: MappedVehicle, rhs: MappedVehicle) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 5 ▸ Supabase DB Models (Codable structs matching schema)
// ─────────────────────────────────────────────────────────────────────────────

// MARK: DBUserRole
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
    /// Converts to the SwiftData `UserRole` used by local model views.
    var asLocalRole: UserRole {
        switch self {
        case .fleetManager: return .fleetManager
        case .driver:       return .driver
        case .maintenance:  return .maintenance
        }
    }
}

// MARK: DBUser
struct DBUser: Codable, Identifiable {
    let id: UUID
    var name: String
    let email: String
    var role: DBUserRole
    var phoneNumber: String?
    var profileImage: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case phoneNumber  = "phone_number"
        case profileImage = "profile_image"
        case createdAt    = "created_at"
    }

    /// Bridges to SwiftData `User` model used by local views.
    var asLocalUser: User {
        User(
            id: id,
            fullName: name,
            email: email,
            phoneNumber: phoneNumber ?? "",
            passwordHash: "",
            role: role.asLocalRole
        )
    }
}

// MARK: - User Mapping Extensions
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
            createdAt: createdAt
        )
    }
}

// MARK: DBVehicleStatus
enum DBVehicleStatus: String, Codable {
    case available
    case inUse        = "in_use"
    case maintenance
    case inactive
}

// MARK: DBVehicle
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
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleNumber    = "vehicle_number"
        case model
        case manufacturer
        case year
        case vin
        case licensePlate     = "license_plate"
        case status
        case assignedDriverId = "assigned_driver_id"
        case lastServiceDate  = "last_service_date"
        case createdAt        = "created_at"
    }
}

// MARK: - Vehicle Mapping Extensions
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
            vehicleType: .truck, // fallback/default
            fuelType: .petrol, // fallback/default
            odometerReading: 0.0,
            status: status.toLocalStatus,
            assignedDriverId: assignedDriverId,
            lastServiceDate: lastServiceDate,
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
            createdAt: createdAt
        )
    }
}

// MARK: DBTripStatus
enum DBTripStatus: String, Codable {
    case assigned
    case started
    case completed
    case cancelled
}

// MARK: DBTrip
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
}

// MARK: DBInspectionStatus
enum DBInspectionStatus: String, Codable {
    case passed
    case failed
    case needsRepair = "needs_repair"
}

// MARK: DBVehicleInspection
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 6 ▸ SwiftData @Model Classes
// ─────────────────────────────────────────────────────────────────────────────

// MARK: User Model
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

// MARK: Vehicle Model
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: Trip Model
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

// MARK: Vehicle Inspection Model
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

// MARK: Defect Report Model
@Model
final class DefectReport {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var reportedBy: UUID
    var inspectionId: UUID
    var title: String
    var defectDescription: String
    var severity: DefectSeverity
    var status: DefectStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        reportedBy: UUID,
        inspectionId: UUID,
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

// MARK: Work Order Model
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

// MARK: Maintenance Record Model
@Model
final class MaintenanceRecord {
    @Attribute(.unique) var id: UUID
    var vehicleId: UUID
    var workOrderId: UUID?
    var serviceType: String
    var serviceDate: Date
    var cost: Double
    var notes: String?
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
        self.performedBy = performedBy
        self.createdAt = createdAt
    }
}

// MARK: SOS Alert Model
@Model
final class SOSAlert {
    @Attribute(.unique) var id: UUID
    var driverId: UUID
    var vehicleId: UUID
    var tripId: UUID?
    var latitude: Double
    var longitude: Double
    var message: String?
    var status: SOSStatus
    var createdAt: Date

    init(
        id: UUID = UUID(),
        driverId: UUID,
        vehicleId: UUID,
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

// MARK: App Notification Model
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

// MARK: Inventory Item Model
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
