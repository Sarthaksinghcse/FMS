//
//  EditVehicleView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Reusable Custom Text Field
struct CustomAddTextField: View {
    let label: String
    let placeholder: String
    let icon: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(isFocused ? AppTheme.Brand.primary : AppTheme.Text.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(isFocused ? AppTheme.Brand.primary : AppTheme.Text.tertiary)

                TextField(placeholder, text: $text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                    .focused($isFocused)
                    .keyboardType(keyboardType)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.02))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? AppTheme.Brand.primary : AppTheme.Glass.border, lineWidth: isFocused ? 1.5 : 1)
            )
        }
    }
}

// MARK: - Edit Vehicle View Model
@MainActor
final class EditVehicleViewModel: ObservableObject {
    private let vehicle: Vehicle
    
    @Published var registrationNumber: String = ""
    @Published var vinNumber: String = ""
    @Published var make: String = ""
    @Published var model: String = ""
    @Published var yearString: String = ""
    @Published var odometerString: String = ""
    
    @Published var vehicleType: VehicleType = .truck
    @Published var fuelType: FuelType = .diesel
    @Published var status: VehicleStatus = .active
    
    @Published var errorMessage: String? = nil
    @Published var isSaveSuccessful: Bool = false
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        self.registrationNumber = vehicle.registrationNumber
        self.vinNumber = vehicle.vinNumber
        self.make = vehicle.make
        self.model = vehicle.model
        self.yearString = String(vehicle.year)
        self.odometerString = String(vehicle.odometerReading)
        self.vehicleType = vehicle.vehicleType
        self.fuelType = vehicle.fuelType
        self.status = vehicle.status
    }
    
    /// Validates forms inputs and returns true if valid, else sets errorMessage
    func validate() -> Bool {
        errorMessage = nil
        
        let cleanedReg = registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedVin = vinNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanedReg.isEmpty else {
            errorMessage = "Registration number is required."
            return false
        }
        
        guard !cleanedVin.isEmpty else {
            errorMessage = "VIN is required."
            return false
        }
        
        guard !cleanedMake.isEmpty else {
            errorMessage = "Manufacturer (Make) is required."
            return false
        }
        
        guard !cleanedModel.isEmpty else {
            errorMessage = "Vehicle model is required."
            return false
        }
        
        guard let year = Int(yearString), year >= 1900 && year <= Calendar.current.component(.year, from: Date()) + 1 else {
            errorMessage = "Please enter a valid manufacture year."
            return false
        }
        
        guard let odometer = Double(odometerString), odometer >= 0 else {
            errorMessage = "Odometer reading must be a positive number."
            return false
        }
        
        return true
    }
    
    /// Saves the edits into the vehicle object in SwiftData.
    /// BACKEND DEVS: Add your cloud database/Supabase API sync/update calls inside this function.
    func saveEdits(context: ModelContext) -> Bool {
        guard validate() else { return false }
        
        let cleanedReg = registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanedVin = vinNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanedMake = make.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let year = Int(yearString) ?? vehicle.year
        let odometer = Double(odometerString) ?? vehicle.odometerReading
        
        // Update SwiftData properties
        vehicle.registrationNumber = cleanedReg
        vehicle.vinNumber = cleanedVin
        vehicle.make = cleanedMake
        vehicle.model = cleanedModel
        vehicle.year = year
        vehicle.vehicleType = vehicleType
        vehicle.fuelType = fuelType
        vehicle.odometerReading = odometer
        vehicle.status = status
        vehicle.updatedAt = Date()
        
        do {
            try context.save()
            
            // Trigger feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            isSaveSuccessful = true
            return true
        } catch {
            errorMessage = "Failed to update vehicle: \(error.localizedDescription)"
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return false
        }
    }
    
    /// Deletes the vehicle.
    /// BACKEND DEVS: Hook up deletion API call here.
    func deleteVehicle(context: ModelContext) -> Bool {
        context.delete(vehicle)
        do {
            try context.save()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            return true
        } catch {
            errorMessage = "Failed to delete vehicle: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Edit Vehicle View
struct EditVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: EditVehicleViewModel
    @State private var showDeleteConfirmation = false
    
    init(vehicle: Vehicle) {
        _viewModel = StateObject(wrappedValue: EditVehicleViewModel(vehicle: vehicle))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(spacing: 16) {
                            // Basic Information section
                            VStack(alignment: .leading, spacing: 14) {
                                sectionTitle("Basic Information")
                                
                                CustomAddTextField(label: "Registration Number", placeholder: "e.g. KA-01-AB-1234", icon: "number", text: $viewModel.registrationNumber)
                                    .textInputAutocapitalization(.characters)
                                
                                CustomAddTextField(label: "VIN", placeholder: "17-digit code", icon: "barcode.viewfinder", text: $viewModel.vinNumber)
                                    .textInputAutocapitalization(.characters)
                                
                                CustomAddTextField(label: "Make / Manufacturer", placeholder: "e.g. Tata", icon: "building.2.fill", text: $viewModel.make)
                                
                                CustomAddTextField(label: "Model", placeholder: "e.g. Ace Gold", icon: "car.side.fill", text: $viewModel.model)
                            }
                            .padding(18)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                            
                            // Specifications section
                            VStack(alignment: .leading, spacing: 16) {
                                sectionTitle("Specifications")
                                
                                CustomAddTextField(label: "Year of Manufacture", placeholder: "e.g. 2024", icon: "calendar", text: $viewModel.yearString, keyboardType: .numberPad)
                                
                                CustomAddTextField(label: "Current Odometer (km)", placeholder: "e.g. 12500", icon: "gauge.with.needle.fill", text: $viewModel.odometerString, keyboardType: .decimalPad)
                                
                                Divider().background(Color.black.opacity(0.06))
                                
                                // Vehicle Type Grid Selector
                                typeSelector
                                
                                Divider().background(Color.black.opacity(0.06))
                                
                                // Fuel Type Picker
                                fuelSelector
                                
                                Divider().background(Color.black.opacity(0.06))
                                
                                // Status Selector
                                statusSelector
                            }
                            .padding(18)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                            
                            // Danger Zone
                            VStack(alignment: .leading, spacing: 12) {
                                sectionTitle("Danger Zone")
                                    .foregroundColor(AppTheme.Status.danger)
                                
                                Button {
                                    showDeleteConfirmation = true
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                        Text("Delete Vehicle")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                        Spacer()
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(AppTheme.Status.danger)
                                    .cornerRadius(10)
                                }
                            }
                            .padding(18)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Edit Vehicle")
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
                    Button("Save") {
                        if viewModel.saveEdits(context: modelContext) {
                            dismiss()
                        }
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .font(.system(.body, design: .rounded, weight: .bold))
                }
            }
            .alert("Delete Vehicle", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if viewModel.deleteVehicle(context: modelContext) {
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently delete this vehicle? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.Brand.primary)
            .padding(.bottom, 2)
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
    
    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle Category")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Text.secondary)
            
            HStack(spacing: 8) {
                ForEach([VehicleType.truck, .van, .car, .bike], id: \.self) { type in
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        viewModel.vehicleType = type
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                            Text(type.displayName)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(viewModel.vehicleType == type ? .white : type.iconColor)
                        .background(viewModel.vehicleType == type ? type.iconColor : type.iconColor.opacity(0.08))
                        .cornerRadius(AppTheme.Radius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var fuelSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fuel Type")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Text.secondary)
            
            Picker("Fuel Type", selection: $viewModel.fuelType) {
                Text("Petrol").tag(FuelType.petrol)
                Text("Diesel").tag(FuelType.diesel)
                Text("Electric").tag(FuelType.electric)
                Text("Hybrid").tag(FuelType.hybrid)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var statusSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle Status")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Text.secondary)
            
            Picker("Vehicle Status", selection: $viewModel.status) {
                Text("Active").tag(VehicleStatus.active)
                Text("Inactive").tag(VehicleStatus.inactive)
                Text("In Maintenance").tag(VehicleStatus.inMaintenance)
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Brand.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.02))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.Glass.border, lineWidth: 1)
            )
        }
    }
}
