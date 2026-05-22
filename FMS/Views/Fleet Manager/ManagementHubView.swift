//
//  ManagementHubView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Management Hub Card Model

struct CardMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let systemIcon: String
    let iconColor: Color
}

struct ManagementCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let metrics: [CardMetric]
    let destination: ManagementDestination
}

enum ManagementDestination: Hashable {
    case vehicleList
    case driverList
    case maintenanceStaff
    case tripList
}

// MARK: - Management Hub View

@available(iOS 26.0, *)
struct ManagementHubView: View {
    
    @State private var appearAnimation = false
    @State private var cardAnimations: [Bool] = [false, false, false, false]
    @State private var selectedDestination: ManagementDestination?
    
    @Environment(\.modelContext) private var modelContext
    
    // SwiftData queries for live statistics
    @Query private var vehicles: [Vehicle]
    @Query private var users: [User]
    @Query private var trips: [Trip]
    @Query private var workOrders: [WorkOrder]
    
    private var driverCount: Int {
        users.filter { $0.role == UserRole.driver }.count
    }
    
    private var maintenanceCount: Int {
        users.filter { $0.role == UserRole.maintenance }.count
    }
    
    private var managementCards: [ManagementCard] {
        [
            ManagementCard(
                title: "Vehicle Management",
                subtitle: "Manage all fleet vehicles",
                icon: "truck.box.fill",
                accentColor: AppTheme.Brand.royalBlue,
                metrics: [
                    CardMetric(label: "Total", value: "\(vehicles.count)", systemIcon: "car.fill", iconColor: AppTheme.Brand.royalBlue),
                    CardMetric(label: "Active", value: "\(vehicles.filter { $0.status == .active }.count)", systemIcon: "checkmark.circle.fill", iconColor: .green),
                    CardMetric(label: "In Shop", value: "\(vehicles.filter { $0.status == .inMaintenance }.count)", systemIcon: "exclamationmark.triangle.fill", iconColor: AppTheme.Brand.accent)
                ],
                destination: .vehicleList
            ),
            ManagementCard(
                title: "Driver Management",
                subtitle: "Manage drivers & assignments",
                icon: "person.fill.checkmark",
                accentColor: Color(red: 0.30, green: 0.70, blue: 0.46),
                metrics: [
                    CardMetric(label: "Total", value: "\(driverCount)", systemIcon: "person.2.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)),
                    CardMetric(label: "Online", value: "\(users.filter { $0.role == .driver && $0.isActive }.count)", systemIcon: "circle.fill", iconColor: .green),
                    CardMetric(label: "Offline", value: "\(users.filter { $0.role == .driver && !$0.isActive }.count)", systemIcon: "circle.fill", iconColor: .gray)
                ],
                destination: .driverList
            ),
            ManagementCard(
                title: "Maintenance Team",
                subtitle: "Manage technicians & tasks",
                icon: "wrench.and.screwdriver.fill",
                accentColor: AppTheme.Brand.accent,
                metrics: [
                    CardMetric(label: "Staff", value: "\(maintenanceCount)", systemIcon: "person.3.fill", iconColor: AppTheme.Brand.accent),
                    CardMetric(label: "Active Orders", value: "\(workOrders.filter { $0.status == .open || $0.status == .inProgress }.count)", systemIcon: "doc.text.fill", iconColor: .orange),
                    CardMetric(label: "Done Orders", value: "\(workOrders.filter { $0.status == .completed }.count)", systemIcon: "checkmark.seal.fill", iconColor: .green)
                ],
                destination: .maintenanceStaff
            ),
            ManagementCard(
                title: "Trip Management",
                subtitle: "Manage trips & schedules",
                icon: "map.fill",
                accentColor: Color(red: 0.58, green: 0.39, blue: 0.87),
                metrics: [
                    CardMetric(label: "Active", value: "\(trips.filter { $0.tripStatus == .started || $0.tripStatus == .inProgress }.count)", systemIcon: "arrow.triangle.turn.up.right.diamond.fill", iconColor: Color(red: 0.58, green: 0.39, blue: 0.87)),
                    CardMetric(label: "Pending", value: "\(trips.filter { $0.tripStatus == .assigned }.count)", systemIcon: "clock.fill", iconColor: .orange),
                    CardMetric(label: "Completed", value: "\(trips.filter { $0.tripStatus == .completed }.count)", systemIcon: "checkmark.circle.fill", iconColor: .green)
                ],
                destination: .tripList
            )
        ]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: - Cards Grid
                        cardsSection
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                        
                        // MARK: - Space at the bottom for Tab Bar
                        Spacer()
                            .frame(height: 110)
                    }
                }
            }
            .navigationTitle("Management Hub")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $selectedDestination) { destination in
                destinationView(for: destination)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
                // Stagger card animations
                for index in cardAnimations.indices {
                    let delay = Double(index) * 0.1 + 0.2
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(delay)) {
                        cardAnimations[index] = true
                    }
                }
            }
        }
    }
    
    // MARK: - Cards Section
    
    private var cardsSection: some View {
        VStack(spacing: 20) {
            ForEach(managementCards) { card in
                let index: Int = managementCards.firstIndex(where: { $0.id == card.id }) ?? 0
                ManagementCardView(card: card) {
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                    selectedDestination = card.destination
                }
                .frame(maxHeight: .infinity)
                .opacity(cardAnimations.indices.contains(index) && cardAnimations[index] ? 1 : 0)
                .offset(y: cardAnimations.indices.contains(index) && cardAnimations[index] ? 0 : 30)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Destination Router
    
    @ViewBuilder
    private func destinationView(for destination: ManagementDestination) -> some View {
        switch destination {
        case .vehicleList:
            VehicleListView()
        case .driverList:
            DriverListView()
        case .maintenanceStaff:
            MaintenanceStaffListView()
        case .tripList:
            TripListView()
        }
    }
}

// MARK: - Management Card View

@available(iOS 26.0, *)
struct ManagementCardView: View {
    
    let card: ManagementCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 14) {
                // Header Info Row
                HStack(spacing: 14) {
                    // Modern Rounded Glass Icon Container
                    ZStack {
                        Circle()
                            .fill(card.accentColor.opacity(0.12))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: card.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(card.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        
                        Text(card.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray.opacity(0.4))
                }
                
                Divider()
                    .background(Color.black.opacity(0.06))
                    .padding(.vertical, 2)
                
                // Dashboard Metrics Layout
                HStack(spacing: 0) {
                    ForEach(card.metrics) { metric in
                        HStack(spacing: 8) {
                            // Circular background for the small metric icon
                            ZStack {
                                Circle()
                                    .fill(metric.iconColor.opacity(0.08))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: metric.systemIcon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(metric.iconColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(metric.value)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                
                                Text(metric.label)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [card.accentColor.opacity(0.08), card.accentColor.opacity(0.01)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                card.accentColor.opacity(0.25),
                                card.accentColor.opacity(0.05),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview {
    ManagementHubView()
        .modelContainer(for: [Vehicle.self, User.self, Trip.self], inMemory: true)
}
