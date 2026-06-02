//
//  TabBar.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI
import SwiftData
import Supabase

struct MaintenanceDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    // Logged-in maintenance user
    let currentUser: User

    // SwiftData queries (only used to pass to inventory and/or derive badge counts)
    @Query private var allInventory: [InventoryItem]

    @State private var selectedTab: Int = 0
    @State private var schedulingFilter: Int = 0
    @State private var realtimeChannel: RealtimeChannelV2? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            MaintenanceDashboardTab(currentUser: currentUser, selectedTab: $selectedTab, schedulingFilter: $schedulingFilter)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            MaintenanceWorkOrdersTab(currentUser: currentUser)
                .tabItem {
                    Label("Work Orders", systemImage: "wrench.and.screwdriver.fill")
                }
                .tag(1)

            InventoryTabView(currentUser: currentUser, items: allInventory)
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
                .tag(2)
        }
        .accentColor(AppTheme.Brand.primary)
        .task {
            await SupabaseManager.shared.syncAllData(context: modelContext)
            startRealtimeListener()
        }
        .onDisappear {
            if let activeChannel = realtimeChannel {
                let client = SupabaseManager.shared.client
                Task {
                    await client.removeChannel(activeChannel)
                }
                realtimeChannel = nil
            }
        }
    }

    private func startRealtimeListener() {
        guard realtimeChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("maintenance_dashboard_realtime")
        self.realtimeChannel = channel
        
        Task {
            let workOrderStream = channel.postgresChange(AnyAction.self, schema: "public", table: "work_orders")
            let vehicleStream = channel.postgresChange(AnyAction.self, schema: "public", table: "vehicles")
            
            try? await channel.subscribeWithError()
            
            async let _ : () = handleStream(workOrderStream)
            async let _ : () = handleStream(vehicleStream)
        }
    }
    
    private func handleStream<S: AsyncSequence>(_ stream: S) async {
        do {
            for try await _ in stream {
                await SupabaseManager.shared.syncAllData(context: modelContext)
            }
        } catch {
            print("Stream error: \(error)")
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
