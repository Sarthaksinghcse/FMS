//
//  TripFormView.swift
//  FMS
//
//  Full Add / Edit / Delete trip forms for the Fleet Manager's
//  Trip Management screen. Follows the VehicleFormView.swift pattern.
//

import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Add Trip Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct AddTripFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]

    // ── Form State ────────────────────────────────────────────────────────────
    @State private var tripCode         = ""
    @State private var selectedVehicle: Vehicle?
    @State private var selectedDriver: User?
    @State private var startLocation    = ""
    @State private var endLocation      = ""
    @State private var startLatText     = ""
    @State private var startLongText    = ""
    @State private var endLatText       = ""
    @State private var endLongText      = ""
    @State private var scheduledStartTime = Date()
    @State private var scheduledEndTime   = Date().addingTimeInterval(3600)
    @State private var distanceText     = ""
    @State private var notes            = ""

    // ── Validation ────────────────────────────────────────────────────────────
    @State private var showValidationAlert  = false
    @State private var validationMessage    = ""
    @State private var saveSuccess          = false

    // ── Focus ─────────────────────────────────────────────────────────────────
    @FocusState private var focusedField: TripFocusField?

    private var drivers: [User] { allUsers.filter { $0.role == .driver } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Form sections ──────────────────────────────────
                        formSection(title: "Trip Details", icon: "map.fill", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)) {
                            TripFormField(label: "Trip Code", placeholder: "e.g. TRP-001",
                                         text: $tripCode, keyboardType: .default, focus: $focusedField, tag: .tripCode)
                        }

                        formSection(title: "Assignment", icon: "person.2.fill", iconColor: AppTheme.Brand.royalBlue) {
                            VehiclePickerRow(label: "Vehicle", vehicles: vehicles, selection: $selectedVehicle)
                            FormDivider()
                            DriverPickerRow(label: "Driver", drivers: drivers, selection: $selectedDriver)
                        }

                        formSection(title: "Locations", icon: "location.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            TripFormField(label: "Start Location", placeholder: "e.g. Mumbai",
                                         text: $startLocation, keyboardType: .default, focus: $focusedField, tag: .startLocation)
                            FormDivider()
                            TripFormField(label: "End Location", placeholder: "e.g. Delhi",
                                         text: $endLocation, keyboardType: .default, focus: $focusedField, tag: .endLocation)
                        }

                        formSection(title: "Coordinates", icon: "location.circle.fill", iconColor: AppTheme.Brand.accent) {
                            TripFormField(label: "Start Latitude", placeholder: "-90 to 90",
                                         text: $startLatText, keyboardType: .decimalPad, focus: $focusedField, tag: .startLat)
                            FormDivider()
                            TripFormField(label: "Start Longitude", placeholder: "-180 to 180",
                                         text: $startLongText, keyboardType: .decimalPad, focus: $focusedField, tag: .startLong)
                            FormDivider()
                            TripFormField(label: "End Latitude", placeholder: "-90 to 90",
                                         text: $endLatText, keyboardType: .decimalPad, focus: $focusedField, tag: .endLat)
                            FormDivider()
                            TripFormField(label: "End Longitude", placeholder: "-180 to 180",
                                         text: $endLongText, keyboardType: .decimalPad, focus: $focusedField, tag: .endLong)
                        }

                        formSection(title: "Schedule", icon: "calendar", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)) {
                            DatePickerRow(label: "Start Time", date: $scheduledStartTime, showsTime: true)
                            FormDivider()
                            DatePickerRow(label: "End Time", date: $scheduledEndTime, showsTime: true)
                        }

                        formSection(title: "Distance & Notes", icon: "gauge.with.needle.fill", iconColor: AppTheme.Brand.royalBlue) {
                            TripFormField(label: "Distance (km)", placeholder: "e.g. 1450",
                                         text: $distanceText, keyboardType: .decimalPad, focus: $focusedField, tag: .distance)
                            FormDivider()
                            TripNotesField(label: "Notes", placeholder: "Optional notes",
                                          text: $notes, focus: $focusedField, tag: .notes)
                        }

                        // ── Save Button ────────────────────────────────────
                        saveButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Add Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
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
            .alert("Trip Created", isPresented: $saveSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(tripCode) has been created successfully.")
            }
        }
    }

    // MARK: Save Button

    private var saveButton: some View {
        Button {
            saveTrip()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Create Trip")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.58, green: 0.39, blue: 0.87), Color(red: 0.48, green: 0.29, blue: 0.77)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 0.58, green: 0.39, blue: 0.87).opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Save Action

    private func saveTrip() {
        // Validation
        guard !tripCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Trip code is required."; showValidationAlert = true; return
        }
        guard let vehicle = selectedVehicle else {
            validationMessage = "Please select a vehicle."; showValidationAlert = true; return
        }
        guard let driver = selectedDriver else {
            validationMessage = "Please select a driver."; showValidationAlert = true; return
        }
        guard !startLocation.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Start location is required."; showValidationAlert = true; return
        }
        guard !endLocation.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "End location is required."; showValidationAlert = true; return
        }
        
        // Coordinate validation
        guard let startLat = Double(startLatText), startLat >= -90, startLat <= 90 else {
            validationMessage = "Start latitude must be between -90 and 90."; showValidationAlert = true; return
        }
        guard let startLong = Double(startLongText), startLong >= -180, startLong <= 180 else {
            validationMessage = "Start longitude must be between -180 and 180."; showValidationAlert = true; return
        }
        guard let endLat = Double(endLatText), endLat >= -90, endLat <= 90 else {
            validationMessage = "End latitude must be between -90 and 90."; showValidationAlert = true; return
        }
        guard let endLong = Double(endLongText), endLong >= -180, endLong <= 180 else {
            validationMessage = "End longitude must be between -180 and 180."; showValidationAlert = true; return
        }
        
        // Time validation
        guard scheduledStartTime < scheduledEndTime else {
            validationMessage = "Scheduled end time must be after start time."; showValidationAlert = true; return
        }
        
        // Distance validation
        guard let distance = Double(distanceText), distance > 0 else {
            validationMessage = "Please enter a valid distance."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let trip = Trip(
            tripCode:            tripCode.trimmingCharacters(in: .whitespaces).uppercased(),
            vehicleId:           vehicle.id,
            driverId:            driver.id,
            startLocation:       startLocation.trimmingCharacters(in: .whitespaces),
            endLocation:         endLocation.trimmingCharacters(in: .whitespaces),
            startLatitude:       startLat,
            startLongitude:      startLong,
            endLatitude:         endLat,
            endLongitude:        endLong,
            scheduledStartTime:  scheduledStartTime,
            scheduledEndTime:    scheduledEndTime,
            distanceKm:          distance,
            tripStatus:          .assigned,
            notes:               notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        modelContext.insert(trip)
        try? modelContext.save()
        saveSuccess = true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Edit Trip Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct EditTripFormView: View {

    let trip: Trip

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]

    // ── Form State ────────────────────────────────────────────────────────────
    @State private var tripCode: String
    @State private var selectedVehicle: Vehicle?
    @State private var selectedDriver: User?
    @State private var startLocation: String
    @State private var endLocation: String
    @State private var startLatText: String
    @State private var startLongText: String
    @State private var endLatText: String
    @State private var endLongText: String
    @State private var scheduledStartTime: Date
    @State private var scheduledEndTime: Date
    @State private var distanceText: String
    @State private var notes: String
    @State private var tripStatus: TripStatus

    @State private var showValidationAlert = false
    @State private var validationMessage   = ""
    @State private var showDeleteConfirm   = false
    @State private var saveSuccess         = false
    @FocusState private var focusedField: TripFocusField?

    private var drivers: [User] { allUsers.filter { $0.role == .driver } }

    init(trip: Trip) {
        self.trip = trip
        _tripCode            = State(initialValue: trip.tripCode)
        _startLocation       = State(initialValue: trip.startLocation)
        _endLocation         = State(initialValue: trip.endLocation)
        _startLatText        = State(initialValue: String(trip.startLatitude))
        _startLongText       = State(initialValue: String(trip.startLongitude))
        _endLatText          = State(initialValue: String(trip.endLatitude))
        _endLongText         = State(initialValue: String(trip.endLongitude))
        _scheduledStartTime  = State(initialValue: trip.scheduledStartTime)
        _scheduledEndTime    = State(initialValue: trip.scheduledEndTime)
        _distanceText        = State(initialValue: String(format: "%.1f", trip.distanceKm))
        _notes               = State(initialValue: trip.notes ?? "")
        _tripStatus          = State(initialValue: trip.tripStatus)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Trip badge ─────────────────────────────────────
                        tripBadge

                        // ── Sections ───────────────────────────────────────
                        formSection(title: "Trip Details", icon: "map.fill", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)) {
                            TripFormField(label: "Trip Code", placeholder: "e.g. TRP-001",
                                         text: $tripCode, keyboardType: .default, focus: $focusedField, tag: .tripCode)
                            FormDivider()
                            TripStatusPickerRow(selection: $tripStatus)
                        }

                        formSection(title: "Assignment", icon: "person.2.fill", iconColor: AppTheme.Brand.royalBlue) {
                            VehiclePickerRow(label: "Vehicle", vehicles: vehicles, selection: $selectedVehicle)
                            FormDivider()
                            DriverPickerRow(label: "Driver", drivers: drivers, selection: $selectedDriver)
                        }

                        formSection(title: "Locations", icon: "location.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            TripFormField(label: "Start Location", placeholder: "e.g. Mumbai",
                                         text: $startLocation, keyboardType: .default, focus: $focusedField, tag: .startLocation)
                            FormDivider()
                            TripFormField(label: "End Location", placeholder: "e.g. Delhi",
                                         text: $endLocation, keyboardType: .default, focus: $focusedField, tag: .endLocation)
                        }

                        formSection(title: "Coordinates", icon: "location.circle.fill", iconColor: AppTheme.Brand.accent) {
                            TripFormField(label: "Start Latitude", placeholder: "-90 to 90",
                                         text: $startLatText, keyboardType: .decimalPad, focus: $focusedField, tag: .startLat)
                            FormDivider()
                            TripFormField(label: "Start Longitude", placeholder: "-180 to 180",
                                         text: $startLongText, keyboardType: .decimalPad, focus: $focusedField, tag: .startLong)
                            FormDivider()
                            TripFormField(label: "End Latitude", placeholder: "-90 to 90",
                                         text: $endLatText, keyboardType: .decimalPad, focus: $focusedField, tag: .endLat)
                            FormDivider()
                            TripFormField(label: "End Longitude", placeholder: "-180 to 180",
                                         text: $endLongText, keyboardType: .decimalPad, focus: $focusedField, tag: .endLong)
                        }

                        formSection(title: "Schedule", icon: "calendar", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)) {
                            DatePickerRow(label: "Start Time", date: $scheduledStartTime, showsTime: true)
                            FormDivider()
                            DatePickerRow(label: "End Time", date: $scheduledEndTime, showsTime: true)
                        }

                        formSection(title: "Distance & Notes", icon: "gauge.with.needle.fill", iconColor: AppTheme.Brand.royalBlue) {
                            TripFormField(label: "Distance (km)", placeholder: "e.g. 1450",
                                         text: $distanceText, keyboardType: .decimalPad, focus: $focusedField, tag: .distance)
                            FormDivider()
                            TripNotesField(label: "Notes", placeholder: "Optional notes",
                                          text: $notes, focus: $focusedField, tag: .notes)
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
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
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
            } message: { Text("\(tripCode) has been updated.") }
            .confirmationDialog(
                "Delete \(trip.tripCode)?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Trip", role: .destructive) { deleteTrip() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the trip. This action cannot be undone.")
            }
        }
        .onAppear {
            // Set initial vehicle and driver selections
            selectedVehicle = vehicles.first { $0.id == trip.vehicleId }
            selectedDriver = drivers.first { $0.id == trip.driverId }
        }
    }

    // MARK: Trip Badge

    private var tripBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.58, green: 0.39, blue: 0.87).opacity(0.8), Color(red: 0.58, green: 0.39, blue: 0.87)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(red: 0.58, green: 0.39, blue: 0.87).opacity(0.35), radius: 10, y: 4)
                Image(systemName: "map.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.tripCode)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text("\(trip.startLocation) → \(trip.endLocation)")
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
                colors: [Color(red: 0.58, green: 0.39, blue: 0.87), Color(red: 0.48, green: 0.29, blue: 0.77)],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 0.58, green: 0.39, blue: 0.87).opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Delete Button

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                Text("Delete Trip").font(.system(size: 15, weight: .semibold, design: .rounded))
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
        // Validation
        guard !tripCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Trip code is required."; showValidationAlert = true; return
        }
        guard let vehicle = selectedVehicle else {
            validationMessage = "Please select a vehicle."; showValidationAlert = true; return
        }
        guard let driver = selectedDriver else {
            validationMessage = "Please select a driver."; showValidationAlert = true; return
        }
        guard !startLocation.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Start location is required."; showValidationAlert = true; return
        }
        guard !endLocation.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "End location is required."; showValidationAlert = true; return
        }
        
        guard let startLat = Double(startLatText), startLat >= -90, startLat <= 90 else {
            validationMessage = "Start latitude must be between -90 and 90."; showValidationAlert = true; return
        }
        guard let startLong = Double(startLongText), startLong >= -180, startLong <= 180 else {
            validationMessage = "Start longitude must be between -180 and 180."; showValidationAlert = true; return
        }
        guard let endLat = Double(endLatText), endLat >= -90, endLat <= 90 else {
            validationMessage = "End latitude must be between -90 and 90."; showValidationAlert = true; return
        }
        guard let endLong = Double(endLongText), endLong >= -180, endLong <= 180 else {
            validationMessage = "End longitude must be between -180 and 180."; showValidationAlert = true; return
        }
        
        guard scheduledStartTime < scheduledEndTime else {
            validationMessage = "Scheduled end time must be after start time."; showValidationAlert = true; return
        }
        
        guard let distance = Double(distanceText), distance > 0 else {
            validationMessage = "Please enter a valid distance."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        trip.tripCode           = tripCode.trimmingCharacters(in: .whitespaces).uppercased()
        trip.vehicleId          = vehicle.id
        trip.driverId           = driver.id
        trip.startLocation      = startLocation.trimmingCharacters(in: .whitespaces)
        trip.endLocation        = endLocation.trimmingCharacters(in: .whitespaces)
        trip.startLatitude      = startLat
        trip.startLongitude     = startLong
        trip.endLatitude        = endLat
        trip.endLongitude       = endLong
        trip.scheduledStartTime = scheduledStartTime
        trip.scheduledEndTime   = scheduledEndTime
        trip.distanceKm         = distance
        trip.tripStatus         = tripStatus
        trip.notes              = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)

        try? modelContext.save()
        saveSuccess = true
    }

    private func deleteTrip() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        modelContext.delete(trip)
        try? modelContext.save()
        dismiss()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared Form Components for Trip Forms
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Field Tag Enum

enum TripFocusField: Hashable {
    case tripCode, startLocation, endLocation, startLat, startLong, endLat, endLong, distance, notes
}

// MARK: Text Field Row

struct TripFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    var focus: FocusState<TripFocusField?>.Binding
    let tag: TripFocusField

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 120, alignment: .leading)

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

// MARK: Notes Field Row

struct TripNotesField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<TripFocusField?>.Binding
    let tag: TripFocusField

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.Brand.royalBlue)
                .focused(focus, equals: tag)
                .lineLimit(3...6)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }
}

// MARK: Vehicle Picker Row

struct VehiclePickerRow: View {
    let label: String
    let vehicles: [Vehicle]
    @Binding var selection: Vehicle?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if vehicles.isEmpty {
                Text("No vehicles available. Add vehicles first.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                Picker("", selection: $selection) {
                    Text("Select Vehicle").tag(nil as Vehicle?)
                    ForEach(vehicles) { vehicle in
                        Text("\(vehicle.registrationNumber) - \(vehicle.make) \(vehicle.model)")
                            .tag(vehicle as Vehicle?)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Brand.royalBlue)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }
}

// MARK: Driver Picker Row

struct DriverPickerRow: View {
    let label: String
    let drivers: [User]
    @Binding var selection: User?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if drivers.isEmpty {
                Text("No drivers available. Add drivers first.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.gray)
                    .italic()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                Picker("", selection: $selection) {
                    Text("Select Driver").tag(nil as User?)
                    ForEach(drivers) { driver in
                        Text(driver.fullName).tag(driver as User?)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Brand.royalBlue)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }
}

// MARK: Trip Status Picker Row

struct TripStatusPickerRow: View {
    @Binding var selection: TripStatus

    private let options: [(TripStatus, String, Color)] = [
        (.assigned,    "Assigned",    Color.orange),
        (.started,     "Started",     Color.blue),
        (.inProgress,  "In Progress", Color(red: 0.58, green: 0.39, blue: 0.87)),
        (.completed,   "Completed",   Color(red: 0.30, green: 0.70, blue: 0.46)),
        (.cancelled,   "Cancelled",   Color(red: 0.85, green: 0.25, blue: 0.25))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
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
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 14)
        }
    }
}
