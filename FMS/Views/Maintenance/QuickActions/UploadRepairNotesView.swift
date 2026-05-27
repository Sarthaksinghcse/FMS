//
//  UploadRepairNotesView.swift
//  FMS
//

import SwiftUI
import SwiftData
import PhotosUI

struct UploadRepairNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Vehicle.registrationNumber) private var vehicles: [Vehicle]
    @Query private var workOrders: [WorkOrder]

    // Form State
    @State private var selectedVehicleId: UUID?
    @State private var selectedWorkOrderId: UUID?
    @State private var serviceType: String = "General Repair"
    @State private var notes: String = ""
    @State private var costString: String = ""
    
    // Photo Picker State
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [(data: Data, uiImage: UIImage)] = []
    @State private var capturedImage: UIImage?
    
    // Attachment Options
    @State private var showAttachmentOptions = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showFilePicker = false
    
    // UI State
    @State private var isUploading = false
    @State private var showSuccessOverlay = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let serviceTypes = ["General Repair", "Oil Change", "Tire Replacement", "Brake Service", "Engine Diagnostics", "Body Work", "Other"]

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    
                    // Main Form Card
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Section 1: Identification
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Record Details")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.accent)
                                .textCase(.uppercase)

                            // Vehicle Selector
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Vehicle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Vehicle", selection: $selectedVehicleId) {
                                    Text("Choose a vehicle...").tag(UUID?.none)
                                    ForEach(vehicles) { vehicle in
                                        Text("\(vehicle.make) \(vehicle.model) (\(vehicle.registrationNumber))")
                                            .tag(UUID?.some(vehicle.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }
                            
                            // Work Order Selector (Optional)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Link Work Order (Optional)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Work Order", selection: $selectedWorkOrderId) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(workOrders.filter { $0.vehicleId == selectedVehicleId }) { order in
                                        Text(order.title).tag(UUID?.some(order.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }
                        }

                        Divider()

                        // Section 2: Service Info
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Service Information")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.accent)
                                .textCase(.uppercase)

                            // Service Type
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Service Type")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                
                                Picker("Service Type", selection: $serviceType) {
                                    ForEach(serviceTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }

                            // Cost
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Cost (₹)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextField("e.g. 5000", text: $costString)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 14))
                                    .padding(12)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Repair Notes")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Text.secondary)
                                TextEditor(text: $notes)
                                    .frame(minHeight: 100)
                                    .padding(6)
                                    .background(Color.black.opacity(0.04))
                                    .cornerRadius(8)
                            }
                        }

                        Divider()

                        // Section 3: Photo Evidence
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Image Evidence")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Brand.accent)
                                .textCase(.uppercase)

                            Button {
                                showAttachmentOptions = true
                            } label: {
                                HStack {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 18))
                                    Text("Add Photos / Files")
                                        .font(.system(size: 13, weight: .bold))
                                    Spacer()
                                    Text("\(selectedImages.count)/5")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(10)
                                .foregroundColor(AppTheme.Brand.primary)
                            }

                            if !selectedImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(selectedImages.indices, id: \.self) { index in
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: selectedImages[index].uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                Button {
                                                    selectedImages.remove(at: index)
                                                    selectedItems.remove(at: index)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                        .background(Circle().fill(.white))
                                                }
                                                .offset(x: 5, y: -5)
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.card)
                    .shadow(color: AppTheme.Shadow.card, radius: 10, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // Upload Button
                    Button(action: saveMaintenanceRecord) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 8)
                                Text("Uploading...")
                            } else {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("Save Repair Record")
                            }
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            isFormValid && !isUploading ? AppTheme.Brand.primary : Color.gray.opacity(0.5)
                        )
                        .cornerRadius(12)
                        .shadow(color: isFormValid && !isUploading ? AppTheme.Brand.primary.opacity(0.3) : Color.clear, radius: 8, y: 3)
                    }
                    .disabled(!isFormValid || isUploading)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }

            if showSuccessOverlay {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().fill(AppTheme.Status.success).frame(width: 80, height: 80)
                            Image(systemName: "checkmark").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        }
                        Text("Record Saved").font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Repair notes and images uploaded.").font(.system(size: 13)).foregroundColor(AppTheme.Text.secondary)
                    }
                    .padding(32)
                    .background(AppTheme.Background.card)
                    .cornerRadius(AppTheme.Radius.modal)
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Upload Repair Notes")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Upload Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Add Attachment", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
            Button("Take Photo") { showCamera = true }
            Button("Choose from Photo Library") { showPhotoLibrary = true }
            Button("Choose from Files") { showFilePicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage, let data = image.jpegData(compressionQuality: 0.8) {
                if selectedImages.count < 5 {
                    selectedImages.append((data, image))
                } else {
                    errorMessage = "You can only upload up to 5 images."
                    showErrorAlert = true
                }
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedItems) { oldValue, newValue in
            loadImages(from: newValue)
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            do {
                let urls = try result.get()
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                            if selectedImages.count < 5 {
                                selectedImages.append((data, image))
                            }
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } catch {
                errorMessage = "Failed to load files."
                showErrorAlert = true
            }
        }
    }

    private var isFormValid: Bool {
        selectedVehicleId != nil && !notes.isEmpty && Double(costString) != nil
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        Task {
            var newImages: [(Data, UIImage)] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    
                    // Validate image format (must be JPG or PNG)
                    if let contentType = item.supportedContentTypes.first {
                        if contentType == .jpeg || contentType == .png || contentType == .heic {
                             newImages.append((data, uiImage))
                        } else {
                            await MainActor.run {
                                errorMessage = "Unsupported file type. Please upload JPG or PNG images."
                                showErrorAlert = true
                            }
                        }
                    } else {
                        newImages.append((data, uiImage))
                    }
                }
            }
            await MainActor.run {
                self.selectedImages = newImages
            }
        }
    }

    private func saveMaintenanceRecord() {
        guard let vehicleId = selectedVehicleId, let cost = Double(costString) else { return }
        let userId = SupabaseManager.shared.currentUser?.id ?? UUID()
        let recordId = UUID()
        
        isUploading = true
        
        Task {
            var uploadedURLs: [String] = []
            
            do {
                for (index, imageData) in selectedImages.enumerated() {
                    let url = try await SupabaseManager.shared.uploadRepairImage(recordId: recordId, imageData: imageData.data, index: index)
                    uploadedURLs.append(url)
                }
                
                let dbRecord = DBMaintenanceRecord(
                    id: recordId,
                    vehicleId: vehicleId,
                    workOrderId: selectedWorkOrderId,
                    serviceType: serviceType,
                    serviceDate: Date(),
                    cost: cost,
                    notes: notes,
                    repairImages: uploadedURLs.isEmpty ? nil : uploadedURLs,
                    performedBy: userId,
                    createdAt: Date()
                )
                
                try await SupabaseManager.shared.createMaintenanceRecord(dbRecord)
                
                // Save to local context
                await MainActor.run {
                    modelContext.insert(dbRecord.asLocalRecord)
                    try? modelContext.save()
                    isUploading = false
                    withAnimation { showSuccessOverlay = true }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
                
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to upload record: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}
