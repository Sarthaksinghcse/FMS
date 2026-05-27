//
//  MessageInputView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

struct MessageInputView: View {
    @Binding var textMessage: String
    var onSend: () -> Void
    var onAttachPhoto: () -> Void = {}
    var onAttachWorkOrder: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Attach File / Work Order
                Button(action: onAttachWorkOrder) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Text.secondary)
                }
                .buttonStyle(ScaleButtonStyle())

                // Attach Camera / Emergency Photo
                Button(action: onAttachPhoto) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Text.secondary)
                }
                .buttonStyle(ScaleButtonStyle())

                // Text Input
                TextField("Type a message...", text: $textMessage)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(20)

                // Send Button
                Button(action: onSend) {
                    ZStack {
                        Circle()
                            .fill(textMessage.isEmpty ? Color.gray.opacity(0.3) : AppTheme.Brand.primary)
                            .frame(width: 34, height: 34)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(textMessage.isEmpty)
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
