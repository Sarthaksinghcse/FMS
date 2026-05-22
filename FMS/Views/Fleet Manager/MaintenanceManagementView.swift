//
//  MaintenanceManagementView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Maintenance Management View Model
@MainActor
final class MaintenanceManagementViewModel: ObservableObject {
    @Published var errorMessage: String? = nil
    
    // Add work order state
    @Published var newTitle: String = ""
    @Published var newDescription: String = ""
    @Published var selectedVehicleId: UUID? = nil
    @Published var selectedStaffId: UUID? = nil
    @Published var selectedPriority: WorkOrderPriority = .medium
    @Published var estimatedCostString: String = ""
    
    func resetForm() {
        newTitle = ""
        newDescription = ""
        selectedVehicleId = nil
        selectedStaffId = nil
        selectedPriority = .medium
        estimatedCostString = ""
        errorMessage = nil
    }
    
    /// Validates and schedules a new Work Order.
    /// Updates the vehicle status to .inMaintenance.
    /// BACKEND DEVS: Add Supabase integration inside this function.
    func scheduleWorkOrder(context: ModelContext, vehicles: [Vehicle], staff: [User]) -> Bool {
        errorMessage = nil
        
        let cleanedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedDesc = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let vehicleId = selectedVehicleId else {
            errorMessage = "Please select a vehicle."
            return false
        }
        
        guard let staffId = selectedStaffId else {
            errorMessage = "Please assign a maintenance staff member."
            return false
        }
        
        guard !cleanedTitle.isEmpty else {
            errorMessage = "Please enter a work order title."
            return false
        }
        
        guard let selectedVehicle = vehicles.first(where: { $0.id == vehicleId }) else {
            errorMessage = "Selected vehicle not found."
            return false
        }
        
        guard staff.contains(where: { $0.id == staffId }) else {
            errorMessage = "Selected staff member not found."
            return false
        }
        
        let estCost = Double(estimatedCostString)
        if !estimatedCostString.isEmpty && estCost == nil {
            errorMessage = "Please enter a valid estimated cost."
            return false
        }
        
        // 1. Create the work order
        let workOrder = WorkOrder(
            vehicleId: vehicleId,
            assignedTo: staffId,
            title: cleanedTitle,
            workDescription: cleanedDesc,
            priority: selectedPriority,
            status: .open,
            estimatedCost: estCost
        )
        
        // 2. Update vehicle status to inMaintenance
        selectedVehicle.status = .inMaintenance
        selectedVehicle.updatedAt = Date()
        
        context.insert(workOrder)
        
        do {
            try context.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = "Failed to create work order: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    /// Starts work on a Work Order (updates status to inProgress)
    /// BACKEND DEVS: Sync with cloud DB here
    func startWork(workOrderId: UUID, context: ModelContext, workOrders: [WorkOrder]) -> Bool {
        errorMessage = nil
        guard let wo = workOrders.first(where: { $0.id == workOrderId }) else {
            errorMessage = "Work order not found."
            return false
        }
        
        wo.status = .inProgress
        
        do {
            try context.save()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            return true
        } catch {
            errorMessage = "Failed to update work order: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Completes the work order. Creates a MaintenanceRecord and resets the Vehicle status to .active
    /// BACKEND DEVS: Sync with cloud DB here
    func completeWork(workOrderId: UUID, finalCost: Double, context: ModelContext, workOrders: [WorkOrder], vehicles: [Vehicle]) -> Bool {
        errorMessage = nil
        guard let wo = workOrders.first(where: { $0.id == workOrderId }) else {
            errorMessage = "Work order not found."
            return false
        }
        
        guard let vehicle = vehicles.first(where: { $0.id == wo.vehicleId }) else {
            errorMessage = "Associated vehicle not found."
            return false
        }
        
        // 1. Mark completed
        wo.status = .completed
        wo.completedAt = Date()
        
        // 2. Restore vehicle status to active (or inactive depending on preference, active is default)
        vehicle.status = .active
        vehicle.lastServiceDate = Date()
        // Automatically schedule next service in 3 months
        vehicle.nextServiceDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
        vehicle.updatedAt = Date()
        
        // 3. Create MaintenanceRecord
        let maintenanceRecord = MaintenanceRecord(
            vehicleId: wo.vehicleId,
            workOrderId: wo.id,
            serviceType: wo.title,
            serviceDate: Date(),
            cost: finalCost,
            notes: wo.workDescription + "\nScheduled Priority: \(wo.priority.rawValue)",
            performedBy: wo.assignedTo
        )
        context.insert(maintenanceRecord)
        
        do {
            try context.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = "Failed to complete work order: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Cancels a Work Order, restoring the Vehicle status to .active
    /// BACKEND DEVS: Sync with cloud DB here
    func cancelWork(workOrderId: UUID, context: ModelContext, workOrders: [WorkOrder], vehicles: [Vehicle]) -> Bool {
        errorMessage = nil
        guard let wo = workOrders.first(where: { $0.id == workOrderId }) else {
            errorMessage = "Work order not found."
            return false
        }
        
        wo.status = .cancelled
        
        if let vehicle = vehicles.first(where: { $0.id == wo.vehicleId }) {
            // Check if there are other active work orders for this vehicle before marking active
            let otherActive = workOrders.contains { $0.vehicleId == wo.vehicleId && $0.id != wo.id && ($0.status == .open || $0.status == .inProgress) }
            if !otherActive {
                vehicle.status = .active
                vehicle.updatedAt = Date()
            }
        }
        
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Failed to cancel: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Maintenance Management View
struct MaintenanceManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = MaintenanceManagementViewModel()
    
    // SwiftData Queries
    @Query(sort: \WorkOrder.createdAt, order: .reverse) private var workOrders: [WorkOrder]
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    
    @State private var showingScheduler = false
    @State private var showingCompletionDialog = false
    @State private var selectedWorkOrderForCompletion: WorkOrder? = nil
    @State private var finalCostString: String = ""
    @State private var selectedTab: Int = 0 // 0: Active, 1: History
    
    private var maintenanceStaff: [User] {
        allUsers.filter { $0.role == .maintenance }
    }
    
    private var activeWorkOrders: [WorkOrder] {
        workOrders.filter { $0.status == .open || $0.status == .inProgress }
    }
    
    private var historicWorkOrders: [WorkOrder] {
        workOrders.filter { $0.status == .completed || $0.status == .cancelled }
    }
    
    private func getVehicleName(for id: UUID) -> String {
        if let vehicle = vehicles.first(where: { $0.id == id }) {
            return "\(vehicle.registrationNumber) (\(vehicle.make) \(vehicle.model))"
        }
        return "Unknown Vehicle"
    }
    
    private func getStaffName(for id: UUID) -> String {
        allUsers.first(where: { $0.id == id })?.fullName ?? "Unknown Staff"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                    
                    // Top Segmented Picker
                    Picker("Orders", selection: $selectedTab) {
                        Text("Active (\(activeWorkOrders.count))").tag(0)
                        Text("History (\(historicWorkOrders.count))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.Background.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            let items = selectedTab == 0 ? activeWorkOrders : historicWorkOrders
                            
                            if items.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
                                        .padding(.top, 60)
                                    Text(selectedTab == 0 ? "No active maintenance work orders." : "No historic records found.")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(items) { order in
                                    workOrderCard(order)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                
                // Add Floating Action Button for scheduling
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            viewModel.resetForm()
                            showingScheduler = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                Text("New Order")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(AppTheme.Brand.primary)
                            .cornerRadius(28)
                            .shadow(color: AppTheme.Brand.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Maintenance Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .font(.system(.body, design: .rounded))
                }
            }
            // Sheet for Scheduling
            .sheet(isPresented: $showingScheduler) {
                ScheduleWorkOrderSheet(viewModel: viewModel, vehicles: vehicles, staff: maintenanceStaff, isPresented: $showingScheduler)
            }
            // Dialog/Sheet for Completing
            .sheet(isPresented: $showingCompletionDialog) {
                if let wo = selectedWorkOrderForCompletion {
                    CompleteWorkOrderSheet(viewModel: viewModel, workOrder: wo, finalCostString: $finalCostString, isPresented: $showingCompletionDialog) { cost in
                        if viewModel.completeWork(workOrderId: wo.id, finalCost: cost, context: modelContext, workOrders: workOrders, vehicles: vehicles) {
                            showingCompletionDialog = false
                            selectedWorkOrderForCompletion = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Work Order Card Helper View
    
    private func workOrderCard(_ order: WorkOrder) -> some View {
        let priColor: Color
        let priBg: Color
        switch order.priority {
        case .low:
            priColor = AppTheme.Brand.primary
            priBg = AppTheme.IconBg.blue
        case .medium:
            priColor = AppTheme.Brand.teal
            priBg = AppTheme.IconBg.teal
        case .high:
            priColor = AppTheme.Brand.accent
            priBg = AppTheme.IconBg.orange
        case .urgent:
            priColor = AppTheme.Status.danger
            priBg = AppTheme.IconBg.red
        }
        
        let statColor: Color
        let statText: String
        switch order.status {
        case .open:
            statColor = AppTheme.Status.danger
            statText = "Open"
        case .inProgress:
            statColor = AppTheme.Status.warning
            statText = "In Progress"
        case .completed:
            statColor = AppTheme.Status.success
            statText = "Completed"
        case .cancelled:
            statColor = .gray
            statText = "Cancelled"
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Priority Badge
                Text(order.priority.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(priColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priBg)
                    .cornerRadius(6)
                
                Spacer()
                
                // Status Badge
                Text(statText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(statColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(order.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(order.workDescription)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            
            Divider().background(Color.black.opacity(0.06))
            
            VStack(spacing: 8) {
                HStack {
                    Label("Vehicle", systemImage: "truck.box.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    Text(getVehicleName(for: order.vehicleId))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
                
                HStack {
                    Label("Assigned Tech", systemImage: "person.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    Text(getStaffName(for: order.assignedTo))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
                
                if let cost = order.estimatedCost {
                    HStack {
                        Label("Est. Cost", systemImage: "indianrupeesign.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Spacer()
                        Text(String(format: "₹%.2f", cost))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                    }
                }
            }
            
            // Actions
            if order.status == .open {
                Button {
                    _ = viewModel.startWork(workOrderId: order.id, context: modelContext, workOrders: workOrders)
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                        Text("Start Maintenance Work")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(AppTheme.Brand.primary)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            } else if order.status == .inProgress {
                HStack(spacing: 8) {
                    Button {
                        _ = viewModel.cancelWork(workOrderId: order.id, context: modelContext, workOrders: workOrders, vehicles: vehicles)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Cancel Order")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(AppTheme.Status.danger)
                        .background(AppTheme.IconBg.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        selectedWorkOrderForCompletion = order
                        finalCostString = order.estimatedCost != nil ? String(format: "%.0f", order.estimatedCost!) : ""
                        showingCompletionDialog = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Work")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(AppTheme.Status.success)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(order.status == .inProgress ? AppTheme.Status.warning.opacity(0.3) : AppTheme.Glass.border.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.Status.danger)
                .font(.system(size: 16))
            
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
        }
        .padding(14)
        .background(AppTheme.Status.danger.opacity(0.08))
        .cornerRadius(AppTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Status.danger.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Add / Schedule Work Order Sheet
struct ScheduleWorkOrderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: MaintenanceManagementViewModel
    let vehicles: [Vehicle]
    let staff: [User]
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(spacing: 16) {
                            
                            // Vehicle Picker Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("1. Select Vehicle")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                                
                                Picker("Select Vehicle", selection: $viewModel.selectedVehicleId) {
                                    Text("Choose...").tag(nil as UUID?)
                                    ForEach(vehicles) { vehicle in
                                        Text("\(vehicle.registrationNumber) (\(vehicle.make))").tag(vehicle.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.02))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.Glass.border, lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Staff Picker Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("2. Assign Maintenance Tech")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                                
                                Picker("Assign Tech", selection: $viewModel.selectedStaffId) {
                                    Text("Choose...").tag(nil as UUID?)
                                    ForEach(staff) { tech in
                                        Text(tech.fullName).tag(tech.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.02))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.Glass.border, lineWidth: 1)
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Details
                            VStack(alignment: .leading, spacing: 14) {
                                Text("3. Order Details")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                                
                                CustomAddTextField(label: "Job Title", placeholder: "e.g. Engine Overheating Fix / Brake replacement", icon: "wrench.and.screwdriver.fill", text: $viewModel.newTitle)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Work Description")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    TextEditor(text: $viewModel.newDescription)
                                        .frame(height: 100)
                                        .padding(8)
                                        .background(Color.black.opacity(0.02))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppTheme.Glass.border, lineWidth: 1)
                                        )
                                }
                                
                                CustomAddTextField(label: "Estimated Cost (₹)", placeholder: "e.g. 5000", icon: "indianrupeesign.circle.fill", text: $viewModel.estimatedCostString, keyboardType: .decimalPad)
                            }
                            
                            // Priority
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Priority Level")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Priority", selection: $viewModel.selectedPriority) {
                                    Text("Low").tag(WorkOrderPriority.low)
                                    Text("Medium").tag(WorkOrderPriority.medium)
                                    Text("High").tag(WorkOrderPriority.high)
                                    Text("Urgent").tag(WorkOrderPriority.urgent)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Schedule Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schedule") {
                        if viewModel.scheduleWorkOrder(context: modelContext, vehicles: vehicles, staff: staff) {
                            isPresented = false
                        }
                    }
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.Status.danger)
                .font(.system(size: 16))
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
            Spacer()
        }
        .padding(14)
        .background(AppTheme.Status.danger.opacity(0.08))
        .cornerRadius(AppTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Status.danger.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Complete Work Order Sheet (Input cost)
struct CompleteWorkOrderSheet: View {
    @ObservedObject var viewModel: MaintenanceManagementViewModel
    let workOrder: WorkOrder
    @Binding var finalCostString: String
    @Binding var isPresented: Bool
    let onComplete: (Double) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Complete Work Order")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Brand.primary)
                        
                        Text("Please specify the final actual cost of maintenance for \"\(workOrder.title)\" to log expenses.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                        
                        CustomAddTextField(label: "Final Cost (₹)", placeholder: "e.g. 5200", icon: "indianrupeesign.circle.fill", text: $finalCostString, keyboardType: .numberPad)
                    }
                    .padding(18)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                    .padding(16)
                    
                    Spacer()
                }
                .padding(.top, 16)
            }
            .navigationTitle("Finalize Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") {
                        if let cost = Double(finalCostString), cost >= 0 {
                            onComplete(cost)
                        } else {
                            viewModel.errorMessage = "Please enter a valid final cost."
                        }
                    }
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
}

#Preview {
    MaintenanceManagementView()
}
