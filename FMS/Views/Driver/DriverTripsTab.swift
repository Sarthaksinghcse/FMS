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

    var body: some View {
        NavigationStack {
            List {

                // ── Active trip section (only when running) ──────────────
                if vm.isTripActive {
                    Section {
                        ActiveTripCell(vm: vm)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }
                }

                // ── Upcoming trips ───────────────────────────────────────
                Section {
                    if vm.upcomingTrips.isEmpty {
                        EmptyTripsCell()
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(vm.upcomingTrips.enumerated()), id: \.offset) { i, trip in
                            TripRow(trip: trip, index: i, vm: vm)
                                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                                // ── Swipe actions ───────────────────────
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
                                // ── Long-press context menu ──────────────
                                .contextMenu {
                                    Button {
                                        vm.mapActiveTrip = trip
                                    } label: {
                                        Label("Start Trip", systemImage: "play.fill")
                                    }
                                    Button { vm.showPreTrip   = true } label: { Label("Pre-Trip Inspection",  systemImage: "checklist") }
                                    Button { vm.showPostTrip  = true } label: { Label("Post-Trip Inspection", systemImage: "checkmark.seal.fill") }
                                    Divider()
                                    Button { vm.showVoiceLog  = true } label: { Label("Voice Log",    systemImage: "mic.fill") }
                                    Button { vm.showIssue     = true } label: { Label("Report Issue", systemImage: "exclamationmark.bubble.fill") }
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
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.large)
            // ── Toolbar: secondary actions in a menu ─────────────────────
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { vm.showVoiceLog  = true } label: { Label("Voice Log",        systemImage: "mic.fill") }
                        Button { vm.showMessaging = true } label: { Label("Messages",          systemImage: "message.fill") }
                        Divider()
                        Button { vm.showPreTrip   = true } label: { Label("Pre-Trip Inspect",  systemImage: "checklist") }
                        Button { vm.showPostTrip  = true } label: { Label("Post-Trip Inspect", systemImage: "checkmark.seal.fill") }
                        Divider()
                        Button { vm.showIssue     = true } label: { Label("Report Issue",  systemImage: "exclamationmark.bubble.fill") }
                        Button(role: .destructive) { vm.showDefect = true } label: {
                            Label("Report Defect", systemImage: "wrench.and.screwdriver.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.fmsIndigo)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State Cell

private struct EmptyTripsCell: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 40, weight: .thin))
                .foregroundStyle(Color.fmsIndigo.opacity(0.30))
            Text("No trips assigned")
                .font(.system(size: 16, weight: .medium))
            Text("Your fleet manager will assign routes here.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
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
                    ) { vm.confirmEnd = true }
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
    @State private var geocoding = true
    @State private var cameraPos = MapCameraPosition.automatic

    // Pre-trip gate
    @State private var showPreTripNav = false
    @State private var preTripPassed  = false

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
                    if let r = route {
                        MapPolyline(r.polyline)
                            .stroke(
                                Color.fmsIndigo,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
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
                            Text(isActiveTrip ? "Navigating to" : "Planned route to")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(trip.destination)
                                .font(.system(size: 18, weight: .bold))
                                .lineLimit(1)
                            if let r = route {
                                Text(String(format: "%.1f km  ·  ~%d min",
                                            r.distance / 1000,
                                            Int(r.expectedTravelTime / 60)))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.fmsIndigo)
                            }
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
                        TripMetaCell(icon: "fuelpump.fill",
                                     value: String(format: "%.0f%%", vm.fuelLevel * 100), label: "Fuel")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    Divider().padding(.horizontal, 20).padding(.top, 4)

                    // ── Action row ─────────────────────────────────────────
                    if isActiveTrip {
                        // ── In-trip: 4 live actions ───────────────────────
                        HStack(spacing: 10) {
                            MapActionButton(label: "Voice Log",    icon: "mic.fill",                   style: .glass)     { vm.showVoiceLog = true }
                            MapActionButton(label: "Report",       icon: "exclamationmark.bubble.fill", style: .warning)   { vm.showIssue    = true }
                            MapActionButton(label: "Defect",       icon: "wrench.and.screwdriver.fill", style: .warning)   { vm.showDefect   = true }
                            MapActionButton(label: "End Trip",     icon: "stop.fill",                   style: .destructive) {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { vm.confirmEnd = true }
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
                InspectionFormSheet(isPreTrip: true) { passed in
                    preTripPassed = passed
                }
            }
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
            route = try? await MKDirections(request: req).calculate().routes.first
            if let r = route {
                let rect = r.polyline.boundingMapRect
                cameraPos = .rect(rect.insetBy(dx: -rect.size.width * 0.18, dy: -rect.size.height * 0.18))
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

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Trips Tab") {
    DriverTripsTab(vm: DriverDashboardViewModel())
}
