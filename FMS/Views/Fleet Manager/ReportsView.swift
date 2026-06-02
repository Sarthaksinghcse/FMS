import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Live data queries from SwiftData
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query private var defectReports: [DefectReport]
    @Query private var workOrders: [WorkOrder]
    
    @State private var selectedPeriod: String = "All Time"
    let periods = ["Today", "This Week", "This Month", "All Time"]
    
    // MARK: - Dynamic Calculations
    
    private var filteredRecords: [MaintenanceRecord] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case "Today":
            let start = calendar.startOfDay(for: now)
            return maintenanceRecords.filter { $0.serviceDate >= start }
        case "This Week":
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return maintenanceRecords.filter { $0.serviceDate >= start }
        case "This Month":
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return maintenanceRecords.filter { $0.serviceDate >= start }
        default:
            return maintenanceRecords
        }
    }
    
    private var totalMaintenanceCost: Double {
        filteredRecords.reduce(0.0) { $0 + $1.cost }
    }
    
    private var averageServiceCost: Double {
        guard !filteredRecords.isEmpty else { return 0.0 }
        return totalMaintenanceCost / Double(filteredRecords.count)
    }
    
    private var activeWorkJobsCount: Int {
        workOrders.filter { $0.status == .inProgress || $0.status == .open }.count
    }
    
    private var openDefectsCount: Int {
        defectReports.filter { $0.status == .open || $0.status == .inProgress }.count
    }
    
    // MARK: - Category Cost Breakdown
    struct ServiceCategoryCost: Identifiable {
        let id = UUID()
        let category: String
        let icon: String
        let color: Color
        let cost: Double
    }
    
    private var categoryCosts: [ServiceCategoryCost] {
        var oilCost = 0.0
        var tireCost = 0.0
        var brakeCost = 0.0
        var generalCost = 0.0
        
        for record in filteredRecords {
            let type = record.serviceType.lowercased()
            if type.contains("oil") || type.contains("filter") || type.contains("fluid") {
                oilCost += record.cost
            } else if type.contains("tire") || type.contains("wheel") || type.contains("alignment") {
                tireCost += record.cost
            } else if type.contains("brake") || type.contains("pad") || type.contains("rotor") {
                brakeCost += record.cost
            } else {
                generalCost += record.cost
            }
        }
        
        return [
            ServiceCategoryCost(category: "Engine & Fluids", icon: "drop.fill", color: AppTheme.Brand.amber, cost: oilCost),
            ServiceCategoryCost(category: "Tires & Alignment", icon: "circle.circle.fill", color: AppTheme.Brand.teal, cost: tireCost),
            ServiceCategoryCost(category: "Brakes & Rotors", icon: "exclamationmark.shield.fill", color: AppTheme.Status.danger, cost: brakeCost),
            ServiceCategoryCost(category: "General / Other", icon: "wrench.fill", color: AppTheme.Brand.primary, cost: generalCost)
        ]
    }
    
    private var totalCategorySum: Double {
        categoryCosts.reduce(0.0) { $0 + $1.cost }
    }
    
    // MARK: - Overdue Maintenance (Criterion 3)
    private var overdueVehicles: [Vehicle] {
        vehicles.filter { vehicle in
            if vehicle.status == .inMaintenance { return true }
            if let next = vehicle.nextServiceDate, next < Date() { return true }
            if vehicle.odometerReading > 50000 && vehicle.lastServiceDate == nil { return true }
            return false
        }
    }
    
    // MARK: - Frequently Maintained Vehicles (Criterion 3)
    struct VehicleServiceCount: Identifiable {
        let id: UUID
        let vehicle: Vehicle
        let count: Int
    }
    
    private var frequentlyMaintained: [VehicleServiceCount] {
        var counts: [UUID: Int] = [:]
        for record in maintenanceRecords {
            counts[record.vehicleId, default: 0] += 1
        }
        
        return counts.map { vehicleId, count in
            let vehicle = vehicles.first(where: { $0.id == vehicleId }) ?? Vehicle(
                registrationNumber: "Unknown",
                vinNumber: "",
                make: "Unknown",
                model: "Vehicle",
                year: 2023,
                vehicleType: .car,
                fuelType: .petrol,
                odometerReading: 0
            )
            return VehicleServiceCount(id: vehicleId, vehicle: vehicle, count: count)
        }
        .sorted { $0.count > $1.count }
        .filter { $0.count > 0 }
    }
    
    private var maxServiceCount: Double {
        Double(frequentlyMaintained.first?.count ?? 1)
    }
    
    private func vehicleForRecord(_ record: MaintenanceRecord) -> Vehicle? {
        vehicles.first(where: { $0.id == record.vehicleId })
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        headerSection
                        
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(periods, id: \.self) { period in
                                Text(period).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        
                        kpiCardsSection
                        performanceInsightsSection
                        costBreakdownSection
                        overdueAlertsSection
                        frequentlyMaintainedSection
                        historyLogSection
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .font(.system(.body, design: .rounded))
                }
            }
        }
    }
    
    // MARK: - @ViewBuilder Modular Sections
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Maintenance Reports")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text("Real-time fleet maintenance analytics and fleet performance insights.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            
            NavigationLink {
                AIReportsView()
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.darkOrange.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.darkOrange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Executive AI Report")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            Text("Drafted by AI analyst")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Theme.darkOrange.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.darkOrange.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    @ViewBuilder
    private var kpiCardsSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ReportKpiCard(
                title: "Total Expenses",
                value: String(format: "₹%.0f", totalMaintenanceCost),
                subtitle: "\(filteredRecords.count) Service Logs",
                icon: "indianrupeesign.circle.fill",
                color: AppTheme.Brand.primary,
                bgColor: AppTheme.IconBg.blue
            )
            
            ReportKpiCard(
                title: "Average / Incident",
                value: String(format: "₹%.0f", averageServiceCost),
                subtitle: selectedPeriod,
                icon: "chart.bar.fill",
                color: AppTheme.Brand.violet,
                bgColor: AppTheme.IconBg.violet
            )
            
            ReportKpiCard(
                title: "Active Work Orders",
                value: "\(activeWorkJobsCount)",
                subtitle: "Assigned Jobs",
                icon: "wrench.and.screwdriver.fill",
                color: AppTheme.Brand.amber,
                bgColor: AppTheme.IconBg.amber
            )
            
            ReportKpiCard(
                title: "Open Defect Alerts",
                value: "\(openDefectsCount)",
                subtitle: "Needs Attention",
                icon: "exclamationmark.octagon.fill",
                color: AppTheme.Status.danger,
                bgColor: AppTheme.IconBg.red
            )
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var performanceInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppTheme.Brand.amber)
                Text("Performance Insights")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if !overdueVehicles.isEmpty {
                    Text("• Critical: \(overdueVehicles.count) vehicles require urgent scheduled servicing to maintain optimal operational performance.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Status.danger)
                } else {
                    Text("• Fleet Status: Optimal. No overdue maintenance jobs or pending schedules detected today.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Status.success)
                }
                
                // Analyze highest spending category
                let maxCat = categoryCosts.max(by: { $0.cost < $1.cost })
                if let highest = maxCat, highest.cost > 0 {
                    Text("• Expense Warning: '\(highest.category)' is the highest cost driver at \(String(format: "₹%.0f", highest.cost)), representing \(String(format: "%.0f%%", (totalCategorySum > 0 ? highest.cost / totalCategorySum : 0.0) * 100)) of your filtered budget.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                }
                
                Text("• Recommendation: Rotate tires every 10,000 km to decrease tire costs by up to 15% and increase fuel economy.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(AppTheme.Text.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(AppTheme.Glass.border.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var costBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Service Category Cost Breakdown")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            
            VStack(spacing: 14) {
                ForEach(categoryCosts) { cat in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(cat.color)
                                Text(cat.category)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                            Spacer()
                            Text(String(format: "₹%.0f (%.0f%%)", cat.cost, (totalCategorySum > 0 ? cat.cost / totalCategorySum : 0.0) * 100))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black.opacity(0.04))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cat.color.gradient)
                                    .frame(width: geo.size.width * CGFloat(totalCategorySum > 0 ? cat.cost / totalCategorySum : 0.0), height: 6)
                            }
                        }
                        .frame(height: 6)
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
                .stroke(AppTheme.Glass.border.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var overdueAlertsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("⚠️ Overdue Maintenance Alerts")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Spacer()
                Text("\(overdueVehicles.count) Vehicles")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(overdueVehicles.isEmpty ? AppTheme.Status.success : AppTheme.Status.danger)
                    .clipShape(Capsule())
            }
            
            if overdueVehicles.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Status.success)
                        Text("All vehicles current")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(overdueVehicles) { vehicle in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.IconBg.red)
                                    .frame(width: 38, height: 38)
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Status.danger)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.registrationNumber)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                Text("\(vehicle.make) \(vehicle.model) · Odo: \(Int(vehicle.odometerReading)) km")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(vehicle.status == .inMaintenance ? "Maintenance" : "Overdue")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(vehicle.status == .inMaintenance ? AppTheme.Brand.amber : AppTheme.Status.danger)
                                    .cornerRadius(6)
                                
                                if let nextDate = vehicle.nextServiceDate {
                                    Text("Due: " + formatDateShort(nextDate))
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.02))
                        .cornerRadius(10)
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
                .stroke(AppTheme.Glass.border.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var frequentlyMaintainedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("📊 Frequently Maintained Vehicles")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            
            if frequentlyMaintained.isEmpty {
                Text("No service records found.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(frequentlyMaintained.prefix(4)) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.vehicle.registrationNumber)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    Text("\(item.vehicle.make) \(item.vehicle.model)")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                Text("\(item.count) Services")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.violet)
                            }
                            
                            // Progress bar visually showing frequency
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.black.opacity(0.03))
                                        .frame(height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(AppTheme.Brand.violet.gradient)
                                        .frame(width: geo.size.width * CGFloat(Double(item.count) / maxServiceCount), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.02))
                        .cornerRadius(10)
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
                .stroke(AppTheme.Glass.border.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var historyLogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🔧 Live Maintenance Log History")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.top, 14)
            
            if filteredRecords.isEmpty {
                Text("No records found in this time period.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredRecords.sorted(by: { $0.serviceDate > $1.serviceDate })) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.serviceType)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                    
                                    Text((vehicleForRecord(record)?.registrationNumber ?? "Unknown Vehicle") + " · " + formatDateLong(record.serviceDate))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text(String(format: "₹%.0f", record.cost))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Brand.primary)
                            }
                            
                            if let notes = record.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.03))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 18)
                        
                        Divider().padding(.horizontal, 18)
                    }
                }
            }
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(AppTheme.Glass.border.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
    
    // MARK: - Helpers
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    private func formatDateLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Report KPI Card View

struct ReportKpiCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let bgColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(AppTheme.Glass.border.opacity(0.15), lineWidth: 1)
        )
    }
}
