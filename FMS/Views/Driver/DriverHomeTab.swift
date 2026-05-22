//
//  DriverHomeTab.swift
//  FMS
//
//  Tab 1 — Dashboard home. Uber/Ola-style minimal layout.
//  One primary focus at a time. Breathes. No clutter.
//  Target: iOS 26+
//

import SwiftUI

// MARK: - Driver Home Tab

@available(iOS 26.0, *)
struct DriverHomeTab: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── 1. Greeting ─────────────────────────────────────────
                    GreetingRow(vm: vm)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 32)

                    // ── 2. Primary card (trip or idle prompt) ────────────────
                    PrimaryCard(vm: vm)
                        .padding(.horizontal, 24)

                    // ── 3. Notification badge (single, subtle) ───────────────
                    if let banner = vm.banners.first {
                        NoticeStrip(banner: banner)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                    }


                    // ── 5. Vehicle summary (one clean line) ──────────────────
                    VehicleRow(vm: vm)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                    // ── 6. Messages (bare list, no card chrome) ──────────────
                    MessageList(vm: vm)
                        .padding(.horizontal, 24)
                        .padding(.top, 32)

                    Spacer(minLength: 48)
                }
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 1. Greeting Row

private struct GreetingRow: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(vm.greeting)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(vm.driverFirstName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Profile avatar + status dot — tap to open profile
            Button { vm.showProfile = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.fmsIndigo.gradient)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(vm.driverFirstName.prefix(1)))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    Circle()
                        .fill(vm.driverStatus.dot)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 2. Primary Card

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

// Active state — shows timer + destination
private struct LiveTripCard: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Live badge
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.red.opacity(0.5), radius: 3)
                Text("In Progress")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }

            // Timer (hero element)
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.elapsedFormatted)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                if let trip = vm.activeTrip {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(trip.destination)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // Actions
            HStack(spacing: 10) {
                Button { vm.mapActiveTrip = vm.activeTrip; vm.showMaps = true } label: {
                    Label("Navigate", systemImage: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fmsIndigo)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .glassEffect(.regular.tint(Color.fmsIndigo.opacity(0.08)),
                                     in: RoundedRectangle(cornerRadius: 12))
                }
                Button { vm.confirmEnd = true } label: {
                    Label("End Trip", systemImage: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.red.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red.opacity(0.12), lineWidth: 1)
        )
    }
}

// Idle state — shows next trip + start CTA
private struct IdleCard: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let trip = vm.upcomingTrips.first {
                // Next trip label
                Text("Next trip")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                // Route in large text
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.source)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fmsIndigo)
                        Text(trip.destination)
                            .font(.system(size: 22, weight: .bold))
                            .lineLimit(1)
                    }
                }

                // Metadata chips
                HStack(spacing: 8) {
                    MetaChip(icon: "arrow.left.arrow.right",
                             label: String(format: "%.0f km", trip.distance))
                    if let s = trip.startTime {
                        MetaChip(icon: "clock",
                                 label: s.formatted(.dateTime.hour().minute()))
                    }
                    if trip.notes != nil {
                        MetaChip(icon: "exclamationmark", label: "Priority")
                    }
                }

                // Start button
                Button { vm.mapActiveTrip = trip } label: {
                    Text("Start Trip")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.fmsIndigo.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                // No trips
                VStack(alignment: .leading, spacing: 8) {
                    Text("No trips today")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Your fleet manager will assign trips here.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(22)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MetaChip: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(UIColor.tertiarySystemFill))
        .clipShape(Capsule())
    }
}

// MARK: - 3. Notice Strip (single banner, very subtle)

private struct NoticeStrip: View {
    let banner: DashboardBanner

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(banner.tint)
                .frame(width: 6, height: 6)
            Text(banner.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text(banner.body)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
    }
}



// MARK: - 5. Vehicle Row

private struct VehicleRow: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Section label + defect link
            HStack {
                Text("Vehicle")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { vm.showDefect = true } label: {
                    Text("Report defect")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Status.danger)
                }
            }

            // Card
            VStack(spacing: 0) {

                // ── Manufacturer ─────────────────────────────────────────────
                VehicleStatRow(
                    icon: "building.2.fill",
                    label: "Manufacturer",
                    value: vm.vehicleManufacturer
                )
                Color(UIColor.separator)
                    .frame(height: 0.4)
                    .padding(.leading, 40)

                // ── Model ─────────────────────────────────────────────────────
                VehicleStatRow(
                    icon: "car.side.fill",
                    label: "Model",
                    value: "\(vm.vehicleModel)  (\(vm.vehicleYear))"
                )
                Color(UIColor.separator)
                    .frame(height: 0.4)
                    .padding(.leading, 40)

                // ── Plate ─────────────────────────────────────────────────────
                VehicleStatRow(
                    icon: "car.fill",
                    label: "Plate number",
                    value: vm.assignedReg
                )
                Color(UIColor.separator)
                    .frame(height: 0.4)
                    .padding(.leading, 40)

                // ── Fuel ──────────────────────────────────────────────────────
                VehicleStatRow(
                    icon: "fuelpump.fill",
                    label: "Fuel level",
                    value: String(format: "%.0f%%", vm.fuelLevel * 100),
                    valueColor: vm.fuelLevel < 0.25
                        ? AppTheme.Status.danger
                        : Color.fmsIndigo
                )
                Color(UIColor.separator)
                    .frame(height: 0.4)
                    .padding(.leading, 40)

                // ── Odometer ─────────────────────────────────────────────────
                VehicleStatRow(
                    icon: "gauge",
                    label: "Odometer",
                    value: "12,430 km"
                )
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct VehicleStatRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.fmsIndigo)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - 6. Message List (bare, no card chrome)

private struct MessageList: View {
    @ObservedObject var vm: DriverDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Text("Messages")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                    let unread = vm.messages.filter(\.unread).count
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                Spacer()
                Button { vm.showMessaging = true } label: {
                    Text("See all")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.fmsIndigo)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(vm.messages.prefix(2).enumerated()), id: \.offset) { i, m in
                    BareMessageRow(msg: m)
                    if i == 0 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .onTapGesture { vm.showMessaging = true }
        }
    }
}

private struct BareMessageRow: View {
    let msg: DriverChatMessage

    private var roleColor: Color {
        switch msg.role {
        case "Fleet Manager": return Color.fmsIndigo
        case "Maintenance":   return AppTheme.Brand.accent
        default:              return Color(UIColor.systemGray)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.10))
                    .frame(width: 36, height: 36)
                Text(msg.initials)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(roleColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(msg.sender)
                        .font(.system(size: 14, weight: msg.unread ? .semibold : .regular))
                    if msg.unread {
                        Circle()
                            .fill(Color.fmsIndigo)
                            .frame(width: 5, height: 5)
                    }
                    Spacer()
                    Text(msg.time)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text(msg.preview)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(msg.sender): \(msg.preview)")
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Home Tab") {
    DriverHomeTab(vm: DriverDashboardViewModel())
}
