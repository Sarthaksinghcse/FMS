// FMS/Services/VehicleHealthService.swift
import Foundation

enum HealthGrade: String, CaseIterable {
    case excellent = "Excellent"   // 85–100
    case good      = "Good"        // 70–84
    case fair      = "Fair"        // 50–69
    case poor      = "Poor"        // 30–49
    case critical  = "Critical"    // 0–29

    var colorName: String {
        switch self {
        case .excellent: return "green"
        case .good:      return "teal"
        case .fair:      return "yellow"
        case .poor:      return "orange"
        case .critical:  return "red"
        }
    }

    static func from(score: Int) -> HealthGrade {
        switch score {
        case 85...: return .excellent
        case 70..<85: return .good
        case 50..<70: return .fair
        case 30..<50: return .poor
        default:     return .critical
        }
    }
}

struct VehicleHealthScore: Identifiable {
    let id: UUID            // vehicleId
    let vehicleNumber: String
    let score: Int          // 0–100
    let grade: HealthGrade
    let issueFlags: [String]
    let suggestedTasks: [String]
    var llmSummary: String? = nil
}

final class VehicleHealthService {
    static let shared = VehicleHealthService()

    private init() {}

    func computeScore(
        vehicle: DBVehicle,
        defects: [DBDefectReport],
        records: [DBMaintenanceRecord],
        inspections: [DBVehicleInspection]
    ) -> VehicleHealthScore {
        var score = 100
        var issues: [String] = []
        var tasks: [String] = []

        // 1. Overdue service
        if let next = vehicle.nextServiceDate, next < Date() {
            score -= 20
            issues.append("Service overdue")
            tasks.append("Schedule immediate service appointment")
        }

        // 2. Open defects
        let vehicleDefects = defects.filter { $0.vehicleId == vehicle.id && $0.status == .open }
        for defect in vehicleDefects {
            switch defect.severity {
            case .low:      score -= 3
            case .medium:   score -= 8;  issues.append("Medium defect: \(defect.title)")
            case .high:     score -= 15; issues.append("Critical defect: \(defect.title)")
            }
        }
        if !vehicleDefects.isEmpty {
            tasks.append("Resolve \(vehicleDefects.count) open defect report(s)")
        }

        // 3. No inspection in 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentInspections = inspections.filter {
            $0.vehicleId == vehicle.id && $0.inspectionDate > thirtyDaysAgo
        }
        if recentInspections.isEmpty {
            score -= 10
            issues.append("No inspection in 30+ days")
            tasks.append("Conduct a full vehicle inspection")
        }

        // 4. No maintenance record in 60 days
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let recentRecords = records.filter {
            $0.vehicleId == vehicle.id && $0.serviceDate > sixtyDaysAgo
        }
        if recentRecords.isEmpty {
            score -= 10
            issues.append("No maintenance activity in 60+ days")
        }

        let clamped = max(0, min(score, 100))
        return VehicleHealthScore(
            id: vehicle.id,
            vehicleNumber: vehicle.vehicleNumber,
            score: clamped,
            grade: .from(score: clamped),
            issueFlags: issues,
            suggestedTasks: tasks
        )
    }

    func analyzeFleet(
        vehicles: [DBVehicle],
        defects: [DBDefectReport],
        records: [DBMaintenanceRecord],
        inspections: [DBVehicleInspection]
    ) -> [VehicleHealthScore] {
        vehicles
            .map { computeScore(vehicle: $0, defects: defects, records: records, inspections: inspections) }
            .sorted { $0.score < $1.score }  // worst first
    }
}
