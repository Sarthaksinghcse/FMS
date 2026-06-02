// FMS/Services/FuelOptimizationService.swift
import Foundation

struct VehicleFuelStats: Identifiable {
    let id: UUID            // vehicleId
    let vehicleNumber: String
    let fuelType: String
    let totalLitres: Double
    let totalSpend: Double
    let avgCostPerLitre: Double
    let logCount: Int
    let isHighConsumer: Bool       // true if spend > 1.5× fleet average
    let percentAboveAverage: Double
}

struct FuelInsight: Codable {
    let insightsText: String
    let estimatedSavings: Double
    let highConsumers: [VehicleInsight]

    enum CodingKeys: String, CodingKey {
        case insightsText    = "insights_text"
        case estimatedSavings = "estimated_savings"
        case highConsumers   = "high_consumers"
    }

    struct VehicleInsight: Codable, Identifiable {
        var id: String { vehicleId }
        let vehicleId: String
        let issue: String
        let recommendation: String

        enum CodingKeys: String, CodingKey {
            case vehicleId      = "vehicle_id"
            case issue
            case recommendation
        }
    }
}

final class FuelOptimizationService {
    static let shared = FuelOptimizationService()

    private init() {}

    func analyzeFleetFuel(
        logs: [DBFuelLog],
        vehicles: [DBVehicle]
    ) -> [VehicleFuelStats] {
        let vehicleMap = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0) })

        // Group logs by vehicle
        let grouped = Dictionary(grouping: logs, by: { $0.vehicleId ?? UUID() })

        var stats: [VehicleFuelStats] = []
        for (vehicleId, vehicleLogs) in grouped {
            guard let vehicle = vehicleMap[vehicleId] else { continue }
            let totalLitres = vehicleLogs.reduce(0) { $0 + $1.litres }
            let totalSpend  = vehicleLogs.reduce(0) { $0 + $1.amountPaid }

            stats.append(VehicleFuelStats(
                id: vehicleId,
                vehicleNumber: vehicle.vehicleNumber,
                fuelType: vehicle.fuelType ?? "unknown",
                totalLitres: totalLitres,
                totalSpend: totalSpend,
                avgCostPerLitre: totalLitres > 0 ? totalSpend / totalLitres : 0,
                logCount: vehicleLogs.count,
                isHighConsumer: false,          // set below
                percentAboveAverage: 0          // set below
            ))
        }

        // Mark high consumers (spend > 1.5× fleet average)
        let avgSpend = stats.isEmpty ? 0 : stats.reduce(0) { $0 + $1.totalSpend } / Double(stats.count)
        return stats.map { s in
            let pct = avgSpend > 0 ? ((s.totalSpend - avgSpend) / avgSpend) * 100 : 0
            return VehicleFuelStats(
                id: s.id, vehicleNumber: s.vehicleNumber, fuelType: s.fuelType,
                totalLitres: s.totalLitres, totalSpend: s.totalSpend,
                avgCostPerLitre: s.avgCostPerLitre, logCount: s.logCount,
                isHighConsumer: s.totalSpend > avgSpend * 1.5,
                percentAboveAverage: pct
            )
        }.sorted { $0.totalSpend > $1.totalSpend }
    }
}
