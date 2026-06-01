//
//  PredictiveAlertDetailView.swift
//  FMS
//
//  Created by Naman Yadav on 27/05/26.
//

import SwiftUI
import SwiftData

struct PredictiveAlertDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var vehicles: [Vehicle]
    
    @State private var alerts: [DBPredictiveAlert] = []
    @State private var isLoading = false
    @State private var isRunningAI = false
    @State private var errorMessage: String? = nil

    private var activeAlert: DBPredictiveAlert? {
        alerts.first
    }

    private var associatedVehicle: Vehicle? {
        guard let vehicleId = activeAlert?.vehicleId else { return nil }
        return vehicles.first { $0.id == vehicleId }
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 100)
                            ProgressView()
                                .tint(AppTheme.Brand.royalBlue)
                            Text("Fetching database records...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if let activeAlert = activeAlert {
                        // Diagnostic Status Header Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "cpu.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SMART TELEMATICS DETECTED")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                    Text("AI Maintenance Prediction")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.primary)
                                }
                                Spacer()
                                
                                Text(activeAlert.riskLevel.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        activeAlert.riskLevel.localizedCaseInsensitiveCompare("critical") == .orderedSame ||
                                        activeAlert.riskLevel.localizedCaseInsensitiveCompare("high") == .orderedSame ? AppTheme.Status.danger : AppTheme.Brand.amber
                                    )
                                    .cornerRadius(6)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Diagnostic Summary")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.Text.primary)
                                
                                if let explanation = activeAlert.llmExplanation, !explanation.isEmpty {
                                    Text(explanation)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Text.secondary)
                                        .lineSpacing(4)
                                } else if let reasons = activeAlert.triggeredReasons, !reasons.isEmpty {
                                    Text(reasons.joined(separator: "\n"))
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Text.secondary)
                                        .lineSpacing(4)
                                } else {
                                    Text("AI predicts maintenance required due to telemetry risk score of \(Int(activeAlert.riskScore * 100))%.")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                                
                                if let action = activeAlert.suggestedAction, !action.isEmpty {
                                    Text("Recommended Action: \(action)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(AppTheme.Brand.primary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                .stroke(AppTheme.Glass.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Live Sensor Trend Chart (Visual Simulation of the specific wear risk)
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Risk Wear & Performance Trend")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            // Visual trend matching the alert's risk score
                            HStack(alignment: .bottom, spacing: 14) {
                                ForEach(0..<6) { idx in
                                    // Decline trend according to the risk score
                                    let startingValue = 100.0
                                    let declineMultiplier = activeAlert.riskScore > 0.7 ? 12.0 : 4.0
                                    let value = startingValue - Double(idx) * declineMultiplier
                                    let pct = CGFloat(value / 100.0)
                                    
                                    VStack(spacing: 6) {
                                        Text("\(Int(value))%")
                                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                                            .foregroundColor(pct < 0.5 ? AppTheme.Status.danger : AppTheme.Text.secondary)
                                        
                                        ZStack(alignment: .bottom) {
                                            Capsule()
                                                .fill(AppTheme.Glass.ringTrack)
                                                .frame(width: 24, height: 100)
                                            
                                            Capsule()
                                                .fill(pct < 0.5 ? AppTheme.Status.danger : AppTheme.Brand.royalBlue)
                                                .frame(width: 24, height: 100 * pct)
                                        }
                                        
                                        Text("Wk \(idx + 1)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                            
                            HStack(spacing: 12) {
                                childIndicatorLegend(color: AppTheme.Brand.royalBlue, label: "Optimal Condition")
                                childIndicatorLegend(color: AppTheme.Status.danger, label: "Critical Wear / Risk")
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                .stroke(AppTheme.Glass.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // Vehicle Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Associated Vehicle Details")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "truck.box.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(associatedVehicle?.model ?? "Vehicle Model")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.Text.primary)
                                    Text("Reg No: \(associatedVehicle?.registrationNumber ?? "MH-12-AB-3456")")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                .stroke(AppTheme.Glass.border, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    } else {
                        // Empty State if no active alert
                        VStack(spacing: 16) {
                            Spacer().frame(height: 50)
                            Image(systemName: "sparkles.radiance")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.Brand.royalBlue.opacity(0.6))
                            
                            Text("No Active Diagnostic Alerts")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("Run AI Diagnostic analysis to process vehicle telematics and identify potential maintenance risks in the database.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Text.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Status.danger)
                            .padding(.horizontal)
                    }
                    
                    // AI Run / Refresh Button
                    VStack(spacing: 12) {
                        Button {
                            runAIDiagnostic()
                        } label: {
                            HStack {
                                if isRunningAI {
                                    ProgressView().tint(.white)
                                        .padding(.trailing, 8)
                                    Text("Analyzing Telematics...")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Run AI Diagnostic Analysis")
                                }
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.Brand.royalBlue)
                            .cornerRadius(12)
                            .shadow(color: AppTheme.Shadow.primaryGlow(opacity: 0.2), radius: 6, y: 3)
                        }
                        .disabled(isRunningAI || isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("AI Smart Diagnostic")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchAlertsFromDatabase()
        }
    }
    
    private func childIndicatorLegend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10)).foregroundColor(AppTheme.Text.secondary)
        }
    }
    
    private func fetchAlertsFromDatabase() async {
        isLoading = true
        errorMessage = nil
        do {
            self.alerts = try await SupabaseManager.shared.fetchPredictiveAlerts(onlyActive: true)
        } catch {
            errorMessage = "Failed to load alerts: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func runAIDiagnostic() {
        isRunningAI = true
        errorMessage = nil
        Task {
            do {
                // Invoke Supabase Deno Edge Function "predict-maintenance"
                let response: [String: [DBPredictiveAlert]] = try await AIServiceManager.shared.invoke("predict-maintenance")
                await MainActor.run {
                    if let newAlerts = response["alerts"] {
                        self.alerts = newAlerts
                    } else {
                        Task { await fetchAlertsFromDatabase() }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "AI diagnostic run failed: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isRunningAI = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PredictiveAlertDetailView()
    }
}
