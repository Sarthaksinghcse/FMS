
import SwiftUI
import Supabase

struct FleetManagerChatDetailView: View {
    let currentUser: DBUser
    let chatUser: DBUser
    
    @Environment(SupabaseManager.self) private var supabase
    @State private var messageText = ""
    @State private var messages: [DBMessage] = []
    @State private var realtimeChannel: RealtimeChannelV2?
    @Environment(\.dismiss) private var dismiss
    @State private var forwardSuccess = false
    
    private var conversationMessages: [DBMessage] {
        messages.filter {
            $0.senderId == chatUser.id || $0.receiverId == chatUser.id
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar containing user status and info
            HStack(spacing: 12) {
                // Avatar with online status
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(roleColor(for: chatUser.role).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(String(chatUser.name.prefix(2)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor(for: chatUser.role))
                    
                    Circle()
                        .fill(chatUser.isActive ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 1, y: 1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(chatUser.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(chatUser.isActive ? "Online" : "Offline")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(chatUser.isActive ? .green : .secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay(
                VStack {
                    Spacer()
                    Divider()
                }
            )
            
            // Conversation messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        if conversationMessages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.4))
                                    .padding(.top, 40)
                                Text("No messages yet")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.gray)
                                Text("Send a message to start the conversation.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(conversationMessages) { message in
                                let isMe = message.senderId == currentUser.id
                                HStack {
                                    if isMe {
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(message.message)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(AppTheme.Brand.primary)
                                                .cornerRadius(16)
                                                .contextMenu {
                                                    Button {
                                                        forwardToAll(messageText: message.message)
                                                    } label: {
                                                        Label("Forward to All (Broadcast)", systemImage: "megaphone.fill")
                                                    }
                                                }
                                            Text(formatTime(message.timestamp))
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 4)
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(message.message)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(16)
                                                .contextMenu {
                                                    Button {
                                                        forwardToAll(messageText: message.message)
                                                    } label: {
                                                        Label("Forward to All (Broadcast)", systemImage: "megaphone.fill")
                                                    }
                                                }
                                            Text(formatTime(message.timestamp))
                                                .font(.system(size: 9))
                                                .foregroundColor(.gray)
                                                .padding(.leading, 4)
                                        }
                                        Spacer()
                                    }
                                }
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(red: 0.98, green: 0.98, blue: 0.99))
                .onAppear {
                    if let lastMsg = conversationMessages.last {
                        proxy.scrollTo(lastMsg.id, anchor: .bottom)
                    }
                }
                .onChange(of: conversationMessages.count) { oldValue, newValue in
                    if let lastMsg = conversationMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom Message Input Bar
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .font(.system(size: 15))
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
                Button(action: {
                    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        sendMessage(text)
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.white)
                        .padding(10)
                        .background(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : AppTheme.Brand.primary)
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
        }
        .alert("Forwarded Successfully", isPresented: $forwardSuccess) {
            Button("OK") {}
        } message: {
            Text("This message has been successfully broadcast to all drivers and maintenance staff.")
        }
        .navigationTitle(chatUser.name)
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
    
    private func roleColor(for role: DBUserRole) -> Color {
        switch role {
        case .driver:
            return AppTheme.Brand.royalBlue
        case .maintenance:
            return Color(red: 236/255, green: 110/255, blue: 37/255)
        case .fleetManager:
            return .purple
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func loadMessages() async {
        do {
            self.messages = try await supabase.fetchMessages()
        } catch {
            print("Failed to load Fleet Manager chat messages: \(error)")
        }
    }
    
    private func sendMessage(_ text: String) {
        let dbMsg = DBMessage(
            id: UUID(),
            senderId: currentUser.id,
            receiverId: chatUser.id,
            message: text,
            timestamp: Date()
        )
        Task {
            do {
                try await supabase.sendMessage(dbMsg)
                await MainActor.run {
                    self.messageText = ""
                    Task {
                        await loadMessages()
                    }
                }
            } catch {
                print("Failed to send message from Fleet Manager: \(error)")
            }
        }
    }
    
    private func forwardToAll(messageText: String) {
        Task {
            do {
                let drivers = try await supabase.fetchDrivers()
                let maintenance = try await supabase.fetchMaintenancePersonnel()
                let myId = currentUser.id
                let allRecipients = (drivers + maintenance).filter { $0.id != myId }
                
                if !allRecipients.isEmpty {
                    let messages = allRecipients.map { recipient in
                        DBMessage(
                            id: UUID(),
                            senderId: myId,
                            receiverId: recipient.id,
                            message: messageText,
                            timestamp: Date()
                        )
                    }
                    try await supabase.sendBroadcastMessages(messages)
                    
                    await MainActor.run {
                        forwardSuccess = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } catch {
                print("Failed to forward message: \(error)")
            }
        }
    }
    
    private func startRealtimeListener() {
        guard realtimeChannel == nil else { return }
        let client = supabase.client
        let channel = client.channel("fleet_manager_chat_messages_realtime")
        
        Task {
            let changes = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages"
            )
            
            try? await channel.subscribeWithError()
            self.realtimeChannel = channel
            
            struct MessageHeader: Codable {
                let sender_id: UUID
                let receiver_id: UUID
            }
            
            for await change in changes {
                guard let header = try? change.record.decode(as: MessageHeader.self) else { continue }
                if header.sender_id == chatUser.id || header.receiver_id == chatUser.id {
                    _ = await MainActor.run {
                        Task {
                            await loadMessages()
                        }
                    }
                }
            }
        }
    }
}
