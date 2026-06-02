//
//  Inventory.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import SwiftData

struct InventoryTabView: View {
    @Environment(\.modelContext) private var modelContext
    let currentUser: User
    let items: [InventoryItem]

    @Query private var allNotifications: [AppNotification]
    
    @State private var searchText: String = ""
    @State private var selectedFilter: Int = 0 // 0: All, 1: Low Stock, 2: In Stock
    @State private var showingAddInventory = false
    @State private var selectedDetailItem: InventoryItem? = nil

    private var lowStock: [InventoryItem] { items.filter { $0.quantityInStock <= $0.reorderThreshold } }
    
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

    private var totalQuantity: Int {
        items.reduce(0) { $0 + $1.quantityInStock }
    }

    private var filteredItems: [InventoryItem] {
        var baseItems = items
        if selectedFilter == 1 {
            baseItems = items.filter { $0.quantityInStock <= $0.reorderThreshold }
        } else if selectedFilter == 2 {
            baseItems = items.filter { $0.quantityInStock > $0.reorderThreshold }
        }
        
        if searchText.isEmpty {
            return baseItems
        } else {
            return baseItems.filter {
                $0.partName.localizedCaseInsensitiveContains(searchText) ||
                $0.partNumber.localizedCaseInsensitiveContains(searchText) ||
                ($0.supplierName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // AI Spare Parts Forecast Report Banner
                        NavigationLink {
                            SparePartsForecastView()
                        } label: {
                            HStack {
                                HStack(spacing: 10) {
                                    ZStack {
                                        Circle()
                                            .fill(AppTheme.Brand.primary.opacity(0.12))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(AppTheme.Brand.primary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("AI Spare Parts Forecast")
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.black)
                                        Text("Predictive stock demand & reorder intelligence")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(AppTheme.Brand.primary.opacity(0.04))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.Brand.primary.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Stats Dashboard Bar
                        HStack(spacing: 12) {
                            // Total Parts
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Parts")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                Text("\(items.count)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.Background.card)
                            .cornerRadius(12)
                            
                            // Low Stock Alert
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Low Stock")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                  HStack(spacing: 4) {
                                    Text("\(lowStock.count)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(lowStock.isEmpty ? AppTheme.Text.primary : AppTheme.Status.danger)
                                    if !lowStock.isEmpty {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Status.danger)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.Background.card)
                            .cornerRadius(12)
                            
                            // Total Quantity
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Units")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                Text("\(totalQuantity)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.Background.card)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Search & Filter Controls
                        VStack(spacing: 10) {
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextField("Search parts, number, supplier...", text: $searchText)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Text.primary)
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppTheme.Text.tertiary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(AppTheme.Background.card)
                            .cornerRadius(10)
                            .padding(.horizontal)

                            // Native Segmented Picker (HIG Compliant)
                            Picker("Inventory Filter", selection: $selectedFilter) {
                                Text("All").tag(0)
                                Text("Low Stock").tag(1)
                                Text("Healthy Stock").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }

                        // Cards List
                        if filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppTheme.Text.tertiary)
                                Text("No parts found")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                Text("Try adjusting your search or filter.")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Text.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems) { item in
                                    InventoryRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedDetailItem = item
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    }
                }
                .refreshable {
                    await SupabaseManager.shared.syncAllData(context: modelContext)
                }
                
                // FAB to Add Spare Parts
                Button {
                    showingAddInventory = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: AppTheme.Brand.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .background(AppTheme.Background.page)
            .navigationTitle("Inventory")
            .sheet(isPresented: $showingAddInventory) {
                AddInventoryView()
            }
            .sheet(item: $selectedDetailItem) { item in
                InventoryDetailView(item: item)
            }
        }
    }
}

struct InventoryRow: View {
    let item: InventoryItem

    private var isLow: Bool { item.quantityInStock <= item.reorderThreshold }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Left side: Elegant dynamic icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isLow ? AppTheme.Brand.accent.opacity(0.12) : AppTheme.Brand.teal.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isLow ? "exclamationmark.triangle.fill" : "shippingbox.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isLow ? AppTheme.Brand.accent : AppTheme.Brand.teal)
                }
                
                // Middle: Part info
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.partName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    
                    HStack(spacing: 8) {
                        Text("P/#\(item.partNumber)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Text.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Background.page)
                            .cornerRadius(4)
                        
                        if let supplier = item.supplierName, !supplier.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 10))
                                Text(supplier)
                            }
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Right side: Stock Levels
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(item.quantityInStock)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(isLow ? AppTheme.Status.danger : AppTheme.Text.primary)
                    
                    Text("units in stock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                }
            }
            
            // Bottom Stock Health indicator
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Reorder Threshold: \(item.reorderThreshold) · Cost: ₹\(String(format: "%.2f", item.unitCost))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                    
                    Spacer()
                    
                    if isLow {
                        Text("CRITICAL STOCK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.Status.danger)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Status.danger.opacity(0.12))
                            .cornerRadius(4)
                    } else {
                        Text("HEALTHY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.Status.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Status.success.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
                
                // Progress Bar
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    // Fill percentage relative to reorder threshold * 2 or just standard safety margin
                    let percentage = CGFloat(min(Double(item.quantityInStock) / Double(max(1, item.reorderThreshold * 2)), 1.0))
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Glass.ringTrack)
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(isLow ? AppTheme.Status.danger : AppTheme.Status.success)
                            .frame(width: totalWidth * percentage, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
    }
}
