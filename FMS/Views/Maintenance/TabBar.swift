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
    @ObservedObject private var accessibility = AccessibilityManager.shared

    // Logged-in maintenance user
    let currentUser: User

    // SwiftData queries (only used to pass to inventory and/or derive badge counts)
    @Query private var allInventory: [InventoryItem]

    @State private var selectedTab: Int = 0
    @State private var schedulingFilter: Int = 0
    @State private var realtimeChannel: RealtimeChannelV2? = nil
    @State private var pollingTask: Task<Void, Never>? = nil

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
        .tint(AppTheme.Brand.primary)
        .task {
            await SupabaseManager.shared.syncAllData(context: modelContext)
            startRealtimeListener()
            
            pollingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    if Task.isCancelled { break }
                    print("🔄 [Maintenance Dashboard Polling] Syncing latest database changes...")
                    await SupabaseManager.shared.syncAllData(context: modelContext)
                }
            }
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
            
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
            let inventoryStream = channel.postgresChange(AnyAction.self, schema: "public", table: "inventory_items")
            let notificationStream = channel.postgresChange(AnyAction.self, schema: "public", table: "notifications")
            
            do {
                try await channel.subscribeWithError()
                print("🟢 [Maintenance Realtime] Subscribed successfully to channel: maintenance_dashboard_realtime")
            } catch {
                print("❌ [Maintenance Realtime] Subscription failed: \(error.localizedDescription)")
            }
            
            async let _ : () = handleStream(workOrderStream, tableName: "work_orders")
            async let _ : () = handleStream(vehicleStream, tableName: "vehicles")
            async let _ : () = handleStream(inventoryStream, tableName: "inventory_items")
            async let _ : () = handleStream(notificationStream, tableName: "notifications")
        }
    }
    
    private func handleStream<S: AsyncSequence>(_ stream: S, tableName: String) async {
        print("🟢 [Maintenance Realtime] Stream listener active for: \(tableName)")
        do {
            for try await event in stream {
                print("⚡️ [Maintenance Realtime] Event detected in \(tableName): \(event)")
                await SupabaseManager.shared.syncAllData(context: modelContext)
            }
        } catch {
            print("❌ [Maintenance Realtime] Stream error in \(tableName): \(error)")
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
