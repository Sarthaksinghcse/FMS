import SwiftUI
import MapKit

struct FleetTrackingView: View {
    @State private var viewModel = FleetTrackingViewModel()
    @State private var selectedVehicle: MappedVehicle?
    @Environment(\.dismiss)private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentRoute: MKRoute?
    var initialSelectedVehicleId: UUID? = nil
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, selection: $selectedVehicle) {
                MapCircle(center: viewModel.hubCoordinate, radius: viewModel.geofenceRadius)
                    .foregroundStyle(AppTheme.Brand.primary.opacity(0.1))
                    .stroke(AppTheme.Brand.primary, lineWidth: 2)
                
                if let route = currentRoute {
                    MapPolyline(route)
                        .stroke(AppTheme.Brand.primary, lineWidth: 5)
                }
                
                ForEach(viewModel.mappedVehicles.filter { $0.coordinate != nil }) { mappedVehicle in
                    Marker(
                        mappedVehicle.vehicle.vehicleNumber,
                        systemImage: "car.fill",
                        coordinate: mappedVehicle.coordinate!
                    )
                    .tint(mappedVehicle.statusColor)
                    .tag(mappedVehicle)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
            
            if viewModel.isLoading {
                VStack {
                    ProgressView("Loading vehicles...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text(error)
                        .foregroundColor(AppTheme.Status.danger)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 40)
            }
            
            if !viewModel.mappedVehicles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(spacing: 16) {
                            ForEach(viewModel.mappedVehicles) { vehicle in
                                VehicleHorizontalCard(
                                    mappedVehicle: vehicle,
                                    isSelected: selectedVehicle == vehicle
                                )
                                .id(vehicle.id)
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        selectedVehicle = vehicle
                                        if let coordinate = vehicle.coordinate {
                                            cameraPosition = .region(MKCoordinateRegion(
                                                center: coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                            ))
                                        }
                                        proxy.scrollTo(vehicle.id, anchor: .center)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .scrollTargetLayout()
                        .onChange(of: selectedVehicle?.id) { _, newId in
                            if let newId = newId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        proxy.scrollTo(newId, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollTargetBehavior(.viewAligned)
                .simultaneousGesture(
                    DragGesture().onChanged { value in
                        if abs(value.translation.width) > 5 && selectedVehicle != nil {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedVehicle = nil
                            }
                        }
                    }
                )
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Live Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { await viewModel.loadVehicles() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
        }
        .onAppear {
            viewModel.startLiveTracking()
        }
        .onDisappear {
            viewModel.stopLiveTracking()
        }
        .onChange(of: viewModel.mappedVehicles) { _, newVehicles in
            if let currentSelected = selectedVehicle {
                if let updated = newVehicles.first(where: { $0.vehicle.id == currentSelected.vehicle.id }) {
                    selectedVehicle = updated
                } else {
                    selectedVehicle = nil
                }
            } else if let initialId = initialSelectedVehicleId {
                if let matched = newVehicles.first(where: { $0.vehicle.id == initialId }) {
                    selectedVehicle = matched
                    if let coordinate = matched.coordinate {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                }
            }
        }
        .onChange(of: selectedVehicle?.id) { _, newId in
            if let newId = newId, let vehicle = viewModel.mappedVehicles.first(where: { $0.id == newId }) {
                fetchRoute(for: vehicle)
            } else {
                withAnimation(.easeInOut) {
                    currentRoute = nil
                }
            }
        }
    }
    
    private func fetchRoute(for vehicle: MappedVehicle) {
        guard let trip = vehicle.trip else {
            withAnimation(.easeInOut) { currentRoute = nil }
            return
        }
        
        Task {
            let geocoder = CLGeocoder()
            do {
                let sourcePlacemarks = try? await geocoder.geocodeAddressString(trip.source)
                let destPlacemarks = try? await geocoder.geocodeAddressString(trip.destination)
                
                let sourceCoord = sourcePlacemarks?.first?.location?.coordinate ?? vehicle.coordinate
                let destCoord = destPlacemarks?.first?.location?.coordinate
                
                guard let source = sourceCoord, let dest = destCoord else {
                    await MainActor.run { withAnimation { currentRoute = nil } }
                    return
                }
                
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
                request.transportType = .automobile
                
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                
                await MainActor.run {
                    withAnimation(.easeInOut) {
                        self.currentRoute = response.routes.first
                    }
                }
            } catch {
                print("Failed to calculate route: \(error.localizedDescription)")
                await MainActor.run {
                    withAnimation { self.currentRoute = nil }
                }
            }
        }
    }
}

struct VehicleHorizontalCard: View {
    let mappedVehicle: MappedVehicle
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mappedVehicle.trip?.tripCode ?? "No Active Trip")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Brand.primary)
                Spacer()
                Circle()
                    .fill(mappedVehicle.statusColor)
                    .frame(width: 8, height: 8)
            }
            
            HStack {
                Text(mappedVehicle.vehicle.vehicleNumber)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("\(mappedVehicle.vehicle.manufacturer) \(mappedVehicle.vehicle.model)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if isSelected {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().padding(.vertical, 2)
                    
                    if let driver = mappedVehicle.driver {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.secondary)
                            Text(driver.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        if let phone = driver.phoneNumber, !phone.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(phone)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    if let trip = mappedVehicle.trip {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(AppTheme.Status.success)
                                Text(trip.source)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "flag.circle.fill")
                                    .foregroundColor(AppTheme.Status.danger)
                                Text(trip.destination)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    if let coordinate = mappedVehicle.coordinate {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "location.fill")
                                .foregroundColor(AppTheme.Brand.primary)
                                .font(.caption)
                            Text(String(format: "Lat: %.4f, Lon: %.4f", coordinate.latitude, coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            HStack {
                if let lastUpdated = mappedVehicle.lastUpdated {
                    Text("Updated " + timeAgo(from: lastUpdated))
                        .font(.caption2)
                        .foregroundColor(AppTheme.Brand.primary)
                } else {
                    Text("Location Pending")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Text.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: isSelected ? UIScreen.main.bounds.width - 48 : 220)
        .background(
            ZStack {
                AppTheme.Background.card
                if isSelected {
                    AppTheme.Brand.primary.opacity(0.05)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(isSelected ? AppTheme.Brand.primary : AppTheme.Glass.border, lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: isSelected ? 12 : 6, x: 0, y: isSelected ? 6 : 3)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    FleetTrackingView()
}
