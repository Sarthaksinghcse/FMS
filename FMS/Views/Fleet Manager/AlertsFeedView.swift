
import SwiftUI
import SwiftData
import Combine

struct AlertsFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = AlertsFeedViewModel()
    
    
    @Query(sort: \SOSAlert.createdAt, order: .reverse) private var sosAlerts: [SOSAlert]
    @Query(sort: \DefectReport.createdAt, order: .reverse) private var defectReports: [DefectReport]
    @Query private var users: [User]
    @Query private var vehicles: [Vehicle]
    
    
    @State private var selectedFilter: AlertFilterType = .all
    @State private var searchQuery: String = ""
    @State private var selectedDefectForAssignment: DefectReport? = nil
    
    enum AlertFilterType: String, CaseIterable, Identifiable {
        case all = "All"
        case sos = "SOS"
        case defects = "Defects"
        
        var id: String { self.rawValue }
    }
    
    
    private func driverName(for id: UUID) -> String {
        users.first(where: { $0.id == id })?.fullName ?? "Unknown Driver"
    }
    
    private func vehicleName(for id: UUID) -> String {
        if let vehicle = vehicles.first(where: { $0.id == id }) {
            return "\(vehicle.registrationNumber) (\(vehicle.make) \(vehicle.model))"
        }
        return "Unknown Vehicle"
    }
    
    
    struct DisplayAlert: Identifiable {
        let id: UUID
        let type: AlertType
        let title: String
        let description: String
        let severityText: String
        let severityColor: Color
        let severityBgColor: Color
        let date: Date
        let statusText: String
        let statusColor: Color
        let driverName: String
        let vehicleName: String
        let rawObject: Any 
        
        enum AlertType {
            case sos
            case defect
        }
    }
    
    private var allDisplayAlerts: [DisplayAlert] {
        var list: [DisplayAlert] = []
        
        
        for sos in sosAlerts {
            list.append(DisplayAlert(
                id: sos.id,
                type: .sos,
                title: "SOS EMERGENCY ALERT",
                description: sos.message ?? "Emergency SOS signal triggered by driver.",
                severityText: "URGENT",
                severityColor: .white,
                severityBgColor: AppTheme.Status.danger,
                date: sos.createdAt,
                statusText: sos.status == .active ? "Active" : "Resolved",
                statusColor: sos.status == .active ? AppTheme.Status.danger : AppTheme.Status.success,
                driverName: driverName(for: sos.driverId),
                vehicleName: vehicleName(for: sos.vehicleId),
                rawObject: sos
            ))
        }
        
        
        for defect in defectReports {
            let sevColor: Color
            let sevBg: Color
            switch defect.severity {
            case .high:
                sevColor = AppTheme.Status.danger
                sevBg = AppTheme.IconBg.red
            case .medium:
                sevColor = AppTheme.Status.warning
                sevBg = AppTheme.IconBg.orange
            case .low:
                sevColor = AppTheme.Brand.primary
                sevBg = AppTheme.IconBg.blue
            }
            
            let statColor: Color
            switch defect.status {
            case .open:
                statColor = AppTheme.Status.danger
            case .inProgress:
                statColor = AppTheme.Status.warning
            case .resolved:
                statColor = AppTheme.Status.success
            }
            
            list.append(DisplayAlert(
                id: defect.id,
                type: .defect,
                title: "Defect: \(defect.title)",
                description: defect.defectDescription,
                severityText: defect.severity.rawValue.uppercased(),
                severityColor: sevColor,
                severityBgColor: sevBg,
                date: defect.createdAt,
                statusText: defect.status == .open ? "Open" : (defect.status == .inProgress ? "In Progress" : "Resolved"),
                statusColor: statColor,
                driverName: driverName(for: defect.reportedBy),
                vehicleName: vehicleName(for: defect.vehicleId),
                rawObject: defect
            ))
        }
        
        
        list.sort { $0.date > $1.date }
        return list
    }
    
    private var filteredAlerts: [DisplayAlert] {
        let alerts = allDisplayAlerts
        
        
        let typedAlerts: [DisplayAlert]
        switch selectedFilter {
        case .all:
            typedAlerts = alerts
        case .sos:
            typedAlerts = alerts.filter { $0.type == .sos }
        case .defects:
            typedAlerts = alerts.filter { $0.type == .defect }
        }
        
        
        if searchQuery.isEmpty {
            return typedAlerts
        } else {
            let query = searchQuery.lowercased()
            return typedAlerts.filter {
                $0.title.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.driverName.lowercased().contains(query) ||
                $0.vehicleName.lowercased().contains(query)
            }
        }
    }
    
    
    private var activeSOSCount: Int {
        sosAlerts.filter { $0.status == .active }.count
    }
    
    private var pendingDefectsCount: Int {
        defectReports.filter { $0.status == .open || $0.status == .inProgress }.count
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
                    
                    
                    VStack(spacing: 12) {
                        
                        HStack(spacing: 12) {
                            MiniStatBadge(
                                title: "Active SOS",
                                count: activeSOSCount,
                                color: AppTheme.Status.danger,
                                systemImage: "exclamationmark.octagon.fill"
                            )
                            
                            MiniStatBadge(
                                title: "Open Defects",
                                count: pendingDefectsCount,
                                color: AppTheme.Status.warning,
                                systemImage: "wrench.and.screwdriver.fill"
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(AlertFilterType.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        
                        searchField(placeholder: "Search alerts by driver, vehicle, or issue...", text: $searchQuery)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                    .background(AppTheme.Background.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                    
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            if filteredAlerts.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bell.slash.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
                                        .padding(.top, 40)
                                    Text(searchQuery.isEmpty ? "All alerts are cleared! Good job." : "No matching alerts found.")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(filteredAlerts) { alert in
                                    AlertFeedCard(alert: alert, viewModel: viewModel, context: modelContext, sosAlerts: sosAlerts, defectReports: defectReports, selectedDefectForAssignment: $selectedDefectForAssignment)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PredictiveAlertsView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                            Text("Predictive")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.purple)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(item: $selectedDefectForAssignment) { defect in
                AssignTechnicianSheet(defect: defect, users: users, viewModel: viewModel, context: modelContext, defectReports: defectReports)
            }
        }
    }
    
    
    
    private func searchField(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray.opacity(0.6))
                .font(.system(size: 14))
            
            TextField(placeholder, text: text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.Glass.border.opacity(0.5), lineWidth: 1)
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


struct MiniStatBadge: View {
    let title: String
    let count: Int
    let color: Color
    let systemImage: String
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Background.page)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Glass.border.opacity(0.2), lineWidth: 1)
        )
    }
}


struct AlertFeedCard: View {
    let alert: AlertsFeedView.DisplayAlert
    let viewModel: AlertsFeedViewModel
    let context: ModelContext
    let sosAlerts: [SOSAlert]
    let defectReports: [DefectReport]
    @Binding var selectedDefectForAssignment: DefectReport?
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        if alert.type == .sos && alert.statusText == "Active" {
                            Circle()
                                .fill(AppTheme.Status.danger.opacity(isPulsing ? 0.35 : 0.15))
                                .frame(width: 32, height: 32)
                                .scaleEffect(isPulsing ? 1.25 : 0.95)
                        }
                        
                        Image(systemName: alert.type == .sos ? "exclamationmark.shield.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(alert.type == .sos ? AppTheme.Status.danger : AppTheme.Brand.amber)
                            .font(.system(size: alert.type == .sos ? 16 : 14, weight: .bold))
                    }
                    .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.type == .sos ? "SOS EMERGENCY ALERT" : "DEFECT REPORT")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(alert.type == .sos ? AppTheme.Status.danger : AppTheme.Text.secondary)
                            .tracking(0.5)
                        
                        Text(alert.statusText.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(alert.statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(alert.statusColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Severity Badge
                Text(alert.severityText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        alert.type == .sos && alert.statusText == "Active"
                            ? LinearGradient(colors: [AppTheme.Status.danger, AppTheme.Status.danger.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [alert.severityBgColor, alert.severityBgColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: alert.type == .sos && alert.statusText == "Active" ? AppTheme.Status.danger.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(alert.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text(alert.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider().background(Color.black.opacity(0.06))
            
            // Details Grid
            HStack(spacing: 16) {
                // Driver Detail Pill
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 28, height: 28)
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DRIVER")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(alert.driverName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                    }
                }
                .padding(.trailing, 4)
                
                // Vehicle Detail Pill
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 28, height: 28)
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VEHICLE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(alert.vehicleName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Time Detail Pill
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REPORTED")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text(alert.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                }
            }
            .padding(.vertical, 2)
            
            // Buttons block
            if alert.type == .sos {
                if let sosAlert = alert.rawObject as? SOSAlert, sosAlert.status == .active {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        _ = viewModel.resolveSOSAlert(alertId: sosAlert.id, context: context, alerts: sosAlerts)
                    } label: {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Resolve SOS Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.Status.success, AppTheme.Status.success.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppTheme.Radius.small)
                        .shadow(color: AppTheme.Status.success.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                } else {
                    resolvedBanner
                }
            } else if alert.type == .defect {
                if let defect = alert.rawObject as? DefectReport {
                    if defect.status != .resolved {
                        HStack(spacing: 10) {
                            if defect.status == .open {
                                Button {
                                    selectedDefectForAssignment = defect
                                } label: {
                                    HStack(spacing: 4) {
                                        Spacer()
                                        Image(systemName: "person.badge.plus")
                                            .font(.caption)
                                        Text("Assign Technician")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .background(AppTheme.IconBg.blue)
                                    .cornerRadius(AppTheme.Radius.small - 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Button {
                                _ = viewModel.updateDefectStatus(defectId: defect.id, newStatus: .resolved, context: context, defects: defectReports)
                            } label: {
                                HStack(spacing: 4) {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                    Text("Mark Resolved")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .foregroundColor(.white)
                                .background(AppTheme.Status.success)
                                .cornerRadius(AppTheme.Radius.small - 2)
                                .shadow(color: AppTheme.Status.success.opacity(0.15), radius: 3, x: 0, y: 1.5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)
                    } else {
                        resolvedBanner
                    }
                }
            }
        }
        .padding(18)
        .background(
            alert.type == .sos && alert.statusText == "Active"
                ? LinearGradient(
                    colors: [AppTheme.Status.danger.opacity(0.08), Color.red.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                : LinearGradient(
                    colors: [AppTheme.Background.card, AppTheme.Background.card],
                    startPoint: .top,
                    endPoint: .bottom
                  )
        )
        .cornerRadius(AppTheme.Radius.card)
        .shadow(
            color: alert.type == .sos && alert.statusText == "Active"
                ? AppTheme.Status.danger.opacity(0.08)
                : AppTheme.Shadow.card,
            radius: 12, x: 0, y: 6
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(
                    alert.type == .sos && alert.statusText == "Active"
                        ? AppTheme.Status.danger.opacity(isPulsing ? 0.70 : 0.35)
                        : AppTheme.Glass.border.opacity(0.2),
                    lineWidth: alert.type == .sos && alert.statusText == "Active" ? 1.5 : 1.0
                )
        )
        .onAppear {
            if alert.type == .sos && alert.statusText == "Active" {
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
    
    private var resolvedBanner: some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(AppTheme.Status.success)
            Text("Issue Resolved")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Status.success)
            Spacer()
        }
        .padding(.vertical, 8)
        .background(AppTheme.Status.success.opacity(0.08))
        .cornerRadius(8)
        .padding(.top, 4)
    }
}

struct AssignTechnicianSheet: View {
    let defect: DefectReport
    let users: [User]
    let viewModel: AlertsFeedViewModel
    let context: ModelContext
    let defectReports: [DefectReport]
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMechanicId: UUID? = nil
    @State private var priority: WorkOrderPriority = .medium
    @State private var notes: String = ""
    @State private var isSubmitting = false
    
    private var mechanics: [User] {
        users.filter { $0.role == .maintenance }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Header info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Defect details")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                            
                            Text(defect.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text(defect.defectDescription)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.Background.card)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Form
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // Mechanic Selector
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Assign Technician")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Technician", selection: $selectedMechanicId) {
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
                            
                            // Priority
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Priority Level")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Priority", selection: $priority) {
                                    Text("Low").tag(WorkOrderPriority.low)
                                    Text("Medium").tag(WorkOrderPriority.medium)
                                    Text("High").tag(WorkOrderPriority.high)
                                    Text("Urgent").tag(WorkOrderPriority.urgent)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Additional notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Assignment Notes")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                TextField("e.g. Please check engine sensor first...", text: $notes, axis: .vertical)
                                    .font(.system(size: 14))
                                    .lineLimit(3...6)
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(20)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        Button {
                            guard let mechanicId = selectedMechanicId else { return }
                            isSubmitting = true
                            Task {
                                let success = await viewModel.assignDefect(
                                    defectId: defect.id,
                                    mechanicId: mechanicId,
                                    priority: priority,
                                    notes: notes,
                                    context: context,
                                    defects: defectReports
                                )
                                isSubmitting = false
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                    Text("Create Work Assignment")
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedMechanicId != nil ? AppTheme.Brand.primary : Color.gray.opacity(0.5))
                            .cornerRadius(12)
                        }
                        .disabled(selectedMechanicId == nil || isSubmitting)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Assign Defect to Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
}

#Preview {
    AlertsFeedView()
}
