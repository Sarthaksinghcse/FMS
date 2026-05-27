//
//  ChatDetailView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

struct MessageThreadItem: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isSender: Bool
    let timestamp: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ChatDetailView: View {
    @Binding var channel: CommunicationChannel
    
    @State private var textMessage: String = ""
    @State private var messages: [MessageThreadItem] = []
    @State private var replyIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            
            // Header Info Bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(channel.avatarColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    
                    Text(channel.initials)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(channel.avatarColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.senderName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Active Coordination")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Text.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(AppTheme.Background.card)
            .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)

            // Message Bubble list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            MessageBubble(
                                text: msg.text,
                                isSender: msg.isSender,
                                timestamp: msg.timestamp
                            )
                            .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(AppTheme.Background.page)

            // Typing Input Row
            MessageInputView(
                textMessage: $textMessage,
                onSend: sendMessage,
                onAttachPhoto: simulatePhotoAttachment,
                onAttachWorkOrder: simulateWorkOrderAttachment
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load sample history
            messages = [
                MessageThreadItem(text: "Hello! This is the coordination thread regarding recent diagnostics.", isSender: false, timestamp: Date().addingTimeInterval(-7200)),
                MessageThreadItem(text: channel.textPreview, isSender: false, timestamp: Date().addingTimeInterval(-1800))
            ]
            channel.unreadCount = 0
        }
    }

    private func sendMessage() {
        let sentText = textMessage
        textMessage = ""
        
        let userMsg = MessageThreadItem(text: sentText, isSender: true, timestamp: Date())
        messages.append(userMsg)

        // Trigger dynamic auto-responses
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let autoReplyText = channel.autoReplies[replyIndex % channel.autoReplies.count]
            replyIndex += 1
            
            let replyMsg = MessageThreadItem(text: autoReplyText, isSender: false, timestamp: Date())
            withAnimation(.spring()) {
                messages.append(replyMsg)
            }
        }
    }

    private func simulatePhotoAttachment() {
        textMessage = "[ATTACHED REPAIR EVIDENCE: Spark Plug wear level analysis]"
    }

    private func simulateWorkOrderAttachment() {
        textMessage = "[LINKED WORK ORDER: #\(Int.random(in: 1000...9999)) Brake Assembly Check]"
    }
}
