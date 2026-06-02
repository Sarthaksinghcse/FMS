// FMS/ViewModels/Fleet Manager/PredictiveMaintenanceViewModel.swift
import SwiftUI
import Observation

@Observable
final class PredictiveMaintenanceViewModel {
    var alerts: [DBPredictiveAlert] = []
    var isGenerating = false
    var isLoading = false
    var errorMessage: String?

    func loadAlerts() async {
        isLoading = true
        errorMessage = nil
        do {
            self.alerts = try await SupabaseManager.shared.fetchPredictiveAlerts(onlyActive: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func triggerAIAnalysis() async {
        isGenerating = true
        errorMessage = nil
        do {
            // Trigger Deno function predict-maintenance
            let response: [String: [DBPredictiveAlert]] = try await AIServiceManager.shared.invoke("predict-maintenance")
            if let newAlerts = response["alerts"] {
                self.alerts = newAlerts
            } else {
                await loadAlerts()
            }
        } catch {
            errorMessage = "AI analysis failed: \(error.localizedDescription)"
        }
        isGenerating = false
    }
}
