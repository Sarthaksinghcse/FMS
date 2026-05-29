//
//  ChatDetailView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import Supabase

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
    
    @State private var textMessage: String = ""
    @State private var messages: [MessageThreadItem] = []
    @State private var realtimeChannel: RealtimeChannelV2? = nil

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
        
        let dbMsg = DBMessage(
            id: UUID(),
            senderId: currentUserId,
            receiverId: channel.id,
            message: sentText,
            timestamp: Date()
        )
        
        Task {
            do {
                try await supabase.sendMessage(dbMsg)
                await loadMessages()
            } catch {
                print("Failed to send message: \(error)")
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
