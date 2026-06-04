






import SwiftUI
import SwiftData
import Combine
import Supabase

struct MaintenanceSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Background.card)
        .cornerRadius(16)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}

struct MaintenanceManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = MaintenanceManagementViewModel()
    
    @Query(sort: \WorkOrder.createdAt, order: .reverse) private var workOrders: [WorkOrder]
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var defectReports: [DefectReport]
    @Query(sort: \MaintenanceRecord.serviceDate, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    
    @State private var showingScheduler = false
    @State private var showingCompletionDialog = false
    @State private var selectedWorkOrderForCompletion: WorkOrder? = nil
    @State private var finalCostString: String = ""
    @State private var selectedTab: Int = 0 
    @State private var sortByAIPriority = false
    
    @State private var predictiveAlerts: [DBPredictiveAlert] = []
    @State private var isLoadingAlerts = false
    
    private var maintenanceStaff: [User] {
        allUsers.filter { $0.role == .maintenance }
    }
    
    private var activeWorkOrders: [WorkOrder] {
        let base = workOrders.filter { $0.status == .open || $0.status == .inProgress }
        let sortedBase: [WorkOrder]
        if sortByAIPriority {
            sortedBase = AIWorkOrderService.shared.sorted(base, defects: defectReports, vehicles: vehicles)
        } else {
            sortedBase = base.sorted { $0.createdAt > $1.createdAt }
        }
        
        return sortedBase.sorted { (wo1, wo2) -> Bool in
            let isPending1 = wo1.workDescription.contains("[PENDING_APPROVAL]")
            let isPending2 = wo2.workDescription.contains("[PENDING_APPROVAL]")
            
            if isPending1 && !isPending2 {
                return true
            } else if !isPending1 && isPending2 {
                return false
            } else {
                let idx1 = sortedBase.firstIndex(where: { $0.id == wo1.id }) ?? 0
                let idx2 = sortedBase.firstIndex(where: { $0.id == wo2.id }) ?? 0
                return idx1 < idx2
            }
        }
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
    
    private func getPredictiveAlert(for vehicleId: UUID) -> DBPredictiveAlert? {
        predictiveAlerts.first { $0.vehicleId == vehicleId }
    }
    
    private func currentStatusText(for order: WorkOrder) -> String {
        if order.workDescription.contains("[PENDING_APPROVAL]") {
            return "Awaiting Approval"
        } else if order.workDescription.contains("[REJECTED]") {
            return "Rejected"
        } else if order.workDescription.contains("[INFO_REQUESTED]") {
            return "Info Requested"
        }
        
        switch order.status {
        case .open: return "Assigned"
        case .inProgress: return "Repair In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    private func currentStepIndex(for order: WorkOrder) -> Int {
        if order.status == .completed { return 6 }
        if order.workDescription.contains("[PENDING_APPROVAL]") { return 3 }
        
        switch order.status {
        case .open:
            return 0
        case .inProgress:
            let desc = order.workDescription.lowercased()
            if desc.contains("inspection") { return 1 }
            if desc.contains("diagnos") { return 2 }
            if desc.contains("parts") { return 4 }
            if desc.contains("quality") || desc.contains("check") { return 5 }
            return 4
        default:
            return 0
        }
    }
    
    private func getDowntimeString(for order: WorkOrder) -> String {
        let endDate = order.completedAt ?? Date()
        let interval = endDate.timeIntervalSince(order.createdAt)
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days == 0 {
            return "\(hours) Hours"
        } else {
            return "\(days) Day \(hours) Hours"
        }
    }
    
    private func fetchAllPredictiveAlerts() async {
        isLoadingAlerts = true
        do {
            let alerts = try await SupabaseManager.shared.fetchPredictiveAlerts(onlyActive: true)
            await MainActor.run {
                self.predictiveAlerts = alerts
                self.isLoadingAlerts = false
            }
        } catch {
            print("Failed to load Gemini predictions: \(error)")
            self.isLoadingAlerts = false
        }
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppTheme.Background.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            // Top Summary Cards Grid
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                MaintenanceSummaryCard(
                                    title: "Active Orders",
                                    value: "\(workOrders.filter { $0.status == .open || $0.status == .inProgress }.count)",
                                    icon: "wrench.and.screwdriver.fill",
                                    color: AppTheme.Brand.primary
                                )
                                
                                MaintenanceSummaryCard(
                                    title: "Awaiting Approval",
                                    value: "\(workOrders.filter { $0.status == .open && $0.workDescription.contains("[PENDING_APPROVAL]") }.count)",
                                    icon: "checkmark.shield.fill",
                                    color: AppTheme.Brand.amber
                                )
                                
                                MaintenanceSummaryCard(
                                    title: "In Workshop",
                                    value: "\(vehicles.filter { $0.status == .inMaintenance }.count)",
                                    icon: "box.truck.fill",
                                    color: AppTheme.Brand.teal
                                )
                                
                                MaintenanceSummaryCard(
                                    title: "Critical Alerts",
                                    value: "\(workOrders.filter { ($0.status == .open || $0.status == .inProgress) && $0.priority == .urgent }.count)",
                                    icon: "exclamationmark.triangle.fill",
                                    color: AppTheme.Status.danger
                                )
                            }
                            .padding(.bottom, 8)
                            
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
            }
            .navigationTitle("Maintenance Hub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.royalBlue)
                    .font(.system(.body, design: .rounded))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.resetForm()
                        showingScheduler = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
            .task {
                await SupabaseManager.shared.syncAllData(context: modelContext)
                await fetchAllPredictiveAlerts()
            }
            .sheet(isPresented: $showingScheduler) {
                ScheduleWorkOrderSheet(viewModel: viewModel, vehicles: vehicles, staff: maintenanceStaff, isPresented: $showingScheduler)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingCompletionDialog) {
                if let wo = selectedWorkOrderForCompletion {
                    CompleteWorkOrderSheet(viewModel: viewModel, workOrder: wo, finalCostString: $finalCostString, isPresented: $showingCompletionDialog) { cost in
                        if viewModel.completeWork(workOrderId: wo.id, finalCost: cost, context: modelContext, workOrders: workOrders, vehicles: vehicles) {
                            showingCompletionDialog = false
                            selectedWorkOrderForCompletion = nil
                        }
                    }
                    .interactiveDismissDisabled()
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
        
        let localRecord = maintenanceRecords.first { $0.workOrderId == order.id }
        let currentCost = localRecord?.cost ?? order.estimatedCost ?? 0.0
        
        let alert = getPredictiveAlert(for: order.vehicleId)
        let riskScorePercent = alert != nil ? Int(alert!.riskScore * 100) : 0
        let suggestedAction = alert?.suggestedAction ?? "Schedule standard inspection"
        
        let step = currentStepIndex(for: order) + 1
        let totalSteps = 7
        let percent = Double(step) / Double(totalSteps)
        
        let isPending = order.workDescription.contains("[PENDING_APPROVAL]")
        
        let cardContent = VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(order.priority.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(priColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priBg)
                    .cornerRadius(6)
                
                Text("WO-\(order.id.uuidString.prefix(4).uppercased())")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                
                Spacer()
                
                Text(currentStatusText(for: order))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(order.workDescription.contains("[PENDING_APPROVAL]") ? AppTheme.Brand.amber : priColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(getVehicleName(for: order.vehicleId))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(order.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
            }
            
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.1), lineWidth: 3)
                        .frame(width: 38, height: 38)
                    
                    Circle()
                        .trim(from: 0, to: alert != nil ? CGFloat(alert!.riskScore) : 0.05)
                        .stroke(
                            alert?.riskLevel.localizedCaseInsensitiveCompare("critical") == .orderedSame ||
                            alert?.riskLevel.localizedCaseInsensitiveCompare("high") == .orderedSame
                            ? AppTheme.Status.danger
                            : Theme.darkOrange,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 38, height: 38)
                        .rotationEffect(Angle(degrees: -90))
                    
                    Text("\(riskScorePercent)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }
                .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Failure Risk")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.darkOrange)
                    
                    Text(suggestedAction)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Text.primary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(10)
            .background(Theme.darkOrange.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.darkOrange.opacity(0.15), lineWidth: 1)
            )
            
            Divider().background(Color.black.opacity(0.06))
            
            VStack(spacing: 8) {
                HStack {
                    Label("Assigned Tech", systemImage: "person.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    Text(getStaffName(for: order.assignedTo))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
                
                HStack {
                    Label("Downtime Tracker", systemImage: "clock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    Text(getDowntimeString(for: order))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Status.danger)
                }
                
                HStack {
                    Label("Cost Estimate", systemImage: "indianrupeesign.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    
                    let estStr = order.estimatedCost != nil ? String(format: "₹%.2f", order.estimatedCost!) : "Awaiting"
                    let actStr = localRecord != nil ? String(format: "₹%.2f", currentCost) : "Awaiting actual"
                    
                    Text("Est: \(estStr) | Act: \(actStr)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
                
                HStack {
                    Label("Last Updated", systemImage: "calendar")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    Text(order.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                }
            }
            
            Divider().background(Color.black.opacity(0.06))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Repair Progress Timeline")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Spacer()
                    Text("\(currentStatusText(for: order)) (\(step)/\(totalSteps))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Brand.primary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.Brand.primary)
                            .frame(width: geo.size.width * CGFloat(percent), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.top, 2)
            
            if isPending {
                HStack(spacing: 8) {
                    Button {
                        approveWorkOrder(order)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Approve")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(AppTheme.Status.success)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button {
                        declineWorkOrder(order)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                            Text("Decline")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(AppTheme.Status.danger)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    NavigationLink(destination: WorkOrderDetailedView(order: order).environment(\.modelContext, modelContext)) {
                        HStack {
                            Spacer()
                            Image(systemName: "eye.fill")
                            Text("View")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(AppTheme.Brand.primary)
                        .background(AppTheme.Brand.primary.opacity(0.1))
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
        
        return Group {
            if isPending {
                cardContent
            } else {
                NavigationLink(destination: WorkOrderDetailedView(order: order).environment(\.modelContext, modelContext)) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
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
    }
    
    private func approveWorkOrder(_ order: WorkOrder) {
        order.status = .open
        order.workDescription = order.workDescription
            .replacingOccurrences(of: "[PENDING_APPROVAL] ", with: "")
            .replacingOccurrences(of: "[PENDING_APPROVAL]", with: "")
        try? modelContext.save()
        
        let dbWO = order.asDBWorkOrder
        Task {
            do {
                try await SupabaseManager.shared.updateWorkOrder(dbWO)
                
                // Add a notification for the mechanic
                let notif = DBNotification(
                    id: UUID(),
                    userId: order.assignedTo,
                    title: "✅ Work Order Approved",
                    message: "Fleet Manager has approved work order \"\(order.title)\". It is now scheduled.",
                    type: .maintenance,
                    isRead: false,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.createNotification(notif)
            } catch {
                print("Failed to approve work order on Supabase: \(error)")
            }
        }
    }
    
    private func declineWorkOrder(_ order: WorkOrder) {
        order.status = .cancelled
        order.workDescription = order.workDescription
            .replacingOccurrences(of: "[PENDING_APPROVAL] ", with: "")
            .replacingOccurrences(of: "[PENDING_APPROVAL]", with: "")
        if !order.workDescription.contains("[REJECTED]") {
            order.workDescription = "[REJECTED] " + order.workDescription
        }
        
        if let vehicle = vehicles.first(where: { $0.id == order.vehicleId }) {
            vehicle.status = .active
            vehicle.updatedAt = Date()
            
            // Sync vehicle status to Supabase
            let dbVehicle = DBVehicle(
                id: vehicle.id,
                vehicleNumber: vehicle.registrationNumber,
                model: vehicle.model,
                manufacturer: vehicle.make,
                year: vehicle.year,
                vin: vehicle.vinNumber,
                licensePlate: vehicle.registrationNumber,
                status: .available,
                assignedDriverId: vehicle.assignedDriverId,
                lastServiceDate: vehicle.lastServiceDate,
                createdAt: vehicle.createdAt
            )
            Task {
                try? await SupabaseManager.shared.updateVehicle(dbVehicle)
            }
        }
        
        try? modelContext.save()
        
        let dbWO = order.asDBWorkOrder
        Task {
            do {
                try await SupabaseManager.shared.updateWorkOrder(dbWO)
                
                // Add a notification for the technician
                let notif = DBNotification(
                    id: UUID(),
                    userId: order.assignedTo,
                    title: "❌ Work Order Declined",
                    message: "Fleet Manager has declined work order \"\(order.title)\".",
                    type: .maintenance,
                    isRead: false,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.createNotification(notif)
            } catch {
                print("Failed to decline work order on Supabase: \(error)")
            }
        }
    }
}


struct ScheduleWorkOrderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: MaintenanceManagementViewModel
    let vehicles: [Vehicle]
    let staff: [User]
    @Binding var isPresented: Bool
    var onScheduleSuccess: (() -> Void)? = nil
    
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
                            onScheduleSuccess?()
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
