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
    @State private var showProfile = false
    
    var body: some View {
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

                            HStack(spacing: 10) {
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
                        AddTripFormView()
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
            .sheet(isPresented: $showProfile) {
                FleetManagerProfileView()
                    .environment(\.modelContext, modelContext)
            }
            .task {
                DatabaseSeeder.seedIfEmpty(context: modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ProfileMenuButton(
                        initials: "FM",
                        avatarColor: AppTheme.Brand.primaryDeep
                    ) {
                        showProfile = true
                    }
                }
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



#Preview {
    FleetDashboardView()
}
