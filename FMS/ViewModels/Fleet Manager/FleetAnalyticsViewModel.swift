import SwiftUI

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

    // MARK: - Fleet Metrics (current snapshot — not period-filtered)

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

    // MARK: - Maintenance (current snapshot)

    func openWorkOrdersCount(workOrders: [WorkOrder]) -> Int {
        workOrders.filter { $0.status == .open || $0.status == .inProgress }.count
    }

    func defectResolutionRate(defects: [DefectReport]) -> Double {
        guard !defects.isEmpty else { return 0 }
        let resolved = defects.filter { $0.status == .resolved }.count
        return Double(resolved) / Double(defects.count)
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

    // MARK: - Driver Metrics (current snapshot)

    func driverStats(users: [User]) -> (total: Int, active: Int, rate: Double) {
        let drivers       = users.filter { $0.role == .driver }
        let activeDrivers = drivers.filter { $0.isActive }.count
        let rate          = drivers.isEmpty ? 0.0 : Double(activeDrivers) / Double(drivers.count)
        return (drivers.count, activeDrivers, rate)
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
}
