//
//  DriverFormView.swift
//  FMS
//
//  Full Add / Edit / Delete driver forms for the Fleet Manager's
//  Driver Management screen. Follows the VehicleFormView.swift pattern.
//

import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Add Driver Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct AddDriverFormView: View {

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

                        // ── Save Button ────────────────────────────────────
                        saveButton

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
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                        .foregroundColor(AppTheme.Brand.royalBlue)
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


    // MARK: Save Button

    private var saveButton: some View {
        Button {
            saveDriver()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Save Driver")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.70, blue: 0.46), Color(red: 0.25, green: 0.60, blue: 0.40)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 0.30, green: 0.70, blue: 0.46).opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Save Action

    private func saveDriver() {
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

        let driver = User(
            fullName:     fullName.trimmingCharacters(in: .whitespaces),
            email:        email.trimmingCharacters(in: .whitespaces).lowercased(),
            phoneNumber:  phoneNumber.trimmingCharacters(in: .whitespaces),
            passwordHash: passwordHash,
            role:         .driver,
            isActive:     isActive
        )

        modelContext.insert(driver)
        try? modelContext.save()
        saveSuccess = true
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Edit Driver Form
// ─────────────────────────────────────────────────────────────────────────────

@available(iOS 26.0, *)
struct EditDriverFormView: View {

    let driver: User

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

                        // ── Driver badge ───────────────────────────────────
                        driverBadge

                        // ── Sections ───────────────────────────────────────
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
            .navigationTitle("Edit Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Brand.royalBlue)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { focusedField = nil }
                        .foregroundColor(AppTheme.Brand.royalBlue)
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

    // MARK: Driver Badge

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
                colors: [Color(red: 0.30, green: 0.70, blue: 0.46), Color(red: 0.25, green: 0.60, blue: 0.40)],
                startPoint: .leading, endPoint: .trailing
            ))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color(red: 0.30, green: 0.70, blue: 0.46).opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: Delete Button

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill").font(.system(size: 15, weight: .semibold))
                Text("Delete Driver").font(.system(size: 15, weight: .semibold, design: .rounded))
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

        driver.fullName    = fullName.trimmingCharacters(in: .whitespaces)
        driver.email       = email.trimmingCharacters(in: .whitespaces).lowercased()
        driver.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        driver.isActive    = isActive
        driver.updatedAt   = .now

        try? modelContext.save()
        saveSuccess = true
    }

    private func deleteDriver() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        modelContext.delete(driver)
        try? modelContext.save()
        dismiss()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared Form Components for User Forms
// ─────────────────────────────────────────────────────────────────────────────

// MARK: Field Tag Enum

enum UserFocusField: Hashable {
    case fullName, email, phoneNumber, password
}

// MARK: Text Field Row

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

// MARK: Password Field Row

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

// MARK: Status Toggle Row

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
