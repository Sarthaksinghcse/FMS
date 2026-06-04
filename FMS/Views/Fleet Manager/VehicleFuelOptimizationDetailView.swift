// FMS/Views/Fleet Manager/VehicleFuelOptimizationDetailView.swift
import SwiftUI
import Supabase

struct VehicleFuelInsightResponse: Codable {
    let vehicleNumber: String
    let totalSpend: Double
    let totalLitres: Double
    let avgCostPerLitre: Double
    let insights: String
    let issues: [String]
    let recommendations: [String]
    let estimatedSavings: Double

    // Gemini sometimes returns numbers as strings — handle both
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vehicleNumber = try c.decode(String.self, forKey: .vehicleNumber)
        insights = try c.decode(String.self, forKey: .insights)
        issues = (try? c.decode([String].self, forKey: .issues)) ?? []
        recommendations = (try? c.decode([String].self, forKey: .recommendations)) ?? []

        // Decode numbers that may arrive as String or Double
        totalSpend = Self.flexDouble(container: c, key: .totalSpend)
        totalLitres = Self.flexDouble(container: c, key: .totalLitres)
        avgCostPerLitre = Self.flexDouble(container: c, key: .avgCostPerLitre)
        estimatedSavings = Self.flexDouble(container: c, key: .estimatedSavings)
    }

    private enum CodingKeys: String, CodingKey {
        case vehicleNumber, totalSpend, totalLitres, avgCostPerLitre
        case insights, issues, recommendations, estimatedSavings
    }

    private static func flexDouble(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        if let v = try? container.decode(Double.self, forKey: key) { return v }
        if let s = try? container.decode(String.self, forKey: key), let v = Double(s) { return v }
        return 0
    }
}

struct VehicleFuelOptimizationDetailView: View {
    let stats: VehicleFuelStats
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var response: VehicleFuelInsightResponse?

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Vehicle Specs Header Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.royalBlue.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "fuelpump.fill")
                                    .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(Theme.royalBlue)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stats.vehicleNumber)
                                    .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                Text("\(stats.logCount) Refuels logged")
                                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(AppTheme.Text.secondary)
                            }
                            
                            Spacer()
                            
                            Text(stats.fuelType.uppercased())
                                .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.royalBlue)
                                .cornerRadius(6)
                        }
                        
                        Divider()
                        
                        // Specs grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            specItem(label: "TOTAL SPEND", value: String(format: "₹%.0f", stats.totalSpend))
                            specItem(label: "TOTAL LITRES", value: String(format: "%.1f L", stats.totalLitres))
                            specItem(label: "AVG COST / LITRE", value: String(format: "₹%.2f", stats.avgCostPerLitre))
                            specItem(label: "FLEET COMP", value: stats.percentAboveAverage > 0 ? String(format: "+%.0f%% vs avg", stats.percentAboveAverage) : "Optimal")
                        }
                    }
                    .padding(18)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .stroke(AppTheme.Glass.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    
                    // AI Status & Generation Block
                    if isLoading {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 40)
                            ProgressView()
                                .tint(Theme.royalBlue)
                            Text("Gemini is analyzing vehicle consumption patterns...")
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                            Spacer().frame(height: 40)
                        }
                        .frame(maxWidth: .infinity)
                    } else if let error = errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                .foregroundColor(Theme.darkOrange)
                            Text(error)
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else if let ai = response {
                        
                        // AI Summary
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Theme.royalBlue)
                                Text("AI Optimization Diagnostics")
                                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                            
                            Text(ai.insights)
                                .font(.system(size: 12.5 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .lineSpacing(4)
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.Glass.border, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                        // AI Potential Savings
                        if ai.estimatedSavings > 0 {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.royalBlue.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "indianrupeesign.circle.fill")
                                            .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                            .foregroundColor(Theme.royalBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ESTIMATED MONTHLY SAVINGS")
                                            .font(.system(size: 8 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .tracking(0.5)
                                        Text(String(format: "₹%.0f", ai.estimatedSavings))
                                            .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(14)
                            .background(AppTheme.Background.card)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.royalBlue.opacity(0.15), lineWidth: 1.5)
                            )
                            .padding(.horizontal, 16)
                        }
                        
                        // Inefficiencies Identified
                        if !ai.issues.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Consumption Inefficiencies")
                                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                
                                ForEach(ai.issues, id: \.self) { issue in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(Theme.darkOrange)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 6)
                                        Text(issue)
                                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.darkOrange.opacity(0.04))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Theme.darkOrange.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Actionable Advice / Recommendations
                        if !ai.recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Optimization Recommendations")
                                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                
                                ForEach(ai.recommendations, id: \.self) { rec in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                            .foregroundColor(Theme.royalBlue)
                                            .padding(.top, 2)
                                        Text(rec)
                                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                                            .foregroundColor(.black)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppTheme.Background.card)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(AppTheme.Glass.border, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("\(stats.vehicleNumber) Optimization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await runAIDiagnostics()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                            .foregroundColor(Theme.royalBlue)
                    }
                }
                .disabled(isLoading)
            }
        }
        .task {
            await runAIDiagnostics()
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func specItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 8 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.tertiary)
            Text(value)
                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func runAIDiagnostics() async {
        isLoading = true
        errorMessage = nil
        do {
            let payload = VehicleFuelDiagnosticsRequest(vehicleId: stats.id.uuidString)
            let options = FunctionInvokeOptions(method: .post, body: payload)
            
            // Use the decode closure overload to get raw Data
            let decoded: VehicleFuelInsightResponse = try await SupabaseManager.shared.client.functions
                .invoke("fuel-optimization-insights", options: options) { data, _ in
                    let rawString = String(data: data, encoding: .utf8) ?? "(non-utf8)"
                    print("[FuelAI] Raw response for \(self.stats.vehicleNumber): \(rawString.prefix(1000))")
                    return try JSONDecoder().decode(VehicleFuelInsightResponse.self, from: data)
                }
            
            await MainActor.run {
                self.response = decoded
            }
        } catch {
            print("[FuelAI] Error for \(stats.vehicleNumber): \(error)")
            await MainActor.run {
                errorMessage = "AI diagnostic failed: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }
}

private struct VehicleFuelDiagnosticsRequest: Codable {
    let vehicleId: String
}
