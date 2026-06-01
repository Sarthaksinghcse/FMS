






import SwiftUI
import SwiftData
import Combine


@MainActor
final class AlertsFeedViewModel: ObservableObject {
    @Published var errorMessage: String? = nil
    
    
    
    func resolveSOSAlert(alertId: UUID, context: ModelContext, alerts: [SOSAlert]) -> Bool {
        errorMessage = nil
        guard let alert = alerts.first(where: { $0.id == alertId }) else {
            errorMessage = "Alert not found."
            return false
        }
        
        alert.status = .resolved
        
        do {
            try context.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            
            let notification = DBNotification(
                id: UUID(),
                userId: alert.driverId,
                title: "SOS Alert Resolved",
                message: "Your emergency alert has been acknowledged and resolved by the fleet manager.",
                type: .emergency,
                isRead: false,
                createdAt: Date()
            )
            let dbAlert = alert.asDBSOSAlert
            Task {
                try? await SupabaseManager.shared.updateSOSAlert(dbAlert)
                try? await SupabaseManager.shared.createNotification(notification)
            }
            
            return true
        } catch {
            errorMessage = "Failed to resolve SOS: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    
    
    func updateDefectStatus(defectId: UUID, newStatus: DefectStatus, context: ModelContext, defects: [DefectReport]) -> Bool {
        errorMessage = nil
        guard let defect = defects.first(where: { $0.id == defectId }) else {
            errorMessage = "Defect report not found."
            return false
        }
        
        defect.status = newStatus
        
        do {
            try context.save()
            
            // Sync status update to Supabase
            let dbDefect = defect.asDBDefectReport
            Task {
                try? await SupabaseManager.shared.updateDefectReport(dbDefect)
            }
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return true
        } catch {
            errorMessage = "Failed to update defect: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    func assignDefect(defectId: UUID, mechanicId: UUID, priority: WorkOrderPriority, notes: String, context: ModelContext, defects: [DefectReport]) async -> Bool {
        errorMessage = nil
        guard let defect = defects.first(where: { $0.id == defectId }) else {
            errorMessage = "Defect report not found."
            return false
        }
        
        defect.status = .inProgress
        
        let workOrder = WorkOrder(
            id: UUID(),
            vehicleId: defect.vehicleId,
            defectReportId: defect.id,
            assignedTo: mechanicId,
            title: defect.title,
            workDescription: defect.defectDescription + (notes.isEmpty ? "" : "\nNotes: \(notes)"),
            priority: priority,
            status: .open,
            createdAt: Date()
        )
        
        context.insert(workOrder)
        
        do {
            try context.save()
            
            let dbDefect = defect.asDBDefectReport
            let dbWorkOrder = workOrder.asDBWorkOrder
            
            let notif = DBNotification(
                id: UUID(),
                userId: mechanicId,
                title: "New Work Order Assigned",
                message: "You have been assigned to repair defect on Vehicle \(defect.vehicleId.uuidString.prefix(4)): \(defect.title)",
                type: .maintenance,
                isRead: false,
                createdAt: Date()
            )
            
            try await SupabaseManager.shared.updateDefectReport(dbDefect)
            try await SupabaseManager.shared.createWorkOrder(dbWorkOrder)
            try await SupabaseManager.shared.createNotification(notif)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = "Failed to assign defect: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
}

