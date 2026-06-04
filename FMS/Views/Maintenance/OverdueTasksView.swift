//
//  OverdueTasksView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI
import SwiftData
import Combine

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class OverdueTasksViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published var selectedFilter: Int = 0   // 0=All, 1=Critical (>3 days), 2=My Tasks

    let currentUserId: UUID
    private let allWorkOrders: [WorkOrder]

    init(currentUserId: UUID, allWorkOrders: [WorkOrder]) {
        self.currentUserId = currentUserId
        self.allWorkOrders = allWorkOrders
    }

    /// Overdue = open/inProgress orders older than 1 day
    var overdueOrders: [WorkOrder] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        return allWorkOrders.filter { order in
            (order.status == .open || order.status == .inProgress) &&
            order.createdAt < cutoff
        }
    }

    var filteredTasks: [WorkOrder] {
        var base = overdueOrders

        switch selectedFilter {
        case 1: base = base.filter { daysOverdue(for: $0) >= 3 }
        case 2: base = base.filter { $0.assignedTo == currentUserId }
        default: break
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            base = base.filter {
                $0.title.lowercased().contains(q) ||
                $0.workDescription.lowercased().contains(q)
            }
        }

        // Sort: most overdue first, then by priority
        return base.sorted {
            let d0 = daysOverdue(for: $0), d1 = daysOverdue(for: $1)
            if d0 != d1 { return d0 > d1 }
            return $0.priority.sortOrder < $1.priority.sortOrder
        }
    }

    func daysOverdue(for order: WorkOrder) -> Int {
        let diff = Calendar.current.dateComponents([.day], from: order.createdAt, to: .now)
        return max(0, diff.day ?? 0)
    }

    var criticalCount: Int { filteredTasks.filter { daysOverdue(for: $0) >= 3 }.count }
    var filterChips: [String] { ["All Overdue", "Critical (3+ days)", "My Tasks"] }
    var accentColor: Color { AppTheme.Status.danger }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────────────────────────────────────

struct OverdueTasksView: View {

    @StateObject private var vm: OverdueTasksViewModel

    init(currentUserId: UUID, allWorkOrders: [WorkOrder]) {
        _vm = StateObject(wrappedValue: OverdueTasksViewModel(
            currentUserId: currentUserId,
            allWorkOrders: allWorkOrders
        ))
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        // Alert banner
                        if !vm.filteredTasks.isEmpty {
                            OverdueAlertBanner(
                                totalOverdue: vm.filteredTasks.count,
                                criticalCount: vm.criticalCount
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }

                        if vm.filteredTasks.isEmpty {
                            DetailEmptyState(
                                icon: "checkmark.shield.fill",
                                title: "No Overdue Tasks",
                                message: "All maintenance tasks are on schedule. Great work!",
                                accentColor: AppTheme.Status.success
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(vm.filteredTasks) { order in
                                    NavigationLink(destination: MaintenanceTaskDetailView(order: order)) {
                                        OverdueTaskCard(
                                            order: order,
                                            daysOverdue: vm.daysOverdue(for: order)
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .padding(.bottom, 32)
                        }
                    } header: {
                        VStack(spacing: 12) {
                            TaskSearchBar(text: $vm.searchText, placeholder: "Search overdue tasks...")
                                .padding(.top, 8)

                            FilterChipRow(
                                chips: vm.filterChips,
                                selected: $vm.selectedFilter,
                                accentColor: vm.accentColor
                            )
                            .padding(.bottom, 4)
                        }
                        .background(AppTheme.Background.page)
                    }
                }
            }
        }
        .navigationTitle("Overdue")
        .navigationBarTitleDisplayMode(.large)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Alert Banner
// ─────────────────────────────────────────────────────────────────────────────

private struct OverdueAlertBanner: View {
    let totalOverdue: Int
    let criticalCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.Status.danger.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    .foregroundColor(AppTheme.Status.danger)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(totalOverdue) overdue work order\(totalOverdue == 1 ? "" : "s")")
                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                Text(criticalCount > 0
                     ? "\(criticalCount) critical (3+ days past due)"
                     : "Immediate attention required")
                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                    .foregroundColor(AppTheme.Status.danger.opacity(0.8))
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.Status.danger.opacity(0.06))
        .cornerRadius(AppTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Status.danger.opacity(0.20), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Overdue Task Card
// ─────────────────────────────────────────────────────────────────────────────

private struct OverdueTaskCard: View {
    let order: WorkOrder
    let daysOverdue: Int

    private var urgencyColor: Color {
        if daysOverdue >= 5 { return AppTheme.Status.danger }
        if daysOverdue >= 3 { return Color.orange }
        return AppTheme.Brand.amber
    }

    private var urgencyLabel: String {
        if daysOverdue >= 5 { return "CRITICAL" }
        if daysOverdue >= 3 { return "URGENT" }
        return "OVERDUE"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Overdue indicator strip ──────────────────────────────────────
            HStack(spacing: 0) {
                Rectangle()
                    .fill(urgencyColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(order.title)
                                .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                                .lineLimit(1)
                            Text("Due: \(order.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                        Spacer()

                        // Overdue duration badge
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(urgencyLabel)
                                .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .black))
                                .foregroundColor(urgencyColor)
                            Text("\(daysOverdue)d late")
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(urgencyColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(urgencyColor.opacity(0.10))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Divider().padding(.horizontal, 14)

                    // Detail rows
                    VStack(alignment: .leading, spacing: 8) {
                        OverdueDetailRow(
                            icon: "wrench.fill",
                            label: "Pending Service",
                            value: order.workDescription.isEmpty ? "Unspecified Maintenance" : order.workDescription,
                            color: urgencyColor
                        )
                        OverdueDetailRow(
                            icon: "calendar.badge.exclamationmark",
                            label: "Due Date",
                            value: order.createdAt.formatted(date: .complete, time: .omitted),
                            color: AppTheme.Brand.primary
                        )
                        OverdueDetailRow(
                            icon: "clock.badge.xmark",
                            label: "Days Overdue",
                            value: daysOverdue == 1 ? "1 day overdue" : "\(daysOverdue) days overdue",
                            color: urgencyColor
                        )
                        OverdueDetailRow(
                            icon: "person.badge.clock.fill",
                            label: "Assigned To",
                            value: "Tech #\(order.assignedTo.uuidString.prefix(4).uppercased())",
                            color: AppTheme.Brand.violet
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 14)

                    // Footer
                    HStack {
                        PriorityBadge(priority: order.priority)
                        Spacer()
                        TaskStatusBadge(
                            label: order.status.displayLabel,
                            color: order.status.color,
                            icon: "circle.fill"
                        )
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                            .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                            .padding(.leading, 6)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: urgencyColor.opacity(0.12), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(
                    LinearGradient(
                        colors: [urgencyColor.opacity(0.22), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

private struct OverdueDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                .foregroundColor(AppTheme.Text.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}
