import SwiftUI
import SwiftData
import MapKit

struct CardMetric: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let systemIcon: String
    let iconColor: Color
}

struct ManagementCard: Identifiable {
    var id: ManagementDestination { destination }
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



@available(iOS 26.0, *)
struct ManagementHubView: View {

    @State private var appearAnimation = false
    @State private var cardAnimations: [Bool] = [false, false, false]
    @State private var path: [ManagementDestination] = []

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
                    CardMetric(label: "Available", value: "\(vehicles.filter { $0.status == .active }.count)",
                               systemIcon: "checkmark.circle.fill",          iconColor: .green),
                    CardMetric(label: "Maintenance",  value: "\(vehicles.filter { $0.status == .inMaintenance }.count)",
                               systemIcon: "exclamationmark.triangle.fill",  iconColor: AppTheme.Brand.accent)
                ],
                destination: .vehicleList
            ),
            ManagementCard(
                title: "Driver Management",
                subtitle: "Manage drivers & assignments",
                icon: "person.fill",
                accentColor: Color(red: 0.30, green: 0.70, blue: 0.46),
                metrics: [
                    CardMetric(label: "Total",   value: "\(driverCount)",
                               systemIcon: "person.2.fill",  iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)),
                    CardMetric(label: "Active",  value: "\(users.filter { $0.role == .driver && $0.isActive }.count)",
                               systemIcon: "checkmark.circle.fill",    iconColor: .green),
                    CardMetric(label: "Inactive", value: "\(users.filter { $0.role == .driver && !$0.isActive }.count)",
                               systemIcon: "xmark.circle.fill",    iconColor: .gray)
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
        NavigationStack(path: $path) {
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
            .navigationDestination(for: ManagementDestination.self) { destination in
                destinationView(for: destination)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
                for index in cardAnimations.indices {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1 + 0.2)) {
                        cardAnimations[index] = true
                    }
                }
                Task {
                    await SupabaseManager.shared.syncAllData(context: modelContext)
                }
            }
        }
    }

    

    private var cardsSection: some View {
        VStack(spacing: 20) {
            ForEach(managementCards) { card in
                let index = managementCards.firstIndex(where: { $0.id == card.id }) ?? 0
                ManagementCardView(card: card) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    path.append(card.destination)
                }
                .opacity(cardAnimations.indices.contains(index) && cardAnimations[index] ? 1 : 0)
                .offset(y: cardAnimations.indices.contains(index) && cardAnimations[index] ? 0 : 30)
            }
        }
    }

    

    @ViewBuilder
    private func destinationView(for destination: ManagementDestination) -> some View {
        switch destination {
        case .vehicleList:      VehicleListView()
        case .driverList:       DriverListView()
        case .maintenanceStaff: MaintenanceStaffListView()
        }
    }
}



@available(iOS 26.0, *)
struct ManagementCardView: View {
    let card: ManagementCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                
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









@available(iOS 26.0, *)
struct VehicleListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query private var allRecords: [MaintenanceRecord]

    @State private var searchText = ""
    @State private var selectedFilter: VehicleStatusFilter = .all
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?
    @State private var appearAnimation = false
    @State private var cardsAppeared: Set<UUID> = []
    @State private var isLoading = false

    init(initialFilter: VehicleStatusFilter = .all) {
        _selectedFilter = State(initialValue: initialFilter)
    }

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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    filterChipsSection
                    
                    if vehicles.isEmpty && isLoading {
                        VStack {
                            Spacer()
                            ProgressView("Syncing vehicles...")
                                .tint(AppTheme.Brand.royalBlue)
                                .foregroundStyle(AppTheme.Text.secondary)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Spacer()
                        }
                        .frame(minHeight: 200)
                    } else if filteredVehicles.isEmpty {
                        Group {
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
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredVehicles) { vehicle in
                                let idx = filteredVehicles.firstIndex(where: { $0.id == vehicle.id }) ?? 0
                                NavigationLink {
                                    VehicleMaintenanceHistoryView(vehicle: vehicle)
                                } label: {
                                    VehicleCardView(vehicle: vehicle) {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        editingVehicle = vehicle
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
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
                        .padding(.top, 4)
                        .padding(.bottom, 100)
                    }
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

    private func countForFilter(_ filter: VehicleStatusFilter) -> Int {
        guard let status = filter.vehicleStatus else { return vehicles.count }
        return vehicles.filter { $0.status == status }.count
    }

    private func syncVehicles() async {
        isLoading = true
        defer { isLoading = false }
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








@available(iOS 26.0, *)
enum DriverStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case online = "Online"
    case offline = "Offline"
    
    var id: String { rawValue }
    
    var chipColor: Color {
        switch self {
        case .all: return AppTheme.Brand.royalBlue
        case .online: return .green
        case .offline: return .gray
        }
    }
}

@available(iOS 26.0, *)
struct DriverListView: View {

    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedFilter: DriverStatusFilter = .all
    @State private var showAddDriver = false
    @State private var selectedDriverForEdit: User?
    @State private var cardAnimations: [UUID: Bool] = [:]
    @State private var isLoading = false

    init(initialFilter: DriverStatusFilter = .all) {
        _selectedFilter = State(initialValue: initialFilter)
    }

    private var drivers: [User] { allUsers.filter { $0.role == UserRole.driver } }

    private var filteredDrivers: [User] {
        let baseDrivers = drivers.filter { d in
            switch selectedFilter {
            case .all: return true
            case .online: return d.isActive
            case .offline: return !d.isActive
            }
        }
        guard !searchText.isEmpty else { return baseDrivers }
        let q = searchText.lowercased()
        return baseDrivers.filter { $0.fullName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    private func vehicleForDriver(_ d: User) -> Vehicle? {
        vehicles.first { $0.assignedDriverId == d.id }
    }

    private func activeTripForDriver(_ d: User) -> Trip? {
        trips.first { $0.driverId == d.id && ($0.tripStatus == .assigned || $0.tripStatus == .started || $0.tripStatus == .inProgress) }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    filterChipsSection
                    
                    if drivers.isEmpty && isLoading {
                        VStack {
                            Spacer()
                            ProgressView("Syncing drivers...")
                                .tint(AppTheme.Brand.royalBlue)
                                .foregroundStyle(AppTheme.Text.secondary)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Spacer()
                        }
                        .frame(minHeight: 200)
                    } else if filteredDrivers.isEmpty {
                        Group {
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
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredDrivers) { driver in
                                driverCard(driver)
                                    .opacity(cardAnimations[driver.id] == true ? 1 : 0)
                                    .offset(y: cardAnimations[driver.id] == true ? 0 : 30)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
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
        .task {
            triggerCardAnimations()
            while !Task.isCancelled {
                await syncDrivers()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .onChange(of: filteredDrivers.count) { triggerCardAnimations() }
    }

    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DriverStatusFilter.allCases) { filter in
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
    }

    private func countForFilter(_ filter: DriverStatusFilter) -> Int {
        switch filter {
        case .all: return drivers.count
        case .online: return drivers.filter { $0.isActive }.count
        case .offline: return drivers.filter { !$0.isActive }.count
        }
    }

    private func driverCard(_ driver: User) -> some View {
        HStack(spacing: 16) {
            NavigationLink(destination: DriverHistoryView(driver: driver)) {
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

                    
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

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
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.Glass.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private func activeStatusBadge(isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isActive ? Color.green : Color.gray)
            Text(isActive ? "Active" : "Inactive")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.3)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundColor(isActive ? .green : .gray)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isActive ? Color.green.opacity(0.08) : Color.gray.opacity(0.08))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func triggerCardAnimations() {
        for (index, driver) in filteredDrivers.enumerated() {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.08 + 0.15)) {
                cardAnimations[driver.id] = true
            }
        }
    }

    private func syncDrivers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dbDrivers = try await SupabaseManager.shared.fetchDrivers()
            await MainActor.run {
                for dbd in dbDrivers {
                    if let localDriver = allUsers.first(where: { $0.id == dbd.id }) {
                        localDriver.fullName = dbd.name
                        localDriver.email = dbd.email
                        localDriver.phoneNumber = dbd.phoneNumber ?? ""
                        localDriver.role = dbd.role.asLocalRole
                        localDriver.isActive = dbd.isActive
                    } else {
                        let newDriver = dbd.asLocalUser
                        modelContext.insert(newDriver)
                    }
                }
                
                if SupabaseManager.shared.currentUser?.role == .fleetManager {
                    let remoteIds = Set(dbDrivers.map { $0.id })
                    let localDrivers = allUsers.filter { $0.role == .driver }
                    for localDriver in localDrivers {
                        if !remoteIds.contains(localDriver.id) {
                            modelContext.delete(localDriver)
                        }
                    }
                }
                
                try? modelContext.save()
            }
        } catch {
            print("Failed to sync drivers: \(error)")
        }
    }
}



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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if filteredStaff.isEmpty {
                        Group {
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
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredStaff) { staff in
                                staffCard(for: staff)
                                    .opacity(cardAnimations[staff.id] == true ? 1 : 0)
                                    .offset(y: cardAnimations[staff.id] == true ? 0 : 30)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .refreshable {
            await syncMaintenanceStaff()
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
        .onAppear {
            triggerCardAnimations()
            Task {
                await syncMaintenanceStaff()
            }
        }
        .onChange(of: filteredStaff.count) { triggerCardAnimations() }
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

    private func syncMaintenanceStaff() async {
        do {
            let dbStaff = try await SupabaseManager.shared.fetchMaintenancePersonnel()
            await MainActor.run {
                for dbs in dbStaff {
                    if let localStaff = allUsers.first(where: { $0.id == dbs.id }) {
                        localStaff.fullName = dbs.name
                        localStaff.email = dbs.email
                        localStaff.phoneNumber = dbs.phoneNumber ?? ""
                        localStaff.role = dbs.role.asLocalRole
                        localStaff.isActive = dbs.isActive
                    } else {
                        let newStaff = dbs.asLocalUser
                        modelContext.insert(newStaff)
                    }
                }
                
                if SupabaseManager.shared.currentUser?.role == .fleetManager {
                    let remoteIds = Set(dbStaff.map { $0.id })
                    let localStaff = allUsers.filter { $0.role == .maintenance }
                    for s in localStaff {
                        if !remoteIds.contains(s.id) {
                            modelContext.delete(s)
                        }
                    }
                }
                
                try? modelContext.save()
            }
        } catch {
            print("Failed to sync maintenance staff: \(error)")
        }
    }
}



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








enum TripCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case upcoming = "Upcoming"
    case completed = "Completed"

    var id: String { rawValue }
}



@available(iOS 26.0, *)
struct TripListView: View {

    @State private var searchText = ""
    @State private var selectedFilter: TripCategoryFilter = .all
    @State private var showAddTrip = false
    @State private var editingTrip: Trip? = nil
    @State private var appearAnimation = false
    @State private var cardAnimations: Set<UUID> = []
    @State private var isLoading = false

    init(initialFilter: TripCategoryFilter = .all) {
        _selectedFilter = State(initialValue: initialFilter)
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.scheduledStartTime, order: .reverse) private var allTrips: [Trip]
    @Query(sort: \User.fullName) private var allUsers: [User]

    private var filteredTrips: [Trip] {
        var trips = allTrips
        switch selectedFilter {
        case .all:
            break
        case .active:
            trips = trips.filter { $0.tripStatus == .started || $0.tripStatus == .inProgress }
        case .upcoming:
            trips = trips.filter { $0.tripStatus == .assigned }
        case .completed:
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
        case .completed:
            return allTrips.filter { $0.tripStatus == .completed || $0.tripStatus == .cancelled }.count
        }
    }

    private func driverName(for driverId: UUID) -> String? {
        allUsers.first(where: { $0.id == driverId && $0.role == UserRole.driver })?.fullName
    }

    var body: some View {
        NavigationStack {
            ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            VStack(spacing: 0) {
                filterChips.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 8)
                if allTrips.isEmpty && isLoading {
                    Spacer()
                    ProgressView("Syncing trips...")
                        .tint(AppTheme.Brand.royalBlue)
                        .foregroundStyle(AppTheme.Text.secondary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Spacer()
                } else if filteredTrips.isEmpty {
                    if searchText.isEmpty && selectedFilter == .all {
                        ContentUnavailableView {
                            Label("No Trips Yet", systemImage: "map.fill")
                        } description: {
                            Text("Schedule or dispatch your first trip.")
                        } actions: {
                            Button("Add Trip") { showAddTrip = true }
                                .buttonStyle(.borderedProminent).tint(AppTheme.Brand.royalBlue)
                        }
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                } else {
                    tripListContent
                }
            }
        }
        .refreshable {
            await syncTrips()
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appearAnimation = true }
            Task {
                await syncTrips()
            }
        }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TripCategoryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    let chipColor: Color = {
                        switch filter {
                        case .all:      return AppTheme.Brand.accent 
                        case .active:   return Color(red: 0.30, green: 0.70, blue: 0.46) 
                        case .upcoming: return Color(red: 0.15, green: 0.38, blue: 0.90) 
                        case .completed: return Color(red: 0.55, green: 0.58, blue: 0.62) 
                        }
                    }()
                    
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
                                    .background(isSelected ? Color.white.opacity(0.25) : chipColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(isSelected ? .white : chipColor)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(isSelected ? chipColor : chipColor.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(isSelected ? Color.clear : chipColor.opacity(0.2), lineWidth: 1))
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
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripCardView(
                            trip: trip,
                            driverName: driverName(for: trip.driverId),
                            accentColor: trip.tripStatus.badgeColor,
                            onEdit: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                editingTrip = trip
                            }
                        )
                    }
                    .buttonStyle(.plain)
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

    private func syncTrips() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dbTrips = try await SupabaseManager.shared.fetchTrips()
            await MainActor.run {
                for dbt in dbTrips {
                    if let localTrip = allTrips.first(where: { $0.id == dbt.id }) {
                        localTrip.vehicleId = dbt.vehicleId
                        localTrip.driverId = dbt.driverId
                        localTrip.startLocation = dbt.source
                        localTrip.endLocation = dbt.destination
                        localTrip.scheduledStartTime = dbt.startTime ?? Date()
                        localTrip.scheduledEndTime = dbt.endTime ?? Date().addingTimeInterval(7200)
                        localTrip.actualStartTime = dbt.startTime
                        localTrip.actualEndTime = dbt.endTime
                        localTrip.distanceKm = dbt.distance
                        localTrip.tripStatus = dbt.status.toLocalStatus
                        localTrip.notes = dbt.notes
                    } else {
                        modelContext.insert(dbt.asLocalTrip)
                    }
                }
                
                if SupabaseManager.shared.currentUser?.role == .fleetManager {
                    let remoteIds = Set(dbTrips.map { $0.id })
                    for localTrip in allTrips {
                        if !remoteIds.contains(localTrip.id) {
                            modelContext.delete(localTrip)
                        }
                    }
                }
                
                try? modelContext.save()
            }
        } catch {
            print("Failed to sync trips: \(error)")
        }
    }
}



@available(iOS 26.0, *)
struct TripCardView: View {
    let trip: Trip
    let driverName: String?
    let accentColor: Color
    let onEdit: () -> Void

    private static let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "dd MMM yyyy · hh:mm a"; return f }()
    private static let timeFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "hh:mm a"; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
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

            
            HStack(spacing: 0) {
                tripDetailCol(label: "DEPARTURE", value: Self.timeFmt.string(from: trip.scheduledStartTime), icon: "clock.fill")
                Spacer()
                tripDetailCol(label: "ARRIVAL",   value: Self.timeFmt.string(from: trip.scheduledEndTime),   icon: "clock.badge.checkmark.fill")
                Spacer()
                tripDetailCol(label: "DISTANCE",  value: String(format: "%.1f km", trip.distanceKm),         icon: "road.lanes")
            }

            
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
            Image(systemName: trip.tripStatus.badgeIcon)
                .font(.system(size: 10, weight: .bold))
            Text(trip.tripStatus.displayName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(trip.tripStatus.badgeColor)
        .clipShape(Capsule())
        .layoutPriority(1)
    }

    private func tripDetailCol(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(accentColor.opacity(0.6))
            Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.7)).tracking(0.8)
            Text(value).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.black)
        }
    }
}



@available(iOS 26.0, *)
struct AddTripStubView: View {
    @Environment(\.dismiss) private var dismiss
    private let tripBlue = AppTheme.Brand.royalBlue

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle().fill(tripBlue.opacity(0.08)).frame(width: 100, height: 100)
                        Image(systemName: "map.fill").font(.system(size: 38, weight: .medium))
                            .foregroundColor(tripBlue.opacity(0.5)).symbolEffect(.bounce)
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
                    Button("Cancel") { dismiss() }.foregroundColor(tripBlue)
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct EditTripStubView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    private let tripBlue = AppTheme.Brand.royalBlue

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle().fill(tripBlue.opacity(0.08)).frame(width: 100, height: 100)
                        Image(systemName: "pencil.and.list.clipboard").font(.system(size: 38, weight: .medium))
                            .foregroundColor(tripBlue.opacity(0.5)).symbolEffect(.bounce)
                    }
                    VStack(spacing: 8) {
                        Text("Edit Trip").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("Editing \(trip.tripCode)").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundColor(tripBlue)
                        Text("Trip editing form\ncoming soon.")
                            .font(.system(size: 14, design: .rounded)).foregroundColor(.gray).multilineTextAlignment(.center)
                    }
                    Spacer(); Spacer()
                }
            }
            .navigationTitle("Edit Trip").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(tripBlue)
                }
            }
        }
    }
}


// MARK: - Trip Detail View

@available(iOS 26.0, *)
struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var vehicles: [Vehicle]
    @Query private var users: [User]

    private var assignedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == trip.vehicleId })
    }

    private var assignedDriver: User? {
        users.first(where: { $0.id == trip.driverId })
    }

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // ── Map View ──────────────────────────────
                    mapCard
                    
                    // ── Route Info ────────────────────────────
                    routeInfoCard
                    
                    // ── Schedule details ──────────────────────
                    scheduleCard
                    
                    // ── Assignment Details ────────────────────
                    assignmentCard

                    // ── Distance & Instructions ────────────────
                    additionalInfoCard

                    Spacer().frame(height: 20)
                }
                .padding(16)
            }
        }
        .navigationTitle(trip.tripCode)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let startCoord = CLLocationCoordinate2D(latitude: trip.startLatitude, longitude: trip.startLongitude)
            let endCoord = CLLocationCoordinate2D(latitude: trip.endLatitude, longitude: trip.endLongitude)
            
            // Set up camera bounds to fit both points nicely
            let center = CLLocationCoordinate2D(
                latitude: (startCoord.latitude + endCoord.latitude) / 2.0,
                longitude: (startCoord.longitude + endCoord.longitude) / 2.0
            )
            let span = MKCoordinateSpan(
                latitudeDelta: abs(startCoord.latitude - endCoord.latitude) * 1.5 + 0.05,
                longitudeDelta: abs(startCoord.longitude - endCoord.longitude) * 1.5 + 0.05
            )
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    // MARK: - Map Card
    private var mapCard: some View {
        VStack(spacing: 0) {
            Map(position: $position) {
                Marker("Start", systemImage: "play.circle.fill", coordinate: CLLocationCoordinate2D(latitude: trip.startLatitude, longitude: trip.startLongitude))
                    .tint(.green)
                Marker("End", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: trip.endLatitude, longitude: trip.endLongitude))
                    .tint(.red)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }

    // MARK: - Route Info Card
    private var routeInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Route Details")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)

            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("START LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text(trip.startLocation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Text.primary)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "flag.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("END LOCATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Text.tertiary)
                    Text(trip.endLocation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Text.primary)
                }
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }

    // MARK: - Schedule Details Card
    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Schedule")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: trip.tripStatus.badgeIcon)
                        .font(.system(size: 10))
                    Text(trip.tripStatus.displayName)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trip.tripStatus.badgeColor)
                .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 16) {
                // Vertical Timeline Line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 2, height: 75)
                    
                    Circle()
                        .fill(trip.tripStatus == .completed ? Color.gray : Color.red)
                        .frame(width: 10, height: 10)
                }
                .padding(.top, 5)
                
                // Content Columns
                VStack(alignment: .leading, spacing: 20) {
                    // Departure Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEPARTURE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .tracking(0.8)
                        
                        Text(trip.scheduledStartTime.formatted(date: .long, time: .shortened))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                        
                        if let actualStart = trip.actualStartTime {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("Actual: \(actualStart.formatted(date: .long, time: .shortened))")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Text.secondary)
                            }
                        }
                    }
                    
                    // Arrival Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ARRIVAL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(trip.tripStatus == .completed ? .gray : .red)
                            .tracking(0.8)
                        
                        Text(trip.scheduledEndTime.formatted(date: .long, time: .shortened))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Text.primary)
                        
                        if let actualEnd = trip.actualEndTime {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(trip.tripStatus == .completed ? .gray : .red)
                                Text("Actual: \(actualEnd.formatted(date: .long, time: .shortened))")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Text.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }

    // MARK: - Assignment Card
    private var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Assignments")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)

            if let vehicle = assignedVehicle {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(vehicle.vehicleType.iconColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: vehicle.vehicleType.icon)
                            .font(.system(size: 18))
                            .foregroundColor(vehicle.vehicleType.iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("VEHICLE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.Text.primary)
                        Text("VIN: \(vehicle.vinNumber) · \(vehicle.year)")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }
            } else {
                Text("⚠️ No assigned vehicle found")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Brand.accent)
            }

            Divider()

            if let driver = assignedDriver {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Brand.royalBlue.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Text(initials(for: driver.fullName))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASSIGNED DRIVER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.Text.tertiary)
                        Text(driver.fullName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.Text.primary)
                        Text("\(driver.email) · \(driver.phoneNumber)")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }
            } else {
                Text("⚠️ No assigned driver found")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Brand.accent)
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }

    // MARK: - Distance & Special Instructions Card
    private var additionalInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Additional Information")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)

            TripDetailRow(label: "Total Distance", value: String(format: "%.1f km", trip.distanceKm))

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("SPECIAL INSTRUCTIONS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary)
                
                Text(trip.notes ?? "No special instructions provided.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineSpacing(3)
            }
        }
        .padding(16)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }

    private func initials(for name: String) -> String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

private struct TripDetailRow: View {
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
