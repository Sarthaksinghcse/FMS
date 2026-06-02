// FMS/ViewModels/Fleet Manager/FuelOptimizationViewModel.swift
import SwiftUI
import Observation
import Supabase

@Observable
final class FuelOptimizationViewModel {
    var fuelStats: [VehicleFuelStats] = []
    var insight: FuelInsight?
    var isGenerating = false
    var isLoading = false
    var errorMessage: String?

    func loadFuelInsights(forceRefresh: Bool = false, loadOnlyFromCache: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let logs = try await SupabaseManager.shared.fetchFuelLogs()
            let vehicles = try await SupabaseManager.shared.fetchVehicles()
            self.fuelStats = FuelOptimizationService.shared.analyzeFleetFuel(logs: logs, vehicles: vehicles)

            if !forceRefresh {
                // Try fetching cached latest AI insights
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

            if loadOnlyFromCache {
                isLoading = false
                return
            }

            // Fetch latest AI insights directly from database
            isGenerating = true
            let cached: [FuelInsight] = try await SupabaseManager.shared.client.from("ai_fuel_insights")
                .select()
                .order("generated_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let report = cached.first {
                self.insight = report
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
        isLoading = false
    }
}
