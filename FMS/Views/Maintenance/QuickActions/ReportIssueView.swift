//
//  ReportIssueView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import SwiftData

struct ReportIssueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // SwiftData Queries
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]

    // Form State
    @State private var selectedVehicleId: UUID?
    @State private var issueCategory: String = "Engine"
    @State private var selectedSeverity: DefectSeverity = .medium
    @State private var issueTitle: String = ""
    @State private var remarks: String = ""
    @State private var isImageAttached = false

    // UI state
    @State private var showSuccessOverlay = false
    
    // Categories List
    private let categories = ["Engine", "Brakes", "Tires", "Electrical", "Safety", "Cabin", "Body", "Other"]

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    
                    // Main Form Card
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Section 1: Identification
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Asset Details")
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.accent)
                                .textCase(.uppercase)

                            // Vehicle Selector
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Select Affected Vehicle")
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Vehicle", selection: $selectedVehicleId) {
                                    Text("Choose a vehicle...").tag(UUID?.none)
                                    ForEach(vehicles) { vehicle in
                                        Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))")
                                            .tag(UUID?.some(vehicle.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }
                        }

                        Divider()

                        // Section 2: Defect description
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Incident Information")
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.accent)
                                .textCase(.uppercase)

                            // Title
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Title / Summary")
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextField("e.g. Brake oil leakage, Tire puncture", text: $issueTitle)
                                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }

                            // Category
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Category")
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Category", selection: $issueCategory) {
                                    ForEach(categories, id: \.self) { cat in
                                        Text(cat).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }

                            // Severity
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Severity Level")
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Severity", selection: $selectedSeverity) {
                                    Text("Low").tag(DefectSeverity.low)
                                    Text("Medium").tag(DefectSeverity.medium)
                                    Text("High").tag(DefectSeverity.high)
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        Divider()

                        // Section 3: Notes & Photo
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Details & Evidence")
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.accent)
                                .textCase(.uppercase)

                            // Remarks
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description of defect / safety issue")
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextEditor(text: $remarks)
                                    .frame(minHeight: 100)
                                    .padding(6)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }

                            // Photo Upload Mock
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Attach Photo Evidence")
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Button {
                                    withAnimation(.easeInOut) {
                                        isImageAttached.toggle()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: isImageAttached ? "checkmark.circle.fill" : "camera.fill")
                                            .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                            .foregroundColor(isImageAttached ? AppTheme.Status.success : AppTheme.Brand.accent)
                                        Text(isImageAttached ? "Image Evidence Attached" : "Capture / Upload Photo")
                                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                            .foregroundColor(isImageAttached ? AppTheme.Status.success : AppTheme.Text.secondary)
                                        Spacer()
                                        if isImageAttached {
                                            Image(systemName: "trash.fill")
                                                .foregroundColor(AppTheme.Status.danger)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        isImageAttached ? AppTheme.Status.success.opacity(0.06) : Color.black.opacity(0.04)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isImageAttached ? AppTheme.Status.success.opacity(0.2) : Color.clear, lineWidth: 1)
                                    )
                                    .cornerRadius(10)
                                }
                                
                                if isImageAttached {
                                    // Mock Thumbnail image
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 32 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                            .foregroundColor(.gray.opacity(0.6))
                                            .frame(width: 80, height: 80)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(10)
                                            .shadow(radius: 2)
                                        
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 18, height: 18)
                                            .background(AppTheme.Brand.accent)
                                            .clipShape(Circle())
                                            .offset(x: 5, y: -5)
                                    }
                                    .padding(.top, 4)
                                    .transition(.scale)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // Report Button
                    Button(action: saveDefectReport) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Submit Safety Report")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isFormValid ? AppTheme.Brand.accent : AppTheme.Brand.accent.opacity(0.2)
                        )
                        .cornerRadius(12)
                        .shadow(color: isFormValid ? AppTheme.Brand.accent.opacity(0.3) : Color.clear, radius: 8, y: 3)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }

            // Success Overlay
            if showSuccessOverlay {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Status.success)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 32 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: -2, y: 2)
                        }
                        
                        Text("Safety Incident Logged")
                            .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        
                        Text("Defect report submitted. The fleet manager has been notified.")
                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                            .foregroundColor(AppTheme.Text.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 32)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.modal)
                    .shadow(color: AppTheme.Shadow.modal, radius: 20)
                    .frame(width: 320)
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Report Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var isFormValid: Bool {
        selectedVehicleId != nil && !issueTitle.isEmpty && !remarks.isEmpty
    }

    private func saveDefectReport() {
        guard isFormValid else { return }

        // Fetch current user from SupabaseManager or fall back
        let userId = SupabaseManager.shared.currentUser?.id ?? UUID()

        let newReport = DefectReport(
            vehicleId: selectedVehicleId!,
            reportedBy: userId,
            inspectionId: UUID(), // dummy inspection reference
            title: issueTitle,
            defectDescription: "Category: \(issueCategory) - \(remarks)\(isImageAttached ? " [Evidence Photo Attached]" : "")",
            severity: selectedSeverity,
            status: .open
        )

        modelContext.insert(newReport)
        
        // Also insert a notification for fleet managers
        let adminNotification = AppNotification(
            userId: UUID(), // Notify alert queue
            title: "Safety Defect Reported",
            message: "Vehicle ID \(selectedVehicleId!.uuidString.prefix(6)) reported with \(selectedSeverity.rawValue.uppercased()) severity.",
            type: .defectAlert
        )
        modelContext.insert(adminNotification)

        try? modelContext.save()

        withAnimation(.spring()) {
            showSuccessOverlay = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSuccessOverlay = false
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationView {
        ReportIssueView()
    }
    .modelContainer(for: [DefectReport.self, Vehicle.self, AppNotification.self], inMemory: true)
}
