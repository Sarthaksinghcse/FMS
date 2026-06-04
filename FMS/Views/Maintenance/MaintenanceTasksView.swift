//
//  MaintenanceTasksView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import Supabase
import AVFoundation

struct MaintenanceTaskDetailView: View {
    let order: WorkOrder

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var inventoryItems: [InventoryItem]

    @ObservedObject private var accessibility = AccessibilityManager.shared
    @State private var speechSynthesizer = AVSpeechSynthesizer()

    @State private var repairNotes: String = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var repairPhotos: [UIImage] = []
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var uploadError: String? = nil

    @State private var laborCostText: String = ""
    @State private var selectedParts: [UUID: Int] = [:]

    private func speak(_ text: String) {
        AudioSpeechManager.shared.speak(text)
    }

    private var statusColor: Color {
        if order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]") {
            return AppTheme.Brand.amber
        }
        return order.status.color
    }

    private var mechanicDisplayId: String {
        "TECH-" + order.assignedTo.uuidString.prefix(8).uppercased()
    }

    private var vehicleDisplayId: String {
        "VEH-" + order.vehicleId.uuidString.prefix(8).uppercased()
    }

    private var serviceBayDisplay: String {
        "Bay \(abs(order.id.hashValue % 6) + 1)"
    }

    private var estimatedCostDisplay: String {
        guard let cost = order.estimatedCost else { return "₹0.00" }
        return "₹" + String(format: "%.2f", cost)
    }

    private var partsCostDisplay: String {
        guard let cost = order.estimatedCost else { return "₹0.00" }
        return "₹" + String(format: "%.2f", cost * 0.4)
    }

    private var laborCostDisplay: String {
        guard let cost = order.estimatedCost else { return "₹0.00" }
        return "₹" + String(format: "%.2f", cost * 0.6)
    }

    private var simulatedParts: [String] {
        let all = [
            ["Brake pads (front)", "Rotor disc (x2)", "Brake caliper"],
            ["Engine oil filter", "Synthetic oil 5W-30 (4L)", "Drain plug washer"],
            ["Air filter", "Spark plugs (x4)", "Ignition coil"],
            ["Coolant 5L", "Radiator cap", "Overflow tank hose"],
            ["Transmission fluid (2L)", "Gasket set", "Seal ring kit"],
            ["Battery (12V)", "Terminal connectors", "Battery tray"]
        ]
        return all[abs(order.id.hashValue) % all.count]
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // ── Hero status card ─────────────────────────────────────
                    DetailHeroCard(order: order)

                    // ── Work details ─────────────────────────────────────────
                    DetailSection(
                        title: "Work Order Details",
                        icon: "doc.text.fill",
                        accentColor: AppTheme.Brand.primary
                    ) {
                        VStack(spacing: 0) {
                            DetailInfoRow(label: "Work Order Title", value: order.title, icon: "wrench.fill", color: AppTheme.Brand.primary)
                            Divider().padding(.leading, 52)
                            DetailInfoRow(label: "Description", value: order.workDescription.isEmpty ? "No description provided." : order.workDescription, icon: "text.alignleft", color: AppTheme.Brand.violet)
                            Divider().padding(.leading, 52)
                            DetailInfoRow(label: "Priority", value: order.priority.rawValue.capitalized, icon: "flag.fill", color: order.priority.detailColor)
                            Divider().padding(.leading, 52)
                            let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
                            let statusLabel = isPending ? "Approval Pending" : order.status.displayLabel
                            DetailInfoRow(label: "Status", value: statusLabel, icon: "circle.fill", color: statusColor)
                        }
                    }

                    // ── Schedule ─────────────────────────────────────────────
                    DetailSection(title: "Schedule", icon: "calendar", accentColor: AppTheme.Brand.teal) {
                        VStack(spacing: 0) {
                            DetailInfoRow(
                                label: "Created",
                                value: order.createdAt.formatted(date: .complete, time: .shortened),
                                icon: "calendar.badge.plus",
                                color: AppTheme.Brand.teal
                            )
                            if let completed = order.completedAt {
                                Divider().padding(.leading, 52)
                                DetailInfoRow(
                                    label: "Completed",
                                    value: completed.formatted(date: .complete, time: .shortened),
                                    icon: "checkmark.circle.fill",
                                    color: AppTheme.Status.success
                                )
                            } else {
                                Divider().padding(.leading, 52)
                                DetailInfoRow(
                                    label: "Est. Completion",
                                    value: (Calendar.current.date(byAdding: .hour, value: 3, to: order.createdAt) ?? .now)
                                        .formatted(date: .omitted, time: .shortened),
                                    icon: "clock.badge.exclamationmark",
                                    color: AppTheme.Brand.amber
                                )
                            }
                        }
                    }

                    // ── Financials ───────────────────────────────────────────
                    if let cost = order.estimatedCost, cost > 0 {
                        DetailSection(title: "Financials", icon: "indianrupeesign.circle.fill", accentColor: AppTheme.Status.success) {
                            VStack(spacing: 0) {
                                DetailInfoRow(
                                    label: "Estimated Cost",
                                    value: estimatedCostDisplay,
                                    icon: "indianrupeesign.circle",
                                    color: AppTheme.Status.success
                                )
                                Divider().padding(.leading, 52)
                                DetailInfoRow(
                                    label: "Parts Cost",
                                    value: partsCostDisplay,
                                    icon: "cube.box.fill",
                                    color: AppTheme.Brand.primary
                                )
                                Divider().padding(.leading, 52)
                                DetailInfoRow(
                                    label: "Labor Cost",
                                    value: laborCostDisplay,
                                    icon: "person.fill",
                                    color: AppTheme.Brand.violet
                                )
                            }
                        }
                    }

                    // ── Parts list ───────────────────────────────────────────
                    DetailSection(
                        title: "Parts & Materials",
                        icon: "cube.box.fill",
                        accentColor: AppTheme.Brand.amber
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(simulatedParts.enumerated()), id: \.offset) { idx, part in
                                HStack(spacing: 12) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(AppTheme.Brand.amber.opacity(0.8))
                                        .clipShape(Circle())

                                    Text(part)
                                        .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                                        .foregroundColor(AppTheme.Text.primary)

                                    Spacer()

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                        .foregroundColor(AppTheme.Status.success)
                                }
                                .padding(.horizontal, 16)

                                if idx < simulatedParts.count - 1 {
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }

                    // ── Assignment ───────────────────────────────────────────
                    DetailSection(title: "Assignment", icon: "person.2.fill", accentColor: AppTheme.Brand.violet) {
                        VStack(spacing: 0) {
                            DetailInfoRow(
                                label: "Mechanic ID",
                                value: mechanicDisplayId,
                                icon: "person.badge.key.fill",
                                color: AppTheme.Brand.violet
                            )
                            Divider().padding(.leading, 52)
                            DetailInfoRow(
                                label: "Service Bay",
                                value: serviceBayDisplay,
                                icon: "mappin.circle.fill",
                                color: AppTheme.Status.success
                            )
                            Divider().padding(.leading, 52)
                            DetailInfoRow(
                                label: "Vehicle ID",
                                value: vehicleDisplayId,
                                icon: "car.fill",
                                color: AppTheme.Brand.primary
                            )
                        }
                    }

                    // ── Task Execution / Actions Section ─────────────────────
                    DetailSection(title: "Task Execution", icon: "play.circle.fill", accentColor: AppTheme.Brand.primaryDeep) {
                        VStack(alignment: .leading, spacing: 16) {
                            let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
                            if isPending {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(AppTheme.Brand.amber)
                                        .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Approval Pending")
                                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        Text("This work order requires approval from the Fleet Manager before work can start.")
                                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.Brand.amber.opacity(0.08))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.Brand.amber.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            } else if order.status == .open {
                                Button {
                                    startTask()
                                } label: {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Start Repair Task")
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppTheme.Brand.primary.gradient)
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            } else if order.status == .inProgress {
                                VStack(alignment: .leading, spacing: 14) {
                                    // Labor Cost Input
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Labor Cost (₹)")
                                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                            .foregroundColor(AppTheme.Text.secondary)
                                        
                                        TextField("e.g. 1500", text: $laborCostText)
                                            .keyboardType(.decimalPad)
                                            .padding(10)
                                            .background(Color.black.opacity(0.04))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.1), lineWidth: 1)
                                            )
                                    }
                                    
                                    // Parts Used Picker
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Parts Used")
                                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                            .foregroundColor(AppTheme.Text.secondary)
                                        
                                        if inventoryItems.isEmpty {
                                            Text("No inventory items found.")
                                                .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                                .italic()
                                                .foregroundColor(.gray)
                                        } else {
                                            VStack(alignment: .leading, spacing: 8) {
                                                ForEach(inventoryItems) { item in
                                                    let isSelected = selectedParts[item.id] != nil
                                                    let qty = selectedParts[item.id] ?? 0
                                                    
                                                    HStack {
                                                        Button {
                                                            if isSelected {
                                                                selectedParts.removeValue(forKey: item.id)
                                                            } else {
                                                                if item.quantityInStock > 0 {
                                                                    selectedParts[item.id] = 1
                                                                }
                                                            }
                                                        } label: {
                                                            HStack(spacing: 8) {
                                                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                                                    .foregroundColor(isSelected ? AppTheme.Brand.primary : .gray)
                                                                    .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                                                
                                                                VStack(alignment: .leading, spacing: 2) {
                                                                    Text(item.partName)
                                                                        .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                                                        .foregroundColor(.black)
                                                                    Text("In stock: \(item.quantityInStock) · Price: ₹\(Int(item.unitCost))")
                                                                        .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                                                        .foregroundColor(.gray)
                                                                }
                                                            }
                                                        }
                                                        .buttonStyle(PlainButtonStyle())
                                                        .disabled(item.quantityInStock <= 0 && !isSelected)
                                                        
                                                        Spacer()
                                                        
                                                        if isSelected {
                                                            HStack(spacing: 10) {
                                                                Button {
                                                                    if qty > 1 {
                                                                        selectedParts[item.id] = qty - 1
                                                                    }
                                                                } label: {
                                                                    Image(systemName: "minus.circle.fill")
                                                                        .foregroundColor(AppTheme.Brand.primary)
                                                                        .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                                                }
                                                                
                                                                Text("\(qty)")
                                                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                                                    .frame(width: 20)
                                                                    .multilineTextAlignment(.center)
                                                                
                                                                Button {
                                                                    if qty < item.quantityInStock {
                                                                        selectedParts[item.id] = qty + 1
                                                                    }
                                                                } label: {
                                                                    Image(systemName: "plus.circle.fill")
                                                                        .foregroundColor(AppTheme.Brand.primary)
                                                                        .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                                                }
                                                            }
                                                        } else if item.quantityInStock <= 0 {
                                                            Text("OUT OF STOCK")
                                                                .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                                                .foregroundColor(AppTheme.Status.danger)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(AppTheme.Status.danger.opacity(0.1))
                                                                .cornerRadius(4)
                                                        }
                                                    }
                                                    .padding(.vertical, 4)
                                                }
                                            }
                                            .padding(10)
                                            .background(Color.black.opacity(0.02))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.06), lineWidth: 1)
                                            )
                                        }
                                    }
                                    
                                    Text("Repair Notes / Evidence")
                                        .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                        .foregroundColor(AppTheme.Text.secondary)
                                    
                                    TextEditor(text: $repairNotes)
                                        .frame(minHeight: 80)
                                        .padding(8)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.1), lineWidth: 1)
                                        )
                                    
                                    // PhotosPicker
                                    PhotosPicker(
                                        selection: $selectedPhotoItems,
                                        maxSelectionCount: 5,
                                        matching: .images,
                                        photoLibrary: .shared()
                                    ) {
                                        Label("Attach Repair Evidence Photos", systemImage: "photo.badge.plus")
                                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                            .foregroundColor(AppTheme.Brand.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .onChange(of: selectedPhotoItems) { _, newItems in
                                        Task {
                                            var loaded: [UIImage] = []
                                            for item in newItems {
                                                if let data = try? await item.loadTransferable(type: Data.self),
                                                   let img = UIImage(data: data) {
                                                    loaded.append(img)
                                                }
                                            }
                                            repairPhotos = loaded
                                        }
                                    }
                                    
                                    if !repairPhotos.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(repairPhotos.indices, id: \.self) { idx in
                                                    Image(uiImage: repairPhotos[idx])
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 60, height: 60)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                }
                                            }
                                        }
                                    }
                                    
                                    if let error = uploadError {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(AppTheme.Status.danger)
                                    }
                                    
                                    let isCostValid = Double(laborCostText) != nil
                                    let canComplete = !repairNotes.isEmpty && !laborCostText.isEmpty && isCostValid && !isSubmitting
                                    
                                    Button {
                                        completeTask()
                                    } label: {
                                        HStack {
                                            if isSubmitting {
                                                ProgressView().tint(.white)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                Text("Complete Repair Task")
                                                    .fontWeight(.bold)
                                            }
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(canComplete ? AppTheme.Status.success : AppTheme.Status.success.opacity(0.3))
                                        .cornerRadius(10)
                                    }
                                    .disabled(!canComplete)
                                }
                                .padding()
                            } else if order.status == .completed {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(AppTheme.Status.success)
                                        .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Task Completed & Logged")
                                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        Text("Synced successfully back to Fleet Manager.")
                                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                            .foregroundColor(AppTheme.Text.secondary)
                                    }
                                }
                                .padding()
                            }
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(order.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Repair Logged", isPresented: $showSuccessAlert) {
            Button("OK") {}
        } message: {
            Text("Work order successfully completed and synchronized.")
        }
    }

    private func startTask() {
        order.status = .inProgress
        try? modelContext.save()
        
        let dbOrder = order.asDBWorkOrder
        Task {
            try? await SupabaseManager.shared.updateWorkOrder(dbOrder)
        }
    }
    
    private func completeTask() {
        isSubmitting = true
        uploadError = nil
        
        let mechanicId = SupabaseManager.shared.currentUser?.id ?? order.assignedTo
        
        Task {
            var imageUrls: [String] = []
            
            for (idx, photo) in repairPhotos.enumerated() {
                if let data = photo.jpegData(compressionQuality: 0.8) {
                    do {
                        let url = try await SupabaseManager.shared.uploadRepairImage(recordId: order.id, imageData: data, index: idx)
                        imageUrls.append(url)
                    } catch {
                        print("Failed to upload image: \(error.localizedDescription)")
                    }
                }
            }
            
            let laborCost = Double(laborCostText) ?? 0.0
            var partsCost = 0.0
            var partsSummary: [String] = []
            
            for (partId, qty) in selectedParts {
                if let part = inventoryItems.first(where: { $0.id == partId }) {
                    partsCost += part.unitCost * Double(qty)
                    partsSummary.append("\(part.partName) (x\(qty))")
                    
                    // Deduct stock levels locally & on Supabase
                    part.quantityInStock -= qty
                    let dbItem = part.asDBItem
                    do {
                        try await SupabaseManager.shared.updateInventoryItem(dbItem)
                    } catch {
                        print("Failed to update inventory item on Supabase: \(error.localizedDescription)")
                    }
                }
            }
            
            let totalCost = laborCost + partsCost
            let partsString = partsSummary.isEmpty ? "None" : partsSummary.joined(separator: ", ")
            let finalNotes = "Labor Cost: ₹\(String(format: "%.2f", laborCost)). Parts Used: \(partsString). Notes: \(repairNotes)"
            
            let record = DBMaintenanceRecord(
                id: UUID(),
                vehicleId: order.vehicleId,
                workOrderId: order.id,
                serviceType: order.title,
                serviceDate: Date(),
                cost: totalCost,
                notes: finalNotes,
                repairImages: imageUrls.isEmpty ? nil : imageUrls,
                performedBy: mechanicId,
                createdAt: Date()
            )
            
            do {
                try await SupabaseManager.shared.createMaintenanceRecord(record)
                
                if var dbVehicle = try? await SupabaseManager.shared.fetchVehicles().first(where: { $0.id == order.vehicleId }) {
                    dbVehicle.status = .available
                    try? await SupabaseManager.shared.updateVehicle(dbVehicle)
                }
                
                await MainActor.run {
                    order.status = .completed
                    order.completedAt = Date()
                    
                    // Set local vehicle status to active
                    if let localVehicle = (try? modelContext.fetch(FetchDescriptor<Vehicle>()))?.first(where: { $0.id == order.vehicleId }) {
                        localVehicle.status = .active
                        localVehicle.updatedAt = Date()
                    }
                    
                    try? modelContext.save()
                    
                    let dbOrder = order.asDBWorkOrder
                    Task {
                        try? await SupabaseManager.shared.updateWorkOrder(dbOrder)
                    }
                    
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    uploadError = "Failed to complete task on server: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Hero Card
// ─────────────────────────────────────────────────────────────────────────────

private struct DetailHeroCard: View {
    let order: WorkOrder

    var gradientColors: [Color] {
        let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
        if isPending {
            return [AppTheme.Brand.amber.opacity(0.08), Color.clear]
        }
        switch order.status {
        case .completed: return [AppTheme.Status.success.opacity(0.08), Color.clear]
        case .inProgress: return [AppTheme.Brand.primary.opacity(0.08), Color.clear]
        case .open: return [AppTheme.Brand.amber.opacity(0.08), Color.clear]
        case .cancelled: return [AppTheme.Brand.primary.opacity(0.08), Color.clear]
        }
    }

    var body: some View {
        let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
        let label = isPending ? "Approval Pending" : order.status.displayLabel
        let color = isPending ? AppTheme.Brand.amber : order.status.color
        let icon = isPending ? "clock.fill" : order.status.detailIcon
        
        VStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: icon)
                    .font(.system(size: 28 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(spacing: 6) {
                Text(order.title)
                    .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                    .multilineTextAlignment(.center)

                TaskStatusBadge(
                    label: label,
                    color: color,
                    icon: icon
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            ZStack {
                AppTheme.Background.card
                LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom)
            }
        )
        .cornerRadius(AppTheme.Radius.large)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Detail Section Wrapper
// ─────────────────────────────────────────────────────────────────────────────

private struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    var onSpeak: (() -> Void)? = nil
    let content: () -> Content

    init(title: String, icon: String, accentColor: Color, onSpeak: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.onSpeak = onSpeak
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                
                if let onSpeak = onSpeak {
                    Spacer()
                    Button(action: onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(accentColor)
                            .padding(6)
                            .background(accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
            .padding(.horizontal)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Detail Info Row
// ─────────────────────────────────────────────────────────────────────────────

private struct DetailInfoRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.10))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)
                Text(value)
                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - WorkOrderStatus Extension (detail icons)
// ─────────────────────────────────────────────────────────────────────────────

extension WorkOrderStatus {
    var detailIcon: String {
        switch self {
        case .open:       return "doc.text.fill"
        case .inProgress: return "wrench.and.screwdriver.fill"
        case .completed:  return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }
}
