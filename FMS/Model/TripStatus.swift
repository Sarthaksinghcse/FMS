//
//  TripStatus.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//

import Foundation

enum TripStatus: String, Codable {
    case assigned
    case started
    case completed
    case cancelled
}

struct Trip: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var source: String
    var destination: String
    var startTime: Date?
    var endTime: Date?
    var distance: Double
    var status: TripStatus
    var notes: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        vehicleId: UUID,
        driverId: UUID,
        source: String,
        destination: String,
        startTime: Date? = nil,
        endTime: Date? = nil,
        distance: Double = 0,
        status: TripStatus = .assigned,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.driverId = driverId
        self.source = source
        self.destination = destination
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
    }
}
