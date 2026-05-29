//
//  MessagePreviewSection.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

struct MessagesPreviewSection: View {
    @State private var sampleMessages = [
        PreviewMessage(
            senderName: "Alex Johnson",
            textPreview: "Truck 12 repair completed",
            timestamp: "2m ago",
            unreadCount: 1,
            initials: "AJ",
            avatarBg: AppTheme.Brand.primary
        ),
        PreviewMessage(
            senderName: "Fleet Manager",
            textPreview: "Check overdue maintenance tasks",
            timestamp: "10m ago",
            unreadCount: 2,
            initials: "FM",
            avatarBg: AppTheme.Brand.violet
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Brand.primary)
                    
                    Text("Messages")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                }
                
                Spacer()
                
                NavigationLink(destination: CommunicationView()) {
                    Text("See All")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 10) {
                ForEach(sampleMessages) { msg in
                    NavigationLink(destination: CommunicationView()) {
                        MessagePreviewCard(message: msg)
                    }
                    .buttonStyle(TactileScaleButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationView {
        ScrollView {
            MessagesPreviewSection()
        }
    }
}
