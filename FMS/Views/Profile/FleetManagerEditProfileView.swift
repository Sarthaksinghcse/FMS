







import SwiftUI
import PhotosUI



@available(iOS 26.0, *)
struct FleetManagerEditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseManager.shared

    @State private var fullName: String = ""
    @State private var phoneNumber: String = ""
    @State private var isSaving = false
    @State private var showSaved = false
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

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

                                if let data = selectedImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else if let imageURLString = user?.profileImage, let imageURL = URL(string: imageURLString) {
                                    CachedAsyncImage(url: imageURL) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Text(initials.isEmpty ? "FM" : initials)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(
                                                LinearGradient(
                                                    colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Text(initials.isEmpty ? "FM" : initials)
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }

                            PhotosPicker(selection: $selectedItem, matching: .images) {
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
                            let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
                            guard trimmedPhone.isValidPhoneNumber else {
                                errorAlertMessage = "Please enter a valid 10-digit phone number."
                                showErrorAlert = true
                                return
                            }
                            
                            isSaving = true
                            
                            Task {
                                guard var updatedUser = user else {
                                    await MainActor.run { isSaving = false }
                                    return
                                }
                                
                                updatedUser.name = fullName
                                updatedUser.phoneNumber = phoneNumber.isEmpty ? nil : phoneNumber
                                
                                do {
                                    if let imgData = selectedImageData {
                                        let urlString = try await supabase.uploadAvatar(userId: updatedUser.id, imageData: imgData)
                                        let timestamp = Int(Date().timeIntervalSince1970)
                                        updatedUser.profileImage = "\(urlString)?t=\(timestamp)"
                                    }
                                    
                                    try await supabase.updateDriver(updatedUser)
                                    
                                    await MainActor.run {
                                        isSaving = false
                                        showSaved = true
                                    }
                                } catch {
                                    await MainActor.run {
                                        isSaving = false
                                        errorAlertMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                                }
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
            .onChange(of: selectedItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.selectedImageData = data
                        }
                    }
                }
            }
            .alert("Profile Updated", isPresented: $showSaved) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your profile has been saved successfully.")
            }
            .alert("Validation Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorAlertMessage)
            }
        }
    }
}




@available(iOS 26.0, *)
#Preview {
    FleetManagerEditProfileView()
}
