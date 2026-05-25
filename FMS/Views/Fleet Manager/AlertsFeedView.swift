






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
                                    AlertFeedCard(alert: alert, viewModel: viewModel, context: modelContext, sosAlerts: sosAlerts, defectReports: defectReports)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Alerts Feed")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: alert.type == .sos ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(alert.type == .sos ? AppTheme.Status.danger : AppTheme.Brand.amber)
                        .font(.system(size: 16))
                    
                    Text(alert.type == .sos ? "SOS EMERGENCY" : "DEFECT REPORT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                }
                
                Spacer()
                
                
                Text(alert.severityText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(alert.severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(alert.severityBgColor)
                    .cornerRadius(6)
            }
            
            
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(alert.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(3)
            }
            
            Divider().background(Color.black.opacity(0.06))
            
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("Driver")
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.tertiary)
                    
                    Text(alert.driverName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 10))
                        Text("Vehicle")
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.tertiary)
                    
                    Text(alert.vehicleName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text("Reported")
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.tertiary)
                    
                    Text(alert.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                }
            }
            
            
            if alert.type == .sos {
                if let sosAlert = alert.rawObject as? SOSAlert, sosAlert.status == .active {
                    Button {
                        _ = viewModel.resolveSOSAlert(alertId: sosAlert.id, context: context, alerts: sosAlerts)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.shield.fill")
                            Text("Resolve SOS Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(AppTheme.Status.success)
                        .cornerRadius(AppTheme.Radius.small)
                        .shadow(color: AppTheme.Status.success.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                } else {
                    resolvedBanner
                }
            } else if alert.type == .defect {
                if let defect = alert.rawObject as? DefectReport {
                    if defect.status != .resolved {
                        HStack(spacing: 8) {
                            if defect.status == .open {
                                Button {
                                    _ = viewModel.updateDefectStatus(defectId: defect.id, newStatus: .inProgress, context: context, defects: defectReports)
                                } label: {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "play.fill")
                                        Text("Start Work")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .background(AppTheme.IconBg.blue)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Button {
                                _ = viewModel.updateDefectStatus(defectId: defect.id, newStatus: .resolved, context: context, defects: defectReports)
                            } label: {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark Resolved")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .foregroundColor(.white)
                                .background(AppTheme.Status.success)
                                .cornerRadius(8)
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
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(alert.type == .sos && alert.statusText == "Active" ? AppTheme.Status.danger.opacity(0.3) : AppTheme.Glass.border.opacity(0.3), lineWidth: 1.5)
        )
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

#Preview {
    AlertsFeedView()
}
