import SwiftUI
import Supabase


// MARK: - Theme Configuration
struct Theme {
    static let royalBlue = Color(red: 0.15, green: 0.38, blue: 0.90)
    static let darkOrange = Color(red: 0.93, green: 0.46, blue: 0.0)
    static let clearWhite = Color.white
    static let glassBorder = Color.black.opacity(0.20)
}

// MARK: - UI Helper for Existing Model
extension UserRole {
    var displayName: String {
        switch self {
        case .fleetManager: return "Fleet Manager"
        case .driver: return "Driver"
        case .maintenance: return "Maintenance Personnel"
        }
    }
    static let allRoles: [UserRole] = [.fleetManager, .driver, .maintenance]

    var toDBUserRole: DBUserRole {
        switch self {
        case .fleetManager: return .fleetManager
        case .driver: return .driver
        case .maintenance: return .maintenance
        }
    }
}

// MARK: - Focus Enum for Premium Interaction
enum FocusField: Hashable {
    case email, password
}

// MARK: - Premium Authentication View
struct AuthView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared

    // User Input States
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole: UserRole = .fleetManager

    // Focus State for Native Feel
    @FocusState private var focusedField: FocusField?

    // Animation States
    @State private var appearAnimation = false

    // Error Alert State
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.clearWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // MARK: Premium Header Section
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.royalBlue.opacity(0.8), Theme.royalBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 100)
                                .shadow(color: Theme.royalBlue.opacity(0.3), radius: 12, x: 0, y: 8)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )

                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(.white)
                                .symbolEffect(.bounce, value: appearAnimation)
                        }

                        VStack(spacing: 6) {
                            Text("Fleeto")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .tracking(0.5)

                            Text("Sign in to your dashboard")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 36)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    // MARK: Form Section
                    VStack(spacing: 24) {

                        // Role Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SELECT ROLE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.gray.opacity(0.8))
                                .tracking(1.0)

                            Menu {
                                Picker("Role", selection: $selectedRole) {
                                    ForEach(UserRole.allRoles, id: \.self) { role in
                                        Text(role.displayName).tag(role)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedRole.displayName)
                                        .foregroundColor(.black)
                                        .font(.system(.body, design: .rounded))
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.glassBorder, lineWidth: 1)
                                )
                            }
                        }

                        // Credentials
                        VStack(spacing: 16) {
                            PremiumInputField(icon: "envelope.fill", placeholder: "Email Address", text: $email, isFocused: focusedField == .email)
                                .keyboardType(.emailAddress)
                                .focused($focusedField, equals: .email)

                            PremiumSecureField(icon: "key.fill", placeholder: "Password", text: $password, isFocused: focusedField == .password)
                                .focused($focusedField, equals: .password)
                        }

                        // Submit Button
                        Button(action: handleAuthentication) {
                            HStack {
                                if supabaseManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text("Sign In")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.royalBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Theme.royalBlue.opacity(0.3), radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(supabaseManager.isLoading)
                        .padding(.top, 8)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 24, x: 0, y: 12)
                    .padding(.horizontal, 24)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    Spacer()
                    Spacer()
                }

                // MARK: Glass Error Alert Overlay
                if showErrorAlert {
                    GlassErrorAlert(
                        message: errorAlertMessage,
                        onCancel: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showErrorAlert = false
                                email = ""
                                password = ""
                            }
                        },
                        onTryAgain: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showErrorAlert = false
                                password = ""
                                focusedField = .password
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .zIndex(10)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    // MARK: - Actions
    private func handleAuthentication() {
        let impactHeavy = UIImpactFeedbackGenerator(style: .medium)
        impactHeavy.impactOccurred()
        focusedField = nil

        Task {
            do {
                try await supabaseManager.signIn(
                    email: email,
                    passwordString: password,
                    expectedRole: selectedRole.toDBUserRole
                )
            } catch {
                // Surface error in glass alert popup
                errorAlertMessage = error.localizedDescription
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showErrorAlert = true
                }
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Glass Error Alert Component
struct GlassErrorAlert: View {
    let message: String
    let onCancel: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        ZStack {
            // Invisible tap-to-dismiss layer
            Color.clear
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Glass card
            VStack(spacing: 0) {
                // Icon + title
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 28)

                    Text("Wrong Credentials")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }

                Divider()
                    .background(Color.gray.opacity(0.3))

                // Action buttons
                HStack(spacing: 0) {
                    // Cancel
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .frame(height: 52)
                        .background(Color.gray.opacity(0.3))

                    // Try Again
                    Button(action: onTryAgain) {
                        Text("Try Again")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(Theme.royalBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 40, x: 0, y: 20)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Reusable Premium Components

struct PremiumInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isFocused ? Theme.royalBlue : .gray.opacity(0.8))
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.black)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Theme.royalBlue : Theme.glassBorder, lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct PremiumSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isFocused ? Theme.royalBlue : .gray.opacity(0.8))
                .frame(width: 24)

            SecureField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.black)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? Theme.royalBlue : Theme.glassBorder, lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Custom Button Style for Premium Press Effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    AuthView()
}
