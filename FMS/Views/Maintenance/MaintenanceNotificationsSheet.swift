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
                
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        Text("Notifications")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Text.tertiary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    if filteredNotifications.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.Text.tertiary)
                            Text("All Caught Up!")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                            Text("No notifications at the moment.")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Text.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                    } else {
                        List {
                            ForEach(filteredNotifications) { notification in
                                Button {
                                    handleNotificationTap(notification)
                                } label: {
                                    NotificationRow(notification: notification)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear)
                    }
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
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconBgColor)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(notification.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(AppTheme.Brand.royalBlue)
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                    }
                }
                
                Text(notification.message)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(notification.createdAt.formatted(.relative(presentation: .numeric)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(notification.isRead ? AppTheme.Background.card : AppTheme.Brand.royalBlue.opacity(0.04))
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(notification.isRead ? AppTheme.Glass.border : AppTheme.Brand.royalBlue.opacity(0.15), lineWidth: 1)
        )
    }
}
