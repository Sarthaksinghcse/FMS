
import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Numeric-only input helper
/// Strips any character that is not a digit or a single decimal point.
private func numericOnly(_ text: String, allowDecimal: Bool = true) -> String {
    var result = ""
    var hasDot = false
    for ch in text {
        if ch.isNumber {
            result.append(ch)
        } else if allowDecimal && (ch == "." || ch == ",") && !hasDot {
            result.append(".")
            hasDot = true
        }
    }
    return result
}


// MARK: - Fuel Section Card (Home Dashboard)

struct FuelSectionCard: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FuelLog.loggedAt, order: .reverse) private var fuelLogs: [FuelLog]

    private var lastLog: FuelLog? { fuelLogs.first }

    var body: some View {
        Button {
            vm.showFuelLog = true
        } label: {
            HStack(spacing: 16) {
                // Fuel pump icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hue: 0.58, saturation: 0.70, brightness: 0.55).opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "fuelpump.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hue: 0.58, saturation: 0.80, brightness: 0.75))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Log Refuel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let log = lastLog {
                        HStack(spacing: 4) {
                            Text("Last:")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1fL · ₹%.0f", log.litres, log.amountPaid))
                                .foregroundStyle(.primary)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(log.loggedAt, style: .relative)
                                .foregroundStyle(.secondary)
                            Text("ago")
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 12))
                    } else {
                        Text("No refuel logged yet")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Fuel Log Sheet

struct FuelLogSheet: View {
    @ObservedObject var vm: DriverDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Form fields — raw strings, validated on change
    @State private var litresText   = ""
    @State private var amountText   = ""
    @State private var notes        = ""

    // Receipt photo
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var receiptImage: UIImage?

    // Submission
    @State private var saving = false
    @State private var saved  = false
    @State private var validationError: String?

    // Derived numbers from validated strings
    private var litres: Double?  { Double(litresText)  }
    private var amount: Double?  { Double(amountText)  }

    // Fuel type read from the local SwiftData Vehicle record, fallback to petrol
    private var vehicleFuelType: FuelType {
        if let vid = vm.assignedVehicle?.id,
           let local = vm.allLocalVehicles.first(where: { $0.id == vid }) {
            return local.fuelType
        }
        return .petrol
    }

    private var canSave: Bool {
        (litres ?? 0) > 0 && (amount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Hero ─────────────────────────────────────────────────
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hue: 0.58, saturation: 0.70, brightness: 0.55).opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(Color(hue: 0.58, saturation: 0.80, brightness: 0.75))
                        }
                        Text("Log Refuel")
                            .font(.system(size: 20, weight: .bold))
                        Text("Record your fuel fill-up details")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // ── Vehicle / Fuel type info row ─────────────────────────
                    HStack(spacing: 14) {
                        Image(systemName: vehicleFuelType.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hue: 0.58, saturation: 0.80, brightness: 0.75))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fuel Type")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(vehicleFuelType.displayName)
                                .font(.system(size: 15, weight: .medium))
                        }
                        Spacer()
                        if let v = vm.assignedVehicle {
                            Text(v.vehicleNumber)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

                    // ── Quantity & Amount ─────────────────────────────────────
                    VStack(spacing: 0) {

                        // Litres
                        HStack(spacing: 14) {
                            Image(systemName: "gauge.with.needle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quantity")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                TextField("0.0", text: $litresText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .medium))
                                    .onChange(of: litresText) { _, new in
                                        let clean = numericOnly(new)
                                        if clean != new { litresText = clean }
                                    }
                            }
                            Spacer()
                            Text("Litres")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        Divider().padding(.leading, 56)

                        // Amount
                        HStack(spacing: 14) {
                            Image(systemName: "indianrupeesign.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Amount Paid")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .medium))
                                    .onChange(of: amountText) { _, new in
                                        let clean = numericOnly(new)
                                        if clean != new { amountText = clean }
                                    }
                            }
                            Spacer()
                            Text("₹")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

                    // ── Receipt Photo ─────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 14) {
                            Image(systemName: "receipt.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Receipt")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(receiptImage == nil ? "Attach fuel receipt photo" : "Receipt attached")
                                    .font(.system(size: 14))
                                    .foregroundStyle(receiptImage == nil ? .secondary : .primary)
                            }
                            Spacer()

                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 1,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                if let img = receiptImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.fmsIndigo.opacity(0.4), lineWidth: 1)
                                        )
                                } else {
                                    Label("Add", systemImage: "photo.badge.plus")
                                        .labelStyle(.iconOnly)
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.fmsIndigo)
                                        .frame(width: 44, height: 44)
                                        .background(Color.fmsIndigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedPhotoItems) {
                                Task {
                                    if let item = selectedPhotoItems.first,
                                       let data = try? await item.loadTransferable(type: Data.self) {
                                        receiptImage = UIImage(data: data)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if let img = receiptImage {
                            Divider().padding(.leading, 56)
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        receiptImage = nil
                                        selectedPhotoItems = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, Color.black.opacity(0.5))
                                    }
                                    .padding(.top, 6)
                                    .padding(.trailing, 22)
                                }
                        }
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))

                    // ── Notes ─────────────────────────────────────────────────
                    TextField("Additional notes (optional)…", text: $notes, axis: .vertical)
                        .font(.system(size: 14))
                        .lineLimit(2...4)
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))

                    // ── Validation error ──────────────────────────────────────
                    if let err = validationError {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.Status.danger)
                    }

                    // ── Save Button ───────────────────────────────────────────
                    Button {
                        save()
                    } label: {
                        Group {
                            if saving {
                                ProgressView().tint(.white)
                            } else if saved {
                                Label("Saved!", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            } else {
                                Label("Save Refuel Log", systemImage: "fuelpump.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            saved ? AppTheme.Status.success.gradient : Color.fmsIndigo.gradient
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave || saving || saved)
                }
                .padding(20)
            }
            .background(Color.fmsBackground.ignoresSafeArea())
            .navigationTitle("Refuel Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        guard let l = litres, l > 0, let a = amount, a > 0 else {
            validationError = "Please enter valid quantity and amount."
            return
        }
        validationError = nil
        saving = true

        let driverId  = SupabaseManager.shared.currentUser?.id ?? UUID()
        let vehicleId = vm.assignedVehicle?.id

        Task {
            let imgData = receiptImage.flatMap { $0.jpegData(compressionQuality: 0.8) }
            var receiptUrl: String? = nil
            let logId = UUID()
            
            if let data = imgData {
                do {
                    receiptUrl = try await SupabaseManager.shared.uploadReceiptImage(logId: logId, imageData: data)
                } catch {
                    print("Failed to upload receipt image to Supabase: \(error.localizedDescription)")
                }
            }

            let dbLog = DBFuelLog(
                id: logId,
                driverId: driverId,
                vehicleId: vehicleId,
                tripId: vm.currentTrip?.id,
                fuelType: vehicleFuelType.rawValue,
                litres: l,
                amountPaid: a,
                odometer: vm.assignedVehicle?.odometerReading,
                receiptUrl: receiptUrl,
                notes: notes.isEmpty ? nil : notes,
                createdAt: Date()
            )

            do {
                try await SupabaseManager.shared.createFuelLog(dbLog)
            } catch {
                print("Failed to sync fuel log to Supabase: \(error.localizedDescription)")
            }

            let log = FuelLog(
                id: logId,
                driverId: driverId,
                vehicleId: vehicleId,
                tripId: vm.currentTrip?.id,
                fuelType: vehicleFuelType.rawValue,
                litres: l,
                amountPaid: a,
                odometer: vm.assignedVehicle?.odometerReading,
                receiptImageData: imgData,
                notes: notes.isEmpty ? nil : notes,
                loggedAt: Date()
            )

            await MainActor.run {
                modelContext.insert(log)
                try? modelContext.save()

                withAnimation {
                    saving = false
                    saved  = true
                }

                UINotificationFeedbackGenerator().notificationOccurred(.success)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        }
    }
}
