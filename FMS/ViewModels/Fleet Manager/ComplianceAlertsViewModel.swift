import Foundation
import SwiftUI
import SwiftData

// MARK: - Display Model

struct ComplianceAlertItem: Identifiable {
    let id: UUID
    let vehicleId: UUID
    let vehicleRegistration: String
    let vehicleMakeModel: String
    let vehicleYear: Int
    let vehicleType: VehicleType
    let alertType: ComplianceAlertType
    let status: ComplianceAlertStatus
    let deadlineDate: Date
    let daysRemaining: Int
    let resolvedAt: Date?
    let persistedAlertId: UUID?

    var isOverdue: Bool { status == .overdue }

    var urgencyLabel: String {
        if status == .resolved {
            return "Resolved"
        } else if daysRemaining < 0 {
            return "\(abs(daysRemaining)) day\(abs(daysRemaining) == 1 ? "" : "s") overdue"
        } else if daysRemaining == 0 {
            return "Due today"
        } else {
            return "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining"
        }
    }

    var urgencyColor: Color {
        if status == .resolved {
            return ComplianceAlertStatus.resolved.color
        } else if daysRemaining < 0 {
            return ComplianceAlertStatus.overdue.color
        } else if daysRemaining <= 7 {
            return Color(red: 0.90, green: 0.45, blue: 0.15)
        } else {
            return ComplianceAlertStatus.upcoming.color
        }
    }
}

// MARK: - Segment Filter

enum ComplianceSegment: String, CaseIterable, Identifiable {
    case all = "All"
    case overdue = "Overdue"
    case upcoming = "Upcoming"
    case resolved = "Resolved"

    var id: String { rawValue }
}

// MARK: - ViewModel

@Observable
class ComplianceAlertsViewModel {

    var selectedSegment: ComplianceSegment = .all
    var selectedType: ComplianceAlertType? = nil

    // MARK: - Generate alerts from vehicle data

    func generateAlerts(
        vehicles: [Vehicle],
        persistedAlerts: [ComplianceAlert]
    ) -> [ComplianceAlertItem] {
        let now = Date()
        let calendar = Calendar.current
        let alertWindow: TimeInterval = 86400 * 30 // 30 days for insurance/permit
        let serviceWindow: TimeInterval = 86400 * 14 // 14 days for servicing

        var items: [ComplianceAlertItem] = []

        for vehicle in vehicles {
            // Insurance
            if let expiryDate = vehicle.insuranceExpiryDate {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiryDate)).day ?? 0

                if days <= 30 {
                    let resolvedAlert = persistedAlerts.first {
                        $0.vehicleId == vehicle.id &&
                        $0.alertType == .insurance &&
                        $0.status == .resolved &&
                        calendar.isDate($0.deadlineDate, inSameDayAs: expiryDate)
                    }

                    let status: ComplianceAlertStatus = resolvedAlert != nil ? .resolved : (days < 0 ? .overdue : .upcoming)

                    items.append(ComplianceAlertItem(
                        id: UUID(uuidString: "c1-\(vehicle.id.uuidString.prefix(24))") ?? UUID(),
                        vehicleId: vehicle.id,
                        vehicleRegistration: vehicle.registrationNumber,
                        vehicleMakeModel: "\(vehicle.make) \(vehicle.model)",
                        vehicleYear: vehicle.year,
                        vehicleType: vehicle.vehicleType,
                        alertType: .insurance,
                        status: status,
                        deadlineDate: expiryDate,
                        daysRemaining: days,
                        resolvedAt: resolvedAlert?.resolvedAt,
                        persistedAlertId: resolvedAlert?.id
                    ))
                }
            }

            // Permit
            if let expiryDate = vehicle.permitExpiryDate {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: expiryDate)).day ?? 0

                if days <= 30 {
                    let resolvedAlert = persistedAlerts.first {
                        $0.vehicleId == vehicle.id &&
                        $0.alertType == .permit &&
                        $0.status == .resolved &&
                        calendar.isDate($0.deadlineDate, inSameDayAs: expiryDate)
                    }

                    let status: ComplianceAlertStatus = resolvedAlert != nil ? .resolved : (days < 0 ? .overdue : .upcoming)

                    items.append(ComplianceAlertItem(
                        id: UUID(uuidString: "c2-\(vehicle.id.uuidString.prefix(24))") ?? UUID(),
                        vehicleId: vehicle.id,
                        vehicleRegistration: vehicle.registrationNumber,
                        vehicleMakeModel: "\(vehicle.make) \(vehicle.model)",
                        vehicleYear: vehicle.year,
                        vehicleType: vehicle.vehicleType,
                        alertType: .permit,
                        status: status,
                        deadlineDate: expiryDate,
                        daysRemaining: days,
                        resolvedAt: resolvedAlert?.resolvedAt,
                        persistedAlertId: resolvedAlert?.id
                    ))
                }
            }

            // Servicing
            if let serviceDate = vehicle.nextServiceDate {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: serviceDate)).day ?? 0

                if days <= 14 {
                    let resolvedAlert = persistedAlerts.first {
                        $0.vehicleId == vehicle.id &&
                        $0.alertType == .servicing &&
                        $0.status == .resolved &&
                        calendar.isDate($0.deadlineDate, inSameDayAs: serviceDate)
                    }

                    let status: ComplianceAlertStatus = resolvedAlert != nil ? .resolved : (days < 0 ? .overdue : .upcoming)

                    items.append(ComplianceAlertItem(
                        id: UUID(uuidString: "c3-\(vehicle.id.uuidString.prefix(24))") ?? UUID(),
                        vehicleId: vehicle.id,
                        vehicleRegistration: vehicle.registrationNumber,
                        vehicleMakeModel: "\(vehicle.make) \(vehicle.model)",
                        vehicleYear: vehicle.year,
                        vehicleType: vehicle.vehicleType,
                        alertType: .servicing,
                        status: status,
                        deadlineDate: serviceDate,
                        daysRemaining: days,
                        resolvedAt: resolvedAlert?.resolvedAt,
                        persistedAlertId: resolvedAlert?.id
                    ))
                }
            }
        }

        // Sort: overdue first (most overdue), then upcoming (soonest), then resolved
        return items.sorted { a, b in
            if a.status == .resolved && b.status != .resolved { return false }
            if a.status != .resolved && b.status == .resolved { return true }
            if a.status == .overdue && b.status == .upcoming { return true }
            if a.status == .upcoming && b.status == .overdue { return false }
            return a.daysRemaining < b.daysRemaining
        }
    }

    // MARK: - Filtered alerts

    func filteredAlerts(from allAlerts: [ComplianceAlertItem]) -> [ComplianceAlertItem] {
        var result = allAlerts

        // Segment filter
        switch selectedSegment {
        case .all:
            break
        case .overdue:
            result = result.filter { $0.status == .overdue }
        case .upcoming:
            result = result.filter { $0.status == .upcoming }
        case .resolved:
            result = result.filter { $0.status == .resolved }
        }

        // Type filter
        if let type = selectedType {
            result = result.filter { $0.alertType == type }
        }

        return result
    }

    // MARK: - Summary counts

    func overdueCount(from alerts: [ComplianceAlertItem]) -> Int {
        alerts.filter { $0.status == .overdue }.count
    }

    func upcomingCount(from alerts: [ComplianceAlertItem]) -> Int {
        alerts.filter { $0.status == .upcoming }.count
    }

    func resolvedCount(from alerts: [ComplianceAlertItem]) -> Int {
        alerts.filter { $0.status == .resolved }.count
    }

    // MARK: - Resolve alert

    func resolveAlert(
        item: ComplianceAlertItem,
        context: ModelContext
    ) {
        // Check if persisted alert already exists
        if let existingId = item.persistedAlertId {
            // Already resolved — do nothing
            return
        }

        // Create new persisted resolved alert
        let alert = ComplianceAlert(
            vehicleId: item.vehicleId,
            alertType: item.alertType,
            status: .resolved,
            deadlineDate: item.deadlineDate,
            resolvedAt: .now,
            notes: "Resolved by Fleet Manager"
        )
        context.insert(alert)
        try? context.save()

        Task {
            do {
                try await SupabaseManager.shared.createComplianceAlert(alert.asDBAlert)
            } catch {
                print("Failed to sync compliance alert resolution to Supabase: \(error.localizedDescription)")
            }
        }
    }
}
