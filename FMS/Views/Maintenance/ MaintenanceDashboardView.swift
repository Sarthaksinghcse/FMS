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
        .accentColor(.blue)
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Maintenance")
                            .font(.headline).fontWeight(.semibold)
                        Text("Maintenance Personnel")
                            .font(.caption).foregroundColor(.secondary)
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
                    iconColor: .red,
                    iconBg: Color.red.opacity(0.12),
                    title: "Pending Repairs",
                    value: "\(pendingOrders.count)",
                    valueColor: .red,
                    footnote: pendingOrders.isEmpty ? "None pending" : "\(pendingOrders.count) open work orders"
                )
                StatCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    iconBg: Color.green.opacity(0.12),
                    title: "Completed Today",
                    value: "\(completedToday.count)",
                    valueColor: .green,
                    footnote: "Since midnight"
                )
                StatCard(
                    icon: "clock.fill",
                    iconColor: .orange,
                    iconBg: Color.orange.opacity(0.12),
                    title: "In Progress",
                    value: "\(inProgressOrders.count)",
                    valueColor: .orange,
                    footnote: inProgressOrders.isEmpty ? "No change" : "Active now"
                )
                StatCard(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: Color.purple,
                    iconBg: Color.purple.opacity(0.12),
                    title: "Low Stock Items",
                    value: "\(lowStockItems.count)",
                    valueColor: .purple,
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
                QuickActionButton(icon: "wrench.fill",           label: "Create\nWork Order",    color: .blue)
                QuickActionButton(icon: "checkmark.square.fill", label: "Update\nMaintenance",   color: .green)
                QuickActionButton(icon: "camera.fill",           label: "Upload\nRepair Notes",  color: .purple)
                QuickActionButton(icon: "clock.fill",            label: "View\nSchedule",        color: .blue)
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
                    .font(.subheadline).foregroundColor(.blue)
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
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }

    // MARK: Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.systemBackground))
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
                            .foregroundColor(.red)
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
                    .font(.caption).foregroundColor(.secondary)
                if let supplier = item.supplierName {
                    Text(supplier)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantityInStock)")
                    .font(.title3).fontWeight(.bold)
                    .foregroundColor(isLow ? .red : .primary)
                Text("in stock")
                    .font(.caption2).foregroundColor(.secondary)
                if isLow {
                    Text("Reorder: \(item.reorderThreshold)")
                        .font(.caption2)
                        .foregroundColor(.red)
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
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1)
                Text(order.status == .completed
                     ? "Completed \(order.completedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")"
                     : "Created \(order.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            WorkOrderStatusBadge(status: order.status)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
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
                    .foregroundColor(.primary)
                if count > 0 {
                    Text("\(min(count, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.red)
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
                .foregroundColor(.primary)
            Text(value)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(valueColor)
            Text(footnote)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
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
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
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
        case .open:       return .red
        case .inProgress: return .orange
        case .completed:  return Color(red: 0.18, green: 0.65, blue: 0.36)
        case .cancelled:  return .gray
        }
    }
}

extension WorkOrderPriority {
    var color: Color {
        switch self {
        case .low:    return .gray
        case .medium: return .blue
        case .high:   return .orange
        case .urgent: return .red
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

