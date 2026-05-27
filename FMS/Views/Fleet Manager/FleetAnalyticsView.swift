import SwiftUI
import SwiftData
import Charts

struct FleetAnalyticsView: View {

    @Environment(\.modelContext) private var modelContext

    @Query private var vehicles: [Vehicle]
    @Query private var allUsers: [User]
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @Query(sort: \WorkOrder.createdAt, order: .reverse) private var workOrders: [WorkOrder]
    @Query(sort: \DefectReport.createdAt, order: .reverse) private var defectReports: [DefectReport]
    @Query private var maintenanceRecords: [MaintenanceRecord]

    @State private var viewModel = FleetAnalyticsViewModel()
    @State private var appearAnimation = false
    @State private var distributionTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        periodPicker

                        kpiCardsGrid

                        fleetStatusSection

                        tripTrendSection

                        tripStatusSection

                        vehicleDistributionSection

                        maintenanceHealthSection

                        driverOverviewSection

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Fleet Analytics")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(FleetAnalyticsViewModel.TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    // MARK: - KPI Cards (2×2)

    private var kpiCardsGrid: some View {
        let utilization     = viewModel.fleetUtilization(vehicles: vehicles)
        let completionRate  = viewModel.tripCompletionRate(trips: trips)
        let totalDist       = viewModel.totalDistance(trips: trips)
        let avgDist         = viewModel.averageTripDistance(trips: trips)

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            AnalyticsKPICard(
                title: "Utilization Rate",
                value: viewModel.formatPercent(utilization),
                subtitle: "\(vehicles.filter { $0.status == .active }.count) of \(vehicles.count) active",
                icon: "gauge.with.needle",
                color: AppTheme.Brand.primary,
                bgColor: AppTheme.IconBg.blue
            )

            AnalyticsKPICard(
                title: "Trip Completion",
                value: viewModel.formatPercent(completionRate),
                subtitle: viewModel.selectedPeriod.rawValue,
                icon: "checkmark.circle.fill",
                color: AppTheme.Status.success,
                bgColor: AppTheme.IconBg.green
            )

            AnalyticsKPICard(
                title: "Total Distance",
                value: "\(viewModel.formatDistance(totalDist)) km",
                subtitle: viewModel.selectedPeriod.rawValue,
                icon: "road.lanes",
                color: AppTheme.Brand.primaryDeep,
                bgColor: AppTheme.IconBg.indigo
            )

            AnalyticsKPICard(
                title: "Avg Trip Distance",
                value: "\(viewModel.formatDistance(avgDist)) km",
                subtitle: viewModel.selectedPeriod.rawValue,
                icon: "map.fill",
                color: AppTheme.Brand.violet,
                bgColor: AppTheme.IconBg.violet
            )
        }
        .padding(.horizontal, 16)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appearAnimation)
    }

    // MARK: - Fleet Status

    private var fleetStatusSection: some View {
        let counts = viewModel.vehicleStatusCounts(vehicles: vehicles)
        let total  = vehicles.count

        return analyticsCard(title: "Fleet Status", subtitle: "Current") {
            VStack(spacing: 16) {
                // Stacked bar
                GeometryReader { geo in
                    let width = geo.size.width
                    let activeW      = total > 0 ? width * CGFloat(counts.active) / CGFloat(total) : 0
                    let maintenanceW = total > 0 ? width * CGFloat(counts.maintenance) / CGFloat(total) : 0
                    let inactiveW    = width - activeW - maintenanceW

                    HStack(spacing: 2) {
                        if counts.active > 0 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(AppTheme.Status.success)
                                .frame(width: max(4, activeW))
                        }
                        if counts.maintenance > 0 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(AppTheme.Status.danger)
                                .frame(width: max(4, maintenanceW))
                        }
                        if counts.inactive > 0 {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: max(4, max(0, inactiveW)))
                        }
                    }
                }
                .frame(height: 14)

                // Status pills
                HStack(spacing: 20) {
                    fleetStatusPill(label: "Active", count: counts.active, color: AppTheme.Status.success)
                    Spacer()
                    fleetStatusPill(label: "In Maintenance", count: counts.maintenance, color: AppTheme.Status.danger)
                    Spacer()
                    fleetStatusPill(label: "Inactive", count: counts.inactive, color: Color.gray)
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: appearAnimation)
    }

    private func fleetStatusPill(label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.tertiary)
            }
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Text.primary)
                .padding(.leading, 14)
        }
    }

    // MARK: - Trip Trend (7-Day Bar Chart)

    private var tripTrendSection: some View {
        let trendData = viewModel.sevenDayTrend(trips: trips)
        let maxCount  = trendData.map(\.count).max() ?? 1

        return analyticsCard(title: "Trip Trends", subtitle: "Last 7 Days") {
            if trendData.allSatisfy({ $0.count == 0 }) {
                chartEmptyState(message: "No trips in the last 7 days")
            } else {
                Chart {
                    ForEach(trendData) { item in
                        BarMark(
                            x: .value("Day", item.date, unit: .day),
                            y: .value("Trips", item.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                    }

                    RuleMark(
                        y: .value("Average", Double(trendData.reduce(0) { $0 + $1.count }) / 7.0)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .foregroundStyle(AppTheme.Brand.accent.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Brand.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Brand.accent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .chartYScale(domain: 0 ... max(maxCount + 2, 5))
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.gray.opacity(0.15))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                }
                .frame(height: 200)
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appearAnimation)
    }

    // MARK: - Trip Status Breakdown (Donut)

    private var tripStatusSection: some View {
        let statusData  = viewModel.tripStatusBreakdown(trips: trips)
        let totalTrips  = viewModel.tripsInPeriodCount(trips: trips)

        return analyticsCard(title: "Trip Status", subtitle: viewModel.selectedPeriod.rawValue) {
            if statusData.isEmpty {
                chartEmptyState(message: "No trips in this period")
            } else {
                HStack(spacing: 20) {
                    // Donut chart
                    ZStack {
                        Chart {
                            ForEach(statusData) { item in
                                SectorMark(
                                    angle: .value("Count", item.count),
                                    innerRadius: .ratio(0.618),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(item.color)
                                .cornerRadius(4)
                            }
                        }
                        .frame(width: 140, height: 140)

                        // Center label
                        VStack(spacing: 1) {
                            Text("\(totalTrips)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Text.primary)
                            Text("Trips")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.Text.tertiary)
                        }
                    }

                    // Legend
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(statusData) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                Text(item.label)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.Text.secondary)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.Text.primary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: appearAnimation)
    }

    // MARK: - Vehicle Distribution (Tabbed Charts)

    private var vehicleDistributionSection: some View {
        analyticsCard(title: "Vehicle Distribution", subtitle: "Current Fleet") {
            VStack(spacing: 16) {
                // Tab selector
                Picker("Distribution", selection: $distributionTab) {
                    Text("By Type").tag(0)
                    Text("By Fuel").tag(1)
                }
                .pickerStyle(.segmented)

                if distributionTab == 0 {
                    vehicleTypeChart
                } else {
                    fuelTypeChart
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appearAnimation)
    }

    private var vehicleTypeChart: some View {
        let data = viewModel.vehicleTypeBreakdown(vehicles: vehicles)
        return Group {
            if data.isEmpty {
                chartEmptyState(message: "No vehicles registered")
            } else {
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Type", item.label)
                        )
                        .foregroundStyle(item.color.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Text.secondary)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.Text.primary)
                    }
                }
                .frame(height: CGFloat(max(data.count, 1)) * 50)
            }
        }
    }

    private var fuelTypeChart: some View {
        let data = viewModel.fuelTypeBreakdown(vehicles: vehicles)
        return Group {
            if data.isEmpty {
                chartEmptyState(message: "No vehicles registered")
            } else {
                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Fuel", item.label)
                        )
                        .foregroundStyle(item.color.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing, alignment: .leading, spacing: 8) {
                            Text("\(item.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Text.secondary)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.Text.primary)
                    }
                }
                .frame(height: CGFloat(max(data.count, 1)) * 50)
            }
        }
    }

    // MARK: - Maintenance Health

    private var maintenanceHealthSection: some View {
        let openWOs        = viewModel.openWorkOrdersCount(workOrders: workOrders)
        let defectRate     = viewModel.defectResolutionRate(defects: defectReports)
        let priorities     = viewModel.workOrderPriorities(workOrders: workOrders)
        let maintCost      = viewModel.maintenanceCost(records: maintenanceRecords)

        return analyticsCard(title: "Maintenance Health", subtitle: "Current") {
            VStack(spacing: 16) {
                // KPI row
                HStack(spacing: 12) {
                    maintenanceKPIPill(
                        title: "Open Work Orders",
                        value: "\(openWOs)",
                        icon: "wrench.and.screwdriver.fill",
                        color: AppTheme.Brand.amber
                    )
                    maintenanceKPIPill(
                        title: "Defect Resolution",
                        value: viewModel.formatPercent(defectRate),
                        icon: "checkmark.shield.fill",
                        color: AppTheme.Status.success
                    )
                }

                // Maintenance cost
                HStack(spacing: 12) {
                    maintenanceKPIPill(
                        title: "Maintenance Cost",
                        value: viewModel.formatCost(maintCost),
                        icon: "indianrupeesign.circle.fill",
                        color: AppTheme.Brand.violet
                    )
                    maintenanceKPIPill(
                        title: "Total Defects",
                        value: "\(defectReports.count)",
                        icon: "exclamationmark.triangle.fill",
                        color: AppTheme.Status.danger
                    )
                }

                // Priority breakdown
                VStack(alignment: .leading, spacing: 10) {
                    Text("Work Order Priority")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Text.tertiary)

                    ForEach(priorities) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(item.color)
                                .frame(width: 20)

                            Text(item.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.Text.primary)

                            Spacer()

                            Text("\(item.count)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.Text.primary)

                            // Mini bar
                            let maxPriority = max(priorities.map(\.count).max() ?? 1, 1)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(item.color.opacity(0.25))
                                .frame(width: 60, height: 8)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(item.color)
                                        .frame(width: 60 * CGFloat(item.count) / CGFloat(maxPriority))
                                }
                        }
                    }
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: appearAnimation)
    }

    private func maintenanceKPIPill(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.tertiary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.gray.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Driver Overview

    private var driverOverviewSection: some View {
        let stats = viewModel.driverStats(users: allUsers)

        return analyticsCard(title: "Driver Overview", subtitle: "Current") {
            HStack(spacing: 20) {
                // Circular progress
                FleetCircularProgressView(progress: stats.rate)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Driver Availability")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.Text.tertiary)

                    Text(viewModel.formatPercent(stats.rate))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Text.primary)

                    Text("\(stats.active) of \(stats.total) drivers active")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.Text.secondary)
                }

                Spacer()
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: appearAnimation)
    }

    // MARK: - Reusable Section Card

    private func analyticsCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.primary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.Text.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            content()
        }
        .padding(18)
        .background(AppTheme.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    private func chartEmptyState(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.Text.tertiary.opacity(0.4))
                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Text.tertiary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}


// MARK: - KPI Card Component

private struct AnalyticsKPICard: View {
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
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.tertiary)

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Text.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(AppTheme.Glass.border.opacity(0.4), lineWidth: 1)
        )
    }
}


#Preview {
    FleetAnalyticsView()
}
