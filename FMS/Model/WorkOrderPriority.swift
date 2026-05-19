//
//  WorkOrderPriority.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//


import Foundation

enum WorkOrderPriority: String, Codable {
    case low
    case medium
    case high
    case urgent
}

enum WorkOrderStatus: String, Codable {
    case open
    case inProgress = "in_progress"
    case completed
    case closed
}

struct WorkOrder: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleId: UUID
    var createdBy: UUID
    var assignedTo: UUID
    var priority: WorkOrderPriority
    var issueDescription: String
    var status: WorkOrderStatus
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        createdBy: UUID,
        assignedTo: UUID,
        priority: WorkOrderPriority = .medium,
        issueDescription: String,
        status: WorkOrderStatus = .open,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.createdBy = createdBy
        self.assignedTo = assignedTo
        self.priority = priority
        self.issueDescription = issueDescription
        self.status = status
        self.createdAt = createdAt
    }
}
