// FMS/ViewModels/Fleet Manager/WorkOrderPrioritizationViewModel.swift
import SwiftUI
import Observation

@Observable
final class WorkOrderPrioritizationViewModel {
    var sortedWorkOrders: [DBWorkOrder] = []
    var scoreMap: [UUID: Double] = [:]   // workOrderId → score
    var isLoading = false
    var errorMessage: String?

    func loadAndPrioritize() async {
        isLoading = true
        errorMessage = nil
        do {
            let workOrders = try await SupabaseManager.shared.fetchWorkOrders()
            let defects    = try await SupabaseManager.shared.fetchDefectReports()
            let vehicles   = try await SupabaseManager.shared.fetchVehicles()

            // Build score map for badge display
            let defectMap  = Dictionary(uniqueKeysWithValues: defects.map { ($0.vehicleId, $0) })
            let vehicleMap = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })
            
            var localScoreMap: [UUID: Double] = [:]
            for order in workOrders {
                localScoreMap[order.id] = AIWorkOrderService.shared.computePriorityScore(
                    workOrder: order,
                    defect: defectMap[order.vehicleId],
                    vehicle: vehicleMap[order.vehicleId]
                )
            }
            
            self.scoreMap = localScoreMap
            self.sortedWorkOrders = AIWorkOrderService.shared.sorted(workOrders, defects: defects, vehicles: vehicles)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
