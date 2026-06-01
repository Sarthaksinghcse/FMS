//
//  DashboardView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import SwiftData

struct MaintenanceDashboardTab: View {
    @Environment(\.modelContext) private var modelContext
    // Logged-in maintenance user (passed from parent/login)
    let currentUser: User

    // SwiftData queries
    @Query private var allWorkOrders: [WorkOrder]
    @Query private var allInventory: [InventoryItem]
    @Query private var allNotifications: [AppNotification]

    // Navigation trigger or tab switching binding if needed
    @Binding var selectedTab: Int
    @Binding var schedulingFilter: Int

    @State private var showingProfile = false
    @State private var showChat = false
    @State private var showingNotifications = false

    private var personnelFirstName: String {
        guard !currentUser.fullName.isEmpty else { return "Staff" }
        return currentUser.fullName.components(separatedBy: " ").first ?? currentUser.fullName
    }

    private func getGreetingTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning" }
        else if hour < 17 { return "Good Afternoon" }
        else { return "Good Evening" }
    }

    // MARK: - Derived properties

    private var initials: String {
        let components = currentUser.fullName.components(separatedBy: " ")
        let first = components.first?.first.map(String.init) ?? ""
        let last = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        let combined = first + last
        return combined.isEmpty ? "M" : combined.uppercased()
    }

    private var scheduledToday: [WorkOrder] {
        return allWorkOrders.filter {
            $0.status == .open
        }
    }

    private var inProgressOrders: [WorkOrder] {
        allWorkOrders.filter { $0.status == .inProgress }
    }

    private var completedToday: [WorkOrder] {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return allWorkOrders.filter {
            $0.status == .completed &&
            ($0.completedAt ?? .distantPast) >= startOfDay
        }
    }

    private var overdueOrders: [WorkOrder] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        return allWorkOrders.filter {
            $0.assignedTo == currentUser.id &&
            ($0.status == .open || $0.status == .inProgress) &&
            $0.createdAt < cutoff
        }
    }

    private var lowStockItems: [InventoryItem] {
        allInventory.filter { $0.quantityInStock <= $0.reorderThreshold }
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

    var body: some View {
        // ── NavigationStack for smooth push transitions ───────────────────────
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Premium header
                        MaintenanceHeaderView(
                            title: personnelFirstName,
                            subtitle: "",
                            greeting: getGreetingTime() + ",",
                            initials: initials,
                            avatarColor: AppTheme.Brand.primaryDeep,
                            notificationCount: unreadNotifications.count,
                            onNotificationTap: { showingNotifications = true },
                            onProfileTap: { showingProfile = true },
                            showChat: false,
                            onChatTap: { showChat = true }
                        )
                        .padding(.top, 8)

                        overviewSection
                        quickActionsSection
                        aiInsightsSection
                        recentWorkOrdersSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 32)
                }
                .safeAreaPadding(.top)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .refreshable {
                    await SupabaseManager.shared.syncAllData(context: modelContext)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingProfile) {
                MaintenanceProfileView()
            }
            .sheet(isPresented: $showingNotifications) {
                MaintenanceNotificationsSheet(currentUser: currentUser)
            }
            .navigationDestination(isPresented: $showChat) {
                CommunicationView()
            }
        }
    }

    // MARK: - Overview Cards (fully tappable via NavigationLink)

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Overview")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                // ── 1. Scheduling (renamed from Pending Repairs) ─────────────────
                TappableOverviewCard(
                    icon: "doc.text.fill",
                    iconColor: AppTheme.Text.secondary,
                    iconBg: Color(.systemGray6),
                    gradient: [Color.clear, Color.clear],
                    title: "Scheduling",
                    value: "\(scheduledToday.count)",
                    footnote: scheduledToday.count == 1 ? "1 open work order" : "\(scheduledToday.count) open work orders",
                    valueColor: Color(red: 0.08, green: 0.12, blue: 0.22)
                ) {
                    ScheduledTasksView(
                        currentUser: currentUser,
                        allWorkOrders: allWorkOrders
                    )
                }

                // ── 2. Completed Today ────────────────────────────────────────
                TappableOverviewCard(
                    icon: "checkmark.circle.fill",
                    iconColor: AppTheme.Status.success,
                    iconBg: AppTheme.Status.success.opacity(0.12),
                    gradient: [Color.clear, Color.clear],
                    title: "Completed Today",
                    value: "\(completedToday.count)",
                    footnote: "Since midnight",
                    valueColor: AppTheme.Status.success
                ) {
                    CompletedTasksView(
                        currentUserId: currentUser.id,
                        allWorkOrders: allWorkOrders
                    )
                }

                // ── 3. In Progress ────────────────────────────────────────────
                TappableOverviewCard(
                    icon: "clock.fill",
                    iconColor: AppTheme.Brand.amber,
                    iconBg: AppTheme.IconBg.amber,
                    gradient: [Color.clear, Color.clear],
                    title: "In Progress",
                    value: "\(inProgressOrders.count)",
                    footnote: "Active now",
                    valueColor: AppTheme.Brand.amber
                ) {
                    InProgressTasksView(
                        currentUserId: currentUser.id,
                        allWorkOrders: allWorkOrders
                    )
                }

                // ── 4. Low Stock Parts ────────────────────────────────────────
                TappableOverviewCard(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: AppTheme.Status.danger,
                    iconBg: AppTheme.Status.danger.opacity(0.12),
                    gradient: [Color.clear, Color.clear],
                    title: "Low Stock Parts",
                    value: "\(lowStockItems.count)",
                    footnote: "Need reordering",
                    valueColor: AppTheme.Status.danger
                ) {
                    LowStockPartsDetailView()
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Actions")
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                GridQuickActionButton(
                    icon: "wrench.and.screwdriver.fill",
                    label: "Create Work Order",
                    destination: CreateWorkOrderView()
                )
                
                GridQuickActionButton(
                    icon: "checkmark.square.fill",
                    label: "Update Maintenance",
                    destination: UpdateMaintenanceView(currentUser: currentUser)
                )
                
                GridQuickActionButton(
                    icon: "camera.fill",
                    label: "Report an issue",
                    destination: ReportIssueView()
                )
                
                GridQuickActionButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: "Chat",
                    destination: CommunicationView()
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - AI Insights

    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "AI Insights")
            
            NavigationLink(destination: PredictiveAlertDetailView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Brand.royalBlue.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Predictive Maintenance Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("SMART")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(AppTheme.Brand.royalBlue)
                                .cornerRadius(4)
                        }
                        
                        Text("Brake pads on Truck 12 may run below safety threshold levels within 7 days. Tap to inspect...")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                }
                .padding(14)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .stroke(AppTheme.Glass.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: SparePartsForecastView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.purple.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "box.truck.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("AI Parts Demand Forecasting")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("PREDICT")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                        
                        Text("Calculate upcoming parts consumption & reorder recommendations...")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                }
                .padding(14)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .stroke(AppTheme.Glass.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            NavigationLink(destination: VehicleHealthAnalysisView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.teal.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.teal)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("AI Vehicle Health Analytics")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            
                            Text("HEALTH")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.teal)
                                .cornerRadius(4)
                        }
                        
                        Text("Assess fleet vehicle health grades, issue flags and repair tasks...")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                }
                .padding(14)
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .stroke(AppTheme.Glass.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
    }

    // MARK: - Recent Work Orders

    private var recentWorkOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Recent Work Orders")
                Spacer()
                Button("See All") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selectedTab = 2 }
                }
                .font(.subheadline).foregroundColor(AppTheme.Brand.primary)
            }
            .padding(.horizontal)

            if recentWorkOrders.isEmpty {
                emptyState(icon: "wrench.and.screwdriver", message: "No work orders assigned yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentWorkOrders.enumerated()), id: \.element.id) { idx, order in
                        NavigationLink(destination: MaintenanceTaskDetailView(order: order)) {
                            WorkOrderRow(order: order)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if idx < recentWorkOrders.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(AppTheme.Background.card)
                .cornerRadius(AppTheme.Radius.card)
                .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }



    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(AppTheme.Text.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppTheme.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppTheme.Background.card)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - NavigationQuickActionButton
struct NavigationQuickActionButton<Destination: View>: View {
    let icon: String
    let label: String
    let description: String
    let color: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    Text(description)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .padding(.trailing, 2)
            }
            .frame(width: 175, height: 48) // Uniform horizontal capsule card
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.medium)
            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                    .stroke(AppTheme.Glass.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - GridQuickActionButton
struct GridQuickActionButton<Destination: View>: View {
    let icon: String
    let label: String
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.Brand.primary.opacity(0.08))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.Text.primary)
                    .frame(height: 32, alignment: .top)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

