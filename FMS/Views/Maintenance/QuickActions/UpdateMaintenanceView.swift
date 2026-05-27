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

// MARK: - Edit Sheet
private struct MaintenanceEditSheet: View {
    @Bindable var order: WorkOrder
    var onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    @State private var notesInput: String = ""
    @State private var costInput: String = ""
    @State private var currentPart: String = ""
    @State private var partsList: [String] = []

    init(order: WorkOrder, onSave: @escaping () -> Void) {
        self.order = order
        self.onSave = onSave
        
        // Populate initial values
        _notesInput = State(initialValue: order.workDescription)
        if let cost = order.estimatedCost {
            _costInput = State(initialValue: String(format: "%.0f", cost))
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Status Picker Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Task Status")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                            
                            Picker("Status", selection: $order.status) {
                                Text("Pending").tag(WorkOrderStatus.open)
                                Text("In Progress").tag(WorkOrderStatus.inProgress)
                                Text("Completed").tag(WorkOrderStatus.completed)
                                Text("Cancelled").tag(WorkOrderStatus.cancelled)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)

                        // Costs & Notes
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Service Record Details")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)

                            // Cost field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Total Estimated Cost (INR)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextField("e.g. 7500", text: $costInput)
                                    .keyboardType(.numberPad)
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }

                            // Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Work Description & Progress Notes")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextEditor(text: $notesInput)
                                    .frame(minHeight: 120)
                                    .padding(6)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)

                        // Add Spare Parts Used
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spare Parts & Consumables Used")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)

                            HStack {
                                TextField("Add part e.g. Spark Plug, Air Filter", text: $currentPart)
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                                
                                Button {
                                    if !currentPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        partsList.append(currentPart)
                                        currentPart = ""
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(AppTheme.Brand.primary)
                                }
                            }

                            if !partsList.isEmpty {
                                ForEach(partsList, id: \.self) { part in
                                    HStack {
                                        Image(systemName: "cube.box.fill")
                                            .foregroundColor(AppTheme.Brand.violet)
                                        Text(part)
                                            .font(.system(size: 13, weight: .medium))
                                        Spacer()
                                        Button {
                                            partsList.removeAll(where: { $0 == part })
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Update Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Apply cost and notes updates
                        order.estimatedCost = Double(costInput)
                        
                        // Append parts list to notes if added
                        if !partsList.isEmpty {
                            let partsStr = "\nParts used: \(partsList.joined(separator: ", "))"
                            order.workDescription = notesInput + partsStr
                        } else {
                            order.workDescription = notesInput
                        }

                        if order.status == .completed {
                            order.completedAt = Date()
                        }
                        
                        onSave()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
