
import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct AddMaintenanceFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    
    @State private var fullName     = ""
    @State private var email        = ""
    @State private var phoneNumber  = ""
    @State private var password     = ""
    @State private var isActive     = true

    
    @State private var showValidationAlert  = false
    @State private var validationMessage    = ""
    @State private var saveSuccess          = false
    @State private var isSaving             = false

    
    @FocusState private var focusedField: UserFocusField?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        
                        formSection(title: "Personal Information", icon: "person.fill", iconColor: AppTheme.Brand.accent) {
                            UserFormField(label: "Full Name", placeholder: "e.g. Jane Smith",
                                         text: $fullName, keyboardType: .default, focus: $focusedField, tag: .fullName)
                            FormDivider()
                            UserFormField(label: "Email", placeholder: "e.g. jane@example.com",
                                         text: $email, keyboardType: .emailAddress, focus: $focusedField, tag: .email)
                            FormDivider()
                            UserFormField(label: "Phone Number", placeholder: "e.g. +1234567890",
                                         text: $phoneNumber, keyboardType: .phonePad, focus: $focusedField, tag: .phoneNumber)
                        }

                        formSection(title: "Security", icon: "lock.fill", iconColor: AppTheme.Brand.royalBlue) {
                            UserPasswordField(label: "Password", placeholder: "Enter password",
                                            text: $password, focus: $focusedField, tag: .password)
                        }

                        formSection(title: "Status", icon: "circle.fill", iconColor: Theme.royalBlue) {
                            StatusToggleRow(label: "Active Status", isOn: $isActive)
                        }

                        
                        saveButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Add Maintenance Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.darkOrange)
                        .disabled(isSaving)
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert("Staff Added", isPresented: $saveSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(fullName) has been added as maintenance staff.")
            }
        }
    }


    

    private var saveButton: some View {
        Button {
            saveStaff()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(isSaving ? "Saving..." : "Save Staff Member")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [AppTheme.Brand.accent, AppTheme.Brand.accent.opacity(0.7)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isSaving)
    }

    

    private func saveStaff() {
        
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Full name is required."; showValidationAlert = true; return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            validationMessage = "Email is required."; showValidationAlert = true; return
        }
        guard trimmedEmail.isValidEmail else {
            validationMessage = "Please enter a valid email address."; showValidationAlert = true; return
        }
        
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !trimmedPhone.isEmpty else {
            validationMessage = "Phone number is required."; showValidationAlert = true; return
        }
        guard trimmedPhone.isValidPhoneNumber else {
            validationMessage = "Please enter a valid 10-digit phone number."; showValidationAlert = true; return
        }
        guard !password.isEmpty else {
            validationMessage = "Password is required."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        isSaving = true

        Task {
            let emailToSend = email.trimmingCharacters(in: .whitespaces).lowercased()
            let nameToSend = fullName.trimmingCharacters(in: .whitespaces)
            let phoneToSend = phoneNumber.trimmingCharacters(in: .whitespaces)
            let rawPassword = password
            
            do {
                let dbUser = try await SupabaseManager.shared.createMaintenanceStaff(
                    email: emailToSend,
                    passwordString: rawPassword,
                    fullName: nameToSend,
                    phoneNumber: phoneToSend,
                    isActive: isActive
                )
                
                let passwordHash = Data(rawPassword.utf8).base64EncodedString()
                let staff = User(
                    id: dbUser.id,
                    fullName: nameToSend,
                    email: emailToSend,
                    phoneNumber: phoneToSend,
                    passwordHash: passwordHash,
                    role: .maintenance,
                    isActive: isActive
                )
                
                do {
                    try await EmailManager.shared.sendWelcomeEmail(to: emailToSend, name: nameToSend, passwordString: rawPassword)
                } catch {
                    print("⚠️ Welcome email send failed: \(error.localizedDescription)")
                }
                
                await MainActor.run {
                    modelContext.insert(staff)
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            } catch {
                print("Failed to save maintenance staff to Supabase: \(error)")
                
                let fallbackId = UUID()
                let passwordHash = Data(rawPassword.utf8).base64EncodedString()
                let staff = User(
                    id: fallbackId,
                    fullName: nameToSend,
                    email: emailToSend,
                    phoneNumber: phoneToSend,
                    passwordHash: passwordHash,
                    role: .maintenance,
                    isActive: isActive
                )
                
                do {
                    try await EmailManager.shared.sendWelcomeEmail(to: emailToSend, name: nameToSend, passwordString: rawPassword)
                } catch {
                    print("⚠️ Welcome email send failed in offline fallback: \(error.localizedDescription)")
                }
                
                await MainActor.run {
                    modelContext.insert(staff)
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            }
        }
    }
}





@available(iOS 26.0, *)
struct EditMaintenanceFormView: View {

    let staff: User

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    
    @State private var fullName: String
    @State private var email: String
    @State private var phoneNumber: String
    @State private var isActive: Bool

    @State private var showValidationAlert = false
    @State private var validationMessage   = ""
    @State private var showDeleteConfirm   = false
    @State private var saveSuccess         = false
    @State private var isSaving            = false
    @State private var isDeleting          = false
    @FocusState private var focusedField: UserFocusField?

    init(staff: User) {
        self.staff = staff
        _fullName    = State(initialValue: staff.fullName)
        _email       = State(initialValue: staff.email)
        _phoneNumber = State(initialValue: staff.phoneNumber)
        _isActive    = State(initialValue: staff.isActive)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        
                        staffBadge

                        
                        formSection(title: "Personal Information", icon: "person.fill", iconColor: AppTheme.Brand.accent) {
                            UserFormField(label: "Full Name", placeholder: "e.g. Jane Smith",
                                         text: $fullName, keyboardType: .default, focus: $focusedField, tag: .fullName)
                            FormDivider()
                            UserFormField(label: "Email", placeholder: "e.g. jane@example.com",
                                         text: $email, keyboardType: .emailAddress, focus: $focusedField, tag: .email)
                            FormDivider()
                            UserFormField(label: "Phone Number", placeholder: "e.g. +1234567890",
                                         text: $phoneNumber, keyboardType: .phonePad, focus: $focusedField, tag: .phoneNumber)
                        }

                        formSection(title: "Status", icon: "circle.fill", iconColor: Theme.royalBlue) {
                            StatusToggleRow(label: "Active Status", isOn: $isActive)
                        }

                        
                        saveButton

                        
                        deleteButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Edit Staff Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.darkOrange)
                        .disabled(isSaving || isDeleting)
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: { Text(validationMessage) }
            .alert("Changes Saved", isPresented: $saveSuccess) {
                Button("Done") { dismiss() }
            } message: { Text("\(fullName) has been updated.") }
            .confirmationDialog(
                "Delete \(staff.fullName)?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Staff Member", role: .destructive) { deleteStaff() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the staff member from your team. This action cannot be undone.")
            }
        }
    }

    

    private var staffBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [AppTheme.Brand.accent.opacity(0.8), AppTheme.Brand.accent],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .shadow(color: AppTheme.Brand.accent.opacity(0.35), radius: 10, y: 4)
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(staff.fullName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text(staff.email)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.Glass.border, lineWidth: 1))
        .padding(.top, 8)
    }

    

    private var saveButton: some View {
        Button { saveChanges() } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
                }
                Text(isSaving ? "Saving..." : "Save Changes").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient(
                colors: [AppTheme.Brand.accent, AppTheme.Brand.accent.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isSaving || isDeleting)
    }

    

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.darkOrange))
                } else {
                    Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                }
                Text(isDeleting ? "Deleting..." : "Delete Staff Member").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Theme.darkOrange)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Theme.darkOrange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.darkOrange.opacity(0.25), lineWidth: 1))
        }
        .disabled(isSaving || isDeleting)
    }

    

    private func saveChanges() {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Full name is required."; showValidationAlert = true; return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            validationMessage = "Email is required."; showValidationAlert = true; return
        }
        guard trimmedEmail.isValidEmail else {
            validationMessage = "Please enter a valid email address."; showValidationAlert = true; return
        }
        
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        guard !trimmedPhone.isEmpty else {
            validationMessage = "Phone number is required."; showValidationAlert = true; return
        }
        guard trimmedPhone.isValidPhoneNumber else {
            validationMessage = "Please enter a valid 10-digit phone number."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let updatedDBUser = DBUser(
            id: staff.id,
            name: fullName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            role: staff.role.toDBUserRole,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phoneNumber.trimmingCharacters(in: .whitespaces),
            profileImage: staff.profileImageURL,
            isActive: isActive,
            createdAt: staff.createdAt
        )

        isSaving = true

        Task {
            do {
                try await SupabaseManager.shared.updateDriver(updatedDBUser)
                
                await MainActor.run {
                    staff.fullName    = fullName.trimmingCharacters(in: .whitespaces)
                    staff.email       = email.trimmingCharacters(in: .whitespaces).lowercased()
                    staff.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
                    staff.isActive    = isActive
                    staff.updatedAt   = .now

                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            } catch {
                print("Failed to update staff on Supabase: \(error)")
                await MainActor.run {
                    staff.fullName    = fullName.trimmingCharacters(in: .whitespaces)
                    staff.email       = email.trimmingCharacters(in: .whitespaces).lowercased()
                    staff.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
                    staff.isActive    = isActive
                    staff.updatedAt   = .now

                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            }
        }
    }

    private func deleteStaff() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        isDeleting = true
        
        Task {
            do {
                try await SupabaseManager.shared.deleteDriver(id: staff.id)
                
                await MainActor.run {
                    modelContext.delete(staff)
                    try? modelContext.save()
                    isDeleting = false
                    dismiss()
                }
            } catch {
                print("Failed to delete staff from Supabase: \(error)")
                await MainActor.run {
                    modelContext.delete(staff)
                    try? modelContext.save()
                    isDeleting = false
                    dismiss()
                }
            }
        }
    }
}
