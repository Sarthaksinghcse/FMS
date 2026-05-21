//
//  UserRole.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//

import Foundation
import SwiftData

// MARK: - User Role

enum UserRole: String, Codable {
    case fleetManager
    case driver
    case maintenance
}

// MARK: - Vehicle Type

enum VehicleType: String, Codable {
    case truck
    case van
    case car
    case bike
}

// MARK: - Fuel Type

enum FuelType: String, Codable {
    case petrol
    case diesel
    case electric
    case hybrid
}

// MARK: - Vehicle Status

enum VehicleStatus: String, Codable {
    case active
    case inactive
    case inMaintenance
}

// MARK: - Trip Status

enum TripStatus: String, Codable {
    case assigned
    case started
    case inProgress
    case completed
    case cancelled
}

// MARK: - Inspection Type

enum InspectionType: String, Codable {
    case preTrip
    case postTrip
}

// MARK: - Defect Severity

enum DefectSeverity: String, Codable {
    case low
    case medium
    case high
}

// MARK: - Defect Status

enum DefectStatus: String, Codable {
    case open
    case inProgress
    case resolved
}

// MARK: - Work Order Priority

enum WorkOrderPriority: String, Codable {
    case low
    case medium
    case high
    case urgent
}

// MARK: - Work Order Status

enum WorkOrderStatus: String, Codable {
    case open
    case inProgress
    case completed
    case cancelled
}

// MARK: - SOS Status

enum SOSStatus: String, Codable {
    case active
    case resolved
}

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case tripAssigned
    case maintenanceAlert
    case defectAlert
    case sosAlert
    case general
}

// MARK: - User Model

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

// MARK: - Vehicle Model

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

// MARK: - Trip Model

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

// MARK: - Vehicle Inspection Model

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

// MARK: - Defect Report Model

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

// MARK: - Work Order Model

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

// MARK: - Maintenance Record Model

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

// MARK: - SOS Alert Model

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

// MARK: - Notification Model

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


// MARK: - Inventory Model

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
