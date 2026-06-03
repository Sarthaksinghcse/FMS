// FMS/ViewModels/Fleet Manager/FuelOptimizationViewModel.swift
import SwiftUI
import Observation
import Supabase

@Observable
final class FuelOptimizationViewModel {
    var fuelStats: [VehicleFuelStats] = []
    var insight: FuelInsight?
    var vehicles: [DBVehicle] = []
    var isGenerating = false
    var isLoading = false
    var errorMessage: String?

    struct ActiveVehicleInsight: Identifiable {
        var id: String { insight.id }
        let insight: FuelInsight.VehicleInsight
        let vehicle: DBVehicle
    }

    var activeInsights: [ActiveVehicleInsight] {
        guard let insight = insight else { return [] }
        return insight.highConsumers.compactMap { vehicle in
            guard let dbVeh = matchedVehicle(for: vehicle.vehicleId) else { return nil }
            return ActiveVehicleInsight(insight: vehicle, vehicle: dbVeh)
        }
    }

    private func matchedVehicle(for vehicleId: String) -> DBVehicle? {
        let cleanId = vehicleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanId == "n/a" || cleanId.isEmpty || cleanId == "unknown" {
            return nil
        }
        return vehicles.first { v in
            let uuidStr = v.id.uuidString.lowercased()
            let vehNum = v.vehicleNumber.lowercased()
            return uuidStr == cleanId || 
                   vehNum == cleanId || 
                   uuidStr.hasPrefix(cleanId) || 
                   cleanId.hasPrefix(uuidStr.prefix(8))
        }
    }

    func loadFuelInsights(forceRefresh: Bool = false, loadOnlyFromCache: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Always load local stats from real DB fuel logs
            let logs = try await SupabaseManager.shared.fetchFuelLogs()
            let vehicles = try await SupabaseManager.shared.fetchVehicles()
            self.vehicles = vehicles
            self.fuelStats = FuelOptimizationService.shared.analyzeFleetFuel(logs: logs, vehicles: vehicles)

            // 2. Try loading cached insight (unless forceRefresh)
            if !forceRefresh {
                let cached: [FuelInsight] = try await SupabaseManager.shared.client.from("ai_fuel_insights")
                    .select()
                    .order("generated_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                if let report = cached.first {
                    self.insight = report
                    self.isLoading = false
                    return
                }
            }

            // 3. If cache-only mode, stop here
            if loadOnlyFromCache {
                isLoading = false
                return
            }

            // 4. Call AI edge function for real-time fleet insights
            isGenerating = true
            let decoded: FuelInsight = try await SupabaseManager.shared.client.functions
                .invoke("fuel-optimization-insights", options: FunctionInvokeOptions(method: .post, body: [:] as [String: String])) { data, _ in
                    try JSONDecoder().decode(FuelInsight.self, from: data)
                }
            self.insight = decoded
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
        isLoading = false
    }
}
