import SwiftUI
import Supabase




enum FocusField: Hashable {
    case email, password
}


struct AuthView: View {
    @Environment(SupabaseManager.self) private var supabaseManager

    
    @State private var email = ""
    @State private var password = ""

    
    @FocusState private var focusedField: FocusField?

    
    @State private var appearAnimation = false

    
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.auth.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppTheme.Brand.royalBlue.opacity(0.8),
                                            AppTheme.Brand.royalBlue
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 100)
                                .shadow(
                                    color: AppTheme.Brand.royalBlue.opacity(0.3),
                                    radius: 12, x: 0, y: 8
                                )
                                .overlay(
                                    Circle()
                                        .stroke(AppTheme.Text.onDark.opacity(0.2), lineWidth: 1)
                                )

                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(AppTheme.Text.onDark)
                                .symbolEffect(.bounce, value: appearAnimation)
                        }

                        VStack(spacing: 6) {
                            Text("Fleeto")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Text.primary)
                                .tracking(0.5)

                            Text("Sign in to your dashboard")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(AppTheme.Text.tertiary)
                        }
                    }
                    .padding(.bottom, 36)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    
                    VStack(spacing: 24) {

                        


                        
                        VStack(spacing: 16) {
                            PremiumInputField(
                                icon: "envelope.fill",
                                placeholder: "Email Address",
                                text: $email,
                                isFocused: focusedField == .email
                            )
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)

                            PremiumSecureField(
                                icon: "key.fill",
                                placeholder: "Password",
                                text: $password,
                                isFocused: focusedField == .password
                            )
                            .focused($focusedField, equals: .password)
                        }

                        
                        Button(action: handleAuthentication) {
                            HStack {
                                if supabaseManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Text.onDark))
                                        .padding(.trailing, 8)
                                }
                                Text("Sign In")
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.Text.onDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.Brand.royalBlue)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous))
                            .shadow(
                                color: AppTheme.Brand.royalBlue.opacity(0.3),
                                radius: 10, x: 0, y: 6
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(supabaseManager.isLoading)
                        .padding(.top, 8)
                    }
                    .padding(AppTheme.Spacing.lg + 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.form, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.form, style: .continuous)
                            .stroke(AppTheme.Glass.border, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.Shadow.card, radius: 24, x: 0, y: 12)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .opacity(appearAnimation ? 1 : 0)
                    .offset(y: appearAnimation ? 0 : 20)

                    Spacer()
                    Spacer()
                }

                
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

    
    private func handleAuthentication() {
        let impactHeavy = UIImpactFeedbackGenerator(style: .medium)
        impactHeavy.impactOccurred()
        focusedField = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.isValidEmail else {
            errorAlertMessage = "Please enter a valid email address."
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showErrorAlert = true
            }
            return
        }
        guard !password.isEmpty else {
            errorAlertMessage = "Please enter a password."
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showErrorAlert = true
            }
            return
        }

        Task {
            do {
                try await supabaseManager.signIn(
                    email: trimmedEmail,
                    passwordString: password
                )
            } catch {
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


struct GlassErrorAlert: View {
    let message: String
    let onCancel: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Status.danger.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(AppTheme.Status.danger)
                    }
                    .padding(.top, 28)

                    Text("Wrong Credentials")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppTheme.Text.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }

                Divider()

                HStack(spacing: 0) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundColor(AppTheme.Text.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider().frame(height: 52)

                    Button(action: onTryAgain) {
                        Text("Try Again")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous)
                    .stroke(AppTheme.Text.onDark.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: AppTheme.Shadow.modal, radius: 40, x: 0, y: 20)
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }
}



struct PremiumInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isFocused ? AppTheme.Brand.royalBlue : AppTheme.Text.tertiary.opacity(0.8))
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .stroke(
                    isFocused ? AppTheme.Brand.royalBlue : AppTheme.Glass.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
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
                .foregroundColor(isFocused ? AppTheme.Brand.royalBlue : AppTheme.Text.tertiary.opacity(0.8))
                .frame(width: 24)

            SecureField(placeholder, text: $text)
                .font(.system(.body, design: .rounded))
                .foregroundColor(AppTheme.Text.primary)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                .stroke(
                    isFocused ? AppTheme.Brand.royalBlue : AppTheme.Glass.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}


struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}


#Preview {
    AuthView()
        .environment(SupabaseManager.shared)
}
