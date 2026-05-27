//
//  AddInventoryView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import SwiftData

struct AddInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var partName: String = ""
    @State private var partNumber: String = ""
    @State private var quantityInStock: String = ""
    @State private var reorderThreshold: String = ""
    @State private var unitCost: String = ""
    @State private var supplierName: String = ""

    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var isFormValid: Bool {
        !partName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !partNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(quantityInStock) != nil &&
        Int(reorderThreshold) != nil &&
        Double(unitCost) != nil
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // Part Details Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Part Details")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.Text.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            FormField(icon: "wrench.and.screwdriver.fill", label: "Part Name", text: $partName, placeholder: "e.g. Brake Pad Set", color: AppTheme.Brand.primary)

                            Divider().padding(.leading, 50)

                            FormField(icon: "number", label: "Part Number", text: $partNumber, placeholder: "e.g. BP-4420", color: AppTheme.Brand.teal)
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
                            FormField(icon: "shippingbox.fill", label: "Quantity", text: $quantityInStock, placeholder: "e.g. 50", color: AppTheme.Brand.violet, keyboard: .numberPad)

                            Divider().padding(.leading, 50)

                            FormField(icon: "exclamationmark.triangle.fill", label: "Reorder Threshold", text: $reorderThreshold, placeholder: "e.g. 10", color: AppTheme.Brand.amber, keyboard: .numberPad)

                            Divider().padding(.leading, 50)

                            FormField(icon: "dollarsign.circle.fill", label: "Unit Cost", text: $unitCost, placeholder: "e.g. 45.99", color: AppTheme.Status.success, keyboard: .decimalPad)
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
                            FormField(icon: "building.2.fill", label: "Supplier Name", text: $supplierName, placeholder: "e.g. AutoParts Co.", color: AppTheme.Brand.primaryDeep)
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 6, y: 2)
                        .padding(.horizontal)
                    }

                    // Submit Button
                    Button(action: saveItem) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Add to Inventory")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isFormValid
                                ? LinearGradient(colors: [AppTheme.Brand.primary, AppTheme.Brand.primaryDeep], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppTheme.Radius.medium)
                        .shadow(color: isFormValid ? AppTheme.Brand.primary.opacity(0.3) : Color.clear, radius: 8, y: 4)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer(minLength: 32)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle("Add Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Item Added", isPresented: $showingSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("\(partName) has been added to inventory successfully.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveItem() {
        guard let qty = Int(quantityInStock),
              let threshold = Int(reorderThreshold),
              let cost = Double(unitCost) else {
            errorMessage = "Please enter valid numeric values."
            showingError = true
            return
        }

        let item = InventoryItem(
            partName: partName.trimmingCharacters(in: .whitespaces),
            partNumber: partNumber.trimmingCharacters(in: .whitespaces),
            quantityInStock: qty,
            reorderThreshold: threshold,
            unitCost: cost,
            supplierName: supplierName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : supplierName.trimmingCharacters(in: .whitespaces)
        )

        modelContext.insert(item)
        showingSuccess = true
    }
}

// MARK: - Form Field Row

private struct FormField: View {
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
