







import SwiftUI



@available(iOS 26.0, *)
struct FleetManagerEditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared

    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var isSaving = false
    @State private var showSaved = false

    private var user: DBUser? { supabase.currentUser }

    private var initials: String {
        let parts = fullName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: AppTheme.Brand.primary.opacity(0.30), radius: 12, y: 4)

                                Text(initials.isEmpty ? "FM" : initials)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            Button { } label: {
                                Text("Change Photo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Brand.primary)
                            }
                        }
                        .padding(.top, 8)

                        
                        VStack(spacing: 0) {
                            ProfileFormField(
                                icon: "person.fill",
                                label: "Full Name",
                                text: $fullName,
                                placeholder: "Enter your name"
                            )

                            Divider().padding(.leading, 56)

                            ProfileFormField(
                                icon: "phone.fill",
                                label: "Phone Number",
                                text: $phoneNumber,
                                placeholder: "+91 XXXXX XXXXX",
                                keyboardType: .phonePad
                            )

                            Divider().padding(.leading, 56)

                            
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Text.tertiary)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Email")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.Text.tertiary)
                                    Text(user?.email ?? "manager@fms.com")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }

                                Spacer()

                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Text.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 56)

                            
                            HStack(spacing: 12) {
                                Image(systemName: "shield.checkered")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Text.tertiary)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Role")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.Text.tertiary)
                                    Text("Fleet Manager")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppTheme.Text.secondary)
                                }

                                Spacer()

                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Text.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, x: 0, y: 4)

                        
                        Button {
                            isSaving = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isSaving = false
                                showSaved = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                }
                                Text(isSaving ? "Saving..." : "Save Changes")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: AppTheme.Shadow.primaryGlow(), radius: 12, y: 4)
                        }
                        .disabled(isSaving)
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .onAppear {
                fullName = user?.name ?? ""
                phoneNumber = user?.phoneNumber ?? ""
            }
            .alert("Profile Updated", isPresented: $showSaved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been saved successfully.")
            }
        }
    }
}



struct ProfileFormField: View {
    let icon: String
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Brand.primary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Text.tertiary)
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Text.primary)
                    .keyboardType(keyboardType)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



@available(iOS 26.0, *)
#Preview {
    FleetManagerEditProfileView()
}
