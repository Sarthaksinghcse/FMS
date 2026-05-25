//
//  FleetDashboardViewModel.swift
//  FMS
//

import SwiftUI
import SwiftData

@Observable
final class FleetDashboardViewModel {
    var activeQuickAction: ActiveQuickAction? = nil
    
    enum ActiveQuickAction: Identifiable {
        case addVehicle
        case assignDriver
        case reports
        case alerts
        case maintenance
        
        var id: Self { self }
    }
    
    func getGreetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning, Manager"
        } else if hour < 17 {
            return "Good Afternoon, Manager"
        } else {
            return "Good Evening, Manager"
        }
    }
    
    func getFormattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    func getDynamicStats(vehicles: [Vehicle], allUsers: [User], trips: [Trip]) -> [DashboardStat] {
        let totalVehicles = vehicles.count
        let activeVehicles = vehicles.filter { $0.status == .active }.count
        let driversOnline = allUsers.filter { $0.role == .driver && $0.isActive }.count
        let liveTrips = trips.filter { $0.tripStatus == .inProgress || $0.tripStatus == .started }.count
        
        return [
            DashboardStat(
                icon: "car.fill",
                iconColor: AppTheme.Brand.primary,
                iconBgColor: AppTheme.IconBg.blue,
                value: "\(totalVehicles)",
                label: "Total Vehicles",
                trend: "",
                isTrendPositive: true,
                graphData: []
            ),
            DashboardStat(
                icon: "location.fill",
                iconColor: AppTheme.Status.success,
                iconBgColor: AppTheme.IconBg.green,
                value: "\(activeVehicles)",
                label: "Active Now",
                trend: "",
                isTrendPositive: true,
                graphData: []
            ),
            DashboardStat(
                icon: "person.2.fill",
                iconColor: AppTheme.Brand.violet,
                iconBgColor: AppTheme.IconBg.violet,
                value: "\(driversOnline)",
                label: "Drivers Online",
                trend: "",
                isTrendPositive: true,
                graphData: []
            ),
            DashboardStat(
                icon: "arrow.up.arrow.down",
                iconColor: AppTheme.Brand.teal,
                iconBgColor: AppTheme.IconBg.teal,
                value: "\(liveTrips)",
                label: "Live Trips",
                trend: "",
                isTrendPositive: false,
                graphData: []
            )
        ]
    }
    
    func getFleetUtilizationProgress(vehicles: [Vehicle]) -> Double {
        let totalVehiclesCount = vehicles.count
        let activeVehiclesCount = vehicles.filter { $0.status == .active }.count
        return totalVehiclesCount > 0 ? Double(activeVehiclesCount) / Double(totalVehiclesCount) : 0.0
    }
}
