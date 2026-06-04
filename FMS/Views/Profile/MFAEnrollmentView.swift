import SwiftUI
import CoreImage.CIFilterBuiltins

struct MFAEnrollmentView: View {
    @Environment(SupabaseManager.self) private var supabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var factorId = ""
    @State private var secretKey = ""
    @State private var qrCodeUri = ""
    
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var isEnrolling = false
    @State private var setupError: String? = nil
    @State private var isSuccess = false
    @State private var copiedToClipboard = false
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "shield.checkered",
                            iconColor: AppTheme.Brand.primary,
                            title: "Setup 2-Step Verification",
                            subtitle: "Add an extra layer of security to your account"
                        )
                        
                        if isEnrolling {
                            ProgressView("Generating secure key...")
                                .padding(.vertical, 40)
                        } else if isSuccess {
                            successStateView
                        } else if !secretKey.isEmpty {
                            enrollmentFormView
                        } else {
                            // Initial fallback if something failed to load
                            VStack(spacing: 16) {
                                Text("Unable to initialize MFA Setup.")
                                    .foregroundColor(AppTheme.Status.danger)
                                Button("Try Again") {
                                    startMFAEnrollment()
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("2-Step Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelEnrollment()
                    }
                }
            }
            .task {
                startMFAEnrollment()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var enrollmentFormView: some View {
        VStack(spacing: 24) {
            // Step 1: Install App
            VStack(alignment: .leading, spacing: 12) {
                Text("1. INSTALL AUTHENTICATOR APP")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .tracking(0.6)
                
                Text("Download Google Authenticator or Microsoft Authenticator from the App Store on your device.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Text.primary)
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
            
            // Step 2: Scan QR Code
            VStack(spacing: 16) {
                Text("2. SCAN QR CODE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .tracking(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let qrImage = generateQRCode(from: qrCodeUri) {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
                
                Text("Scan this QR code with your authenticator app.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Text.secondary)
                
                Divider().padding(.vertical, 8)
                
                // Manual Secret Key Fallback
                VStack(spacing: 8) {
                    Text("Can't scan the QR code? Copy the key manually:")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Text.secondary)
                    
                    HStack(spacing: 12) {
                        Text(secretKey)
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(AppTheme.Text.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.04))
                            .cornerRadius(8)
                        
                        Button {
                            UIPasteboard.general.string = secretKey
                            copiedToClipboard = true
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedToClipboard = false
                            }
                        } label: {
                            Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                .foregroundColor(copiedToClipboard ? AppTheme.Status.success : AppTheme.Brand.primary)
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .padding(16)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
            
            // Step 3: Enter Code
            VStack(spacing: 16) {
                Text("3. VERIFY CODE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.Text.tertiary)
                    .tracking(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Enter the 6-digit code generated by your app to verify and enable 2-step verification.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundColor(AppTheme.Text.tertiary)
                    
                    TextField("6-Digit Code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .font(.system(.body, design: .rounded))
                        .focused($isInputFocused)
                        .onChange(of: verificationCode) { _, newValue in
                            if newValue.count > 6 {
                                verificationCode = String(newValue.prefix(6))
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.03))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                
                if let errorMsg = setupError {
                    Text(errorMsg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Status.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Button(action: verifyAndEnableMFA) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.trailing, 8)
                        }
                        Text("Verify & Enable")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(verificationCode.count < 6 || isLoading ? AppTheme.Brand.primary.opacity(0.5) : AppTheme.Brand.primary)
                    .cornerRadius(AppTheme.Radius.medium)
                }
                .disabled(verificationCode.count < 6 || isLoading)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(AppTheme.Background.card)
            .cornerRadius(AppTheme.Radius.card)
            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
        }
    }
    
    private var successStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.Status.success.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 38))
                    .foregroundColor(AppTheme.Status.success)
            }
            
            VStack(spacing: 8) {
                Text("Verification Active")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
                
                Text("Two-step verification has been enabled. You will be prompted to enter a security code on your next login.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Text.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Close Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.Brand.primary)
                    .cornerRadius(AppTheme.Radius.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 12)
        }
        .padding(24)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)
        .padding(.vertical, 20)
    }
    
    // MARK: - CoreImage QR Code Generator
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    // MARK: - Logic / Methods
    
    private func startMFAEnrollment() {
        isEnrolling = true
        setupError = nil
        
        Task {
            do {
                let result = try await supabaseManager.enrollMFA()
                await MainActor.run {
                    self.factorId = result.factorId
                    self.secretKey = result.secret
                    self.qrCodeUri = result.qrCodeUri
                    self.isEnrolling = false
                }
            } catch {
                await MainActor.run {
                    self.setupError = "Failed to start enrollment: \(error.localizedDescription)"
                    self.isEnrolling = false
                }
            }
        }
    }
    
    private func verifyAndEnableMFA() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        isLoading = true
        setupError = nil
        isInputFocused = false
        
        Task {
            do {
                try await supabaseManager.verifyMFAEnrollment(factorId: factorId, code: verificationCode)
                await MainActor.run {
                    self.isLoading = false
                    self.isSuccess = true
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.setupError = "Invalid verification code. Please try again."
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func cancelEnrollment() {
        // If they created an unverified factor, unenroll it so it doesn't count towards the 10-factor limit.
        if !factorId.isEmpty {
            Task {
                try? await supabaseManager.unenrollMFA(factorId: factorId)
            }
        }
        dismiss()
    }
}

#Preview {
    MFAEnrollmentView()
        .environment(SupabaseManager.shared)
}
