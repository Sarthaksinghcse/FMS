//
//  MessagePreviewCard.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

struct PreviewMessage: Identifiable, Hashable {
    let id = UUID()
    let senderName: String
    let textPreview: String
    let timestamp: String
    var unreadCount: Int
    let initials: String
    let avatarBg: Color
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PreviewMessage, rhs: PreviewMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessagePreviewCard: View {
    let message: PreviewMessage

    var body: some View {
        HStack(spacing: 14) {
            
            // Avatar
            ZStack {
                Circle()
                    .fill(message.avatarBg.opacity(0.12))
                    .frame(width: 46, height: 46)
                
                Text(message.initials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(message.avatarBg)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(message.senderName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    
                    Spacer()
                    
                    Text(message.timestamp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Text.tertiary)
                }
                
                HStack {
                    Text(message.textPreview)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Text.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if message.unreadCount > 0 {
                        Text("\(message.unreadCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Circle().fill(Theme.darkOrange)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.Background.card)
        .cornerRadius(AppTheme.Radius.card)
        .shadow(color: AppTheme.Shadow.card, radius: 4, x: 0, y: 2)
    }
}

#Preview {
    MessagePreviewCard(
        message: PreviewMessage(
            senderName: "Alex Johnson",
            textPreview: "Truck 12 repair completed",
            timestamp: "2m ago",
            unreadCount: 1,
            initials: "AJ",
            avatarBg: Theme.royalBlue
        )
    )
    .padding()
    .background(Color.gray.opacity(0.1))
}
