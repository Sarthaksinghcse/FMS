//
//  FleetDashboardView.swift
//  FMS
//

import SwiftUI
import SwiftData
import MapKit

struct FleetDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var vehicles: [Vehicle]
    @Query private var allUsers: [User]
    @Query private var trips: [Trip]
    
    @State private var viewModel = FleetDashboardViewModel()
    @State private var trackingViewModel = FleetTrackingViewModel()
    
    @State private var selectedTab = 0
    @State private var cameraPos: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))
    @State private var selectedVehicle: MappedVehicle?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            trackingTab
                .tabItem {
                    Label("Tracking", systemImage: "location.fill")
                }
                .tag(1)

            ManagementHubView()
                .tabItem {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
                .tag(2)
        }
        .accentColor(AppTheme.Brand.primary)
    }

    // MARK: - Dashboard Tab Content
    private var dashboardTab: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.getGreetingText())
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12),
                                      GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(viewModel.getDynamicStats(vehicles: vehicles, allUsers: allUsers, trips: trips)) { stat in
                                DashboardStatCard(stat: stat)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Actions")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(DashboardMockData.quickActions) { action in
                                        DashboardQuickActionCard(action: action) {
                                            let impact = UIImpactFeedbackGenerator(style: .medium)
                                            impact.impactOccurred()
                                            switch action.label {
                                            case "Add Vehicle":
                                                viewModel.activeQuickAction = .addVehicle
                                            case "Assign Driver":
                                                viewModel.activeQuickAction = .assignDriver
                                            case "Reports":
                                                viewModel.activeQuickAction = .reports
                                            case "Alerts":
                                                viewModel.activeQuickAction = .alerts
                                            case "Maintenance":
                                                viewModel.activeQuickAction = .maintenance
                                            default:
                                                break
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        
                        let totalVehiclesCount = vehicles.count
                        let activeVehiclesCount = vehicles.filter { $0.status == .active }.count
                        let progress = viewModel.getFleetUtilizationProgress(vehicles: vehicles)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 16) {
                                FleetCircularProgressView(progress: progress)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fleet Utilization")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.black)
                                    
                                    Text("\(activeVehiclesCount) of \(totalVehiclesCount) vehicles active today")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 8) {
                                Text("Recent Activity")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Text("3")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.Text.onDark)
                                    .frame(width: 18, height: 18)
                                    .background(AppTheme.Status.danger)
                                    .clipShape(Circle())

                                Spacer()

                                Button("See All") { print("See All pressed") }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Brand.primary)
                            }
                            .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(DashboardMockData.activities.enumerated()),
                                    id: \.element.id
                                ) { index, activity in
                                    DashboardActivityRow(activity: activity)
                                    
                                    if index < DashboardMockData.activities.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 16)
                        }
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Dashboard")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(item: $viewModel.activeQuickAction) { action in
                Group {
                    switch action {
                    case .addVehicle:
                        AddVehicleFormView()
                    case .assignDriver:
                        AssignDriverView()
                    case .reports:
                        ReportsView()
                    case .alerts:
                        AlertsFeedView()
                    case .maintenance:
                        MaintenanceManagementView()
                    }
                }
                .environment(\.modelContext, modelContext)
            }
            .task {
                DatabaseSeeder.seedIfEmpty(context: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Button(action: {
                            print("Notification tapped")
                        }) {
                            ZStack(alignment: .topTrailing) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.Background.card)
                                        .frame(width: 38, height: 38)
                                        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Text.primary.opacity(0.6))
                                }
                                
                                Circle()
                                    .fill(AppTheme.Status.danger)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -2, y: 2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        ProfileMenuButton(
                            initials: "FM",
                            avatarColor: AppTheme.Brand.primaryDeep
                        )
                    }
                    .padding(.trailing, 2)
                }
            }
        }
    }

    // MARK: - Tracking Tab Content
    private var trackingTab: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPos) {
                    ForEach(trackingViewModel.mappedVehicles) { vehicle in
                        let markerColor: Color = vehicle.vehicle.status == .inUse ? .green : .gray
                        Annotation(vehicle.vehicle.vehicleNumber, coordinate: vehicle.coordinate, anchor: .bottom) {
                            ZStack {
                                Circle()
                                    .fill(markerColor.opacity(0.2))
                                    .frame(width: 42, height: 42)
                                Circle()
                                    .fill(markerColor)
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.15), radius: 4)
                                Image(systemName: "truck.box.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .onTapGesture {
                                selectedVehicle = vehicle
                                withAnimation {
                                    cameraPos = .region(MKCoordinateRegion(
                                        center: vehicle.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                                    ))
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color(UIColor.systemGray4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    Text("Active Fleet Tracking")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(trackingViewModel.mappedVehicles) { vehicle in
                                let driverName = allUsers.first(where: { $0.id == vehicle.vehicle.assignedDriverId })?.fullName ?? "Unassigned"
                                TrackingVehicleCard(
                                    vehicle: vehicle,
                                    driverName: driverName,
                                    isSelected: selectedVehicle?.id == vehicle.id
                                ) {
                                    selectedVehicle = vehicle
                                    withAnimation {
                                        cameraPos = .region(MKCoordinateRegion(
                                            center: vehicle.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                        ))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, y: -2)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .navigationTitle("Live Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            cameraPos = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 37.334900, longitude: -122.009020),
                                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                            ))
                            selectedVehicle = nil
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
            .task {
                await trackingViewModel.loadVehicles()
            }
        }
    }
}

struct FleetCircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Glass.ringTrack, lineWidth: 6)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AppTheme.Brand.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Brand.primary)
        }
        .frame(width: 52, height: 52)
    }
}

struct TrackingVehicleCard: View {
    let vehicle: MappedVehicle
    let driverName: String
    let isSelected: Bool
    let onTap: () -> Void

    private var statusText: String {
        vehicle.vehicle.status == .inUse ? "Moving" : "Idle"
    }

    private var statusColor: Color {
        vehicle.vehicle.status == .inUse ? .green : .gray
    }

    private var driverLabel: String {
        driverName
    }

    private var speedLabel: String {
        vehicle.vehicle.status == .inUse ? "45 km/h" : "0 km/h"
    }

    private var borderColor: Color {
        isSelected ? AppTheme.Brand.primary : Color.clear
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(vehicle.vehicle.vehicleNumber)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Spacer()
                    Text(statusText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(4)
                }

                Text(vehicle.vehicle.model)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack {
                    Label(driverLabel, systemImage: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(speedLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .padding(12)
            .frame(width: 220)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    FleetDashboardView()
}
