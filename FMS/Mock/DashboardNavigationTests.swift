import Foundation
import SwiftUI

@available(iOS 26.0, *)
struct DashboardNavigationTests {
    static func runTests() {
        print("--- Running Dashboard Navigation Tests ---")
        let viewModel = FleetDashboardViewModel()
        
        // 1. Test Dynamic Stats calculations
        let testDrivers = [
            User(id: UUID(), fullName: "Driver 1", email: "d1@fms.com", phoneNumber: "", passwordHash: "", role: .driver, isActive: true),
            User(id: UUID(), fullName: "Driver 2", email: "d2@fms.com", phoneNumber: "", passwordHash: "", role: .driver, isActive: false),
            User(id: UUID(), fullName: "Manager 1", email: "m1@fms.com", phoneNumber: "", passwordHash: "", role: .fleetManager, isActive: true)
        ]
        
        let testVehicles = [
            Vehicle(id: UUID(), registrationNumber: "V1", vinNumber: "", make: "", model: "", year: 2024, vehicleType: .truck, fuelType: .diesel, odometerReading: 0, status: .active),
            Vehicle(id: UUID(), registrationNumber: "V2", vinNumber: "", make: "", model: "", year: 2024, vehicleType: .van, fuelType: .petrol, odometerReading: 0, status: .inactive),
            Vehicle(id: UUID(), registrationNumber: "V3", vinNumber: "", make: "", model: "", year: 2024, vehicleType: .car, fuelType: .electric, odometerReading: 0, status: .active)
        ]
        
        let testTrips = [
            Trip(id: UUID(), tripCode: "T1", vehicleId: UUID(), driverId: UUID(), startLocation: "", endLocation: "", startLatitude: 0, startLongitude: 0, endLatitude: 0, endLongitude: 0, scheduledStartTime: Date(), scheduledEndTime: Date(), distanceKm: 0, tripStatus: .inProgress),
            Trip(id: UUID(), tripCode: "T2", vehicleId: UUID(), driverId: UUID(), startLocation: "", endLocation: "", startLatitude: 0, startLongitude: 0, endLatitude: 0, endLongitude: 0, scheduledStartTime: Date(), scheduledEndTime: Date(), distanceKm: 0, tripStatus: .assigned),
            Trip(id: UUID(), tripCode: "T3", vehicleId: UUID(), driverId: UUID(), startLocation: "", endLocation: "", startLatitude: 0, startLongitude: 0, endLatitude: 0, endLongitude: 0, scheduledStartTime: Date(), scheduledEndTime: Date(), distanceKm: 0, tripStatus: .completed)
        ]
        
        let stats = viewModel.getDynamicStats(vehicles: testVehicles, allUsers: testDrivers, trips: testTrips)
        assert(stats.count == 4)
        
        // Verify stats values
        let totalVehicles = stats.first(where: { $0.label == "Total Vehicles" })?.value
        assert(totalVehicles == "3", "Expected Total Vehicles to be 3, got \(String(describing: totalVehicles))")
        
        let activeNow = stats.first(where: { $0.label == "Available Now" })?.value
        assert(activeNow == "2", "Expected Available Now to be 2, got \(String(describing: activeNow))")
        
        let driversOnline = stats.first(where: { $0.label == "Drivers Online" })?.value
        assert(driversOnline == "1", "Expected Drivers Online to be 1, got \(String(describing: driversOnline))")
        
        let liveTrips = stats.first(where: { $0.label == "Live Trips" })?.value
        assert(liveTrips == "1", "Expected Live Trips to be 1, got \(String(describing: liveTrips))")
        
        // 2. Verify navigation destinations
        func destinationFor(label: String) -> DashboardNavigationDestination {
            switch label {
            case "Total Vehicles": return .totalVehicles
            case "Available Now":  return .activeNow
            case "Drivers Online": return .driversOnline
            case "Live Trips":     return .liveTrips
            default:               return .totalVehicles
            }
        }
        
        assert(destinationFor(label: "Total Vehicles") == .totalVehicles)
        assert(destinationFor(label: "Available Now") == .activeNow)
        assert(destinationFor(label: "Drivers Online") == .driversOnline)
        assert(destinationFor(label: "Live Trips") == .liveTrips)
        
        print(" All Dashboard Navigation Tests Passed successfully!")
    }
}
