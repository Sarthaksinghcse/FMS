import SwiftUI

@available(iOS 26.0, *)
struct ResetPasswordView: View {
    @Environment(SupabaseManager.self) private var supabaseManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        ProfileInnerScreenHeader(
                            icon: "lock.rotation",
                            iconColor: AppTheme.Brand.primary,
                            title: "Reset Password",
                            subtitle: "Set a secure new password for your account"
                        )
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ENTER NEW CREDENTIALS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Text.tertiary)
                                .tracking(0.6)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            
                            VStack(spacing: 0) {
                                ProfileSecureFormField(
                                    icon: "key.fill",
                                    label: "New Password",
                                    text: $newPassword,
                                    placeholder: "At least 6 characters"
                                )
                                Divider().padding(.leading, 48)
                                ProfileSecureFormField(
                                    icon: "key.fill",
                                    label: "Confirm New Password",
                                    text: $confirmPassword,
                                    placeholder: "Confirm your password"
                                )
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
                        }
                        
                        Button {
                            updatePassword()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.white)
                                }
                                Text(isSaving ? "Saving..." : "Save Password")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.Brand.primary)
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: AppTheme.Brand.primary.opacity(0.3), radius: 10, y: 4)
                        }
                        .disabled(isSaving || newPassword.isEmpty || confirmPassword.isEmpty)
                        .opacity((newPassword.isEmpty || confirmPassword.isEmpty) ? 0.5 : 1.0)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been reset successfully. You are now logged in.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorAlertMessage)
            }
        }
    }
    
    private func updatePassword() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        let trimmedPassword = newPassword.trimmingCharacters(in: .whitespaces)
        guard trimmedPassword.count >= 6 else {
            errorAlertMessage = "Password must be at least 6 characters long."
            showErrorAlert = true
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.error)
            return
        }
        
        guard trimmedPassword == confirmPassword else {
            errorAlertMessage = "Passwords do not match."
            showErrorAlert = true
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.error)
            return
        }
        
        isSaving = true
        Task {
            do {
                try await supabaseManager.updatePassword(newPassword: trimmedPassword)
                await MainActor.run {
                    isSaving = false
                    showSuccessAlert = true
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorAlertMessage = error.localizedDescription
                    showErrorAlert = true
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.error)
                }
            }
        }
    }
}
