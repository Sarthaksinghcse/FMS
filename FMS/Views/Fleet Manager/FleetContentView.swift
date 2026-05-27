//FMS

import SwiftUI
import SwiftData
import Supabase

struct FleetContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    
    @State private var showRedSplash = false
    @State private var sosMessage = ""
    @State private var isPulsing = false
    @State private var realtimeChannel: RealtimeChannelV2?
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FleetDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(0)

                //                FleetTrackingView()
                //                    .tabItem {
                //                        Label("Tracking", systemImage: "location.fill")
                //                    }
                //                    .tag(1)

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
        .task {
            startRealtimeSOSListener()
        }
        .onDisappear {
            if let activeChannel = realtimeChannel {
                let client = SupabaseManager.shared.client
                Task {
                    await client.removeChannel(activeChannel)
                }
                realtimeChannel = nil
            }
        }
    }
    
    private func startRealtimeSOSListener() {
        guard realtimeChannel == nil else { return }
        let client = SupabaseManager.shared.client
        let channel = client.channel("fleet_manager_notifications")
        
        Task {
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "notifications"
            )
            
            try? await channel.subscribeWithError()
            self.realtimeChannel = channel
            
            for await change in changes {
                guard let notif = try? change.record.decode(as: DBNotification.self) else { continue }
                if notif.type == .emergency {
                    triggerEmergencySOS(notif: notif)
                }
            }
        }
    }
    
    @MainActor
    private func triggerEmergencySOS(notif: DBNotification) {
        
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.error)
        
        sosMessage = notif.message
        
        
        let localNotif = notif.asLocalNotification
        modelContext.insert(localNotif)
        
        let localSOS = SOSAlert(
            id: notif.id,
            driverId: notif.userId,
            vehicleId: UUID(), 
            tripId: UUID(), 
            latitude: 28.5450, 
            longitude: 77.2600, 
            message: notif.message,
            status: .active,
            createdAt: notif.createdAt
        )
        modelContext.insert(localSOS)
        try? modelContext.save()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showRedSplash = true
        }
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                if showRedSplash && sosMessage == notif.message {
                    showRedSplash = false
                }
            }
        }
    }
}

#Preview {
    FleetContentView()
}
