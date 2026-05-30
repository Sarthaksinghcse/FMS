import SwiftUI
import MapKit

struct FleetTrackingView: View {
    @State private var viewModel = FleetTrackingViewModel()
    @State private var selectedVehicle: MappedVehicle?
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, selection: $selectedVehicle) {
                MapCircle(center: viewModel.hubCoordinate, radius: viewModel.geofenceRadius)
                    .foregroundStyle(AppTheme.Brand.primary.opacity(0.1))
                    .stroke(AppTheme.Brand.primary, lineWidth: 2)
                
                ForEach(viewModel.mappedVehicles) { mappedVehicle in
                    Marker(
                        mappedVehicle.vehicle.vehicleNumber,
                        systemImage: "car.fill",
                        coordinate: mappedVehicle.coordinate
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
            
            if let selected = selectedVehicle {
                VehicleDetailCard(mappedVehicle: selected, onClose: {
                    selectedVehicle = nil
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Live Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
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

struct VehicleDetailCard: View {
    let mappedVehicle: MappedVehicle
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(mappedVehicle.vehicle.vehicleNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(mappedVehicle.vehicle.manufacturer) \(mappedVehicle.vehicle.model) (\(String(mappedVehicle.vehicle.year)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Text.secondary)
                        .font(.title3)
                }
            }
            
            Divider()
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(mappedVehicle.statusColor)
                            .frame(width: 8, height: 8)
                        Text(mappedVehicle.vehicle.status.rawValue.capitalized.replacingOccurrences(of: "_", with: " "))
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mappedVehicle.vehicle.licensePlate)
                        .font(.callout)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
}

#Preview {
    FleetTrackingView()
}
