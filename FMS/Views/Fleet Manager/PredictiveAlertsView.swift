// FMS/Views/Fleet Manager/PredictiveAlertsView.swift
import SwiftUI

struct PredictiveAlertsView: View {
    @State private var viewModel = PredictiveMaintenanceViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Panel with Stats
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Predictive Risks")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                        Text("\(viewModel.alerts.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }

                    Spacer()

                    Button {
                        Task {
                            await viewModel.triggerAIAnalysis()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Re-Analyze Fleet")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(colors: [AppTheme.Brand.primary, AppTheme.Brand.primary.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(20)
                        .shadow(color: AppTheme.Brand.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .disabled(viewModel.isGenerating || viewModel.isLoading)
                }
                .padding(20)
                .background(AppTheme.Background.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                if viewModel.isLoading && viewModel.alerts.isEmpty {
                    Spacer()
                    ProgressView("Analyzing fleet data...")
                        .tint(AppTheme.Brand.primary)
                    Spacer()
                } else if viewModel.alerts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Status.success.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.Status.success)
                        }

                        Text("Your Fleet is Healthy")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.black)

                        Text("No upcoming breakdown risks predicted in the next 30 days.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            Task {
                                await viewModel.triggerAIAnalysis()
                            }
                        } label: {
                            Text("Run AI Health Check")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(AppTheme.Brand.primary)
                                .cornerRadius(24)
                        }
                        .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.alerts) { alert in
                                predictiveCard(alert)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("AI Predictive Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadAlerts()
            }
        }
    }

    private func predictiveCard(_ alert: DBPredictiveAlert) -> some View {
        let riskColor: Color
        let riskBg: Color
        switch alert.riskLevel {
        case "critical":
            riskColor = AppTheme.Status.danger
            riskBg = AppTheme.IconBg.red
        case "high":
            riskColor = AppTheme.Brand.accent
            riskBg = AppTheme.IconBg.orange
        case "medium":
            riskColor = AppTheme.Brand.amber
            riskBg = AppTheme.IconBg.orange.opacity(0.3)
        default:
            riskColor = AppTheme.Status.success
            riskBg = AppTheme.Brand.primary.opacity(0.12)
        }

        return VStack(alignment: .leading, spacing: 14) {
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(riskBg)
                            .frame(width: 32, height: 32)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(riskColor)
                            .font(.system(size: 14, weight: .bold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("VEHICLE ID")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                        Text(alert.vehicleId.uuidString.prefix(8).uppercased())
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                }

                Spacer()

                // Score Badge
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text(String(format: "Risk: %.0f%%", alert.riskScore * 100))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(riskColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(riskColor.opacity(0.1))
                .clipShape(Capsule())
            }

            // AI Explanation
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Brand.primary)
                    Text("AI PREDICTION")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Brand.primary)
                        .tracking(0.5)
                }

                Text(alert.llmExplanation ?? alert.triggeredReasons?.joined(separator: ", ") ?? "High probability of mechanical breakdown detected.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(AppTheme.Brand.primary.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.Brand.primary.opacity(0.1), lineWidth: 1)
            )

            // Recommended Action
            if let action = alert.suggestedAction {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(AppTheme.Brand.primary)
                        .font(.system(size: 12))
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("RECOMMENDED ACTION")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(action)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(AppTheme.Glass.border.opacity(0.2), lineWidth: 1.0)
        )
    }
}
