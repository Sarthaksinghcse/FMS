//
//  UpdateMaintenanceView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI
import SwiftData

struct UpdateMaintenanceView: View {
    let currentUser: User
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // SwiftData Query for all active/incomplete work orders
    @Query private var allWorkOrders: [WorkOrder]
    @Query private var allVehicles: [Vehicle]
    @Query(sort: \MaintenanceRecord.serviceDate, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]

    @State private var searchText = ""
    @State private var filterStatus: Int = 0 // 0 = Active, 1 = Service History

    @State private var selectedOrder: WorkOrder? = nil
    @State private var selectedRecord: MaintenanceRecord? = nil
    @State private var showDirectRecordSheet = false

    // Filtered orders
    private var filteredOrders: [WorkOrder] {
        allWorkOrders.filter { order in
            // Filter by completion status
            let matchesStatus = (order.status != .completed && order.status != .cancelled)
            
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
                    Text("Service History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if filterStatus == 0 {
                    // Search Bar
                    TaskSearchBar(text: $searchText, placeholder: "Search work orders...")
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    if filteredOrders.isEmpty {
                        Spacer()
                        DetailEmptyState(
                            icon: "wrench.and.screwdriver",
                            title: "No Work Orders",
                            message: "No active work orders were found matching your selection.",
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
                } else {
                    if maintenanceRecords.isEmpty {
                        Spacer()
                        DetailEmptyState(
                            icon: "doc.text.magnifyingglass",
                            title: "No Service History",
                            message: "No completed maintenance records found.",
                            accentColor: AppTheme.Brand.amber
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(maintenanceRecords) { record in
                                    Button {
                                        selectedRecord = record
                                    } label: {
                                        MaintenanceRecordCard(record: record, vehicle: findVehicle(for: record.vehicleId))
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
        }
        .navigationTitle("Update Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if filterStatus == 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDirectRecordSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Brand.amber)
                    }
                }
            }
        }
        .sheet(item: $selectedOrder) { order in
            MaintenanceEditSheet(order: order, currentUser: currentUser, allVehicles: allVehicles, onSave: {
                try? modelContext.save()
                selectedOrder = nil
            })
        }
        .sheet(item: $selectedRecord) { record in
            MaintenanceRecordDetailSheet(record: record, vehicle: findVehicle(for: record.vehicleId))
        }
        .sheet(isPresented: $showDirectRecordSheet) {
            RecordDirectMaintenanceSheet(currentUser: currentUser, allVehicles: allVehicles)
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
                let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
                let statText = isPending ? "Approval Pending" : order.status.displayLabel
                let statColor = isPending ? AppTheme.Brand.amber : order.status.color
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statColor)
                        .frame(width: 8, height: 8)
                    Text(statText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(statColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statColor.opacity(0.08))
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

// MARK: - Record Card Component
private struct MaintenanceRecordCard: View {
    let record: MaintenanceRecord
    let vehicle: Vehicle?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.serviceType)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                        .lineLimit(1)
                    
                    if let vehicle = vehicle {
                        Text("\(vehicle.make) \(vehicle.model) (Reg: \(vehicle.registrationNumber))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }
                Spacer()
                Text(record.serviceDate, format: .dateTime.day().month().year())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Text.tertiary)
            }

            Divider()

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Status.success)
                    Text("Completed")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Status.success)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.Status.success.opacity(0.08))
                .cornerRadius(8)

                Spacer()

                Text("₹\(Int(record.cost))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.Brand.amber)
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, y: 3)
    }
}

// MARK: - Maintenance Record Detail Sheet
private struct MaintenanceRecordDetailSheet: View {
    let record: MaintenanceRecord
    let vehicle: Vehicle?
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Service Information")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 12) {
                                ProfileInfoRow(label: "Service Type", value: record.serviceType)
                                Divider().padding(.leading, 16)
                                ProfileInfoRow(label: "Cost", value: "₹\(Int(record.cost))", valueColor: AppTheme.Brand.amber)
                                Divider().padding(.leading, 16)
                                ProfileInfoRow(label: "Date", value: record.serviceDate.formatted(date: .abbreviated, time: .omitted))
                            }
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.03))
                            .cornerRadius(12)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)

                        if !record.replacedParts.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Replaced Parts")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                    .textCase(.uppercase)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(record.replacedParts, id: \.self) { part in
                                        HStack(spacing: 5) {
                                            Image(systemName: "cube.box.fill")
                                                .font(.system(size: 10))
                                            Text(part)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(AppTheme.Brand.violet)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(AppTheme.Brand.violet.opacity(0.1))
                                        .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                        }
                        
                        if let notes = record.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Work Notes")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                    .textCase(.uppercase)
                                
                                Text(notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Text.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.03))
                                    .cornerRadius(12)
                            }
                            .padding(16)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Record Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Record Direct Maintenance Sheet
private struct RecordDirectMaintenanceSheet: View {
    let currentUser: User
    let allVehicles: [Vehicle]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Query actual spare parts inventory from SwiftData
    @Query private var allInventory: [InventoryItem]

    private var inStockInventory: [InventoryItem] {
        allInventory.filter { $0.quantityInStock > 0 }
    }

    @State private var selectedVehicleId: UUID? = nil
    @State private var serviceType: String = ""
    @State private var serviceDate: Date = Date()
    @State private var costInput: String = ""
    @State private var notesInput: String = ""
    @State private var partsList: [String] = []

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Service Information")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Vehicle")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                Picker("Select Vehicle", selection: $selectedVehicleId) {
                                    Text("Select a vehicle").tag(UUID?.none)
                                    ForEach(allVehicles) { vehicle in
                                        Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))")
                                            .tag(UUID?.some(vehicle.id))
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Service Type")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextField("e.g. Engine Repair, Battery Replacement", text: $serviceType)
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Service Date")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                DatePicker("", selection: $serviceDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Total Cost (INR)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextField("e.g. 2500", text: $costInput)
                                    .keyboardType(.numberPad)
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Spare Parts & Consumables Used")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)

                            // Premium in-stock parts selector (displays live spare parts catalog dropdown)
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
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Work Notes")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                            
                            TextEditor(text: $notesInput)
                                .frame(minHeight: 120)
                                .padding(6)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let vId = selectedVehicleId else { return }
                        
                        // Append parts list to notes if added
                        let finalNotes: String
                        if !partsList.isEmpty {
                            finalNotes = notesInput + "\nParts used: \(partsList.joined(separator: ", "))"
                            
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
                                                userId: currentUser.id,
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
                            finalNotes = notesInput
                        }

                        let record = MaintenanceRecord(
                            vehicleId: vId,
                            workOrderId: nil,
                            serviceType: serviceType,
                            serviceDate: serviceDate,
                            cost: Double(costInput) ?? 0.0,
                            notes: finalNotes,
                            replacedParts: partsList,
                            performedBy: currentUser.id
                        )
                        modelContext.insert(record)
                        
                        // Sync maintenance record to database
                        let dbRecord = record.asDBRecord
                        Task {
                            try? await SupabaseManager.shared.createMaintenanceRecord(dbRecord)
                        }
                        
                        if let vehicle = allVehicles.first(where: { $0.id == vId }) {
                            vehicle.status = .active
                            vehicle.lastServiceDate = serviceDate
                            vehicle.nextServiceDate = Calendar.current.date(byAdding: .month, value: 3, to: serviceDate)
                            
                            // Sync vehicle update to database
                            let dbVehicle = vehicle.asDBVehicle
                            Task {
                                try? await SupabaseManager.shared.updateVehicle(dbVehicle)
                            }
                        }
                        
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(selectedVehicleId == nil || serviceType.isEmpty)
                }
            }
        }
    }
}
