//
//  ReportsView.swift
//  FMS
//
//  Created on 21/05/26.
//

import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // SwiftData Queries
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    @Query private var maintenanceRecords: [MaintenanceRecord]
    @Query private var defectReports: [DefectReport]
    
    @State private var selectedPeriod: String = "This Month"
    let periods = ["Today", "This Week", "This Month"]
    
    // MARK: - Computed Metrics for Analytics
    
    private var totalVehicles: Int { vehicles.count }
    private var activeVehiclesCount: Int { vehicles.filter { $0.status == .active }.count }
    private var inShopCount: Int { vehicles.filter { $0.status == .inMaintenance }.count }
    
    private var utilizationRate: Double {
        guard totalVehicles > 0 else { return 0.0 }
        return Double(activeVehiclesCount) / Double(totalVehicles)
    }
    
    private var totalTripsCount: Int {
        switch selectedPeriod {
        case "Today":
            let start = Calendar.current.startOfDay(for: Date())
            return trips.filter { $0.createdAt >= start }.count
        case "This Week":
            let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return trips.filter { $0.createdAt >= start }.count
        default:
            let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return trips.filter { $0.createdAt >= start }.count
        }
    }
    
    private var totalMaintenanceCost: Double {
        let relevantRecords: [MaintenanceRecord]
        switch selectedPeriod {
        case "Today":
            let start = Calendar.current.startOfDay(for: Date())
            relevantRecords = maintenanceRecords.filter { $0.serviceDate >= start }
        case "This Week":
            let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            relevantRecords = maintenanceRecords.filter { $0.serviceDate >= start }
        default:
            let start = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            relevantRecords = maintenanceRecords.filter { $0.serviceDate >= start }
        }
        return relevantRecords.reduce(0.0) { $0 + $1.cost }
    }
    
    private var openDefectsCount: Int {
        defectReports.filter { $0.status == .open || $0.status == .inProgress }.count
    }
    
    // Fuel Type counts
    private var fuelTypeDistribution: [FuelType: Int] {
        var distribution: [FuelType: Int] = [.petrol: 0, .diesel: 0, .electric: 0, .hybrid: 0]
        for vehicle in vehicles {
            distribution[vehicle.fuelType, default: 0] += 1
        }
        return distribution
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Period Selector
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(periods, id: \.self) { period in
                                Text(period).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // MARK: - Core Grid KPIs
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                            spacing: 12
                        ) {
                            ReportKpiCard(
                                title: "Utilization Rate",
                                value: String(format: "%.0f%%", utilizationRate * 100),
                                subtitle: "\(activeVehiclesCount) of \(totalVehicles) active",
                                icon: "gauge.with.needle",
                                color: AppTheme.Brand.primary,
                                bgColor: AppTheme.IconBg.blue
                            )
                            
                            ReportKpiCard(
                                title: "Trips Logged",
                                value: "\(totalTripsCount)",
                                subtitle: selectedPeriod,
                                icon: "map.fill",
                                color: Color(red: 0.58, green: 0.39, blue: 0.87),
                                bgColor: Color(red: 0.58, green: 0.39, blue: 0.87).opacity(0.12)
                            )
                            
                            ReportKpiCard(
                                title: "Maintenance Cost",
                                value: String(format: "₹%.0f", totalMaintenanceCost),
                                subtitle: "Expenses \(selectedPeriod.lowercased())",
                                icon: "wrench.and.screwdriver.fill",
                                color: AppTheme.Brand.amber,
                                bgColor: AppTheme.IconBg.amber
                            )
                            
                            ReportKpiCard(
                                title: "Active Issues",
                                value: "\(openDefectsCount)",
                                subtitle: "Pending attention",
                                icon: "exclamationmark.octagon.fill",
                                color: AppTheme.Status.danger,
                                bgColor: AppTheme.IconBg.red
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // MARK: - Fuel Type Breakdown
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fuel Distribution")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 12) {
                                ForEach([FuelType.electric, .hybrid, .diesel, .petrol], id: \.self) { fuel in
                                    let count = fuelTypeDistribution[fuel] ?? 0
                                    let percentage = totalVehicles > 0 ? Double(count) / Double(totalVehicles) : 0.0
                                    
                                    FuelProgressRow(
                                        fuelType: fuel,
                                        count: count,
                                        percentage: percentage
                                    )
                                }
                            }
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        
                        // MARK: - Fleet Availability Breakdown
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fleet Status Summary")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            
                            HStack(spacing: 20) {
                                StatusPillSummary(
                                    label: "Active / On Duty",
                                    count: activeVehiclesCount,
                                    color: AppTheme.Status.success
                                )
                                Spacer()
                                StatusPillSummary(
                                    label: "In Maintenance",
                                    count: inShopCount,
                                    color: AppTheme.Status.danger
                                )
                                Spacer()
                                StatusPillSummary(
                                    label: "Inactive",
                                    count: totalVehicles - activeVehiclesCount - inShopCount,
                                    color: .gray
                                )
                            }
                            .padding(.top, 4)
                        }
                        .padding(18)
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Analytics Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dismiss") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                    .font(.system(.body, design: .rounded))
                }
            }
        }
    }
}

// MARK: - KPI Card Helper

struct ReportKpiCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let bgColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                .stroke(AppTheme.Glass.border.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Fuel Progress Row Helper

struct FuelProgressRow: View {
    let fuelType: FuelType
    let count: Int
    let percentage: Double
    
    private var color: Color {
        switch fuelType {
        case .petrol: return AppTheme.Brand.accent
        case .diesel: return AppTheme.Brand.amber
        case .electric: return AppTheme.Status.success
        case .hybrid: return AppTheme.Brand.teal
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: fuelType.icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                    Text(fuelType.displayName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("\(count) \(count == 1 ? "vehicle" : "vehicles") (\(Int(percentage * 100))%)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percentage), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Status Summary Row Helper

struct StatusPillSummary: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .padding(.leading, 14)
        }
    }
}
