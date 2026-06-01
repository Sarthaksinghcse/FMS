import SwiftUI
import SwiftData

struct ComplianceAlertsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var vehicles: [Vehicle]
    @Query private var persistedAlerts: [ComplianceAlert]

    @State private var viewModel = ComplianceAlertsViewModel()
    @State private var selectedAlert: ComplianceAlertItem? = nil
    @State private var alertToResolve: ComplianceAlertItem? = nil

    private var allAlerts: [ComplianceAlertItem] {
        viewModel.generateAlerts(vehicles: vehicles, persistedAlerts: persistedAlerts)
    }

    private var displayedAlerts: [ComplianceAlertItem] {
        viewModel.filteredAlerts(from: allAlerts)
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: - Summary Badges
                    summaryBadges

                    // MARK: - Segment Picker
                    segmentPicker

                    // MARK: - Type Filter Chips
                    typeFilterChips

                    // MARK: - Alerts List
                    if displayedAlerts.isEmpty {
                        emptyState
                    } else {
                        alertsList
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Compliance & Renewals")
        .toolbarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedAlert) { item in
            ComplianceAlertDetailSheet(item: item) {
                resolveFromDetail(item: item)
            }
        }
        .sheet(item: $alertToResolve) { item in
            ResolveAlertSheet(item: item) { newDate in
                performResolve(item: item, newDate: newDate)
            }
        }
    }

    // MARK: - Summary Badges

    private var summaryBadges: some View {
        HStack(spacing: 12) {
            ComplianceSummaryBadge(
                icon: "exclamationmark.triangle.fill",
                count: viewModel.overdueCount(from: allAlerts),
                label: "Overdue",
                color: ComplianceAlertStatus.overdue.color
            )
            ComplianceSummaryBadge(
                icon: "clock.badge.exclamationmark",
                count: viewModel.upcomingCount(from: allAlerts),
                label: "Upcoming",
                color: ComplianceAlertStatus.upcoming.color
            )
            ComplianceSummaryBadge(
                icon: "checkmark.seal.fill",
                count: viewModel.resolvedCount(from: allAlerts),
                label: "Resolved",
                color: ComplianceAlertStatus.resolved.color
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        Picker("Filter", selection: $viewModel.selectedSegment) {
            ForEach(ComplianceSegment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    // MARK: - Type Filter Chips

    private var typeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TypeFilterChip(
                    label: "All Types",
                    icon: "square.grid.2x2.fill",
                    isSelected: viewModel.selectedType == nil,
                    color: AppTheme.Brand.primary
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedType = nil
                    }
                }

                ForEach(ComplianceAlertType.allCases, id: \.self) { type in
                    TypeFilterChip(
                        label: type.displayName,
                        icon: type.icon,
                        isSelected: viewModel.selectedType == type,
                        color: type.color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedType = (viewModel.selectedType == type) ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Alerts List

    private var alertsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(displayedAlerts) { item in
                ComplianceAlertCard(item: item) {
                    selectedAlert = item
                }
                .swipeActions(edge: .trailing) {
                    if item.status != .resolved {
                        Button {
                            alertToResolve = item
                        } label: {
                            Label("Resolve", systemImage: "checkmark.circle.fill")
                        }
                        .tint(ComplianceAlertStatus.resolved.color)
                    }
                }
                .contextMenu {
                    if item.status != .resolved {
                        Button {
                            alertToResolve = item
                        } label: {
                            Label("Mark as Resolved", systemImage: "checkmark.circle.fill")
                        }
                    }
                    Button {
                        selectedAlert = item
                    } label: {
                        Label("View Details", systemImage: "info.circle")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Status.success.opacity(0.5))

            Text("All Clear!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)

            Text("No compliance alerts match your current filters.\nAll vehicles are within safe compliance limits.")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
        .padding(.horizontal, 16)
    }

    private func resolveFromDetail(item: ComplianceAlertItem) {
        selectedAlert = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            alertToResolve = item
        }
    }

    private func performResolve(item: ComplianceAlertItem, newDate: Date) {
        if let vehicle = vehicles.first(where: { $0.id == item.vehicleId }) {
            // Update vehicle model attributes based on alert type
            switch item.alertType {
            case .insurance:
                vehicle.insuranceExpiryDate = newDate
            case .permit:
                vehicle.permitExpiryDate = newDate
            case .servicing:
                vehicle.nextServiceDate = newDate
                vehicle.lastServiceDate = Date() // Mark last service as completed today
            }
            
            // Mark the alert as resolved in SwiftData persisted store
            viewModel.resolveAlert(item: item, context: modelContext)
            
            // Save local SwiftData context
            try? modelContext.save()
            
            // Sync updated vehicle information back to the remote database
            let dbVehicle = vehicle.asDBVehicle
            Task {
                do {
                    try await SupabaseManager.shared.updateVehicle(dbVehicle)
                    print("Synced resolved vehicle details to remote database.")
                } catch {
                    print("Failed to sync resolved vehicle details to database: \(error.localizedDescription)")
                }
            }
        }
    }
}


// MARK: - Summary Badge

struct ComplianceSummaryBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }
}


// MARK: - Type Filter Chip

struct TypeFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Alert Card

struct ComplianceAlertCard: View {
    let item: ComplianceAlertItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon badge
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(item.alertType.color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: item.alertType.icon)
                        .font(.system(size: 20))
                        .foregroundColor(item.alertType.color)
                        .frame(width: 48, height: 48)

                    // Status dot
                    Circle()
                        .fill(item.status.color)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: 3, y: 3)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.alertType.displayName)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(item.alertType.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(item.alertType.color.opacity(0.1))
                            )

                        ComplianceStatusPill(status: item.status)
                    }

                    Text(item.vehicleRegistration)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)

                    Text("\(item.vehicleMakeModel) · \(item.vehicleYear)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Text.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(item.deadlineDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 11))
                        Text("·")
                        Text(item.urgencyLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(item.urgencyColor)
                    }
                    .foregroundColor(AppTheme.Text.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.5))
            }
            .padding(14)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                    .stroke(
                        item.status == .overdue
                            ? ComplianceAlertStatus.overdue.color.opacity(0.3)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Status Pill

struct ComplianceStatusPill: View {
    let status: ComplianceAlertStatus

    var body: some View {
        Text(status.displayName.uppercased())
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(status.color.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(status.color.opacity(0.25), lineWidth: 1)
            )
    }
}


// MARK: - Detail Sheet

struct ComplianceAlertDetailSheet: View {
    let item: ComplianceAlertItem
    let onResolve: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Status header
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: item.alertType.icon)
                                        .font(.system(size: 22))
                                        .foregroundColor(item.alertType.color)
                                    Text(item.alertType.displayName + " Alert")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(AppTheme.Text.primary)
                                }
                                ComplianceStatusPill(status: item.status)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        // Vehicle Details
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Vehicle Information")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)

                            DetailRow(label: "Registration", value: item.vehicleRegistration)
                            DetailRow(label: "Make & Model", value: item.vehicleMakeModel)
                            DetailRow(label: "Year", value: "\(item.vehicleYear)")
                            DetailRow(label: "Type", value: item.vehicleType.displayName)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        // Deadline Details
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Deadline Information")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)

                            DetailRow(
                                label: "Deadline Date",
                                value: item.deadlineDate.formatted(date: .long, time: .omitted)
                            )
                            DetailRow(label: "Status", value: item.urgencyLabel, valueColor: item.urgencyColor)

                            if let resolvedAt = item.resolvedAt {
                                DetailRow(
                                    label: "Resolved On",
                                    value: resolvedAt.formatted(date: .long, time: .shortened),
                                    valueColor: ComplianceAlertStatus.resolved.color
                                )
                            }
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        // Resolve button
                        if item.status != .resolved {
                            Button {
                                onResolve()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                    Text("Mark as Resolved")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [ComplianceAlertStatus.resolved.color, ComplianceAlertStatus.resolved.color.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(AppTheme.Radius.medium)
                                .shadow(color: ComplianceAlertStatus.resolved.color.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer().frame(height: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Alert Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
    }
}


// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Text.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor ?? AppTheme.Text.primary)
        }
    }
}


// MARK: - Resolve Alert Calendar Sheet

struct ResolveAlertSheet: View {
    let item: ComplianceAlertItem
    let onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header info card
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(item.alertType.color.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                Image(systemName: item.alertType.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(item.alertType.color)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.vehicleRegistration)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Text.primary)
                                Text("Renewing \(item.alertType.displayName)")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Text.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        // Date picker card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("New Expiration Date")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)

                            DatePicker(
                                "Select Date",
                                selection: $selectedDate,
                                in: Date()...,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .tint(item.alertType.color)
                        }
                        .padding(16)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                        // Action button
                        Button {
                            onSave(selectedDate)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text("Update and Resolve")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [item.alertType.color, item.alertType.color.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: item.alertType.color.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)

                        Spacer().frame(height: 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Resolve Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                // Pre-populate with a reasonable future date
                let calendar = Calendar.current
                if item.alertType == .insurance {
                    selectedDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                } else if item.alertType == .permit {
                    selectedDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
                } else { // servicing
                    selectedDate = calendar.date(byAdding: .month, value: 6, to: Date()) ?? Date()
                }
            }
        }
    }
}
