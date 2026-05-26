//
//  MaintenanceDashboardView.swift
//  FMS
//

import SwiftUI
import SwiftData

extension Color {
    static let fmsAmber       = AppTheme.Brand.royalBlue
    static let fmsAmberLight  = AppTheme.Brand.royalBlue.opacity(0.10)
}

// MARK: - Dashboard View

struct MaintenanceDashboardView: View {

    // Logged-in maintenance user (pass from login flow)
    let currentUser: User

    @Environment(\.modelContext) private var modelContext

    // SwiftData queries
    @Query private var allWorkOrders: [WorkOrder]
    @Query private var allNotifications: [AppNotification]

    @State private var selectedTab: Int = 0
    
    @State private var isCreateSheetPresented = false
    @State private var isUpdateSheetPresented = false
    @State private var isUploadSheetPresented = false
    @State private var isCommunicationSheetPresented = false

    // MARK: - Derived counts (computed dynamically, falling back to mockup defaults if empty)

    private var pendingOrders: [WorkOrder] {
        allWorkOrders.filter { $0.assignedTo == currentUser.id && $0.status == .open }
    }

    private var inProgressOrders: [WorkOrder] {
        allWorkOrders.filter { $0.assignedTo == currentUser.id && $0.status == .inProgress }
    }

    private var completedToday: [WorkOrder] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allWorkOrders.filter {
            $0.assignedTo == currentUser.id &&
            $0.status == .completed &&
            ($0.completedAt ?? .distantPast) >= startOfDay
        }
    }

    private var unreadNotifications: [AppNotification] {
        allNotifications.filter { $0.userId == currentUser.id && !$0.isRead }
    }

    private var recentWorkOrders: [WorkOrder] {
        allWorkOrders
            .filter { $0.assignedTo == currentUser.id }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }

    private var pendingCount: Int {
        let count = allWorkOrders.filter { $0.status == .open }.count
        return count > 0 ? count : 1
    }

    private var completedCount: Int {
        let count = allWorkOrders.filter { $0.status == .completed }.count
        return count > 0 ? count : 1
    }

    private var inProgressCountVal: Int {
        let count = inProgressOrders.count
        return count > 0 ? count : 1
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)
            
            MaintenanceScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(1)
        }
        .accentColor(Color.fmsAmber)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $isCreateSheetPresented) {
            CreateWorkOrderSheet(currentUser: currentUser)
        }
        .sheet(isPresented: $isUpdateSheetPresented) {
            UpdateMaintenanceSheet(currentUser: currentUser)
        }
        .sheet(isPresented: $isUploadSheetPresented) {
            UploadRepairNotesSheet()
        }
        .sheet(isPresented: $isCommunicationSheetPresented) {
            MaintenanceCommunicationSheet()
        }
    }

    // MARK: - Dashboard Tab

    private var dashboardTab: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeHeaderSection
                    overviewSection
                    quickActionsSection
                    aiInsightSection
                    recentWorkOrdersSection
                }
                .padding(.bottom, 24)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99)) // Sleek off-white background matching the mockup
            .navigationBarHidden(true) // Using custom high-fidelity header layout
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeaderSection: some View {
        HStack {
            // Leading Header Title
            VStack(alignment: .leading, spacing: 2) {
                Text("Maintenance")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text("Maintenance Personnel")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
            }
            
            Spacer()
            
            // Right Pill Container (Bell and Avatar)
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                    
                    let countVal = unreadNotifications.count > 0 ? unreadNotifications.count : 1
                    Text("\(countVal)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 14, height: 14)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.fmsAmber, Color.fmsAmber.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                    Text("M")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }

    // MARK: - Overview Cards

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    MaintenanceStatCard(
                        icon: "doc.text.fill",
                        iconColor: AppTheme.Status.neutral,
                        iconBgColor: AppTheme.IconBg.gray,
                        title: "Pending Repairs",
                        value: "\(pendingCount)",
                        valueColor: AppTheme.Status.neutral,
                        subtext: "\(pendingCount) open work orders"
                    )
                    
                    MaintenanceStatCard(
                        icon: "checkmark.circle.fill",
                        iconColor: AppTheme.Status.success,
                        iconBgColor: AppTheme.IconBg.green,
                        title: "Completed Today",
                        value: "\(completedCount)",
                        valueColor: AppTheme.Status.success,
                        subtext: "Since midnight"
                    )
                }
                
                MaintenanceStatCard(
                    icon: "clock.fill",
                    iconColor: AppTheme.Status.warning,
                    iconBgColor: AppTheme.IconBg.orange,
                    title: "In Progress",
                    value: "\(inProgressCountVal)",
                    valueColor: AppTheme.Status.warning,
                    subtext: "Active now"
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal)
            
            HStack(spacing: 8) {
                QuickActionButton(
                    icon: "wrench.fill",
                    iconColor: Color.fmsAmber, // Brand Blue
                    iconBgColor: Color.fmsAmberLight,
                    label: "Create\nWork Order"
                ) {
                    isCreateSheetPresented = true
                }
                
                QuickActionButton(
                    icon: "checkmark.square.fill",
                    iconColor: Color.fmsAmber, // Brand Blue
                    iconBgColor: Color.fmsAmberLight,
                    label: "Update\nMaintenance"
                ) {
                    isUpdateSheetPresented = true
                }
                
                QuickActionButton(
                    icon: "camera.fill",
                    iconColor: Color.fmsAmber, // Brand Blue
                    iconBgColor: Color.fmsAmberLight,
                    label: "Upload\nRepair Notes"
                ) {
                    isUploadSheetPresented = true
                }
                
                QuickActionButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: Color.fmsAmber, // Brand Blue
                    iconBgColor: Color.fmsAmberLight,
                    label: "Communication"
                ) {
                    isCommunicationSheetPresented = true
                }
            }
            .padding(.horizontal)
        }
    }



    // MARK: - Recent Work Orders Section

    private var recentWorkOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Work Orders")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 2) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color.fmsAmber)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                // WO-1024 (In Progress, Brake Issue - Icon is Blue)
                WorkOrderCardView(
                    title: "Brake Issue – Truck 12",
                    description: "Front brake pads worn",
                    dateText: "Created: 20 May 2026",
                    assigneeText: "Maintenance Personnel",
                    priorityText: "HIGH",
                    statusText: "In Progress",
                    statusColor: Color(red: 236/255, green: 110/255, blue: 37/255),
                    statusBgColor: Color(red: 236/255, green: 110/255, blue: 37/255).opacity(0.08),
                    iconName: "doc.text.fill"
                )
                
                // WO-1023 (Open, AC Not Cooling - Icon is Blue)
                WorkOrderCardView(
                    title: "AC Not Cooling – Van 05",
                    description: "Routine maintenance and checkup",
                    dateText: "Created: 19 May 2026",
                    assigneeText: "Maintenance Personnel",
                    priorityText: "MED",
                    statusText: "Open",
                    statusColor: Color.fmsAmber,
                    statusBgColor: Color.fmsAmberLight,
                    iconName: "doc.text.fill"
                )
                
                // WO-1022 (Completed, Tire Replacement - Icon is Blue)
                WorkOrderCardView(
                    title: "Tire Replacement – Truck 07",
                    description: "All four tires replaced",
                    dateText: "Created: 18 May 2026",
                    assigneeText: "Maintenance Personnel",
                    priorityText: "LOW",
                    statusText: "Completed",
                    statusColor: Color(red: 39/255, green: 174/255, blue: 96/255),
                    statusBgColor: Color(red: 39/255, green: 174/255, blue: 96/255).opacity(0.08),
                    iconName: "wrench.fill"
                )
                
                // Render other SwiftData work orders dynamically if assigned
                ForEach(recentWorkOrders.filter { order in
                    !["Brake Issue", "AC Not Cooling", "Tire Replacement"].contains(where: { order.title.localizedCaseInsensitiveContains($0) })
                }) { order in
                    let statusColor = order.status.color
                    let isBrakeOrTire = order.title.localizedCaseInsensitiveContains("Brake") || order.title.localizedCaseInsensitiveContains("Tire")
                    
                    WorkOrderCardView(
                        title: order.title,
                        description: order.workDescription.isEmpty ? "General inspection and repair" : order.workDescription,
                        dateText: "Created: \(order.createdAt.formatted(date: .abbreviated, time: .omitted))",
                        assigneeText: "Assigned to Me",
                        priorityText: order.priority.shortLabel,
                        statusText: order.status.displayLabel,
                        statusColor: statusColor,
                        statusBgColor: statusColor.opacity(0.08),
                        iconName: isBrakeOrTire ? "wrench.fill" : "doc.text.fill"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - AI Insights Section

    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal)
            
            Button(action: {
                // Future predictive inspection navigation or sheets can be added here
            }) {
                HStack(spacing: 14) {
                    // Left glowing brain / chart icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.fmsAmberLight)
                            .frame(width: 48, height: 48)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 20))
                            .foregroundColor(Color.fmsAmber)
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Predictive Maintenance Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("SMART")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.fmsAmber)
                                .cornerRadius(4)
                        }
                        
                        Text("Brake pads on Truck 12 may run below safety threshold levels within 7 days. Tap to inspect.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
                }
                .padding(14)
                .background(AppTheme.Background.card)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
    }
}

// MARK: - Stat Card Component

struct MaintenanceStatCard: View {
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    let title: String
    let value: String
    let valueColor: Color
    let subtext: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBgColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor)
                
                Text(subtext)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.04), lineWidth: 1.2)
        )
    }
}

struct QuickActionButton: View {
    let icon: String
    let iconColor: Color
    let iconBgColor: Color
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(iconBgColor)
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ShrinkButtonStyle())
    }
}

// MARK: - Schedule Card Component is now imported dynamically from the central ScheduleCardView.swift component

// MARK: - Work Order Card Component

struct WorkOrderCardView: View {
    let title: String
    let description: String
    let dateText: String
    let assigneeText: String
    let priorityText: String // e.g. "LOW", "HIGH", "MED", "URGENT"
    let statusText: String
    let statusColor: Color
    let statusBgColor: Color
    let iconName: String // e.g. "wrench.fill" or "doc.text.fill"
    
    var body: some View {
        HStack(spacing: 12) {
            // Left priority box (from screenshot)
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(Color.fmsAmber) // Icon is amber!
                
                Text(priorityText.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .frame(width: 52, height: 52)
            .background(Color.black.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.02), lineWidth: 1)
            )
            
            // Center text
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(1)
                
                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
                
                Text(dateText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .lineLimit(1)
                
                Text(assigneeText)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right status capsule & chevron
            HStack(spacing: 6) {
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusBgColor)
                    .cornerRadius(8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
            }
        }
        .padding(12)
        .background(AppTheme.Background.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.04), lineWidth: 1.2)
        )
    }
}

// MARK: - Utility Card Component

struct UtilityCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    var badgeCount: Int? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fmsAmberLight)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color.fmsAmber)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            if let badge = badgeCount {
                Text("\(badge)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.fmsAmber)
                    .clipShape(Circle())
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Background.card)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1.5)
        )
    }
}

// MARK: - Shrink Button Style (Tactile HIG interaction)

struct ShrinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    let count: Int
    var body: some View {
        Button(action: {}) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Text.primary)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.fmsAmber)
                        .clipShape(Circle())
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(ShrinkButtonStyle())
    }
}

// MARK: - Helper Model Extensions

extension WorkOrderStatus {
    var displayLabel: String {
        switch self {
        case .open:       return "Open"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }
    var color: Color {
        switch self {
        case .open:       return Color.fmsAmber
        case .inProgress: return AppTheme.Status.progress
        case .completed:  return AppTheme.Status.success
        case .cancelled:  return .gray
        }
    }
}

extension WorkOrderPriority {
    var color: Color {
        switch self {
        case .low:    return .gray
        case .medium: return Color.fmsAmber
        case .high:   return Color(red: 236/255, green: 110/255, blue: 37/255)
        case .urgent: return Color(red: 219/255, green: 68/255, blue: 85/255)
        }
    }
    var shortLabel: String {
        switch self {
        case .low:    return "LOW"
        case .medium: return "MED"
        case .high:   return "HIGH"
        case .urgent: return "URGENT"
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainerView: View {
        static let container: ModelContainer = {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let schema = Schema([User.self, WorkOrder.self, AppNotification.self, Vehicle.self, MaintenanceRecord.self])
            return try! ModelContainer(for: schema, configurations: config)
        }()
        
        let user: User
        
        init() {
            let ctx = Self.container.mainContext
            
            let fetchUser = try? ctx.fetch(FetchDescriptor<User>())
            if let existingUser = fetchUser?.first {
                self.user = existingUser
            } else {
                let newUser = User(
                    fullName: "Raj Kumar",
                    email: "raj@fleet.com",
                    phoneNumber: "9876543210",
                    passwordHash: "hashed",
                    role: .maintenance
                )
                ctx.insert(newUser)
                
                let wo1 = WorkOrder(vehicleId: UUID(), assignedTo: newUser.id,
                                    title: "Brake Issue – Truck 12",
                                    workDescription: "Front brake pads worn",
                                    priority: .high)
                let wo2 = WorkOrder(vehicleId: UUID(), assignedTo: newUser.id,
                                    title: "Oil Change – Van 05",
                                    workDescription: "Routine 10k km service",
                                    priority: .medium, status: .inProgress)
                let wo3 = WorkOrder(vehicleId: UUID(), assignedTo: newUser.id,
                                    title: "Tire Replacement – Truck 07",
                                    workDescription: "All four tires replaced",
                                    priority: .low, status: .completed,
                                    completedAt: .now)
                [wo1, wo2, wo3].forEach { ctx.insert($0) }
                
                let notif = AppNotification(userId: newUser.id,
                                            title: "New Work Order",
                                            message: "WO assigned: Brake Issue Truck 12",
                                            type: .maintenanceAlert)
                ctx.insert(notif)
                
                self.user = newUser
            }
        }
        
        var body: some View {
            MaintenanceDashboardView(currentUser: user)
                .modelContainer(Self.container)
        }
    }
    
    return PreviewContainerView()
}

// MARK: - Interactive Sheet Components

struct CreateWorkOrderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let currentUser: User
    
    @Query private var allVehicles: [Vehicle]
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPriority: WorkOrderPriority = .medium
    @State private var selectedVehicleId: UUID = UUID()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Work Order Details").foregroundColor(.primary).bold()) {
                    TextField("Title (e.g. Brake Replacement)", text: $title)
                        .foregroundColor(.primary)
                    
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Describe the issue in detail...")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $description)
                            .foregroundColor(.primary)
                            .frame(height: 100)
                    }
                }
                
                Section(header: Text("Priority").foregroundColor(.primary).bold()) {
                    Picker("Priority", selection: $selectedPriority) {
                        Text("Low").tag(WorkOrderPriority.low)
                        Text("Medium").tag(WorkOrderPriority.medium)
                        Text("High").tag(WorkOrderPriority.high)
                        Text("Urgent").tag(WorkOrderPriority.urgent)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Select Vehicle").foregroundColor(.primary).bold()) {
                    if allVehicles.isEmpty {
                        Text("No vehicles found in SwiftData.")
                            .foregroundColor(.primary)
                    } else {
                        Picker("Vehicle", selection: $selectedVehicleId) {
                            ForEach(allVehicles) { vehicle in
                                Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))")
                                    .foregroundColor(.primary)
                                    .tag(vehicle.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Work Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                if let firstVehicle = allVehicles.first {
                    selectedVehicleId = firstVehicle.id
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                let newOrder = WorkOrder(
                    vehicleId: selectedVehicleId,
                    assignedTo: currentUser.id,
                    title: title.isEmpty ? "General Repair" : title,
                    workDescription: description,
                    priority: selectedPriority,
                    status: .open
                )
                modelContext.insert(newOrder)
                try? modelContext.save()
                dismiss()
            }
            .disabled(title.isEmpty)
        }
    }
}

struct UpdateMaintenanceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let currentUser: User
    
    @Query private var allWorkOrders: [WorkOrder]
    
    var body: some View {
        let myWorkOrders = allWorkOrders.filter { $0.assignedTo == currentUser.id && $0.status != .completed }
        
        return NavigationView {
            List {
                if myWorkOrders.isEmpty {
                    Text("No pending work orders assigned to you.")
                        .foregroundColor(.primary)
                        .padding()
                } else {
                    ForEach(myWorkOrders) { order in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(order.workDescription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                order.status = .completed
                                order.completedAt = .now
                                
                                // Create corresponding Maintenance Record
                                let record = MaintenanceRecord(
                                    vehicleId: order.vehicleId,
                                    workOrderId: order.id,
                                    serviceType: order.title,
                                    serviceDate: .now,
                                    cost: 350.0, // Mock cost
                                    notes: "Completed successfully",
                                    performedBy: currentUser.id
                                )
                                modelContext.insert(record)
                                try? modelContext.save()
                            } label: {
                                Text("Complete")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct UploadRepairNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notesText = ""
    @State private var showingImageSelected = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Write Repair Notes").foregroundColor(.primary).bold()) {
                    TextEditor(text: $notesText)
                        .foregroundColor(.primary)
                        .frame(height: 120)
                }
                
                Section(header: Text("Attachment").foregroundColor(.primary).bold()) {
                    Button(action: {
                        showingImageSelected = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text(showingImageSelected ? "Repair_Photo.jpg attached" : "Take or Upload Photo")
                        }
                        .foregroundColor(Color.fmsAmber)
                    }
                }
            }
            .navigationTitle("Upload Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        dismiss()
                    }
                    .disabled(notesText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Maintenance Communication & Chat Views

struct MaintenanceCommunicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter = 0 // 0: All, 1: Managers, 2: Drivers
    
    // Custom Struct for Maintenance Chats
    struct MaintenanceChatThread: Identifiable {
        let id = UUID()
        var sender: String
        var role: String
        var roleLabel: String
        var time: String
        var lastMessage: String
        var initials: String
        var avatarColor: Color
        var unread: Bool
        var messages: [ChatMessage]
    }
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let isMe: Bool
        let text: String
        let time: String
    }
    
    @State private var threads = [
        MaintenanceChatThread(
            sender: "Priya Menon",
            role: "manager",
            roleLabel: "Fleet Manager",
            time: "10:30 AM",
            lastMessage: "Please check the brakes on Truck 12 immediately.",
            initials: "PM",
            avatarColor: Color(red: 0.0, green: 55/255, blue: 176/255),
            unread: true,
            messages: [
                ChatMessage(isMe: false, text: "Hello, we noticed an alert for Truck 12 brakes.", time: "10:28 AM"),
                ChatMessage(isMe: false, text: "Please check the brakes on Truck 12 immediately.", time: "10:30 AM")
            ]
        ),
        MaintenanceChatThread(
            sender: "Rajesh Kumar",
            role: "driver",
            roleLabel: "Driver (Truck 12)",
            time: "09:45 AM",
            lastMessage: "The brake pedal feels spongy when stopping. I have parked it in Bay 2.",
            initials: "RK",
            avatarColor: Color(red: 242/255, green: 153/255, blue: 74/255),
            unread: true,
            messages: [
                ChatMessage(isMe: false, text: "The brake pedal feels spongy when stopping. I have parked it in Bay 2.", time: "09:45 AM")
            ]
        ),
        MaintenanceChatThread(
            sender: "Amit Patel",
            role: "driver",
            roleLabel: "Driver (Van 05)",
            time: "Yesterday",
            lastMessage: "AC coolant levels were topped up. Works perfectly now, thanks!",
            initials: "AP",
            avatarColor: Color(red: 39/255, green: 174/255, blue: 96/255),
            unread: false,
            messages: [
                ChatMessage(isMe: true, text: "AC is serviced. Let me know if it cools fine.", time: "Yesterday, 3:15 PM"),
                ChatMessage(isMe: false, text: "AC coolant levels were topped up. Works perfectly now, thanks!", time: "Yesterday, 3:30 PM")
            ]
        ),
        MaintenanceChatThread(
            sender: "Suresh Rao",
            role: "manager",
            roleLabel: "Operations Manager",
            time: "2 days ago",
            lastMessage: "Weekly inventory order approved. Parts arriving Monday.",
            initials: "SR",
            avatarColor: Color(red: 99/255, green: 81/255, blue: 242/255),
            unread: false,
            messages: [
                ChatMessage(isMe: true, text: "Requesting inventory approval for 10 brake pads.", time: "2 days ago"),
                ChatMessage(isMe: false, text: "Weekly inventory order approved. Parts arriving Monday.", time: "2 days ago")
            ]
        )
    ]
    
    var filteredThreads: [MaintenanceChatThread] {
        threads.filter { thread in
            let matchesSearch = searchText.isEmpty || thread.sender.localizedCaseInsensitiveContains(searchText) || thread.lastMessage.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter: Bool
            if selectedFilter == 1 {
                matchesFilter = thread.role == "manager"
            } else if selectedFilter == 2 {
                matchesFilter = thread.role == "driver"
            } else {
                matchesFilter = true
            }
            
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search chats...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Filter Segment Control
                Picker("Filter", selection: $selectedFilter) {
                    Text("All").tag(0)
                    Text("Managers").tag(1)
                    Text("Drivers").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Chats List
                ScrollView {
                    VStack(spacing: 12) {
                        if filteredThreads.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 40)
                                Text("No conversations found")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(filteredThreads) { thread in
                                NavigationLink(destination: MaintenanceChatDetailView(thread: thread, onMessageSent: { newMsg in
                                    if let idx = threads.firstIndex(where: { $0.id == thread.id }) {
                                        threads[idx].messages.append(ChatMessage(isMe: true, text: newMsg, time: "Just Now"))
                                        threads[idx].lastMessage = newMsg
                                        threads[idx].time = "Just Now"
                                        threads[idx].unread = false
                                    }
                                })) {
                                    HStack(spacing: 14) {
                                        // Avatar Circle
                                        ZStack {
                                            Circle()
                                                .fill(thread.avatarColor.opacity(0.12))
                                                .frame(width: 48, height: 48)
                                            Text(thread.initials)
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(thread.avatarColor)
                                        }
                                        
                                        // Chat Info
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(thread.sender)
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundColor(.black)
                                                
                                                Spacer()
                                                
                                                Text(thread.time)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Text(thread.roleLabel)
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundColor(thread.role == "manager" ? AppTheme.Brand.primaryDeep : Color.fmsAmber)
                                            
                                            Text(thread.lastMessage)
                                                .font(.system(size: 13, weight: thread.unread ? .semibold : .regular, design: .rounded))
                                                .foregroundColor(thread.unread ? .black : .gray)
                                                .lineLimit(1)
                                        }
                                        
                                        if thread.unread {
                                            Circle()
                                                .fill(Color.fmsAmber)
                                                .frame(width: 8, height: 8)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.black.opacity(0.04), lineWidth: 1.2)
                                    )
                                    .shadow(color: Color.black.opacity(0.01), radius: 5, x: 0, y: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            }
            .navigationTitle("Communication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.fmsAmber)
                    .bold()
                }
            }
        }
    }
}

struct MaintenanceChatDetailView: View {
    @State var thread: MaintenanceCommunicationSheet.MaintenanceChatThread
    var onMessageSent: (String) -> Void
    
    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(thread.messages) { message in
                            HStack {
                                if message.isMe {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(message.text)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.fmsAmber)
                                            .cornerRadius(16)
                                        Text(message.time)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.text)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(16)
                                        Text(message.time)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    if let lastMsg = thread.messages.last {
                        proxy.scrollTo(lastMsg.id, anchor: .bottom)
                    }
                }
                .onChange(of: thread.messages.count) { _ in
                    if let lastMsg = thread.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom Message Input Bar
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .font(.system(size: 15))
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: {
                    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        onMessageSent(text)
                        let newMsg = MaintenanceCommunicationSheet.ChatMessage(isMe: true, text: text, time: "Just Now")
                        thread.messages.append(newMsg)
                        messageText = ""
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.fmsAmber)
                        .padding(10)
                        .background(Color.fmsAmberLight)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
        }
        .navigationTitle(thread.sender)
        .navigationBarTitleDisplayMode(.inline)
    }
}
