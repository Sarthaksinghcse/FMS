






import SwiftUI
import SwiftData
import Combine






struct MaintenanceManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = MaintenanceManagementViewModel()
    
    
    @Query(sort: \WorkOrder.createdAt, order: .reverse) private var workOrders: [WorkOrder]
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var defectReports: [DefectReport]
    
    @State private var showingScheduler = false
    @State private var showingCompletionDialog = false
    @State private var selectedWorkOrderForCompletion: WorkOrder? = nil
    @State private var finalCostString: String = ""
    @State private var selectedTab: Int = 0 
    @State private var sortByAIPriority = false
    
    private var maintenanceStaff: [User] {
        allUsers.filter { $0.role == .maintenance }
    }
    
    private var activeWorkOrders: [WorkOrder] {
        let base = workOrders.filter { $0.status == .open || $0.status == .inProgress }
        if sortByAIPriority {
            return AIWorkOrderService.shared.sorted(base, defects: defectReports, vehicles: vehicles)
        }
        return base
    }
    
    private var historicWorkOrders: [WorkOrder] {
        let base = workOrders.filter { $0.status == .completed || $0.status == .cancelled }
        if sortByAIPriority {
            return AIWorkOrderService.shared.sorted(base, defects: defectReports, vehicles: vehicles)
        }
        return base
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
                    
                    
                    HStack(spacing: 12) {
                        Picker("Orders", selection: $selectedTab) {
                            Text("Active (\(activeWorkOrders.count))").tag(0)
                            Text("History (\(historicWorkOrders.count))").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                sortByAIPriority.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: sortByAIPriority ? "sparkles" : "sparkles.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text("AI Sort")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundColor(sortByAIPriority ? .white : .purple)
                            .background(sortByAIPriority ? Color.purple : Color.purple.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
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
            
            .sheet(isPresented: $showingScheduler) {
                ScheduleWorkOrderSheet(viewModel: viewModel, vehicles: vehicles, staff: maintenanceStaff, isPresented: $showingScheduler)
            }
            
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
                
                Text(order.priority.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(priColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priBg)
                    .cornerRadius(6)
                
                let localDefect = defectReports.first(where: { $0.vehicleId == order.vehicleId })
                let localVehicle = vehicles.first(where: { $0.id == order.vehicleId })
                let score = AIWorkOrderService.shared.computePriorityScore(workOrder: order, defect: localDefect, vehicle: localVehicle)
                
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text(String(format: "AI Score: %.0f", score))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
                
                Spacer()
                
                
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
