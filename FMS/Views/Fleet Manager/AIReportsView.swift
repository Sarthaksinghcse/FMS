// FMS/Views/Fleet Manager/AIReportsView.swift
import SwiftUI
import SwiftData

struct AIReportsView: View {
    var isPresentedAsSheet: Bool = false
    @State private var viewModel = AIReportsViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                            await viewModel.loadReport(context: modelContext, forceRefresh: true, loadOnlyFromCache: false)
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
                        .background(LinearGradient(colors: [Theme.royalBlue, Theme.royalBlue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(18)
                        .shadow(color: Theme.royalBlue.opacity(0.2), radius: 6, x: 0, y: 3)
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
                            .tint(Theme.royalBlue)
                            .scaleEffect(1.2)
                        Text("Running AI analytics engines...")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                    Spacer()
                } else if let report = viewModel.report {
                    let parsed = parseSections(from: report.reportText)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Render Each Section in a beautiful Card
                            ForEach(parsed.sections) { section in
                                VStack(alignment: .leading, spacing: 14) {
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
                        .padding(16)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.royalBlue.opacity(0.5))
                        
                        Text("No Fleet Report Generated")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Button {
                            Task {
                                await viewModel.loadReport(context: modelContext, forceRefresh: true, loadOnlyFromCache: false)
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
            if isPresentedAsSheet {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.royalBlue)
                    .font(.system(.body, design: .rounded))
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadReport(context: modelContext, forceRefresh: false, loadOnlyFromCache: true)
            }
        }
    }
    
    // MARK: - Parser & Structs
    
    struct ReportSection: Identifiable {
        let id = UUID()
        let title: String
        let content: String
        
        var icon: String {
            let t = title.lowercased()
            if t.contains("health") || t.contains("overview") {
                return "heart.text.square.fill"
            } else if t.contains("operational") || t.contains("highlights") {
                return "bolt.fill"
            } else if t.contains("cost") || t.contains("analysis") || t.contains("expenditure") {
                return "indianrupeesign.circle.fill"
            } else {
                return "doc.text.fill"
            }
        }
        
        var iconColor: Color {
            let t = title.lowercased()
            if t.contains("health") || t.contains("overview") {
                return AppTheme.Status.success
            } else if t.contains("operational") || t.contains("highlights") {
                return AppTheme.Brand.accent
            } else if t.contains("cost") || t.contains("analysis") || t.contains("expenditure") {
                return AppTheme.Brand.royalBlue
            } else {
                return AppTheme.Brand.violet
            }
        }
        
        var iconBgColor: Color {
            let t = title.lowercased()
            if t.contains("health") || t.contains("overview") {
                return AppTheme.IconBg.green
            } else if t.contains("operational") || t.contains("highlights") {
                return AppTheme.IconBg.amber
            } else if t.contains("cost") || t.contains("analysis") || t.contains("expenditure") {
                return AppTheme.IconBg.blue
            } else {
                return AppTheme.IconBg.violet
            }
        }
    }
    
    private func parseSections(from text: String) -> (title: String, sections: [ReportSection]) {
        var mainTitle = "Executive Fleet Report"
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
#Preview {
    AIReportsView()
}
