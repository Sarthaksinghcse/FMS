import SwiftUI

struct FleetContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FleetDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            FleetTrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "location.fill")
                }
                .tag(1)

            TripListView()
                .tabItem {
                    Label("Trips", systemImage: "map.fill")
                }
                .tag(2)

            ManagementHubView()
                .tabItem {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .tint(AppTheme.Brand.primary)
    }
}

#Preview {
    FleetContentView()
}
