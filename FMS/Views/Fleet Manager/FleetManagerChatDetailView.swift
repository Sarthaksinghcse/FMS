import SwiftUI
import Supabase
import PhotosUI

struct FleetManagerChatDetailView: View {
    let currentUser: DBUser
    let chatUser: DBUser
    
    @Environment(SupabaseManager.self) private var supabase
    @State private var messageText = ""
    @State private var messages: [DBMessage] = []
    @State private var realtimeChannel: RealtimeChannelV2?
    @Environment(\.dismiss) private var dismiss
    @State private var forwardSuccess = false
    @State private var selectedImageData: Data? = nil
    @State private var selectedItem: PhotosPickerItem? = nil

    private var conversationMessages: [DBMessage] {
        messages.filter {
            $0.senderId == chatUser.id || $0.receiverId == chatUser.id
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header bar containing user status, info and mockup Close button
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Brand.primary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .padding(.leading, 4)
                
                // Avatar with online status
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(roleColor(for: chatUser.role).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text(String(chatUser.name.prefix(2)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor(for: chatUser.role))
                    
                    Circle()
                        .fill(chatUser.isActive ? AppTheme.Status.success : AppTheme.Brand.primary.opacity(0.4))
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
                        .foregroundColor(chatUser.isActive ? AppTheme.Status.success : .secondary)
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
                                            messageBubbleContent(text: message.message, isMe: true)
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
                                            messageBubbleContent(text: message.message, isMe: false)
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
                .onChange(of: conversationMessages.count) {
                    if let lastMsg = conversationMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMsg.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom Message Input Bar with Photo Picker
            VStack(spacing: 0) {
                if let imgData = selectedImageData, let uiImage = UIImage(data: imgData) {
                    HStack {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                            
                            Button {
                                selectedImageData = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.Status.danger)
                                    .background(Circle().fill(Color.white))
                            }
                            .offset(x: 6, y: -6)
                        }
                        .padding(.leading, 16)
                        .padding(.vertical, 8)
                        
                        Spacer()
                    }
                    .background(Color.white)
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    // Text Input Area with Photo Picker
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.Brand.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        TextField("Type a message...", text: $messageText)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    
                    Button(action: {
                        let sentText = messageText
                        let imgData = selectedImageData
                        selectedImageData = nil
                        messageText = ""
                        
                        Task {
                            if let data = imgData {
                                let msgId = UUID()
                                do {
                                    let urlString = try await supabase.uploadChatImage(messageId: msgId, imageData: data)
                                    let imgMsg = DBMessage(
                                        id: msgId,
                                        senderId: currentUser.id,
                                        receiverId: chatUser.id,
                                        message: "[IMAGE: \(urlString)]",
                                        timestamp: Date()
                                    )
                                    try await supabase.sendMessage(imgMsg)
                                } catch {
                                    let base64 = data.base64EncodedString()
                                    let imgMsg = DBMessage(
                                        id: msgId,
                                        senderId: currentUser.id,
                                        receiverId: chatUser.id,
                                        message: "[IMAGE_BASE64: \(base64)]",
                                        timestamp: Date()
                                    )
                                    try await supabase.sendMessage(imgMsg)
                                }
                            }
                            
                            let text = sentText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                let dbMsg = DBMessage(
                                    id: UUID(),
                                    senderId: currentUser.id,
                                    receiverId: chatUser.id,
                                    message: text,
                                    timestamp: Date()
                                )
                                try await supabase.sendMessage(dbMsg)
                            }
                            
                            await loadMessages()
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white)
                            .padding(10)
                            .background((messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil) ? AppTheme.Brand.primary.opacity(0.3) : AppTheme.Brand.primary)
                            .clipShape(Circle())
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImageData == nil)
                }
                .padding()
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: -2)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .alert("Forwarded Successfully", isPresented: $forwardSuccess) {
            Button("OK") {}
        } message: {
            Text("This message has been successfully broadcast to all drivers and maintenance staff.")
        }
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
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        self.selectedImageData = data
                        self.selectedItem = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func messageBubbleContent(text: String, isMe: Bool) -> some View {
        if text.hasPrefix("[IMAGE:"), text.hasSuffix("]") {
            let urlString = String(text.dropFirst(7).dropLast())
            if let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 220)
                        .cornerRadius(12)
                } placeholder: {
                    ProgressView().tint(isMe ? .white : AppTheme.Brand.primary)
                }
                .padding(4)
                .background(isMe ? AppTheme.Brand.primary : Color(.systemGray6))
                .cornerRadius(16)
            } else {
                fallbackText(text, isMe: isMe)
            }
        } else if text.hasPrefix("[IMAGE_BASE64:"), text.hasSuffix("]") {
            let base64String = String(text.dropFirst(14).dropLast())
            if let data = Data(base64Encoded: base64String), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .cornerRadius(12)
                    .padding(4)
                    .background(isMe ? AppTheme.Brand.primary : Color(.systemGray6))
                    .cornerRadius(16)
            } else {
                fallbackText(text, isMe: isMe)
            }
        } else {
            fallbackText(text, isMe: isMe)
        }
    }

    private func fallbackText(_ text: String, isMe: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundColor(isMe ? .white : .black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMe ? AppTheme.Brand.primary : Color(.systemGray6))
            .cornerRadius(16)
    }

    private func roleColor(for role: DBUserRole) -> Color {
        switch role {
        case .driver:
            return AppTheme.Brand.royalBlue
        case .maintenance:
            return AppTheme.Brand.accent
        case .fleetManager:
            return AppTheme.Brand.primaryDeep
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
