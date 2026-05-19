//
//  CreateAccountView.swift
//  FMS
//
//  Created by Sarthak Singh on 19/05/26.
//

import SwiftUI

// MARK: - Color Theme
extension Color {
    // Purple palette
    static let fmsPurple = Color(red: 103/255, green: 58/255, blue: 183/255)           // #6736B7
    static let fmsDeepPurple = Color(red: 69/255, green: 39/255, blue: 160/255)        // #4527A0
    static let fmsVividPurple = Color(red: 124/255, green: 77/255, blue: 255/255)      // #7C4DFF
    static let fmsLightPurple = Color(red: 179/255, green: 136/255, blue: 255/255)     // #B388FF
    static let fmsSoftPurple = Color(red: 237/255, green: 231/255, blue: 246/255)      // #EDE7F6
    static let fmsUltraLightPurple = Color(red: 245/255, green: 242/255, blue: 252/255) // #F5F2FC

    // Orange accent (from dashboard reference)
    static let fmsOrange = Color(red: 255/255, green: 181/255, blue: 71/255)           // #FFB547
    static let fmsDeepOrange = Color(red: 255/255, green: 150/255, blue: 30/255)       // #FF961E

    // Light theme supporting colors
    static let fmsTextPrimary = Color(red: 30/255, green: 20/255, blue: 60/255)        // #1E143C
    static let fmsTextSecondary = Color(red: 120/255, green: 110/255, blue: 150/255)   // #786E96
    static let fmsInputBg = Color(red: 248/255, green: 246/255, blue: 252/255)         // #F8F6FC
    static let fmsInputStroke = Color(red: 210/255, green: 200/255, blue: 230/255)     // #D2C8E6
    static let fmsDivider = Color(red: 230/255, green: 225/255, blue: 240/255)         // #E6E1F0
}

// MARK: - Create Account View
@available(iOS 26.0, *)
struct CreateAccountView: View {
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false
    @State private var agreedToTerms: Bool = false
    @State private var isLoading: Bool = false
    @State private var showSuccessAlert: Bool = false



    var body: some View {
        ZStack {
            // Clean white background with subtle purple tint
            backgroundView

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection

                    formCard

                    bottomSection

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
            }
        }

        .alert("Account Created!", isPresented: $showSuccessAlert) {
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Your admin account has been created successfully. You can now log in.")
        }
    }

    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Subtle purple gradient blobs for depth
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.fmsLightPurple.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: geo.size.width - 120, y: -80)
                    .blur(radius: 80)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.fmsVividPurple.opacity(0.1), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .offset(x: -80, y: geo.size.height - 300)
                    .blur(radius: 90)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.fmsOrange.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 250, height: 250)
                    .offset(x: geo.size.width - 200, y: geo.size.height - 150)
                    .blur(radius: 70)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 50)

            // Logo with Liquid Glass
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.fmsVividPurple.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 20)

                // Glass circle with purple tint
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 88, height: 88)

                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.fmsDeepPurple, .fmsVividPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .glassEffect(.regular.tint(.fmsLightPurple.opacity(0.3)), in: .circle)
                .shadow(color: .fmsPurple.opacity(0.2), radius: 16, y: 6)
            }

            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.fmsTextPrimary)

                Text("Register as a Fleet Manager to get started")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.fmsTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Form Card with Liquid Glass
    private var formCard: some View {
        VStack(spacing: 20) {
            // Full Name
            customTextField(
                icon: "person.fill",
                placeholder: "Full Name",
                text: $fullName,
                keyboardType: .default
            )

            // Email
            customTextField(
                icon: "envelope.fill",
                placeholder: "Email Address",
                text: $email,
                keyboardType: .emailAddress
            )

            // Phone
            customTextField(
                icon: "phone.fill",
                placeholder: "Phone Number",
                text: $phone,
                keyboardType: .phonePad
            )

            // Password
            customSecureField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                isVisible: $isPasswordVisible
            )

            // Confirm Password
            customSecureField(
                icon: "lock.shield.fill",
                placeholder: "Confirm Password",
                text: $confirmPassword,
                isVisible: $isConfirmPasswordVisible
            )


            // Terms checkbox
            termsCheckbox

            // Create Account Button
            createAccountButton
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white.opacity(0.45))
        )
        .glassEffect(.regular.tint(.white.opacity(0.2)), in: .rect(cornerRadius: 28))
        .shadow(color: .fmsPurple.opacity(0.08), radius: 30, y: 12)
    }

    // MARK: - Custom Text Field
    private func customTextField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.fmsPurple)
                .frame(width: 22)

            TextField("", text: text, prompt: Text(placeholder)
                .foregroundColor(.fmsTextSecondary.opacity(0.6)))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.fmsTextPrimary)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .disableAutocorrection(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.fmsInputBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fmsInputStroke.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Custom Secure Field
    private func customSecureField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.fmsPurple)
                .frame(width: 22)

            Group {
                if isVisible.wrappedValue {
                    TextField("", text: text, prompt: Text(placeholder)
                        .foregroundColor(.fmsTextSecondary.opacity(0.6)))
                } else {
                    SecureField("", text: text, prompt: Text(placeholder)
                        .foregroundColor(.fmsTextSecondary.opacity(0.6)))
                }
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.fmsTextPrimary)
            .disableAutocorrection(true)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.fmsTextSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.fmsInputBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.fmsInputStroke.opacity(0.7), lineWidth: 1)
        )
    }

    // MARK: - Password Hints
   

    private func passwordRequirement(_ text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(met ? .fmsPurple : .fmsTextSecondary.opacity(0.35))

            Text(text)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(met ? .fmsTextPrimary.opacity(0.8) : .fmsTextSecondary.opacity(0.5))
        }
    }

    // MARK: - Terms Checkbox
    private var termsCheckbox: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                agreedToTerms.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(agreedToTerms ? Color.fmsPurple : Color.fmsInputStroke, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if agreedToTerms {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.fmsDeepPurple, .fmsVividPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                (Text("I agree to the ")
                    .foregroundColor(.fmsTextSecondary) +
                Text("Terms & Privacy Policy")
                    .foregroundColor(.fmsPurple)
                    .bold())
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(1)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Create Account Button
    private var createAccountButton: some View {
        Button {
            createAccount()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: isFormValid
                                ? [.fmsDeepPurple, .fmsVividPurple]
                                : [Color.fmsDivider, Color.fmsDivider.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: isFormValid ? .fmsPurple.opacity(0.4) : .clear, radius: 14, y: 6)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.1)
                } else {
                    HStack(spacing: 10) {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .bold, design: .rounded))

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(isFormValid ? .white : .fmsTextSecondary.opacity(0.5))
                }
            }
            .frame(height: 56)
        }
        .disabled(!isFormValid || isLoading)
        .padding(.top, 8)
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        HStack(spacing: 4) {
            Text("Already have an account?")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.fmsTextSecondary)

            Button {
                // Navigate to login
            } label: {
                Text("Sign In")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.fmsPurple)
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    // MARK: - Validation
    private var isFormValid: Bool {
        !fullName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        !phone.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword &&
        agreedToTerms
    }

    // MARK: - Create Account Action
    private func createAccount() {
        guard isFormValid else { return }

        withAnimation {
            isLoading = true
        }

        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                isLoading = false
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Preview
@available(iOS 26.0, *)
#Preview {
    CreateAccountView()
}
