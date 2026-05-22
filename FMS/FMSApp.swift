//
//  FMSApp.swift
//  FMS
//
//  Created by Sarthak Singh on 19/05/26.
//

import SwiftUI
import SwiftData

@main
@available(iOS 26.0, *)
struct FMSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            User.self,
            Vehicle.self,
            Trip.self,
            VehicleInspection.self,
            DefectReport.self,
            WorkOrder.self,
            MaintenanceRecord.self,
            SOSAlert.self,
            AppNotification.self,
            InventoryItem.self
        ])
    }
}
