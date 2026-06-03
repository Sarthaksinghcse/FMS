//
//  Scheduling.swift
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
final class ScheduledTasksViewModel: ObservableObject {

    // MARK: Published state
    @Published var searchText: String = ""
    @Published var selectedFilter: Int = 0    // 0=All, 1=High Priority, 2=Assigned To Me

    // MARK: Data (injected from SwiftData queries + user context)
    let currentUserId: UUID
    private let allWorkOrders: [WorkOrder]

    init(currentUserId: UUID, allWorkOrders: [WorkOrder]) {
        self.currentUserId = currentUserId
        self.allWorkOrders = allWorkOrders
    }

    // MARK: Filtered tasks
    var filteredTasks: [WorkOrder] {
        var base = allWorkOrders.filter { order in
            order.status == .open
        }

        // Apply chip filter
        switch selectedFilter {
        case 1: base = base.filter { $0.priority == .high || $0.priority == .urgent }
        case 2: base = base.filter { $0.assignedTo == currentUserId }
        default: break
        }

        // Apply search
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            base = base.filter {
                $0.title.lowercased().contains(q) ||
                $0.workDescription.lowercased().contains(q)
            }
        }

        return base.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    var filterChips: [String] { ["All", "High Priority", "Assigned To Me"] }
    var accentColor: Color { AppTheme.Brand.amber }
}

extension WorkOrderPriority {
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high:   return 1
        case .medium: return 2
        case .low:    return 3
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Main View
// ─────────────────────────────────────────────────────────────────────────────

struct ScheduledTasksView: View {
    let currentUser: User
    let hidesTabBar: Bool
    @StateObject private var vm: ScheduledTasksViewModel
    @Environment(\.dismiss) private var dismiss
    private var externalFilter: Binding<Int>?

    @Query private var allNotifications: [AppNotification]

    init(currentUser: User, allWorkOrders: [WorkOrder], selectedFilter: Binding<Int>? = nil, hidesTabBar: Bool = false) {
        self.currentUser = currentUser
        self.externalFilter = selectedFilter
        self.hidesTabBar = hidesTabBar
        _vm = StateObject(wrappedValue: ScheduledTasksViewModel(
            currentUserId: currentUser.id,
            allWorkOrders: allWorkOrders
        ))
    }

    private var filterBinding: Binding<Int> {
        Binding(
            get: { externalFilter?.wrappedValue ?? vm.selectedFilter },
            set: { newValue in
                externalFilter?.wrappedValue = newValue
                vm.selectedFilter = newValue
            }
        )
    }

    private var initials: String {
        let components = currentUser.fullName.components(separatedBy: " ")
        let first = components.first?.first.map(String.init) ?? ""
        let last = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        let combined = first + last
        return combined.isEmpty ? "M" : combined.uppercased()
    }

    private var unreadNotificationsCount: Int {
        allNotifications.filter { $0.userId == currentUser.id && !$0.isRead }.count
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            // Empty / Populated content
                            if vm.filteredTasks.isEmpty {
                                DetailEmptyState(
                                    icon: "doc.text.magnifyingglass",
                                    title: "No Tasks Found",
                                    message: "No maintenance tasks are scheduled for today matching your filters.",
                                    accentColor: vm.accentColor
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(vm.filteredTasks) { order in
                                        NavigationLink(destination: MaintenanceTaskDetailView(order: order)) {
                                            ScheduledTaskCard(order: order)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 32)
                            }
                        } header: {
                            VStack(spacing: 12) {
                                // Search
                                TaskSearchBar(text: $vm.searchText, placeholder: "Search by vehicle, service type...")
                                    .padding(.top, 8)

                                // Filter chips
                                FilterChipRow(
                                    chips: vm.filterChips,
                                    selected: filterBinding,
                                    accentColor: vm.accentColor
                                )
                                .padding(.bottom, 4)
                            }
                            .background(AppTheme.Background.page)
                        }
                    }
                }
            }
        }
        .toolbar(hidesTabBar ? .hidden : .automatic, for: .tabBar)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Task Card
// ─────────────────────────────────────────────────────────────────────────────

private struct ScheduledTaskCard: View {
    let order: WorkOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top header bar with priority accent
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(order.priority.detailColor)
                        .frame(width: 8, height: 8)
                    Text(order.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        .lineLimit(1)
                }
                Spacer()
                PriorityBadge(priority: order.priority)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            // Detail rows
            VStack(alignment: .leading, spacing: 8) {
                ScheduledDetailRow(
                    icon: "wrench.and.screwdriver",
                    label: "Service Type",
                    value: order.workDescription.isEmpty ? "General Maintenance" : order.workDescription,
                    color: AppTheme.Brand.amber
                )
                ScheduledDetailRow(
                    icon: "clock",
                    label: "Scheduled",
                    value: order.createdAt.formatted(date: .omitted, time: .shortened),
                    color: AppTheme.Brand.primary
                )
                ScheduledDetailRow(
                    icon: "person.fill",
                    label: "Assigned Mechanic",
                    value: "Mechanic #\(order.assignedTo.uuidString.prefix(4).uppercased())",
                    color: AppTheme.Brand.violet
                )
                ScheduledDetailRow(
                    icon: "mappin.circle.fill",
                    label: "Location",
                    value: "Service Bay \(Int(order.id.hashValue % 6 + 1))",
                    color: AppTheme.Status.success
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)

            // Footer: Status + chevron
            HStack {
                let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
                let displayLabel = isPending ? "Approval Pending" : order.status.displayLabel
                let displayColor = isPending ? AppTheme.Brand.amber : order.status.color
                let displayIcon = isPending ? "clock.fill" : "circle.fill"
                
                TaskStatusBadge(
                    label: displayLabel,
                    color: displayColor,
                    icon: displayIcon
                )
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(
                    LinearGradient(colors: [AppTheme.Brand.amber.opacity(0.18), Color.clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
}

private struct ScheduledDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Text.primary)
                .lineLimit(1)
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MaintenanceSchedulingTab Wrapper
// ─────────────────────────────────────────────────────────────────────────────

struct MaintenanceSchedulingTab: View {
    let currentUser: User
    @Binding var selectedFilter: Int

    @Query private var allWorkOrders: [WorkOrder]

    var body: some View {
        NavigationStack {
            ScheduledTasksView(
                currentUser: currentUser,
                allWorkOrders: allWorkOrders,
                selectedFilter: $selectedFilter
            )
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
