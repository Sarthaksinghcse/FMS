






import Foundation
import SwiftData

@MainActor
struct DatabaseSeeder {
    static func seedIfEmpty(context: ModelContext) {
        // Seed inventory items first if needed
        seedInventory(context: context)
        
        do {
            let vehicleDescriptor = FetchDescriptor<Vehicle>()
            let existingVehicles = try context.fetch(vehicleDescriptor)
            
            let userDescriptor = FetchDescriptor<User>()
            let existingUsers = try context.fetch(userDescriptor)
            
            guard existingVehicles.isEmpty && existingUsers.isEmpty else {
                
                return
            }
        } catch {
            print("Failed to fetch database records for seeding check: \(error)")
            return
        }
        
        print(" Seeding SwiftData database with premium mock data...")
        
        
        let driver1 = User(
            id: UUID(uuidString: "d0000000-0000-0000-0000-000000000001")!,
            fullName: "Priyanshu Namdev",
            email: "priyanshu@fleet.com",
            phoneNumber: "+91 9999988888",
            passwordHash: "hashed",
            role: .driver,
            isActive: true
        )
        
        let driver2 = User(
            id: UUID(uuidString: "d0000000-0000-0000-0000-000000000002")!,
            fullName: "Amit Kumar",
            email: "amit@fleet.com",
            phoneNumber: "+91 8888877777",
            passwordHash: "hashed",
            role: .driver,
            isActive: true
        )
        
        let driver3 = User(
            id: UUID(uuidString: "d0000000-0000-0000-0000-000000000003")!,
            fullName: "Sarthak Singh",
            email: "sarthak@fleet.com",
            phoneNumber: "+91 7777766666",
            passwordHash: "hashed",
            role: .driver,
            isActive: false
        )
        
        let tech1 = User(
            id: UUID(uuidString: "d0000000-0000-0000-0000-000000000004")!,
            fullName: "Raj Kumar",
            email: "raj@fleet.com",
            phoneNumber: "+91 9876543210",
            passwordHash: "hashed",
            role: .maintenance,
            isActive: true
        )
        
        let tech2 = User(
            id: UUID(uuidString: "d0000000-0000-0000-0000-000000000005")!,
            fullName: "Naman Yadav",
            email: "naman@fleet.com",
            phoneNumber: "+91 8585858585",
            passwordHash: "hashed",
            role: .maintenance,
            isActive: true
        )
        
        [driver1, driver2, driver3, tech1, tech2].forEach { context.insert($0) }
        
        
        let v1 = Vehicle(
            id: UUID(uuidString: "e0000000-0000-0000-0000-000000000001")!,
            registrationNumber: "DL-01-MA-4532",
            vinNumber: "1HGCM82633A004352",
            make: "Tata",
            model: "Ace Gold",
            year: 2023,
            vehicleType: .truck,
            fuelType: .diesel,
            odometerReading: 45230.0,
            status: .active,
            assignedDriverId: driver1.id,
            lastServiceDate: Date().addingTimeInterval(-86400 * 60),
            nextServiceDate: Date().addingTimeInterval(86400 * 5),
            insuranceExpiryDate: Date().addingTimeInterval(-86400 * 3),
            permitExpiryDate: Date().addingTimeInterval(86400 * 45)
        )
        
        let v2 = Vehicle(
            id: UUID(uuidString: "e0000000-0000-0000-0000-000000000002")!,
            registrationNumber: "HR-26-CR-8921",
            vinNumber: "2HGCM82633A004353",
            make: "Maruti",
            model: "Eeco",
            year: 2022,
            vehicleType: .van,
            fuelType: .petrol,
            odometerReading: 32100.0,
            status: .active,
            assignedDriverId: driver2.id,
            lastServiceDate: Date().addingTimeInterval(-86400 * 30),
            nextServiceDate: Date().addingTimeInterval(86400 * 60),
            insuranceExpiryDate: Date().addingTimeInterval(86400 * 10),
            permitExpiryDate: Date().addingTimeInterval(-86400 * 7)
        )
        
        let v3 = Vehicle(
            id: UUID(uuidString: "e0000000-0000-0000-0000-000000000003")!,
            registrationNumber: "DL-03-EV-1024",
            vinNumber: "3HGCM82633A004354",
            make: "Tata",
            model: "Nexon EV",
            year: 2024,
            vehicleType: .car,
            fuelType: .electric,
            odometerReading: 12800.0,
            status: .inMaintenance,
            assignedDriverId: nil,
            lastServiceDate: Date().addingTimeInterval(-86400 * 90),
            nextServiceDate: Date().addingTimeInterval(-86400 * 10),
            insuranceExpiryDate: Date().addingTimeInterval(86400 * 120),
            permitExpiryDate: Date().addingTimeInterval(86400 * 12)
        )
        
        let v4 = Vehicle(
            id: UUID(uuidString: "e0000000-0000-0000-0000-000000000004")!,
            registrationNumber: "UP-16-PK-6721",
            vinNumber: "4HGCM82633A004355",
            make: "Mahindra",
            model: "Bolero Pickup",
            year: 2021,
            vehicleType: .truck,
            fuelType: .diesel,
            odometerReading: 78500.0,
            status: .inactive,
            assignedDriverId: nil,
            lastServiceDate: Date().addingTimeInterval(-86400 * 180),
            nextServiceDate: Date().addingTimeInterval(-86400 * 20),
            insuranceExpiryDate: Date().addingTimeInterval(-86400 * 15),
            permitExpiryDate: Date().addingTimeInterval(-86400 * 30)
        )
        
        let v5 = Vehicle(
            id: UUID(uuidString: "e0000000-0000-0000-0000-000000000005")!,
            registrationNumber: "DL-04-BI-7711",
            vinNumber: "5HGCM82633A004356",
            make: "Hero",
            model: "Splendor Plus",
            year: 2023,
            vehicleType: .bike,
            fuelType: .petrol,
            odometerReading: 8200.0,
            status: .active,
            assignedDriverId: driver3.id,
            lastServiceDate: Date().addingTimeInterval(-86400 * 15),
            nextServiceDate: Date().addingTimeInterval(86400 * 75),
            insuranceExpiryDate: Date().addingTimeInterval(86400 * 200),
            permitExpiryDate: Date().addingTimeInterval(86400 * 90)
        )
        
        let v6 = Vehicle(
            id: UUID(uuidString: "e0000000-0000-0000-0000-000000000006")!,
            registrationNumber: "MH-02-HY-3344",
            vinNumber: "6HGCM82633A004357",
            make: "Toyota",
            model: "Hyryder Hybrid",
            year: 2024,
            vehicleType: .car,
            fuelType: .hybrid,
            odometerReading: 5600.0,
            status: .active,
            assignedDriverId: nil,
            lastServiceDate: Date().addingTimeInterval(-86400 * 20),
            nextServiceDate: Date().addingTimeInterval(86400 * 8),
            insuranceExpiryDate: Date().addingTimeInterval(86400 * 6),
            permitExpiryDate: Date().addingTimeInterval(86400 * 180)
        )
        
        [v1, v2, v3, v4, v5, v6].forEach { context.insert($0) }
        
        
        let t1 = Trip(
            id: UUID(uuidString: "f0000000-0000-0000-0000-000000000184")!,
            tripCode: "TRIP-1842",
            vehicleId: v1.id,
            driverId: driver1.id,
            startLocation: "Okhla Phase 3",
            endLocation: "Nehru Place",
            startLatitude: 28.5422,
            startLongitude: 77.2721,
            endLatitude: 28.5492,
            endLongitude: 77.2519,
            scheduledStartTime: Date().addingTimeInterval(-3600),
            scheduledEndTime: Date().addingTimeInterval(1800),
            actualStartTime: Date().addingTimeInterval(-3400),
            distanceKm: 4.8,
            tripStatus: .inProgress,
            notes: "Routine courier run"
        )
        
        let t2 = Trip(
            id: UUID(uuidString: "f0000000-0000-0000-0000-000000000183")!,
            tripCode: "TRIP-1839",
            vehicleId: v2.id,
            driverId: driver2.id,
            startLocation: "Gurgaon Sec 21",
            endLocation: "Noida Sec 62",
            startLatitude: 28.5034,
            startLongitude: 77.0841,
            endLatitude: 28.6256,
            endLongitude: 77.3789,
            scheduledStartTime: Date().addingTimeInterval(-7200),
            scheduledEndTime: Date().addingTimeInterval(-3600),
            actualStartTime: Date().addingTimeInterval(-7100),
            actualEndTime: Date().addingTimeInterval(-3700),
            distanceKm: 38.5,
            tripStatus: .completed,
            notes: "Cargo delivery completed successfully"
        )
        
        [t1, t2].forEach { context.insert($0) }
        
        
        let defect1 = DefectReport(
            vehicleId: v3.id,
            reportedBy: driver1.id,
            inspectionId: UUID(),
            title: "Brake Squealing",
            defectDescription: "Front brake pads making loud squealing noise when braking at low speed.",
            severity: .high,
            status: .inProgress,
            createdAt: Date().addingTimeInterval(-86400)
        )
        
        let defect2 = DefectReport(
            vehicleId: v1.id,
            reportedBy: driver2.id,
            inspectionId: UUID(),
            title: "Tail Light Cracked",
            defectDescription: "Rear left indicator cover is cracked, bulb still functioning.",
            severity: .low,
            status: .open,
            createdAt: Date().addingTimeInterval(-3600 * 4)
        )
        
        [defect1, defect2].forEach { context.insert($0) }
        
        
        let sos1 = SOSAlert(
            driverId: driver1.id,
            vehicleId: v1.id,
            tripId: t1.id,
            latitude: 28.5450,
            longitude: 77.2600,
            message: "Engine heating light turned on. Stopping on the side of the road.",
            status: .active,
            createdAt: Date().addingTimeInterval(-900)
        )
        
        context.insert(sos1)
        
        
        let wo1 = WorkOrder(
            vehicleId: v3.id,
            defectReportId: defect1.id,
            assignedTo: tech1.id,
            title: "Brake Pad Replacement & Inspection",
            workDescription: "Replace front disc brake pads and check rotors for wear.",
            priority: .high,
            status: .inProgress,
            estimatedCost: 1500.0,
            createdAt: Date().addingTimeInterval(-43200)
        )
        
        context.insert(wo1)
        
        
        let record1 = MaintenanceRecord(
            vehicleId: v1.id,
            workOrderId: UUID(),
            serviceType: "Engine Oil & Filter Service",
            serviceDate: Date().addingTimeInterval(-86400 * 5),
            cost: 3200.0,
            notes: "Replaced oil with Shell Helix 5W-40. Replaced air and oil filters.",
            performedBy: tech2.id
        )
        
        let record2 = MaintenanceRecord(
            vehicleId: v2.id,
            workOrderId: UUID(),
            serviceType: "Tire Rotation & Wheel Alignment",
            serviceDate: Date().addingTimeInterval(-86400 * 12),
            cost: 1800.0,
            notes: "Rotated all 4 tires and calibrated laser wheel alignment.",
            performedBy: tech1.id
        )
        
        [record1, record2].forEach { context.insert($0) }
        
        do {
            try context.save()
            print(" Database successfully seeded with 6 vehicles, 5 users, 2 trips, 2 defects, 1 SOS, 1 work order, and 2 records.")
        } catch {
            print("Failed to save seeded context: \(error.localizedDescription)")
        }
    }
    
    private static func seedInventory(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<InventoryItem>()
            let existing = try context.fetch(descriptor)
            guard existing.isEmpty else { return }
            
            print(" Seeding SwiftData database with premium inventory data...")
            let items = [
                InventoryItem(
                    partName: "Front Brake Pads",
                    partNumber: "BP-F4102-T12",
                    quantityInStock: 3,
                    reorderThreshold: 5,
                    unitCost: 1200.0,
                    supplierName: "Bosch Automotive"
                ),
                InventoryItem(
                    partName: "Premium Oil Filter",
                    partNumber: "OF-P589-S1",
                    quantityInStock: 25,
                    reorderThreshold: 10,
                    unitCost: 450.0,
                    supplierName: "Mann+Hummel"
                ),
                InventoryItem(
                    partName: "H4 LED Headlight Bulb",
                    partNumber: "LB-H4LED-12V",
                    quantityInStock: 2,
                    reorderThreshold: 4,
                    unitCost: 850.0,
                    supplierName: "Philips Lighting"
                ),
                InventoryItem(
                    partName: "Engine Air Filter",
                    partNumber: "AF-E7881",
                    quantityInStock: 14,
                    reorderThreshold: 8,
                    unitCost: 650.0,
                    supplierName: "Mann+Hummel"
                ),
                InventoryItem(
                    partName: "All-Weather Wiper Blades",
                    partNumber: "WB-AW22-18",
                    quantityInStock: 12,
                    reorderThreshold: 6,
                    unitCost: 350.0,
                    supplierName: "Michelin Parts"
                )
            ]
            
            items.forEach { context.insert($0) }
            try context.save()
            print(" Seeding inventory completed successfully.")
        } catch {
            print("Failed to seed inventory items: \(error.localizedDescription)")
        }
    }
}
