import SwiftUI
import SwiftData

@Observable
final class FleetDashboardViewModel {
    var activeQuickAction: ActiveQuickAction? = nil
    var showAllActivities: Bool = false

    let quickActions: [DashboardQuickAction] = [
        DashboardQuickAction(
            icon: "bubble.left.and.bubble.right.fill",
            iconColor: AppTheme.Brand.primary,
            bgColor: AppTheme.IconBg.blue,
            label: "Chat"
        ),
        DashboardQuickAction(
            icon: "person.badge.plus",
            iconColor: AppTheme.Brand.violet,
            bgColor: AppTheme.IconBg.violet,
            label: "Assign Driver"
        ),
        DashboardQuickAction(
            icon: "exclamationmark.octagon.fill",
            iconColor: AppTheme.Status.danger,
            bgColor: AppTheme.IconBg.red,
            label: "Alerts"
        ),
        DashboardQuickAction(
            icon: "wrench.and.screwdriver.fill",
            iconColor: AppTheme.Brand.amber,
            bgColor: AppTheme.IconBg.amber,
            label: "Maintenance"
        )
    ]

    enum ActiveQuickAction: Identifiable {
        case addVehicle
        case assignDriver
        case reports
        case alerts
        case maintenance

        var id: Self { self }
    }

    func getGreetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning, Manager" }
        else if hour < 17 { return "Good Afternoon, Manager" }
        else { return "Good Evening, Manager" }
    }

    func getGreetingTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }

    func getGreetingPosition() -> String {
        return "Manager"
    }

    // MARK: - Stats

    func getDynamicStats(vehicles: [Vehicle], allUsers: [User], trips: [Trip]) -> [DashboardStat] {
        let totalVehicles  = vehicles.count
        let activeVehicles = vehicles.filter { $0.status == .active }.count
        let driversOnline  = allUsers.filter { $0.role == .driver && $0.isActive }.count
        let liveTrips      = trips.filter { $0.tripStatus == .inProgress || $0.tripStatus == .started }.count

        return [
            DashboardStat(icon: "car.fill",           iconColor: AppTheme.Brand.primary,
                          iconBgColor: AppTheme.IconBg.blue,   value: "\(totalVehicles)",
                          label: "Total Vehicles",    trend: "", isTrendPositive: true,  graphData: []),
            DashboardStat(icon: "location.fill",      iconColor: AppTheme.Status.success,
                          iconBgColor: AppTheme.IconBg.green,  value: "\(activeVehicles)",
                          label: "Available Now",     trend: "", isTrendPositive: true,  graphData: []),
            DashboardStat(icon: "person.2.fill",      iconColor: AppTheme.Brand.violet,
                          iconBgColor: AppTheme.IconBg.violet, value: "\(driversOnline)",
                          label: "Drivers Online",   trend: "", isTrendPositive: true,  graphData: []),
            DashboardStat(icon: "arrow.up.arrow.down",iconColor: AppTheme.Brand.teal,
                          iconBgColor: AppTheme.IconBg.teal,   value: "\(liveTrips)",
                          label: "Live Trips",        trend: "", isTrendPositive: false, graphData: [])
        ]
    }

    func getFleetUtilizationProgress(vehicles: [Vehicle]) -> Double {
        let total  = vehicles.count
        let active = vehicles.filter { $0.status == .active }.count
        return total > 0 ? Double(active) / Double(total) : 0.0
    }

    // MARK: - Real-Time Activity Feed

    /// Builds a unified, time-sorted activity list from live SwiftData collections.
    /// Each item is tagged with the initiator: "Driver", "Fleet Manager", or "System".
    func buildActivities(
        trips: [Trip],
        users: [User],
        vehicles: [Vehicle],
        sosAlerts: [SOSAlert],
        defectReports: [DefectReport],
        workOrders: [WorkOrder]
    ) -> [DashboardActivity] {

        // ── Helpers ───────────────────────────────────────────────
        func driverName(for id: UUID) -> String {
            users.first(where: { $0.id == id })?.fullName ?? "Unknown Driver"
        }
        func vehicleLabel(for id: UUID) -> String {
            guard let v = vehicles.first(where: { $0.id == id }) else { return "Unknown Vehicle" }
            return "\(v.make) \(v.model)"
        }
        func relTime(_ date: Date) -> String {
            let diff = Date().timeIntervalSince(date)
            if diff < 60        { return "Just now" }
            if diff < 3600      { return "\(Int(diff / 60))m ago" }
            if diff < 86400     { return "\(Int(diff / 3600))h ago" }
            return "\(Int(diff / 86400))d ago"
        }

        var items: [DashboardActivity] = []

        // ── Trips ─────────────────────────────────────────────────
        for trip in trips {
            let driver  = driverName(for: trip.driverId)
            let vehicle = vehicleLabel(for: trip.vehicleId)

            switch trip.tripStatus {
            case .inProgress, .started:
                let eventDate = trip.actualStartTime ?? trip.scheduledStartTime
                items.append(DashboardActivity(
                    title: "Trip \(trip.tripCode) Started",
                    subtitle: "\(driver) → \(trip.endLocation)",
                    time: relTime(eventDate),
                    icon: "arrow.turn.up.right",
                    iconColor: AppTheme.Brand.primary,
                    iconBgColor: AppTheme.IconBg.blue,
                    source: "Driver",
                    date: eventDate
                ))

            case .completed:
                let eventDate = trip.actualEndTime ?? trip.scheduledEndTime
                items.append(DashboardActivity(
                    title: "Trip \(trip.tripCode) Completed",
                    subtitle: "\(driver) delivered to \(trip.endLocation)",
                    time: relTime(eventDate),
                    icon: "checkmark.seal.fill",
                    iconColor: AppTheme.Status.success,
                    iconBgColor: AppTheme.IconBg.green,
                    source: "Driver",
                    date: eventDate
                ))

            case .assigned:
                items.append(DashboardActivity(
                    title: "Trip \(trip.tripCode) Assigned",
                    subtitle: "\(vehicle) assigned to \(driver)",
                    time: relTime(trip.createdAt),
                    icon: "person.badge.plus",
                    iconColor: AppTheme.Brand.violet,
                    iconBgColor: AppTheme.IconBg.violet,
                    source: "Fleet Manager",
                    date: trip.createdAt
                ))

            case .cancelled:
                items.append(DashboardActivity(
                    title: "Trip \(trip.tripCode) Cancelled",
                    subtitle: "\(driver) — \(trip.startLocation) → \(trip.endLocation)",
                    time: relTime(trip.createdAt),
                    icon: "xmark.circle.fill",
                    iconColor: AppTheme.Status.danger,
                    iconBgColor: AppTheme.IconBg.red,
                    source: "Fleet Manager",
                    date: trip.createdAt
                ))
            }
        }

        // ── SOS Alerts ────────────────────────────────────────────
        for sos in sosAlerts {
            let driver  = driverName(for: sos.driverId)
            let vehicle = vehicleLabel(for: sos.vehicleId)
            let status  = sos.status == .active ? "Active 🔴" : "Resolved ✅"
            items.append(DashboardActivity(
                title: "SOS Emergency Alert",
                subtitle: "\(driver) • \(vehicle) [\(status)]",
                time: relTime(sos.createdAt),
                icon: "exclamationmark.octagon.fill",
                iconColor: AppTheme.Status.danger,
                iconBgColor: AppTheme.IconBg.red,
                source: "Driver",
                date: sos.createdAt
            ))
        }

        // ── Defect Reports ────────────────────────────────────────
        for defect in defectReports {
            let reporter = driverName(for: defect.reportedBy)
            let vehicle  = vehicleLabel(for: defect.vehicleId)
            let (sevColor, sevBg): (Color, Color) = {
                switch defect.severity {
                case .high:   return (AppTheme.Status.danger,  AppTheme.IconBg.red)
                case .medium: return (AppTheme.Status.warning, AppTheme.IconBg.orange)
                case .low:    return (AppTheme.Brand.primary,  AppTheme.IconBg.blue)
                }
            }()
            items.append(DashboardActivity(
                title: "Defect: \(defect.title)",
                subtitle: "\(vehicle) • Reported by \(reporter)",
                time: relTime(defect.createdAt),
                icon: "exclamationmark.triangle.fill",
                iconColor: sevColor,
                iconBgColor: sevBg,
                source: "Driver",
                date: defect.createdAt
            ))
        }

        // ── Work Orders ───────────────────────────────────────────
        for wo in workOrders {
            let vehicle = vehicleLabel(for: wo.vehicleId)
            let (woIcon, woColor, woBg): (String, Color, Color) = {
                switch wo.status {
                case .open:      return ("wrench.fill",                AppTheme.Brand.amber,    AppTheme.IconBg.amber)
                case .inProgress:return ("wrench.and.screwdriver.fill",AppTheme.Brand.violet,   AppTheme.IconBg.violet)
                case .completed: return ("checkmark.seal.fill",        AppTheme.Status.success, AppTheme.IconBg.green)
                case .cancelled: return ("xmark.circle.fill",          AppTheme.Status.danger,  AppTheme.IconBg.red)
                }
            }()
            items.append(DashboardActivity(
                title: "Work Order: \(wo.title)",
                subtitle: "\(vehicle) • \(wo.status.displayName)",
                time: relTime(wo.createdAt),
                icon: woIcon,
                iconColor: woColor,
                iconBgColor: woBg,
                source: "Fleet Manager",
                date: wo.createdAt
            ))
        }

        // Sort newest → oldest, cap at 50
        return Array(items.sorted { $0.date > $1.date }.prefix(50))
    }

    /// Badge count = events in last 24 hours
    func recentBadgeCount(activities: [DashboardActivity]) -> Int {
        let cutoff = Date().addingTimeInterval(-86_400)
        return activities.filter { $0.date > cutoff }.count
    }
}
