






import SwiftUI
import AVKit

@available(iOS 26.0, *)
struct ContentView: View {
    @Environment(SupabaseManager.self) private var supabaseManager
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.4)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                if let user = supabaseManager.currentUser {
                    switch user.role {
                    case .fleetManager:
                        FleetContentView()
                    case .maintenance:
                        
                        MaintenanceDashboardView(currentUser: user.asLocalUser)
                    case .driver:
                        DriverDashboardView()
                    }
                } else {
                    AuthView()
                }
            }
        }
    }
}

@available(iOS 26.0, *)
struct SplashView: View {
    @State private var player = AVPlayer()
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if let url = Bundle.main.url(forResource: "splash_video", withExtension: "mp4") {
                PlayerView(player: player)
                    .blendMode(.multiply) // Magically makes the video's white background transparent!
                    .onAppear {
                        player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        player.play()
                    }
                    .ignoresSafeArea()
            } else {
                // Fallback if video isn't found
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 150)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(isPresented: Bindable(supabaseManager).showResetPasswordSheet) {
            ResetPasswordView()
                .environment(supabaseManager)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 App opened with URL: \(url.absoluteString)")
        if url.scheme == "carwaan" && (url.host == "reset-password" || url.absoluteString.contains("type=recovery")) {
            Task {
                do {
                    try await supabaseManager.handleRecoveryLink(url)
                } catch {
                    print("❌ Error restoring session from recovery link: \(error.localizedDescription)")
                }
            }
        }
    }
}

@available(iOS 26.0, *)
class VideoUIView: UIView {
    var playerLayer = AVPlayerLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white // Changes letterbox bars to white
        self.layer.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

@available(iOS 26.0, *)
struct PlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> VideoUIView {
        let view = VideoUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill // Zoom to fill screen and hide bars
        return view
    }
    
    func updateUIView(_ uiView: VideoUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}


@available(iOS 26.0, *)
struct DashboardView: View {
    @Environment(SupabaseManager.self) private var supabaseManager
    @State private var vehicles: [DBVehicle] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("User Profile")) {
                    if let user = supabaseManager.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(user.name)
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Text.secondary)
                            Text("Role: \(user.role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)")
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.Brand.primary.opacity(0.1))
                                .foregroundColor(AppTheme.Brand.primary)
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Vehicles (Supabase DB)")) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading vehicles...")
                            Spacer()
                        }
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(AppTheme.Status.danger)
                    } else if vehicles.isEmpty {
                        Text("No vehicles found in database.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vehicles) { vehicle in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.vehicleNumber)
                                    .font(.headline)
                                Text("\(vehicle.manufacturer) \(vehicle.model) (\(String(vehicle.year)))")
                                    .font(.subheadline)
                                HStack {
                                    Text("Plate: \(vehicle.licensePlate)")
                                    Spacer()
                                    Text(vehicle.status.rawValue.uppercased())
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(vehicle.status == .available ? AppTheme.Status.success : AppTheme.Status.warning)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await supabaseManager.signOut()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("FMS Dashboard")
            .refreshable {
                await loadVehicles()
            }
            .task {
                await loadVehicles()
            }
        }
    }
    
    private func loadVehicles() async {
        isLoading = true
        errorMessage = nil
        do {
            vehicles = try await supabaseManager.fetchVehicles()
        } catch {
            errorMessage = "Failed to load vehicles: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

@available(iOS 26.0, *)
#Preview {
    ContentView()
        .environment(SupabaseManager.shared)
}



@available(iOS 26.0, *)
struct DriverPlaceholderView: View {
    let user: DBUser
    @Environment(SupabaseManager.self) private var supabaseManager

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Background.driverStart, AppTheme.Background.driverEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 110, height: 110)
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Welcome, \(user.name)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Driver Dashboard")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Text("Your full dashboard is coming soon.\nYou are securely logged in as a Driver.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    Button {
                        Task { try? await supabaseManager.signOut() }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(AppTheme.Brand.accent.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.bottom, 48)
                }
            }
            .navigationBarHidden(true)
        }
    }
}
