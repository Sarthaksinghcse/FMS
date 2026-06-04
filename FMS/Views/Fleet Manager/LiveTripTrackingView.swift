import SwiftUI
import MapKit

@available(iOS 26.0, *)
struct LiveTripTrackingView: View {
    let trip: Trip
    let driverName: String
    let driverPhone: String?
    let vehicleName: String
    
    @State private var viewModel: LiveTripTrackingViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @Environment(\.dismiss) private var dismiss
    
    init(trip: Trip, driverName: String, driverPhone: String?, vehicleName: String) {
        self.trip = trip
        self.driverName = driverName
        self.driverPhone = driverPhone
        self.vehicleName = vehicleName
        self._viewModel = State(initialValue: LiveTripTrackingViewModel(trip: trip))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Full screen Map
            Map(position: $cameraPosition) {
                // Route endpoints
                Marker("Start", systemImage: "play.circle.fill", coordinate: CLLocationCoordinate2D(latitude: trip.startLatitude, longitude: trip.startLongitude))
                    .tint(AppTheme.Status.success)
                
                Marker("End", systemImage: "flag.fill", coordinate: CLLocationCoordinate2D(latitude: trip.endLatitude, longitude: trip.endLongitude))
                    .tint(AppTheme.Status.danger)
                
                // Live/Simulated current location marker
                if let currentCoord = viewModel.vehicleLocation {
                    Marker(
                        "\(trip.tripCode) (Current Location)",
                        systemImage: "car.fill",
                        coordinate: currentCoord
                    )
                    .tint(AppTheme.Brand.primary)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()
            
            // Bottom Information Card
            VStack(spacing: 0) {
                // Drag handle bar
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Header Status
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VEHICLE LOCATION")
                                .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.secondary)
                                .tracking(1.0)
                            
                            Text(vehicleName)
                                .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        // Status Badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(trip.tripStatus == .inProgress ? AppTheme.Status.success : AppTheme.Brand.primary)
                                .frame(width: 6, height: 6)
                            Text(trip.tripStatus.displayName.uppercased())
                                .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        }
                        .foregroundColor(trip.tripStatus == .inProgress ? AppTheme.Status.success : AppTheme.Brand.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (trip.tripStatus == .inProgress ? AppTheme.Status.success : AppTheme.Brand.primary).opacity(0.1)
                        )
                        .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // Route Details
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(AppTheme.Status.success)
                                .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Departure")
                                    .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(.gray)
                                Text(trip.startLocation)
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "flag.circle.fill")
                                .foregroundColor(AppTheme.Status.danger)
                                .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Destination")
                                    .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                                    .foregroundColor(.gray)
                                Text(trip.endLocation)
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Driver card & call button
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Brand.primary.opacity(0.1))
                                .frame(width: 42, height: 42)
                            Text(driverInitials(for: driverName))
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(driverName)
                                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            
                            if let lastUpdate = viewModel.lastUpdated {
                                Text("Last updated \(timeAgo(from: lastUpdate))")
                                    .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(.gray)
                            } else {
                                Text("Syncing location...")
                                    .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        if let phone = driverPhone, !phone.isEmpty {
                            Button {
                                if let url = URL(string: "tel://\(phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(AppTheme.Status.success)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(AppTheme.Background.card)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -4)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle("Track Trip")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.Brand.primary)
                } else {
                    Button {
                        Task { await viewModel.fetchLocation() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startTracking()
            // Recenter map on vehicle location or route midpoint
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let startCoord = CLLocationCoordinate2D(latitude: trip.startLatitude, longitude: trip.startLongitude)
                let endCoord = CLLocationCoordinate2D(latitude: trip.endLatitude, longitude: trip.endLongitude)
                
                let midLat = (startCoord.latitude + endCoord.latitude) / 2
                let midLng = (startCoord.longitude + endCoord.longitude) / 2
                let midCoord = viewModel.vehicleLocation ?? CLLocationCoordinate2D(latitude: midLat, longitude: midLng)
                
                let span = MKCoordinateSpan(
                    latitudeDelta: abs(startCoord.latitude - endCoord.latitude) * 1.5 + 0.05,
                    longitudeDelta: abs(startCoord.longitude - endCoord.longitude) * 1.5 + 0.05
                )
                withAnimation(.easeInOut) {
                    cameraPosition = .region(MKCoordinateRegion(center: midCoord, span: span))
                }
            }
        }
        .onDisappear {
            viewModel.stopTracking()
        }
        .onChange(of: viewModel.lastUpdated) { _, newTime in
            if newTime != nil, let newLocation = viewModel.vehicleLocation {
                withAnimation(.easeInOut) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: newLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                    ))
                }
            }
        }
    }
    
    private func driverInitials(for name: String) -> String {
        let components = name.components(separatedBy: " ")
        let first = components.first?.first.map(String.init) ?? ""
        let last = components.count > 1 ? components.last?.first.map(String.init) ?? "" : ""
        let combined = first + last
        return combined.isEmpty ? "D" : combined.uppercased()
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
