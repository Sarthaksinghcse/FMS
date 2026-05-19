//
//  UserRole.swift
//  FMS
//
//  Created by Naman Yadav on 20/05/26.
//


import Foundation

enum UserRole: String, Codable {
    case fleetManager = "fleet_manager"
    case driver
    case maintenance
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String
    var role: UserRole
    var phoneNumber: String?
    var profileImage: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        role: UserRole,
        phoneNumber: String? = nil,
        profileImage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.phoneNumber = phoneNumber
        self.profileImage = profileImage
        self.createdAt = createdAt
    }
}
