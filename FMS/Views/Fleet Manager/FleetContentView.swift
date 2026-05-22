import SwiftUI

@available(iOS 26.0, *)
struct FleetContentView: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2") {
                NavigationStack {
                    FleetDashboardView()
                }
            }
            Tab("Management", systemImage: "slider.horizontal.3") {
                ManagementHubView()
            }
            Tab("Tracking", systemImage: "location") {
                NavigationStack {
                    FleetTrackingView()
                }
            }
        }
        .accentColor(AppTheme.Brand.primary)
    }
}

@available(iOS 26.0, *)
#Preview {
    FleetContentView()
}
