// FMS/Services/AIWorkOrderService.swift
import Foundation

final class AIWorkOrderService {
    static let shared = AIWorkOrderService()

    private init() {}

    /// Score a single work order (0–100). Higher = more urgent.
    func computePriorityScore(
        workOrder: DBWorkOrder,
        defect: DBDefectReport?,
        vehicle: DBVehicle?
    ) -> Double {
        var score = 0.0

        // 1. Base priority from existing field
        switch workOrder.priority {
        case .urgent: score += 40
        case .high:   score += 30
        case .medium: score += 20
        case .low:    score += 10
        }

        // 2. Linked defect severity bonus
        if let defect {
            switch defect.severity {
            case .low:      score += 5
            case .medium:   score += 10
            case .high:     score += 20
            }
        }

        // 3. Vehicle currently in maintenance = needs faster resolution
        if vehicle?.status == .maintenance { score += 15 }

        // 4. Age factor — older open work orders get higher urgency
        let ageInDays = Calendar.current.dateComponents(
            [.day], from: workOrder.createdAt, to: Date()).day ?? 0
        score += min(Double(ageInDays) * 0.5, 15) // capped at 15

        return min(score, 100)
    }

    /// Sort all work orders by AI priority score descending.
    func sorted(
        _ workOrders: [DBWorkOrder],
        defects: [DBDefectReport],
        vehicles: [DBVehicle]
    ) -> [DBWorkOrder] {
        let defectMap  = Dictionary(defects.map { ($0.vehicleId, $0) }, uniquingKeysWith: { first, _ in first })
        let vehicleMap = Dictionary(vehicles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return workOrders.sorted {
            computePriorityScore(
                workOrder: $0,
                defect: defectMap[$0.vehicleId],
                vehicle: vehicleMap[$0.vehicleId]
            ) >
            computePriorityScore(
                workOrder: $1,
                defect: defectMap[$1.vehicleId],
                vehicle: vehicleMap[$1.vehicleId]
            )
        }
    }

    /// Human-readable label for a score
    func priorityLabel(score: Double) -> String {
        switch score {
        case 75...: return "Auto-Urgent"
        case 50..<75: return "High"
        case 25..<50: return "Medium"
        default:      return "Low"
        }
    }

    func priorityColor(score: Double) -> String {
        switch score {
        case 75...: return "red"
        case 50..<75: return "orange"
        case 25..<50: return "yellow"
        default:      return "green"
        }
    }

    // MARK: - SwiftData Local Support

    /// Score a local SwiftData WorkOrder (0–100)
    func computePriorityScore(
        workOrder: WorkOrder,
        defect: DefectReport?,
        vehicle: Vehicle?
    ) -> Double {
        var score = 0.0

        // 1. Base priority
        switch workOrder.priority {
        case .low:    score += 10
        case .medium: score += 20
        case .high:   score += 30
        case .urgent: score += 40
        }

        // 2. Linked defect severity
        if let defect {
            switch defect.severity {
            case .low:    score += 5
            case .medium: score += 10
            case .high:   score += 20
            }
        }

        // 3. Vehicle status
        if vehicle?.status == .inMaintenance { score += 15 }

        // 4. Age factor
        let ageInDays = Calendar.current.dateComponents(
            [.day], from: workOrder.createdAt, to: Date()).day ?? 0
        score += min(Double(ageInDays) * 0.5, 15)

        return min(score, 100)
    }

    /// Sort SwiftData WorkOrders by AI priority score descending
    func sorted(
        _ workOrders: [WorkOrder],
        defects: [DefectReport],
        vehicles: [Vehicle]
    ) -> [WorkOrder] {
        let defectMap  = Dictionary(defects.map { ($0.vehicleId, $0) }, uniquingKeysWith: { first, _ in first })
        let vehicleMap = Dictionary(vehicles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return workOrders.sorted {
            computePriorityScore(
                workOrder: $0,
                defect: defectMap[$0.vehicleId],
                vehicle: vehicleMap[$0.vehicleId]
            ) >
            computePriorityScore(
                workOrder: $1,
                defect: defectMap[$1.vehicleId],
                vehicle: vehicleMap[$1.vehicleId]
            )
        }
    }
}

