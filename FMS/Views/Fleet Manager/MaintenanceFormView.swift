//
//  MaintenanceFormView.swift
//  FMS
//
//  Full Add / Edit / Delete maintenance staff forms for the Fleet Manager's
//  Maintenance Management screen. Follows the VehicleFormView.swift pattern.
//

import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Add Maintenance Staff Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct AddMaintenanceFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Form State ────────────────────────────────────────────────────────────
    @State private var fullName     = ""
    @State private var email        = ""
    @State private var phoneNumber  = ""
    @State private var password     = ""
    @State private var isActive     = true

    // ── Validation ────────────────────────────────────────────────────────────
    @State private var showValidationAlert  = false
    @State private var validationMessage    = ""
    @State private var saveSuccess          = false

    // ── Focus ─────────────────────────────────────────────────────────────────
    @FocusState private var focusedField: UserFocusField?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Form sections ──────────────────────────────────
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

                        formSection(title: "Status", icon: "circle.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            StatusToggleRow(label: "Active Status", isOn: $isActive)
                        }

                        // ── Save Button ────────────────────────────────────
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
                        .foregroundColor(.red)
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


    // MARK: Save Button

    private var saveButton: some View {
        Button {
            saveStaff()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Save Staff Member")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [AppTheme.Brand.accent, Color(red: 0.85, green: 0.35, blue: 0.25)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Save Action

    private func saveStaff() {
        // Validation
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Full name is required."; showValidationAlert = true; return
        }
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Email is required."; showValidationAlert = true; return
        }
        guard email.contains("@") else {
            validationMessage = "Please enter a valid email address."; showValidationAlert = true; return
        }
        guard !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Phone number is required."; showValidationAlert = true; return
        }
        guard !password.isEmpty else {
            validationMessage = "Password is required."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Simple password hashing using base64 for demo purposes
        let passwordHash = Data(password.utf8).base64EncodedString()

        let staff = User(
            fullName:     fullName.trimmingCharacters(in: .whitespaces),
            email:        email.trimmingCharacters(in: .whitespaces).lowercased(),
            phoneNumber:  phoneNumber.trimmingCharacters(in: .whitespaces),
            passwordHash: passwordHash,
            role:         .maintenance,
            isActive:     isActive
        )

        modelContext.insert(staff)
        try? modelContext.save()
        saveSuccess = true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Edit Maintenance Staff Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct EditMaintenanceFormView: View {

    let staff: User

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    // ── Form State ────────────────────────────────────────────────────────────
    @State private var fullName: String
    @State private var email: String
    @State private var phoneNumber: String
    @State private var isActive: Bool

    @State private var showValidationAlert = false
    @State private var validationMessage   = ""
    @State private var showDeleteConfirm   = false
    @State private var saveSuccess         = false
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

                        // ── Staff badge ────────────────────────────────────
                        staffBadge

                        // ── Sections ───────────────────────────────────────
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

                        formSection(title: "Status", icon: "circle.fill", iconColor: Color(red: 0.30, green: 0.70, blue: 0.46)) {
                            StatusToggleRow(label: "Active Status", isOn: $isActive)
                        }

                        // ── Save ───────────────────────────────────────────
                        saveButton

                        // ── Delete ─────────────────────────────────────────
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
                        .foregroundColor(.red)
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

    // MARK: Staff Badge

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

    // MARK: Save Button

    private var saveButton: some View {
        Button { saveChanges() } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold))
                Text("Save Changes").font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LinearGradient(
                colors: [AppTheme.Brand.accent, Color(red: 0.85, green: 0.35, blue: 0.25)],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.Brand.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Delete Button

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                Text("Delete Staff Member").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(red: 0.85, green: 0.15, blue: 0.15))
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.85, green: 0.15, blue: 0.15).opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: Actions

    private func saveChanges() {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Full name is required."; showValidationAlert = true; return
        }
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Email is required."; showValidationAlert = true; return
        }
        guard email.contains("@") else {
            validationMessage = "Please enter a valid email address."; showValidationAlert = true; return
        }
        guard !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Phone number is required."; showValidationAlert = true; return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        staff.fullName    = fullName.trimmingCharacters(in: .whitespaces)
        staff.email       = email.trimmingCharacters(in: .whitespaces).lowercased()
        staff.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        staff.isActive    = isActive
        staff.updatedAt   = .now

        try? modelContext.save()
        saveSuccess = true
    }

    private func deleteStaff() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        modelContext.delete(staff)
        try? modelContext.save()
        dismiss()
    }
}
