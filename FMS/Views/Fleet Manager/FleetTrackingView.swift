//
//  FleetTrackingView.swift
//  FMS
//
//  Created by Priyanshu Namdev on 21/05/26.
//

import SwiftUI
import MapKit

@available(iOS 26.0, *)
struct FleetTrackingView: View {
    @StateObject private var viewModel = FleetTrackingViewModel()
    @State private var selectedVehicle: MappedVehicle?
    
    // Initial camera position centered on the hub
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. The Map
                Map(position: $cameraPosition, selection: $selectedVehicle) {
                    // Draw the Geofence
                    MapCircle(center: viewModel.hubCoordinate, radius: viewModel.geofenceRadius)
                        .foregroundStyle(Color.blue.opacity(0.1))
                        .stroke(Color.blue, lineWidth: 2)
                    
                    // Draw the Vehicles
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
                
                // 2. Loading / Error Overlays
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
                            .foregroundColor(.red)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 40)
                }
                
                // 3. Selected Vehicle Detail Card
                if let selected = selectedVehicle {
                    VehicleDetailCard(mappedVehicle: selected, onClose: {
                        selectedVehicle = nil
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Live Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await viewModel.loadVehicles() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadVehicles()
            }
            // Animate selection changes
            .animation(.easeInOut, value: selectedVehicle?.id)
        }
    }
}

// MARK: - Vehicle Detail Card
@available(iOS 26.0, *)
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
                        .foregroundColor(.gray)
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
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
}

@available(iOS 26.0, *)
#Preview {
    FleetTrackingView()
}
