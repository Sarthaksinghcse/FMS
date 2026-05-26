







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
                                value: "48 Runs",
                                subtitle: "Completed runs",
                                icon: "road.lanes",
                                iconColor: Color.fmsIndigo
                            )
                            PerformanceCard(
                                title: "Time Logged",
                                value: "112 hrs",
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
                Text(vm.driverName)
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
        VStack(alignment: .leading, spacing: 16) {
            if let trip = vm.upcomingTrips.first {
                
                HStack {
                    Text("TRIP-\(trip.id.uuidString.prefix(5).uppercased())")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("ASSIGNED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.fmsIndigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.fmsIndigo.opacity(0.10))
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
                        Text(trip.notes ?? "Dry Van Food Grd")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }

                Divider()

                
                Button {
                    vm.mapActiveTrip = trip
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Start Active Trip")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.fmsIndigo.gradient)
                    .cornerRadius(14)
                }
            } else {
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
