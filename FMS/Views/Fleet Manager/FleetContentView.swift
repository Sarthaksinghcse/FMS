//FMS

import SwiftUI
import SwiftData
import Supabase
import MapKit
import AVFoundation

struct FleetContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    @Query(sort: \SOSAlert.createdAt, order: .reverse) private var sosAlerts: [SOSAlert]
    
    @State private var showRedSplash = false
    @State private var sosMessage = ""
    @State private var isPulsing = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var usersRealtimeChannel: RealtimeChannelV2?
    @State private var activeSOSAlert: DBSOSAlert?
    @State private var pollingTask: Task<Void, Never>?
    @State private var acknowledgedAlertIds = Set<UUID>()
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FleetDashboardView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(0)

                TripListView()
                    .tabItem {
                        Label("Trips", systemImage: "map.fill")
                    }
                    .tag(1)

                ManagementHubView()
                    .tabItem {
                        Label("Manage", systemImage: "slider.horizontal.3")
                    }
                    .tag(2)
                
                FleetAnalyticsView()
                    .tabItem{
                        Label("Analytics", systemImage: "chart.bar.xaxis")
                    }
                    .tag(3)
            }
            .tint(AppTheme.Brand.primary)
            
            
            if showRedSplash, let alert = activeSOSAlert {
                let driver = activeDriver(for: alert)
                let driverPhone = driver?.phoneNumber ?? "+91 9452404531"
                let driverName = driver?.fullName ?? "Sanskaar Yadav"
                
                let vehicle = activeVehicle(for: alert)
                let vehicleCode = vehicle?.registrationNumber ?? "BKE-001"
                let vehicleModel = vehicle != nil ? "\(vehicle!.make) \(vehicle!.model)" : "Harley-Davidson LiveWire One"
                
                ZStack {
                    // Full screen solid dark backdrop
                    Color.black.opacity(0.92)
                        .ignoresSafeArea()
                    
                    // Outer orange warning glowing border shadow
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Theme.darkOrange.opacity(0.35), lineWidth: 20)
                        .blur(radius: 12)
                        .ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20)
                            
                            // Pulsing exclamation alarm icon
                            ZStack {
                                Circle()
                                    .fill(Theme.darkOrange.opacity(0.15))
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(isPulsing ? 1.2 : 0.95)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                                
                                Circle()
                                    .fill(Theme.darkOrange.gradient)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: Theme.darkOrange.opacity(0.4), radius: 10, x: 0, y: 4)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                                    .symbolEffect(.bounce.up, options: .repeating)
                            }
                            
                            // Title Header
                            VStack(spacing: 6) {
                                Text("CRITICAL EMERGENCY ALERT")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.darkOrange)
                                    .tracking(2.0)
                                
                                Text("Driver SOS Triggered")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            // Translucent Glassmorphism Card
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 14) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(driverName)
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("Driver • \(driverPhone)")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Theme.darkOrange.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "motorcycle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(Theme.darkOrange)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vehicleCode)
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text(vehicleModel)
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.12))
                                
                                // Emergency message text
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EMERGENCY MESSAGE")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.darkOrange)
                                        .tracking(1.0)
                                    
                                    Text(alert.message ?? "Driver \(driverName) has triggered a panic alarm. Assistance is required immediately.")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.95))
                                        .lineSpacing(4)
                                }
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1.5)
                            )
                            .padding(.horizontal, 20)
                            
                            // MapView card showing coordinates
                            let centerCoord = CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: centerCoord,
                                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                            ))) {
                                Annotation(driverName, coordinate: centerCoord) {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.darkOrange.opacity(0.25))
                                            .frame(width: 44, height: 44)
                                        
                                        Circle()
                                            .fill(Theme.darkOrange)
                                            .frame(width: 26, height: 26)
                                            .shadow(color: Theme.darkOrange.opacity(0.4), radius: 6, x: 0, y: 3)
                                            .overlay(
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            }
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                            )
                            .overlay(
                                Text("LIVE GEOFENCE COORDINATES")
                                    .font(.system(size: 8, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.85))
                                    .cornerRadius(4)
                                    .padding(8),
                                alignment: .bottomTrailing
                            )
                            .padding(.horizontal, 20)
                            
                            Spacer().frame(height: 10)
                            
                            // Custom Slide to Acknowledge gesture track
                            SlideToAcknowledgeView {
                                acknowledgeSOS(alert: alert)
                            }
                            .padding(.horizontal, 20)
                            
                            Spacer().frame(height: 20)
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(9999)
                .onAppear {
                    isPulsing = true
                }
            }
        }
        .task {
            startRealtimeSOSListener()
            startRealtimeUsersListener()
            
            // Sync immediately on startup to get the latest online/offline active SOS
            await SupabaseManager.shared.syncAllData(context: modelContext)
            checkForActiveAlerts()
            
            // Start safety polling loop to fetch SOS alerts in the background every 15 seconds
            pollingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    if Task.isCancelled { break }
                    print("🔄 [SOS Polling] Safety sync running...")
                    await syncActiveSOSAlerts()
                }
            }
        }
        .onChange(of: sosAlerts) { _, _ in
            checkForActiveAlerts()
        }
        .onDisappear {
            pollingTask?.cancel()
            pollingTask = nil
            
            let client = SupabaseManager.shared.client
            if let activeChannel = realtimeChannel {
                Task {
                    await client.removeChannel(activeChannel)
                }
                realtimeChannel = nil
            }
            if let activeUsersChannel = usersRealtimeChannel {
                Task {
                    await client.removeChannel(activeUsersChannel)
                }
                usersRealtimeChannel = nil
            }
        }
    }
    
    private func startRealtimeSOSListener() {
        guard realtimeChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("fleet_manager_sos_alerts_realtime")
        
        Task {
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "sos_alerts"
            )
            
            do {
                try await channel.subscribeWithError()
                print("🟢 [Realtime SOS] Subscribed successfully to sos_alerts channel.")
            } catch {
                print("❌ [Realtime SOS] Failed to subscribe to channel: \(error.localizedDescription)")
            }
            self.realtimeChannel = channel
            
            for await change in changes {
                do {
                    let alert = try change.record.decode(as: DBSOSAlert.self)
                    if alert.status == .active {
                        triggerEmergencySOS(alert: alert)
                    }
                } catch {
                    print("❌ Failed to decode DBSOSAlert in Realtime SOS listener: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    private func checkForActiveAlerts() {
        if let active = sosAlerts.first(where: { $0.status == .active }) {
            if !showRedSplash && !acknowledgedAlertIds.contains(active.id) {
                triggerEmergencySOS(alert: active.asDBSOSAlert)
            }
        } else {
            if showRedSplash {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    showRedSplash = false
                    activeSOSAlert = nil
                }
            }
        }
    }
    
    @MainActor
    private func triggerEmergencySOS(alert: DBSOSAlert) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.error)
        
        let descriptor = FetchDescriptor<User>()
        let localUsers = (try? modelContext.fetch(descriptor)) ?? []
        let driverName = localUsers.first(where: { $0.id == alert.driverId })?.fullName ?? "Driver"
        
        sosMessage = alert.message ?? "Driver \(driverName) has triggered a panic alarm. Assistance is required immediately."
        activeSOSAlert = alert
        
        let alertId = alert.id
        let sosDescriptor = FetchDescriptor<SOSAlert>()
        let localSOSs = (try? modelContext.fetch(sosDescriptor)) ?? []
        if !localSOSs.contains(where: { $0.id == alertId }) {
            let localSOS = alert.asLocalSOS
            modelContext.insert(localSOS)
        }
        
        let notifDescriptor = FetchDescriptor<AppNotification>()
        let localNotifs = (try? modelContext.fetch(notifDescriptor)) ?? []
        if !localNotifs.contains(where: { $0.id == alertId }) {
            let localNotif = AppNotification(
                id: alert.id,
                userId: SupabaseManager.shared.currentUser?.id ?? UUID(),
                title: "🚨 EMERGENCY SOS SIGNAL",
                message: sosMessage,
                type: .sosAlert,
                isRead: false,
                createdAt: alert.createdAt
            )
            modelContext.insert(localNotif)
        }
        
        try? modelContext.save()
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            showRedSplash = true
        }
        
        SOSSoundManager.shared.playAlarm()
    }
    
    private func activeDriver(for alert: DBSOSAlert) -> User? {
        let descriptor = FetchDescriptor<User>()
        let localUsers = (try? modelContext.fetch(descriptor)) ?? []
        return localUsers.first(where: { $0.id == alert.driverId })
    }
    
    private func activeVehicle(for alert: DBSOSAlert) -> Vehicle? {
        guard let vId = alert.vehicleId else { return nil }
        let descriptor = FetchDescriptor<Vehicle>()
        let localVehicles = (try? modelContext.fetch(descriptor)) ?? []
        return localVehicles.first(where: { $0.id == vId })
    }
    
    @MainActor
    private func acknowledgeSOS(alert: DBSOSAlert) {
        // Simply record that this alert has been acknowledged locally by the manager
        // We do NOT change the status to resolved in Supabase or SwiftData here.
        // The status remains .active until resolved manually via the Alerts Feed detailed screen.
        acknowledgedAlertIds.insert(alert.id)
        
        SOSSoundManager.shared.stopAlarm()
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            showRedSplash = false
            activeSOSAlert = nil
        }
    }
    
    private func startRealtimeUsersListener() {
        guard usersRealtimeChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("fleet_manager_users_realtime")
        
        Task {
            let updateChanges = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "users"
            )
            
            let insertChanges = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "users"
            )
            
            try? await channel.subscribeWithError()
            self.usersRealtimeChannel = channel
            
            // Listen to updates
            Task {
                for await change in updateChanges {
                    guard let dbUser = try? change.record.decode(as: DBUser.self) else { continue }
                    handleUserRealtimeUpdate(dbUser: dbUser)
                }
            }
            
            // Listen to inserts
            Task {
                for await change in insertChanges {
                    guard let dbUser = try? change.record.decode(as: DBUser.self) else { continue }
                    handleUserRealtimeUpdate(dbUser: dbUser)
                }
            }
        }
    }
    
    @MainActor
    private func handleUserRealtimeUpdate(dbUser: DBUser) {
        let descriptor = FetchDescriptor<User>()
        let localUsers = (try? modelContext.fetch(descriptor)) ?? []
        if let local = localUsers.first(where: { $0.id == dbUser.id }) {
            local.fullName = dbUser.name
            local.email = dbUser.email
            local.phoneNumber = dbUser.phoneNumber ?? ""
            local.role = dbUser.role.asLocalRole
            local.isActive = dbUser.isActive
            try? modelContext.save()
            print("🟢 [Realtime] Updated user \(dbUser.name) online status to \(dbUser.isActive)")
        } else {
            let newUser = dbUser.asLocalUser
            modelContext.insert(newUser)
            try? modelContext.save()
            print("🟢 [Realtime] Added new user \(dbUser.name)")
        }
    }
    
    private func syncActiveSOSAlerts() async {
        do {
            let remoteSOS: [DBSOSAlert] = try await SupabaseManager.shared.client.from("sos_alerts")
                .select()
                .eq("status", value: DBSOSStatus.active.rawValue)
                .execute()
                .value
            
            await MainActor.run {
                let descriptor = FetchDescriptor<SOSAlert>()
                let localSOS = (try? modelContext.fetch(descriptor)) ?? []
                
                // 1. Update/insert active alerts
                for rs in remoteSOS {
                    if let local = localSOS.first(where: { $0.id == rs.id }) {
                        local.driverId = rs.driverId
                        local.vehicleId = rs.vehicleId
                        local.tripId = rs.tripId
                        local.latitude = rs.latitude
                        local.longitude = rs.longitude
                        local.message = rs.message
                        local.status = rs.status.toLocalStatus
                    } else {
                        modelContext.insert(rs.asLocalSOS)
                    }
                }
                
                // 2. Resolve local alerts that are no longer active in Supabase
                let remoteActiveIds = Set(remoteSOS.map { $0.id })
                for localAlert in localSOS {
                    if localAlert.status == .active && !remoteActiveIds.contains(localAlert.id) {
                        localAlert.status = .resolved
                        print("ℹ️ [SOS Polling] Local SOS \(localAlert.id) marked resolved because it is not active remotely.")
                    }
                }
                
                try? modelContext.save()
            }
        } catch {
            print("⚠️ [SOS Polling] Failed to fetch active SOS: \(error.localizedDescription)")
        }
    }
}

#Preview {
    FleetContentView()
}

struct SlideToAcknowledgeView: View {
    let onSwipeSuccess: () -> Void
    @State private var dragOffset: CGFloat = 0
    private let buttonWidth: CGFloat = 56
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let maxOffset = trackWidth - buttonWidth
            
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .frame(height: 56)
                    .overlay(
                        Capsule()
                            .stroke(Theme.darkOrange.opacity(0.35), lineWidth: 1.5)
                    )
                
                // Track Text
                HStack {
                    Spacer()
                    Text("Slide to Acknowledge")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.darkOrange)
                        .opacity(Double(1.0 - (dragOffset / maxOffset)))
                    Spacer()
                }
                
                // Sliding Button
                ZStack {
                    Circle()
                        .fill(Theme.darkOrange.gradient)
                        .frame(width: buttonWidth, height: buttonWidth)
                        .shadow(color: Theme.darkOrange.opacity(0.4), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            dragOffset = min(max(0, translation), maxOffset)
                        }
                        .onEnded { value in
                            if dragOffset >= maxOffset * 0.85 {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    dragOffset = maxOffset
                                }
                                onSwipeSuccess()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
            .frame(height: 56)
        }
        .frame(height: 56)
    }
}
