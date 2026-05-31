// FMS/ViewModels/Maintenance/VehicleHealthViewModel.swift
import SwiftUI
import Observation
import Supabase

@Observable
final class VehicleHealthViewModel {
    var healthScores: [VehicleHealthScore] = []
    var isGenerating = false
    var isLoading = false
    var errorMessage: String?

    func loadHealth(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        do {
            let vehicles = try await SupabaseManager.shared.fetchVehicles()
            let defects = try await SupabaseManager.shared.fetchDefectReports()
            
            // Fetch database health scores
            let dbScores = try await SupabaseManager.shared.fetchVehicleHealthScores()
            let scoreMap = Dictionary(uniqueKeysWithValues: dbScores.map { ($0.vehicleId, $0) })

            // Compute local rule-based score and append LLM insights if available
            self.healthScores = vehicles.map { vehicle in
                let matchingDefects = defects.filter { $0.vehicleId == vehicle.id }
                
                var local = VehicleHealthService.shared.computeScore(
                    vehicle: vehicle,
                    defects: matchingDefects,
                    records: [],
                    inspections: []
                )
                
                if let dbScore = scoreMap[vehicle.id] {
                    local.llmSummary = dbScore.llmSummary
                }
                return local
            }.sorted { $0.score < $1.score } // worst first

            if forceRefresh || dbScores.isEmpty {
                // Call Deno vehicle health analysis
                isGenerating = true
                let _: Data = try await SupabaseManager.shared.client.functions.invoke("vehicle-health-analysis")
                
                // Reload DB scores after running AI analysis
                let freshDBScores = try await SupabaseManager.shared.fetchVehicleHealthScores()
                let freshScoreMap = Dictionary(uniqueKeysWithValues: freshDBScores.map { ($0.vehicleId, $0) })
                
                self.healthScores = self.healthScores.map { score in
                    var updated = score
                    if let dbScore = freshScoreMap[score.id] {
                        updated.llmSummary = dbScore.llmSummary
                    }
                    return updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
        isLoading = false
    }
}
