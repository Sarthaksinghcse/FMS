import SwiftUI
import SwiftData
import MapKit


@available(iOS 26.0, *)
struct AddTripFormView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var allTrips: [Trip]
    
    
    @State private var tripCode         = ""
    @State private var selectedVehicle: Vehicle?
    @State private var selectedDriver: User?
    @State private var startLocation    = ""
    @State private var endLocation      = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    @State private var scheduledStartTime = Date().addingTimeInterval(2 * 3600)
    @State private var scheduledEndTime   = Date().addingTimeInterval(4 * 3600)
    @State private var additionalHours: Double = 0.0
    @State private var distanceText     = ""
    @State private var notes            = ""
    @State private var timeCheckTask: Task<Void, Never>? = nil
    
    
    @State private var showValidationAlert  = false
    @State private var validationMessage    = ""
    @State private var saveSuccess          = false
    @State private var isSaving             = false
    
    
    @FocusState private var focusedField: TripFocusField?
    
    private var drivers: [User] { allUsers.filter { $0.role == .driver } }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        
                        formSection(title: "Trip Details", icon: "map.fill", iconColor: AppTheme.Brand.teal) {
                            TripFormField(label: "Trip Code", placeholder: "e.g. TRP-001",
                                          text: $tripCode, keyboardType: .default, focus: $focusedField, tag: .tripCode,
                                          isEditable: false)
                        }
                        
                        formSection(title: "Locations", icon: "location.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            LocationSelectionRow(label: "Start Location", placeholder: "Select on map", locationText: startLocation) {
                                showingStartPicker = true
                            }
                            FormDivider()
                            LocationSelectionRow(label: "End Location", placeholder: "Select on map", locationText: endLocation) {
                                showingEndPicker = true
                            }
                        }
                        
                        formSection(title: "Schedule", icon: "calendar", iconColor: AppTheme.Brand.royalBlue) {
                            DatePickerRow(label: "Start Time", date: $scheduledStartTime, showsTime: true)
                            if scheduledStartTime < Date().addingTimeInterval(2 * 3600 - 60) {
                                Text("⚠️ Start time must be at least 2 hours from now.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                            FormDivider()
                            DatePickerRow(label: "End Time", date: $scheduledEndTime, showsTime: true)
                            FormDivider()
                            AdditionalTimeStepperRow(label: "Additional Time", additionalHours: $additionalHours)
                        }
                        
                        formSection(title: "Assignment", icon: "person.2.fill", iconColor: AppTheme.Brand.royalBlue) {
                            VehiclePickerRow(label: "Vehicle", vehicles: vehicles, selection: $selectedVehicle, allTrips: allTrips, startTime: scheduledStartTime, endTime: scheduledEndTime, currentTripId: nil)
                            FormDivider()
                            DriverPickerRow(label: "Driver", drivers: drivers, selection: $selectedDriver, allTrips: allTrips, startTime: scheduledStartTime, endTime: scheduledEndTime, currentTripId: nil)
                        }
                        
                        formSection(title: "Distance & Special Instructions", icon: "gauge.with.needle.fill", iconColor: AppTheme.Brand.royalBlue) {
                            TripFormField(label: "Distance (km)", placeholder: "e.g. 1450",
                                          text: $distanceText, keyboardType: .decimalPad, focus: $focusedField, tag: .distance)
                            FormDivider()
                            TripNotesField(label: "Special Instructions", placeholder: "Optional special instructions",
                                           text: $notes, focus: $focusedField, tag: .notes)
                        }
                        
                        
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
                        .foregroundColor(.red)
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
            .sheet(isPresented: $showingStartPicker) {
                LocationPickerSheet(
                    title: "Select Start Location",
                    initialLocation: startLocation,
                    initialCoordinate: startCoordinate
                ) { address, coord in
                    startLocation = address
                    startCoordinate = coord
                    calculateDistanceIfPossible()
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingEndPicker) {
                LocationPickerSheet(
                    title: "Select End Location",
                    initialLocation: endLocation,
                    initialCoordinate: endCoordinate
                ) { address, coord in
                    endLocation = address
                    endCoordinate = coord
                    calculateDistanceIfPossible()
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: scheduledStartTime) { oldValue, newValue in
                let duration = scheduledEndTime.timeIntervalSince(oldValue)
                scheduledEndTime = newValue.addingTimeInterval(duration)
                
                timeCheckTask?.cancel()
                timeCheckTask = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }
                    if scheduledStartTime < Date().addingTimeInterval(2 * 3600 - 60) {
                        await MainActor.run {
                            withAnimation(.spring()) {
                                scheduledStartTime = Date().addingTimeInterval(2 * 3600)
                            }
                        }
                    }
                }
            }
            .onChange(of: additionalHours) { oldValue, newValue in
                let diff = (newValue - oldValue) * 3600
                scheduledEndTime = scheduledEndTime.addingTimeInterval(diff)
            }
            .onAppear {
                if tripCode.isEmpty {
                    let calendar = Calendar.current
                    let todayTripsCount = allTrips.filter { calendar.isDateInToday($0.createdAt) }.count
                    let nextTripNumber = todayTripsCount + 1
                    
                    let date = Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMdd"
                    let dateStr = formatter.string(from: date)
                    let tripNumberStr = String(format: "%02d", nextTripNumber)
                    tripCode = "TRP-\(dateStr)\(tripNumberStr)"
                }
            }
        }
    }
    
    
    
    private var saveButton: some View {
        Button {
            saveTrip()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(isSaving ? "Creating..." : "Create Trip")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.primary],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isSaving)
    }
    
    
    
    private func saveTrip() {
        
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
        
        
        guard scheduledStartTime < scheduledEndTime else {
            validationMessage = "Scheduled end time must be after start time."; showValidationAlert = true; return
        }
        guard scheduledStartTime >= Date().addingTimeInterval(2 * 3600 - 60) else {
            validationMessage = "Trip start time must be at least 2 hours from now."
            showValidationAlert = true
            scheduledStartTime = Date().addingTimeInterval(2 * 3600)
            return
        }
        
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isSaving = true
        
        Task {
            guard let startCoordObj = startCoordinate, let endCoordObj = endCoordinate else {
                await MainActor.run {
                    validationMessage = "Please select valid map locations."
                    showValidationAlert = true
                    isSaving = false
                }
                return
            }
            
            let distance: Double
            if let userDistance = Double(distanceText), userDistance > 0 {
                distance = userDistance
            } else {
                let startLoc = CLLocation(latitude: startCoordObj.latitude, longitude: startCoordObj.longitude)
                let endLoc = CLLocation(latitude: endCoordObj.latitude, longitude: endCoordObj.longitude)
                distance = Double(String(format: "%.1f", startLoc.distance(from: endLoc) / 1000.0)) ?? 0.0
            }
            
            let trip = Trip(
                tripCode:            tripCode.trimmingCharacters(in: .whitespaces).uppercased(),
                vehicleId:           vehicle.id,
                driverId:            driver.id,
                startLocation:       startLocation.trimmingCharacters(in: .whitespaces),
                endLocation:         endLocation.trimmingCharacters(in: .whitespaces),
                startLatitude:       startCoordObj.latitude,
                startLongitude:      startCoordObj.longitude,
                endLatitude:         endCoordObj.latitude,
                endLongitude:        endCoordObj.longitude,
                scheduledStartTime:  scheduledStartTime,
                scheduledEndTime:    scheduledEndTime,
                distanceKm:          distance,
                tripStatus:          .assigned,
                notes:               notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
            )
            
            do {
                try await SupabaseManager.shared.createTrip(trip.asDBTrip)
                
                
                let driverEmail = driver.email
                let driverName = driver.fullName
                Task {
                    try? await EmailManager.shared.sendTripAssignmentEmail(
                        to: driverEmail,
                        name: driverName,
                        tripCode: trip.tripCode,
                        source: trip.startLocation,
                        destination: trip.endLocation,
                        startTime: trip.scheduledStartTime,
                        distance: trip.distanceKm
                    )
                }
                
                await MainActor.run {
                    modelContext.insert(trip)
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            } catch {
                print("Failed to save trip to Supabase: \(error)")
                await MainActor.run {
                    modelContext.insert(trip)
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            }
        }
    }
    
    private func calculateDistanceIfPossible() {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let dist = startLoc.distance(from: endLoc) / 1000.0
        distanceText = String(format: "%.1f", dist)
        
        Task {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            request.transportType = .automobile
            
            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    await MainActor.run {
                        let drivingDist = route.distance / 1000.0
                        distanceText = String(format: "%.1f", drivingDist)
                        scheduledEndTime = scheduledStartTime.addingTimeInterval(route.expectedTravelTime + (additionalHours * 3600))
                    }
                }
            } catch {
                print("Failed to calculate directions: \(error)")
            }
        }
    }
}





@available(iOS 26.0, *)
struct EditTripFormView: View {
    
    let trip: Trip
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    
    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query(sort: \User.fullName) private var allUsers: [User]
    @Query private var allTrips: [Trip]
    
    @State private var tripCode: String
    @State private var selectedVehicle: Vehicle?
    @State private var selectedDriver: User?
    @State private var startLocation: String
    @State private var endLocation: String
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var showingStartPicker = false
    @State private var showingEndPicker = false
    @State private var scheduledStartTime: Date
    @State private var scheduledEndTime: Date
    @State private var additionalHours: Double = 0.0
    @State private var distanceText: String
    @State private var notes: String
    @State private var timeCheckTask: Task<Void, Never>? = nil
    @State private var tripStatus: TripStatus
    
    @State private var showValidationAlert = false
    @State private var validationMessage   = ""
    @State private var showDeleteConfirm   = false
    @State private var saveSuccess         = false
    @State private var isSaving             = false
    @State private var isDeleting           = false
    @FocusState private var focusedField: TripFocusField?
    
    private var drivers: [User] { allUsers.filter { $0.role == .driver } }
    
    init(trip: Trip) {
        self.trip = trip
        _tripCode            = State(initialValue: trip.tripCode)
        _startLocation       = State(initialValue: trip.startLocation)
        _endLocation         = State(initialValue: trip.endLocation)
        _startCoordinate     = State(initialValue: CLLocationCoordinate2D(latitude: trip.startLatitude, longitude: trip.startLongitude))
        _endCoordinate       = State(initialValue: CLLocationCoordinate2D(latitude: trip.endLatitude, longitude: trip.endLongitude))
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
                        
                        
                        tripBadge
                        
                        
                        formSection(title: "Trip Details", icon: "map.fill", iconColor: AppTheme.Brand.teal) {
                            TripFormField(label: "Trip Code", placeholder: "e.g. TRP-001",
                                          text: $tripCode, keyboardType: .default, focus: $focusedField, tag: .tripCode,
                                          isEditable: false)
                            FormDivider()
                            TripStatusPickerRow(selection: $tripStatus)
                        }
                        
                        formSection(title: "Locations", icon: "location.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            LocationSelectionRow(label: "Start Location", placeholder: "Select on map", locationText: startLocation) {
                                showingStartPicker = true
                            }
                            FormDivider()
                            LocationSelectionRow(label: "End Location", placeholder: "Select on map", locationText: endLocation) {
                                showingEndPicker = true
                            }
                        }
                        
                        formSection(title: "Schedule", icon: "calendar", iconColor: AppTheme.Brand.royalBlue) {
                            DatePickerRow(label: "Start Time", date: $scheduledStartTime, showsTime: true)
                            if scheduledStartTime != trip.scheduledStartTime && scheduledStartTime < Date().addingTimeInterval(2 * 3600 - 60) {
                                Text("⚠️ New start time must be at least 2 hours from now.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                            FormDivider()
                            DatePickerRow(label: "End Time", date: $scheduledEndTime, showsTime: true)
                            FormDivider()
                            AdditionalTimeStepperRow(label: "Additional Time", additionalHours: $additionalHours)
                        }
                        
                        formSection(title: "Assignment", icon: "person.2.fill", iconColor: AppTheme.Brand.royalBlue) {
                            VehiclePickerRow(label: "Vehicle", vehicles: vehicles, selection: $selectedVehicle, allTrips: allTrips, startTime: scheduledStartTime, endTime: scheduledEndTime, currentTripId: trip.id)
                            FormDivider()
                            DriverPickerRow(label: "Driver", drivers: drivers, selection: $selectedDriver, allTrips: allTrips, startTime: scheduledStartTime, endTime: scheduledEndTime, currentTripId: trip.id)
                        }
                        
                        formSection(title: "Distance & Special Instructions", icon: "gauge.with.needle.fill", iconColor: AppTheme.Brand.royalBlue) {
                            TripFormField(label: "Distance (km)", placeholder: "e.g. 1450",
                                          text: $distanceText, keyboardType: .decimalPad, focus: $focusedField, tag: .distance)
                            FormDivider()
                            TripNotesField(label: "Special Instructions", placeholder: "Optional special instructions",
                                           text: $notes, focus: $focusedField, tag: .notes)
                        }
                        
                        
                        saveButton
                        
                        
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
                        .foregroundColor(.red)
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
        .sheet(isPresented: $showingStartPicker) {
            LocationPickerSheet(
                title: "Select Start Location",
                initialLocation: startLocation,
                initialCoordinate: startCoordinate
            ) { address, coord in
                startLocation = address
                startCoordinate = coord
                calculateDistanceIfPossible()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingEndPicker) {
            LocationPickerSheet(
                title: "Select End Location",
                initialLocation: endLocation,
                initialCoordinate: endCoordinate
            ) { address, coord in
                endLocation = address
                endCoordinate = coord
                calculateDistanceIfPossible()
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: scheduledStartTime) { oldValue, newValue in
            let duration = scheduledEndTime.timeIntervalSince(oldValue)
            scheduledEndTime = newValue.addingTimeInterval(duration)
            
            timeCheckTask?.cancel()
            timeCheckTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                if scheduledStartTime != trip.scheduledStartTime && scheduledStartTime < Date().addingTimeInterval(2 * 3600 - 60) {
                    await MainActor.run {
                        withAnimation(.spring()) {
                            scheduledStartTime = trip.scheduledStartTime
                        }
                    }
                }
            }
        }
        .onChange(of: additionalHours) { oldValue, newValue in
            let diff = (newValue - oldValue) * 3600
            scheduledEndTime = scheduledEndTime.addingTimeInterval(diff)
        }
        .onAppear {
            
            selectedVehicle = vehicles.first { $0.id == trip.vehicleId }
            selectedDriver = drivers.first { $0.id == trip.driverId }
        }
    }
    
    
    
    private var tripBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Brand.royalBlue.opacity(0.8), AppTheme.Brand.royalBlue],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 10, y: 4)
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
    
    
    
    private var saveButton: some View {
        Button { saveChanges() } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
                }
                Text(isSaving ? "Saving..." : "Save Changes").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient(
                colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.primary],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isSaving || isDeleting)
    }
    
    
    
    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.85, green: 0.15, blue: 0.15)))
                } else {
                    Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                }
                Text(isDeleting ? "Deleting..." : "Delete Trip").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.25), lineWidth: 1))
        }
        .disabled(isSaving || isDeleting)
    }
    
    
    
    private func saveChanges() {
        
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
        
        guard scheduledStartTime < scheduledEndTime else {
            validationMessage = "Scheduled end time must be after start time."; showValidationAlert = true; return
        }
        
        if scheduledStartTime != trip.scheduledStartTime {
            guard scheduledStartTime >= Date().addingTimeInterval(2 * 3600 - 60) else {
                validationMessage = "New trip start time must be at least 2 hours from now."
                showValidationAlert = true
                scheduledStartTime = trip.scheduledStartTime
                return
            }
        }
        
        guard let distance = Double(distanceText), distance > 0 else {
            validationMessage = "Please enter a valid distance."; showValidationAlert = true; return
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        isSaving = true
        
        Task {
            guard let startCoordObj = startCoordinate, let endCoordObj = endCoordinate else {
                await MainActor.run {
                    validationMessage = "Please select valid map locations."
                    showValidationAlert = true
                    isSaving = false
                }
                return
            }
            
            let updatedDBTrip = DBTrip(
                id: trip.id,
                vehicleId: vehicle.id,
                driverId: driver.id,
                source: startLocation.trimmingCharacters(in: .whitespaces),
                destination: endLocation.trimmingCharacters(in: .whitespaces),
                startTime: scheduledStartTime,
                endTime: scheduledEndTime,
                distance: distance,
                status: tripStatus.toDBStatus,
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
                createdAt: trip.createdAt
            )
            
            do {
                try await SupabaseManager.shared.updateTrip(updatedDBTrip)
                await MainActor.run {
                    trip.tripCode           = tripCode.trimmingCharacters(in: .whitespaces).uppercased()
                    trip.vehicleId          = vehicle.id
                    trip.driverId           = driver.id
                    trip.startLocation      = startLocation.trimmingCharacters(in: .whitespaces)
                    trip.endLocation        = endLocation.trimmingCharacters(in: .whitespaces)
                    trip.startLatitude      = startCoordObj.latitude
                    trip.startLongitude     = startCoordObj.longitude
                    trip.endLatitude        = endCoordObj.latitude
                    trip.endLongitude       = endCoordObj.longitude
                    trip.scheduledStartTime = scheduledStartTime
                    trip.scheduledEndTime   = scheduledEndTime
                    trip.distanceKm         = distance
                    trip.tripStatus         = tripStatus
                    trip.notes              = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
                    
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            } catch {
                print("Failed to update trip on Supabase: \(error)")
                await MainActor.run {
                    trip.tripCode           = tripCode.trimmingCharacters(in: .whitespaces).uppercased()
                    trip.vehicleId          = vehicle.id
                    trip.driverId           = driver.id
                    trip.startLocation      = startLocation.trimmingCharacters(in: .whitespaces)
                    trip.endLocation        = endLocation.trimmingCharacters(in: .whitespaces)
                    trip.startLatitude      = startCoordObj.latitude
                    trip.startLongitude     = startCoordObj.longitude
                    trip.endLatitude        = endCoordObj.latitude
                    trip.endLongitude       = endCoordObj.longitude
                    trip.scheduledStartTime = scheduledStartTime
                    trip.scheduledEndTime   = scheduledEndTime
                    trip.distanceKm         = distance
                    trip.tripStatus         = tripStatus
                    trip.notes              = notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
                    
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            }
        }
    }
    
    private func deleteTrip() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        isDeleting = true
        
        Task {
            do {
                
                try await SupabaseManager.shared.deleteTrip(id: trip.id)
                
                await MainActor.run {
                    modelContext.delete(trip)
                    try? modelContext.save()
                    isDeleting = false
                    dismiss()
                }
            } catch {
                print("Failed to delete trip from Supabase: \(error)")
                
                await MainActor.run {
                    modelContext.delete(trip)
                    try? modelContext.save()
                    isDeleting = false
                    dismiss()
                }
            }
        }
    }
    
    private func calculateDistanceIfPossible() {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let dist = startLoc.distance(from: endLoc) / 1000.0
        distanceText = String(format: "%.1f", dist)
        
        Task {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            request.transportType = .automobile
            
            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    await MainActor.run {
                        let drivingDist = route.distance / 1000.0
                        distanceText = String(format: "%.1f", drivingDist)
                        scheduledEndTime = scheduledStartTime.addingTimeInterval(route.expectedTravelTime + (additionalHours * 3600))
                    }
                }
            } catch {
                print("Failed to calculate directions: \(error)")
            }
        }
    }
}







struct AdditionalTimeStepperRow: View {
    let label: String
    @Binding var additionalHours: Double
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    if additionalHours > 0 {
                        additionalHours -= 0.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(additionalHours > 0 ? AppTheme.Brand.royalBlue : .gray)
                }
                .disabled(additionalHours <= 0)
                
                Text(String(format: "%.1f hrs", additionalHours))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                    .frame(minWidth: 55, alignment: .center)
                
                Button {
                    additionalHours += 0.5
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

enum TripFocusField: Hashable {
    case tripCode, startLocation, endLocation, startLat, startLong, endLat, endLong, distance, notes
}



struct LocationSelectionRow: View {
    let label: String
    let placeholder: String
    let locationText: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 120, alignment: .leading)
                
                Spacer()
                
                Text(locationText.isEmpty ? placeholder : locationText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(locationText.isEmpty ? .gray : AppTheme.Brand.royalBlue)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct TripFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    var focus: FocusState<TripFocusField?>.Binding
    let tag: TripFocusField
    var isEditable: Bool = true
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 120, alignment: .leading)
            
            if isEditable {
                TextField(placeholder, text: $text)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.Brand.royalBlue)
                    .keyboardType(keyboardType)
                    .focused(focus, equals: tag)
                    .multilineTextAlignment(.trailing)
            } else {
                Spacer()
                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



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



struct VehiclePickerRow: View {
    let label: String
    let vehicles: [Vehicle]
    @Binding var selection: Vehicle?
    var allTrips: [Trip] = []
    var startTime: Date = Date()
    var endTime: Date = Date()
    var currentTripId: UUID? = nil
    
    private var availableVehicles: [Vehicle] {
        vehicles.filter { vehicle in
            vehicle.status == .active && !hasOverlap(for: vehicle.id)
        }
    }
    
    private var unavailableVehicles: [Vehicle] {
        vehicles.filter { vehicle in
            vehicle.status != .active || hasOverlap(for: vehicle.id)
        }
    }
    
    private func hasOverlap(for entityId: UUID) -> Bool {
        allTrips.contains { trip in
            guard trip.id != currentTripId else { return false }
            guard trip.vehicleId == entityId else { return false }
            guard trip.tripStatus != .completed && trip.tripStatus != .cancelled else { return false }
            return trip.scheduledStartTime < endTime && trip.scheduledEndTime > startTime
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
            
            if vehicles.isEmpty {
                Text("No vehicles available")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.gray)
                    .italic()
            } else {
                Menu {
                    Button("Select Vehicle") {
                        selection = nil
                    }

                    if !availableVehicles.isEmpty {
                        Section("Available Vehicles") {
                            ForEach(availableVehicles) { vehicle in
                                Button {
                                    selection = vehicle
                                } label: {
                                    Text("\(vehicle.registrationNumber) - \(vehicle.make) \(vehicle.model)")
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    
                    if !unavailableVehicles.isEmpty {
                        Section("Unavailable Vehicles") {
                            ForEach(unavailableVehicles) { vehicle in
                                Button {
                                    selection = vehicle
                                } label: {
                                    Text("\(vehicle.registrationNumber) - \(vehicle.make) \(vehicle.model)")
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            selection.map {
                                "\($0.registrationNumber) - \($0.make) \($0.model)"
                            } ?? "Select Vehicle"
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 170, alignment: .trailing)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



struct DriverPickerRow: View {
    let label: String
    let drivers: [User]
    @Binding var selection: User?
    var allTrips: [Trip] = []
    var startTime: Date = Date()
    var endTime: Date = Date()
    var currentTripId: UUID? = nil
    
    private var availableDrivers: [User] {
        drivers.filter { driver in
            driver.isActive && !hasOverlap(for: driver.id)
        }
    }
    
    private var unavailableDrivers: [User] {
        drivers.filter { driver in
            driver.isActive && hasOverlap(for: driver.id)
        }
    }
    
    private func hasOverlap(for entityId: UUID) -> Bool {
        allTrips.contains { trip in
            guard trip.id != currentTripId else { return false }
            guard trip.driverId == entityId else { return false }
            guard trip.tripStatus != .completed && trip.tripStatus != .cancelled else { return false }
            return trip.scheduledStartTime < endTime && trip.scheduledEndTime > startTime
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
            
            if drivers.isEmpty {
                Text("No drivers available")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.gray)
                    .italic()
            } else {
                Menu {
                    if !availableDrivers.isEmpty {
                        Section("Available Drivers") {
                            ForEach(availableDrivers) { driver in
                                Button {
                                    selection = driver
                                } label: {
                                    Text(driver.fullName)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    
                    if !unavailableDrivers.isEmpty {
                        Section("Unavailable Drivers") {
                            ForEach(unavailableDrivers) { driver in
                                Button {
                                    selection = driver
                                } label: {
                                    Text(driver.fullName)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } label: {
                    
                    HStack(spacing: 4) {
                        
                        Text(selection?.fullName ?? "Select Driver")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 170, alignment: .trailing)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Brand.royalBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



struct TripStatusPickerRow: View {
    @Binding var selection: TripStatus
    
    private let options: [(TripStatus, String, Color)] = [
        (.assigned,    "Assigned",    Color(red: 0.15, green: 0.38, blue: 0.90)),
        (.started,     "Started",     Color(red: 0.30, green: 0.70, blue: 0.46)),
        (.inProgress,  "In Progress", Color(red: 0.30, green: 0.70, blue: 0.46)),
        (.completed,   "Completed",   Color(red: 0.55, green: 0.58, blue: 0.62)),
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

@MainActor
func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = address
    let search = MKLocalSearch(request: request)
    do {
        let response = try await search.start()
        return response.mapItems.first?.placemark.coordinate
    } catch {
        return nil
    }
}

func fallbackCoordinate(for address: String) -> CLLocationCoordinate2D {
    let normalized = address.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.contains("mumbai") {
        return CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    } else if normalized.contains("delhi") || normalized.contains("okhla") || normalized.contains("nehru") {
        return CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090)
    } else if normalized.contains("pune") {
        return CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    } else if normalized.contains("gurgaon") {
        return CLLocationCoordinate2D(latitude: 28.5034, longitude: 77.0841)
    } else if normalized.contains("noida") {
        return CLLocationCoordinate2D(latitude: 28.6256, longitude: 77.3789)
    } else if normalized.contains("bangalore") || normalized.contains("bengaluru") {
        return CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)
    }
    return CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020)
}
