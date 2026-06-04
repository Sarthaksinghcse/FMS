// FMS/Views/Maintenance/MaintenanceWorkOrdersTab.swift
import SwiftUI
import SwiftData

struct MaintenanceWorkOrdersTab: View {
    let currentUser: User

    @Query private var allWorkOrders: [WorkOrder]
    @State private var selectedStatusFilter: Int = 0 // 0: Open, 1: In Progress, 2: Completed

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Picker for status
                Picker("Status", selection: $selectedStatusFilter) {
                    Text("Open").tag(0)
                    Text("In Progress").tag(1)
                    Text("Completed").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Group {
                    switch selectedStatusFilter {
                    case 0:
                        ScheduledTasksView(currentUser: currentUser, allWorkOrders: allWorkOrders)
                    case 1:
                        InProgressTasksView(currentUserId: currentUser.id, allWorkOrders: allWorkOrders)
                    default:
                        CompletedTasksView(currentUserId: currentUser.id, allWorkOrders: allWorkOrders)
                    }
                }
                .transition(.opacity)
            }
            .background(AppTheme.Background.page)
            .navigationTitle("Work Orders")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
