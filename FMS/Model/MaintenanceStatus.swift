//
//  MaintenanceStatus.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//


import Foundation

enum MaintenanceStatus: String, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
}

struct MaintenanceTask: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleId: UUID
    var assignedTo: UUID
    var serviceType: String
    var dueDate: Date
    var status: MaintenanceStatus
    var notes: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        assignedTo: UUID,
        serviceType: String,
        dueDate: Date,
        status: MaintenanceStatus = .pending,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.assignedTo = assignedTo
        self.serviceType = serviceType
        self.dueDate = dueDate
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
    }
}
