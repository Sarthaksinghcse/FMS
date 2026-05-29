//
//  DashboardDetailComponent.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//



import SwiftUI
import SwiftData



// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Tappable Overview Card (replaces StatCard in Dashboard)
// ─────────────────────────────────────────────────────────────────────────────

struct TappableOverviewCard<Destination: View>: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let gradient: [Color]
    let title: String
    let value: String
    let footnote: String
    var valueColor: Color? = nil
    let destination: () -> Destination

    @State private var isPressed = false

    var body: some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconBg)
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary.opacity(0.6))
                        .padding(.top, 4)
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)

                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor ?? Color(red: 0.08, green: 0.12, blue: 0.22))

                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Text.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                        .fill(AppTheme.Background.card)
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                }
            )
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Detail Screen Header
// ─────────────────────────────────────────────────────────────────────────────

struct DetailScreenHeader: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
            }
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Search Bar
// ─────────────────────────────────────────────────────────────────────────────

struct TaskSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search tasks..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Text.tertiary)

            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Text.primary)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { text = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Text.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.medium)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Filter Chip
// ─────────────────────────────────────────────────────────────────────────────

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : AppTheme.Text.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? accentColor : AppTheme.Background.card)
                )
                .shadow(
                    color: isSelected ? accentColor.opacity(0.3) : Color.black.opacity(0.04),
                    radius: isSelected ? 4 : 2, x: 0, y: 1
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
    }
}

struct FilterChipRow: View {
    let chips: [String]
    @Binding var selected: Int
    let accentColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips.indices, id: \.self) { idx in
                    FilterChip(
                        label: chips[idx],
                        isSelected: selected == idx,
                        accentColor: accentColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = idx
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Status Badge (reusable pill)
// ─────────────────────────────────────────────────────────────────────────────

struct TaskStatusBadge: View {
    let label: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Priority Badge
// ─────────────────────────────────────────────────────────────────────────────

struct PriorityBadge: View {
    let priority: WorkOrderPriority

    var body: some View {
        Text(priority.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(priority.detailColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priority.detailColor.opacity(0.12))
            .cornerRadius(6)
    }
}

extension WorkOrderPriority {
    var detailColor: Color {
        switch self {
        case .low:    return .gray
        case .medium: return AppTheme.Brand.primary
        case .high:   return AppTheme.Brand.amber
        case .urgent: return AppTheme.Status.danger
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Maintenance Task Model (backend-ready)
// ─────────────────────────────────────────────────────────────────────────────
// This struct bridges WorkOrder (SwiftData) to a richer UI model,
// and is ready for a backend payload mapping layer.

struct MaintenanceTask: Identifiable {
    let id: UUID
    let vehicleName: String
    let serviceType: String
    let scheduledTime: Date
    let mechanicName: String
    let location: String
    let priority: WorkOrderPriority
    let status: WorkOrderStatus
    let estimatedCompletion: Date?
    let partsUsed: [String]
    let laborCost: Double?
    let repairNotes: String?
    let daysOverdue: Int

    // MARK: Init from WorkOrder (SwiftData model)
    init(from order: WorkOrder,
         vehicleName: String,
         mechanicName: String,
         location: String = "Bay \(Int.random(in: 1...6))",
         partsUsed: [String] = [],
         repairNotes: String? = nil,
         serviceType: String? = nil) {
        self.id = order.id
        self.vehicleName = vehicleName
        self.serviceType = serviceType ?? order.title
        self.scheduledTime = order.createdAt
        self.mechanicName = mechanicName
        self.location = location
        self.priority = order.priority
        self.status = order.status
        self.estimatedCompletion = order.completedAt ?? Calendar.current.date(byAdding: .hour, value: 3, to: order.createdAt)
        self.partsUsed = partsUsed
        self.laborCost = order.estimatedCost
        self.repairNotes = order.workDescription
        self.daysOverdue = {
            guard order.status == .open else { return 0 }
            let diff = Calendar.current.dateComponents([.day], from: order.createdAt, to: .now)
            return max(0, (diff.day ?? 0))
        }()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Empty State View
// ─────────────────────────────────────────────────────────────────────────────

struct DetailEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(accentColor.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Text.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 40)
    }
}

