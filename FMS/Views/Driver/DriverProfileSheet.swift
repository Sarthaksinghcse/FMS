import SwiftUI

@available(iOS 26.0, *)
struct DriverProfileSheet: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var supabase = SupabaseManager.shared
    @State private var showSignOutConfirm = false

    
    private let totalTrips    = 142
    private let totalKmDriven = 4_820.0
    private let joinDate      = "March 2023"
    private let employeeId    = "DRV-00412"
    private let licenseNo     = "TN-24-2019-0041823"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Hero: Avatar + Name + ID ───────────────────────────
                    HeroHeader(vm: vm, employeeId: employeeId)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    
                    // ── Stats strip (2 key numbers) ────────────────────────
                    StatsStrip(
                        totalTrips: totalTrips,
                        totalKm:    totalKmDriven
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    // ── Status row ─────────────────────────────────────────
                    ProfileSection(header: "Status") {
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(vm.driverStatus.dot)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                )
                            
                            Toggle("Status", isOn: Binding(
                                get: { vm.driverStatus == .active },
                                set: { newValue in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        vm.driverStatus = newValue ? .active : .offline
                                    }
                                }
                            ))
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .tint(AppTheme.Status.success)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // ── Account info rows ──────────────────────────────────
                    ProfileSection(header: "Account") {
                        ProfileRow(icon: "person.fill",
                                   iconBg: AppTheme.Brand.primaryDeep,
                                   label: "Full Name",
                                   value: vm.driverFirstName)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "creditcard.fill",
                                   iconBg: AppTheme.Brand.primaryDeep,
                                   label: "Employee ID",
                                   value: employeeId)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "doc.text.fill",
                                   iconBg: Color(red: 0.35, green: 0.55, blue: 0.95),
                                   label: "License No.",
                                   value: licenseNo)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "calendar",
                                   iconBg: AppTheme.Brand.teal,
                                   label: "Joined",
                                   value: joinDate)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    // ── Vehicle rows ───────────────────────────────────────
                    ProfileSection(header: "Assigned Vehicle") {
                        ProfileRow(icon: "car.side.fill",
                                   iconBg: AppTheme.Brand.violet,
                                   label: "Model",
                                   value: "\(vm.vehicleModel)  (\(vm.vehicleYear))")
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "building.2.fill",
                                   iconBg: AppTheme.Brand.violet,
                                   label: "Manufacturer",
                                   value: vm.vehicleManufacturer)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "car.fill",
                                   iconBg: AppTheme.Brand.violet,
                                   label: "Plate",
                                   value: vm.assignedReg)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "fuelpump.fill",
                                   iconBg: vm.fuelLevel < 0.25
                                   ? AppTheme.Status.danger
                                   : AppTheme.Status.success,
                                   label: "Fuel Level",
                                   value: String(format: "%.0f%%", vm.fuelLevel * 100),
                                   valueColor: vm.fuelLevel < 0.25
                                   ? AppTheme.Status.danger
                                   : AppTheme.Status.success)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    // ── Settings rows ──────────────────────────────────────
                    ProfileSection(header: "Settings") {
                        ProfileRow(icon: "bell.fill",
                                   iconBg: AppTheme.Brand.accent,
                                   label: "Notifications",
                                   showChevron: true)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "lock.fill",
                                   iconBg: AppTheme.Brand.amber,
                                   label: "Privacy & Security",
                                   showChevron: true)
                        Divider().padding(.leading, 56)
                        ProfileRow(icon: "questionmark.circle.fill",
                                   iconBg: Color(UIColor.systemGray),
                                   label: "Help & Support",
                                   showChevron: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    // ── Sign out ───────────────────────────────────────────
                    Button {
                        Task {
                            try? await SupabaseManager.shared.signOut()
                            dismiss()
                        }
                    } label: {
                        Text("Sign Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.Status.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.Status.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Driver Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { try? await supabase.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your Driver account?")
            }
        }
    }




@available(iOS 26.0, *)
private struct HeroHeader: View {
    @ObservedObject var vm: DriverDashboardViewModel
    let employeeId: String

    var body: some View {
        VStack(spacing: 14) {
            
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Brand.primaryDeep, AppTheme.Brand.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        Text(String(vm.driverFirstName.prefix(1)))
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: AppTheme.Brand.primaryDeep.opacity(0.30), radius: 12, y: 6)

                
                Circle()
                    .fill(vm.driverStatus.dot)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color(UIColor.systemGroupedBackground), lineWidth: 3))
            }

            
            VStack(spacing: 4) {
                Text(vm.driverName)
                    .font(.system(size: 24, weight: .bold))
                HStack(spacing: 6) {
                    Text(vm.driverStatus.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(vm.driverStatus.dot)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(employeeId)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}



private struct StatsStrip: View {
    let totalTrips: Int
    let totalKm:    Double

    var body: some View {
        HStack(spacing: 10) {
            StatPill(value: "\(totalTrips)", label: "Trips",  icon: "map.fill",          color: AppTheme.Brand.primaryDeep)
            StatPill(value: String(format: "%.0f km", totalKm), label: "Driven", icon: "arrow.left.arrow.right", color: AppTheme.Brand.teal)
        }
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    let icon:  String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }
}





private struct ProfileSection<Content: View>: View {
    let header: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}



private struct ProfileRow: View {
    let icon: String
    let iconBg: Color
    let label: String
    var value: String = ""
    var valueColor: Color = .secondary
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            
            RoundedRectangle(cornerRadius: 8)
                .fill(iconBg)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                )

            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.primary)

            Spacer()

            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(UIColor.systemGray3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}



@available(iOS 26.0, *)
#Preview("Driver Profile") {
    DriverProfileSheet(vm: DriverDashboardViewModel())
}
