//
//  PredictiveAlertDetailView.swift
//  FMS
//
//  Created by Naman Yadav on 27/05/26.
//

import SwiftUI
import SwiftData

struct PredictiveAlertDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var defectReports: [DefectReport]
    @Query private var inspections: [VehicleInspection]
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @Query(sort: \MaintenanceRecord.serviceDate, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    
    @State private var alerts: [DBPredictiveAlert] = []
    @State private var selectedAlertId: UUID? = nil
    @State private var isLoading = false
    @State private var isRunningAI = false
    @State private var errorMessage: String? = nil
    
    @StateObject private var schedulerViewModel = MaintenanceManagementViewModel()
    @State private var showingScheduler = false

    private var activeAlert: DBPredictiveAlert? {
        if let selectedId = selectedAlertId {
            return alerts.first { $0.id == selectedId }
        }
        return alerts.first
    }

    private var associatedVehicle: Vehicle? {
        guard let vehicleId = activeAlert?.vehicleId else { return nil }
        return vehicles.first { $0.id == vehicleId }
    }
    
    private func vehicle(for alert: DBPredictiveAlert) -> Vehicle? {
        vehicles.first { $0.id == alert.vehicleId }
    }
    
    private var maintenanceStaff: [User] {
        allUsers.filter { $0.role == .maintenance }
    }

    private var activeDefects: [DefectReport] {
        guard let vehicleId = activeAlert?.vehicleId else { return [] }
        return defectReports.filter { $0.vehicleId == vehicleId && $0.status != .resolved }
    }
    
    private var vehicleInspections: [VehicleInspection] {
        guard let vehicleId = activeAlert?.vehicleId else { return [] }
        return inspections.filter { $0.vehicleId == vehicleId }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    private var recentTripDistance: Double {
        guard let vehicleId = activeAlert?.vehicleId else { return 0.0 }
        let vehicleTrips = trips.filter { $0.vehicleId == vehicleId && $0.tripStatus == .completed }
        return vehicleTrips.reduce(0.0) { $0 + $1.distanceKm }
    }
    
    private var lastMaintenanceRecord: MaintenanceRecord? {
        guard let vehicleId = activeAlert?.vehicleId else { return nil }
        return maintenanceRecords.filter { $0.vehicleId == vehicleId }.first
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 100)
                            ProgressView()
                                .tint(AppTheme.Brand.royalBlue)
                            Text("Fetching database records...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if !alerts.isEmpty {
                        // Horizontal Selector for predicted vehicle alerts
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PREDICTION FLEET LIST (\(alerts.count))")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(alerts) { alert in
                                        PredictionSelectorCard(
                                            alert: alert,
                                            vehicle: vehicle(for: alert),
                                            isSelected: activeAlert?.id == alert.id,
                                            action: {
                                                selectedAlertId = alert.id
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)

                        if let activeAlert = activeAlert {
                            // Diagnostic Status Header Card
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "cpu.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(AppTheme.Brand.royalBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("SMART TELEMATICS DETECTED")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(AppTheme.Brand.royalBlue)
                                        Text("AI Maintenance Prediction")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.Text.primary)
                                    }
                                    Spacer()
                                    
                                    Text(activeAlert.riskLevel.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            activeAlert.riskLevel.localizedCaseInsensitiveCompare("critical") == .orderedSame ||
                                            activeAlert.riskLevel.localizedCaseInsensitiveCompare("high") == .orderedSame ? AppTheme.Status.danger : AppTheme.Brand.amber
                                        )
                                        .cornerRadius(6)
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("AI Diagnostic Summary")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(AppTheme.Text.primary)
                                    
                                    if let explanation = activeAlert.llmExplanation, !explanation.isEmpty {
                                        Text(explanation)
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .lineSpacing(4)
                                    } else if let reasons = activeAlert.triggeredReasons, !reasons.isEmpty {
                                        Text(reasons.joined(separator: "\n"))
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .lineSpacing(4)
                                    } else {
                                        Text("AI predicts maintenance required due to telemetry risk score of \(Int(activeAlert.riskScore * 100))%.")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                    
                                    if let action = activeAlert.suggestedAction, !action.isEmpty {
                                        Text("Recommended Action: \(action)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(AppTheme.Brand.primary)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            .padding(16)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                    .stroke(AppTheme.Glass.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                            
                            // Telemetry & AI Diagnostic Input Factors Card
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Telemetry & AI Diagnostic Input Factors")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                                
                                // Odometer & Runs
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "speedometer")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.Brand.royalBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Mileage & Fleet Runs")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        
                                        Text("Current Odometer: \(Int(associatedVehicle?.odometerReading ?? 0)) km")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                        
                                        Text("Recent Trip Activity: \(Int(recentTripDistance)) km completed run")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                }
                                
                                Divider().background(Color.black.opacity(0.06))
                                
                                // Pre/Post-Trip Inspection & Defect Status
                                HStack(alignment: .top, spacing: 12) {
                                    let hasActiveDefects = !activeDefects.isEmpty
                                    ZStack {
                                        Circle()
                                            .fill(hasActiveDefects ? AppTheme.Status.danger.opacity(0.1) : AppTheme.Status.success.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: hasActiveDefects ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(hasActiveDefects ? AppTheme.Status.danger : AppTheme.Status.success)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Inspection & Defect Status")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        
                                        if hasActiveDefects {
                                            ForEach(activeDefects) { defect in
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(AppTheme.Status.danger)
                                                        .frame(width: 4, height: 4)
                                                    Text("\(defect.title) (\(defect.severity.rawValue.uppercased()))")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(AppTheme.Text.secondary)
                                                }
                                            }
                                        } else {
                                            Text("No active defects reported in pre/post-trip inspections.")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        }
                                        
                                        if let lastInspection = vehicleInspections.first {
                                            let typeText = lastInspection.inspectionType == .preTrip ? "Pre-Trip" : "Post-Trip"
                                            let dateText = lastInspection.createdAt.formatted(date: .abbreviated, time: .shortened)
                                            Text("Last \(typeText) Checkup: \(dateText)")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(AppTheme.Text.tertiary)
                                            
                                            if let remarks = lastInspection.remarks, !remarks.trimmingCharacters(in: .whitespaces).isEmpty {
                                                Text("\"\(remarks)\"")
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .foregroundColor(AppTheme.Text.secondary)
                                                    .italic()
                                                    .padding(6)
                                                    .background(Color.black.opacity(0.03))
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }
                                }
                                
                                Divider().background(Color.black.opacity(0.06))
                                
                                // Service Interval
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.Brand.amber.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "wrench.and.screwdriver.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.Brand.amber)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Scheduled Service & Interval")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        
                                        if let nextService = associatedVehicle?.nextServiceDate {
                                            Text("Next Scheduled Service: \(nextService.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(AppTheme.Brand.primary)
                                        } else {
                                            Text("No upcoming scheduled services.")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        }
                                        
                                        if let lastRecord = lastMaintenanceRecord {
                                            Text("Last Completed Service: \(lastRecord.serviceType) on \(lastRecord.serviceDate.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        } else if let lastService = associatedVehicle?.lastServiceDate {
                                            Text("Last Completed Service: \(lastService.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        } else {
                                            Text("No completed service history logged.")
                                                .font(.system(size: 11))
                                                .foregroundColor(AppTheme.Text.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                    .stroke(AppTheme.Glass.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                            
                            // Vehicle Info
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Associated Vehicle Details")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                                
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                            .frame(width: 50, height: 50)
                                        Image(systemName: "truck.box.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(AppTheme.Brand.royalBlue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(associatedVehicle?.model ?? "Vehicle Model")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        Text("Reg No: \(associatedVehicle?.registrationNumber ?? "MH-12-AB-3456")")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                                    .stroke(AppTheme.Glass.border, lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                    } else {
                        // Empty State if no active alert
                        VStack(spacing: 16) {
                            Spacer().frame(height: 50)
                            Image(systemName: "sparkles.radiance")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.Brand.royalBlue.opacity(0.6))
                            
                            Text("No Active Diagnostic Alerts")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("Run AI Diagnostic analysis to process vehicle telematics and identify potential maintenance risks in the database.")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Text.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Status.danger)
                            .padding(.horizontal)
                    }
                    
                    // AI Run / Refresh & Direct Schedule Action Buttons
                    VStack(spacing: 12) {
                        if let activeAlert = activeAlert {
                            Button {
                                // Populate scheduler state
                                schedulerViewModel.resetForm()
                                schedulerViewModel.selectedVehicleId = activeAlert.vehicleId
                                
                                // Map risk level to priority
                                switch activeAlert.riskLevel.lowercased() {
                                case "critical":
                                    schedulerViewModel.selectedPriority = .urgent
                                case "high":
                                    schedulerViewModel.selectedPriority = .high
                                case "medium":
                                    schedulerViewModel.selectedPriority = .medium
                                default:
                                    schedulerViewModel.selectedPriority = .low
                                }
                                
                                // Populate title and description
                                let component = activeAlert.triggeredReasons?.first ?? "Component"
                                schedulerViewModel.newTitle = "Preventive Maintenance: \(component)"
                                schedulerViewModel.newDescription = """
                                Scheduled via AI Smart Diagnostic recommendation.
                                
                                AI Explanation:
                                \(activeAlert.llmExplanation ?? "Potential breakdown risk detected.")
                                
                                Suggested Action:
                                \(activeAlert.suggestedAction ?? "Perform full system diagnostic and repair.")
                                """
                                
                                showingScheduler = true
                            } label: {
                                HStack {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                    Text("Schedule Maintenance Task")
                                }
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.royalBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(12)
                                .shadow(color: AppTheme.Brand.royalBlue.opacity(0.25), radius: 6, y: 3)
                            }
                        }
                        
                        Button {
                            runAIDiagnostic()
                        } label: {
                            HStack {
                                if isRunningAI {
                                    ProgressView().tint(AppTheme.Brand.royalBlue)
                                        .padding(.trailing, 8)
                                    Text("Analyzing Telematics...")
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                } else {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                    Text("Run AI Diagnostic Analysis")
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                }
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.Brand.royalBlue.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.Brand.royalBlue.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(isRunningAI || isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .padding(.vertical, 20)
            }
            .sheet(isPresented: $showingScheduler) {
                ScheduleWorkOrderSheet(
                    viewModel: schedulerViewModel,
                    vehicles: vehicles,
                    staff: maintenanceStaff,
                    isPresented: $showingScheduler
                )
            }
        }
        .navigationTitle("AI Smart Diagnostic")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchAlertsFromDatabase()
        }
    }
    

    private func fetchAlertsFromDatabase() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await SupabaseManager.shared.fetchPredictiveAlerts(onlyActive: true)
            
            // Filter to ensure only the latest unique prediction is shown per vehicle
            var uniqueAlerts: [DBPredictiveAlert] = []
            var seenVehicles = Set<UUID>()
            for alert in fetched {
                if !seenVehicles.contains(alert.vehicleId) {
                    seenVehicles.insert(alert.vehicleId)
                    uniqueAlerts.append(alert)
                }
            }
            
            await MainActor.run {
                self.alerts = uniqueAlerts
                if self.selectedAlertId == nil || !uniqueAlerts.contains(where: { $0.id == self.selectedAlertId }) {
                    self.selectedAlertId = uniqueAlerts.first?.id
                }
            }
        } catch {
            errorMessage = "Failed to load alerts: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func runAIDiagnostic() {
        isRunningAI = true
        errorMessage = nil
        Task {
            do {
                // Invoke Supabase Deno Edge Function "predict-maintenance"
                let response: [String: [DBPredictiveAlert]] = try await AIServiceManager.shared.invoke("predict-maintenance")
                
                await MainActor.run {
                    if let newAlerts = response["alerts"] {
                        // Filter unique by vehicle
                        var uniqueAlerts: [DBPredictiveAlert] = []
                        var seenVehicles = Set<UUID>()
                        for alert in newAlerts {
                            if !seenVehicles.contains(alert.vehicleId) {
                                seenVehicles.insert(alert.vehicleId)
                                uniqueAlerts.append(alert)
                            }
                        }
                        self.alerts = uniqueAlerts
                        self.selectedAlertId = uniqueAlerts.first?.id
                    } else {
                        Task { await fetchAlertsFromDatabase() }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "AI diagnostic run failed: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isRunningAI = false
            }
        }
    }
}

struct PredictionSelectorCard: View {
    let alert: DBPredictiveAlert
    let vehicle: Vehicle?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        let regNo = vehicle?.registrationNumber ?? alert.vehicleId.uuidString.prefix(8).uppercased()
        let model = vehicle?.model ?? "Unknown Vehicle"
        
        let riskColor: Color = {
            switch alert.riskLevel.lowercased() {
            case "critical": return AppTheme.Status.danger
            case "high": return AppTheme.Brand.accent
            case "medium": return AppTheme.Brand.amber
            default: return AppTheme.Status.success
            }
        }()
        
        return Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(regNo)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : AppTheme.Text.primary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(riskColor)
                        .frame(width: 8, height: 8)
                }
                
                Text(model)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.Text.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                    Text(String(format: "Risk: %.0f%%", alert.riskScore * 100))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(isSelected ? .white : riskColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 140)
            .background(
                isSelected
                    ? AnyView(LinearGradient(colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.royalBlue.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyView(AppTheme.Background.card)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.Brand.royalBlue : AppTheme.Glass.border.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.Brand.royalBlue.opacity(0.2) : Color.clear, radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        PredictiveAlertDetailView()
    }
}
