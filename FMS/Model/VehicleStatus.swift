//
//  VehicleStatus.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//

import Foundation

enum VehicleStatus: String, Codable {
    case available
    case inUse = "in_use"
    case maintenance
    case inactive
}

struct Vehicle: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleNumber: String
    var model: String
    var manufacturer: String
    var year: Int
    var vin: String
    var licensePlate: String
    var status: VehicleStatus
    var assignedDriverId: UUID?
    var lastServiceDate: Date?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        vehicleNumber: String,
        model: String,
        manufacturer: String,
        year: Int,
        vin: String,
        licensePlate: String,
        status: VehicleStatus = .available,
        assignedDriverId: UUID? = nil,
        lastServiceDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleNumber = vehicleNumber
        self.model = model
        self.manufacturer = manufacturer
        self.year = year
        self.vin = vin
        self.licensePlate = licensePlate
        self.status = status
        self.assignedDriverId = assignedDriverId
        self.lastServiceDate = lastServiceDate
        self.createdAt = createdAt
    }
}
