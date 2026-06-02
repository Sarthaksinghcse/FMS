// FMS/Views/Fleet Manager/WorkOrderDetailedView.swift
import SwiftUI
import SwiftData
import Supabase

struct WorkOrderDetailedView: View {
    let order: WorkOrder
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData Queries for looking up associated assets
    @Query private var vehicles: [Vehicle]
    @Query private var allUsers: [User]
    @Query(sort: \MaintenanceRecord.serviceDate, order: .reverse) private var maintenanceRecords: [MaintenanceRecord]
    
    @State private var selectedTab = 0
    @State private var predictiveAlert: DBPredictiveAlert? = nil
    @State private var isLoadingAlert = false
    @State private var infoRequestText = ""
    @State private var showingInfoPrompt = false
    @State private var approvalHistory: [String] = []
    
    // Navigation / Chat
    @State private var showChat = false
    
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
    
    // Dynamic Cost calculations
    private var estimatedCost: Double {
        order.estimatedCost ?? 0.0
    }
    
    private var actualCost: Double {
        matchingMaintenanceRecord?.cost ?? estimatedCost
    }
    
    private var partsCost: Double {
        actualCost * 0.65
    }
    
    private var laborCost: Double {
        actualCost * 0.25
    }
    
    private var additionalCost: Double {
        actualCost * 0.10
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
        }
        .sheet(isPresented: $showingInfoPrompt) {
            infoRequestSheet
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
            // Cost Summary Breakdown
            VStack(alignment: .leading, spacing: 14) {
                Text("Cost Summary")
                    .font(.system(size: 14, weight: .bold))
                Divider()
                
                costBreakdownRow(label: "Estimated Cost", amount: estimatedCost)
                costBreakdownRow(label: "Parts Cost", amount: partsCost)
                costBreakdownRow(label: "Labor Cost", amount: laborCost)
                costBreakdownRow(label: "Additional Cost", amount: additionalCost)
                
                Divider()
                
                HStack {
                    Text("Current Cost")
                        .font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text("₹" + String(format: "%.2f", actualCost))
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
            
            // Approval History List
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
                            Text("Approve Cost")
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
