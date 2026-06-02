// FMS/Views/Maintenance/VehicleHealthAnalysisView.swift
import SwiftUI

struct VehicleHealthAnalysisView: View {
    @State private var viewModel = VehicleHealthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Summary KPI Header
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fleet Health Status")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                        Text(fleetHealthStatusText)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }

                    Spacer()

                    Button {
                        Task {
                            await viewModel.loadHealth(forceRefresh: true)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isGenerating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .bold))
                                Text("AI Health Check")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(LinearGradient(colors: [Color.fmsIndigo, Color.fmsIndigo.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(18)
                        .shadow(color: Color.fmsIndigo.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .disabled(viewModel.isGenerating || viewModel.isLoading)
                }
                .padding(18)
                .background(AppTheme.Background.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                if viewModel.isLoading && viewModel.healthScores.isEmpty {
                    Spacer()
                    ProgressView("Analyzing fleet health...")
                        .tint(AppTheme.Brand.primary)
                    Spacer()
                } else if viewModel.healthScores.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No Vehicles Registered")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.healthScores) { score in
                                vehicleHealthCard(score)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("Vehicle Health")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadHealth()
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var fleetHealthStatusText: String {
        let scores = viewModel.healthScores.map { Double($0.score) }
        guard !scores.isEmpty else { return "No Data" }
        let avg = scores.reduce(0.0, +) / Double(scores.count)
        if avg >= 85 { return "Excellent (Avg: \(Int(avg)))" }
        else if avg >= 70 { return "Good (Avg: \(Int(avg)))" }
        else if avg >= 50 { return "Fair (Avg: \(Int(avg)))" }
        else { return "Poor (Avg: \(Int(avg)))" }
    }

    private func vehicleHealthCard(_ score: VehicleHealthScore) -> some View {
        let healthColor: Color
        switch score.grade {
        case .excellent: healthColor = AppTheme.Status.success
        case .good:      healthColor = AppTheme.Brand.teal
        case .fair:      healthColor = AppTheme.Status.warning.opacity(0.7)
        case .poor:      healthColor = AppTheme.Status.warning
        case .critical:  healthColor = AppTheme.Status.danger
        }

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.vehicleNumber)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("Grade: " + score.grade.rawValue)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(healthColor)
                }

                Spacer()

                // Circular Progress Dial
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.04), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(Double(score.score) / 100.0))
                        .stroke(healthColor.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(score.score)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }
            }

            // AI Diagnostics block
            if let summary = score.llmSummary {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(Color.fmsIndigo)
                        Text("AI DIAGNOSTICS")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(Color.fmsIndigo)
                            .tracking(0.5)
                    }

                    Text(summary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.fmsIndigo.opacity(0.03))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.fmsIndigo.opacity(0.1), lineWidth: 1)
                )
            }

            // Issues list
            if !score.issueFlags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PENDING ISSUES")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.tertiary)
                    
                    ForEach(score.issueFlags, id: \.self) { issue in
                        HStack(spacing: 6) {
                            Circle().fill(AppTheme.Status.danger).frame(width: 4, height: 4)
                            Text(issue)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                    }
                }
            }

            // Actions list
            if !score.suggestedTasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECOMMENDED MAINTENANCE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.tertiary)
                    
                    ForEach(score.suggestedTasks, id: \.self) { task in
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Brand.primary)
                            Text(task)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Glass.border, lineWidth: 1)
        )
    }
}
