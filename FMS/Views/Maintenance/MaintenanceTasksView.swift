//
//  MaintenanceTasksView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//

import SwiftUI
import SwiftData

struct MaintenanceTaskDetailView: View {
    let order: WorkOrder

    @Environment(\.dismiss) private var dismiss

    private var statusColor: Color { order.status.color }

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
                    DetailSection(title: "Work Order Details", icon: "doc.text.fill", accentColor: AppTheme.Brand.primary) {
                        VStack(spacing: 0) {
                            DetailInfoRow(label: "Work Order Title", value: order.title, icon: "wrench.fill", color: AppTheme.Brand.primary)
                            Divider().padding(.leading, 52)
                            DetailInfoRow(label: "Description", value: order.workDescription.isEmpty ? "No description provided." : order.workDescription, icon: "text.alignleft", color: AppTheme.Brand.violet)
                            Divider().padding(.leading, 52)
                            DetailInfoRow(label: "Priority", value: order.priority.rawValue.capitalized, icon: "flag.fill", color: order.priority.detailColor)
                            Divider().padding(.leading, 52)
                            DetailInfoRow(label: "Status", value: order.status.displayLabel, icon: "circle.fill", color: statusColor)
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
                                    value: "₹\(String(format: "%.2f", cost))",
                                    icon: "indianrupeesign.circle",
                                    color: AppTheme.Status.success
                                )
                                Divider().padding(.leading, 52)
                                DetailInfoRow(
                                    label: "Parts Cost",
                                    value: "₹\(String(format: "%.2f", cost * 0.4))",
                                    icon: "cube.box.fill",
                                    color: AppTheme.Brand.primary
                                )
                                Divider().padding(.leading, 52)
                                DetailInfoRow(
                                    label: "Labor Cost",
                                    value: "₹\(String(format: "%.2f", cost * 0.6))",
                                    icon: "person.fill",
                                    color: AppTheme.Brand.violet
                                )
                            }
                        }
                    }

                    // ── Parts list ───────────────────────────────────────────
                    DetailSection(title: "Parts & Materials", icon: "cube.box.fill", accentColor: AppTheme.Brand.amber) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(simulatedParts.enumerated()), id: \.offset) { idx, part in
                                HStack(spacing: 12) {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(AppTheme.Brand.amber.opacity(0.8))
                                        .clipShape(Circle())

                                    Text(part)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.Text.primary)

                                    Spacer()

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
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
                                value: "TECH-\(order.assignedTo.uuidString.prefix(8).uppercased())",
                                icon: "person.badge.key.fill",
                                color: AppTheme.Brand.violet
                            )
                            Divider().padding(.leading, 52)
                            DetailInfoRow(
                                label: "Service Bay",
                                value: "Bay \(abs(order.id.hashValue % 6) + 1)",
                                icon: "mappin.circle.fill",
                                color: AppTheme.Status.success
                            )
                            Divider().padding(.leading, 52)
                            DetailInfoRow(
                                label: "Vehicle ID",
                                value: "VEH-\(order.vehicleId.uuidString.prefix(8).uppercased())",
                                icon: "car.fill",
                                color: AppTheme.Brand.primary
                            )
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
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Hero Card
// ─────────────────────────────────────────────────────────────────────────────

private struct DetailHeroCard: View {
    let order: WorkOrder

    var gradientColors: [Color] {
        switch order.status {
        case .completed: return [AppTheme.Status.success.opacity(0.08), Color.clear]
        case .inProgress: return [AppTheme.Brand.primary.opacity(0.08), Color.clear]
        case .open: return [AppTheme.Brand.amber.opacity(0.08), Color.clear]
        case .cancelled: return [Color.gray.opacity(0.08), Color.clear]
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(order.status.color.opacity(0.12))
                    .frame(width: 70, height: 70)
                Image(systemName: order.status.detailIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(order.status.color)
            }

            VStack(spacing: 6) {
                Text(order.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
                    .multilineTextAlignment(.center)

                TaskStatusBadge(
                    label: order.status.displayLabel,
                    color: order.status.color,
                    icon: order.status.detailIcon
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
    let content: () -> Content

    init(title: String, icon: String, accentColor: Color, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.22))
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
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
