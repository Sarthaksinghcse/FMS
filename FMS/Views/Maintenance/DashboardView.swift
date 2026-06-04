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
    @Query private var allUsers: [User]

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

    private var managerChannel: CommunicationChannel? {
        guard let manager = allUsers.first(where: { $0.role == .fleetManager }) else { return nil }
        
        let parts = manager.fullName.split(separator: " ")
        let initials: String
        if parts.count >= 2 {
            initials = String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else {
            initials = String(manager.fullName.prefix(2)).uppercased()
        }
        
        return CommunicationChannel(
            id: manager.id,
            senderName: manager.fullName,
            textPreview: "Chat with Manager",
            timestamp: "",
            unreadCount: 0,
            initials: initials,
            avatarColor: AppTheme.Brand.violet,
            category: .managers,
            autoReplies: []
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // ── Greeting Header ────────────────────────
                        HStack(alignment: .center, spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(getGreetingTime() + ",")
                                    .font(.system(size: 17 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .regular))
                                    .foregroundStyle(.secondary)
                                Text(personnelFirstName)
                                    .font(.system(size: 28 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            // Bell Button
                            Button {
                                showingNotifications = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 18 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                        .foregroundStyle(Color(UIColor.label))
                                        .frame(width: 40, height: 40)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .clipShape(Circle())
                                    
                                    if unreadNotifications.count > 0 {
                                        Circle()
                                            .fill(AppTheme.Status.danger)
                                            .frame(width: 10, height: 10)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer().frame(width: 12)

                            // Avatar Button
                            Button {
                                showingProfile = true
                            } label: {
                                ZStack {
                                    if let imageURLString = currentUser.profileImageURL,
                                       let imageURL = URL(string: imageURLString) {
                                        CachedAsyncImage(url: imageURL) { image in
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [AppTheme.Brand.primary, AppTheme.Brand.primary.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                            Text(initials)
                                                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.5)
                                                .frame(width: 40, height: 40, alignment: .center)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        overviewSection

                        quickActionsSection
                        recentWorkOrdersSection
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
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
            .sheet(isPresented: $showChat) {
                NavigationStack {
                    CommunicationView()
                }
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
                    title: "Scheduled",
                    value: "\(scheduledToday.count)",
                    footnote: scheduledToday.count == 1 ? "1 open work order" : "\(scheduledToday.count) open work orders",
                    valueColor: Color(red: 0.08, green: 0.12, blue: 0.22)
                ) {
                    ScheduledTasksView(
                        currentUser: currentUser,
                        allWorkOrders: allWorkOrders,
                        hidesTabBar: true
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
                        allWorkOrders: allWorkOrders,
                        hidesTabBar: true
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
                        allWorkOrders: allWorkOrders,
                        hidesTabBar: true
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
                
                Button {
                    showChat = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.Brand.primary.opacity(0.08))
                                .frame(width: 56, height: 56)
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                .foregroundColor(AppTheme.Brand.royalBlue)
                        }
                        
                        Text("Chat")
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
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
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }



    // MARK: - Recent Work Orders

    private var recentWorkOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Recent Work Orders")
                Spacer()
                Button("See All") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selectedTab = 1 }
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
                .font(.system(size: 36 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
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
                        .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    Text(description)
                        .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
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
                        .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
                
                Text(label)
                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
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