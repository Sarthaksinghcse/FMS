import SwiftUI
import SwiftData

struct AllActivitiesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var onActivityTap: ((DashboardActivity) -> Void)? = nil

    // Live SwiftData queries
    @Query(sort: \Trip.createdAt,          order: .reverse) private var trips: [Trip]
    @Query(sort: \SOSAlert.createdAt,      order: .reverse) private var sosAlerts: [SOSAlert]
    @Query(sort: \DefectReport.createdAt,  order: .reverse) private var defectReports: [DefectReport]
    @Query(sort: \WorkOrder.createdAt,     order: .reverse) private var workOrders: [WorkOrder]
    @Query private var users: [User]
    @Query private var vehicles: [Vehicle]

    @State private var selectedFilter: FilterTab = .all
    @State private var searchText: String = ""

    private let viewModel = FleetDashboardViewModel()

    enum FilterTab: String, CaseIterable, Identifiable {
        case all           = "All"
        case driver        = "Driver"
        case fleetManager  = "Fleet Manager"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .all:          return "list.bullet"
            case .driver:       return "person.fill"
            case .fleetManager: return "briefcase.fill"
            }
        }

        var color: Color {
            switch self {
            case .all:          return AppTheme.Brand.primary
            case .driver:       return AppTheme.Brand.teal
            case .fleetManager: return AppTheme.Brand.violet
            }
        }
    }

    private var allActivities: [DashboardActivity] {
        viewModel.buildActivities(
            trips: trips,
            users: users,
            vehicles: vehicles,
            sosAlerts: sosAlerts,
            defectReports: defectReports,
            workOrders: workOrders
        )
    }

    private var filteredActivities: [DashboardActivity] {
        let bySource: [DashboardActivity]
        switch selectedFilter {
        case .all:
            bySource = allActivities
        case .driver:
            bySource = allActivities.filter { $0.source == "Driver" }
        case .fleetManager:
            bySource = allActivities.filter { $0.source == "Fleet Manager" }
        }

        guard !searchText.isEmpty else { return bySource }
        let q = searchText.lowercased()
        return bySource.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q) ||
            $0.source.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(FilterTab.allCases) { tab in
                                filterChip(tab)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(AppTheme.Background.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)

                    // Activity list
                    if filteredActivities.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filteredActivities.enumerated()), id: \.element.id) { index, activity in
                                    Button {
                                        dismiss()
                                        onActivityTap?(activity)
                                    } label: {
                                        DashboardActivityRow(activity: activity)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if index < filteredActivities.count - 1 {
                                        Divider().padding(.leading, 66)
                                    }
                                }
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("All Activity")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search activities…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.royalBlue)
                        .font(.system(.body, design: .rounded))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(filteredActivities.count) events")
                        .font(.system(size: 12 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                }
            }
        }
    }

    // MARK: - Sub-views

    private func filterChip(_ tab: FilterTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedFilter = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold))
                Text(tab.rawValue)
                    .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
            }
            .foregroundColor(selectedFilter == tab ? .white : tab.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(selectedFilter == tab ? tab.color : tab.color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selectedFilter == tab ? tab.color : tab.color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                .font(.system(size: 44 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0)))
                .foregroundColor(AppTheme.Text.tertiary.opacity(0.4))
            Text(searchText.isEmpty ? "No activities yet" : "No matching activities")
                .font(.system(size: 15 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Text.secondary)
            Text(searchText.isEmpty ? "Activity will appear here as trips, alerts and maintenance events happen." : "Try a different search term or filter.")
                .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), design: .rounded))
                .foregroundColor(AppTheme.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

#Preview {
    AllActivitiesView(onActivityTap: nil)
}
