import SwiftUI
import SwiftData

struct DriverHistoryView: View {
    let driver: User

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.scheduledStartTime, order: .reverse) private var allTrips: [Trip]
    @Query(sort: \VehicleInspection.createdAt, order: .reverse) private var allInspections: [VehicleInspection]
    @Query(sort: \DefectReport.createdAt, order: .reverse) private var allDefects: [DefectReport]
    @Query private var vehicles: [Vehicle]

    @State private var selectedTab: HistoryTab = .trips
    @State private var animateIn = false

    enum HistoryTab: String, CaseIterable, Identifiable {
        case trips = "Trips"
        case inspections = "Inspections"
        case issues = "Issues"

        var id: String { self.rawValue }

        var icon: String {
            switch self {
            case .trips: return "map.fill"
            case .inspections: return "doc.text.magnifyingglass"
            case .issues: return "exclamationmark.triangle.fill"
            }
        }
    }

    // Helper data computed dynamically
    private var isOnline: Bool {
        driver.isActive || driverTrips.contains { $0.tripStatus == .started || $0.tripStatus == .inProgress }
    }

    private var assignedVehicle: Vehicle? {
        if let v = vehicles.first(where: { $0.assignedDriverId == driver.id }) {
            return v
        }
        let activeTrip = driverTrips.first { $0.tripStatus == .assigned || $0.tripStatus == .started || $0.tripStatus == .inProgress }
        if let trip = activeTrip, let v = vehicles.first(where: { $0.id == trip.vehicleId }) {
            return v
        }
        return nil
    }

    private var driverTrips: [Trip] {
        allTrips.filter { $0.driverId == driver.id }
    }

    private var driverInspections: [VehicleInspection] {
        allInspections.filter { $0.driverId == driver.id }
    }

    private var driverIssues: [DefectReport] {
        allDefects.filter { $0.reportedBy == driver.id }
    }

    private var totalDistanceKm: Double {
        driverTrips.filter { $0.tripStatus == .completed }.reduce(0) { $0 + $1.distanceKm }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeaderCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    assignedVehicleCard
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    statsStrip
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    tabSelector
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)

                    tabContent
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Driver Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateIn = true
            }
        }
    }

    // MARK: - Subviews

    private var profileHeaderCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [AppTheme.Brand.royalBlue.opacity(0.8), AppTheme.Brand.royalBlue],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 72, height: 72)
                        .shadow(color: AppTheme.Brand.royalBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                    Text(initials(for: driver.fullName))
                        .font(.system(size: 24 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(driver.fullName)
                        .font(.system(size: 22 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(.gray.opacity(0.6))
                        Text(driver.email)
                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(.gray.opacity(0.6))
                        Text(driver.phoneNumber)
                            .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }

            Divider()
                .background(Color.black.opacity(0.06))

            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isOnline ? AppTheme.Status.success : AppTheme.Status.danger)
                        .frame(width: 8, height: 8)
                    Text(isOnline ? "Active" : "Inactive")
                        .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                }
                .foregroundColor(isOnline ? AppTheme.Status.success : AppTheme.Status.danger)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isOnline ? AppTheme.Status.success.opacity(0.1) : AppTheme.Status.danger.opacity(0.1)))
                .overlay(Capsule().stroke(isOnline ? AppTheme.Status.success.opacity(0.2) : AppTheme.Status.danger.opacity(0.2), lineWidth: 1))

                HStack(spacing: 5) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                    Text("Driver")
                        .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                }
                .foregroundColor(AppTheme.Brand.royalBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.Brand.royalBlue.opacity(0.1)))
                .overlay(Capsule().stroke(AppTheme.Brand.royalBlue.opacity(0.2), lineWidth: 1))

                Spacer()
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private var assignedVehicleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ASSIGNED VEHICLE")
                .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .tracking(0.8)

            if let vehicle = assignedVehicle {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Brand.royalBlue.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: "car.fill")
                            .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(vehicle.make) \(vehicle.model)")
                            .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text("Reg: \(vehicle.registrationNumber)")
                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                        .foregroundColor(.gray.opacity(0.3))
                }
                .padding(14)
                .background(Color.black.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 16 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No Vehicle Assigned")
                        .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.6))
                        .italic()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            statItem(title: "Trips", value: "\(driverTrips.count)", icon: "map", color: AppTheme.Brand.royalBlue)
            statItem(title: "Inspections", value: "\(driverInspections.count)", icon: "doc.text.magnifyingglass", color: AppTheme.Brand.violet)
            statItem(title: "Issues Reported", value: "\(driverIssues.count)", icon: "exclamationmark.triangle", color: AppTheme.Brand.accent)
        }
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text(title)
                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private var tabSelector: some View {
        Picker("Category", selection: $selectedTab) {
            ForEach(HistoryTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .trips:
            tripsHistoryList
        case .inspections:
            inspectionsHistoryList
        case .issues:
            issuesHistoryList
        }
    }

    // MARK: - Trips List

    private var tripsHistoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if driverTrips.isEmpty {
                emptyTabState(message: "No trips assigned to this driver yet.", icon: "map.fill")
            } else {
                ForEach(driverTrips) { trip in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(trip.tripCode)
                                .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            Spacer()
                            tripStatusBadge(status: trip.tripStatus)
                        }

                        HStack(spacing: 8) {
                            VStack(spacing: 4) {
                                Circle().fill(AppTheme.Brand.royalBlue).frame(width: 6, height: 6)
                                Line().stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2]))
                                    .foregroundColor(.gray.opacity(0.4))
                                    .frame(width: 1, height: 16)
                                Image(systemName: "mappin.circle.fill").font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0))).foregroundColor(AppTheme.Brand.accent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.startLocation)
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                                Text(trip.endLocation)
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                        }

                        Divider()
                            .background(Color.black.opacity(0.06))

                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(.gray)
                                Text(trip.scheduledStartTime.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(String(format: "%.1f km", trip.distanceKm))
                                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.royalBlue)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.Background.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.04), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                }
            }
        }
    }

    private func tripStatusBadge(status: TripStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.badgeIcon)
                .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
            Text(status.displayName)
                .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
        }
        .foregroundColor(status.badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(status.badgeColor.opacity(0.1)))
        .overlay(Capsule().stroke(status.badgeColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Inspections List

    private var inspectionsHistoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if driverInspections.isEmpty {
                emptyTabState(message: "No safety inspections submitted yet.", icon: "doc.text.magnifyingglass")
            } else {
                ForEach(driverInspections) { inspection in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: inspection.inspectionType.icon)
                                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                    .foregroundColor(inspection.inspectionType.color)
                                Text(inspection.inspectionType.displayName)
                                    .font(.system(size: 14 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                            }
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Circle().fill(inspection.defectReported ? AppTheme.Status.danger : AppTheme.Status.success).frame(width: 6, height: 6)
                                Text(inspection.defectReported ? "Issue Reported" : "All Clear")
                                    .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(inspection.defectReported ? AppTheme.Status.danger : AppTheme.Status.success)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(inspection.defectReported ? AppTheme.Status.danger.opacity(0.1) : AppTheme.Status.success.opacity(0.1)))
                        }

                        // Inspection checklist summary
                        HStack(spacing: 8) {
                            checklistIcon(label: "Brakes", ok: inspection.brakeCondition)
                            checklistIcon(label: "Tires", ok: inspection.tireCondition)
                            checklistIcon(label: "Engine", ok: inspection.engineCondition)
                            checklistIcon(label: "Lights", ok: inspection.lightsCondition)
                            checklistIcon(label: "Oil", ok: inspection.oilLevelOk)
                        }
                        .padding(.vertical, 4)

                        if let remarks = inspection.remarks, !remarks.isEmpty {
                            Divider()
                                .background(Color.black.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remarks")
                                    .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .black, design: .rounded))
                                    .foregroundColor(.gray)
                                    .tracking(0.5)
                                Text(remarks)
                                    .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                                    .foregroundColor(.black.opacity(0.8))
                            }
                        }

                        Divider()
                            .background(Color.black.opacity(0.06))

                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                .foregroundColor(.gray)
                            Text(inspection.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.Background.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.04), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                }
            }
        }
    }

    private func checklistIcon(label: String, ok: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(ok ? AppTheme.Status.success : AppTheme.Status.danger)
            Text(label)
                .font(.system(size: 10 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(0.03)))
    }

    // MARK: - Issues List

    private var issuesHistoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if driverIssues.isEmpty {
                emptyTabState(message: "No issues reported yet.", icon: "exclamationmark.triangle.fill")
            } else {
                ForEach(driverIssues) { defect in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(defect.title)
                                    .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                Text(defect.defectDescription)
                                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                                    .foregroundColor(.gray)
                                    .lineLimit(3)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 6) {
                                defectSeverityBadge(severity: defect.severity)
                                defectStatusBadge(status: defect.status)
                            }
                        }

                        Divider()
                            .background(Color.black.opacity(0.06))

                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                                .foregroundColor(.gray)
                            Text(defect.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(AppTheme.Background.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.04), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                }
            }
        }
    }

    private func defectSeverityBadge(severity: DefectSeverity) -> some View {
        Text(severity.displayName)
            .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(severity.color))
    }

    private func defectStatusBadge(status: DefectStatus) -> some View {
        Text(status.displayName)
            .font(.system(size: 9 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
            .foregroundColor(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(status.color.opacity(0.1)))
            .overlay(Capsule().stroke(status.color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Utilities

    private func emptyTabState(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(.gray.opacity(0.4))
            Text(message)
                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AccessibilityManager.shared.isHighContrastEnabled ? Color.black : Color.black.opacity(0.03), lineWidth: 1))
    }
}

// Drawing helper
struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// Extension helpers for domain mappings
extension InspectionType {
    var displayName: String {
        switch self {
        case .preTrip: return "Pre-Trip Inspection"
        case .postTrip: return "Post-Trip Inspection"
        }
    }

    var icon: String {
        switch self {
        case .preTrip: return "arrow.right.circle.fill"
        case .postTrip: return "arrow.left.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .preTrip: return AppTheme.Brand.royalBlue
        case .postTrip: return AppTheme.Brand.violet
        }
    }
}

extension DefectSeverity {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return AppTheme.Status.success
        case .medium: return AppTheme.Status.warning
        case .high: return AppTheme.Status.danger
        }
    }
}

extension DefectStatus {
    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .resolved: return "Resolved"
        }
    }

    var color: Color {
        switch self {
        case .open: return AppTheme.Status.danger
        case .inProgress: return AppTheme.Status.warning
        case .resolved: return AppTheme.Status.success
        }
    }
}
