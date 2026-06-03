// FMS/Views/Maintenance/SparePartsForecastView.swift
import SwiftUI

struct SparePartsForecastView: View {
    @State private var viewModel = SparePartsForecastViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.forecasts.isEmpty {
                    Spacer()
                    ProgressView("Computing spare parts demand...")
                        .tint(AppTheme.Brand.primary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // Parsed AI Report Sections
                            let parsed = parseSections(from: viewModel.summary)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(parsed.sections) { section in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(section.iconBgColor)
                                                    .frame(width: 38, height: 38)
                                                Image(systemName: section.icon)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(section.iconColor)
                                            }
                                            
                                            Text(section.title)
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                        }
                                        
                                        Text(LocalizedStringKey(section.content))
                                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.Text.primary)
                                            .lineSpacing(5)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(18)
                                    .background(AppTheme.Background.card)
                                    .cornerRadius(AppTheme.Radius.card)
                                    .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                            .stroke(AppTheme.Glass.border.opacity(0.12), lineWidth: 1)
                                    )
                                }
                            }
                            
                            // Stock lists
                            if !viewModel.atRiskParts.isEmpty {
                                Text("Stockout Risks Detected")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 8)
                                
                                ForEach(viewModel.atRiskParts) { part in
                                    partCard(part)
                                }
                            }

                            if !viewModel.healthyParts.isEmpty {
                                Text("Safe Stock Levels")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.top, 8)
                                
                                ForEach(viewModel.healthyParts) { part in
                                    partCard(part)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("AI Parts Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.loadForecast(forceRefresh: true)
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.Brand.primary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadForecast(forceRefresh: false)
            }
        }
        .toolbar(.hidden, for: .tabBar)
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
                        .foregroundColor(part.stockoutRisk ? AppTheme.Status.danger : AppTheme.Status.success)
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
                            .foregroundColor(AppTheme.Brand.primary)
                        Text("+\(part.recommendedReorder) units")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.Background.card)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(part.stockoutRisk ? AppTheme.Status.danger.opacity(0.15) : AppTheme.Glass.border, lineWidth: 1)
        )
    }

    // MARK: - Parser & Structs
    
    struct ReportSection: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        
        var icon: String {
            let t = title.lowercased()
            if t.contains("health") || t.contains("overview") {
                return "shippingbox.fill"
            } else if t.contains("risk") || t.contains("stockout") {
                return "exclamationmark.triangle.fill"
            } else if t.contains("recommend") || t.contains("reorder") {
                return "arrow.up.arrow.down.circle.fill"
            } else {
                return "doc.text.fill"
            }
        }
        
        var iconColor: Color {
            let t = title.lowercased()
            if t.contains("health") || t.contains("overview") {
                return AppTheme.Brand.teal
            } else if t.contains("risk") || t.contains("stockout") {
                return AppTheme.Status.danger
            } else if t.contains("recommend") || t.contains("reorder") {
                return AppTheme.Brand.primary
            } else {
                return AppTheme.Brand.violet
            }
        }
        
        var iconBgColor: Color {
            let t = title.lowercased()
            if t.contains("health") || t.contains("overview") {
                return AppTheme.Brand.teal.opacity(0.12)
            } else if t.contains("risk") || t.contains("stockout") {
                return AppTheme.Status.danger.opacity(0.12)
            } else if t.contains("recommend") || t.contains("reorder") {
                return AppTheme.Brand.primary.opacity(0.12)
            } else {
                return AppTheme.Brand.violet.opacity(0.12)
            }
        }
    }
    
    private func parseSections(from text: String) -> (title: String, sections: [ReportSection]) {
        var mainTitle = "Executive Inventory Forecast"
        var parsedSections: [ReportSection] = []
        
        let blocks = text.components(separatedBy: "\n")
        
        var currentSectionTitle = ""
        var currentSectionContent = ""
        
        func cleanText(_ input: String) -> String {
            var cleaned = input.replacingOccurrences(of: "\"\"", with: "")
            cleaned = cleaned.replacingOccurrences(of: "\"", with: "")
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") {
                let cleanTitle = cleanText(trimmed.replacingOccurrences(of: "**", with: ""))
                
                if cleanTitle.lowercased().contains("report") && parsedSections.isEmpty && currentSectionTitle.isEmpty {
                    mainTitle = cleanTitle
                } else {
                    if !currentSectionTitle.isEmpty && !currentSectionContent.isEmpty {
                        let finalContent = cleanText(currentSectionContent)
                        parsedSections.append(ReportSection(title: currentSectionTitle, content: finalContent))
                        currentSectionContent = ""
                    }
                    currentSectionTitle = cleanTitle
                }
            } else {
                currentSectionContent += (currentSectionContent.isEmpty ? "" : "\n") + trimmed
            }
        }
        
        if !currentSectionTitle.isEmpty && !currentSectionContent.isEmpty {
            let finalContent = cleanText(currentSectionContent)
            parsedSections.append(ReportSection(title: currentSectionTitle, content: finalContent))
        }
        
        if parsedSections.isEmpty {
            let finalContent = cleanText(text)
            parsedSections.append(ReportSection(title: "Overview", content: finalContent))
        }
        
        return (cleanText(mainTitle), parsedSections)
    }
}
