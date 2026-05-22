//
//  VehicleListView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Vehicle Status Filter

enum VehicleStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case inactive = "Inactive"
    case inMaintenance = "In Maintenance"
    
    var id: String { rawValue }
    
    var vehicleStatus: VehicleStatus? {
        switch self {
        case .all: return nil
        case .active: return .active
        case .inactive: return .inactive
        case .inMaintenance: return .inMaintenance
        }
    }
    
    var chipColor: Color {
        switch self {
        case .all: return AppTheme.Brand.royalBlue
        case .active: return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .inactive: return AppTheme.Brand.accent
        case .inMaintenance: return Color(red: 0.85, green: 0.25, blue: 0.25)
        }
    }
}

// MARK: - Vehicle Status UI Helper

extension VehicleStatus {
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .inMaintenance: return "Maintenance"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .active: return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .inactive: return AppTheme.Brand.accent
        case .inMaintenance: return Color(red: 0.85, green: 0.25, blue: 0.25)
        }
    }
    
    var statusIcon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .inactive: return "pause.circle.fill"
        case .inMaintenance: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Vehicle Type UI Helper

extension VehicleType {
    var displayName: String {
        switch self {
        case .truck: return "Truck"
        case .van: return "Van"
        case .car: return "Car"
        case .bike: return "Bike"
        }
    }
    
    var icon: String {
        switch self {
        case .truck: return "truck.box.fill"
        case .van: return "bus.fill"
        case .car: return "car.fill"
        case .bike: return "bicycle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .truck: return AppTheme.Brand.royalBlue
        case .van: return Color(red: 0.58, green: 0.39, blue: 0.87)
        case .car: return Color(red: 0.30, green: 0.70, blue: 0.46)
        case .bike: return AppTheme.Brand.accent
        }
    }
}

// MARK: - Fuel Type UI Helper

extension FuelType {
    var displayName: String {
        switch self {
        case .petrol: return "Petrol"
        case .diesel: return "Diesel"
        case .electric: return "Electric"
        case .hybrid: return "Hybrid"
        }
    }
    
    var icon: String {
        switch self {
        case .petrol: return "fuelpump.fill"
        case .diesel: return "fuelpump.fill"
        case .electric: return "bolt.fill"
        case .hybrid: return "leaf.fill"
        }
    }
}

// MARK: - Vehicle List View

@available(iOS 26.0, *)
struct VehicleListView: View {
    
    // MARK: - SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    
    // MARK: - State
    @State private var searchText = ""
    @State private var selectedFilter: VehicleStatusFilter = .all
    @State private var showAddVehicle = false
    @State private var editingVehicle: Vehicle?
    @State private var appearAnimation = false
    @State private var cardsAppeared: Set<UUID> = []
    
    // MARK: - Filtered Vehicles
    private var filteredVehicles: [Vehicle] {
        vehicles.filter { vehicle in
            // Status filter
            let matchesStatus: Bool
            if let status = selectedFilter.vehicleStatus {
                matchesStatus = vehicle.status == status
            } else {
                matchesStatus = true
            }
            
            // Search filter
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.lowercased()
                matchesSearch = vehicle.registrationNumber.lowercased().contains(query) ||
                    vehicle.make.lowercased().contains(query) ||
                    vehicle.model.lowercased().contains(query)
            }
            
            return matchesStatus && matchesSearch
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Filter Chips
                filterChipsSection
                
                // MARK: - Vehicle List / Empty State
                if filteredVehicles.isEmpty {
                    if searchText.isEmpty && selectedFilter == .all {
                        ContentUnavailableView {
                            Label("No Vehicles Yet", systemImage: "car.fill")
                        } description: {
                            Text("Add your first vehicle to the fleet.")
                        } actions: {
                            Button("Add Vehicle") {
                                showAddVehicle = true
                            }
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
        .navigationTitle("Vehicle Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search registration, make, model...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showAddVehicle = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleView()
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $editingVehicle) { vehicle in
            EditVehicleView(vehicle: vehicle)
                .environment(\.modelContext, modelContext)
        }
    }
    
    
    
    // MARK: - Filter Chips
    
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
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
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
    
    // MARK: - Vehicle List
    
    private var vehicleListSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(filteredVehicles) { vehicle in
                    let index: Int = filteredVehicles.firstIndex(where: { $0.id == vehicle.id }) ?? 0
                    let delay: Double = Double(index) * 0.07
                    VehicleCardView(vehicle: vehicle) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        editingVehicle = vehicle
                    }
                    .opacity(cardsAppeared.contains(vehicle.id) ? 1 : 0)
                    .offset(y: cardsAppeared.contains(vehicle.id) ? 0 : 30)
                    .onAppear {
                        withAnimation(
                            Animation.spring(response: 0.6, dampingFraction: 0.8)
                            .delay(delay)
                        ) {
                            _ = cardsAppeared.insert(vehicle.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Space for FAB
            .padding(.top, 4)
        }
    }
    
    // MARK: - Empty State
    
    
    
    // MARK: - Helpers
    
    private func countForFilter(_ filter: VehicleStatusFilter) -> Int {
        if filter == .all { return vehicles.count }
        guard let status = filter.vehicleStatus else { return 0 }
        return vehicles.filter { $0.status == status }.count
    }
}

// MARK: - Filter Chip View

@available(iOS 26.0, *)
struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        let badgeBgColor: Color = isSelected ? Color.white.opacity(0.25) : color.opacity(0.12)
        let chipBgColor: Color = isSelected ? color : color.opacity(0.08)
        let strokeColor: Color = isSelected ? color : color.opacity(0.2)
        let fgColor: Color = isSelected ? .white : color
        
        return Button(action: onTap) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeBgColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundColor(fgColor)
            .background(chipBgColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Vehicle Card View

@available(iOS 26.0, *)
struct VehicleCardView: View {
    let vehicle: Vehicle
    let onEdit: () -> Void
    
    private var formattedOdometer: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: vehicle.odometerReading)) ?? "\(Int(vehicle.odometerReading))"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            
            // MARK: Vehicle Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [vehicle.vehicleType.iconColor.opacity(0.8), vehicle.vehicleType.iconColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: vehicle.vehicleType.iconColor.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: vehicle.vehicleType.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // MARK: Vehicle Details
            VStack(alignment: .leading, spacing: 6) {
                
                // Registration + Status
                HStack(alignment: .center) {
                    Text(vehicle.registrationNumber)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: vehicle.status.statusIcon)
                            .font(.system(size: 9))
                        Text(vehicle.status.displayName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.3)
                    }
                    .foregroundColor(vehicle.status.statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(vehicle.status.statusColor.opacity(0.10))
                    .clipShape(Capsule())
                }
                
                // Make, Model, Year
                Text("\(vehicle.make) \(vehicle.model) · \(String(vehicle.year))")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
                
                // Type + Fuel Badges + Odometer
                HStack(spacing: 8) {
                    // Vehicle Type Badge
                    HStack(spacing: 4) {
                        Image(systemName: vehicle.vehicleType.icon)
                            .font(.system(size: 9))
                        Text(vehicle.vehicleType.displayName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(vehicle.vehicleType.iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vehicle.vehicleType.iconColor.opacity(0.08))
                    .clipShape(Capsule())
                    
                    // Fuel Type Badge
                    HStack(spacing: 4) {
                        Image(systemName: vehicle.fuelType.icon)
                            .font(.system(size: 9))
                        Text(vehicle.fuelType.displayName)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Odometer
                    HStack(spacing: 3) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 9))
                        Text("\(formattedOdometer) km")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.gray.opacity(0.7))
                }
            }
            
            // MARK: Edit Button
            Button {
                onEdit()
            } label: {
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
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.Glass.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Add Vehicle Stub View

@available(iOS 26.0, *)
struct AddVehicleStubView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(AppTheme.Brand.royalBlue.opacity(0.08))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(AppTheme.Brand.royalBlue.opacity(0.5))
                            .symbolEffect(.bounce)
                    }
                    
                    Text("Add New Vehicle")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text("Vehicle creation form will\nbe implemented here.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    
                    Spacer()
                }
            }
            .navigationTitle("New Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
        }
    }
}

// MARK: - Edit Vehicle Stub View

@available(iOS 26.0, *)
struct EditVehicleStubView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(vehicle.vehicleType.iconColor.opacity(0.08))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(vehicle.vehicleType.iconColor.opacity(0.5))
                            .symbolEffect(.bounce)
                    }
                    
                    Text("Edit Vehicle")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Text("\(vehicle.registrationNumber)\n\(vehicle.make) \(vehicle.model) · \(String(vehicle.year))")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    
                    Spacer()
                }
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Vehicle.self, configurations: config)
    
    // Sample vehicles
    let sampleVehicles: [Vehicle] = [
        Vehicle(
            registrationNumber: "KA-01-AB-1234",
            vinNumber: "1HGCM82633A004352",
            make: "Tata",
            model: "Ace Gold",
            year: 2023,
            vehicleType: .truck,
            fuelType: .diesel,
            odometerReading: 45_230,
            status: .active
        ),
        Vehicle(
            registrationNumber: "MH-02-CD-5678",
            vinNumber: "2HGCM82633A004353",
            make: "Maruti",
            model: "Eeco",
            year: 2022,
            vehicleType: .van,
            fuelType: .petrol,
            odometerReading: 32_100,
            status: .active
        ),
        Vehicle(
            registrationNumber: "DL-03-EF-9012",
            vinNumber: "3HGCM82633A004354",
            make: "Tata",
            model: "Nexon EV",
            year: 2024,
            vehicleType: .car,
            fuelType: .electric,
            odometerReading: 12_800,
            status: .inMaintenance
        ),
        Vehicle(
            registrationNumber: "TN-04-GH-3456",
            vinNumber: "4HGCM82633A004355",
            make: "Mahindra",
            model: "Bolero Pickup",
            year: 2021,
            vehicleType: .truck,
            fuelType: .diesel,
            odometerReading: 78_500,
            status: .inactive
        ),
        Vehicle(
            registrationNumber: "KA-05-IJ-7890",
            vinNumber: "5HGCM82633A004356",
            make: "Hero",
            model: "Splendor Plus",
            year: 2023,
            vehicleType: .bike,
            fuelType: .petrol,
            odometerReading: 8_200,
            status: .active
        ),
        Vehicle(
            registrationNumber: "GJ-06-KL-2345",
            vinNumber: "6HGCM82633A004357",
            make: "Toyota",
            model: "Hyryder Hybrid",
            year: 2024,
            vehicleType: .car,
            fuelType: .hybrid,
            odometerReading: 5_600,
            status: .active
        )
    ]
    
    for vehicle in sampleVehicles {
        container.mainContext.insert(vehicle)
    }
    
    return NavigationStack {
        VehicleListView()
    }
    .modelContainer(container)
}
