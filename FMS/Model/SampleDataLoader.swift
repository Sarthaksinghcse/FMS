import Foundation
import SwiftData

@available(iOS 26.0, *)
struct SampleDataLoader {
    
    @MainActor
    static func seedData(context: ModelContext) {
        // Check if we already have users
        let userDescriptor = FetchDescriptor<User>()
        do {
            let existingUsers = try context.fetch(userDescriptor)
            if !existingUsers.isEmpty {
                // Already seeded
                return
            }
        } catch {
            print("Failed to fetch existing users: \(error)")
        }
        
        print("Seeding initial fleet database...")
        
        // 1. Seed Users
        let admin = User(
            fullName: "Admin Manager",
            email: "admin@fms.com",
            phoneNumber: "+1 (555) 019-0001",
            passwordHash: "admin123", // For mock purposes
            role: .fleetManager,
            isActive: true
        )
        
        let driver1 = User(
            fullName: "John Driver",
            email: "john@fms.com",
            phoneNumber: "+1 (555) 019-2831",
            passwordHash: "driver123",
            role: .driver,
            isActive: true
        )
        
        let driver2 = User(
            fullName: "Sarah Connor",
            email: "sarah@fms.com",
            phoneNumber: "+1 (555) 014-9821",
            passwordHash: "driver123",
            role: .driver,
            isActive: true
        )
        
        let mechanic1 = User(
            fullName: "Mike Mechanic",
            email: "mike@fms.com",
            phoneNumber: "+1 (555) 017-3849",
            passwordHash: "mech123",
            role: .maintenance,
            isActive: true
        )
        
        let mechanic2 = User(
            fullName: "Alex Tech",
            email: "alex@fms.com",
            phoneNumber: "+1 (555) 012-7384",
            passwordHash: "mech123",
            role: .maintenance,
            isActive: true
        )
        
        context.insert(admin)
        context.insert(driver1)
        context.insert(driver2)
        context.insert(mechanic1)
        context.insert(mechanic2)
        
        // Save to make IDs valid
        try? context.save()
        
        // 2. Seed Vehicles
        let vehicle1 = Vehicle(
            registrationNumber: "MH-12-AB-1234",
            vinNumber: "1FTBF2B60KKA12345",
            make: "Ford",
            model: "Transit 350",
            year: 2022,
            vehicleType: .truck,
            fuelType: .diesel,
            odometerReading: 45200.0,
            status: .active,
            assignedDriverId: driver1.id,
            lastServiceDate: Calendar.current.date(byAdding: .day, value: -40, to: Date()),
            nextServiceDate: Calendar.current.date(byAdding: .day, value: 50, to: Date()),
            insuranceExpiryDate: Calendar.current.date(byAdding: .day, value: 120, to: Date())
        )
        
        let vehicle2 = Vehicle(
            registrationNumber: "DL-3C-XY-5678",
            vinNumber: "5YJ3E1EA5LF500000",
            make: "Tesla",
            model: "Model Y",
            year: 2023,
            vehicleType: .car,
            fuelType: .electric,
            odometerReading: 12400.0,
            status: .inMaintenance,
            assignedDriverId: nil,
            lastServiceDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            nextServiceDate: Calendar.current.date(byAdding: .day, value: 85, to: Date()),
            insuranceExpiryDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) // Expired! (Compliance alert)
        )
        
        let vehicle3 = Vehicle(
            registrationNumber: "CA-88-GG-9999",
            vinNumber: "1FVACWDB2JH111111",
            make: "Freightliner",
            model: "M2 106",
            year: 2020,
            vehicleType: .truck,
            fuelType: .diesel,
            odometerReading: 154800.0,
            status: .active,
            assignedDriverId: driver2.id,
            lastServiceDate: Calendar.current.date(byAdding: .day, value: -120, to: Date()),
            nextServiceDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()), // Overdue service!
            insuranceExpiryDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())
        )
        
        context.insert(vehicle1)
        context.insert(vehicle2)
        context.insert(vehicle3)
        
        try? context.save()
        
        // 3. Seed Maintenance Records (for history charts)
        let record1 = MaintenanceRecord(
            vehicleId: vehicle1.id,
            serviceType: "Engine Oil & Filter",
            serviceDate: Calendar.current.date(byAdding: .day, value: -40, to: Date())!,
            cost: 150.00,
            notes: "Regular scheduled oil change. Filters replaced.",
            performedBy: mechanic1.id
        )
        
        let record2 = MaintenanceRecord(
            vehicleId: vehicle1.id,
            serviceType: "Brake Pads Replacement",
            serviceDate: Calendar.current.date(byAdding: .day, value: -90, to: Date())!,
            cost: 420.00,
            notes: "Front and rear brake pads replaced. Caliper serviced.",
            performedBy: mechanic1.id
        )
        
        let record3 = MaintenanceRecord(
            vehicleId: vehicle3.id,
            serviceType: "Transmission Service",
            serviceDate: Calendar.current.date(byAdding: .day, value: -120, to: Date())!,
            cost: 1250.00,
            notes: "Transmission fluid flush, filter change.",
            performedBy: mechanic2.id
        )
        
        let record4 = MaintenanceRecord(
            vehicleId: vehicle2.id,
            serviceType: "Tire Rotation & Balance",
            serviceDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            cost: 85.00,
            notes: "Rotated tires, checked alignment.",
            performedBy: mechanic2.id
        )
        
        context.insert(record1)
        context.insert(record2)
        context.insert(record3)
        context.insert(record4)
        
        // 4. Seed Work Orders (pending maintenance tasks)
        let order1 = WorkOrder(
            vehicleId: vehicle2.id,
            assignedTo: mechanic1.id,
            title: "Battery Health Check",
            workDescription: "Driver reports rapid discharge in sub-zero temps. Diagnostic scan required.",
            priority: .high,
            status: .inProgress,
            estimatedCost: 350.0
        )
        
        let order2 = WorkOrder(
            vehicleId: vehicle3.id,
            assignedTo: mechanic2.id,
            title: "Overdue Service PM",
            workDescription: "Annual complete system inspection and fluid change.",
            priority: .medium,
            status: .open,
            estimatedCost: 600.0
        )
        
        context.insert(order1)
        context.insert(order2)
        
        // 5. Seed Notifications
        let notif1 = AppNotification(
            userId: admin.id,
            title: "Insurance Expiry Alert",
            message: "Vehicle Tesla Model Y (DL-3C-XY-5678) insurance expired on \(formattedShortDate(Calendar.current.date(byAdding: .day, value: -10, to: Date())!)).",
            type: .maintenanceAlert,
            isRead: false
        )
        
        let notif2 = AppNotification(
            userId: admin.id,
            title: "Geofence Violation",
            message: "Vehicle Ford Transit (MH-12-AB-1234) breached boundary 'Warehouse Central'.",
            type: .general,
            isRead: false
        )
        
        let notif3 = AppNotification(
            userId: admin.id,
            title: "SOS Triggered",
            message: "Driver John Driver triggered SOS alert from Route 12.",
            type: .sosAlert,
            isRead: false
        )
        
        context.insert(notif1)
        context.insert(notif2)
        context.insert(notif3)
        
        // 6. Seed Inventory Items
        let item1 = InventoryItem(
            partName: "Synthethic Engine Oil 5W-30",
            partNumber: "OIL-5W30-1G",
            quantityInStock: 25,
            reorderThreshold: 8,
            unitCost: 32.50,
            supplierName: "Chevron Distributors"
        )
        
        let item2 = InventoryItem(
            partName: "Heavy Duty Brake Pads Set",
            partNumber: "BRK-HD-908",
            quantityInStock: 12,
            reorderThreshold: 4,
            unitCost: 85.00,
            supplierName: "Brembo Parts"
        )
        
        let item3 = InventoryItem(
            partName: "Tesla Cabin Air Filter",
            partNumber: "TSL-CAB-FIL",
            quantityInStock: 2, // Low stock alert!
            reorderThreshold: 5,
            unitCost: 22.00,
            supplierName: "EV Parts Direct"
        )
        
        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        
        // 7. Seed Trips
        let trip1 = Trip(
            tripCode: "TRIP-2026-001",
            vehicleId: vehicle1.id,
            driverId: driver1.id,
            startLocation: "Warehouse A (Oakland)",
            endLocation: "Retail Outlet 4 (San Jose)",
            startLatitude: 37.8044,
            startLongitude: -122.2712,
            endLatitude: 37.3382,
            endLongitude: -121.8863,
            scheduledStartTime: Date(),
            scheduledEndTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
            distanceKm: 68.5,
            tripStatus: .inProgress
        )
        
        let trip2 = Trip(
            tripCode: "TRIP-2026-002",
            vehicleId: vehicle3.id,
            driverId: driver2.id,
            startLocation: "Distribution Center (Sacramento)",
            endLocation: "Warehouse B (San Francisco)",
            startLatitude: 38.5816,
            startLongitude: -121.4944,
            endLatitude: 37.7749,
            endLongitude: -122.4194,
            scheduledStartTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
            scheduledEndTime: Calendar.current.date(byAdding: .hour, value: 7, to: Date())!,
            distanceKm: 140.0,
            tripStatus: .assigned
        )
        
        context.insert(trip1)
        context.insert(trip2)
        
        try? context.save()
        print("Fleet database seeded successfully!")
    }
    
    private static func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
