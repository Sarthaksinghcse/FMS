//
//  VehicleFormView.swift
//  FMS
//
//  Full Add / Edit / Delete vehicle forms for the Fleet Manager's
//  Vehicle Management screen. Replaces the previous stub views.
//

import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Add Vehicle Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct AddVehicleFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Form State ────────────────────────────────────────────────────────────
    @State private var registrationNumber = ""
    @State private var vinNumber          = ""
    @State private var make               = ""
    @State private var model              = ""
    @State private var yearText           = ""
    @State private var vehicleType        = VehicleType.truck
    @State private var fuelType           = FuelType.diesel
    @State private var odometerText       = ""
    @State private var lastServiceDate    = Date()
    @State private var nextServiceDate    = Date()
    @State private var insuranceExpiryDate = Date()

    // ── Validation ────────────────────────────────────────────────────────────
    @State private var showValidationAlert  = false
    @State private var validationMessage    = ""
    @State private var saveSuccess          = false

    // ── Focus ─────────────────────────────────────────────────────────────────
    @FocusState private var focusedField: VehicleFocusField?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Hero header ──

                        // ── Form sections ──────────────────────────────────
                        formSection(title: "Identity", icon: "doc.text.fill", iconColor: AppTheme.Brand.royalBlue) {
                            VehicleFormField(label: "Registration No.", placeholder: "e.g. KA-01-AB-1234",
                                            text: $registrationNumber, keyboardType: .default, focus: $focusedField, tag: .registration)
                            FormDivider()
                            VehicleFormField(label: "VIN Number", placeholder: "17-character VIN",
                                            text: $vinNumber, keyboardType: .default, focus: $focusedField, tag: .vin)
                        }

                        formSection(title: "Specifications", icon: "gearshape.2.fill", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)) {
                            VehicleFormField(label: "Make", placeholder: "e.g. Tata, Mahindra",
                                            text: $make, keyboardType: .default, focus: $focusedField, tag: .make)
                            FormDivider()
                            VehicleFormField(label: "Model", placeholder: "e.g. Ace Gold",
                                            text: $model, keyboardType: .default, focus: $focusedField, tag: .model)
                            FormDivider()
                            VehicleFormField(label: "Year", placeholder: "e.g. 2023",
                                            text: $yearText, keyboardType: .numberPad, focus: $focusedField, tag: .year)

                            FormDivider()
                            SegmentPickerRow(label: "Type", options: VehicleType.allCases, selection: $vehicleType) { t in
                                t.displayName
                            }

                            FormDivider()
                            SegmentPickerRow(label: "Fuel", options: FuelType.allCases, selection: $fuelType) { f in
                                f.displayName
                            }
                        }

                        formSection(title: "Odometer", icon: "gauge.with.needle.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            VehicleFormField(label: "Odometer (km)", placeholder: "e.g. 45230",
                                            text: $odometerText, keyboardType: .decimalPad, focus: $focusedField, tag: .odometer)
                        }

                        formSection(title: "Dates", icon: "calendar", iconColor: AppTheme.Brand.accent) {
                            DatePickerRow(label: "Last Service Date", date: $lastServiceDate)
                            FormDivider()
                            DatePickerRow(label: "Next Service Date", date: $nextServiceDate)
                            FormDivider()
                            DatePickerRow(label: "Insurance Expiry", date: $insuranceExpiryDate)
                        }

                        // ── Save Button ────────────────────────────────────
                        saveButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert("Vehicle Added", isPresented: $saveSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(registrationNumber) has been added to your fleet.")
            }
        }
    }


    // MARK: Save Button

    private var saveButton: some View {
        Button {
            saveVehicle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Save Vehicle")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.primaryDeep],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Save Action

    private func saveVehicle() {
        // Validation
        guard !registrationNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Registration number is required."; showValidationAlert = true; return
        }
        guard !vinNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "VIN number is required."; showValidationAlert = true; return
        }
        guard !make.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Vehicle make is required."; showValidationAlert = true; return
        }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Vehicle model is required."; showValidationAlert = true; return
        }
        guard let year = Int(yearText), year >= 1980, year <= Calendar.current.component(.year, from: Date()) + 1 else {
            validationMessage = "Please enter a valid year (1980–present)."; showValidationAlert = true; return
        }
        let odometer = Double(odometerText) ?? 0

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let vehicle = Vehicle(
            registrationNumber: registrationNumber.trimmingCharacters(in: .whitespaces).uppercased(),
            vinNumber:          vinNumber.trimmingCharacters(in: .whitespaces).uppercased(),
            make:               make.trimmingCharacters(in: .whitespaces),
            model:              model.trimmingCharacters(in: .whitespaces),
            year:               year,
            vehicleType:        vehicleType,
            fuelType:           fuelType,
            odometerReading:    odometer,
            status:             .active,
            lastServiceDate:    lastServiceDate,
            nextServiceDate:    nextServiceDate,
            insuranceExpiryDate:insuranceExpiryDate
        )

        modelContext.insert(vehicle)
        try? modelContext.save()
        saveSuccess = true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Edit Vehicle Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct EditVehicleFormView: View {

    let vehicle: Vehicle

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Form State ────────────────────────────────────────────────────────────
    @State private var registrationNumber: String
    @State private var vinNumber: String
    @State private var make: String
    @State private var model: String
    @State private var yearText: String
    @State private var vehicleType: VehicleType
    @State private var fuelType: FuelType
    @State private var odometerText: String
    @State private var status: VehicleStatus
    @State private var lastServiceDate: Date
    @State private var nextServiceDate: Date
    @State private var insuranceExpiryDate: Date

    @State private var showValidationAlert = false
    @State private var validationMessage   = ""
    @State private var showDeleteConfirm   = false
    @State private var saveSuccess         = false
    @FocusState private var focusedField: VehicleFocusField?

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _registrationNumber  = State(initialValue: vehicle.registrationNumber)
        _vinNumber           = State(initialValue: vehicle.vinNumber)
        _make                = State(initialValue: vehicle.make)
        _model               = State(initialValue: vehicle.model)
        _yearText            = State(initialValue: String(vehicle.year))
        _vehicleType         = State(initialValue: vehicle.vehicleType)
        _fuelType            = State(initialValue: vehicle.fuelType)
        _odometerText        = State(initialValue: String(format: "%.0f", vehicle.odometerReading))
        _status              = State(initialValue: vehicle.status)
        _lastServiceDate     = State(initialValue: vehicle.lastServiceDate ?? Date())
        _nextServiceDate     = State(initialValue: vehicle.nextServiceDate ?? Date())
        _insuranceExpiryDate = State(initialValue: vehicle.insuranceExpiryDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Identity badge ─────────────────────────────────
                        vehicleBadge

                        // ── Sections ───────────────────────────────────────
                        formSection(title: "Identity", icon: "doc.text.fill", iconColor: AppTheme.Brand.royalBlue) {
                            VehicleFormField(label: "Registration No.", placeholder: "e.g. KA-01-AB-1234",
                                            text: $registrationNumber, keyboardType: .default, focus: $focusedField, tag: .registration)
                            FormDivider()
                            VehicleFormField(label: "VIN Number", placeholder: "17-character VIN",
                                            text: $vinNumber, keyboardType: .default, focus: $focusedField, tag: .vin)
                        }

                        formSection(title: "Specifications", icon: "gearshape.2.fill", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)) {
                            VehicleFormField(label: "Make", placeholder: "e.g. Tata",
                                            text: $make, keyboardType: .default, focus: $focusedField, tag: .make)
                            FormDivider()
                            VehicleFormField(label: "Model", placeholder: "e.g. Ace Gold",
                                            text: $model, keyboardType: .default, focus: $focusedField, tag: .model)
                            FormDivider()
                            VehicleFormField(label: "Year", placeholder: "e.g. 2023",
                                            text: $yearText, keyboardType: .numberPad, focus: $focusedField, tag: .year)
                            FormDivider()
                            SegmentPickerRow(label: "Type", options: VehicleType.allCases, selection: $vehicleType) { $0.displayName }
                            FormDivider()
                            SegmentPickerRow(label: "Fuel", options: FuelType.allCases, selection: $fuelType) { $0.displayName }
                        }

                        formSection(title: "Status & Odometer", icon: "gauge.with.needle.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            StatusPickerRow(selection: $status)
                            FormDivider()
                            VehicleFormField(label: "Odometer (km)", placeholder: "e.g. 45230",
                                            text: $odometerText, keyboardType: .decimalPad, focus: $focusedField, tag: .odometer)
                        }

                        formSection(title: "Dates", icon: "calendar", iconColor: AppTheme.Brand.accent) {
                            DatePickerRow(label: "Last Service Date", date: $lastServiceDate)
                            FormDivider()
                            DatePickerRow(label: "Next Service Date", date: $nextServiceDate)
                            FormDivider()
                            DatePickerRow(label: "Insurance Expiry", date: $insuranceExpiryDate)
                        }

                        // ── Save ───────────────────────────────────────────
                        saveButton

                        // ── Delete ─────────────────────────────────────────
                        deleteButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(validationMessage) }
            .alert("Changes Saved", isPresented: $saveSuccess) {
                Button("Done") { dismiss() }
            } message: { Text("\(registrationNumber) has been updated.") }
            .confirmationDialog(
                "Delete \(vehicle.registrationNumber)?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Vehicle", role: .destructive) { deleteVehicle() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the vehicle from your fleet. This action cannot be undone.")
            }
        }
    }

    // MARK: Vehicle Badge

    private var vehicleBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [vehicle.vehicleType.iconColor.opacity(0.8), vehicle.vehicleType.iconColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .shadow(color: vehicle.vehicleType.iconColor.opacity(0.35), radius: 10, y: 4)
                Image(systemName: vehicle.vehicleType.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.registrationNumber)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text("\(vehicle.make) \(vehicle.model) · \(String(vehicle.year))")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .padding(.top, 8)
    }

    // MARK: Save Button

    private var saveButton: some View {
        Button { saveChanges() } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
                Text("Save Changes").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient(
                colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.primaryDeep],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Delete Button

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                Text("Delete Vehicle").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: Actions

    private func saveChanges() {
        guard !registrationNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Registration number is required."; showValidationAlert = true; return
        }
        guard !vinNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "VIN number is required."; showValidationAlert = true; return
        }
        guard !make.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Vehicle make is required."; showValidationAlert = true; return
        }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Vehicle model is required."; showValidationAlert = true; return
        }
        guard let year = Int(yearText), year >= 1980 else {
            validationMessage = "Please enter a valid year."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        vehicle.registrationNumber   = registrationNumber.trimmingCharacters(in: .whitespaces).uppercased()
        vehicle.vinNumber            = vinNumber.trimmingCharacters(in: .whitespaces).uppercased()
        vehicle.make                 = make.trimmingCharacters(in: .whitespaces)
        vehicle.model                = model.trimmingCharacters(in: .whitespaces)
        vehicle.year                 = year
        vehicle.vehicleType          = vehicleType
        vehicle.fuelType             = fuelType
        vehicle.odometerReading      = Double(odometerText) ?? vehicle.odometerReading
        vehicle.status               = status
        vehicle.lastServiceDate      = lastServiceDate
        vehicle.nextServiceDate      = nextServiceDate
        vehicle.insuranceExpiryDate  = insuranceExpiryDate
        vehicle.updatedAt            = .now

        try? modelContext.save()
        saveSuccess = true
    }

    private func deleteVehicle() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        modelContext.delete(vehicle)
        try? modelContext.save()
        dismiss()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared Form Components
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Field Tag Enum

enum VehicleFocusField: Hashable {
    case registration, vin, make, model, year, odometer
}

// MARK: Form Section Container

@available(iOS 26.0, *)
@ViewBuilder
func formSection<Content: View>(
    title: String,
    icon: String,
    iconColor: Color,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 0) {
        // Section Header
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

        // Card
        VStack(spacing: 0) {
            content()
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
}

// MARK: Text Field Row

struct VehicleFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    var focus: FocusState<VehicleFocusField?>.Binding
    let tag: VehicleFocusField

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 130, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.Brand.royalBlue)
                .keyboardType(keyboardType)
                .focused(focus, equals: tag)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: Segment Picker Row

struct SegmentPickerRow<T: Hashable>: View {
    let label: String
    let options: [T]
    @Binding var selection: T
    let displayName: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = option
                            }
                        } label: {
                            Text(displayName(option))
                                .font(.system(size: 13, weight: selection == option ? .bold : .medium, design: .rounded))
                                .foregroundColor(selection == option ? .white : AppTheme.Brand.royalBlue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selection == option ? AppTheme.Brand.royalBlue : AppTheme.Brand.royalBlue.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 14)
        }
    }
}

// MARK: Status Picker Row

struct StatusPickerRow: View {
    @Binding var selection: VehicleStatus

    private let options: [(VehicleStatus, String, Color)] = [
        (.active,        "Active",      Color(red: 0.30, green: 0.70, blue: 0.46)),
        (.inactive,      "Inactive",    Color.orange),
        (.inMaintenance, "Maintenance", Color(red: 0.85, green: 0.25, blue: 0.25))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            HStack(spacing: 8) {
                ForEach(options, id: \.0) { status, label, color in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = status }
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(color).frame(width: 7, height: 7)
                            Text(label).font(.system(size: 12, weight: selection == status ? .bold : .medium, design: .rounded))
                        }
                        .foregroundColor(selection == status ? .white : color)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selection == status ? color : color.opacity(0.10))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

// MARK: Date Picker Row

struct DatePickerRow: View {
    let label: String
    @Binding var date: Date
    var showsTime: Bool = false

    var body: some View {
        DatePicker(
            label,
            selection: $date,
            displayedComponents: showsTime ? [.date, .hourAndMinute] : [.date]
        )
        .datePickerStyle(.compact)
        .tint(AppTheme.Brand.royalBlue)
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: Divider

struct FormDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - VehicleType / FuelType CaseIterable conformances
// ─────────────────────────────────────────────────────────────────────────────

extension VehicleType: CaseIterable {
    public static var allCases: [VehicleType] { [.truck, .van, .car, .bike] }
}

extension FuelType: CaseIterable {
    public static var allCases: [FuelType] { [.diesel, .petrol, .electric, .hybrid] }
}
