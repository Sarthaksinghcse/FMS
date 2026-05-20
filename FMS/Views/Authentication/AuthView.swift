import SwiftUI

// MARK: - Theme Configuration
struct Theme {
    static let royalBlue = Color(red: 0.15, green: 0.38, blue: 0.90)
    static let darkOrange = Color(red: 0.93, green: 0.46, blue: 0.0)
    static let clearWhite = Color.white
    // Darkened from 0.06 to 0.20 to make the rounded rectangles around the fields darker
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
}

// MARK: - Focus Enum for Premium Interaction
enum FocusField: Hashable {
    case fullName, email, password, confirmPassword
}

// MARK: - Premium Authentication View
struct AuthView: View {
    @State private var isLoginMode = true
    
    // User Input States
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var fullName = ""
    @State private var selectedRole: UserRole = .fleetManager
    
    // Focus State for Native Feel
    @FocusState private var focusedField: FocusField?
    
    // Animation States
    @State private var appearAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.clearWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // MARK: Premium Header Section with Custom Circular Logo
                    VStack(spacing: 20) {
                        
                        // New Circular Logo Boundary
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
                            
                            Text(isLoginMode ? "Sign in to your dashboard" : "Register administrative account")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, isLoginMode ? 36 : 16)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    
                    // MARK: Form Section (Refined Glass Effect)
                    VStack(spacing: 24) {
                        
                        // Role Selection
                        if isLoginMode {
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
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ACCOUNT TYPE")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .tracking(1.0)
                                
                                HStack {
                                    Text(UserRole.fleetManager.displayName)
                                        .foregroundColor(.black)
                                        .font(.system(.body, design: .rounded))
                                    Spacer()
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(Theme.royalBlue)
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
                            
                            PremiumInputField(icon: "person.fill", placeholder: "Full Name", text: $fullName, isFocused: focusedField == .fullName)
                                .focused($focusedField, equals: .fullName)
                        }
                        
                        // Shared Credentials
                        VStack(spacing: 16) {
                            PremiumInputField(icon: "envelope.fill", placeholder: "Email Address", text: $email, isFocused: focusedField == .email)
                                .keyboardType(.emailAddress)
                                .focused($focusedField, equals: .email)
                            
                            PremiumSecureField(icon: "key.fill", placeholder: "Password", text: $password, isFocused: focusedField == .password)
                                .focused($focusedField, equals: .password)
                            
                            if !isLoginMode {
                                PremiumSecureField(icon: "key.fill", placeholder: "Confirm Password", text: $confirmPassword, isFocused: focusedField == .confirmPassword)
                                    .focused($focusedField, equals: .confirmPassword)
                            }
                        }
                        
                        // Submit Button
                        Button(action: handleAuthentication) {
                            Text(isLoginMode ? "Sign In" : "Create Account")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Theme.royalBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Theme.royalBlue.opacity(0.3), radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(ScaleButtonStyle())
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
                    
                    // MARK: Toggle Mode Footer
                    Button(action: {
                        let impactLight = UIImpactFeedbackGenerator(style: .light)
                        impactLight.impactOccurred()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0)) {
                            isLoginMode.toggle()
                            resetFields()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isLoginMode ? "New to the platform?" : "Already an user?")
                                .foregroundColor(.gray)
                            Text(isLoginMode ? "Create an admin account" : "Sign in here")
                                .fontWeight(.bold)
                                .foregroundColor(Theme.darkOrange)
                        }
                        .font(.system(.footnote, design: .rounded))
                    }
                    .padding(.bottom, 24)
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
    }
    
    private func resetFields() {
        email = ""
        password = ""
        confirmPassword = ""
        fullName = ""
        selectedRole = .fleetManager
        focusedField = nil
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
