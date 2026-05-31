// FMS/ViewModels/Fleet Manager/AIReportsViewModel.swift
import SwiftUI
import Observation
import Supabase

@Observable
final class AIReportsViewModel {
    var report: AIAnalyticsReport?
    var isGenerating = false
    var errorMessage: String?

    var formattedDate: String {
        guard let date = report?.generatedAt else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }

    func loadReport(forceRefresh: Bool = false, loadOnlyFromCache: Bool = false) async {
        isGenerating = true
        errorMessage = nil
        do {
            if !forceRefresh {
                // Try to load cached latest report first
                if let cached = try? await SupabaseManager.shared.fetchLatestAIReport() {
                    self.report = cached
                    self.isGenerating = false
                    return
                }
            }
            
            if loadOnlyFromCache {
                isGenerating = false
                return
            }
            
            // Generate report by calling Deno Edge Function
            let response: Data = try await SupabaseManager.shared.client.functions
                .invoke("generate-analytics-report")
            
            self.report = try JSONDecoder.fmsDecoder.decode(AIAnalyticsReport.self, from: response)
        } catch {
            errorMessage = "Failed to generate report: \(error.localizedDescription)"
        }
        isGenerating = false
    }
}
