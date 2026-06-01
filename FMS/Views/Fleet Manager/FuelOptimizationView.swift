// FMS/Views/Fleet Manager/FuelOptimizationView.swift
import SwiftUI

struct FuelOptimizationView: View {
    @State private var viewModel = FuelOptimizationViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Savings Banner
                if let insight = viewModel.insight {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                Image(systemName: "indianrupeesign.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ESTIMATED MONTHLY SAVINGS")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.secondary)
                                    .tracking(0.5)
                                Text(String(format: "₹%.0f", insight.estimatedSavings))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            Button {
                                Task {
                                    await viewModel.loadFuelInsights(forceRefresh: true, loadOnlyFromCache: false)
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .padding(10)
                                    .background(AppTheme.Background.page)
                                    .clipShape(Circle())
                            }
                            .disabled(viewModel.isGenerating)
                        }

                        Text(insight.insightsText)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineSpacing(4)
                    }
                    .padding(18)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .stroke(Color.green.opacity(0.15), lineWidth: 1.5)
                    )
                    .padding(16)
                }

                if viewModel.isLoading && viewModel.fuelStats.isEmpty {
                    Spacer()
                    ProgressView("Analyzing fuel logs...")
                        .tint(AppTheme.Brand.primary)
                    Spacer()
                } else if viewModel.fuelStats.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.08))
                                .frame(width: 80, height: 80)
                            Image(systemName: "fuelpump.slash.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.blue.opacity(0.7))
                        }
                        
                        Text("No Fuel Logs Logged")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text("Start logging your trips and refuels to generate AI fuel optimization insights.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            Task {
                                await viewModel.loadFuelInsights(forceRefresh: true, loadOnlyFromCache: false)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Reload Fuel Data")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppTheme.Brand.primary)
                            .cornerRadius(24)
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // AI High Consumers
                            if let insight = viewModel.insight, !insight.highConsumers.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.purple)
                                        Text("AI Optimization Targets")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                    }
                                    
                                    ForEach(insight.highConsumers) { vehicle in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Vehicle: " + vehicle.vehicleId.prefix(8).uppercased())
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Text("High Consumption")
                                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                                    .foregroundColor(.red)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.red.opacity(0.1))
                                                    .cornerRadius(6)
                                            }
                                            
                                            Text("Issue: " + vehicle.issue)
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(AppTheme.Text.secondary)
                                            
                                            Text("Advice: " + vehicle.recommendation)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundColor(.purple)
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.purple.opacity(0.04))
                                                .cornerRadius(6)
                                        }
                                        .padding(14)
                                        .background(AppTheme.Background.card)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppTheme.Glass.border, lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            
                            // Fleet Stats list
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Vehicle Consumption Stats")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                ForEach(viewModel.fuelStats) { stats in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(stats.isHighConsumer ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "fuelpump.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(stats.isHighConsumer ? .red : .blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(stats.vehicleNumber)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                            Text("\(stats.logCount) Refuels · \(stats.fuelType)")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(String(format: "₹%.0f", stats.totalSpend))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                            
                                            if stats.percentAboveAverage > 0 {
                                                Text(String(format: "+%.0f%% vs avg", stats.percentAboveAverage))
                                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.red)
                                            } else {
                                                Text("Optimal")
                                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(AppTheme.Background.card)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(stats.isHighConsumer ? Color.red.opacity(0.2) : AppTheme.Glass.border, lineWidth: 1)
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
        .navigationTitle("Fuel Optimization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFuelInsights(forceRefresh: false, loadOnlyFromCache: true)
            }
        }
    }
}
