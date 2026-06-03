






import SwiftUI
import SwiftData

@main
@available(iOS 26.0, *)
struct FMSApp: App {
    init() {
        #if DEBUG
        DashboardNavigationTests.runTests()
        #endif
        // Disable scroll bouncing globally so screens do not move or bounce when dragged
        UIScrollView.appearance().bounces = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(SupabaseManager.shared)
        }
        .modelContainer(for: [
            User.self,
            Vehicle.self,
            Trip.self,
            VehicleInspection.self,
            DefectReport.self,
            WorkOrder.self,
            MaintenanceRecord.self,
            SOSAlert.self,
            AppNotification.self,
            InventoryItem.self,
            FuelLog.self,
            ComplianceAlert.self
        ])
    }
}
