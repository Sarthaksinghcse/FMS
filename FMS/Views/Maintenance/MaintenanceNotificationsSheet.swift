//
//  MaintenanceNotificationsSheet.swift
//  FMS
//
//  Created by Antigravity on 30/05/26.
//

import SwiftUI
import SwiftData

struct MaintenanceNotificationsSheet: View {
    let currentUser: User
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \AppNotification.createdAt, order: .reverse) private var allNotifications: [AppNotification]
    @Query private var allWorkOrders: [WorkOrder]
    
    // Track if a specific work order detail should be presented
    @State private var selectedWorkOrder: WorkOrder?
    @State private var navigateToDetail = false
    
    private var filteredNotifications: [AppNotification] {
        allNotifications.filter { $0.userId == currentUser.id }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                if filteredNotifications.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 48 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text("All Caught Up!")
                            .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                        Text("No notifications at the moment.")
                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(AppTheme.Text.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredNotifications) { notification in
                                Button {
                                    handleNotificationTap(notification)
                                } label: {
                                    NotificationRow(notification: notification)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                            .foregroundColor(AppTheme.Text.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            // Navigate to detailed WorkOrder view when tapped
            .navigationDestination(isPresented: $navigateToDetail) {
                if let order = selectedWorkOrder {
                    MaintenanceTaskDetailView(order: order)
                }
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // 1. Mark notification as read locally
        notification.isRead = true
        try? modelContext.save()
        
        // 2. Sync notification status with Supabase
        Task {
            try? await SupabaseManager.shared.updateNotification(notification.asDBNotification)
        }
        
        // 3. Find matching WorkOrder
        if let workOrderId = extractUUID(from: notification.message) {
            if let order = allWorkOrders.first(where: { $0.id == workOrderId }) {
                selectedWorkOrder = order
                navigateToDetail = true
                return
            }
        }
        
        // Fallback: search by matching name or title tokens if ID not parsed
        if let order = allWorkOrders.first(where: { notification.message.contains($0.title) || notification.title.contains($0.title) }) {
            selectedWorkOrder = order
            navigateToDetail = true
        }
    }
    
    private func extractUUID(from text: String) -> UUID? {
        let pattern = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return UUID(uuidString: String(text[range]))
    }
}

private struct NotificationRow: View {
    let notification: AppNotification
    
    private var icon: String {
        switch notification.type {
        case .defectAlert: return "exclamationmark.triangle.fill"
        case .maintenanceAlert: return "wrench.and.screwdriver.fill"
        case .tripAssigned: return "car.fill"
        case .sosAlert: return "exclamationmark.shield.fill"
        case .general: return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .defectAlert: return AppTheme.Brand.amber
        case .maintenanceAlert: return AppTheme.Brand.primary
        case .tripAssigned: return AppTheme.Brand.royalBlue
        case .sosAlert: return AppTheme.Status.danger
        case .general: return AppTheme.Text.secondary
        }
    }
    
    private var iconBgColor: Color {
        iconColor.opacity(0.1)
    }
    
    private var categoryLabel: String {
        switch notification.type {
        case .defectAlert: return "Defect Alert"
        case .maintenanceAlert: return "Maintenance"
        case .tripAssigned: return "Trip Assigned"
        case .sosAlert: return "SOS Emergency"
        case .general: return "General"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // Header Row
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(iconBgColor)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                            .foregroundColor(iconColor)
                    }
                    .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryLabel.uppercased())
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(iconColor)
                            .tracking(0.5)
                        
                        Text(notification.isRead ? "READ" : "UNREAD")
                            .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(notification.isRead ? AppTheme.Text.secondary : AppTheme.Brand.royalBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(notification.isRead ? Color.black.opacity(0.06) : AppTheme.Brand.royalBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Status/New Badge
                Text(!notification.isRead ? "NEW" : "READ")
                    .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        !notification.isRead
                            ? LinearGradient(colors: [AppTheme.Brand.primary, AppTheme.Brand.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: !notification.isRead ? AppTheme.Brand.primary.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text(notification.message)
                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            
            Divider().background(Color.black.opacity(0.06))
            
            // Details Grid
            HStack(spacing: 16) {
                // Category Detail Pill
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 28, height: 28)
                        Image(systemName: "tag.fill")
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TYPE")
                            .font(.system(size: 8 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(categoryLabel)
                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                    }
                }
                .padding(.trailing, 4)
                
                // Action Detail Pill
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.04))
                            .frame(width: 28, height: 28)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACTION")
                            .font(.system(size: 8 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text("VIEW DETAILS")
                            .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Time Detail Pill
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RECEIVED")
                        .font(.system(size: 8 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text(notification.createdAt.formatted(.relative(presentation: .numeric)))
                        .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                }
            }
            .padding(.vertical, 2)
        }
        .padding(18)
        .background(
            !notification.isRead
                ? LinearGradient(
                    colors: [AppTheme.Brand.primary.opacity(0.08), AppTheme.Brand.teal.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                : LinearGradient(
                    colors: [AppTheme.Background.card, AppTheme.Background.card],
                    startPoint: .top,
                    endPoint: .bottom
                  )
        )
        .cornerRadius(AppTheme.Radius.card)
        .shadow(
            color: !notification.isRead
                ? AppTheme.Brand.primary.opacity(0.08)
                : AppTheme.Shadow.card,
            radius: 12, x: 0, y: 6
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(
                    !notification.isRead
                        ? AppTheme.Brand.primary.opacity(0.35)
                        : AppTheme.Glass.border.opacity(0.2),
                    lineWidth: !notification.isRead ? 1.5 : 1.0
                )
        )
    }
}
