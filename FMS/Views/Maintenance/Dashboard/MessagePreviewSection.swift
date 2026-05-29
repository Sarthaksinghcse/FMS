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
                SectionHeader(title: "Messages")
                
                Spacer()
                
                Button(action: {}) {
                    Text("See All")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.Brand.primary)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 10) {
                ForEach(sampleMessages) { msg in
                    Button(action: {}) {
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
