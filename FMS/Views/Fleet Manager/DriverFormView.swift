







import SwiftUI
import SwiftData





@available(iOS 26.0, *)
struct AddDriverFormView: View {

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

                        
                        formSection(title: "Personal Information", icon: "person.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            UserFormField(label: "Full Name", placeholder: "e.g. John Doe",
                                         text: $fullName, keyboardType: .default, focus: $focusedField, tag: .fullName)
                            FormDivider()
                            UserFormField(label: "Email", placeholder: "e.g. john@example.com",
                                         text: $email, keyboardType: .emailAddress, focus: $focusedField, tag: .email)
                            FormDivider()
                            UserFormField(label: "Phone Number", placeholder: "e.g. +1234567890",
                                         text: $phoneNumber, keyboardType: .phonePad, focus: $focusedField, tag: .phoneNumber)
                        }

                        formSection(title: "Security", icon: "lock.fill", iconColor: AppTheme.Brand.royalBlue) {
                            UserPasswordField(label: "Password", placeholder: "Enter password",
                                            text: $password, focus: $focusedField, tag: .password)
                        }

                        formSection(title: "Status", icon: "circle.fill", iconColor: AppTheme.Brand.accent) {
                            StatusToggleRow(label: "Active Status", isOn: $isActive)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Add Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveDriver()
                    }
                    .foregroundColor(AppTheme.Brand.royalBlue)
                    .disabled(isSaving)
                }
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert("Driver Added", isPresented: $saveSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(fullName) has been added as a driver.")
            }
        }
    }


    

    private var saveButton: some View {
        Button {
            saveDriver()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(isSaving ? "Saving..." : "Save Driver")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.primaryDeep],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isSaving)
    }

    

    private func saveDriver() {
        
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
                
                let dbUser = try await SupabaseManager.shared.createDriver(
                    email: emailToSend,
                    passwordString: rawPassword,
                    fullName: nameToSend,
                    phoneNumber: phoneToSend,
                    isActive: isActive
                )
                
                
                let passwordHash = Data(rawPassword.utf8).base64EncodedString()
                
                let driver = User(
                    id: dbUser.id, 
                    fullName: nameToSend,
                    email: emailToSend,
                    phoneNumber: phoneToSend,
                    passwordHash: passwordHash,
                    role: .driver,
                    isActive: isActive
                )
                
                
                do {
                    try await EmailManager.shared.sendWelcomeEmail(to: emailToSend, name: nameToSend, passwordString: rawPassword)
                } catch {
                    print("⚠️ Welcome email send failed: \(error.localizedDescription)")
                }
                
                await MainActor.run {
                    modelContext.insert(driver)
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            } catch {
                print("Failed to save driver to Supabase: \(error)")
                
                
                let fallbackId = UUID()
                let passwordHash = Data(rawPassword.utf8).base64EncodedString()
                let driver = User(
                    id: fallbackId,
                    fullName: nameToSend,
                    email: emailToSend,
                    phoneNumber: phoneToSend,
                    passwordHash: passwordHash,
                    role: .driver,
                    isActive: isActive
                )
                
                
                do {
                    try await EmailManager.shared.sendWelcomeEmail(to: emailToSend, name: nameToSend, passwordString: rawPassword)
                } catch {
                    print("⚠️ Welcome email send failed in offline fallback: \(error.localizedDescription)")
                }
                
                
                await MainActor.run {
                    modelContext.insert(driver)
                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            }
        }
    }
}





@available(iOS 26.0, *)
struct EditDriverFormView: View {

    let driver: User

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

    init(driver: User) {
        self.driver = driver
        _fullName    = State(initialValue: driver.fullName)
        _email       = State(initialValue: driver.email)
        _phoneNumber = State(initialValue: driver.phoneNumber)
        _isActive    = State(initialValue: driver.isActive)
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

                        
                        driverBadge

                        
                        formSection(title: "Personal Information", icon: "person.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            UserFormField(label: "Full Name", placeholder: "e.g. John Doe",
                                         text: $fullName, keyboardType: .default, focus: $focusedField, tag: .fullName)
                            FormDivider()
                            UserFormField(label: "Email", placeholder: "e.g. john@example.com",
                                         text: $email, keyboardType: .emailAddress, focus: $focusedField, tag: .email)
                            FormDivider()
                            UserFormField(label: "Phone Number", placeholder: "e.g. +1234567890",
                                         text: $phoneNumber, keyboardType: .phonePad, focus: $focusedField, tag: .phoneNumber)
                        }

                        formSection(title: "Status", icon: "circle.fill", iconColor: AppTheme.Brand.accent) {
                            StatusToggleRow(label: "Active Status", isOn: $isActive)
                        }

                        
                        deleteButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Edit Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(AppTheme.Brand.royalBlue)
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
                "Delete \(driver.fullName)?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Driver", role: .destructive) { deleteDriver() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the driver from your fleet. This action cannot be undone.")
            }
        }
    }

    

    private var driverBadge: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.30, green: 0.70, blue: 0.46).opacity(0.8), Color(red: 0.30, green: 0.70, blue: 0.46)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(red: 0.30, green: 0.70, blue: 0.46).opacity(0.35), radius: 10, y: 4)
                Text(initials(for: driver.fullName))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.fullName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                Text(driver.email)
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
                colors: [AppTheme.Brand.royalBlue, AppTheme.Brand.primaryDeep],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.royalBlue.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .disabled(isSaving || isDeleting)
    }

    

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.85, green: 0.15, blue: 0.15)))
                } else {
                    Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                }
                Text(isDeleting ? "Deleting..." : "Delete Driver").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.25), lineWidth: 1))
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
            id: driver.id,
            name: fullName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            role: driver.role.toDBUserRole,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phoneNumber.trimmingCharacters(in: .whitespaces),
            profileImage: driver.profileImageURL,
            isActive: isActive,
            createdAt: driver.createdAt
        )

        isSaving = true

        Task {
            do {
                try await SupabaseManager.shared.updateDriver(updatedDBUser)
                
                await MainActor.run {
                    driver.fullName    = fullName.trimmingCharacters(in: .whitespaces)
                    driver.email       = email.trimmingCharacters(in: .whitespaces).lowercased()
                    driver.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
                    driver.isActive    = isActive
                    driver.updatedAt   = .now

                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            } catch {
                print("Failed to update driver on Supabase: \(error)")
                await MainActor.run {
                    driver.fullName    = fullName.trimmingCharacters(in: .whitespaces)
                    driver.email       = email.trimmingCharacters(in: .whitespaces).lowercased()
                    driver.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
                    driver.isActive    = isActive
                    driver.updatedAt   = .now

                    try? modelContext.save()
                    isSaving = false
                    saveSuccess = true
                }
            }
        }
    }

    private func deleteDriver() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        isDeleting = true
        
        Task {
            do {
                try await SupabaseManager.shared.deleteDriver(id: driver.id)
                
                await MainActor.run {
                    modelContext.delete(driver)
                    try? modelContext.save()
                    isDeleting = false
                    dismiss()
                }
            } catch {
                print("Failed to delete driver from Supabase: \(error)")
                await MainActor.run {
                    modelContext.delete(driver)
                    try? modelContext.save()
                    isDeleting = false
                    dismiss()
                }
            }
        }
    }
}







enum UserFocusField: Hashable {
    case fullName, email, phoneNumber, password
}



struct UserFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    var focus: FocusState<UserFocusField?>.Binding
    let tag: UserFocusField

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 110, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.Brand.royalBlue)
                .keyboardType(keyboardType)
                .focused(focus, equals: tag)
                .multilineTextAlignment(.trailing)
                .autocapitalization(tag == .email ? .none : .words)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



struct UserPasswordField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var focus: FocusState<UserFocusField?>.Binding
    let tag: UserFocusField

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .frame(width: 110, alignment: .leading)

            SecureField(placeholder, text: $text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(AppTheme.Brand.royalBlue)
                .focused(focus, equals: tag)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}



struct StatusToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.black)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(AppTheme.Brand.royalBlue)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
