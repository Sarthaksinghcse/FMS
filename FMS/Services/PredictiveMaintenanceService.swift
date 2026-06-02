// FMS/Services/PredictiveMaintenanceService.swift
import Foundation

struct VehicleRisk: Identifiable {
    let id: UUID          // vehicleId
    let vehicleNumber: String
    let riskScore: Double         // 0–100
    let riskLevel: RiskLevel
    let reasons: [String]
    let suggestedAction: String
}

enum RiskLevel: String, Comparable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.low, .medium, .high, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    var colorName: String {
        switch self {
        case .low:      return "green"
        case .medium:   return "yellow"
        case .high:     return "orange"
        case .critical: return "red"
        }
    }
}

final class PredictiveMaintenanceService {
    static let shared = PredictiveMaintenanceService()

    private init() {}

    func assessRisk(
        vehicle: DBVehicle,
        defects: [DBDefectReport],
        records: [DBMaintenanceRecord]
    ) -> VehicleRisk {
        var score = 0.0
        var reasons: [String] = []

        // 1. Overdue service
        if let nextService = vehicle.nextServiceDate, nextService < Date() {
            let overdueDays = Calendar.current.dateComponents(
                [.day], from: nextService, to: Date()).day ?? 0
            score += min(Double(overdueDays) * 2, 30)
            reasons.append("Service overdue by \(overdueDays) day(s)")
        }

        // 2. Open defects on this vehicle
        let vehicleDefects = defects.filter {
            $0.vehicleId == vehicle.id && $0.status == .open
        }
        for defect in vehicleDefects {
            switch defect.severity {
            case .low:      score += 3
            case .medium:   score += 8
            case .high:     score += 15; reasons.append("High defect: \(defect.title)")
            }
        }

        // 3. No maintenance in last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let recentRecords = records.filter {
            $0.vehicleId == vehicle.id && $0.serviceDate > cutoff
        }
        if recentRecords.isEmpty {
            score += 15
            reasons.append("No maintenance activity in 90+ days")
        }

        // 4. Vehicle already in maintenance status = active risk
        if vehicle.status == .maintenance {
            score += 10
            reasons.append("Vehicle currently under maintenance")
        }

        let level: RiskLevel =
            score >= 60 ? .critical :
            score >= 40 ? .high :
            score >= 20 ? .medium : .low

        let action: String
        switch level {
        case .critical: action = "Schedule immediate inspection"
        case .high:     action = "Schedule service within this week"
        case .medium:   action = "Monitor closely, schedule next cycle"
        case .low:      action = "Routine monitoring — no action needed"
        }

        return VehicleRisk(
            id: vehicle.id,
            vehicleNumber: vehicle.vehicleNumber,
            riskScore: min(score, 100),
            riskLevel: level,
            reasons: reasons.isEmpty ? ["No current risk indicators"] : reasons,
            suggestedAction: action
        )
    }

    func analyzeFleet(
        vehicles: [DBVehicle],
        defects: [DBDefectReport],
        records: [DBMaintenanceRecord]
    ) -> [VehicleRisk] {
        vehicles
            .map { assessRisk(vehicle: $0, defects: defects, records: records) }
            .sorted { $0.riskScore > $1.riskScore }
    }
}
