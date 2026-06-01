//
//  SharedComponent.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//



import SwiftUI
import SwiftData

// MARK: - Reusable UI Components

struct MaintenanceHeaderView: View {
    let title: String
    let subtitle: String
    var greeting: String? = nil
    let initials: String
    var avatarColor: Color = AppTheme.Brand.primaryDeep
    let notificationCount: Int
    var onNotificationTap: () -> Void = {}
    var onProfileTap: () -> Void = {}
    var showActions: Bool = true
    var showBackButton: Bool = false
    var showChat: Bool = false
    var onChatTap: () -> Void = {}
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .top) {
            if showBackButton {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Text.primary)
                }
                .padding(.top, 4)
                .padding(.trailing, 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let greeting = greeting, !greeting.isEmpty {
                    Text(greeting)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                }
            }
            
            Spacer()
            
            if showActions {
                HStack(spacing: 16) {
                    if showChat {
                        Button(action: onChatTap) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(UIColor.label))
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: onNotificationTap) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(UIColor.label))
                                .frame(width: 40, height: 40)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                            
                            if notificationCount > 0 {
                                Circle()
                                    .fill(AppTheme.Status.danger)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onProfileTap) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [avatarColor, avatarColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Text(initials)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct CustomCenteredHeaderView: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)
            
            Spacer()
            
            // Dummy view to ensure exact centering
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(AppTheme.Background.page)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title3).fontWeight(.bold)
            .padding(.horizontal)
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let value: String
    let footnote: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(iconBg)
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(iconColor)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                }
                
                Text(title)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(AppTheme.Text.primary)
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary) // Unified clean adaptive dark navy value
                Text(footnote)
                    .font(.caption)
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 11)).fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.medium)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Premium Feature Row Card

struct MaintenanceRowCard: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let description: String
    let footnote: String
    var badgeCount: Int? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Top Row: Icon and Chevron
                HStack {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(iconBg)
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(iconColor)
                        
                        if let count = badgeCount, count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 18, height: 18)
                                .background(AppTheme.Status.danger)
                                .clipShape(Circle())
                                .offset(x: 10, y: -6)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.8))
                }
                
                // Bottom content: Title & Descriptions
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    
                    Text(description)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                        .lineLimit(1)
                    
                    Text(footnote)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Text.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 142, maxHeight: 142, alignment: .topLeading)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Work Order Row

struct WorkOrderRow: View {
    let order: WorkOrder
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 14) {
            // Icon + Priority badge matching the screenshot layout
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray6))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18))
                        .foregroundColor(order.priority.detailColor)
                }
                
                Text(order.priority.shortLabel)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(order.priority.detailColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(order.priority.detailColor.opacity(0.08))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(order.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineLimit(1)
                
                Text(order.workDescription)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
                
                Text("Created: \(order.createdAt.formatted(date: .abbreviated, time: .omitted))\nMaintenance Personnel")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                let isPending = order.status == .open && order.workDescription.contains("[PENDING_APPROVAL]")
                WorkOrderStatusBadge(
                    statusLabel: isPending ? "Approval Pending" : order.status.displayLabel,
                    statusColor: isPending ? AppTheme.Brand.amber : order.status.color
                )
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

        Group {
            if let action = action {
                Button(action: action) {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                content
            }
        }
    }
}

// MARK: - Status Badge

struct WorkOrderStatusBadge: View {
    let statusLabel: String
    let statusColor: Color

    var body: some View {
        Text(statusLabel)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(statusColor.opacity(0.12)))
            .overlay(Capsule().stroke(statusColor.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Notification Bell Button

struct NotificationBellButton: View {
    let count: Int
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.Text.primary.opacity(0.6))
                if count > 0 {
                    Text("\(min(count, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppTheme.Text.onDark)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(AppTheme.Status.danger)
                        .clipShape(Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
    }
}

// MARK: - Model Extensions (display helpers only — no data mutation)

extension WorkOrderStatus {
    var displayLabel: String {
        switch self {
        case .open:       return "Pending"
        case .inProgress: return "In Progress"
        case .completed:  return "Completed"
        case .cancelled:  return "Cancelled"
        }
    }
    var color: Color {
        switch self {
        case .open:       return AppTheme.Brand.accent // Cohesive Amber/Accent
        case .inProgress: return AppTheme.Brand.primary // Cohesive Brand Blue
        case .completed:  return AppTheme.Status.success // Soft clean Green
        case .cancelled:  return .gray
        }
    }
}

extension WorkOrderPriority {
    var color: Color {
        switch self {
        case .low:    return .gray
        case .medium: return AppTheme.Brand.primary
        case .high:   return AppTheme.Brand.primaryDeep
        case .urgent: return AppTheme.Brand.accent
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
