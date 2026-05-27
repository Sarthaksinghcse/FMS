//
//  UpdateMaintenanceView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI
import SwiftData

struct UpdateMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // SwiftData Query for all active/incomplete work orders
    @Query private var allWorkOrders: [WorkOrder]
    @Query private var allVehicles: [Vehicle]

    @State private var searchText = ""
    @State private var filterStatus: Int = 0 // 0 = Active (Open/In Progress), 1 = Completed

    @State private var selectedOrder: WorkOrder? = nil

    // Filtered orders
    private var filteredOrders: [WorkOrder] {
        allWorkOrders.filter { order in
            // Filter by completion status
            let matchesStatus = (filterStatus == 0) ? (order.status != .completed && order.status != .cancelled) : (order.status == .completed)
            
            // Filter by search text
            if !searchText.isEmpty {
                let matchesSearch = order.title.localizedCaseInsensitiveContains(searchText) ||
                                    order.workDescription.localizedCaseInsensitiveContains(searchText)
                return matchesStatus && matchesSearch
            }
            return matchesStatus
        }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Filter Tabs
                Picker("Status Filter", selection: $filterStatus) {
                    Text("Active Tasks").tag(0)
                    Text("Completed").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Search Bar
                TaskSearchBar(text: $searchText, placeholder: "Search work orders...")
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if filteredOrders.isEmpty {
                    Spacer()
                    DetailEmptyState(
                        icon: "wrench.and.screwdriver",
                        title: "No Work Orders",
                        message: "No work orders were found matching your selection.",
                        accentColor: AppTheme.Brand.primary
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredOrders) { order in
                                Button {
                                    selectedOrder = order
                                } label: {
                                    UpdateOrderCard(order: order, vehicle: findVehicle(for: order.vehicleId))
                                }
                                .buttonStyle(TactileScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("Update Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedOrder) { order in
            MaintenanceEditSheet(order: order, onSave: {
                try? modelContext.save()
                selectedOrder = nil
            })
        }
    }

    private func findVehicle(for id: UUID) -> Vehicle? {
        allVehicles.first(where: { $0.id == id })
    }
}

// MARK: - Update Card Component
private struct UpdateOrderCard: View {
    let order: WorkOrder
    let vehicle: Vehicle?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        .lineLimit(1)
                    
                    if let vehicle = vehicle {
                        Text("\(vehicle.make) \(vehicle.model) (Reg: \(vehicle.registrationNumber))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Text.secondary)
                    } else {
                        Text("Vehicle ID: \(order.vehicleId.uuidString.prefix(6))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }
                Spacer()
                PriorityBadge(priority: order.priority)
            }

            Divider()

            HStack {
                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(order.status.color)
                        .frame(width: 8, height: 8)
                    Text(order.status.displayLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(order.status.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(order.status.color.opacity(0.08))
                .cornerRadius(8)

                Spacer()

                if let cost = order.estimatedCost {
                    Text("Est: ₹\(Int(cost))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Text.secondary)
                }

                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Brand.primary)
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, y: 3)
    }
}

// MARK: - Note: MaintenanceEditSheet has been extracted to its own dedicated file.
