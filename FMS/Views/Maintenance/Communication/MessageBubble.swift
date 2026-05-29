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
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.Brand.primary)
                        .cornerRadius(18)
                    
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.Text.tertiary)
                        .padding(.trailing, 4)
                }
                .padding(.leading, 60)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Text.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(18)
                    
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
}

#Preview {
    VStack {
        MessageBubble(text: "Hey, can you inspect Van 05?", isSender: false, timestamp: Date())
        MessageBubble(text: "Sure! Bringing it into Bay 2 now.", isSender: true, timestamp: Date())
    }
    .padding()
}
