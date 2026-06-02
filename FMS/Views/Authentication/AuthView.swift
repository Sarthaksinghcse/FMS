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

    @State private var showForgotPasswordAlert = false
    @State private var forgotPasswordEmail = ""
    @State private var showForgotPasswordSuccess = false
    @State private var isSendingResetLink = false

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

                            HStack {
                                Spacer()
                                Button {
                                    handleForgotPassword()
                                } label: {
                                    Text("Forgot Password?")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.Brand.royalBlue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.top, -4)
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

                if showForgotPasswordAlert {
                    GlassForgotPasswordAlert(
                        email: $forgotPasswordEmail,
                        onCancel: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showForgotPasswordAlert = false
                            }
                        },
                        onSend: {
                            sendForgotPasswordEmail()
                        },
                        isLoading: isSendingResetLink
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .zIndex(10)
                }

                if showForgotPasswordSuccess {
                    GlassSuccessAlert(
                        title: "Email Sent",
                        message: "We've sent a password reset link to \(forgotPasswordEmail). Please check your inbox.",
                        onDismiss: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                showForgotPasswordSuccess = false
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

    
    private func handleForgotPassword() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        forgotPasswordEmail = email
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showForgotPasswordAlert = true
        }
    }
    
    private func sendForgotPasswordEmail() {
        let trimmedEmail = forgotPasswordEmail.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.isValidEmail else {
            errorAlertMessage = "Please enter a valid email address."
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showForgotPasswordAlert = false
                showErrorAlert = true
            }
            return
        }
        
        isSendingResetLink = true
        Task {
            do {
                try await supabaseManager.client.auth
                    .resetPasswordForEmail(trimmedEmail)
                await MainActor.run {
                    isSendingResetLink = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showForgotPasswordAlert = false
                        showForgotPasswordSuccess = true
                    }
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSendingResetLink = false
                    errorAlertMessage = error.localizedDescription
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showForgotPasswordAlert = false
                        showErrorAlert = true
                    }
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.error)
                }
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
            Color.black.opacity(0.2)
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
                        .foregroundColor(Color.black)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Color.black)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }

                Divider()

                HStack(spacing: 0) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(Color.black)
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
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
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
    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isFocused ? AppTheme.Brand.royalBlue : AppTheme.Text.tertiary.opacity(0.8))
                .frame(width: 24)

            if isPasswordVisible {
                TextField(placeholder, text: $text)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                SecureField(placeholder, text: $text)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                    .textInputAutocapitalization(.never)
            }
            
            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Text.tertiary.opacity(0.8))
            }
            .buttonStyle(PlainButtonStyle())
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


struct GlassForgotPasswordAlert: View {
    @Binding var email: String
    let onCancel: () -> Void
    let onSend: () -> Void
    let isLoading: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Brand.royalBlue.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(AppTheme.Brand.royalBlue)
                    }
                    .padding(.top, 24)

                    Text("Reset Password")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black)

                    Text("Enter your email address below. We'll send you a secure link to reset your password.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.md)

                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color.black.opacity(0.6))
                        TextField("Email Address", text: $email)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(Color.black)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.03))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.md)
                }

                Divider()

                HStack(spacing: 0) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)

                    Divider().frame(height: 52)

                    Button(action: onSend) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("Send Link")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundColor(AppTheme.Brand.royalBlue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isLoading)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: AppTheme.Shadow.modal, radius: 40, x: 0, y: 20)
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }
}


struct GlassSuccessAlert: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Status.success.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Status.success)
                    }
                    .padding(.top, 28)

                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(Color.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.lg)
                }

                Divider()

                Button(action: onDismiss) {
                    Text("OK")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundColor(AppTheme.Brand.royalBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.modal, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: AppTheme.Shadow.modal, radius: 40, x: 0, y: 20)
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
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
