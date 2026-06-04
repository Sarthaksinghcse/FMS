import SwiftUI
import UIKit

@Observable
final class FleetAnalyticsViewModel {

    // MARK: - Types

    enum TimePeriod: String, CaseIterable {
        case today     = "Today"
        case thisWeek  = "This Week"
        case thisMonth = "This Month"
    }

    struct DailyTripData: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }
    

    struct TripStatusData: Identifiable {
        let id = UUID()
        let status: TripStatus
        let count: Int
        var color: Color  { status.badgeColor }
        var label: String { status.displayName }
    }

    struct VehicleTypeData: Identifiable {
        let id = UUID()
        let type: VehicleType
        let count: Int
        var color: Color  { type.iconColor }
        var label: String { type.displayName }
        var icon: String  { type.icon }
    }

    struct FuelTypeData: Identifiable {
        let id = UUID()
        let type: FuelType
        let count: Int
        var label: String { type.displayName }
        var icon: String  { type.icon }
        var color: Color {
            switch type {
            case .petrol:   return AppTheme.Brand.accent
            case .diesel:   return AppTheme.Brand.amber
            case .electric: return AppTheme.Status.success
            case .hybrid:   return AppTheme.Brand.teal
            }
        }
    }

    struct PriorityData: Identifiable {
        let id = UUID()
        let priority: WorkOrderPriority
        let count: Int
        var label: String {
            switch priority {
            case .urgent: return "Urgent"
            case .high:   return "High"
            case .medium: return "Medium"
            case .low:    return "Low"
            }
        }
        var color: Color {
            switch priority {
            case .urgent: return AppTheme.Status.danger
            case .high:   return AppTheme.Brand.accent
            case .medium: return AppTheme.Brand.amber
            case .low:    return AppTheme.Status.success
            }
        }
        var icon: String {
            switch priority {
            case .urgent: return "exclamationmark.triangle.fill"
            case .high:   return "arrow.up.circle.fill"
            case .medium: return "minus.circle.fill"
            case .low:    return "arrow.down.circle.fill"
            }
        }
    }

    struct DriverTripStat: Identifiable {
        let id = UUID()
        let driverName: String
        let tripCount: Int
        let completedDistance: Double
    }

    // MARK: - State

    var selectedPeriod: TimePeriod = .thisMonth

    // MARK: - Helpers

    var periodStartDate: Date {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .today:
            return calendar.startOfDay(for: Date())
        case .thisWeek:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .thisMonth:
            return calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }
    }

    var periodLabel: String { selectedPeriod.rawValue }

    // MARK: - Fleet Metrics (current snapshot)

    func fleetUtilization(vehicles: [Vehicle]) -> Double {
        guard !vehicles.isEmpty else { return 0 }
        let active = vehicles.filter { $0.status == .active }.count
        return Double(active) / Double(vehicles.count)
    }

    func vehicleStatusCounts(vehicles: [Vehicle]) -> (active: Int, maintenance: Int, inactive: Int) {
        let active      = vehicles.filter { $0.status == .active }.count
        let maintenance = vehicles.filter { $0.status == .inMaintenance }.count
        let inactive    = vehicles.count - active - maintenance
        return (active, maintenance, inactive)
    }

    func vehicleTypeBreakdown(vehicles: [Vehicle]) -> [VehicleTypeData] {
        VehicleType.allCases.map { type in
            VehicleTypeData(type: type, count: vehicles.filter { $0.vehicleType == type }.count)
        }.filter { $0.count > 0 }
    }

    func fuelTypeBreakdown(vehicles: [Vehicle]) -> [FuelTypeData] {
        FuelType.allCases.map { type in
            FuelTypeData(type: type, count: vehicles.filter { $0.fuelType == type }.count)
        }.filter { $0.count > 0 }
    }

    func vehiclesUsedInPeriod(vehicles: [Vehicle], trips: [Trip]) -> Int {
        let periodTrips = tripsInPeriod(from: trips)
        return Set(periodTrips.map { $0.vehicleId }).count
    }

    func distancePerVehicle(vehicles: [Vehicle], trips: [Trip]) -> Double {
        let used = vehiclesUsedInPeriod(vehicles: vehicles, trips: trips)
        guard used > 0 else { return 0 }
        return totalDistance(trips: trips) / Double(used)
    }

    // MARK: - Trip Metrics (period-filtered)

    func tripsInPeriod(from trips: [Trip]) -> [Trip] {
        let start = periodStartDate
        return trips.filter { $0.createdAt >= start }
    }

    func tripCompletionRate(trips: [Trip]) -> Double {
        let filtered   = tripsInPeriod(from: trips)
        let completed  = filtered.filter { $0.tripStatus == .completed }.count
        let finalized  = filtered.filter { $0.tripStatus == .completed || $0.tripStatus == .cancelled }.count
        guard finalized > 0 else { return 0 }
        return Double(completed) / Double(finalized)
    }

    func totalDistance(trips: [Trip]) -> Double {
        tripsInPeriod(from: trips)
            .filter { $0.tripStatus == .completed }
            .reduce(0) { $0 + $1.distanceKm }
    }

    func averageTripDistance(trips: [Trip]) -> Double {
        let completed = tripsInPeriod(from: trips).filter { $0.tripStatus == .completed }
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.distanceKm } / Double(completed.count)
    }

    func tripStatusBreakdown(trips: [Trip]) -> [TripStatusData] {
        let filtered = tripsInPeriod(from: trips)
        return [TripStatus.completed, .inProgress, .started, .assigned, .cancelled]
            .map { status in
                TripStatusData(status: status, count: filtered.filter { $0.tripStatus == status }.count)
            }
            .filter { $0.count > 0 }
    }

    func tripsInPeriodCount(trips: [Trip]) -> Int {
        tripsInPeriod(from: trips).count
    }

    // MARK: - 7-Day Trend (always last 7 days, independent of period)

    func sevenDayTrend(trips: [Trip]) -> [DailyTripData] {
        let calendar = Calendar.current
        return (0..<7).reversed().map { offset in
            let date    = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: Date())!)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
            let count   = trips.filter { $0.createdAt >= date && $0.createdAt < nextDay }.count
            return DailyTripData(date: date, count: count)
        }
    }

    // MARK: - Maintenance (period-filtered)

    func openWorkOrdersCount(workOrders: [WorkOrder]) -> Int {
        workOrders.filter { $0.status == .open || $0.status == .inProgress }.count
    }

    func workOrdersInPeriod(workOrders: [WorkOrder]) -> Int {
        let start = periodStartDate
        return workOrders.filter { $0.createdAt >= start }.count
    }

    func completedWorkOrdersInPeriod(workOrders: [WorkOrder]) -> Int {
        let start = periodStartDate
        return workOrders.filter { $0.createdAt >= start && $0.status == .completed }.count
    }

    func defectsInPeriod(defects: [DefectReport]) -> Int {
        let start = periodStartDate
        return defects.filter { $0.createdAt >= start }.count
    }

    func defectResolutionRate(defects: [DefectReport]) -> Double {
        guard !defects.isEmpty else { return 0 }
        let resolved = defects.filter { $0.status == .resolved }.count
        return Double(resolved) / Double(defects.count)
    }

    func defectResolutionRateInPeriod(defects: [DefectReport]) -> Double {
        let start = periodStartDate
        let periodDefects = defects.filter { $0.createdAt >= start }
        guard !periodDefects.isEmpty else { return 0 }
        let resolved = periodDefects.filter { $0.status == .resolved }.count
        return Double(resolved) / Double(periodDefects.count)
    }

    func workOrderPriorities(workOrders: [WorkOrder]) -> [PriorityData] {
        let active = workOrders.filter { $0.status == .open || $0.status == .inProgress }
        return [WorkOrderPriority.urgent, .high, .medium, .low].map { p in
            PriorityData(priority: p, count: active.filter { $0.priority == p }.count)
        }
    }

    func maintenanceCost(records: [MaintenanceRecord]) -> Double {
        let start = periodStartDate
        return records.filter { $0.serviceDate >= start }.reduce(0) { $0 + $1.cost }
    }

    // MARK: - Driver Metrics

    func driverStats(users: [User]) -> (total: Int, active: Int, rate: Double) {
        let drivers       = users.filter { $0.role == .driver }
        let activeDrivers = drivers.filter { $0.isActive }.count
        let rate          = drivers.isEmpty ? 0.0 : Double(activeDrivers) / Double(drivers.count)
        return (drivers.count, activeDrivers, rate)
    }

    func driverTripBreakdown(users: [User], trips: [Trip]) -> [DriverTripStat] {
        let drivers = users.filter { $0.role == .driver }
        let periodTrips = tripsInPeriod(from: trips)

        return drivers.map { driver in
            let driverTrips = periodTrips.filter { $0.driverId == driver.id }
            let dist = driverTrips.filter { $0.tripStatus == .completed }.reduce(0.0) { $0 + $1.distanceKm }
            return DriverTripStat(
                driverName: driver.fullName,
                tripCount: driverTrips.count,
                completedDistance: dist
            )
        }
        .sorted { $0.tripCount > $1.tripCount }
    }

    func totalDriverTrips(users: [User], trips: [Trip]) -> Int {
        let periodTrips = tripsInPeriod(from: trips)
        let driverIds = Set(users.filter { $0.role == .driver }.map { $0.id })
        return periodTrips.filter { driverIds.contains($0.driverId) }.count
    }

    // MARK: - Formatting

    func formatDistance(_ km: Double) -> String {
        if km >= 10_000 {
            return String(format: "%.1fK", km / 1000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: km)) ?? "\(Int(km))"
    }

    func formatPercent(_ rate: Double) -> String {
        String(format: "%.0f%%", rate * 100)
    }

    func formatCost(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₹" + (formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))")
    }

    // MARK: - PDF Generation

    private let primaryBlue = UIColor(red: 0.15, green: 0.38, blue: 0.90, alpha: 1.0)
    private let darkOrange = UIColor(red: 0.93, green: 0.46, blue: 0.0, alpha: 1.0)
    private let lightBlueBg = UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0)
    private let borderGray = UIColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1.0)
    private let textPrimary = UIColor(red: 0.11, green: 0.14, blue: 0.19, alpha: 1.0)
    private let textSecondary = UIColor.secondaryLabel
    private let textMuted = UIColor.tertiaryLabel

    func generatePDFData(
        vehicles: [Vehicle],
        users: [User],
        trips: [Trip],
        workOrders: [WorkOrder],
        defectReports: [DefectReport],
        maintenanceRecords: [MaintenanceRecord]
    ) -> Data {
        let pageWidth: CGFloat  = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat     = 40
        let contentWidth        = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        let data = renderer.pdfData { context in
            let cgContext = context.cgContext
            
            var y: CGFloat = margin
            
            // Helper to start a new page and draw background/footer elements
            func startNewPage() {
                context.beginPage()
                drawPageFooter(context: context, pageHeight: pageHeight, margin: margin, dateFormatter: dateFormatter)
                y = margin
            }
            
            startNewPage()

            // ─── HEADER BANNER ───────────────────────────────────────────
            let rect = CGRect(x: margin, y: y, width: contentWidth, height: 80)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
            cgContext.saveGState()
            lightBlueBg.setFill()
            path.fill()
            
            // Draw primary blue left accent bar
            let leftBarRect = CGRect(x: margin, y: y, width: 6, height: 80)
            let leftBarPath = UIBezierPath(roundedRect: leftBarRect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 10, height: 10))
            primaryBlue.setFill()
            leftBarPath.fill()
            cgContext.restoreGState()
            
            // Title Text
            let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: primaryBlue
            ]
            ("FLEET ANALYTICS REPORT" as NSString).draw(at: CGPoint(x: margin + 20, y: y + 18), withAttributes: titleAttrs)
            
            // Subtitle Details
            let detailsFont = UIFont.systemFont(ofSize: 10, weight: .medium)
            let detailsAttrs: [NSAttributedString.Key: Any] = [
                .font: detailsFont,
                .foregroundColor: textSecondary
            ]
            let subStr = "Period: \(selectedPeriod.rawValue.uppercased())  •  Generated: \(dateFormatter.string(from: Date()))"
            (subStr as NSString).draw(at: CGPoint(x: margin + 20, y: y + 44), withAttributes: detailsAttrs)
            
            y += 80 + 20

            // --- Overview KPIs ---
            y = drawSectionHeader("Overview", context: context, y: y, x: margin)
            let utilRate   = formatPercent(fleetUtilization(vehicles: vehicles))
            let compRate   = formatPercent(tripCompletionRate(trips: trips))
            let totalDist  = formatDistance(totalDistance(trips: trips)) + " km"
            let maintCost  = formatCost(maintenanceCost(records: maintenanceRecords))

            let kpiData = [
                ("Fleet Utilization", utilRate),
                ("Trip Completion", compRate),
                ("Total Distance", totalDist),
                ("Maintenance Cost", maintCost)
            ]
            y = drawKPIGrid(kpiData, context: context, y: y, x: margin, width: contentWidth)
            y += 16

            // --- Vehicle Analytics ---
            y = drawDivider(context: context, y: y, x: margin, width: contentWidth)
            y += 12
            y = drawSectionHeader("Vehicle Analytics", context: context, y: y, x: margin)

            let counts = vehicleStatusCounts(vehicles: vehicles)
            let vehUsed = vehiclesUsedInPeriod(vehicles: vehicles, trips: trips)
            let vehicleRows = [
                ("Total Vehicles", "\(vehicles.count)"),
                ("Active", "\(counts.active)"),
                ("In Maintenance", "\(counts.maintenance)"),
                ("Inactive", "\(counts.inactive)"),
                ("Vehicles Used (\(periodLabel))", "\(vehUsed)")
            ]
            y = drawTable(vehicleRows, context: context, y: y, x: margin, width: contentWidth)
            y += 12

            let typeData = vehicleTypeBreakdown(vehicles: vehicles)
            if !typeData.isEmpty {
                if y > pageHeight - 140 {
                    startNewPage()
                }
                y = drawSubHeader("By Type", context: context, y: y, x: margin)
                let typeRows = typeData.map { ($0.label, "\($0.count)") }
                y = drawTable(typeRows, context: context, y: y, x: margin, width: contentWidth)
                y += 12
            }

            let fuelData = fuelTypeBreakdown(vehicles: vehicles)
            if !fuelData.isEmpty {
                if y > pageHeight - 140 {
                    startNewPage()
                }
                y = drawSubHeader("By Fuel", context: context, y: y, x: margin)
                let fuelRows = fuelData.map { ($0.label, "\($0.count)") }
                y = drawTable(fuelRows, context: context, y: y, x: margin, width: contentWidth)
                y += 12
            }

            // Check if we need a new page
            if y > pageHeight - 180 {
                startNewPage()
            }

            // --- Driver Analytics ---
            y = drawDivider(context: context, y: y, x: margin, width: contentWidth)
            y += 12
            y = drawSectionHeader("Driver Analytics", context: context, y: y, x: margin)

            let dStats = driverStats(users: users)
            let driverRows = [
                ("Total Drivers", "\(dStats.total)"),
                ("Active Drivers", "\(dStats.active)"),
                ("Availability", formatPercent(dStats.rate)),
                ("Driver Trips (\(periodLabel))", "\(totalDriverTrips(users: users, trips: trips))")
            ]
            y = drawTable(driverRows, context: context, y: y, x: margin, width: contentWidth)
            y += 12

            let driverBreakdown = driverTripBreakdown(users: users, trips: trips)
            if !driverBreakdown.isEmpty {
                if y > pageHeight - 180 {
                    startNewPage()
                }
                y = drawSubHeader("Driver Trip Breakdown (\(periodLabel))", context: context, y: y, x: margin)
                let dRows = driverBreakdown.map { ("\($0.driverName)", "\($0.tripCount) trips  •  \(formatDistance($0.completedDistance)) km") }
                y = drawTable(dRows, context: context, y: y, x: margin, width: contentWidth)
                y += 12
            }

            // Check if we need a new page
            if y > pageHeight - 180 {
                startNewPage()
            }

            // --- Maintenance Analytics ---
            y = drawDivider(context: context, y: y, x: margin, width: contentWidth)
            y += 12
            y = drawSectionHeader("Maintenance Analytics", context: context, y: y, x: margin)

            let openWOs = openWorkOrdersCount(workOrders: workOrders)
            let periodWOs = workOrdersInPeriod(workOrders: workOrders)
            let completedWOs = completedWorkOrdersInPeriod(workOrders: workOrders)
            let periodDefects = defectsInPeriod(defects: defectReports)
            let defRate = formatPercent(defectResolutionRate(defects: defectReports))

            let maintRows = [
                ("Open Work Orders", "\(openWOs)"),
                ("Work Orders (\(periodLabel))", "\(periodWOs)"),
                ("Completed (\(periodLabel))", "\(completedWOs)"),
                ("Defects (\(periodLabel))", "\(periodDefects)"),
                ("Defect Resolution Rate", defRate),
                ("Maintenance Cost (\(periodLabel))", maintCost)
            ]
            y = drawTable(maintRows, context: context, y: y, x: margin, width: contentWidth)
            y += 12

            let priorities = workOrderPriorities(workOrders: workOrders)
            let activePriorities = priorities.filter { $0.count > 0 }
            if !activePriorities.isEmpty {
                if y > pageHeight - 140 {
                    startNewPage()
                }
                y = drawSubHeader("Active Work Order Priorities", context: context, y: y, x: margin)
                let priRows = activePriorities.map { ($0.label, "\($0.count)") }
                y = drawTable(priRows, context: context, y: y, x: margin, width: contentWidth)
                y += 12
            }

            // Check if we need a new page
            if y > pageHeight - 180 {
                startNewPage()
            }

            // --- Trip Analytics ---
            y = drawDivider(context: context, y: y, x: margin, width: contentWidth)
            y += 12
            y = drawSectionHeader("Trip Analytics (\(periodLabel))", context: context, y: y, x: margin)

            let periodTripCount = tripsInPeriodCount(trips: trips)
            let avgDist = formatDistance(averageTripDistance(trips: trips)) + " km"
            let statusBreakdown = tripStatusBreakdown(trips: trips)

            let tripRows = [
                ("Total Trips", "\(periodTripCount)"),
                ("Total Distance", totalDist),
                ("Avg Trip Distance", avgDist),
                ("Completion Rate", compRate)
            ]
            y = drawTable(tripRows, context: context, y: y, x: margin, width: contentWidth)
            y += 12

            if !statusBreakdown.isEmpty {
                if y > pageHeight - 140 {
                    startNewPage()
                }
                y = drawSubHeader("Trip Status Breakdown", context: context, y: y, x: margin)
                let statusRows = statusBreakdown.map { ($0.label, "\($0.count)") }
                y = drawTable(statusRows, context: context, y: y, x: margin, width: contentWidth)
            }
        }

        return data
    }

    // MARK: - PDF Drawing Helpers

    private func drawPageFooter(
        context: UIGraphicsPDFRendererContext,
        pageHeight: CGFloat,
        margin: CGFloat,
        dateFormatter: DateFormatter
    ) {
        let y = pageHeight - margin + 10
        let footerFont = UIFont.systemFont(ofSize: 8, weight: .regular)
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: textMuted
        ]
        let footerStr = "Fleet Management System  •  Confidential Analytics Report  •  Generated: \(dateFormatter.string(from: Date()))"
        (footerStr as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: footerAttrs)
    }

    private func drawSectionHeader(_ text: String, context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat) -> CGFloat {
        let cgContext = context.cgContext
        
        // Draw colored indicator bar on the left of section header
        let indicatorRect = CGRect(x: x, y: y + 2, width: 4, height: 16)
        let indicatorPath = UIBezierPath(roundedRect: indicatorRect, cornerRadius: 2)
        cgContext.saveGState()
        primaryBlue.setFill()
        indicatorPath.fill()
        cgContext.restoreGState()

        let font  = UIFont.systemFont(ofSize: 13, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textPrimary]
        (text.uppercased() as NSString).draw(at: CGPoint(x: x + 12, y: y + 3), withAttributes: attrs)
        return y + 26
    }

    private func drawSubHeader(_ text: String, context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat) -> CGFloat {
        let font  = UIFont.systemFont(ofSize: 11, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: primaryBlue]
        (text.uppercased() as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
        return y + 18
    }

    private func drawDivider(context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat, width: CGFloat) -> CGFloat {
        let cgContext = context.cgContext
        cgContext.saveGState()
        cgContext.setStrokeColor(borderGray.withAlphaComponent(0.8).cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: x, y: y))
        cgContext.addLine(to: CGPoint(x: x + width, y: y))
        cgContext.strokePath()
        cgContext.restoreGState()
        return y
    }

    private func drawKPIGrid(_ items: [(String, String)], context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat, width: CGFloat) -> CGFloat {
        let cgContext = context.cgContext
        
        let titleFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: textSecondary]
        
        let cardColors: [UIColor] = [
            primaryBlue,
            darkOrange,
            UIColor(red: 0.10, green: 0.28, blue: 0.70, alpha: 1.0), // Deep Blue
            UIColor(red: 0.45, green: 0.25, blue: 0.90, alpha: 1.0)  // Violet/Purple
        ]
        
        let gap: CGFloat = 16
        let cardWidth = (width - gap) / 2
        let cardHeight: CGFloat = 65
        
        var currentY = y
        for row in stride(from: 0, to: items.count, by: 2) {
            for col in 0..<2 where row + col < items.count {
                let item = items[row + col]
                let xPos = x + CGFloat(col) * (cardWidth + gap)
                let yPos = currentY
                
                let rect = CGRect(x: xPos, y: yPos, width: cardWidth, height: cardHeight)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
                
                let themeColor = cardColors[(row + col) % cardColors.count]
                
                // Draw card background (tinted fill)
                cgContext.saveGState()
                themeColor.withAlphaComponent(0.04).setFill()
                path.fill()
                
                // Draw card border (tinted stroke)
                cgContext.setStrokeColor(themeColor.withAlphaComponent(0.18).cgColor)
                cgContext.setLineWidth(1)
                path.stroke()
                cgContext.restoreGState()
                
                // Draw Card Title
                (item.0 as NSString).draw(at: CGPoint(x: xPos + 12, y: yPos + 12), withAttributes: titleAttrs)
                
                // Draw Card Value
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: valueFont,
                    .foregroundColor: themeColor
                ]
                (item.1 as NSString).draw(at: CGPoint(x: xPos + 12, y: yPos + 28), withAttributes: valueAttrs)
            }
            currentY += cardHeight + gap
        }
        return currentY
    }

    private func drawTable(_ rows: [(String, String)], context: UIGraphicsPDFRendererContext, y: CGFloat, x: CGFloat, width: CGFloat) -> CGFloat {
        if rows.isEmpty { return y }
        let cgContext = context.cgContext
        
        let labelFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let valueFont = UIFont.systemFont(ofSize: 10, weight: .bold)
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: textSecondary]
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: textPrimary]
        
        let rowHeight: CGFloat = 24
        let tableHeight = CGFloat(rows.count) * rowHeight + 8
        let rect = CGRect(x: x, y: y, width: width, height: tableHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        
        cgContext.saveGState()
        // Draw soft grey/blue container background
        UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0).setFill()
        path.fill()
        
        // Draw container border
        cgContext.setStrokeColor(borderGray.cgColor)
        cgContext.setLineWidth(0.8)
        path.stroke()
        cgContext.restoreGState()
        
        var currentY = y + 4
        for i in 0..<rows.count {
            let (label, value) = rows[i]
            
            // Draw horizontal separator line for all but the last row
            if i > 0 {
                cgContext.saveGState()
                cgContext.setStrokeColor(borderGray.withAlphaComponent(0.5).cgColor)
                cgContext.setLineWidth(0.5)
                cgContext.move(to: CGPoint(x: x + 12, y: currentY))
                cgContext.addLine(to: CGPoint(x: x + width - 12, y: currentY))
                cgContext.strokePath()
                cgContext.restoreGState()
            }
            
            // Draw text centered vertically in the row
            (label as NSString).draw(at: CGPoint(x: x + 12, y: currentY + (rowHeight - 12) / 2), withAttributes: labelAttrs)
            
            let valueSize = (value as NSString).size(withAttributes: valueAttrs)
            (value as NSString).draw(at: CGPoint(x: x + width - valueSize.width - 12, y: currentY + (rowHeight - 12) / 2), withAttributes: valueAttrs)
            
            currentY += rowHeight
        }
        
        return y + tableHeight
    }
}
