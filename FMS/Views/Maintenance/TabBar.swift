//
//  TabBar.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//



import SwiftUI
import SwiftData

struct MaintenanceDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // Logged-in maintenance user
    let currentUser: User

    // SwiftData queries (only used to pass to inventory and/or derive badge counts)
    @Query private var allInventory: [InventoryItem]

    @State private var selectedTab: Int = 0
    @State private var schedulingFilter: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MaintenanceDashboardTab(currentUser: currentUser, selectedTab: $selectedTab, schedulingFilter: $schedulingFilter)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            InventoryTabView(currentUser: currentUser, items: allInventory)
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox")
                }
                .tag(1)

        }
        .accentColor(AppTheme.Brand.primary)
        .task {
            await SupabaseManager.shared.syncAllData(context: modelContext)
        }
    }
}

// MARK: - Preview

#Preview {
    let user = User(
        fullName: "Raj Kumar",
        email: "raj@fleet.com",
        phoneNumber: "9876543210",
        passwordHash: "hashed",
        role: .maintenance
    )
    
    MaintenanceDashboardView(currentUser: user)
        .modelContainer(for: [WorkOrder.self, InventoryItem.self, AppNotification.self, Vehicle.self, User.self], inMemory: true)
}
