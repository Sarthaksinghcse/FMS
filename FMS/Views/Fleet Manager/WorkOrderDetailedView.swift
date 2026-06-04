// FMS/Views/Fleet Manager/WorkOrderDetailedView.swift
import SwiftUI
import SwiftData
import Supabase

// MARK: - AI Cost Estimation Response Model
struct WorkOrderCostEstimate: Codable {
    let suggestedParts: [SuggestedPart]
    let laborHours: Double
    let laborReason: String
    let laborRatePerHour: Double
    let laborCost: Double
    let additionalCosts: Double
    let additionalReason: String
    let partsCost: Double
    let totalEstimate: Double
    
    struct SuggestedPart: Codable, Identifiable {
        let inventoryId: UUID
        let partName: String
        let partNumber: String
        let unitCost: Double
        let inStock: Int
        var quantity: Int
        let reason: String
        
        var id: UUID { inventoryId }
        var totalCost: Double { unitCost * Double(quantity) }
        
        // Flexible decoder: handles both String and UUID for inventoryId
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            partName = try c.decode(String.self, forKey: .partName)
            partNumber = try c.decode(String.self, forKey: .partNumber)
            unitCost = try c.decode(Double.self, forKey: .unitCost)
            inStock = try c.decode(Int.self, forKey: .inStock)
            quantity = try c.decode(Int.self, forKey: .quantity)
            reason = (try? c.decode(String.self, forKey: .reason)) ?? ""
            
            if let uuid = try? c.decode(UUID.self, forKey: .inventoryId) {
                inventoryId = uuid
            } else if let str = try? c.decode(String.self, forKey: .inventoryId),
                      let uuid = UUID(uuidString: str) {
                inventoryId = uuid
            } else {
                inventoryId = UUID()
            }
        }
    }
}

private struct CostEstimateRequest: Codable {
    let issueDescription: String
    let vehicleId: String
    let vehicleInfo: String
}

struct WorkOrderDetailedView: View {
    let order: WorkOrder
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData Queries for looking up associated assets
    @Query private var vehicles: [Vehicle]
    @Query private var allUsers: [User]
    @Query(sort: \MaintenanceRecord.serviceDate, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    @Query private var inventoryItems: [InventoryItem]
    
    @State private var selectedTab = 0
    @State private var predictiveAlert: DBPredictiveAlert? = nil
    @State private var isLoadingAlert = false
    @State private var infoRequestText = ""
    @State private var showingInfoPrompt = false
    @State private var approvalHistory: [String] = []
    
    // Navigation / Chat
    @State private var showChat = false
    
    // Cost Estimation State
    @State private var costEstimate: WorkOrderCostEstimate?
    @State private var selectedPartQuantities: [UUID: Int] = [:] // inventoryId -> quantity
    @State private var isLoadingCostEstimate = false
    @State private var costEstimateError: String?
    
    // MARK: - Derived Properties (Real Data Only)
    
    private var associatedVehicle: Vehicle? {
        vehicles.first { $0.id == order.vehicleId }
    }
    
    private var assignedTechnician: User? {
        allUsers.first { $0.id == order.assignedTo }
    }
    
    private var matchingMaintenanceRecord: MaintenanceRecord? {
        maintenanceRecords.first { $0.workOrderId == order.id }
    }
    
    // Downtime calculated dynamically from real timestamps
    private var downtimeString: String {
        let endDate = order.completedAt ?? Date()
        let interval = endDate.timeIntervalSince(order.createdAt)
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days == 0 {
            return "\(hours) Hours"
        } else {
            return "\(days) Day \(hours) Hours"
        }
    }
    
    // Rich status derived from database status and pending tags
    private var currentStatusText: String {
        if order.workDescription.contains("[PENDING_APPROVAL]") {
            return "Awaiting Approval"
        } else if order.workDescription.contains("[REJECTED]") {
            return "Rejected"
        } else if order.workDescription.contains("[INFO_REQUESTED]") {
            return "Info Requested"
        }
        
        switch order.status {
        case .open: return "Assigned"
        case .inProgress: return "Repair In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    // Numeric index mapping for the progress bar
    private var currentStepIndex: Int {
        if order.status == .completed { return 6 }
        if order.workDescription.contains("[PENDING_APPROVAL]") { return 3 } // Awaiting Approval
        
        switch order.status {
        case .open:
            return 0 // Assigned
        case .inProgress:
            // Map middle states based on work description keywords
            let desc = order.workDescription.lowercased()
            if desc.contains("inspection") { return 1 }
            if desc.contains("diagnos") { return 2 }
            if desc.contains("parts") { return 4 }
            if desc.contains("quality") || desc.contains("check") { return 5 }
            return 4 // Default Repair phase
        default:
            return 0
        }
    }
    
    // Dynamic Cost calculations — from AI estimate + selected parts
    private var computedPartsCost: Double {
        guard let est = costEstimate else { return 0 }
        return est.suggestedParts.reduce(0) { sum, part in
            let qty = selectedPartQuantities[part.inventoryId] ?? part.quantity
            return sum + part.unitCost * Double(qty)
        }
    }
    
    private var computedLaborCost: Double {
        costEstimate?.laborCost ?? 0
    }
    
    private var computedAdditionalCost: Double {
        costEstimate?.additionalCosts ?? 0
    }
    
    private var computedTotalCost: Double {
        computedPartsCost + computedLaborCost + computedAdditionalCost
    }
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header Block
                headerSection
                
                // MARK: - Progress Tracker
                progressTrackerView
                    .padding(.top, 14)
                
                // MARK: - Custom Tab Bar
                tabBarSection
                    .padding(.top, 16)
                
                // MARK: - Tab Content Area
                ScrollView {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case 0:
                            overviewTabContent
                        case 1:
                            detailsTabContent
                        case 2:
                            costsTabContent
                        case 3:
                            timelineTabContent
                        default:
                            chatTabContent
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Work Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchGeminiPredictiveAlert()
            buildApprovalHistory()
            await loadAICostEstimate()
        }
        .sheet(isPresented: $showingInfoPrompt) {
            infoRequestSheet
                .interactiveDismissDisabled()
        }
    }
    
    // MARK: - Header View Component
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                // Priority Badge + WO ID
                HStack(spacing: 8) {
                    Text(order.priority.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            order.priority == .urgent || order.priority == .high
                            ? AppTheme.Status.danger
                            : AppTheme.Brand.royalBlue
                        )
                        .cornerRadius(6)
                    
                    Text("WO-\(order.id.uuidString.prefix(4).uppercased())")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                }
                
                // Vehicle details
                if let vehicle = associatedVehicle {
                    Text(vehicle.registrationNumber)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                } else {
                    Text("Unknown Vehicle")
                        .font(.system(size: 20, weight: .bold))
                }
                
                // Status description
                HStack(spacing: 6) {
                    Text("Status:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text(currentStatusText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(statusColor(for: currentStatusText))
                }
                .padding(.top, 4)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                // Vehicle image placeholder or stylized box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Brand.royalBlue.opacity(0.08))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "box.truck.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
                
                // Out of Service / Downtime tracker
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Out of Service")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Status.danger)
                    Text(downtimeString)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Progress Tracker View Component
    private var progressTrackerView: some View {
        let steps = ["Assigned", "Inspection", "Diagnosis", "Approval", "Repair", "QC", "Completed"]
        
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    // Connector line before circle (except first step)
                    if index > 0 {
                        Rectangle()
                            .fill(index <= currentStepIndex ? AppTheme.Brand.royalBlue : Color.gray.opacity(0.2))
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Step Circle
                    ZStack {
                        Circle()
                            .fill(index <= currentStepIndex ? AppTheme.Brand.royalBlue : Color.gray.opacity(0.1))
                            .frame(width: 22, height: 22)
                        
                        if index < currentStepIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else if index == currentStepIndex {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            
            // Labels
            HStack {
                ForEach(0..<steps.count, id: \.self) { index in
                    Text(steps[index])
                        .font(.system(size: 8, weight: index == currentStepIndex ? .bold : .medium))
                        .foregroundColor(index == currentStepIndex ? AppTheme.Brand.royalBlue : AppTheme.Text.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(AppTheme.Background.card)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Custom Tab Bar Component
    private var tabBarSection: some View {
        let tabs = ["Overview", "Details", "Costs", "Timeline"]
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { idx in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = idx
                        }
                    } label: {
                        Text(tabs[idx])
                            .font(.system(size: 13, weight: selectedTab == idx ? .bold : .semibold, design: .rounded))
                            .foregroundColor(selectedTab == idx ? .white : AppTheme.Text.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == idx
                                ? AnyView(Capsule().fill(AppTheme.Brand.royalBlue))
                                : AnyView(Capsule().stroke(AppTheme.Glass.border, lineWidth: 1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Tab: Overview Tab Content
    private var overviewTabContent: some View {
        VStack(spacing: 16) {
            // Circular Failure Risk Gauge Powered by Gemini
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppTheme.Brand.royalBlue)
                    Text("AI Risk Analysis")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    Spacer()
                    
                    if isLoadingAlert {
                        ProgressView().tint(AppTheme.Brand.royalBlue)
                    }
                }
                
                Divider()
                
                HStack(spacing: 20) {
                    // Risk percentage gauge
                    let riskPercent = Int((predictiveAlert?.riskScore ?? 0.0) * 100)
                    let riskLevel = predictiveAlert?.riskLevel ?? "Low"
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(Double(riskPercent) / 100.0))
                            .stroke(
                                riskLevel.localizedCaseInsensitiveCompare("critical") == .orderedSame ||
                                riskLevel.localizedCaseInsensitiveCompare("high") == .orderedSame
                                ? AppTheme.Status.danger
                                : AppTheme.Brand.royalBlue,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(Angle(degrees: -90))
                        
                        Text("\(riskPercent)%")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Failure Risk")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.Text.secondary)
                        Text(riskLevel.uppercased())
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(
                                riskLevel.localizedCaseInsensitiveCompare("critical") == .orderedSame ||
                                riskLevel.localizedCaseInsensitiveCompare("high") == .orderedSame
                                ? AppTheme.Status.danger
                                : AppTheme.Brand.royalBlue
                            )
                        
                        Text("Recommendation")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(predictiveAlert?.suggestedAction ?? "Monitor vehicle performance.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Text.primary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(16)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4)
            
            // Work Order Basic Info
            VStack(alignment: .leading, spacing: 12) {
                Text("Work Order Info")
                    .font(.system(size: 14, weight: .bold))
                
                Divider()
                
                infoRow(label: "Reported On", value: order.createdAt.formatted(date: .abbreviated, time: .shortened))
                infoRow(label: "Issue Title", value: order.title)
                infoRow(label: "Category", value: "Fleet Maintenance")
                infoRow(label: "Priority", value: order.priority.rawValue.capitalized)
            }
            .padding(16)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4)
            
            // Technician Card
            if let tech = assignedTechnician {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Assigned Technician")
                        .font(.system(size: 14, weight: .bold))
                    
                    Divider()
                    
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Text(String(tech.fullName.prefix(2).uppercased()))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Brand.royalBlue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: 44, height: 44, alignment: .center)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tech.fullName)
                                .font(.system(size: 14, weight: .bold))
                            Text("Senior Maintenance Technician")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Text.secondary)
                        }
                        
                        Spacer()
                        
                        // Inline Call Button
                        Button {
                            if let phoneURL = URL(string: "tel://\(tech.phoneNumber)") {
                                UIApplication.shared.open(phoneURL)
                            }
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.Brand.royalBlue)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
            }
            
            // Service Bay Detail
            VStack(alignment: .leading, spacing: 10) {
                Label("Workshop Bay Assignment", systemImage: "house.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                
                let bayNum = abs(order.id.hashValue % 4) + 1
                Text("Workshop Section A • Service Bay \(bayNum)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4)
        }
    }
    
    // MARK: - Tab: Details Tab Content
    private var detailsTabContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reported Issue & Diagnostics")
                    .font(.system(size: 14, weight: .bold))
                Divider()
                
                Text("Reported Issue:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Text.secondary)
                Text(order.workDescription)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text("Technician Diagnosis:")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Text.secondary)
                    .padding(.top, 6)
                
                if let record = matchingMaintenanceRecord, let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Text.primary)
                } else {
                    Text("Technician is currently performing inspection and diagnosis. Notes will be displayed once submitted.")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Text.tertiary)
                        .italic()
                }
            }
            .padding(16)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4)
            
            // Uploaded Evidence Images
            if let record = matchingMaintenanceRecord, let images = record.repairImages, !images.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repair Evidence Photos")
                        .font(.system(size: 14, weight: .bold))
                    Divider()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(images, id: \.self) { imgUrl in
                                if let url = URL(string: imgUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .cornerRadius(8)
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: 100, height: 100)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
            }
        }
    }
    
    // MARK: - Tab: Costs & Approval Tab Content
    private var costsTabContent: some View {
        VStack(spacing: 16) {
            if isLoadingCostEstimate {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(AppTheme.Brand.royalBlue)
                    Text("AI is estimating repair costs...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
            } else if let errorMsg = costEstimateError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.Status.danger)
                        .font(.system(size: 32))
                    Text(errorMsg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task {
                            await loadAICostEstimate()
                        }
                    } label: {
                        Text("Retry Estimation")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.Brand.royalBlue)
                            .cornerRadius(8)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
            } else if let estimate = costEstimate {
                // 1. Suggested Parts Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(AppTheme.Brand.royalBlue)
                        Text("Required Spare Parts (AI Matches)")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    Divider()
                    
                    if estimate.suggestedParts.isEmpty {
                        Text("No spare parts are required for this repair.")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Text.tertiary)
                            .italic()
                            .padding(.vertical, 8)
                    } else {
                        ForEach(estimate.suggestedParts) { part in
                            let isSelected = selectedPartQuantities[part.inventoryId] != nil
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    Button {
                                        if isSelected {
                                            selectedPartQuantities.removeValue(forKey: part.inventoryId)
                                        } else {
                                            selectedPartQuantities[part.inventoryId] = part.quantity
                                        }
                                    } label: {
                                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                            .foregroundColor(isSelected ? AppTheme.Brand.royalBlue : .gray)
                                            .font(.system(size: 18))
                                    }
                                    .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(part.partName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(AppTheme.Text.primary)
                                        Text("Part #: \(part.partNumber) • In Stock: \(part.inStock)")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.Text.tertiary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("₹" + String(format: "%.2f", part.unitCost))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Text.primary)
                                }
                                
                                if isSelected {
                                    HStack {
                                        Text("Reason: \(part.reason)")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .lineLimit(2)
                                        
                                        Spacer()
                                        
                                        // Quantity selector
                                        HStack(spacing: 8) {
                                            Button {
                                                let current = selectedPartQuantities[part.inventoryId] ?? part.quantity
                                                if current > 1 {
                                                    selectedPartQuantities[part.inventoryId] = current - 1
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundColor(AppTheme.Brand.royalBlue)
                                            }
                                            
                                            Text("\(selectedPartQuantities[part.inventoryId] ?? part.quantity)")
                                                .font(.system(size: 12, weight: .bold))
                                                .frame(width: 20)
                                                .multilineTextAlignment(.center)
                                            
                                            Button {
                                                let current = selectedPartQuantities[part.inventoryId] ?? part.quantity
                                                if current < part.inStock {
                                                    selectedPartQuantities[part.inventoryId] = current + 1
                                                }
                                            } label: {
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(AppTheme.Brand.royalBlue)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    .padding(.leading, 26)
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
                
                // 2. Labor & Additional Cost Cards
                VStack(alignment: .leading, spacing: 14) {
                    Text("Labor & Miscellaneous Estimate")
                        .font(.system(size: 14, weight: .bold))
                    Divider()
                    
                    // Labor row
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Estimated Labor")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                            Spacer()
                            Text(String(format: "%.1f Hrs @ ₹%.0f/Hr", estimate.laborHours, estimate.laborRatePerHour))
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Text.secondary)
                            Text("₹" + String(format: "%.2f", estimate.laborCost))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                        }
                        if !estimate.laborReason.isEmpty {
                            Text(estimate.laborReason)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Text.tertiary)
                        }
                    }
                    
                    Divider()
                    
                    // Additional costs row
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Additional Costs (Supplies, Disposal)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Text.primary)
                            Spacer()
                            Text("₹" + String(format: "%.2f", estimate.additionalCosts))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                        }
                        if !estimate.additionalReason.isEmpty {
                            Text(estimate.additionalReason)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Text.tertiary)
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
                
                // 3. Overall Cost Summary Breakdown
                VStack(alignment: .leading, spacing: 14) {
                    Text("Total Summary")
                        .font(.system(size: 14, weight: .bold))
                    Divider()
                    
                    costBreakdownRow(label: "Parts Subtotal", amount: computedPartsCost)
                    costBreakdownRow(label: "Labor Subtotal", amount: computedLaborCost)
                    costBreakdownRow(label: "Additional Subtotal", amount: computedAdditionalCost)
                    
                    Divider()
                    
                    HStack {
                        Text("Total Estimated Cost")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("₹" + String(format: "%.2f", computedTotalCost))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                    
                    HStack {
                        Text("Approval Status")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.Text.secondary)
                        Spacer()
                        
                        Text(currentStatusText.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(for: currentStatusText))
                            .cornerRadius(6)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
                
                // 4. Approval History List
                VStack(alignment: .leading, spacing: 14) {
                    Text("Approval History")
                        .font(.system(size: 14, weight: .bold))
                    Divider()
                    
                    ForEach(approvalHistory, id: \.self) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(AppTheme.Brand.royalBlue)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            
                            Text(entry)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Text.primary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
                
                // Fleet Manager Action Buttons
                if order.workDescription.contains("[PENDING_APPROVAL]") || order.workDescription.contains("[INFO_REQUESTED]") {
                    VStack(spacing: 12) {
                        Button {
                            approveCostEstimate()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Approve Cost & Deduct Inventory")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.Status.success)
                            .cornerRadius(10)
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                rejectCostEstimate()
                            } label: {
                                Text("Reject")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.Status.danger)
                                    .cornerRadius(8)
                            }
                            
                            Button {
                                showingInfoPrompt = true
                            } label: {
                                Text("Request More Details")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.Brand.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(AppTheme.Brand.primary, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                // Show approved summary/fallback
                VStack(alignment: .leading, spacing: 14) {
                    Text("Approved Cost Summary")
                        .font(.system(size: 14, weight: .bold))
                    Divider()
                    
                    let approvedTotal = order.estimatedCost ?? 0.0
                    costBreakdownRow(label: "Approved Parts Cost (Est)", amount: approvedTotal * 0.65)
                    costBreakdownRow(label: "Approved Labor Cost (Est)", amount: approvedTotal * 0.25)
                    costBreakdownRow(label: "Approved Additional Cost (Est)", amount: approvedTotal * 0.10)
                    
                    Divider()
                    
                    HStack {
                        Text("Total Approved Cost")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Text("₹" + String(format: "%.2f", approvedTotal))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Status.success)
                    }
                    
                    HStack {
                        Text("Approval Status")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.Text.secondary)
                        Spacer()
                        
                        Text(currentStatusText.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(for: currentStatusText))
                            .cornerRadius(6)
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4)
                
                if order.workDescription.contains("[PENDING_APPROVAL]") || order.workDescription.contains("[INFO_REQUESTED]") {
                    Button {
                        Task {
                            await loadAICostEstimate()
                        }
                    } label: {
                        Text("Generate Cost Estimate via Gemini")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.Brand.royalBlue)
                            .cornerRadius(8)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Tab: Timeline Content
    private var timelineTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Repair Process Timeline")
                .font(.system(size: 14, weight: .bold))
            Divider()
            
            VStack(alignment: .leading, spacing: 20) {
                timelineEventRow(
                    title: "Work Order Created",
                    time: order.createdAt.formatted(date: .abbreviated, time: .shortened),
                    desc: "System logged work order following diagnostic risk detection.",
                    isCompleted: true
                )
                
                let isAssigned = currentStepIndex >= 0
                timelineEventRow(
                    title: "Technician Assigned",
                    time: order.createdAt.addingTimeInterval(300).formatted(date: .omitted, time: .shortened),
                    desc: "Assigned technician: \(assignedTechnician?.fullName ?? "Maintenance Tech")",
                    isCompleted: isAssigned
                )
                
                let isInspected = currentStepIndex >= 1
                timelineEventRow(
                    title: "Initial Inspection Completed",
                    time: order.createdAt.addingTimeInterval(1800).formatted(date: .omitted, time: .shortened),
                    desc: "Technician finished physical safety inspection checks.",
                    isCompleted: isInspected
                )
                
                let isCompleted = order.status == .completed
                timelineEventRow(
                    title: "Maintenance Completed",
                    time: order.completedAt?.formatted(date: .omitted, time: .shortened) ?? "--:--",
                    desc: "Repairs finalized, parts logged, and vehicle returned to service.",
                    isCompleted: isCompleted
                )
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4)
    }
    
    // MARK: - Tab: Embedded Chat Content
    private var chatTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Chat with Technician")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text("ONLINE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppTheme.Status.success)
            }
            Divider()
            
            VStack(spacing: 12) {
                chatBubble(sender: assignedTechnician?.fullName ?? "Technician", message: "Hi Manager, I completed the diagnostics. The brake rotor has severe wear. Need approval for the estimated ₹18,000 cost.", isMe: false)
                
                if order.workDescription.contains("[PENDING_APPROVAL]") {
                    chatBubble(sender: "System", message: "Estimate awaiting approval from Fleet Manager.", isMe: false, isSystem: true)
                } else if !order.workDescription.contains("[PENDING_APPROVAL]") && order.status != .open {
                    chatBubble(sender: "You", message: "Cost estimate approved. Please proceed with the brake component replacement.", isMe: true)
                }
            }
            .frame(minHeight: 180)
            
            HStack {
                TextField("Type message...", text: .constant(""))
                    .padding(10)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(8)
                
                Button {
                    // Send message
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(AppTheme.Brand.royalBlue)
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4)
    }
    
    // MARK: - Information Request Modal Sheet
    private var infoRequestSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Specify details needed from technician for order WO-\(order.id.uuidString.prefix(4).uppercased())")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Text.secondary)
                    .padding(.horizontal)
                
                TextEditor(text: $infoRequestText)
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Request Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingInfoPrompt = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        requestMoreDetails()
                        showingInfoPrompt = false
                    }
                    .font(.bold(.system(size: 14))())
                }
            }
        }
    }
    
    // MARK: - Helper UI Elements
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.Text.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Text.primary)
        }
        .padding(.vertical, 2)
    }
    
    private func costBreakdownRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.Text.secondary)
            Spacer()
            Text("₹" + String(format: "%.2f", amount))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)
        }
    }
    
    private func timelineEventRow(title: String, time: String, desc: String, isCompleted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Circle()
                    .fill(isCompleted ? AppTheme.Brand.royalBlue : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(isCompleted ? AppTheme.Brand.royalBlue : Color.gray.opacity(0.2))
                    .frame(width: 2, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isCompleted ? AppTheme.Text.primary : AppTheme.Text.secondary)
                    Spacer()
                    Text(time)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Text.secondary)
                }
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Text.secondary)
            }
        }
    }
    
    private func chatBubble(sender: String, message: String, isMe: Bool, isSystem: Bool = false) -> some View {
        HStack {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(sender)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary)
                
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isMe ? .white : AppTheme.Text.primary)
                    .padding(10)
                    .background(
                        isSystem
                        ? Color.orange.opacity(0.1)
                        : (isMe ? AppTheme.Brand.royalBlue : Color.black.opacity(0.05))
                    )
                    .cornerRadius(8)
            }
            
            if !isMe { Spacer() }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Completed": return AppTheme.Status.success
        case "Awaiting Approval": return AppTheme.Brand.amber
        case "Rejected": return AppTheme.Status.danger
        case "Info Requested": return AppTheme.Brand.primary
        default: return AppTheme.Brand.primary
        }
    }
    
    // MARK: - Core Operations (Real Database Sync)
    
    private func fetchGeminiPredictiveAlert() async {
        isLoadingAlert = true
        do {
            let alerts = try await SupabaseManager.shared.fetchPredictiveAlerts(onlyActive: true)
            await MainActor.run {
                self.predictiveAlert = alerts.first { $0.vehicleId == order.vehicleId }
                self.isLoadingAlert = false
            }
        } catch {
            print("Failed to load Gemini predictions: \(error)")
            self.isLoadingAlert = false
        }
    }
    
    private func buildApprovalHistory() {
        var history = [
            "Estimate submitted by Technician on " + order.createdAt.formatted(date: .abbreviated, time: .shortened)
        ]
        
        if order.workDescription.contains("[PENDING_APPROVAL]") {
            history.append("Awaiting approval from Fleet Manager")
        } else if order.workDescription.contains("[REJECTED]") {
            history.append("Rejected by Fleet Manager")
        } else if order.workDescription.contains("[INFO_REQUESTED]") {
            history.append("Information request submitted by Fleet Manager")
        } else {
            history.append("Approved by Fleet Manager")
        }
        self.approvalHistory = history
    }
    
    private func approveCostEstimate() {
        // Set estimated cost to the computed total
        order.estimatedCost = computedTotalCost
        
        // Deduct from inventory
        if let estimate = costEstimate {
            for part in estimate.suggestedParts {
                // Only deduct if the part is selected by fleet manager
                guard let qtyToDeduct = selectedPartQuantities[part.inventoryId] else { continue }
                
                // 1. Update local SwiftData
                if let localItem = inventoryItems.first(where: { $0.id == part.inventoryId }) {
                    localItem.quantityInStock = max(0, localItem.quantityInStock - qtyToDeduct)
                    localItem.updatedAt = Date()
                    
                    // 2. Sync to Supabase
                    let dbItem = localItem.asDBItem
                    Task {
                        do {
                            try await SupabaseManager.shared.updateInventoryItem(dbItem)
                            
                            // 3. Create low stock alert if it falls below threshold
                            if localItem.quantityInStock <= localItem.reorderThreshold {
                                let lowStockNotif = DBNotification(
                                    id: UUID(),
                                    userId: order.assignedTo,
                                    title: "⚠️ Low Stock Alert: \(localItem.partName)",
                                    message: "The stock level of \(localItem.partName) (\(localItem.partNumber)) has dropped to \(localItem.quantityInStock), which is below the reorder threshold of \(localItem.reorderThreshold).",
                                    type: .maintenance,
                                    isRead: false,
                                    createdAt: Date()
                                )
                                try? await SupabaseManager.shared.createNotification(lowStockNotif)
                            }
                        } catch {
                            print("Failed to update inventory or create notification in Supabase: \(error)")
                        }
                    }
                }
            }
        }
        
        // Remove PENDING_APPROVAL and pending info tags
        order.workDescription = order.workDescription
            .replacingOccurrences(of: "[PENDING_APPROVAL] ", with: "")
            .replacingOccurrences(of: "[PENDING_APPROVAL]", with: "")
            .replacingOccurrences(of: "[REJECTED] ", with: "")
            .replacingOccurrences(of: "[REJECTED]", with: "")
            .replacingOccurrences(of: "[INFO_REQUESTED] ", with: "")
            .replacingOccurrences(of: "[INFO_REQUESTED]", with: "")
        
        // Transition state to open (Scheduled)
        order.status = .open
        try? modelContext.save()
        
        // Sync to Supabase
        let dbWO = order.asDBWorkOrder
        Task {
            do {
                try await SupabaseManager.shared.updateWorkOrder(dbWO)
                
                // Add a notification for the technician
                let notif = DBNotification(
                    id: UUID(),
                    userId: order.assignedTo,
                    title: "✅ Work Order Approved",
                    message: "Fleet Manager has approved work order \"\(order.title)\". It is now scheduled for repairs.",
                    type: .maintenance,
                    isRead: false,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.createNotification(notif)
                buildApprovalHistory()
            } catch {
                print("Failed to sync cost approval to Supabase: \(error)")
            }
        }
    }
    
    private func loadAICostEstimate() async {
        guard !isLoadingCostEstimate else { return }
        // Only fetch if order is still pending approval and does not have an approved cost yet
        guard order.workDescription.contains("[PENDING_APPROVAL]") || order.workDescription.contains("[INFO_REQUESTED]") else {
            return
        }
        
        isLoadingCostEstimate = true
        costEstimateError = nil
        
        do {
            let vehicleInfo = associatedVehicle.map { "\($0.make) \($0.model) (\($0.year))" } ?? ""
            let payload = CostEstimateRequest(
                issueDescription: order.workDescription,
                vehicleId: order.vehicleId.uuidString,
                vehicleInfo: vehicleInfo
            )
            let options = FunctionInvokeOptions(method: .post, body: payload)
            
            let decoded: WorkOrderCostEstimate = try await SupabaseManager.shared.client.functions
                .invoke("estimate-work-order-cost", options: options) { data, _ in
                    let rawString = String(data: data, encoding: .utf8) ?? "(non-utf8)"
                    print("[CostAI] Raw response: \(rawString)")
                    return try JSONDecoder().decode(WorkOrderCostEstimate.self, from: data)
                }
            
            await MainActor.run {
                self.costEstimate = decoded
                // Pre-populate quantities to selectedPartQuantities
                self.selectedPartQuantities = [:]
                for part in decoded.suggestedParts {
                    self.selectedPartQuantities[part.inventoryId] = part.quantity
                }
                self.isLoadingCostEstimate = false
            }
        } catch {
            print("[CostAI] Error loading cost estimate: \(error)")
            await MainActor.run {
                self.costEstimateError = "Failed to load cost estimate: \(error.localizedDescription)"
                self.isLoadingCostEstimate = false
            }
        }
    }
    
    private func rejectCostEstimate() {
        // Transition state to cancelled
        order.status = .cancelled
        
        // Remove PENDING_APPROVAL and pending info tags
        order.workDescription = order.workDescription
            .replacingOccurrences(of: "[PENDING_APPROVAL] ", with: "")
            .replacingOccurrences(of: "[PENDING_APPROVAL]", with: "")
            .replacingOccurrences(of: "[INFO_REQUESTED] ", with: "")
            .replacingOccurrences(of: "[INFO_REQUESTED]", with: "")
        
        // Tag as rejected in description
        if !order.workDescription.contains("[REJECTED]") {
            order.workDescription = "[REJECTED] " + order.workDescription
        }
        
        // Set vehicle back to active
        if let vehicle = associatedVehicle {
            vehicle.status = .active
            vehicle.updatedAt = Date()
            
            // Sync vehicle status to Supabase
            let dbVehicle = DBVehicle(
                id: vehicle.id,
                vehicleNumber: vehicle.registrationNumber,
                model: vehicle.model,
                manufacturer: vehicle.make,
                year: vehicle.year,
                vin: vehicle.vinNumber,
                licensePlate: vehicle.registrationNumber,
                status: .available,
                assignedDriverId: vehicle.assignedDriverId,
                lastServiceDate: vehicle.lastServiceDate,
                createdAt: vehicle.createdAt
            )
            Task {
                try? await SupabaseManager.shared.updateVehicle(dbVehicle)
            }
        }
        
        try? modelContext.save()
        
        // Sync to Supabase
        let dbWO = order.asDBWorkOrder
        Task {
            do {
                try await SupabaseManager.shared.updateWorkOrder(dbWO)
                
                // Add a notification for the technician
                let notif = DBNotification(
                    id: UUID(),
                    userId: order.assignedTo,
                    title: "❌ Work Order Declined",
                    message: "Fleet Manager has declined work order \"\(order.title)\".",
                    type: .maintenance,
                    isRead: false,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.createNotification(notif)
                buildApprovalHistory()
            } catch {
                print("Failed to sync rejection to Supabase: \(error)")
            }
        }
    }
    
    private func requestMoreDetails() {
        // Tag as info requested
        if !order.workDescription.contains("[INFO_REQUESTED]") {
            order.workDescription = "[INFO_REQUESTED] " + order.workDescription
                .replacingOccurrences(of: "[PENDING_APPROVAL] ", with: "")
                .replacingOccurrences(of: "[PENDING_APPROVAL]", with: "")
        }
        
        // Append request description to notes or chat
        if !infoRequestText.isEmpty {
            order.workDescription += "\n[MANAGER_INFO_REQUEST: \(infoRequestText)]"
        }
        try? modelContext.save()
        
        // Sync to Supabase
        let dbWO = order.asDBWorkOrder
        Task {
            do {
                try await SupabaseManager.shared.updateWorkOrder(dbWO)
                
                // Send notification to technician
                let notif = DBNotification(
                    id: UUID(),
                    userId: order.assignedTo,
                    title: "❓ More Info Requested",
                    message: "Fleet Manager is asking for more details on estimate for \"\(order.title)\": \(infoRequestText)",
                    type: .maintenance,
                    isRead: false,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.createNotification(notif)
                buildApprovalHistory()
            } catch {
                print("Failed to sync request for details: \(error)")
            }
        }
    }
}
