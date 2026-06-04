//
//  ChatDetailView.swift
//  FMS
//

import SwiftUI
import Supabase
import PhotosUI

struct MessageThreadItem: Identifiable, Hashable {
    let id: UUID
    let text: String
    let isSender: Bool
    let timestamp: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ChatDetailView: View {
    let channel: CommunicationChannel
    
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss
    
    @State private var textMessage: String = ""
    @State private var messages: [MessageThreadItem] = []
    @State private var realtimeChannel: RealtimeChannelV2? = nil


    var body: some View {
        VStack(spacing: 0) {
            
            // Redesigned Custom Header to match the reference mockup
            ZStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Brand.primary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                
                Text("Chat with \(channel.senderName)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Text.primary)
            }
            .padding(.vertical, 10)
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
                onAttachWorkOrder: simulateWorkOrderAttachment
            )
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await loadMessages()
            startRealtimeListener()
        }
        .onDisappear {
            if let activeChannel = realtimeChannel {
                let client = supabase.client
                Task {
                    await client.removeChannel(activeChannel)
                }
                realtimeChannel = nil
            }
        }
    }

    func loadMessages() async {
        do {
            guard let currentUserId = supabase.currentUser?.id else { return }
            let allDBMessages = try await supabase.fetchMessages()
            let filtered = allDBMessages.filter { msg in
                (msg.senderId == currentUserId && msg.receiverId == channel.id) ||
                (msg.senderId == channel.id && msg.receiverId == currentUserId)
            }
            
            // Map to MessageThreadItem
            let mapped = filtered.map { msg in
                MessageThreadItem(
                    id: msg.id,
                    text: msg.message,
                    isSender: msg.senderId == currentUserId,
                    timestamp: msg.timestamp
                )
            }
            
            await MainActor.run {
                self.messages = mapped
            }
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func startRealtimeListener() {
        guard realtimeChannel == nil else { return }
        let client = supabase.client
        let channel = client.channel("chat_detail_messages_realtime")
        
        Task {
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages"
            )
            
            try? await channel.subscribeWithError()
            self.realtimeChannel = channel
            
            for await _ in changes {
                await loadMessages()
            }
        }
    }

    private func sendMessage() {
        guard !textMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let currentUserId = supabase.currentUser?.id else { return }
        
        let sentText = textMessage
        textMessage = ""
        
        Task {
            do {
                let textTrimmed = sentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !textTrimmed.isEmpty {
                    let textMsg = DBMessage(
                        id: UUID(),
                        senderId: currentUserId,
                        receiverId: channel.id,
                        message: textTrimmed,
                        timestamp: Date()
                    )
                    try await supabase.sendMessage(textMsg)
                }
                
                await loadMessages()
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }

    private func simulateWorkOrderAttachment() {
        textMessage = "[LINKED WORK ORDER: #\(Int.random(in: 1000...9999)) Brake Assembly Check]"
    }
}
