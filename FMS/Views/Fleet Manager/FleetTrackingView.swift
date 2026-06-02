import SwiftUI
import MapKit

struct FleetTrackingView: View {
    @State private var viewModel = FleetTrackingViewModel()
    @State private var selectedVehicle: MappedVehicle?
    @Environment(\.dismiss)private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, selection: $selectedVehicle) {
                MapCircle(center: viewModel.hubCoordinate, radius: viewModel.geofenceRadius)
                    .foregroundStyle(AppTheme.Brand.primary.opacity(0.1))
                    .stroke(AppTheme.Brand.primary, lineWidth: 2)
                
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
                    HStack(spacing: 16) {
                        ForEach(viewModel.mappedVehicles) { vehicle in
                            VehicleHorizontalCard(
                                mappedVehicle: vehicle,
                                isSelected: selectedVehicle == vehicle
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut) {
                                    selectedVehicle = vehicle
                                    if let coordinate = vehicle.coordinate {
                                        cameraPosition = .region(MKCoordinateRegion(
                                            center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
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
        .animation(.easeInOut, value: selectedVehicle?.id)
    }
}

struct VehicleHorizontalCard: View {
    let mappedVehicle: MappedVehicle
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mappedVehicle.vehicle.vehicleNumber)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Circle()
                    .fill(mappedVehicle.statusColor)
                    .frame(width: 8, height: 8)
            }
            
            Text("\(mappedVehicle.vehicle.manufacturer) \(mappedVehicle.vehicle.model)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack {
                if let lastUpdated = mappedVehicle.lastUpdated {
                    Text(timeAgo(from: lastUpdated))
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
        .frame(width: 200)
        .background(isSelected ? AppTheme.Brand.primary.opacity(0.1) : AppTheme.Background.card)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(isSelected ? AppTheme.Brand.primary : Color.clear, lineWidth: 2)
        )
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: isSelected ? 8 : 4, x: 0, y: 2)
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
