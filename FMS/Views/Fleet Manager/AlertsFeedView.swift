
import SwiftUI
import SwiftData
import Combine
import MapKit

struct AlertsFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = AlertsFeedViewModel()
    
    
    @Query(sort: \SOSAlert.createdAt, order: .reverse) private var sosAlerts: [SOSAlert]
    @Query(sort: \DefectReport.createdAt, order: .reverse) private var defectReports: [DefectReport]
    @Query(sort: \AppNotification.createdAt, order: .reverse) private var notifications: [AppNotification]
    @Query private var users: [User]
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    
    @Binding var showTracking: Bool
    @Binding var selectedVehicleToTrack: UUID?
    
    @State private var routeDeviations: [DBRouteDeviationAlert] = []
    
    @State private var selectedFilter: AlertFilterType = .all
    @State private var searchQuery: String = ""
    @State private var selectedDefectForAssignment: DefectReport? = nil
    @State private var selectedSOSAlert: SOSAlert? = nil
    
    enum AlertFilterType: String, CaseIterable, Identifiable {
        case all = "All"
        case sos = "SOS"
        case defects = "Defects"
        case geofence = "Geofence"
        case queries = "Queries"
        
        var id: String { self.rawValue }
    }
    
    
    private func driverName(for id: UUID) -> String {
        users.first(where: { $0.id == id })?.fullName ?? "Unknown Driver"
    }
    
    private func vehicleName(for id: UUID?) -> String {
        guard let id = id else { return "No Assigned Vehicle" }
        if let vehicle = vehicles.first(where: { $0.id == id }) {
            return "\(vehicle.registrationNumber) (\(vehicle.make) \(vehicle.model))"
        }
        return "Unknown Vehicle"
    }
    
    private func parseDriverName(from message: String) -> String {
        if message.hasPrefix("Driver ") {
            let start = message.index(message.startIndex, offsetBy: 7)
            if let range = message.range(of: " raised a query") {
                return String(message[start..<range.lowerBound])
            }
        }
        return "Unknown Driver"
    }

    private func parseVehicleName(from message: String) -> String {
        let drName = parseDriverName(from: message)
        if let driver = users.first(where: { $0.fullName.lowercased() == drName.lowercased() }) {
            if let trip = trips.first(where: { $0.driverId == driver.id && ($0.tripStatus == .started || $0.tripStatus == .assigned) }) {
                return vehicleName(for: trip.vehicleId)
            }
        }
        return "N/A"
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
            case routeDeviation
            case query
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
        
        for deviation in routeDeviations {
            list.append(DisplayAlert(
                id: deviation.id,
                type: .routeDeviation,
                title: "ROUTE DEVIATION",
                description: "Driver drifted \(Int(deviation.deviationDistanceMeters)) meters off the planned route.",
                severityText: "WARNING",
                severityColor: .white,
                severityBgColor: AppTheme.Status.warning,
                date: deviation.createdAt,
                statusText: deviation.status == .active ? "Active" : "Resolved",
                statusColor: deviation.status == .active ? AppTheme.Status.warning : AppTheme.Status.success,
                driverName: driverName(for: deviation.driverId),
                vehicleName: vehicleName(for: deviation.vehicleId),
                rawObject: deviation
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
        
        for notif in notifications {
            if notif.title.contains("Query") || notif.type == .general {
                list.append(DisplayAlert(
                    id: notif.id,
                    type: .query,
                    title: notif.title,
                    description: notif.message,
                    severityText: "INFO",
                    severityColor: .white,
                    severityBgColor: AppTheme.Brand.royalBlue,
                    date: notif.createdAt,
                    statusText: notif.isRead ? "Resolved" : "Open",
                    statusColor: notif.isRead ? AppTheme.Status.success : AppTheme.Brand.amber,
                    driverName: parseDriverName(from: notif.message),
                    vehicleName: parseVehicleName(from: notif.message),
                    rawObject: notif
                ))
            }
        }
        
        list.sort { $0.date > $1.date }
        return list
    }
    
    private var filteredAlerts: [DisplayAlert] {
        let alerts = allDisplayAlerts
        
        let typedAlerts = alerts.filter { alert in
            switch selectedFilter {
            case .all:
                return true
            case .sos:
                return alert.type == .sos
            case .defects:
                return alert.type == .defect
            case .geofence:
                return alert.type == .routeDeviation
            case .queries:
                return alert.type == .query
            }
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
                                    AlertFeedCard(alert: alert, viewModel: viewModel, context: modelContext, sosAlerts: sosAlerts, defectReports: defectReports, trips: trips, selectedDefectForAssignment: $selectedDefectForAssignment, showTracking: $showTracking, selectedVehicleToTrack: $selectedVehicleToTrack)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if alert.type == .sos, let sosAlert = alert.rawObject as? SOSAlert {
                                                selectedSOSAlert = sosAlert
                                            }
                                        }
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
                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.fmsRed)
                    }
                }


            }
            .task {
                do {
                    routeDeviations = try await SupabaseManager.shared.fetchRouteDeviationAlerts()
                } catch {
                    print("Failed to fetch route deviations: \(error)")
                }
            }
            .sheet(item: $selectedSOSAlert) { sosAlert in
                SOSAlertDetailView(
                    sosAlert: sosAlert,
                    viewModel: viewModel,
                    context: modelContext,
                    sosAlerts: sosAlerts,
                    users: users,
                    vehicles: vehicles,
                    trips: trips,
                    showTracking: $showTracking,
                    selectedVehicleToTrack: $selectedVehicleToTrack,
                    onTrackLive: {
                        dismiss()
                    }
                )
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
    let trips: [Trip]
    @Binding var selectedDefectForAssignment: DefectReport?
    @Binding var showTracking: Bool
    @Binding var selectedVehicleToTrack: UUID?
    @Environment(\.dismiss) private var dismiss
    
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
                        
                        let headerIcon: String = {
                            switch alert.type {
                            case .sos: return "exclamationmark.shield.fill"
                            case .routeDeviation: return "map.fill"
                            case .defect: return "exclamationmark.triangle.fill"
                            case .query: return "questionmark.bubble.fill"
                            }
                        }()
                        
                        let headerColor: Color = {
                            switch alert.type {
                            case .sos: return AppTheme.Status.danger
                            case .routeDeviation: return AppTheme.Brand.amber
                            case .defect: return AppTheme.Brand.amber
                            case .query: return Color.orange
                            }
                        }()
                        
                        Image(systemName: headerIcon)
                            .foregroundColor(headerColor)
                            .font(.system(size: alert.type == .sos ? 16 : 14, weight: .bold))
                    }
                    .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        let headerTitle: String = {
                            switch alert.type {
                            case .sos: return "SOS EMERGENCY ALERT"
                            case .routeDeviation: return "GEOFENCE ALERT"
                            case .defect: return "DEFECT REPORT"
                            case .query: return "DRIVER QUERY"
                            }
                        }()
                        
                        Text(headerTitle)
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
            
            if alert.type == .defect {
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
            } else if alert.type == .query {
                if let notif = alert.rawObject as? AppNotification {
                    if !notif.isRead {
                        Button {
                            notif.isRead = true
                            try? context.save()
                            Task {
                                try? await SupabaseManager.shared.updateNotification(notif.asDBNotification)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("Mark Read")
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
                        .padding(.top, 4)
                    } else {
                        resolvedBanner
                    }
                }
            } else if alert.type == .routeDeviation {
                if let deviation = alert.rawObject as? DBRouteDeviationAlert {
                    if isVehicleLive(vehicleId: deviation.vehicleId) {
                        Button {
                            dismiss()
                            selectedVehicleToTrack = deviation.vehicleId
                            showTracking = true
                        } label: {
                            HStack(spacing: 6) {
                                Spacer()
                                Image(systemName: "map.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("View on Map")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Brand.primary, AppTheme.Brand.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppTheme.Radius.small)
                            .shadow(color: AppTheme.Brand.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 4)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.Text.tertiary)
                            Text("Trip Ended")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.tertiary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(AppTheme.Radius.small)
                        .padding(.top, 4)
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
    
    private func isVehicleLive(vehicleId: UUID) -> Bool {
        trips.contains { trip in
            trip.vehicleId == vehicleId &&
            (trip.tripStatus == .started || trip.tripStatus == .inProgress)
        }
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
    AlertsFeedView(showTracking: .constant(false), selectedVehicleToTrack: .constant(nil))
}

struct SOSAlertDetailView: View {
    let sosAlert: SOSAlert
    let viewModel: AlertsFeedViewModel
    let context: ModelContext
    let sosAlerts: [SOSAlert]
    let users: [User]
    let vehicles: [Vehicle]
    let trips: [Trip]
    
    @Binding var showTracking: Bool
    @Binding var selectedVehicleToTrack: UUID?
    var onTrackLive: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPulsing = false
    
    private var driverName: String {
        users.first(where: { $0.id == sosAlert.driverId })?.fullName ?? "Unknown Driver"
    }
    
    private var driverPhone: String {
        users.first(where: { $0.id == sosAlert.driverId })?.phoneNumber ?? "+91 9452404531"
    }
    
    private var vehicleName: String {
        guard let vehicleId = sosAlert.vehicleId else { return "No Assigned Vehicle" }
        if let vehicle = vehicles.first(where: { $0.id == vehicleId }) {
            return "\(vehicle.registrationNumber) (\(vehicle.make) \(vehicle.model))"
        }
        return "Unknown Vehicle"
    }
    
    private var vehicleModel: String {
        guard let vehicleId = sosAlert.vehicleId else { return "" }
        if let vehicle = vehicles.first(where: { $0.id == vehicleId }) {
            return "\(vehicle.make) \(vehicle.model)"
        }
        return ""
    }
    
    private var vehicleCode: String {
        guard let vehicleId = sosAlert.vehicleId else { return "N/A" }
        return vehicles.first(where: { $0.id == vehicleId })?.registrationNumber ?? "Unknown"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Pulsing alert icon & header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.darkOrange.opacity(isPulsing ? 0.25 : 0.12))
                                    .frame(width: 80, height: 80)
                                    .scaleEffect(isPulsing ? 1.15 : 0.95)
                                
                                Circle()
                                    .fill(Theme.darkOrange.gradient)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Theme.darkOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 10)
                            
                            VStack(spacing: 4) {
                                Text("SOS EMERGENCY ALERT")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.darkOrange)
                                    .tracking(2.0)
                                
                                Text(sosAlert.status == .active ? "CRITICAL ACTIVE STATUS" : "RESOLVED")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(sosAlert.status == .active ? Theme.darkOrange : AppTheme.Status.success)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background((sosAlert.status == .active ? Theme.darkOrange : AppTheme.Status.success).opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        
                        // Driver and Vehicle Details
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Person & Vehicle Information")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            // Driver Card
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(AppTheme.Text.secondary.opacity(0.6))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driverName)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.primary)
                                    
                                    HStack(spacing: 6) {
                                        Text("Driver")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                        Text("•")
                                            .foregroundColor(AppTheme.Text.tertiary)
                                        
                                        Button {
                                            let cleanPhone = driverPhone.replacingOccurrences(of: " ", with: "")
                                            if let url = URL(string: "tel:\(cleanPhone)") {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Text(driverPhone)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundColor(AppTheme.Brand.primary)
                                                .underline()
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                Spacer()
                                
                                // Direct Call Button
                                Button {
                                    let cleanPhone = driverPhone.replacingOccurrences(of: " ", with: "")
                                    if let url = URL(string: "tel:\(cleanPhone)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(AppTheme.Brand.primary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Divider()
                                .background(Color.black.opacity(0.06))
                            
                            // Vehicle Card
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.Brand.primary.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "motorcycle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppTheme.Brand.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vehicleCode)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.primary)
                                    Text(vehicleModel.isEmpty ? "Assigned Vehicle" : vehicleModel)
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        // Incident description card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emergency Message")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            Text(sosAlert.message ?? "Driver \(driverName) has triggered a panic alarm. Assistance is required immediately.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                                .lineSpacing(4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        // Map card
                        let centerCoord = CLLocationCoordinate2D(latitude: sosAlert.latitude, longitude: sosAlert.longitude)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Coordinates")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                            
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(Theme.darkOrange)
                                Text(String(format: "%.5f, %.5f", sosAlert.latitude, sosAlert.longitude))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Text.primary)
                                Spacer()
                             }
                            
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: centerCoord,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            ))) {
                                Annotation(driverName, coordinate: centerCoord) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.darkOrange.opacity(0.25))
                                            .frame(width: 40, height: 40)
                                        
                                        Circle()
                                            .fill(Theme.darkOrange)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: Theme.darkOrange.opacity(0.4), radius: 5, x: 0, y: 2)
                                            .overlay(
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            }
                            .frame(height: 160)
                            .cornerRadius(10)
                            
                            HStack(spacing: 12) {
                                // Open Apple Maps
                                Button {
                                    if let url = URL(string: "maps://?q=\(sosAlert.latitude),\(sosAlert.longitude)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "map.fill")
                                        Text("Open in Maps")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(sosAlert.status == .active ? .white : AppTheme.Text.tertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(sosAlert.status == .active ? AppTheme.Brand.primary : Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(sosAlert.status != .active)
                                
                                // Live Track
                                if let vehicleId = sosAlert.vehicleId {
                                    Button {
                                        selectedVehicleToTrack = vehicleId
                                        showTracking = true
                                        dismiss()
                                        onTrackLive()
                                    } label: {
                                        HStack {
                                            Image(systemName: "location.fill")
                                            Text("Track Live")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(sosAlert.status == .active ? Theme.darkOrange : AppTheme.Text.tertiary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(sosAlert.status == .active ? Theme.darkOrange.opacity(0.12) : Color.gray.opacity(0.08))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(sosAlert.status == .active ? Theme.darkOrange.opacity(0.25) : Color.gray.opacity(0.15), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(sosAlert.status != .active)
                                }
                            }
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                        .padding(.horizontal)
                        
                        // Resolution Action / Banner
                        VStack(spacing: 12) {
                            if sosAlert.status == .active {
                                Button {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    if viewModel.resolveSOSAlert(alertId: sosAlert.id, context: context, alerts: sosAlerts) {
                                        dismiss()
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Spacer()
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Mark Issue as Resolved")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                        Spacer()
                                    }
                                    .padding(.vertical, 14)
                                    .foregroundColor(.white)
                                    .background(
                                        LinearGradient(
                                            colors: [AppTheme.Status.success, AppTheme.Status.success.opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: AppTheme.Status.success.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(AppTheme.Status.success)
                                        .font(.system(size: 16))
                                    Text("This issue is fully resolved")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Status.success)
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                                .background(AppTheme.Status.success.opacity(0.08))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("SOS Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.fmsRed)
                }
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}
