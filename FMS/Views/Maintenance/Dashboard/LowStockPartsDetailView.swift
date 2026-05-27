//
//  LowStockPartsDetailView.swift
//  FMS
//
//  Created by Naman Yadav on 27/05/26.
//

import SwiftUI
import SwiftData

struct LowStockPartsDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allInventory: [InventoryItem]
    
    @Environment(\.dismiss) private var dismiss
    
    private var lowStockItems: [InventoryItem] {
        allInventory.filter { $0.quantityInStock <= $0.reorderThreshold }
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Text.primary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(AppTheme.Background.card)
                
                // Premium Custom Header
                MaintenanceHeaderView(
                    title: "Low Stock Parts",
                    subtitle: "Manage parts that require immediate restocking.",
                    initials: "",
                    avatarColor: AppTheme.Status.danger,
                    notificationCount: 0,
                    showActions: false
                )
                .background(AppTheme.Background.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, y: 2)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if lowStockItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppTheme.Status.success)
                                Text("Inventory is Healthy")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.Text.primary)
                                Text("All parts currently satisfy safe restocking thresholds.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Text.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                        } else {
                            Text("The following items require immediate reordering:")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Text.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(lowStockItems) { item in
                                    InventoryRow(item: item)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 32)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    NavigationStack {
        LowStockPartsDetailView()
            .modelContainer(for: [InventoryItem.self], inMemory: true)
    }
}
