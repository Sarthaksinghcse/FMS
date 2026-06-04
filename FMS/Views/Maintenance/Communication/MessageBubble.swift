//
//  MessageBubble.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

struct MessageBubble: View {
    let text: String
    let isSender: Bool
    let timestamp: Date

    var body: some View {
        HStack {
            if isSender {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    messageContent
                    
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.Text.tertiary)
                        .padding(.trailing, 4)
                }
                .padding(.leading, 60)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    messageContent
                    
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.Text.tertiary)
                        .padding(.leading, 4)
                }
                .padding(.trailing, 60)
                
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        if text.hasPrefix("[IMAGE:"), text.hasSuffix("]") {
            let urlString = String(text.dropFirst(7).dropLast())
            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 150)
                        .cornerRadius(12)
                        .clipped()
                } placeholder: {
                    ProgressView()
                        .tint(isSender ? .white : AppTheme.Brand.primary)
                        .frame(width: 200, height: 150)
                }
                .frame(width: 200, height: 150)
                .padding(4)
                .background(isSender ? AppTheme.Brand.primary : Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            } else {
                fallbackText
            }
        } else if text.hasPrefix("[IMAGE_BASE64:"), text.hasSuffix("]") {
            let base64String = String(text.dropFirst(14).dropLast())
            if let data = Data(base64Encoded: base64String), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 150)
                    .cornerRadius(12)
                    .clipped()
                    .padding(4)
                    .background(isSender ? AppTheme.Brand.primary : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
            } else {
                fallbackText
            }
        } else {
            fallbackText
        }
    }

    private var fallbackText: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isSender ? .white : AppTheme.Text.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSender ? AppTheme.Brand.primary : Color(UIColor.secondarySystemBackground))
            .cornerRadius(18)
    }
}

#Preview {
    VStack {
        MessageBubble(text: "Hey, can you inspect Van 05?", isSender: false, timestamp: Date())
        MessageBubble(text: "Sure! Bringing it into Bay 2 now.", isSender: true, timestamp: Date())
    }
    .padding()
}
