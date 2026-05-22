//
//  FleetDashboardView.swift
//  FMS
//
//  Created by Antigravity on 21/05/26.
//

import SwiftUI
import SwiftData

struct FleetDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var vehicles: [Vehicle]
    @Query private var allUsers: [User]
    @Query private var trips: [Trip]
    
    @State private var activeQuickAction: ActiveQuickAction? = nil
    
    enum ActiveQuickAction: Identifiable {
        case addVehicle
        case assignDriver
        case reports
        case alerts
        case maintenance
        
        var id: Self { self }
    }
    
    private var dynamicStats: [DashboardStat] {
        let totalVehicles = vehicles.count
        let activeVehicles = vehicles.filter { $0.status == .active }.count
        let driversOnline = allUsers.filter { $0.role == .driver && $0.isActive }.count
        let liveTrips = trips.filter { $0.tripStatus == .inProgress || $0.tripStatus == .started }.count
        
        return [
            DashboardStat(
                icon: "car.fill",
                iconColor: AppTheme.Brand.primary,
                iconBgColor: AppTheme.IconBg.blue,
                value: "\(totalVehicles)",
                label: "Total Vehicles",
                trend: "",
                isTrendPositive: true,
                graphData: []
            ),
            DashboardStat(
                icon: "location.fill",
                iconColor: AppTheme.Status.success,
                iconBgColor: AppTheme.IconBg.green,
                value: "\(activeVehicles)",
                label: "Active Now",
                trend: "",
                isTrendPositive: true,
                graphData: []
            ),
            DashboardStat(
                icon: "person.2.fill",
                iconColor: AppTheme.Brand.violet,
                iconBgColor: AppTheme.IconBg.violet,
                value: "\(driversOnline)",
                label: "Drivers Online",
                trend: "",
                isTrendPositive: true,
                graphData: []
            ),
            DashboardStat(
                icon: "arrow.up.arrow.down",
                iconColor: AppTheme.Brand.teal,
                iconBgColor: AppTheme.IconBg.teal,
                value: "\(liveTrips)",
                label: "Live Trips",
                trend: "",
                isTrendPositive: false,
                graphData: []
            )
        ]
    }
    
    // Dynamic greeting and formatted date to match screenshot or update live
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning, Manager"
        } else if hour < 17 {
            return "Good Afternoon, Manager"
        } else {
            return "Good Evening, Manager"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        // Header Greeting & Date (Sits right below native Large Title)
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
                        
                        // 2x2 Analytics Cards Grid
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(dynamicStats) { stat in
                                DashboardStatCard(stat: stat)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Quick Actions Section
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
                                                activeQuickAction = .addVehicle
                                            case "Assign Driver":
                                                activeQuickAction = .assignDriver
                                            case "Reports":
                                                activeQuickAction = .reports
                                            case "Alerts":
                                                activeQuickAction = .alerts
                                            case "Maintenance":
                                                activeQuickAction = .maintenance
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
                        
                        // Fleet Utilization Card
                        let totalVehiclesCount = vehicles.count
                        let activeVehiclesCount = vehicles.filter { $0.status == .active }.count
                        let progress = totalVehiclesCount > 0 ? Double(activeVehiclesCount) / Double(totalVehiclesCount) : 0.0
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 16) {
                                // Circular Progress Ring
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
                            .padding(18)
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        
                        // Recent Activity Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .center, spacing: 8) {
                                Text("Recent Activity")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                
                                // Red notification count badge
                                Text("3")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.Text.onDark)
                                    .frame(width: 18, height: 18)
                                    .background(AppTheme.Status.danger)
                                    .clipShape(Circle())
                                
                                Spacer()
                                
                                Button("See All") {
                                    print("See All pressed")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Brand.primary)
                            }
                            .padding(.horizontal, 16)
                            
                            // Activity Container Card
                            VStack(spacing: 0) {
                                ForEach(Array(DashboardMockData.activities.enumerated()), id: \.element.id) { index, activity in
                                    DashboardActivityRow(activity: activity)
                                    
                                    // Custom padded divider between rows
                                    if index < DashboardMockData.activities.count - 1 {
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                }
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 16)
                        }
                        // Extra bottom spacing to ensure content scrolls beautifully
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Fleet Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $activeQuickAction) { action in
                Group {
                    switch action {
                    case .addVehicle:
                        AddVehicleView()
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
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Toolbar Items: Notification bell and profile initials
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        // Bell Button
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
                                
                                // Red notification dot
                                Circle()
                                    .fill(AppTheme.Status.danger)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -2, y: 2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Profile avatar — tap for Sign Out menu
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
}

// MARK: - Circular Progress View Helper
struct FleetCircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(AppTheme.Glass.ringTrack, lineWidth: 6)
            
            // Progress arc
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    AppTheme.Brand.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
            
            // Inner percentage text
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
