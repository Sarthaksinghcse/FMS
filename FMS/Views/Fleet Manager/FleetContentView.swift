//FMS

import SwiftUI
import SwiftData
import Supabase

struct FleetContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    
    @Query(sort: \SOSAlert.createdAt, order: .reverse) private var sosAlerts: [SOSAlert]
    @State private var acknowledgedAlertIds: Set<UUID> = []
    
    @State private var showRedSplash = false
    @State private var sosMessage = ""
    @State private var isPulsing = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var usersRealtimeChannel: RealtimeChannelV2?
    
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
            
            
            if showRedSplash {
                ZStack {
                    
                    Color.red
                        .opacity(isPulsing ? 0.35 : 0.15)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isPulsing)
                    
                    
                    VStack(spacing: 24) {
                        
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .scaleEffect(isPulsing ? 1.2 : 0.95)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                            
                            Circle()
                                .fill(Color.red.gradient)
                                .frame(width: 56, height: 56)
                                .shadow(color: .red.opacity(0.4), radius: 10, x: 0, y: 4)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .symbolEffect(.bounce.up, options: .repeating)
                        }
                        
                        VStack(spacing: 8) {
                            Text("EMERGENCY PANIC SIGNAL")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.red)
                                .tracking(2.0)
                            
                            Text("🚨 CRITICAL SOS")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                        
                        Text(sosMessage)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.black.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .lineLimit(4)
                        
                        Button {
                            let activeAlerts = sosAlerts.filter { $0.status == .active }
                            for alert in activeAlerts {
                                acknowledgedAlertIds.insert(alert.id)
                            }
                            withAnimation(.easeIn(duration: 0.25)) {
                                showRedSplash = false
                            }
                        } label: {
                            Text("Acknowledge Alarm")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Color.red.gradient)
                                .clipShape(Capsule())
                                .shadow(color: .red.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 320)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 30, x: 0, y: 15)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(9999)
                .onAppear {
                    isPulsing = true
                }
            }
        }
        .onChange(of: sosAlerts) { _, _ in
            checkActiveSOSAlerts()
        }
        .task {
            checkActiveSOSAlerts()
            startRealtimeSOSListener()
            startRealtimeUsersListener()
        }
        .onDisappear {
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
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatters = [
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
                            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                            "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ",
                            "yyyy-MM-dd HH:mm:ss.SSSZZZZZ",
                            "yyyy-MM-dd HH:mm:ssZZZZZ",
                            "yyyy-MM-dd HH:mm:ss"
                        ].map { fmt -> DateFormatter in
                            let f = DateFormatter()
                            f.dateFormat = fmt
                            f.locale = Locale(identifier: "en_US_POSIX")
                            return f
                        }
                        
                        for formatter in formatters {
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        // Lenient ISO8601 Fallbacks
                        let isoFormatter = ISO8601DateFormatter()
                        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = isoFormatter.date(from: dateString) {
                            return date
                        }
                        
                        isoFormatter.formatOptions = [.withInternetDateTime]
                        if let date = isoFormatter.date(from: dateString) {
                            return date
                        }
                        
                        print("⚠️ [Realtime SOS] Lenient date parsing fallback to now for date: \(dateString)")
                        return Date()
                    }
                    
                    let data = try JSONEncoder().encode(change.record)
                    let alert = try decoder.decode(DBSOSAlert.self, from: data)
                    
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
    private func triggerEmergencySOS(alert: DBSOSAlert) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.error)
        
        let descriptor = FetchDescriptor<User>()
        let localUsers = (try? modelContext.fetch(descriptor)) ?? []
        let driverName = localUsers.first(where: { $0.id == alert.driverId })?.fullName ?? "Driver"
        
        sosMessage = alert.message ?? "Driver \(driverName) has triggered a panic alarm. Assistance is required immediately."
        
        let localSOS = alert.asLocalSOS
        modelContext.insert(localSOS)
        
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
        try? modelContext.save()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showRedSplash = true
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
    
    @MainActor
    private func checkActiveSOSAlerts() {
        let active = sosAlerts.filter { $0.status == .active }
        guard let firstActive = active.first else {
            if showRedSplash {
                withAnimation {
                    showRedSplash = false
                }
            }
            return
        }
        
        if !acknowledgedAlertIds.contains(firstActive.id) {
            let descriptor = FetchDescriptor<User>()
            let localUsers = (try? modelContext.fetch(descriptor)) ?? []
            let driverName = localUsers.first(where: { $0.id == firstActive.driverId })?.fullName ?? "Driver"
            
            sosMessage = firstActive.message ?? "Driver \(driverName) has triggered a panic alarm. Assistance is required immediately."
            
            if !showRedSplash {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showRedSplash = true
                }
            }
        }
    }
}

#Preview {
    FleetContentView()
}
