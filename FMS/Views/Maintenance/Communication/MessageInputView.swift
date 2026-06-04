import SwiftUI

struct MessageInputView: View {
    @Binding var textMessage: String
    var onSend: () -> Void
    var onAttachWorkOrder: () -> Void = {}
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Input Area
                TextField("Type a message...", text: $textMessage)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(20)

                // Send Button
                Button(action: onSend) {
                    ZStack {
                        Circle()
                            .fill(textMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppTheme.Brand.primary.opacity(0.15) : AppTheme.Brand.primary)
                            .frame(width: 34, height: 34)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(textMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(AppTheme.Background.card)
        }
    }
}

#Preview {
    MessageInputView(textMessage: .constant("Hello World"), onSend: {})
}
