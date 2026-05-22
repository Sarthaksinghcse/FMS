//
//  AssignDriverView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Assign Driver View Model
@MainActor
final class AssignDriverViewModel: ObservableObject {
    @Published var selectedVehicleId: UUID? = nil
    @Published var selectedDriverId: UUID? = nil
    
    @Published var errorMessage: String? = nil
    @Published var isSaveSuccessful: Bool = false
    
    /// Assigns the selected driver to the selected vehicle.
    /// Clears any other vehicle's assignment to the same driver to maintain a 1-to-1 mapping.
    /// BACKEND DEVS: Add your cloud database/Supabase API sync calls inside this function.
    func assignDriver(context: ModelContext, vehicles: [Vehicle], drivers: [User]) -> Bool {
        errorMessage = nil
        
        guard let vehicleId = selectedVehicleId else {
            errorMessage = "Please select a vehicle."
            return false
        }
        
        guard let driverId = selectedDriverId else {
            errorMessage = "Please select a driver."
            return false
        }
        
        guard let selectedVehicle = vehicles.first(where: { $0.id == vehicleId }) else {
            errorMessage = "Selected vehicle not found."
            return false
        }
        
        guard let selectedDriver = drivers.first(where: { $0.id == driverId }) else {
            errorMessage = "Selected driver not found."
            return false
        }
        
        // 1. Clear this driver from any other vehicles they were assigned to
        for vehicle in vehicles {
            if vehicle.assignedDriverId == selectedDriver.id && vehicle.id != selectedVehicle.id {
                vehicle.assignedDriverId = nil
                vehicle.updatedAt = Date()
            }
        }
        
        // 2. Set the driver for the selected vehicle
        selectedVehicle.assignedDriverId = selectedDriver.id
        selectedVehicle.updatedAt = Date()
        
        do {
            try context.save()
            
            // Trigger haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            isSaveSuccessful = true
            return true
        } catch {
            errorMessage = "Failed to save assignment: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
}

// MARK: - Assign Driver View
struct AssignDriverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    
    @StateObject private var viewModel = AssignDriverViewModel()
    
    @State private var vehicleSearchQuery = ""
    @State private var driverSearchQuery = ""
    
    // Filtered lists
    private var filteredVehicles: [Vehicle] {
        if vehicleSearchQuery.isEmpty {
            return vehicles
        } else {
            let query = vehicleSearchQuery.lowercased()
            return vehicles.filter {
                $0.registrationNumber.lowercased().contains(query) ||
                $0.make.lowercased().contains(query) ||
                $0.model.lowercased().contains(query)
            }
        }
    }
    
    private var drivers: [User] {
        allUsers.filter { $0.role == UserRole.driver }
    }
    
    private var filteredDrivers: [User] {
        if driverSearchQuery.isEmpty {
            return drivers
        } else {
            let query = driverSearchQuery.lowercased()
            return drivers.filter {
                $0.fullName.lowercased().contains(query) ||
                $0.email.lowercased().contains(query)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 16)
                    }
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // MARK: Vehicle Selection Section
                            VStack(alignment: .leading, spacing: 12) {
                                sectionTitle("1. Select Vehicle", icon: "truck.box.fill", color: AppTheme.Brand.primary)
                                
                                searchField(placeholder: "Search registration, make, model...", text: $vehicleSearchQuery)
                                
                                if filteredVehicles.isEmpty {
                                    emptyStateText("No matching vehicles found")
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(filteredVehicles) { vehicle in
                                                let isSelected = viewModel.selectedVehicleId == vehicle.id
                                                let driverName = getAssignedDriverName(for: vehicle)
                                                
                                                Button {
                                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                                    impact.impactOccurred()
                                                    viewModel.selectedVehicleId = vehicle.id
                                                } label: {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        HStack {
                                                            Image(systemName: vehicle.vehicleType.icon)
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundColor(isSelected ? .white : vehicle.vehicleType.iconColor)
                                                            
                                                            Spacer()
                                                            
                                                            if isSelected {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .foregroundColor(.white)
                                                            }
                                                        }
                                                        
                                                        Text(vehicle.registrationNumber)
                                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                                            .foregroundColor(isSelected ? .white : .black)
                                                        
                                                        Text("\(vehicle.make) \(vehicle.model)")
                                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                                                            .lineLimit(1)
                                                        
                                                        Divider()
                                                            .background(isSelected ? Color.white.opacity(0.3) : Color.black.opacity(0.06))
                                                            .padding(.vertical, 2)
                                                        
                                                        Text(driverName == nil ? "Unassigned" : "Driver: \(driverName!)")
                                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                            .foregroundColor({
                                                                if isSelected { return Color.white.opacity(0.9) }
                                                                return driverName == nil ? AppTheme.Brand.accent : AppTheme.Status.success
                                                            }())
                                                            .lineLimit(1)
                                                    }
                                                    .padding(14)
                                                    .frame(width: 150, height: 130)
                                                    .background(isSelected ? AppTheme.Brand.primary : AppTheme.Background.card)
                                                    .cornerRadius(14)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 14)
                                                            .stroke(isSelected ? Color.clear : AppTheme.Glass.border, lineWidth: 1)
                                                    )
                                                    .shadow(color: isSelected ? AppTheme.Brand.primary.opacity(0.2) : AppTheme.Shadow.card, radius: 6, x: 0, y: 3)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(16)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                            
                            // MARK: Driver Selection Section
                            VStack(alignment: .leading, spacing: 12) {
                                sectionTitle("2. Select Driver", icon: "person.fill.checkmark", color: Color(red: 0.30, green: 0.70, blue: 0.46))
                                
                                searchField(placeholder: "Search driver by name...", text: $driverSearchQuery)
                                
                                if filteredDrivers.isEmpty {
                                    emptyStateText("No drivers available")
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(filteredDrivers) { driver in
                                            let isSelected = viewModel.selectedDriverId == driver.id
                                            let currentVehicle = getAssignedVehicleDetails(for: driver)
                                            
                                            Button {
                                                let impact = UIImpactFeedbackGenerator(style: .light)
                                                impact.impactOccurred()
                                                viewModel.selectedDriverId = driver.id
                                            } label: {
                                                HStack(spacing: 14) {
                                                    // Driver Avatar Initials
                                                    ZStack {
                                                        Circle()
                                                            .fill(isSelected ? .white.opacity(0.2) : Color(red: 0.30, green: 0.70, blue: 0.46).opacity(0.12))
                                                            .frame(width: 44, height: 44)
                                                        
                                                        Text(getInitials(driver.fullName))
                                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                                            .foregroundColor(isSelected ? .white : Color(red: 0.30, green: 0.70, blue: 0.46))
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 3) {
                                                        Text(driver.fullName)
                                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                                            .foregroundColor(isSelected ? .white : .black)
                                                        
                                                        Text(currentVehicle == nil ? "Available" : "Assigned: \(currentVehicle!)")
                                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                                            .foregroundColor(isSelected ? .white.opacity(0.8) : (currentVehicle == nil ? AppTheme.Status.success : .gray))
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if isSelected {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .font(.system(size: 18))
                                                    }
                                                }
                                                .padding(12)
                                                .background(isSelected ? Color(red: 0.30, green: 0.70, blue: 0.46) : Color.black.opacity(0.01))
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(isSelected ? Color.clear : AppTheme.Glass.border.opacity(0.5), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                }
                            }
                            .padding(16)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Assign Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .font(.system(.body, design: .rounded))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Assign") {
                        if viewModel.assignDriver(context: modelContext, vehicles: vehicles, drivers: drivers) {
                            dismiss()
                        }
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .font(.system(.body, design: .rounded, weight: .bold))
                }
            }
        }
    }
    
    // MARK: - Helpers & Subviews
    
    private func sectionTitle(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.black)
        }
    }
    
    private func searchField(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray.opacity(0.6))
                .font(.system(size: 14))
            
            TextField(placeholder, text: text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.Glass.border, lineWidth: 1)
        )
    }
    
    private func emptyStateText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppTheme.Status.danger)
                .font(.system(size: 16))
            
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
        }
        .padding(14)
        .background(AppTheme.Status.danger.opacity(0.08))
        .cornerRadius(AppTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.Status.danger.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func getAssignedDriverName(for vehicle: Vehicle) -> String? {
        guard let driverId = vehicle.assignedDriverId else { return nil }
        return allUsers.first(where: { $0.id == driverId })?.fullName
    }
    
    private func getAssignedVehicleDetails(for driver: User) -> String? {
        guard let vehicle = vehicles.first(where: { $0.assignedDriverId == driver.id }) else { return nil }
        return "\(vehicle.registrationNumber) (\(vehicle.make))"
    }
    
    private func getInitials(_ name: String) -> String {
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        let initials = components.compactMap { $0.first }
        return String(initials.prefix(2)).uppercased()
    }
}
