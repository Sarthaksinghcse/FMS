// FMS/Views/Maintenance/SparePartsForecastView.swift
import SwiftUI

struct SparePartsForecastView: View {
    @State private var viewModel = SparePartsForecastViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Summary Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 38, height: 38)
                            Image(systemName: "box.truck.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 16))
                        }
                        
                        Text("AI Spare Parts Demand Forecast")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await viewModel.loadForecast(forceRefresh: true)
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Brand.primary)
                                .padding(8)
                                .background(AppTheme.Background.page)
                                .clipShape(Circle())
                        }
                        .disabled(viewModel.isLoading)
                    }

                    if !viewModel.summary.isEmpty {
                        Text(viewModel.summary)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineSpacing(4)
                    }
                }
                .padding(18)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                .padding(16)

                if viewModel.isLoading && viewModel.forecasts.isEmpty {
                    Spacer()
                    ProgressView("Computing spare parts demand...")
                        .tint(AppTheme.Brand.primary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            if !viewModel.atRiskParts.isEmpty {
                                Text("Stockout Risks Detected")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                ForEach(viewModel.atRiskParts) { part in
                                    partCard(part)
                                }
                            }

                            if !viewModel.healthyParts.isEmpty {
                                Text("Safe Stock Levels")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                                
                                ForEach(viewModel.healthyParts) { part in
                                    partCard(part)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .navigationTitle("Parts Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.loadForecast(forceRefresh: false)
            }
        }
    }

    private func partCard(_ part: PartForecast) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.partName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("Stockout risk: " + (part.stockoutRisk ? "YES" : "NO"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(part.stockoutRisk ? .red : .green)
                }
                
                Spacer()
                
                // Urgency badge
                Text(part.urgency.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(part.urgencyColor)
                    .cornerRadius(6)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT STOCK")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text("\(part.currentStock) units")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("PREDICTED DEMAND (30D)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text("\(part.predictedDemand) units")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }

                Spacer()

                if part.recommendedReorder > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("REORDER REC")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                        Text("+\(part.recommendedReorder) units")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.Background.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(part.stockoutRisk ? Color.red.opacity(0.15) : AppTheme.Glass.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
