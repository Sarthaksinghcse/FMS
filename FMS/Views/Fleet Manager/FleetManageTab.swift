//
//  FleetManageTab.swift
//  FMS
//
//  Consolidated "Manage" tab for the Fleet Manager dashboard.
//  Contains: ManagementHubView, VehicleListView, DriverListView,
//            MaintenanceStaffListView, TripListView — and all their
//            supporting sub-views and stubs — in one file.
//

import SwiftUI
import SwiftData


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 1 ▸ Management Hub
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Models

struct CardMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let systemIcon: String
    let iconColor: Color
}

struct ManagementCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let metrics: [CardMetric]
    let destination: ManagementDestination
}

enum ManagementDestination: Hashable {
    case vehicleList
    case driverList
    case maintenanceStaff
}

// MARK: Hub View

@available(iOS 26.0, *)
struct ManagementHubView: View {

    @State private var appearAnimation = false
    @State private var cardAnimations: [Bool] = [false, false, false]
    @State private var selectedDestination: ManagementDestination?

    @Environment(\.modelContext) private var modelContext

    @Query private var vehicles: [Vehicle]
    @Query private var users: [User]
    @Query private var trips: [Trip]
    @Query private var workOrders: [WorkOrder]

    private var driverCount: Int {
        users.filter { $0.role == UserRole.driver }.count
    }

    private var maintenanceCount: Int {
        users.filter { $0.role == UserRole.maintenance }.count
    }

    private var managementCards: [ManagementCard] {
        [
            ManagementCard(
                title: "Vehicle Management",
                subtitle: "Manage all fleet vehicles",
                icon: "truck.box.fill",
                accentColor: AppTheme.Brand.royalBlue,
                metrics: [
                    CardMetric(label: "Total",   value: "\(vehicles.count)",
                               systemIcon: "car.fill",                       iconColor: AppTheme.Brand.royalBlue),
                    CardMetric(label: "Active",   value: "\(vehicles.filter { $0.status == .active }.count)",
                               systemIcon: "checkmark.circle.fill",          iconColor: .green),
                    CardMetric(label: "In Shop",  value: "\(vehicles.filter { $0.status == .inMaintenance }.count)",
                               systemIcon: "exclamationmark.triangle.fill",  iconColor: AppTheme.Brand.accent)
                ],
                destination: .vehicleList
            ),
            ManagementCard(
                title: "Driver Management",
                subtitle: "Manage drivers & assignments",
                icon: "person.fill.checkmark",
                accentColor: Color(red: 0.30, green: 0.70, blue: 0.46),
                metrics: [
                    CardMetric(label: "Total",   value: "\(driverCount)",
                               systemIcon: "person.2.fill",  iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)),
                    CardMetric(label: "Online",  value: "\(users.filter { $0.role == .driver && $0.isActive }.count)",
                               systemIcon: "circle.fill",    iconColor: .green),
                    CardMetric(label: "Offline", value: "\(users.filter { $0.role == .driver && !$0.isActive }.count)",
                               systemIcon: "circle.fill",    iconColor: .gray)
                ],
                destination: .driverList
            ),
            ManagementCard(
                title: "Maintenance Team",
                subtitle: "Manage technicians & tasks",
                icon: "wrench.and.screwdriver.fill",
                accentColor: AppTheme.Brand.accent,
                metrics: [
                    CardMetric(label: "Staff",        value: "\(maintenanceCount)",
                               systemIcon: "person.3.fill",      iconColor: AppTheme.Brand.accent),
                    CardMetric(label: "Active Orders", value: "\(workOrders.filter { $0.status == .open || $0.status == .inProgress }.count)",
                               systemIcon: "doc.text.fill",      iconColor: .orange),
                    CardMetric(label: "Done Orders",  value: "\(workOrders.filter { $0.status == .completed }.count)",
                               systemIcon: "checkmark.seal.fill", iconColor: .green)
                ],
                destination: .maintenanceStaff
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        cardsSection
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 110)
                    }
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedDestination) { destination in
                destinationView(for: destination)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
                for index in cardAnimations.indices {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1 + 0.2)) {
                        cardAnimations[index] = true
                    }
                }
            }
        }
    }

    // MARK: Cards Grid

    private var cardsSection: some View {
        VStack(spacing: 20) {
            ForEach(managementCards) { card in
                let index = managementCards.firstIndex(where: { $0.id == card.id }) ?? 0
                ManagementCardView(card: card) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedDestination = card.destination
                }
                .opacity(cardAnimations.indices.contains(index) && cardAnimations[index] ? 1 : 0)
                .offset(y: cardAnimations.indices.contains(index) && cardAnimations[index] ? 0 : 30)
            }
        }
    }

    // MARK: Destination Router

    @ViewBuilder
    private func destinationView(for destination: ManagementDestination) -> some View {
        switch destination {
        case .vehicleList:      VehicleListView()
        case .driverList:       DriverListView()
        case .maintenanceStaff: MaintenanceStaffListView()
        }
    }
}

// MARK: Card View

@available(iOS 26.0, *)
struct ManagementCardView: View {
    let card: ManagementCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                // Header
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(card.accentColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: card.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(card.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text(card.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray.opacity(0.4))
                }

                Divider()
                    .background(Color.black.opacity(0.06))
                    .padding(.vertical, 2)

                // Metrics
                HStack(spacing: 0) {
                    ForEach(card.metrics) { metric in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(metric.iconColor.opacity(0.08))
                                    .frame(width: 24, height: 24)
                                Image(systemName: metric.systemIcon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(metric.iconColor)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(metric.value)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                Text(metric.label)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(
                            colors: [card.accentColor.opacity(0.08), card.accentColor.opacity(0.01)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [card.accentColor.opacity(0.25), card.accentColor.opacity(0.05), Color.white.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 2 ▸ Vehicle List
// ─────────────────────────────────────────────────────────────────────────────


// MARK: Vehicle List View

@available(iOS 26.0, *)
struct VehicleListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]

    @State private var searchText = ""
    @State private var selectedFilter: VehicleStatusFilter = .all
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?
    @State private var appearAnimation = false
    @State private var cardsAppeared: Set<UUID> = []

    private var filteredVehicles: [Vehicle] {
        vehicles.filter { v in
            let matchesStatus = selectedFilter.vehicleStatus.map { v.status == $0 } ?? true
            let q = searchText.lowercased()
            let matchesSearch = searchText.isEmpty ||
                v.registrationNumber.lowercased().contains(q) ||
                v.make.lowercased().contains(q) ||
                v.model.lowercased().contains(q)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            VStack(spacing: 0) {
                filterChipsSection
                if filteredVehicles.isEmpty {
                    if searchText.isEmpty && selectedFilter == .all {
                        ContentUnavailableView {
                            Label("No Vehicles Yet", systemImage: "car.fill")
                        } description: {
                            Text("Add your first vehicle to the fleet.")
                        } actions: {
                            Button("Add Vehicle") { showAddVehicle = true }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.Brand.royalBlue)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    vehicleListSection
                }
            }
        }
        .refreshable {
            await syncVehicles()
        }
        .navigationTitle("Vehicle Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search registration, make, model…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAddVehicle = true
                } label: { Image(systemName: "plus") }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
            Task {
                await syncVehicles()
            }
        }
        .sheet(isPresented: $showAddVehicle) {
            if #available(iOS 26.0, *) {
                AddVehicleFormView()
            }
        }
        .sheet(item: $editingVehicle) { v in
            if #available(iOS 26.0, *) {
                EditVehicleFormView(vehicle: v)
            }
        }
    }

    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(VehicleStatusFilter.allCases) { filter in
                    FilterChipView(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        color: filter.chipColor,
                        count: countForFilter(filter)
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    private var vehicleListSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(filteredVehicles) { vehicle in
                    let idx = filteredVehicles.firstIndex(where: { $0.id == vehicle.id }) ?? 0
                    VehicleCardView(vehicle: vehicle) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingVehicle = vehicle
                    }
                    .opacity(cardsAppeared.contains(vehicle.id) ? 1 : 0)
                    .offset(y: cardsAppeared.contains(vehicle.id) ? 0 : 30)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(idx) * 0.07)) {
                            _ = cardsAppeared.insert(vehicle.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
            .padding(.top, 4)
        }
    }

    private func countForFilter(_ filter: VehicleStatusFilter) -> Int {
        guard let status = filter.vehicleStatus else { return vehicles.count }
        return vehicles.filter { $0.status == status }.count
    }

    private func syncVehicles() async {
        do {
            let dbVehicles = try await SupabaseManager.shared.fetchVehicles()
            await MainActor.run {
                for dbv in dbVehicles {
                    if let localVehicle = vehicles.first(where: { $0.id == dbv.id }) {
                        localVehicle.registrationNumber = dbv.vehicleNumber
                        localVehicle.vinNumber = dbv.vin
                        localVehicle.make = dbv.manufacturer
                        localVehicle.model = dbv.model
                        localVehicle.year = dbv.year
                        localVehicle.status = dbv.status.toLocalStatus
                        localVehicle.assignedDriverId = dbv.assignedDriverId
                        localVehicle.lastServiceDate = dbv.lastServiceDate
                    } else {
                        let newVehicle = dbv.asLocalVehicle
                        modelContext.insert(newVehicle)
                    }
                }
                
                let remoteIds = Set(dbVehicles.map { $0.id })
                for localVehicle in vehicles {
                    if !remoteIds.contains(localVehicle.id) {
                        modelContext.delete(localVehicle)
                    }
                }
                
                try? modelContext.save()
            }
        } catch {
            print("Failed to sync vehicles: \(error)")
        }
    }
}

// MARK: Filter Chip

@available(iOS 26.0, *)
struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.25) : color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? color : color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: Vehicle Card

@available(iOS 26.0, *)
struct VehicleCardView: View {
    let vehicle: Vehicle
    let onEdit: () -> Void

    private var formattedOdometer: String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: vehicle.odometerReading)) ?? "\(Int(vehicle.odometerReading))"
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [vehicle.vehicleType.iconColor.opacity(0.8), vehicle.vehicleType.iconColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                    .shadow(color: vehicle.vehicleType.iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
                Image(systemName: vehicle.vehicleType.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(vehicle.registrationNumber)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: vehicle.status.statusIcon).font(.system(size: 9))
                        Text(vehicle.status.displayName).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.3)
                    }
                    .foregroundColor(vehicle.status.statusColor)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(vehicle.status.statusColor.opacity(0.10))
                    .clipShape(Capsule())
                }
                Text("\(vehicle.make) \(vehicle.model) · \(String(vehicle.year))")
                    .font(.system(size: 13, design: .rounded)).foregroundColor(.gray)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: vehicle.vehicleType.icon).font(.system(size: 9))
                        Text(vehicle.vehicleType.displayName).font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(vehicle.vehicleType.iconColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(vehicle.vehicleType.iconColor.opacity(0.08)).clipShape(Capsule())

                    HStack(spacing: 4) {
                        Image(systemName: vehicle.fuelType.icon).font(.system(size: 9))
                        Text(vehicle.fuelType.displayName).font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.gray.opacity(0.06)).clipShape(Capsule())

                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "gauge.with.needle").font(.system(size: 9))
                        Text("\(formattedOdometer) km").font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.gray.opacity(0.7))
                }
            }

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Brand.royalBlue.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Vehicle Stubs replaced by VehicleFormView.swift


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 3 ▸ Driver List
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct DriverListView: View {

    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var vehicles: [Vehicle]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showAddDriver = false
    @State private var selectedDriverForEdit: User?
    @State private var cardAnimations: [UUID: Bool] = [:]

    private var drivers: [User] { allUsers.filter { $0.role == UserRole.driver } }

    private var filteredDrivers: [User] {
        guard !searchText.isEmpty else { return drivers }
        let q = searchText.lowercased()
        return drivers.filter { $0.fullName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    private func vehicleForDriver(_ d: User) -> Vehicle? {
        vehicles.first { $0.assignedDriverId == d.id }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            VStack(spacing: 0) {
                if filteredDrivers.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No Drivers Yet", systemImage: "person.2.fill")
                        } description: {
                            Text("Add your first driver to start managing your fleet team.")
                        } actions: {
                            Button("Add Driver") { showAddDriver = true }
                                .buttonStyle(.borderedProminent).tint(AppTheme.Brand.royalBlue)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    driverList
                }
            }
        }
        .refreshable {
            await syncDrivers()
        }
        .navigationTitle("Driver Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search drivers…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAddDriver = true
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddDriver) { AddDriverFormView() }
        .sheet(item: $selectedDriverForEdit) { d in EditDriverFormView(driver: d) }
        .onAppear {
            triggerCardAnimations()
            Task {
                await syncDrivers()
            }
        }
        .onChange(of: filteredDrivers.count) { triggerCardAnimations() }
    }

    private var driverList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredDrivers) { driver in
                    driverCard(driver)
                        .opacity(cardAnimations[driver.id] == true ? 1 : 0)
                        .offset(y: cardAnimations[driver.id] == true ? 0 : 30)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 100)
        }
    }

    private func driverCard(_ driver: User) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Brand.royalBlue.opacity(0.8), AppTheme.Brand.royalBlue],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                Text(initials(for: driver.fullName))
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(driver.fullName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.black).lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill").font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                    Text(driver.email).font(.system(size: 13, design: .rounded)).foregroundColor(.gray).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill").font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                    Text(driver.phoneNumber).font(.system(size: 13, design: .rounded)).foregroundColor(.gray)
                }

                if let v = vehicleForDriver(driver) {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill").font(.system(size: 11)).foregroundColor(AppTheme.Brand.royalBlue.opacity(0.7))
                        Text(v.registrationNumber).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(AppTheme.Brand.royalBlue)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill").font(.system(size: 11)).foregroundColor(.gray.opacity(0.4))
                        Text("Unassigned").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.gray.opacity(0.5)).italic()
                    }
                }

                HStack(spacing: 8) {
                    driverStatusBadge(isActive: driver.isActive)
                    driverRoleBadge
                }
                .padding(.top, 2)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedDriverForEdit = driver
            } label: {
                ZStack {
                    Circle().fill(Color.gray.opacity(0.08)).frame(width: 40, height: 40)
                    Image(systemName: "pencil").font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private func driverStatusBadge(isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(isActive ? Color.green : Color.red).frame(width: 7, height: 7)
            Text(isActive ? "Active" : "Inactive").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.3)
        }
        .foregroundColor(isActive ? .green : .red)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(isActive ? Color.green.opacity(0.10) : Color.red.opacity(0.10)))
        .overlay(Capsule().stroke(isActive ? Color.green.opacity(0.25) : Color.red.opacity(0.25), lineWidth: 1))
    }

    private var driverRoleBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.fill").font(.system(size: 9))
            Text("Driver").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(0.3)
        }
        .foregroundColor(AppTheme.Brand.royalBlue)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(AppTheme.Brand.royalBlue.opacity(0.10)))
        .overlay(Capsule().stroke(AppTheme.Brand.royalBlue.opacity(0.25), lineWidth: 1))
    }

    private func triggerCardAnimations() {
        for (index, driver) in filteredDrivers.enumerated() {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08 + 0.15)) {
                cardAnimations[driver.id] = true
            }
        }
    }

    private func syncDrivers() async {
        do {
            let dbDrivers = try await SupabaseManager.shared.fetchDrivers()
            await MainActor.run {
                for dbd in dbDrivers {
                    if let localDriver = allUsers.first(where: { $0.id == dbd.id }) {
                        localDriver.fullName = dbd.name
                        localDriver.email = dbd.email
                        localDriver.phoneNumber = dbd.phoneNumber ?? ""
                        localDriver.role = dbd.role.asLocalRole
                    } else {
                        let newDriver = dbd.asLocalUser
                        modelContext.insert(newDriver)
                    }
                }
                
                let remoteIds = Set(dbDrivers.map { $0.id })
                let localDrivers = allUsers.filter { $0.role == .driver }
                for localDriver in localDrivers {
                    if !remoteIds.contains(localDriver.id) {
                        modelContext.delete(localDriver)
                    }
                }
                
                try? modelContext.save()
            }
        } catch {
            print("Failed to sync drivers: \(error)")
        }
    }
}

// MARK: Add / Edit Driver Stubs

@available(iOS 26.0, *)
struct AddDriverStubView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AppTheme.Brand.royalBlue.opacity(0.08), AppTheme.Brand.royalBlue.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                            .symbolEffect(.bounce, value: appeared)
                    }
                    VStack(spacing: 8) {
                        Text("Add New Driver").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("Driver registration form\ncoming soon.")
                            .font(.system(.subheadline, design: .rounded)).foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
            }
            .navigationTitle("New Driver").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(); dismiss()
                    }
                    .fontWeight(.semibold).foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
        }
    }
}

@available(iOS 26.0, *)
struct EditDriverStubView: View {
    let driver: User
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    private var initials: String {
        let parts = driver.fullName.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(driver.fullName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AppTheme.Brand.royalBlue.opacity(0.8), AppTheme.Brand.royalBlue],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 12, x: 0, y: 6)
                        Text(initials).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                    VStack(spacing: 8) {
                        Text("Edit Driver Profile").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text(driver.fullName).font(.system(.subheadline, design: .rounded)).foregroundColor(.gray)
                        Text("Profile editing form\ncoming soon.")
                            .font(.system(.subheadline, design: .rounded)).foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    Spacer()
                }
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
            }
            .navigationTitle("Edit Driver").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(); dismiss()
                    }
                    .fontWeight(.semibold).foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 4 ▸ Maintenance Staff List
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct MaintenanceStaffListView: View {

    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var allWorkOrders: [WorkOrder]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showAddStaffSheet = false
    @State private var selectedStaffForEdit: User?
    @State private var cardAnimations: [UUID: Bool] = [:]

    private var maintenanceStaff: [User] { allUsers.filter { $0.role == UserRole.maintenance } }

    private var filteredStaff: [User] {
        guard !searchText.isEmpty else { return maintenanceStaff }
        let q = searchText.lowercased()
        return maintenanceStaff.filter { $0.fullName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    private func workOrderCount(for id: UUID) -> Int {
        allWorkOrders.filter { $0.assignedTo == id }.count
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            VStack(spacing: 0) {
                if filteredStaff.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No Maintenance Staff", systemImage: "wrench.and.screwdriver.fill")
                        } description: {
                            Text("Add your first technician to get started.")
                        } actions: {
                            Button("Add Staff Member") { showAddStaffSheet = true }
                                .buttonStyle(.borderedProminent).tint(AppTheme.Brand.accent)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    staffListView
                }
            }
        }
        .navigationTitle("Maintenance Team")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search technicians…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAddStaffSheet = true
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddStaffSheet) { AddMaintenanceFormView() }
        .sheet(item: $selectedStaffForEdit) { s in EditMaintenanceFormView(staff: s) }
        .onAppear { triggerCardAnimations() }
        .onChange(of: filteredStaff.count) { triggerCardAnimations() }
    }

    private var staffListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredStaff) { staff in
                    staffCard(for: staff)
                        .opacity(cardAnimations[staff.id] == true ? 1 : 0)
                        .offset(y: cardAnimations[staff.id] == true ? 0 : 30)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 100)
        }
    }

    private func staffCard(for staff: User) -> some View {
        let orders = workOrderCount(for: staff.id)
        return ZStack(alignment: .topTrailing) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [AppTheme.Brand.accent.opacity(0.7), AppTheme.Brand.accent],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 56, height: 56)
                        .shadow(color: AppTheme.Brand.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    Text(initials(for: staff.fullName))
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(staff.fullName)
                        .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(.black).lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill").font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                        Text(staff.email).font(.system(size: 13, design: .rounded)).foregroundColor(.gray).lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill").font(.system(size: 11)).foregroundColor(.gray.opacity(0.6))
                        Text(staff.phoneNumber).font(.system(size: 13, design: .rounded)).foregroundColor(.gray)
                    }
                    HStack(spacing: 8) {
                        staffStatusBadge(isActive: staff.isActive)
                        staffRoleBadge
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                VStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedStaffForEdit = staff
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.Brand.royalBlue)
                            .symbolEffect(.bounce, value: selectedStaffForEdit?.id == staff.id)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    Spacer()
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)

            if orders > 0 {
                Text("\(orders)")
                    .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppTheme.Brand.royalBlue)
                        .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 6, x: 0, y: 3))
                    .offset(x: -12, y: -8)
            }
        }
    }

    private func staffStatusBadge(isActive: Bool) -> some View {
        HStack(spacing: 5) {
            Circle().fill(isActive ? Color.green : AppTheme.Brand.accent).frame(width: 7, height: 7)
            Text(isActive ? "Available" : "Busy").font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(isActive ? Color.green : AppTheme.Brand.accent)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill((isActive ? Color.green : AppTheme.Brand.accent).opacity(0.12)))
    }

    private var staffRoleBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver").font(.system(size: 9, weight: .bold))
            Text("Technician").font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(AppTheme.Brand.accent)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(AppTheme.Brand.accent.opacity(0.12)))
    }

    private func triggerCardAnimations() {
        for (index, staff) in filteredStaff.enumerated() {
            guard cardAnimations[staff.id] != true else { continue }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08 + 0.15)) {
                cardAnimations[staff.id] = true
            }
        }
    }
}

// MARK: Add / Edit Staff Stubs

@available(iOS 26.0, *)
struct AddStaffSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle().fill(AppTheme.Brand.accent.opacity(0.1)).frame(width: 90, height: 90)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(AppTheme.Brand.accent).symbolEffect(.bounce)
                    }
                    VStack(spacing: 8) {
                        Text("Add Staff Member").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("This feature is coming soon.\nYou'll be able to add maintenance technicians here.")
                            .font(.system(size: 15, design: .rounded)).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    Spacer(); Spacer()
                }
            }
            .navigationTitle("New Staff").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppTheme.Brand.accent)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct EditStaffSheetView: View {
    let staff: User
    @Environment(\.dismiss) private var dismiss

    private var staffInitials: String {
        let parts = staff.fullName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [AppTheme.Brand.accent.opacity(0.7), AppTheme.Brand.accent],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: AppTheme.Brand.accent.opacity(0.3), radius: 10, x: 0, y: 6)
                        Text(staffInitials).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                    VStack(spacing: 8) {
                        Text(staff.fullName).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("Edit functionality coming soon.\nYou'll be able to update staff details here.")
                            .font(.system(size: 15, design: .rounded)).foregroundColor(.gray)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    Spacer(); Spacer()
                }
            }
            .navigationTitle("Edit Staff").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(AppTheme.Brand.accent)
                }
            }
        }
    }
}


// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SECTION 5 ▸ Trip List
// ─────────────────────────────────────────────────────────────────────────────


// MARK: Trip Category Filter
enum TripCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case upcoming = "Upcoming"
    case past = "Past"

    var id: String { rawValue }
}

// MARK: Trip List View

@available(iOS 26.0, *)
struct TripListView: View {

    @State private var searchText = ""
    @State private var selectedFilter: TripCategoryFilter = .all
    @State private var showAddTrip = false
    @State private var editingTrip: Trip? = nil
    @State private var appearAnimation = false
    @State private var cardAnimations: Set<UUID> = []

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.scheduledStartTime, order: .reverse) private var allTrips: [Trip]
    @Query private var allUsers: [User]

    private let tripPurple = Color(red: 0.58, green: 0.39, blue: 0.87)

    private var filteredTrips: [Trip] {
        var trips = allTrips
        switch selectedFilter {
        case .all:
            break
        case .active:
            trips = trips.filter { $0.tripStatus == .started || $0.tripStatus == .inProgress }
        case .upcoming:
            trips = trips.filter { $0.tripStatus == .assigned }
        case .past:
            trips = trips.filter { $0.tripStatus == .completed || $0.tripStatus == .cancelled }
        }
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            trips = trips.filter {
                $0.tripCode.lowercased().contains(q) ||
                $0.startLocation.lowercased().contains(q) ||
                $0.endLocation.lowercased().contains(q)
            }
        }
        return trips
    }

    private func countForFilter(_ filter: TripCategoryFilter) -> Int {
        switch filter {
        case .all:
            return allTrips.count
        case .active:
            return allTrips.filter { $0.tripStatus == .started || $0.tripStatus == .inProgress }.count
        case .upcoming:
            return allTrips.filter { $0.tripStatus == .assigned }.count
        case .past:
            return allTrips.filter { $0.tripStatus == .completed || $0.tripStatus == .cancelled }.count
        }
    }

    private func driverName(for driverId: UUID) -> String? {
        allUsers.first(where: { $0.id == driverId && $0.role == UserRole.driver })?.fullName
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            VStack(spacing: 0) {
                filterChips.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 8)
                if filteredTrips.isEmpty {
                    if searchText.isEmpty && selectedFilter == .all {
                        ContentUnavailableView {
                            Label("No Trips Yet", systemImage: "map.fill")
                        } description: {
                            Text("Schedule or dispatch your first trip.")
                        } actions: {
                            Button("Add Trip") { showAddTrip = true }
                                .buttonStyle(.borderedProminent).tint(tripPurple)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    tripListContent
                }
            }
        }
        .navigationTitle("Trip Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search trips…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAddTrip = true
                } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddTrip) { AddTripFormView() }
        .sheet(item: $editingTrip) { t in EditTripFormView(trip: t) }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true } }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TripCategoryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { selectedFilter = filter }
                    } label: {
                        HStack(spacing: 6) {
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            let count = countForFilter(filter)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(isSelected ? Color.white.opacity(0.25) : tripPurple.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(isSelected ? .white : tripPurple)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(isSelected ? tripPurple : tripPurple.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSelected ? Color.clear : tripPurple.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 2)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    private var tripListContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(filteredTrips) { trip in
                    let idx = filteredTrips.firstIndex(where: { $0.id == trip.id }) ?? 0
                    TripCardView(
                        trip: trip,
                        driverName: driverName(for: trip.driverId),
                        accentColor: tripPurple,
                        onEdit: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            editingTrip = trip
                        }
                    )
                    .opacity(cardAnimations.contains(trip.id) ? 1 : 0)
                    .offset(y: cardAnimations.contains(trip.id) ? 0 : 30)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(idx) * 0.07)) {
                            _ = cardAnimations.insert(trip.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 100)
        }
    }
}

// MARK: Trip Card

@available(iOS 26.0, *)
struct TripCardView: View {
    let trip: Trip
    let driverName: String?
    let accentColor: Color
    let onEdit: () -> Void

    private static let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd MMM yyyy"; return f }()
    private static let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "hh:mm a"; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Row
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [accentColor.opacity(0.8), accentColor],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)
                        .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.tripCode).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.black)
                    Text(Self.dateFmt.string(from: trip.scheduledStartTime))
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.gray)
                }
                Spacer()
                tripStatusBadge
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26)).foregroundColor(.gray.opacity(0.35))
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // Route
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill").font(.system(size: 14)).foregroundColor(.green.opacity(0.7))
                Text(trip.startLocation).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.8)).lineLimit(1)
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundColor(.gray.opacity(0.5))
                Image(systemName: "mappin.circle.fill").font(.system(size: 14)).foregroundColor(.red.opacity(0.7))
                Text(trip.endLocation).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.8)).lineLimit(1)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Stats row
            HStack(spacing: 0) {
                tripDetailCol(label: "DEPARTURE", value: Self.timeFmt.string(from: trip.scheduledStartTime), icon: "clock.fill")
                Spacer()
                tripDetailCol(label: "ARRIVAL",   value: Self.timeFmt.string(from: trip.scheduledEndTime),   icon: "clock.badge.checkmark.fill")
                Spacer()
                tripDetailCol(label: "DISTANCE",  value: String(format: "%.1f km", trip.distanceKm),         icon: "road.lanes")
            }

            // Driver info
            if let name = driverName {
                Divider().background(AppTheme.Glass.border)
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill").font(.system(size: 18)).foregroundColor(accentColor.opacity(0.7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASSIGNED DRIVER")
                            .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.7)).tracking(0.8)
                        Text(name).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.black)
                    }
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var tripStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trip.tripStatus.badgeIcon).font(.system(size: 10, weight: .bold))
            Text(trip.tripStatus.displayName).font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(trip.tripStatus.badgeColor).clipShape(Capsule())
    }

    private func tripDetailCol(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(accentColor.opacity(0.6))
            Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.7)).tracking(0.8)
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.black)
        }
    }
}

// MARK: Add / Edit Trip Stubs

@available(iOS 26.0, *)
struct AddTripStubView: View {
    @Environment(\.dismiss) private var dismiss
    private let tripPurple = Color(red: 0.58, green: 0.39, blue: 0.87)

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle().fill(tripPurple.opacity(0.08)).frame(width: 100, height: 100)
                        Image(systemName: "map.fill").font(.system(size: 38, weight: .medium))
                            .foregroundColor(tripPurple.opacity(0.5)).symbolEffect(.bounce)
                    }
                    VStack(spacing: 8) {
                        Text("Add New Trip").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("Trip creation form\ncoming soon.")
                            .font(.system(size: 14, design: .rounded)).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                    Spacer(); Spacer()
                }
            }
            .navigationTitle("New Trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(tripPurple)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct EditTripStubView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    private let tripPurple = Color(red: 0.58, green: 0.39, blue: 0.87)

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle().fill(tripPurple.opacity(0.08)).frame(width: 100, height: 100)
                        Image(systemName: "pencil.and.list.clipboard").font(.system(size: 38, weight: .medium))
                            .foregroundColor(tripPurple.opacity(0.5)).symbolEffect(.bounce)
                    }
                    VStack(spacing: 8) {
                        Text("Edit Trip").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("Editing \(trip.tripCode)").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(tripPurple)
                        Text("Trip editing form\ncoming soon.")
                            .font(.system(size: 14, design: .rounded)).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                    Spacer(); Spacer()
                }
            }
            .navigationTitle("Edit Trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(tripPurple)
                }
            }
        }
    }
}
