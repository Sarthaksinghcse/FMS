//
//  CreateWorkOrderView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import SwiftData

struct CreateWorkOrderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // SwiftData Queries
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query private var allUsers: [User]
    
    // Form State
    @State private var selectedVehicleId: UUID?
    @State private var title: String = ""
    @State private var issueType: String = ""
    @State private var selectedPriority: WorkOrderPriority = .medium
    @State private var selectedMechanicId: UUID?
    @State private var notes: String = ""
    @State private var estimatedCost: String = ""
    
    // UI state
    @State private var showSuccessOverlay = false
    @State private var hasAttemptedSave = false
    
    // Filter maintenance personnel
    private var mechanics: [User] {
        allUsers.filter { $0.role == .maintenance }
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomCenteredHeaderView(title: "New Work Order")
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Form Card
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // Section 1: Vehicle & Mechanic
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Assignment")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .textCase(.uppercase)
                                
                                // Vehicle Selector
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Select Vehicle")
                                        .font(.system(size: 13, weight: .semibold))
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
                                
                                // Mechanic Selector
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Assign Mechanic")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    
                                    Picker("Mechanic", selection: $selectedMechanicId) {
                                        Text("Select technician...").tag(UUID?.none)
                                        ForEach(mechanics) { mechanic in
                                            Text(mechanic.fullName).tag(UUID?.some(mechanic.id))
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
                            
                            // Section 2: Issue details
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Work Details")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .textCase(.uppercase)
                                
                                // Title
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Work Order Title")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    TextField("e.g. Engine Overheating, Brake Squeal", text: $title)
                                        .font(.system(size: 14))
                                        .padding(12)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                }
                                
                                // Issue Type
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Service/Issue Category")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    TextField("e.g. Brakes, Transmission, Engine", text: $issueType)
                                        .font(.system(size: 14))
                                        .padding(12)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                }
                                
                                // Priority
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Priority Level")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    
                                    Picker("Priority", selection: $selectedPriority) {
                                        Text("Low").tag(WorkOrderPriority.low)
                                        Text("Medium").tag(WorkOrderPriority.medium)
                                        Text("High").tag(WorkOrderPriority.high)
                                        Text("Urgent").tag(WorkOrderPriority.urgent)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            
                            Divider()
                            
                            // Section 3: Cost & Notes
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Estimation & Remarks")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .textCase(.uppercase)
                                
                                // Est. Cost
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Estimated Cost (INR)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    TextField("e.g. 5000", text: $estimatedCost)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 14))
                                        .padding(12)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                }
                                
                                // Notes
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Detailed Repair Notes")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    TextEditor(text: $notes)
                                        .frame(minHeight: 100)
                                        .padding(6)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(20)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        
                        // Submit Button
                        Button(action: saveWorkOrder) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                Text("Create Work Order")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                isFormValid ? AppTheme.Brand.primary : Color.gray.opacity(0.5)
                            )
                            .cornerRadius(12)
                            .shadow(color: isFormValid ? AppTheme.Brand.primary.opacity(0.3) : Color.clear, radius: 8, y: 3)
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            } // end VStack
            
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
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(showSuccessOverlay ? 1.0 : 0.5)
                        
                        Text("Work Order Created")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        
                        Text("Task successfully assigned and logged into local records.")
                            .font(.system(size: 13, weight: .medium))
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
        } // end ZStack
        .navigationBarHidden(true)
    } // end body

    // Validation
    private var isFormValid: Bool {
        selectedVehicleId != nil && !title.isEmpty && !issueType.isEmpty && selectedMechanicId != nil
    }
    
    // Save
    private func saveWorkOrder() {
        guard isFormValid else { return }
        
        let cost = Double(estimatedCost) ?? 0.0
        
        let newOrder = WorkOrder(
            vehicleId: selectedVehicleId!,
            defectReportId: nil,
            assignedTo: selectedMechanicId!,
            title: title,
            workDescription: "\(issueType) - \(notes)",
            priority: selectedPriority,
            status: .open,
            estimatedCost: cost > 0 ? cost : nil
        )
        
        modelContext.insert(newOrder)
        try? modelContext.save()
        
        // Show success and dismiss
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
        CreateWorkOrderView()
    }
    .modelContainer(for: [WorkOrder.self, Vehicle.self, User.self], inMemory: true)
}
