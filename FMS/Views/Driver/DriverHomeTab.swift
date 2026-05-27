







import SwiftUI



@available(iOS 26.0, *)
struct DriverHomeTab: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Binding var selectedTab: Int

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

                        PrimaryCard(vm: vm)
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
                            .fill(Color.red)
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

    var body: some View {
        if vm.isTripActive {
            LiveTripCard(vm: vm)
        } else {
            IdleCard(vm: vm)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let trip = vm.activeTrip {
                
                HStack {
                    Text("TRIP-\(trip.id.uuidString.prefix(5).uppercased())")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("IN PROGRESS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.10))
                        .cornerRadius(6)
                }

                Divider()

                
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 4) {
                        Circle()
                            .stroke(Color.fmsIndigo, lineWidth: 3)
                            .frame(width: 14, height: 14)
                        
                        VerticalDashedLine()
                            .frame(height: 24)
                        
                        Circle()
                            .stroke(Color.orange, lineWidth: 3)
                            .frame(width: 14, height: 14)
                    }
                    .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DEPARTURE PORT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(trip.source)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ARRIVAL TERMINAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text(trip.destination)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Divider()

                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DISTANCE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f km", trip.distance))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARGO SPEC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(trip.notes ?? "General Cargo")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                
                Divider()

                
                VStack(alignment: .center, spacing: 12) {
                    Text(vm.elapsedFormatted)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    HStack(spacing: 10) {
                        Button {
                            vm.mapActiveTrip = vm.activeTrip
                            vm.showMaps = true
                        } label: {
                            Label("Navigate", systemImage: "location.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.fmsIndigo)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.fmsIndigo.opacity(0.10))
                                .cornerRadius(12)
                        }

                        Button {
                            vm.showPostTripOnEnd = true
                            vm.showPostTrip = true
                        } label: {
                            Label("End Trip", systemImage: "stop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.red.gradient)
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

    var body: some View {
        if let trip = vm.upcomingTrips.first {
            AssignedTripCard(trip: trip, vm: vm)
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

    private var tripCode: String {
        "TRIP-\(trip.id.uuidString.prefix(8).uppercased())"
    }

    /// Exact ETA: distance (km) ÷ 60 km/h average speed
    private var etaString: String {
        let hours = trip.distance / 60.0
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }

    /// Arrival time = departure time + ETA duration
    private var arrivalTimeString: String {
        let departure = trip.startTime ?? trip.createdAt
        let travelSeconds = (trip.distance / 60.0) * 3600
        let arrival = departure.addingTimeInterval(travelSeconds)
        let f = DateFormatter(); f.dateFormat = "hh:mm a"
        return f.string(from: arrival)
    }

    private var departureTimeString: String {
        let f = DateFormatter(); f.dateFormat = "MMM d · hh:mm a"
        return f.string(from: trip.startTime ?? trip.createdAt)
    }

    private var pickupTimeString: String {
        let f = DateFormatter(); f.dateFormat = "hh:mm a"
        return f.string(from: trip.startTime ?? trip.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Row 1: Trip ID + ASSIGNED badge ──────────────────────────────
            HStack(spacing: 8) {
                Text(tripCode)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("ASSIGNED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.fmsIndigo)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.fmsIndigo.opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // ── Row 2: Route — full width, no map ────────────────────────────
            VStack(spacing: 0) {
                // Departure row
                HStack(alignment: .center, spacing: 14) {
                    // Blue dot
                    ZStack {
                        Circle()
                            .fill(Color.fmsIndigo)
                            .frame(width: 36, height: 36)
                        Image(systemName: "location.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("DEPARTURE")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.fmsIndigo)
                            .tracking(0.5)
                        Text(trip.source)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text(departureTimeString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Dashed connector line
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 36)
                    VStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(Color(UIColor.systemGray4))
                                .frame(width: 2, height: 5)
                                .padding(.vertical, 2)
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 14)
                .padding(.vertical, 2)

                // Arrival row
                HStack(alignment: .center, spacing: 14) {
                    // Orange dot
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 36, height: 36)
                        Image(systemName: "mappin.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ARRIVAL")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.orange)
                            .tracking(0.5)
                        Text(trip.destination)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("ETA \(arrivalTimeString)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            // ── Row 3: 3 Metric Chips (Distance · ETA · Pickup) ──────────────
            HStack(spacing: 0) {
                TripMetricChip(
                    icon: "road.lanes",
                    label: "DISTANCE",
                    value: String(format: "%.0f km", trip.distance)
                )
                TripChipDivider()
                TripMetricChip(
                    icon: "clock",
                    label: "ETA",
                    value: etaString
                )
                TripChipDivider()
                TripMetricChip(
                    icon: "clock.badge.checkmark",
                    label: "PICKUP TIME",
                    value: pickupTimeString
                )
            }
            .padding(.vertical, 2)

            Divider().padding(.horizontal, 16)

            // ── Row 4: Vehicle + Cargo ────────────────────────────────────────
            HStack(spacing: 0) {
                // Vehicle
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fmsIndigo)
                        Text("VEHICLE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Text(vm.assignedVehicle?.licensePlate ?? "Unassigned")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(vm.assignedVehicle?.model ?? "—")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 48)

                // Cargo
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.orange)
                        Text("CARGO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    Text("General Cargo")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(String(format: "%.0f km route", trip.distance))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            // ── Row 5: Fleet Manager Instructions (always shown if notes exist) ──
            if let notes = trip.notes, !notes.isEmpty {
                Divider().padding(.horizontal, 16)

                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.fmsIndigo.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "person.text.rectangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fmsIndigo)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FLEET MANAGER INSTRUCTIONS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.fmsIndigo)
                            .tracking(0.4)
                        Text(notes)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(Color.fmsIndigo.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.vertical, 10)
            }

            Divider().padding(.horizontal, 16)

            // ── Row 6: Message button ─────────────────────────────────────────
            Button {
                vm.showMessaging = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Message Fleet Manager")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.fmsIndigo)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.fmsIndigo.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.fmsIndigo.opacity(0.20), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16).padding(.top, 12)

            // ── Row 7: Start Active Trip ──────────────────────────────────────
            Button {
                vm.mapActiveTrip = trip
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start Active Trip")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.fmsIndigo, Color.fmsIndigo.opacity(0.82)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.fmsIndigo.opacity(0.30), radius: 8, y: 3)
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
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
