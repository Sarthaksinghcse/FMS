// FMS/Views/Fleet Manager/AIReportsView.swift
import SwiftUI

struct AIReportsView: View {
    @State private var viewModel = AIReportsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Banner
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Executive AI Summary")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        if (viewModel.report?.generatedAt) != nil {
                            Text("Generated \(viewModel.formattedDate)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                        } else {
                            Text("Ready to analyze fleet data")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        Task {
                            await viewModel.loadReport(forceRefresh: true, loadOnlyFromCache: false)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if viewModel.isGenerating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Generate Fresh")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(LinearGradient(colors: [Color.purple, Color.purple.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(18)
                        .shadow(color: Color.purple.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .disabled(viewModel.isGenerating)
                }
                .padding(20)
                .background(AppTheme.Background.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                if viewModel.isGenerating && viewModel.report == nil {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.purple)
                            .scaleEffect(1.2)
                        Text("Running AI analytics engines...")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                    Spacer()
                } else if let report = viewModel.report {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Overall Banner
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "chart.bar.doc.horizontal.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.purple)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fleet Analyst Insights")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    Text("Aggregated over past 30 days of fleet operational logs.")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                            }
                            .padding(14)
                            .background(Color.purple.opacity(0.03))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                            )
                            
                            // Executive report text card
                            VStack(alignment: .leading, spacing: 14) {
                                Text("EXECUTIVE MEMORANDUM")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.tertiary)
                                    .tracking(1.0)
                                
                                Text(report.reportText)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                                    .lineSpacing(6)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                    .stroke(AppTheme.Glass.border.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(16)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.purple.opacity(0.5))
                        
                        Text("No Fleet Report Generated")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Button {
                            Task {
                                await viewModel.loadReport(forceRefresh: true, loadOnlyFromCache: false)
                            }
                        } label: {
                            Text("Generate AI Report Now")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(AppTheme.Brand.primary)
                                .cornerRadius(24)
                        }
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("AI Fleet Report")
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
                await viewModel.loadReport(forceRefresh: false, loadOnlyFromCache: true)
            }
        }
    }
}
#Preview {
    AIReportsView()
}
