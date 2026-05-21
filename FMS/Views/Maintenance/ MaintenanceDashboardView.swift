//
//   MaintenanceDashboardView.swift
//  FMS
//
//  Created by Gauri Verma on 21/05/26.
//


import SwiftUI
import SwiftData

// MARK: - Dashboard View

struct MaintenanceDashboardView: View {

    // Logged-in maintenance user (pass from login flow)
    let currentUser: User

    // SwiftData queries
    @Query private var allWorkOrders: [WorkOrder]
    @Query private var allInventory: [InventoryItem]
    @Query private var allNotifications: [AppNotification]

    @State private var selectedTab: Int = 0

    // MARK: Derived counts (computed from real data)

    private var pendingOrders: [WorkOrder] {
        allWorkOrders.filter { $0.assignedTo == currentUser.id && $0.status == .open }
    }

    private var inProgressOrders: [WorkOrder] {
        allWorkOrders.filter { $0.assignedTo == currentUser.id && $0.status == .inProgress }
    }

    private var completedToday: [WorkOrder] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allWorkOrders.filter {
            $0.assignedTo == currentUser.id &&
            $0.status == .completed &&
            ($0.completedAt ?? .distantPast) >= startOfDay
        }
    }

    private var lowStockItems: [InventoryItem] {
        allInventory.filter { $0.quantityInStock <= $0.reorderThreshold }
    }

    private var unreadNotifications: [AppNotification] {
        allNotifications.filter { $0.userId == currentUser.id && !$0.isRead }
    }

    private var recentWorkOrders: [WorkOrder] {
        allWorkOrders
            .filter { $0.assignedTo == currentUser.id }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                .tag(0)

            InventoryTabView(items: allInventory)
                .tabItem { Label("Inventory", systemImage: "shippingbox") }
                .tag(1)
        }
        .accentColor(AppTheme.Brand.primary)
    }

    // MARK: Dashboard Tab

    private var dashboardTab: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    overviewSection
                    quickActionsSection
                    recentWorkOrdersSection
                }
                .padding(.bottom, 32)
            }
            .background(AppTheme.Background.page)
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Maintenance")
                            .font(.headline).fontWeight(.semibold)
                        Text("Maintenance Personnel")
                            .font(.caption).foregroundColor(AppTheme.Text.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NotificationBellButton(count: unreadNotifications.count)
                }
            }
        }
    }

    // MARK: Overview Cards

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Overview")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                StatCard(
                    icon: "doc.text.fill",
                    iconColor: AppTheme.Status.danger,
                    iconBg: AppTheme.IconBg.red,
                    title: "Pending Repairs",
                    value: "\(pendingOrders.count)",
                    valueColor: AppTheme.Status.danger,
                    footnote: pendingOrders.isEmpty ? "None pending" : "\(pendingOrders.count) open work orders"
                )
                StatCard(
                    icon: "checkmark.circle.fill",
                    iconColor: AppTheme.Status.success,
                    iconBg: AppTheme.IconBg.green,
                    title: "Completed Today",
                    value: "\(completedToday.count)",
                    valueColor: AppTheme.Status.success,
                    footnote: "Since midnight"
                )
                StatCard(
                    icon: "clock.fill",
                    iconColor: AppTheme.Status.warning,
                    iconBg: AppTheme.IconBg.orange,
                    title: "In Progress",
                    value: "\(inProgressOrders.count)",
                    valueColor: AppTheme.Status.warning,
                    footnote: inProgressOrders.isEmpty ? "No change" : "Active now"
                )
                StatCard(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: AppTheme.Status.purple,
                    iconBg: AppTheme.IconBg.purple,
                    title: "Low Stock Items",
                    value: "\(lowStockItems.count)",
                    valueColor: AppTheme.Status.purple,
                    footnote: lowStockItems.isEmpty ? "Stock OK" : "Below reorder level"
                )
            }
            .padding(.horizontal)
        }
        .padding(.top, 16)
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Actions")
            HStack(spacing: 10) {
                QuickActionButton(icon: "wrench.fill",           label: "Create\nWork Order",    color: AppTheme.Brand.primary)
                QuickActionButton(icon: "checkmark.square.fill", label: "Update\nMaintenance",   color: AppTheme.Status.success)
                QuickActionButton(icon: "camera.fill",           label: "Upload\nRepair Notes",  color: AppTheme.Status.purple)
                QuickActionButton(icon: "clock.fill",            label: "View\nSchedule",        color: AppTheme.Brand.primary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: Recent Work Orders

    private var recentWorkOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Recent Work Orders")
                Spacer()
                Button("See All") {}
                    .font(.subheadline).foregroundColor(AppTheme.Brand.primary)
            }
            .padding(.horizontal)

            if recentWorkOrders.isEmpty {
                emptyState(icon: "wrench.and.screwdriver", message: "No work orders assigned yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentWorkOrders.enumerated()), id: \.element.id) { idx, order in
                        WorkOrderRow(order: order)
                        if idx < recentWorkOrders.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }

    // MARK: Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(AppTheme.Text.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppTheme.Background.card)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Inventory Tab

struct InventoryTabView: View {
    let items: [InventoryItem]

    private var lowStock: [InventoryItem] { items.filter { $0.quantityInStock <= $0.reorderThreshold } }
    private var okStock: [InventoryItem]  { items.filter { $0.quantityInStock > $0.reorderThreshold } }

    var body: some View {
        NavigationView {
            List {
                if !lowStock.isEmpty {
                    Section {
                        ForEach(lowStock) { item in
                            InventoryRow(item: item)
                        }
                    } header: {
                        Label("Low Stock", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.Status.danger)
                    }
                }

                Section {
                    ForEach(okStock) { item in
                        InventoryRow(item: item)
                    }
                } header: {
                    Text("All Parts")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Inventory")
        }
    }
}

struct InventoryRow: View {
    let item: InventoryItem

    private var isLow: Bool { item.quantityInStock <= item.reorderThreshold }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.partName)
                    .font(.subheadline).fontWeight(.medium)
                Text("Part #\(item.partNumber)")
                    .font(.caption).foregroundColor(AppTheme.Text.secondary)
                if let supplier = item.supplierName {
                    Text(supplier)
                        .font(.caption).foregroundColor(AppTheme.Text.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantityInStock)")
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(isLow ? AppTheme.Status.danger : AppTheme.Text.primary)
                Text("in stock")
                    .font(.caption2).foregroundColor(AppTheme.Text.secondary)
                if isLow {
                    Text("Reorder: \(item.reorderThreshold)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Status.danger)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Work Order Row

struct WorkOrderRow: View {
    let order: WorkOrder

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator + icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(order.priority.color.opacity(0.12))
                    .frame(width: 52, height: 52)
                VStack(spacing: 2) {
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 16))
                        .foregroundColor(order.priority.color)
                    Text(order.priority.shortLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(order.priority.color)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(order.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                Text(order.workDescription)
                    .font(.caption).foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
                Text(order.status == .completed
                     ? "Completed \(order.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")"
                     : "Created \(order.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundColor(AppTheme.Text.secondary)
            }

            Spacer()

            WorkOrderStatusBadge(status: order.status)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Text.tertiary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Status Badge

struct WorkOrderStatusBadge: View {
    let status: WorkOrderStatus

    var body: some View {
        Text(status.displayLabel)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.12))
            .cornerRadius(8)
    }
}

// MARK: - Notification Bell

struct NotificationBellButton: View {
    let count: Int
    var body: some View {
        Button(action: {}) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Text.primary)
                if count > 0 {
                    Text("\(min(count, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Text.onDark)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(AppTheme.Status.danger)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title3).fontWeight(.bold)
            .padding(.horizontal)
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let value: String
    let valueColor: Color
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBg)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(AppTheme.Text.primary)
            Text(value)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(valueColor)
            Text(footnote)
                .font(.caption)
                .foregroundColor(AppTheme.Text.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 11)).fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.medium)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Model Extensions (display helpers only — no data mutation)

extension WorkOrderStatus {
    var displayLabel: String {
        switch self {
        case .open:       return "Pending"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }
    var color: Color {
        switch self {
        case .open:       return AppTheme.Status.danger
        case .inProgress: return AppTheme.Status.warning
        case .completed:  return AppTheme.Status.success
        case .cancelled:  return .gray
        }
    }
}

extension WorkOrderPriority {
    var color: Color {
        switch self {
        case .low:    return .gray
        case .medium: return AppTheme.Brand.primary
        case .high:   return AppTheme.Status.warning
        case .urgent: return AppTheme.Status.danger
        }
    }
    var shortLabel: String {
        switch self {
        case .low:    return "LOW"
        case .medium: return "MED"
        case .high:   return "HIGH"
        case .urgent: return "URGENT"
        }
    }
}

// MARK: - Preview

#Preview {
    // Build an in-memory SwiftData container with sample data
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: User.self, WorkOrder.self, InventoryItem.self, AppNotification.self,
        configurations: config
    )

    let ctx = container.mainContext

    // Sample user
    let user = User(
        fullName: "Raj Kumar",
        email: "raj@fleet.com",
        phoneNumber: "9876543210",
        passwordHash: "hashed",
        role: .maintenance
    )
    ctx.insert(user)

    // Sample work orders
    let wo1 = WorkOrder(vehicleId: UUID(), assignedTo: user.id,
                        title: "Brake Issue – Truck 12",
                        workDescription: "Front brake pads worn",
                        priority: .high)
    let wo2 = WorkOrder(vehicleId: UUID(), assignedTo: user.id,
                        title: "Oil Change – Van 05",
                        workDescription: "Routine 10k km service",
                        priority: .medium, status: .inProgress)
    let wo3 = WorkOrder(vehicleId: UUID(), assignedTo: user.id,
                        title: "Tire Replacement – Truck 08",
                        workDescription: "All four tires replaced",
                        priority: .low, status: .completed,
                        completedAt: .now)
    [wo1, wo2, wo3].forEach { ctx.insert($0) }

    // Sample inventory
    let inv1 = InventoryItem(partName: "Brake Pads", partNumber: "BP-204",
                             quantityInStock: 2, reorderThreshold: 5,
                             unitCost: 850, supplierName: "AutoParts Co.")
    let inv2 = InventoryItem(partName: "Engine Oil 5W-40", partNumber: "OIL-5W40",
                             quantityInStock: 12, reorderThreshold: 5,
                             unitCost: 320)
    let inv3 = InventoryItem(partName: "Air Filter", partNumber: "AF-112",
                             quantityInStock: 1, reorderThreshold: 3,
                             unitCost: 450)
    [inv1, inv2, inv3].forEach { ctx.insert($0) }

    // Sample notification
    let notif = AppNotification(userId: user.id,
                                title: "New Work Order",
                                message: "WO assigned: Brake Issue Truck 12",
                                type: .maintenanceAlert)
    ctx.insert(notif)

    return MaintenanceDashboardView(currentUser: user)
        .modelContainer(container)
}

