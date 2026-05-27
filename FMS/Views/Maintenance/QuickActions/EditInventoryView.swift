//
//  EditInventoryView.swift
//  FMS
//
//  Created by Gauri Verma on 27/05/26.
//

import SwiftUI
import SwiftData

struct EditInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var item: InventoryItem
    var onDelete: (() -> Void)? = nil

    @State private var partName: String = ""
    @State private var partNumber: String = ""
    @State private var quantityInStock: String = ""
    @State private var reorderThreshold: String = ""
    @State private var unitCost: String = ""
    @State private var supplierName: String = ""

    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false

    @State private var hasAttemptedSave = false
    @State private var validationErrors: [String] = []

    init(item: InventoryItem, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onDelete = onDelete
        _partName = State(initialValue: item.partName)
        _partNumber = State(initialValue: item.partNumber)
        _quantityInStock = State(initialValue: String(item.quantityInStock))
        _reorderThreshold = State(initialValue: String(item.reorderThreshold))
        _unitCost = State(initialValue: String(format: "%.2f", item.unitCost))
        _supplierName = State(initialValue: item.supplierName ?? "")
    }

    private func validateForm() -> [String] {
        var errors: [String] = []
        
        let trimmedName = partName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Part Name is required.")
        }
        
        let trimmedNumber = partNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNumber.isEmpty {
            errors.append("Part Number is required.")
        }
        
        let trimmedQty = quantityInStock.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQty.isEmpty {
            errors.append("Quantity in Stock is required.")
        } else if let qty = Int(trimmedQty) {
            if qty < 0 {
                errors.append("Quantity in Stock cannot be negative.")
            }
        } else {
            errors.append("Quantity in Stock must be a valid whole number.")
        }
        
        let trimmedThreshold = reorderThreshold.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedThreshold.isEmpty {
            errors.append("Reorder Threshold is required.")
        } else if let threshold = Int(trimmedThreshold) {
            if threshold < 0 {
                errors.append("Reorder Threshold cannot be negative.")
            }
        } else {
            errors.append("Reorder Threshold must be a valid whole number.")
        }
        
        let trimmedCost = unitCost.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCost.isEmpty {
            errors.append("Unit Cost is required.")
        } else if let cost = Double(trimmedCost) {
            if cost < 0 {
                errors.append("Unit Cost cannot be negative.")
            }
        } else {
            errors.append("Unit Cost must be a valid positive decimal number.")
        }
        
        return errors
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Background.page.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Premium Inline Error / Validation Feedback Card
                        if hasAttemptedSave && !validationErrors.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.octagon.fill")
                                        .foregroundColor(AppTheme.Status.danger)
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Please correct the following errors:")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Status.danger)
                                    Spacer()
                                }
                                
                                ForEach(validationErrors, id: \.self) { errorMsg in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .foregroundColor(AppTheme.Status.danger)
                                            .font(.system(size: 14, weight: .bold))
                                        Text(errorMsg)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(AppTheme.Text.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .padding(14)
                            .background(AppTheme.Status.danger.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.Status.danger.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Part Details Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Part Details")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                FormFieldRow(icon: "wrench.and.screwdriver.fill", label: "Part Name", text: $partName, placeholder: "e.g. Brake Pad Set", color: AppTheme.Brand.primary)

                                Divider().padding(.leading, 50)

                                FormFieldRow(icon: "number", label: "Part Number", text: $partNumber, placeholder: "e.g. BP-4420", color: AppTheme.Brand.teal)
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                            .padding(.horizontal)
                        }

                        // Stock Information Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Stock Information")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                FormFieldRow(icon: "shippingbox.fill", label: "Quantity", text: $quantityInStock, placeholder: "e.g. 50", color: AppTheme.Brand.violet, keyboard: .numberPad)

                                Divider().padding(.leading, 50)

                                FormFieldRow(icon: "exclamationmark.triangle.fill", label: "Reorder Threshold", text: $reorderThreshold, placeholder: "e.g. 10", color: AppTheme.Brand.amber, keyboard: .numberPad)

                                Divider().padding(.leading, 50)

                                FormFieldRow(icon: "dollarsign.circle.fill", label: "Unit Cost", text: $unitCost, placeholder: "e.g. 45.99", color: AppTheme.Status.success, keyboard: .decimalPad)
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                            .padding(.horizontal)
                        }

                        // Supplier Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Supplier (Optional)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Text.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                FormFieldRow(icon: "building.2.fill", label: "Supplier Name", text: $supplierName, placeholder: "e.g. AutoParts Co.", color: AppTheme.Brand.primaryDeep)
                            }
                            .background(AppTheme.Background.card)
                            .cornerRadius(AppTheme.Radius.card)
                            .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                            .padding(.horizontal)
                        }

                        // Save Changes Button
                        Button(action: saveChanges) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Save Changes")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AppTheme.Radius.medium)
                            .shadow(color: AppTheme.Brand.primary.opacity(0.3), radius: 8, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Delete Spare Part Button
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Delete Spare Part")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(AppTheme.Status.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppTheme.Status.danger.opacity(0.08))
                            .cornerRadius(AppTheme.Radius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                                    .stroke(AppTheme.Status.danger.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Edit Spare Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .alert("Changes Saved", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("\(partName) has been updated successfully.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Spare Part", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this part? This action cannot be undone.")
            }
            // Reactive live-error updates as typing proceeds
            .onChange(of: partName) { _, _ in if hasAttemptedSave { withAnimation { validationErrors = validateForm() } } }
            .onChange(of: partNumber) { _, _ in if hasAttemptedSave { withAnimation { validationErrors = validateForm() } } }
            .onChange(of: quantityInStock) { _, _ in if hasAttemptedSave { withAnimation { validationErrors = validateForm() } } }
            .onChange(of: reorderThreshold) { _, _ in if hasAttemptedSave { withAnimation { validationErrors = validateForm() } } }
            .onChange(of: unitCost) { _, _ in if hasAttemptedSave { withAnimation { validationErrors = validateForm() } } }
        }
    }

    private func saveChanges() {
        hasAttemptedSave = true
        let errors = validateForm()
        validationErrors = errors
        
        guard errors.isEmpty else {
            errorMessage = "Please review the form to correct invalid values."
            showingError = true
            return
        }

        guard let qty = Int(quantityInStock),
              let threshold = Int(reorderThreshold),
              let cost = Double(unitCost) else {
            errorMessage = "Please enter valid numeric values."
            showingError = true
            return
        }

        // Apply changes directly to SwiftData model properties
        item.partName = partName.trimmingCharacters(in: .whitespacesAndNewlines)
        item.partNumber = partNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        item.quantityInStock = qty
        item.reorderThreshold = threshold
        item.unitCost = cost
        item.supplierName = supplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        item.updatedAt = Date()

        showingSuccess = true
    }

    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
        onDelete?()
        dismiss()
    }
}

// MARK: - Form Field Row

private struct FormFieldRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    let placeholder: String
    let color: Color
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Text.secondary)

                TextField(placeholder, text: $text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Text.primary)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
