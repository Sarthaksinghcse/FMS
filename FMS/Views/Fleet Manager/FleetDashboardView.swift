//
//  FleetDashboardView.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI
import MapKit
import SwiftData

struct FleetDashboardView: View {
    /// 0 = Dashboard  |  1 = Tracking  |  2 = Manage
    @State private var selectedTab: Int = 0

    // MARK: - Greeting and Date Info
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning, Manager" }
        else if hour < 17 { return "Good Afternoon, Manager" }
        else { return "Good Evening, Manager" }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Tracking State
    @State private var selectedVehicle: TrackedVehicle? = nil
    @State private var cameraPos = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    ))

    private struct TrackedVehicle: Identifiable {
        let id = UUID()
        let regNo: String
        let model: String
        let driver: String
        let status: VehicleStatus
        let speed: String
        let coordinate: CLLocationCoordinate2D
    }

    private var trackedVehicles: [TrackedVehicle] {
        [
            TrackedVehicle(
                regNo: "DL-01-A-1234",
                model: "Tata Ace Gold",
                driver: "Priyanshu N.",
                status: .active,
                speed: "45 km/h",
                coordinate: CLLocationCoordinate2D(latitude: 28.6250, longitude: 77.2200)
            ),
            TrackedVehicle(
                regNo: "DL-03-C-5678",
                model: "Mahindra Supro",
                driver: "Amit K.",
                status: .active,
                speed: "58 km/h",
                coordinate: CLLocationCoordinate2D(latitude: 28.6010, longitude: 77.1890)
            ),
            TrackedVehicle(
                regNo: "DL-04-Y-9012",
                model: "Tata Ultra",
                driver: "Rohan S.",
                status: .inactive,
                speed: "Stopped",
                coordinate: CLLocationCoordinate2D(latitude: 28.6380, longitude: 77.2510)
            ),
            TrackedVehicle(
                regNo: "DL-02-B-3456",
                model: "Ashok Leyland",
                driver: "Suresh P.",
                status: .active,
                speed: "62 km/h",
                coordinate: CLLocationCoordinate2D(latitude: 28.5800, longitude: 77.2300)
            )
        ]
    }

    // MARK: - Main Body
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

            if #available(iOS 26.0, *) {
                ManagementHubView()
                    .tabItem {
                        Label("Manage", systemImage: "slider.horizontal.3")
                    }
                    .tag(2)
            }
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

                        // Greeting & Date
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greetingText)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                            Text(formattedDate)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        // 2×2 Analytics Cards
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12),
                                      GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(DashboardMockData.stats) { stat in
                                DashboardStatCard(stat: stat)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Quick Actions
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Actions")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(DashboardMockData.quickActions) { action in
                                        DashboardQuickActionCard(action: action) {
                                            print("Tapped: \(action.label)")
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }

                        // Fleet Utilization Card
                        HStack(spacing: 16) {
                            FleetCircularProgressView(progress: 0.67)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fleet Utilization")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("67%")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                                Text("32 of 48 vehicles active today")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)

                        // Recent Activity
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

                        Spacer().frame(height: 32)
                    }
                    .padding(.top, 8)
                } // ScrollView
            } // ZStack
            .navigationTitle("Fleet Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        // Notification Bell
                        Button(action: { print("Notifications tapped") }) {
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

                        // Profile avatar → Sign Out popover
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
                // Map View
                Map(position: $cameraPos) {
                    ForEach(trackedVehicles) { vehicle in
                        Annotation(vehicle.regNo, coordinate: vehicle.coordinate, anchor: .bottom) {
                            ZStack {
                                Circle()
                                    .fill((vehicle.status == .active ? Color.green : Color.gray).opacity(0.2))
                                    .frame(width: 42, height: 42)
                                Circle()
                                    .fill(vehicle.status == .active ? Color.green : Color.gray)
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

                // Bottom floating panel
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
                            ForEach(trackedVehicles) { vehicle in
                                Button {
                                    selectedVehicle = vehicle
                                    withAnimation {
                                        cameraPos = .region(MKCoordinateRegion(
                                            center: vehicle.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                        ))
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(vehicle.regNo)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.black)
                                            Spacer()
                                            // Status pill
                                            Text(vehicle.status == .active ? "Moving" : "Idle")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(vehicle.status == .active ? .green : .gray)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background((vehicle.status == .active ? Color.green : Color.gray).opacity(0.1))
                                                .cornerRadius(4)
                                        }

                                        Text(vehicle.model)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)

                                        HStack {
                                            Label(vehicle.driver, systemImage: "person.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(vehicle.speed)
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
                                            .stroke(selectedVehicle?.id == vehicle.id ? AppTheme.Brand.primary : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
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
                    Button(action: {
                        withAnimation {
                            cameraPos = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
                                span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                            ))
                            selectedVehicle = nil
                        }
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
        }
    }
}

// MARK: - Circular Progress Ring
struct FleetCircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(AppTheme.Glass.ringTrack, lineWidth: 6)
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(AppTheme.Brand.primary,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppTheme.Brand.primary)
        }
        .frame(width: 52, height: 52)
    }
}

#Preview {
    FleetDashboardView()
}
