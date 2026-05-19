//
//  Message.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//


import Foundation

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    var senderId: UUID
    var receiverId: UUID
    var message: String
    var timestamp: Date
    
    init(
        id: UUID = UUID(),
        senderId: UUID,
        receiverId: UUID,
        message: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.message = message
        self.timestamp = timestamp
    }
}
