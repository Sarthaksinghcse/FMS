//
//  NotificationType.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//

import Foundation

enum NotificationType: String, Codable {
    case info
    case warning
    case maintenance
    case trip
    case emergency
}

struct AppNotification: Identifiable, Codable, Hashable {
    let id: UUID
    var userId: UUID
    var title: String
    var message: String
    var type: NotificationType
    var createdAt: Date
    var isRead: Bool
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        message: String,
        type: NotificationType,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.message = message
        self.type = type
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
