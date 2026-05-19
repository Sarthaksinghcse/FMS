//
//  InspectionStatus.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//

import Foundation

enum InspectionStatus: String, Codable {
    case passed
    case failed
    case needsRepair = "needs_repair"
}

struct VehicleInspection: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var checklist: [String]
    var defects: String?
    var inspectionDate: Date
    var status: InspectionStatus
    
    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        driverId: UUID,
        checklist: [String],
        defects: String? = nil,
        inspectionDate: Date = Date(),
        status: InspectionStatus
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.checklist = checklist
        self.defects = defects
        self.inspectionDate = inspectionDate
        self.status = status
    }
}
