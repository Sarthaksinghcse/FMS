//
//  DriverTripsTab.swift
//  FMS
//
//  Tab 2 — Trip list, integrated actions & Apple Maps navigation.
//  All actions live contextually — no separate action section.
//  Target: iOS 26+
//

import SwiftUI
import MapKit

// MARK: - Driver Trips Tab

@available(iOS 26.0, *)
struct DriverTripsTab: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @State private var selectedSegment = 0   // 0 = Upcoming, 1 = Completed

    // ── Segment picker bar (pinned below nav bar) ─────────────────────────────
    private var segmentPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["Upcoming", "Completed"].indices, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedSegment = i
                        }
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Text(i == 0 ? "Upcoming" : "Completed")
                                    .font(.system(size: 14, weight: selectedSegment == i ? .bold : .medium))
                                    .foregroundStyle(selectedSegment == i ? Color.fmsIndigo : .secondary)
                                if i == 0 && !vm.upcomingTrips.isEmpty {
                                    Text("\(vm.upcomingTrips.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.fmsIndigo)
                                        .clipShape(Capsule())
                                }
                                if i == 1 && !vm.completedTrips.isEmpty {
                                    Text("\(vm.completedTrips.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(AppTheme.Status.success)
                                        .clipShape(Capsule())
                                }
                            }
                            RoundedRectangle(cornerRadius: 2)
                                .fill(selectedSegment == i ? Color.fmsIndigo : Color.clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .background(Color.fmsBackground)
            Divider()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Segment picker — sits below the large title, above the list ──
                segmentPicker

                // ── Tab Content ───────────────────────────────────────────────
                if selectedSegment == 0 {
                    // ── UPCOMING TRIPS ────────────────────────────────────────
                    List {
                        if vm.isTripActive {
                            Section {
                                ActiveTripCell(vm: vm)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }

                        Section {
                            if vm.upcomingTrips.isEmpty {
                                EmptyTripsCell(icon: "map", message: "No trips assigned",
                                               subtitle: "Your fleet manager will assign routes here.")
                                    .listRowBackground(Color.clear)
                            } else {
                                ForEach(Array(vm.upcomingTrips.enumerated()), id: \.offset) { i, trip in
                                    TripRow(trip: trip, index: i, vm: vm)
                                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button { vm.showDefect = true } label: {
                                                Label("Defect", systemImage: "wrench.and.screwdriver.fill")
                                            }
                                            .tint(AppTheme.Status.danger)
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button { vm.showPreTrip = true } label: {
                                                Label("Inspect", systemImage: "checklist")
                                            }
                                            .tint(Color.fmsIndigo)
                                        }
                                        .contextMenu {
                                            Button { vm.mapActiveTrip = trip } label: {
                                                Label("Start Trip", systemImage: "play.fill")
                                            }
                                            Button { vm.showPreTrip  = true } label: { Label("Pre-Trip Inspection",  systemImage: "checklist") }
                                            Button { vm.showPostTrip = true } label: { Label("Post-Trip Inspection", systemImage: "checkmark.seal.fill") }
                                            Divider()
                                            Button { vm.showVoiceLog = true } label: { Label("Voice Log",    systemImage: "mic.fill") }
                                            Button { vm.showIssue    = true } label: { Label("Report Issue", systemImage: "exclamationmark.bubble.fill") }
                                            Button(role: .destructive) { vm.showDefect = true } label: {
                                                Label("Report Defect", systemImage: "wrench.and.screwdriver.fill")
                                            }
                                        }
                                }
                            }
                        } header: {
                            Text(vm.upcomingTrips.isEmpty ? "Assigned Trips" :
                                 "Assigned · \(vm.upcomingTrips.count) trip\(vm.upcomingTrips.count == 1 ? "" : "s")")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }

                } else {
                    // ── COMPLETED TRIPS ───────────────────────────────────────
                    if vm.completedTrips.isEmpty {
                        Spacer()
                        EmptyTripsCell(icon: "checkmark.seal",
                                       message: "No completed trips yet",
                                       subtitle: "Trips you finish will appear here with full details.")
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(vm.completedTrips) { record in
                                    CompletedTripCard(record: record)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .refreshable { await vm.load() }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Empty State Cell

private struct EmptyTripsCell: View {
    let icon: String
    let message: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.fmsIndigo.opacity(0.30))
            Text(message)
                .font(.system(size: 16, weight: .medium))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Completed Trip Card

@available(iOS 26.0, *)
private struct CompletedTripCard: View {
    let record: CompletedTripRecord
    @State private var showDetail = false

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: record.completedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ───────────────────────────────────────────
            HStack(spacing: 12) {
                // Green check circle
                ZStack {
                    Circle()
                        .fill(AppTheme.Status.success.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.Status.success)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.trip.destination)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text("from  \(record.trip.source)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("COMPLETED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.Status.success)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AppTheme.Status.success.opacity(0.12))
                        .clipShape(Capsule())
                    Text(dateLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            // ── Stats row ────────────────────────────────────────────
            HStack(spacing: 0) {
                StatPill(icon: "clock.fill",
                         value: record.formattedDuration,
                         label: "Time Taken",
                         color: Color.fmsIndigo)
                Divider().frame(height: 36)
                StatPill(icon: "arrow.left.arrow.right",
                         value: String(format: "%.0f km", record.distanceKm),
                         label: "Distance",
                         color: AppTheme.Brand.accent)
                Divider().frame(height: 36)
                StatPill(icon: record.inspectionPassed ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                         value: record.issuesFound == 0 ? "All Clear" : "\(record.issuesFound) Issues",
                         label: "Inspection",
                         color: record.inspectionPassed ? AppTheme.Status.success : AppTheme.Status.danger)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)

            Divider().padding(.horizontal, 16)

            // ── Details button ───────────────────────────────────────
            Button {
                showDetail = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13))
                    Text("View Full Details")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(Color.fmsIndigo)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .sheet(isPresented: $showDetail) {
            TripDetailSheet(record: record)
        }
    }
}

// ── Stat Pill (inside completed card) ─────────────────────────────────────────
private struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trip Detail Sheet

@available(iOS 26.0, *)
struct TripDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: CompletedTripRecord

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .full; f.timeStyle = .short
        return f.string(from: record.completedAt)
    }

    // Inspection items (same list as in InspectionFormSheet)
    private let inspectionItems = [
        ("Brakes & Brake Lights",   "hand.raised.fill"),
        ("Tyres & Tyre Pressure",   "circle.dashed"),
        ("Engine & Oil Level",      "gearshape.fill"),
        ("Headlights & Indicators", "lightbulb.fill"),
        ("Windshield & Wipers",     "cloud.drizzle.fill"),
        ("Seat Belts",              "figure.walk.circle.fill"),
        ("Mirrors",                 "arrow.left.and.right"),
        ("Horn",                    "megaphone.fill"),
        ("First Aid Kit",           "cross.case.fill"),
        ("Documents & Permits",     "doc.text.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Hero summary card ────────────────────────────
                    VStack(spacing: 16) {
                        // Big green check
                        ZStack {
                            Circle()
                                .fill(AppTheme.Status.success.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.Status.success)
                        }

                        VStack(spacing: 4) {
                            Text("Trip Completed")
                                .font(.system(size: 20, weight: .bold))
                            Text(dateLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        // Route
                        HStack(spacing: 8) {
                            Label(record.trip.source, systemImage: "circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Label(record.trip.destination, systemImage: "mappin.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.fmsIndigo)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // ── Key stats grid ───────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("TRIP SUMMARY")

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                            GridItem(.flexible(), spacing: 12)],
                                  spacing: 12) {
                            DetailStatCard(icon: "clock.fill",
                                           label: "Time Taken",
                                           value: record.formattedDuration,
                                           sub: record.elapsedSeconds >= 60
                                               ? "\(record.elapsedSeconds / 60) minutes total"
                                               : "\(record.elapsedSeconds) seconds total",
                                           color: Color.fmsIndigo)
                            DetailStatCard(icon: "arrow.left.arrow.right",
                                           label: "Distance",
                                           value: String(format: "%.0f km", record.distanceKm),
                                           sub: String(format: "%.1f miles", record.distanceKm * 0.621),
                                           color: AppTheme.Brand.accent)
                            DetailStatCard(icon: "fuelpump.fill",
                                           label: "Avg Speed",
                                           value: record.elapsedSeconds > 0
                                               ? String(format: "%.0f km/h",
                                                        record.distanceKm / (Double(record.elapsedSeconds) / 3600))
                                               : "—",
                                           sub: "estimated",
                                           color: AppTheme.Status.success)
                            DetailStatCard(icon: record.inspectionPassed
                                               ? "checkmark.shield.fill"
                                               : "exclamationmark.shield.fill",
                                           label: "Inspection",
                                           value: record.issuesFound == 0 ? "All Clear" : "\(record.issuesFound) Issues",
                                           sub: record.inspectionPassed ? "No defects" : "Flagged",
                                           color: record.inspectionPassed
                                               ? AppTheme.Status.success
                                               : AppTheme.Status.danger)
                        }
                    }

                    // ── Inspection Report ────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("POST-TRIP INSPECTION REPORT")

                        VStack(spacing: 0) {
                            // Summary badge
                            HStack {
                                Image(systemName: record.inspectionPassed
                                      ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(record.inspectionPassed
                                                     ? AppTheme.Status.success
                                                     : AppTheme.Status.danger)
                                Text(record.inspectionPassed
                                     ? "All items passed — vehicle in good condition"
                                     : "\(record.issuesFound) item(s) flagged for maintenance")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(record.inspectionPassed
                                                     ? AppTheme.Status.success
                                                     : AppTheme.Status.danger)
                                Spacer()
                            }
                            .padding(14)
                            .background((record.inspectionPassed
                                         ? AppTheme.Status.success
                                         : AppTheme.Status.danger).opacity(0.08))

                            Divider()

                            // Per-item list — top (10 - issuesFound) passed, rest failed
                            let passedCount = inspectionItems.count - record.issuesFound
                            ForEach(Array(inspectionItems.enumerated()), id: \.offset) { idx, item in
                                let itemPassed = idx < passedCount
                                HStack(spacing: 14) {
                                    Image(systemName: item.1)
                                        .font(.system(size: 15))
                                        .foregroundStyle(itemPassed ? AppTheme.Status.success : AppTheme.Status.danger)
                                        .frame(width: 24)
                                    Text(item.0)
                                        .font(.system(size: 14))
                                        .foregroundStyle(itemPassed ? .primary : AppTheme.Status.danger)
                                    Spacer()
                                    Image(systemName: itemPassed ? "checkmark" : "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(itemPassed ? AppTheme.Status.success : AppTheme.Status.danger)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if idx < inspectionItems.count - 1 {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // ── Remarks ──────────────────────────────────────
                    if !record.inspectionRemarks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader("DRIVER REMARKS")
                            Text(record.inspectionRemarks)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.fmsIndigo)
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }
}

// ── Detail Stat Card (inside TripDetailSheet) ─────────────────────────────────
private struct DetailStatCard: View {
    let icon: String
    let label: String
    let value: String
    let sub: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Active Trip Cell

private struct ActiveTripCell: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Live badge + timer
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                            .shadow(color: .red.opacity(0.5), radius: 3)
                        Text("In Progress")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    Text(vm.elapsedFormatted)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
                Spacer()
                // Fuel pill
                Label(String(format: "%.0f%%", vm.fuelLevel * 100), systemImage: "fuelpump.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(vm.fuelLevel < 0.25 ? .red : Color.fmsIndigo)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background((vm.fuelLevel < 0.25 ? Color.red : Color.fmsIndigo).opacity(0.08))
                    .clipShape(Capsule())
            }

            // Route
            if let trip = vm.activeTrip {
                FMSRouteRow(source: trip.source, destination: trip.destination)
            }

            Divider()

            // 2 × 2 action grid — all in-trip actions, no clutter
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TripActionButton(
                        label: "Navigate",
                        icon: "location.fill",
                        style: .primary
                    ) { vm.mapActiveTrip = vm.activeTrip; vm.showMaps = true }

                    TripActionButton(
                        label: "Voice Log",
                        icon: "mic.fill",
                        style: .glass
                    ) { vm.showVoiceLog = true }
                }
                HStack(spacing: 10) {
                    TripActionButton(
                        label: "Report Issue",
                        icon: "exclamationmark.bubble.fill",
                        style: .warning
                    ) { vm.showIssue = true }

                    TripActionButton(
                        label: "End Trip",
                        icon: "stop.fill",
                        style: .destructive
                    ) {
                        vm.showPostTripOnEnd = true
                        vm.showPostTrip = true
                    }
                }
            }
        }
    }
}

// MARK: - Trip Row (each assigned trip)

private struct TripRow: View {
    let trip: DBTrip
    let index: Int
    @ObservedObject var vm: DriverDashboardViewModel

    private var statusColor: Color {
        switch trip.status {
        case .assigned:  return Color.fmsIndigo
        case .started:   return AppTheme.Status.success
        case .completed: return Color(UIColor.systemGray)
        case .cancelled: return AppTheme.Status.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ───────────────────────────────────────────────────
            HStack(spacing: 10) {
                // Index badge
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.fmsIndigo)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(trip.destination)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Text(trip.source)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(trip.status.rawValue.capitalized)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor.opacity(0.10))
                    .clipShape(Capsule())
            }

            // ── Route visual ─────────────────────────────────────────────
            FMSRouteRow(source: trip.source, destination: trip.destination)

            // ── Meta chips ────────────────────────────────────────────────
            HStack(spacing: 8) {
                TripChip(icon: "arrow.left.arrow.right",
                         label: String(format: "%.0f km", trip.distance))
                if let s = trip.startTime {
                    TripChip(icon: "clock",
                             label: s.formatted(.dateTime.hour().minute()))
                }
                if trip.notes != nil {
                    TripChip(icon: "exclamationmark", label: "Priority")
                }
            }

            Divider()

            // ── Primary CTAs ──────────────────────────────────────────────
            HStack(spacing: 10) {
                // Pre-trip inspect
                Button { vm.showPreTrip = true } label: {
                    Label("Inspect", systemImage: "checklist")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fmsIndigo)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .glassEffect(
                            .regular.tint(Color.fmsIndigo.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }

                // Start / Navigate
                Button {
                    vm.mapActiveTrip = trip
                } label: {
                    Label(
                        (vm.isTripActive && vm.activeTrip?.id == trip.id) ? "Navigate" : "Start",
                        systemImage: (vm.isTripActive && vm.activeTrip?.id == trip.id) ? "location.fill" : "play.fill"
                    )
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.fmsIndigo.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // ── Hint: swipe for more ───────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "hand.point.left")
                    .font(.system(size: 10))
                Text("Swipe for quick actions  ·  Hold for more options")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Trip Chip (meta info pill)

private struct TripChip: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(Capsule())
    }
}

// MARK: - Trip Action Button (used in active trip 2×2 grid)

private enum TripActionStyle { case primary, glass, warning, destructive }

private struct TripActionButton: View {
    let label: String
    let icon: String
    let style: TripActionStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(backgroundContent)
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:     return .white
        case .glass:       return Color.fmsIndigo
        case .warning:     return AppTheme.Brand.accent
        case .destructive: return .white
        }
    }

    private var backgroundContent: some ShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(AppTheme.Brand.primaryDeep.gradient)
        case .glass:
            return AnyShapeStyle(AppTheme.Brand.primaryDeep.opacity(0.08))
        case .warning:
            return AnyShapeStyle(AppTheme.Brand.accent.opacity(0.10))
        case .destructive:
            return AnyShapeStyle(Color.red.gradient)
        }
    }
}

// MARK: - Trip Navigation View (Apple Maps)

@available(iOS 26.0, *)
struct TripNavigationView: View {
    let trip: DBTrip
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sourceItem: MKMapItem?
    @State private var destItem: MKMapItem?
    @State private var route: MKRoute?
    @State private var alternateRoutes: [MKRoute] = []
    @State private var geocoding = true
    @State private var cameraPos = MapCameraPosition.automatic

    // Pre-trip gate
    @State private var showPreTripNav = false
    @State private var preTripPassed  = false

    // Reroute & turn-by-turn
    @State private var showRerouteBanner = false
    @State private var bestAlternate: MKRoute?
    @State private var timeSavedMin = 0
    @State private var showTurnByTurn = false
    @State private var rerouteDismissed = false

    // Already active trip doesn't need pre-trip again
    private var isActiveTrip: Bool { vm.isTripActive && vm.activeTrip?.id == trip.id }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                // ── Map ────────────────────────────────────────────────────
                Map(position: $cameraPos) {
                    if let s = sourceItem?.placemark.coordinate {
                        Annotation("Origin", coordinate: s, anchor: .bottom) {
                            mapPin(icon: "car.fill", color: Color.fmsIndigo)
                        }
                    }
                    if let d = destItem?.placemark.coordinate {
                        Annotation("Destination", coordinate: d, anchor: .bottom) {
                            mapPin(icon: "flag.fill", color: AppTheme.Status.success)
                        }
                    }
                    // Alternate routes (faded gray)
                    ForEach(alternateRoutes, id: \.name) { alt in
                        MapPolyline(alt.polyline)
                            .stroke(
                                Color.gray.opacity(0.35),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [8, 6])
                            )
                    }
                    // Primary route (bold blue)
                    if let r = route {
                        MapPolyline(r.polyline)
                            .stroke(
                                Color.fmsIndigo,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: true))
                .ignoresSafeArea(edges: .top)

                // Loading pill
                if geocoding {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color.fmsIndigo)
                        Text("Calculating route…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glassEffect(.regular, in: Capsule())
                    .padding(.bottom, 300)
                }

                // ── Bottom drawer ─────────────────────────────────────────
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(Color(UIColor.systemGray4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    // Destination info
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            if let r = route {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(String(format: "%d min", Int(r.expectedTravelTime / 60)))
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundStyle(AppTheme.Status.success)
                                    Text(String(format: "%.1f km", r.distance / 1000))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(isActiveTrip ? "Navigating to: \(trip.destination)" : "Planned: \(trip.destination)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button { openInAppleMaps() } label: {
                            Label("Maps", systemImage: "map.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.fmsIndigo)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .glassEffect(.regular.tint(Color.fmsIndigo.opacity(0.08)), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 20)

                    // Stats strip
                    HStack(spacing: 0) {
                        TripMetaCell(icon: "arrow.left.arrow.right",
                                     value: String(format: "%.1f km", trip.distance), label: "Distance")
                        TripMetaCell(icon: "clock",
                                     value: vm.elapsedFormatted, label: "Elapsed")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    // ── Reroute banner ─────────────────────────────────────
                    if showRerouteBanner && !rerouteDismissed {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.Status.success.gradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Faster Route Available")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppTheme.Status.success)
                                Text("Save ~\(timeSavedMin) min via alternate route")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.4)) {
                                    if let alt = bestAlternate {
                                        alternateRoutes.append(route!)
                                        route = alt
                                        bestAlternate = nil
                                        showRerouteBanner = false
                                    }
                                }
                            } label: {
                                Text("Reroute")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(AppTheme.Status.success.gradient)
                                    .clipShape(Capsule())
                            }

                            Button {
                                withAnimation { rerouteDismissed = true }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(6)
                                    .background(Color(UIColor.tertiarySystemFill))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Turn-by-turn steps ─────────────────────────────────
                    if let steps = route?.steps, steps.count > 1 {
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.35)) {
                                    showTurnByTurn.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.fmsIndigo)
                                    Text("Turn-by-Turn · \(steps.count - 1) steps")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.fmsIndigo)
                                    Spacer()
                                    Image(systemName: showTurnByTurn ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if showTurnByTurn {
                                Divider().padding(.leading, 16)
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        let stepsArr = Array(steps.dropFirst())
                                        ForEach(Array(stepsArr.enumerated()), id: \.offset) { idx, step in
                                            TurnStepRow(
                                                index: idx,
                                                instruction: step.instructions,
                                                distance: step.distance,
                                                isFirst: idx == 0,
                                                isLast: idx == stepsArr.count - 1,
                                                iconName: turnIcon(for: step.instructions)
                                            )
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }

                    Divider().padding(.horizontal, 20).padding(.top, 4)

                    // ── Action row ─────────────────────────────────────────
                    if isActiveTrip {
                        // ── In-trip: 4 live actions ───────────────────────
                        HStack(spacing: 10) {
                            MapActionButton(label: "Voice Log",    icon: "mic.fill",                   style: .glass)     { vm.showVoiceLog = true }
                            MapActionButton(label: "Defect",       icon: "wrench.and.screwdriver.fill", style: .warning)   { vm.showDefect   = true }
                            MapActionButton(label: "SOS",          icon: "sos",                         style: .destructive) { vm.showSOSCountdown = true }
                            MapActionButton(label: "End Trip",     icon: "stop.fill",                   style: .destructive) {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    vm.showPostTripOnEnd = true
                                    vm.showPostTrip = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    } else {
                        // ── Pre-start: inspection gate + Start Now ────────
                        VStack(spacing: 14) {

                            // Quick action buttons row
                            HStack(spacing: 10) {
                                // Pre-Trip — shows green tick when passed
                                MapActionButton(
                                    label: preTripPassed ? "Passed ✓" : "Pre-Trip",
                                    icon:  preTripPassed ? "checkmark.seal.fill" : "checklist",
                                    style: preTripPassed ? .primary : .glass
                                ) { showPreTripNav = true }

                                MapActionButton(label: "Defect",    icon: "wrench.and.screwdriver.fill", style: .warning) { vm.showDefect   = true }
                                MapActionButton(label: "Voice Log", icon: "mic.fill",                   style: .glass)   { vm.showVoiceLog = true }
                                MapActionButton(label: "SOS",       icon: "sos",                        style: .destructive) { vm.showSOSCountdown = true }
                            }

                            // Inspection warning banner (shown until passed)
                            if !preTripPassed {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.Brand.accent)
                                    Text("Complete Pre-Trip Inspection before starting")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppTheme.Brand.accent)
                                    Spacer()
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Brand.accent.opacity(0.10))
                                )
                            }

                            // Start Now — locked until inspection passes
                            Button {
                                guard preTripPassed else { showPreTripNav = true; return }
                                vm.beginTrip(trip: trip)
                            } label: {
                                HStack(spacing: 8) {
                                    if !preTripPassed {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    Text(preTripPassed ? "Start Now" : "Complete Inspection to Start")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    preTripPassed
                                        ? AnyShapeStyle(Color.fmsIndigo.gradient)
                                        : AnyShapeStyle(Color(UIColor.systemGray3).gradient)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                    }
                }
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 22
                    )
                    .fill(.regularMaterial)
                )
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: -4)
            }
            .navigationTitle("Navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .glassEffect(.regular, in: Capsule())
                }
            }
            // ── Pre-Trip sheet (auto-opened + can re-open via button) ────
            .sheet(isPresented: $showPreTripNav) {
                InspectionFormSheet(isPreTrip: true) { passed, _, _ in
                    preTripPassed = passed
                }
            }
        }
        // ── SOS Countdown Overlay (over map) ─────────────────────────
        .overlay {
            if vm.showSOSCountdown {
                SOSCountdownOverlay(isPresented: $vm.showSOSCountdown) {
                    vm.sosSentAlert = true
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .alert("🚨 SOS Triggered", isPresented: $vm.sosSentAlert) {
            Button("OK") {}
        } message: {
            Text("Emergency alert has been sent to your fleet manager. Help is on the way.")
        }
        .task { await geocodeAndRoute() }
        .onAppear {
            // Auto-open pre-trip only when this is a new (not yet started) trip
            if !isActiveTrip {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showPreTripNav = true
                }
            }
        }
    }


    // ── Map pin helper ─────────────────────────────────────────────────────
    private func mapPin(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 44, height: 44)
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .shadow(color: color.opacity(0.4), radius: 6)
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // ── Geocode + route ────────────────────────────────────────────────────
    @MainActor
    private func geocodeAndRoute() async {
        async let source = mapItem(for: trip.source)
        async let destination = mapItem(for: trip.destination)

        sourceItem = await source
        destItem = await destination

        if let sourceItem, let destItem {
            let req = MKDirections.Request()
            req.source = sourceItem
            req.destination = destItem
            req.transportType = .automobile
            req.requestsAlternateRoutes = true  // Request traffic-aware alternates

            if let result = try? await MKDirections(request: req).calculate() {
                let allRoutes = result.routes
                route = allRoutes.first

                // Check for faster alternates
                if allRoutes.count > 1, let primary = route {
                    let alts = Array(allRoutes.dropFirst())
                    alternateRoutes = alts

                    // Find best alternate that saves meaningful time (≥ 2 min)
                    if let fastest = alts.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }),
                       fastest.expectedTravelTime < primary.expectedTravelTime - 120 {
                        bestAlternate = fastest
                        timeSavedMin = Int((primary.expectedTravelTime - fastest.expectedTravelTime) / 60)
                        withAnimation(.spring(response: 0.5).delay(1.5)) {
                            showRerouteBanner = true
                        }
                    }
                }

                if let r = route {
                    let rect = r.polyline.boundingMapRect
                    cameraPos = .rect(rect.insetBy(dx: -rect.size.width * 0.18, dy: -rect.size.height * 0.18))
                }
            }
        } else {
            cameraPos = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 28.61, longitude: 77.21),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            ))
        }
        geocoding = false
    }

    private func mapItem(for address: String) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        let response = try? await search.start()
        return response?.mapItems.first
    }

    private func openInAppleMaps() {
        guard let item = destItem else { return }
        item.name = trip.destination
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // ── Turn icon helper ──────────────────────────────────────────────────
    private func turnIcon(for instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("left")  { return "arrow.turn.up.left" }
        if lower.contains("right") { return "arrow.turn.up.right" }
        if lower.contains("u-turn") || lower.contains("u turn") { return "arrow.uturn.left" }
        if lower.contains("merge") { return "arrow.merge" }
        if lower.contains("ramp") || lower.contains("exit") { return "arrow.up.right" }
        if lower.contains("roundabout") || lower.contains("circle") { return "arrow.triangle.capsulepath" }
        if lower.contains("arrive") || lower.contains("destination") { return "mappin.circle.fill" }
        if lower.contains("straight") || lower.contains("continue") { return "arrow.up" }
        return "arrow.up"
    }
}

// MARK: - Map Action Button (compact, used in Maps drawer)

private enum MapActionStyle { case primary, glass, warning, destructive }

private struct MapActionButton: View {
    let label: String
    let icon: String
    let style: MapActionStyle
    let action: () -> Void

    private var color: Color {
        switch style {
        case .primary:     return Color.fmsIndigo
        case .glass:       return Color.fmsIndigo
        case .warning:     return AppTheme.Brand.accent
        case .destructive: return .red
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle((style == .primary || style == .destructive) ? .white : color)
                    .frame(width: 46, height: 46)
                    .background(
                        (style == .primary || style == .destructive)
                        ? AnyShapeStyle(color.gradient)
                        : AnyShapeStyle(color.opacity(0.10))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Turn Step Row (extracted for compiler performance)

private struct TurnStepRow: View {
    let index: Int
    let instruction: String
    let distance: CLLocationDistance
    let isFirst: Bool
    let isLast: Bool
    let iconName: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Step number badge
                ZStack {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 28, height: 28)
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(badgeTextColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(instruction)
                        .font(.system(size: 13, weight: isFirst ? .semibold : .regular))
                        .foregroundStyle(isFirst ? Color.primary : Color.secondary)
                    if distance > 0 {
                        Text(String(format: "%.1f km", distance / 1000))
                            .font(.system(size: 11))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                    }
                }
                Spacer()
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(isFirst ? Color.fmsIndigo : Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if !isLast {
                Divider().padding(.leading, 56)
            }
        }
    }

    private var badgeColor: Color {
        isFirst ? Color.fmsIndigo : Color(UIColor.tertiarySystemFill)
    }

    private var badgeTextColor: Color {
        isFirst ? .white : .secondary
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Trips Tab") {
    DriverTripsTab(vm: DriverDashboardViewModel())
}
