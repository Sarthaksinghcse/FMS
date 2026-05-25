








import SwiftUI
import SwiftData



@available(iOS 26.0, *)
struct MaintenanceProfileView: View {

    @StateObject private var supabase = SupabaseManager.shared

    @State private var showEditProfile = false
    @State private var showWorkHistory = false
    @State private var showCertifications = false
    @State private var showNotificationSettings = false
    @State private var showSecuritySettings = false
    @State private var showHelpSupport = false
    @State private var showSignOutConfirm = false

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        guard let name = user?.name, !name.isEmpty else { return "MP" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    
    private let specializations = ["Engine Repair", "Brake Systems", "Electrical", "Oil & Fluids"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileHeaderCard
                        specializationSection
                        accountSection
                        signOutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) {
                MaintenanceEditProfileView()
            }
            .sheet(isPresented: $showWorkHistory) {
                MaintenanceWorkHistoryView()
            }
            .sheet(isPresented: $showCertifications) {
                MaintenanceCertificationsView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                MaintenanceNotificationSettingsView()
            }
            .sheet(isPresented: $showSecuritySettings) {
                MaintenanceSecuritySettingsView()
            }
            .sheet(isPresented: $showHelpSupport) {
                MaintenanceHelpSupportView()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    Task { try? await supabase.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your Maintenance account?")
            }
        }
    }

    

    private var profileHeaderCard: some View {
        VStack(spacing: 20) {
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.Brand.amber, Color(red: 0.95, green: 0.50, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: AppTheme.Brand.amber.opacity(0.35), radius: 16, y: 6)

                Text(initials)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text(user?.name ?? "Maintenance Personnel")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)

                Text(user?.email ?? "maintenance@fms.com")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)

                if let phone = user?.phoneNumber, !phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                        Text(phone)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Text.tertiary)
                    .padding(.top, 2)
                }

                
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Maintenance Personnel")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppTheme.Brand.amber)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(AppTheme.Brand.amber.opacity(0.10))
                .clipShape(Capsule())
                .padding(.top, 4)
            }

            
            Button {
                showEditProfile = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 13, weight: .medium))
                    Text("Edit Profile")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(AppTheme.Brand.amber)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(AppTheme.Brand.amber.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
    }

    

    private var specializationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Specializations")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                
                VStack(alignment: .leading, spacing: 12) {
                    FlowLayout(spacing: 8) {
                        ForEach(specializations, id: \.self) { spec in
                            HStack(spacing: 5) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 10))
                                Text(spec)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(AppTheme.Brand.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppTheme.Brand.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(16)

                Divider().padding(.leading, 16)

                
                Button {
                    showCertifications = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rosette")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Brand.amber)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.IconBg.amber)
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Certifications & Training")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Text.primary)
                            Text("View certificates and training records")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Text.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.Text.tertiary.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        }
    }

    

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Text.primary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ProfileSettingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: AppTheme.Brand.primary,
                    iconBg: AppTheme.IconBg.blue,
                    title: "Work History",
                    subtitle: "View completed work orders & history"
                ) {
                    showWorkHistory = true
                }

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: AppTheme.Status.danger,
                    iconBg: AppTheme.IconBg.red,
                    title: "Notifications",
                    subtitle: "Work order & inventory alerts"
                ) {
                    showNotificationSettings = true
                }

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "lock.shield.fill",
                    iconColor: AppTheme.Brand.primaryDeep,
                    iconBg: AppTheme.IconBg.indigo,
                    title: "Security",
                    subtitle: "Password & authentication"
                ) {
                    showSecuritySettings = true
                }

                Divider().padding(.leading, 68)

                ProfileSettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: AppTheme.Brand.teal,
                    iconBg: AppTheme.IconBg.teal,
                    title: "Help & Support",
                    subtitle: "FAQs, contact support"
                ) {
                    showHelpSupport = true
                }
            }
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        }
    }

    

    private var signOutSection: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text("Sign Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(AppTheme.Status.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Status.danger.opacity(0.08))
            .cornerRadius(AppTheme.Radius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}



private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentY += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}



@available(iOS 26.0, *)
#Preview {
    MaintenanceProfileView()
}
