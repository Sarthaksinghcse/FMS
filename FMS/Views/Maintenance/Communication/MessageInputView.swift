import SwiftUI
import PhotosUI

struct MessageInputView: View {
    @Binding var textMessage: String
    @Binding var selectedImageData: Data?
    var onSend: () -> Void
    var onAttachWorkOrder: () -> Void = {}
    
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let imgData = selectedImageData, let uiImage = UIImage(data: imgData) {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .clipped()
                        
                        Button {
                            selectedImageData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.Status.danger)
                                .background(Circle().fill(Color.white))
                        }
                        .offset(x: 6, y: -6)
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 8)
                    
                    Spacer()
                }
                .background(AppTheme.Background.card)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // Text Input Area with Photo Picker inside it
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    TextField("Type a message...", text: $textMessage)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.04))
                .cornerRadius(20)

                // Send Button
                Button(action: onSend) {
                    ZStack {
                        Circle()
                            .fill((textMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) ? AppTheme.Brand.primary.opacity(0.15) : AppTheme.Brand.primary)
                            .frame(width: 34, height: 34)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(textMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(AppTheme.Background.card)
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.selectedImageData = data
                        self.selectedItem = nil
                    }
                }
            }
        }
    }
}

#Preview {
    MessageInputView(textMessage: .constant("Hello World"), selectedImageData: .constant(nil), onSend: {})
}
