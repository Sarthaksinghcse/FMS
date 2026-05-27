






import SwiftUI
import SwiftData
import Combine


@MainActor
final class MaintenanceManagementViewModel: ObservableObject {
    @Published var errorMessage: String? = nil
    
    
    @Published var newTitle: String = ""
    @Published var newDescription: String = ""
    @Published var selectedVehicleId: UUID? = nil
    @Published var selectedStaffId: UUID? = nil
    @Published var selectedPriority: WorkOrderPriority = .medium
    @Published var estimatedCostString: String = ""
    
    func resetForm() {
        newTitle = ""
        newDescription = ""
        selectedVehicleId = nil
        selectedStaffId = nil
        selectedPriority = .medium
        estimatedCostString = ""
        errorMessage = nil
    }
    
    
    
    
    func scheduleWorkOrder(context: ModelContext, vehicles: [Vehicle], staff: [User]) -> Bool {
        errorMessage = nil
        
        let cleanedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDesc = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let vehicleId = selectedVehicleId else {
            errorMessage = "Please select a vehicle."
            return false
        }
        
        guard let staffId = selectedStaffId else {
            errorMessage = "Please assign a maintenance staff member."
            return false
        }
        
        guard !cleanedTitle.isEmpty else {
            errorMessage = "Please enter a work order title."
            return false
        }
        
        guard let selectedVehicle = vehicles.first(where: { $0.id == vehicleId }) else {
            errorMessage = "Selected vehicle not found."
            return false
        }
        
        guard staff.contains(where: { $0.id == staffId }) else {
            errorMessage = "Selected staff member not found."
            return false
        }
        
        let estCost = Double(estimatedCostString)
        if !estimatedCostString.isEmpty && estCost == nil {
            errorMessage = "Please enter a valid estimated cost."
            return false
        }
        
        
        let workOrder = WorkOrder(
            vehicleId: vehicleId,
            assignedTo: staffId,
            title: cleanedTitle,
            workDescription: cleanedDesc,
            priority: selectedPriority,
            status: .open,
            estimatedCost: estCost
        )
        
        
        selectedVehicle.status = .inMaintenance
        selectedVehicle.updatedAt = Date()
        
        context.insert(workOrder)
        
        do {
            try context.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            
            let dbWorkOrder = workOrder.asDBWorkOrder
            Task {
                do {
                    try await SupabaseManager.shared.createWorkOrder(dbWorkOrder)
                    
                    let dbVehicle = DBVehicle(
                        id: selectedVehicle.id,
                        vehicleNumber: selectedVehicle.registrationNumber,
                        model: selectedVehicle.model,
                        manufacturer: selectedVehicle.make,
                        year: selectedVehicle.year,
                        vin: selectedVehicle.vinNumber,
                        licensePlate: selectedVehicle.registrationNumber,
                        status: .maintenance,
                        assignedDriverId: selectedVehicle.assignedDriverId,
                        lastServiceDate: selectedVehicle.lastServiceDate,
                        createdAt: selectedVehicle.createdAt
                    )
                    try await SupabaseManager.shared.updateVehicle(dbVehicle)
                } catch {
                    print("⚠️ Failed to sync work order to Supabase: \(error.localizedDescription)")
                }
            }
            
            return true
        } catch {
            errorMessage = "Failed to create work order: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    
    
    func startWork(workOrderId: UUID, context: ModelContext, workOrders: [WorkOrder]) -> Bool {
        errorMessage = nil
        guard let wo = workOrders.first(where: { $0.id == workOrderId }) else {
            errorMessage = "Work order not found."
            return false
        }
        
        wo.status = .inProgress
        
        do {
            try context.save()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            
            var dbWO = wo.asDBWorkOrder
            dbWO.status = .inProgress
            Task {
                try? await SupabaseManager.shared.updateWorkOrder(dbWO)
            }
            
            return true
        } catch {
            errorMessage = "Failed to update work order: \(error.localizedDescription)"
            return false
        }
    }
    
    
    
    func completeWork(workOrderId: UUID, finalCost: Double, context: ModelContext, workOrders: [WorkOrder], vehicles: [Vehicle]) -> Bool {
        errorMessage = nil
        guard let wo = workOrders.first(where: { $0.id == workOrderId }) else {
            errorMessage = "Work order not found."
            return false
        }
        
        guard let vehicle = vehicles.first(where: { $0.id == wo.vehicleId }) else {
            errorMessage = "Associated vehicle not found."
            return false
        }
        
        
        wo.status = .completed
        wo.completedAt = Date()
        
        
        vehicle.status = .active
        vehicle.lastServiceDate = Date()
        
        vehicle.nextServiceDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        vehicle.updatedAt = Date()
        
        
        let maintenanceRecord = MaintenanceRecord(
            vehicleId: wo.vehicleId,
            workOrderId: wo.id,
            serviceType: wo.title,
            serviceDate: Date(),
            cost: finalCost,
            notes: wo.workDescription + "\nScheduled Priority: \(wo.priority.rawValue)",
            performedBy: wo.assignedTo
        )
        context.insert(maintenanceRecord)
        
        do {
            try context.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            
            var dbWO = wo.asDBWorkOrder
            dbWO.status = .completed
            Task {
                do {
                    try await SupabaseManager.shared.updateWorkOrder(dbWO)
                    
                    let dbTask = DBMaintenanceTask(
                        id: UUID(),
                        vehicleId: wo.vehicleId,
                        assignedTo: wo.assignedTo,
                        serviceType: wo.title,
                        dueDate: Date(),
                        status: .completed,
                        notes: wo.workDescription,
                        createdAt: Date()
                    )
                    try await SupabaseManager.shared.createMaintenanceTask(dbTask)
                    try await SupabaseManager.shared.createMaintenanceRecord(maintenanceRecord.asDBRecord)
                } catch {
                    print("⚠️ Failed to sync work order completion to Supabase: \(error.localizedDescription)")
                }
            }
            
            return true
        } catch {
            errorMessage = "Failed to complete work order: \(error.localizedDescription)"
            return false
        }
    }
    
    
    
    func cancelWork(workOrderId: UUID, context: ModelContext, workOrders: [WorkOrder], vehicles: [Vehicle]) -> Bool {
        errorMessage = nil
        guard let wo = workOrders.first(where: { $0.id == workOrderId }) else {
            errorMessage = "Work order not found."
            return false
        }
        
        wo.status = .cancelled
        
        if let vehicle = vehicles.first(where: { $0.id == wo.vehicleId }) {
            
            let otherActive = workOrders.contains { $0.vehicleId == wo.vehicleId && $0.id != wo.id && ($0.status == .open || $0.status == .inProgress) }
            if !otherActive {
                vehicle.status = .active
                vehicle.updatedAt = Date()
            }
        }
        
        do {
            try context.save()
            
            
            var dbWO = wo.asDBWorkOrder
            dbWO.status = .closed
            Task {
                try? await SupabaseManager.shared.updateWorkOrder(dbWO)
            }
            
            return true
        } catch {
            errorMessage = "Failed to cancel: \(error.localizedDescription)"
            return false
        }
    }
}
