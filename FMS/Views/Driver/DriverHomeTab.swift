

import SwiftUI
struct DriverHomeTab: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Binding var selectedTab: Int
    @State private var selectedTripForAddress: DBTrip?
    @ObservedObject private var accessibility = AccessibilityManager.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── 1. Inline Header Row ────────────────────────────────────
                    DashboardInlineHeader(vm: vm)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("ACTIVE ASSIGNED TRIP")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                            Spacer()
                            Button {
                                withAnimation {
                                    selectedTab = 1
                                }
                            } label: {
                                Text("See All")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.fmsIndigo)
                            }
                        }

                        PrimaryCard(vm: vm, selectedTripForAddress: $selectedTripForAddress)
                    }
                    .padding(.horizontal, 20)

                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUICK ACTIONS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        HStack(spacing: 12) {
                            QuickActionGridCell(
                                title: "Emergency SOS",
                                icon: "exclamationmark.shield.fill",
                                iconColor: AppTheme.Status.danger,
                                action: { vm.showSOSCountdown = true }
                            )
                            QuickActionGridCell(
                                title: "Chat",
                                icon: "bubble.left.and.bubble.right.fill",
                                iconColor: Color.fmsIndigo,
                                action: { vm.showMessaging = true }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    
                    // ── FUEL SECTION ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FUEL")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        FuelSectionCard(vm: vm)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // ── DRIVER PERFORMANCE ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DRIVER PERFORMANCE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        HStack(spacing: 12) {
                            PerformanceCard(
                                title: "Total Trips",
                                value: "\(vm.completedTrips.count) Runs",
                                subtitle: "Completed runs",
                                icon: "road.lanes",
                                iconColor: Color.fmsIndigo
                            )
                            PerformanceCard(
                                title: "Time Logged",
                                value: "\(vm.completedTrips.reduce(0) { $0 + $1.elapsedSeconds } / 3600) hrs",
                                subtitle: "Within standard limits",
                                icon: "clock.fill",
                                iconColor: AppTheme.Brand.amber
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    Spacer(minLength: 100)
                }
            }
            .refreshable { await vm.load() }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedTripForAddress) { trip in
                FullAddressSheet(source: trip.source, destination: trip.destination, tripCode: trip.tripCode)
            }
        }
    }
}



private struct DashboardInlineHeader: View {
    @ObservedObject var vm: DriverDashboardViewModel

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good Morning,"
        case 12..<17: return "Good Afternoon,"
        default:      return "Good Evening,"
        }
    }

    private var initials: String {
        let parts = vm.driverName.components(separatedBy: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(vm.driverName.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // ── Two-line greeting on the left ────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(vm.driverName.components(separatedBy: " ").first ?? vm.driverName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()


            // ── Bell button ────────────────────────────────────────
            Button {
                vm.showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(UIColor.label))
                        .frame(width: 40, height: 40)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())

                    let unread = vm.notificationsList.filter { !$0.isRead }.count
                    if unread > 0 {
                        Circle()
                            .fill(AppTheme.Status.danger)
                            .frame(width: 10, height: 10)
                            .offset(x: 1, y: 1)
                    }
                }
            }
            .buttonStyle(.plain)

            // ── Gap between bell and avatar ───────────────────────────
            Spacer().frame(width: 12)

            // ── Driver initials avatar ──────────────────────────────
            Button {
                vm.showProfile = true
            } label: {
                Text(initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.fmsIndigo)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}


// MARK: - 2. Primary Card (Trip details)

private struct PrimaryCard: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Binding var selectedTripForAddress: DBTrip?

    var body: some View {
        if vm.isTripActive {
            LiveTripCard(vm: vm, selectedTripForAddress: $selectedTripForAddress)
        } else {
            IdleCard(vm: vm, selectedTripForAddress: $selectedTripForAddress)
        }
    }
}


private struct VerticalDashedLine: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<6) { _ in
                Circle()
                    .fill(Color(UIColor.systemGray4))
                    .frame(width: 2, height: 2)
            }
        }
    }
}


private struct LiveTripCard: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Binding var selectedTripForAddress: DBTrip?
    @ObservedObject private var accessibility = AccessibilityManager.shared

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func departureTime(for trip: DBTrip) -> String {
        formatTime(trip.startTime ?? trip.createdAt)
    }

    private func arrivalTime(for trip: DBTrip) -> String {
        let dep = trip.startTime ?? trip.createdAt
        let arrival = dep.addingTimeInterval((trip.distance / 60.0) * 3600)
        return formatTime(arrival)
    }

    private func etaString(for trip: DBTrip) -> String {
        let hours = trip.distance / 60.0
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let trip = vm.activeTrip {
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trip.tripCode)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("IN PROGRESS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Status.danger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.Status.danger.opacity(0.10))
                            .cornerRadius(6)
                    }
                    if let notes = trip.notes, !notes.isEmpty {
                        HStack {
                            Image(systemName: "box.truck.fill")
                                .font(.system(size: 10))
                            Text(notes)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.Status.danger)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppTheme.Status.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                Divider()

                
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Circle()
                            .stroke(Color.fmsIndigo, lineWidth: 3)
                            .frame(width: 14, height: 14)
                        
                        Rectangle()
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: 2)
                            .frame(minHeight: 24)
                        
                        Circle()
                            .stroke(Color.orange, lineWidth: 3)
                            .frame(width: 14, height: 14)
                    }
                    .padding(.vertical, 4)
                    .frame(width: 14)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DEPARTURE PORT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(trip.source)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ARRIVAL TERMINAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(trip.destination)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()

                HStack {
                    Button {
                        selectedTripForAddress = trip
                    } label: {
                        Label("View Full Address", systemImage: "map.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.fmsIndigo)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                
                Divider()
                
                HStack(spacing: 0) {
                    TripMetricChip(
                        icon: "road.lanes",
                        label: "DISTANCE",
                        value: String(format: "%.1f km", trip.distance)
                    )
                    TripChipDivider()
                    TripMetricChip(
                        icon: "arrow.up.circle.fill",
                        label: "DEPARTURE",
                        value: departureTime(for: trip)
                    )
                    TripChipDivider()
                    TripMetricChip(
                        icon: "arrow.down.circle.fill",
                        label: "EST. ARRIVAL",
                        value: arrivalTime(for: trip)
                    )
                    TripChipDivider()
                    TripMetricChip(
                        icon: "clock.fill",
                        label: "LIVE ETA",
                        value: etaString(for: trip)
                    )
                }
                
                Divider()

                
                VStack(alignment: .center, spacing: 12) {
                    Text(vm.elapsedFormatted)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    VStack(spacing: 10) {
                        let largeTap = accessibility.driverLargeTapTargets
                        let btnHeight: CGFloat = largeTap ? 64 : 48
                        let btnFontSize: CGFloat = largeTap ? 17 : 14
                        
                        HStack(spacing: 10) {
                            Button {
                                vm.mapActiveTrip = vm.activeTrip
                                vm.showMaps = true
                            } label: {
                                Label("Navigate", systemImage: "location.fill")
                                    .font(.system(size: btnFontSize, weight: .bold))
                                    .foregroundStyle(Color.fmsIndigo)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: btnHeight)
                                    .background(Color.fmsIndigo.opacity(0.10))
                                    .cornerRadius(12)
                            }

                            Button {
                                vm.showVoiceLog = true
                            } label: {
                                Label("Voice Log", systemImage: "mic.fill")
                                    .font(.system(size: btnFontSize, weight: .bold))
                                    .foregroundStyle(Color.fmsIndigo)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: btnHeight)
                                    .background(Color.fmsIndigo.opacity(0.10))
                                    .cornerRadius(12)
                            }
                        }

                        Button {
                            Task {
                                await vm.requestEndTrip()
                            }
                        } label: {
                            Label("End Trip", systemImage: "stop.fill")
                                .font(.system(size: btnFontSize, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: btnHeight)
                                .background(AppTheme.Brand.accent.gradient)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}


private struct IdleCard: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Binding var selectedTripForAddress: DBTrip?

    var body: some View {
        if let trip = vm.upcomingTrips.first {
            AssignedTripCard(trip: trip, vm: vm, selectedTripForAddress: $selectedTripForAddress)
        } else {
            // ── Empty state ────────────────────────────────────────────────
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fmsIndigo.opacity(0.3))
                Text("No trips assigned today")
                    .font(.system(size: 16, weight: .bold))
                Text("Your fleet manager will assign trips here.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
    }
}


private struct AssignedTripCard: View {
    let trip: DBTrip
    @ObservedObject var vm: DriverDashboardViewModel
    @Binding var selectedTripForAddress: DBTrip?

    // ── Computed helpers ─────────────────────────────────────────────────────

    private var tripCode: String {
        trip.tripCode
    }

    /// Exact ETA: distance (km) ÷ 60 km/h
    private var etaString: String {
        let hours = trip.distance / 60.0
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    /// Computed arrival = startTime + travel duration (with date)
    private var arrivalTimeString: String {
        let dep = trip.startTime ?? trip.createdAt
        let arrival = dep.addingTimeInterval((trip.distance / 60.0) * 3600)
        let f = DateFormatter(); f.dateFormat = "MMM d, hh:mm a"
        return f.string(from: arrival)
    }

    private var departureTimeString: String {
        let f = DateFormatter(); f.dateFormat = "MMM d, hh:mm a"
        return f.string(from: trip.startTime ?? trip.createdAt)
    }

    private var pickupTimeString: String {
        let f = DateFormatter(); f.dateFormat = "hh:mm a"
        return f.string(from: trip.startTime ?? trip.createdAt)
    }

    // ── State for collapsible vehicle details ─────────────────────────────────
    @State private var showVehicleDetails = false
    @State private var isAccepted = false

    /// The actual vehicle assigned to this specific trip
    private var tripVehicle: DBVehicle? {
        vm.vehicleForTrip(trip)
    }

    /// Full local Vehicle model with vehicleType, fuelType, insuranceExpiryDate
    private var localVehicle: Vehicle? {
        vm.localVehicleForTrip(trip)
    }

    // ── View ─────────────────────────────────────────────────────────────────

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── 1. Header: Trip ID + Cargo Badge + status badge ─────────────────
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(tripCode)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(UIColor.label))
                    Spacer()
                    Text("ASSIGNED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.fmsIndigo)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.fmsIndigo.opacity(0.10))
                        .clipShape(Capsule())
                }
                if let notes = trip.notes, !notes.isEmpty {
                    HStack {
                        Image(systemName: "box.truck.fill")
                            .font(.system(size: 10))
                        Text(notes)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.fmsIndigo)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.fmsIndigo.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18).padding(.bottom, 14)

            Divider()

            // ── 2. Route Track ────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {

                // Left: vertical track with two icons + connector line
                VStack(spacing: 0) {
                    // Departure icon — solid filled circle with arrow
                    Circle()
                        .fill(Color.fmsIndigo)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )

                    // Dynamic vertical connector line
                    Rectangle()
                        .fill(Color(UIColor.systemGray3))
                        .frame(width: 2.5)

                    // Arrival icon — orange filled circle with flag
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "flag.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .padding(.vertical, 8)
                .frame(width: 38)

                // Right: text for both stops
                VStack(alignment: .leading, spacing: 16) {
                    // Departure text block
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEPARTURE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.fmsIndigo)
                            .kerning(0.6)
                        Text(trip.source)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(departureTimeString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }

                    // Arrival text block
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARRIVAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                            .kerning(0.6)
                        Text(trip.destination)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("ETA \(arrivalTimeString)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            HStack {
                Button {
                    selectedTripForAddress = trip
                } label: {
                    Label("View Full Address", systemImage: "map.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fmsIndigo)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            Divider()

            // ── 3. Metrics row: Distance · Departure · Arrival · ETA ───────────
            HStack(spacing: 0) {
                TripMetricChip(
                    icon: "road.lanes",
                    label: "DISTANCE",
                    value: String(format: "%.1f km", trip.distance)
                )
                TripChipDivider()
                TripMetricChip(
                    icon: "arrow.up.circle.fill",
                    label: "DEPARTURE",
                    value: pickupTimeString
                )
                TripChipDivider()
                TripMetricChip(
                    icon: "arrow.down.circle.fill",
                    label: "EST. ARRIVAL",
                    value: arrivalTimeString
                )
                TripChipDivider()
                TripMetricChip(
                    icon: "clock.fill",
                    label: "ETA",
                    value: etaString
                )
            }

            Divider()

            // ── 4. Vehicle (collapsible) ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showVehicleDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("VEHICLE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                            Text(localVehicle?.registrationNumber ?? tripVehicle?.licensePlate ?? "Not Assigned")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(UIColor.label))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                            .rotationEffect(.degrees(showVehicleDetails ? -180 : 0))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if showVehicleDetails {
                    Divider().padding(.horizontal, 20)
                    
                    VStack(spacing: 0) {
                        vehicleDetailRow(label: "Vehicle Type", value: localVehicle?.vehicleType.displayName ?? "—")
                        Divider().padding(.leading, 50)
                        vehicleDetailRow(label: "Fuel Type", value: localVehicle?.fuelType.displayName ?? "—")
                        Divider().padding(.leading, 50)
                        vehicleDetailRow(label: "Make & Model", value: localVehicle.map { "\($0.make) \($0.model)" } ?? tripVehicle.map { "\($0.manufacturer) \($0.model)" } ?? "—")
                        Divider().padding(.leading, 50)
                        vehicleDetailRow(label: "Year", value: localVehicle.map { String($0.year) } ?? tripVehicle.map { String($0.year) } ?? "—")
                        Divider().padding(.leading, 50)
                        vehicleDetailRow(label: "License Plate", value: localVehicle?.registrationNumber ?? tripVehicle?.licensePlate ?? "—")
                        Divider().padding(.leading, 50)
                        vehicleDetailRow(label: "VIN", value: localVehicle?.vinNumber ?? tripVehicle?.vin ?? "—")
                        Divider().padding(.leading, 50)
                        vehicleDetailRow(label: "Insurance Expiry", value: localVehicle?.insuranceExpiryDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // ── 5. Fleet Manager Instructions (if present) ────────────────
            if let notes = trip.notes, !notes.isEmpty {
                Divider()

                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.fmsIndigo.opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "text.quote")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.fmsIndigo)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FLEET MANAGER INSTRUCTIONS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.fmsIndigo)
                            .kerning(0.4)
                        Text(notes)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(Color.fmsIndigo.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            Divider()

            // ── 6. Actions: Raise Query & Confirm Trip adjacent ──────────────
            HStack(spacing: 12) {
                // Raise a Query
                Button {
                    vm.queryTrip = trip
                    vm.showRaiseQuery = true
                } label: {
                    Label("Raise Query", systemImage: "questionmark.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.orange.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                }

                // Confirm CTA / Start Trip
                Button {
                    if !isAccepted {
                        withAnimation(.spring(response: 0.4)) { isAccepted = true }
                    } else {
                        vm.showRaiseQuery = false
                        vm.queryTrip = nil
                        vm.mapActiveTrip = trip
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isAccepted ? "play.fill" : "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(isAccepted ? "Start Trip" : "Confirm Trip")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        isAccepted ?
                        LinearGradient(
                            colors: [AppTheme.Brand.primary, AppTheme.Brand.primary.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [AppTheme.Brand.primary, AppTheme.Brand.primary.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: isAccepted ? AppTheme.Status.success.opacity(0.3) : AppTheme.Brand.primary.opacity(0.28), radius: 10, y: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 18, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
        )
    }

    /// Helper row for the collapsible vehicle details section
    private func vehicleDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(UIColor.secondaryLabel))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(UIColor.label))
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Trip Metric Chip

private struct TripMetricChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(UIColor.systemGray2))
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.3)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct TripChipDivider: View {
    var body: some View {
        Divider().frame(height: 36)
    }
}





private struct QuickActionGridCell: View {
    let title: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}



private struct PerformanceCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(iconColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}



@available(iOS 26.0, *)
#Preview("Home Tab") {
    DriverHomeTab(vm: DriverDashboardViewModel(), selectedTab: .constant(0))
}
