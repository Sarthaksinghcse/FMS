//
//  MaintenanceEditSheet.swift
//  FMS
//
//  Created by Gauri Verma on 27/05/26.
//

import SwiftUI
import SwiftData

struct SparePartsSelectorView: View {
    let inStockInventory: [InventoryItem]
    @Binding var partsList: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In-Stock Spare Parts:")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Text.secondary)
            
            Menu {
                ForEach(inStockInventory, id: \.id) { item in
                    Button {
                        if !partsList.contains(item.partName) {
                            partsList.append(item.partName)
                        }
                    } label: {
                        HStack {
                            Text(item.partName)
                            Spacer()
                            Text("(\(item.quantityInStock) available)")
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Brand.primary)
                    
                    Text("Select In-Stock Part...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Text.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.04))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }
}

struct MaintenanceEditSheet: View {
    @Bindable var order: WorkOrder
    var currentUser: User
    var allVehicles: [Vehicle]
    var onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Query actual spare parts inventory from SwiftData
    @Query private var allInventory: [InventoryItem]

    private var inStockInventory: [InventoryItem] {
        allInventory.filter { $0.quantityInStock > 0 }
    }

    @State private var notesInput: String = ""
    @State private var costInput: String = ""
    @State private var currentPart: String = ""
    @State private var partsList: [String] = []

    init(order: WorkOrder, currentUser: User, allVehicles: [Vehicle], onSave: @escaping () -> Void) {
        self.order = order
        self.currentUser = currentUser
        self.allVehicles = allVehicles
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

                        // Add Spare Parts Used (Criterion 1 & 3 & 4)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spare Parts & Consumables Used")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)

                            // Premium in-stock parts selector (displays live spare parts catalog)
                            if !inStockInventory.isEmpty {
                                SparePartsSelectorView(inStockInventory: inStockInventory, partsList: $partsList)
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
                                        .buttonStyle(PlainButtonStyle())
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
                        saveOrder(order: order)
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func saveOrder(order: WorkOrder) {
        // Apply cost and notes updates
        order.estimatedCost = Double(costInput)
        
        // Append parts list to notes if added
        if !partsList.isEmpty {
            let partsStr = "\nParts used: \(partsList.joined(separator: ", "))"
            order.workDescription = notesInput + partsStr
            
            // ── Automated Stock Deduction (Criterion 3 & 4) ─────────────
            for partName in partsList {
                if let matchedItem = allInventory.first(where: { $0.partName.localizedCaseInsensitiveCompare(partName) == .orderedSame }) {
                    if matchedItem.quantityInStock > 0 {
                        matchedItem.quantityInStock -= 1
                        
                        // Sync stock deduction to database
                        let dbItem = matchedItem.asDBItem
                        Task {
                            try? await SupabaseManager.shared.updateInventoryItem(dbItem)
                        }
                        
                        // Trigger Alert Notification if stock becomes low (Criterion 4)
                        if matchedItem.quantityInStock <= matchedItem.reorderThreshold {
                            let alertNotification = AppNotification(
                                id: UUID(),
                                userId: order.assignedTo,
                                title: "Low Stock Alert: \(matchedItem.partName)",
                                message: "Inventory for \(matchedItem.partName) is critically low: \(matchedItem.quantityInStock) units left (threshold: \(matchedItem.reorderThreshold)).",
                                type: .maintenanceAlert,
                                isRead: false,
                                createdAt: Date()
                            )
                            modelContext.insert(alertNotification)
                            
                            // Sync notification to database
                            let dbNotif = alertNotification.asDBNotification
                            Task {
                                try? await SupabaseManager.shared.createNotification(dbNotif)
                            }
                        }
                    }
                }
            }
        } else {
            order.workDescription = notesInput
        }

        let isCompleted = order.status == .completed

        if isCompleted {
            order.completedAt = Date()
            
            // Create MaintenanceRecord
            let record = MaintenanceRecord(
                vehicleId: order.vehicleId,
                workOrderId: order.id,
                serviceType: order.title,
                serviceDate: Date(),
                cost: Double(costInput) ?? 0.0,
                notes: order.workDescription,
                replacedParts: partsList,
                performedBy: currentUser.id
            )
            modelContext.insert(record)
            
            // Sync maintenance record to database
            let dbRecord = record.asDBRecord
            Task {
                try? await SupabaseManager.shared.createMaintenanceRecord(dbRecord)
            }
            
            // Update associated vehicle
            if let vehicle = allVehicles.first(where: { $0.id == order.vehicleId }) {
                vehicle.status = .active
                vehicle.lastServiceDate = Date()
                vehicle.nextServiceDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
                
                // Sync vehicle update to database
                let dbVehicle = vehicle.asDBVehicle
                Task {
                    try? await SupabaseManager.shared.updateVehicle(dbVehicle)
                }
            }
        }
        
        // Sync WorkOrder update to database
        let dbOrder = order.asDBWorkOrder
        Task {
            try? await SupabaseManager.shared.updateWorkOrder(dbOrder)
        }
        
        try? modelContext.save()
        onSave()
        dismiss()
    }
}
