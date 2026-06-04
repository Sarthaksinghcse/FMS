//
//  FleetManagerChatListView.swift
//  FMS
//

import SwiftUI
import Supabase

struct FleetManagerChatListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseManager.self) private var supabase
    
    @State private var searchText = ""
    @State private var selectedRoleFilter: RoleFilter = .all
    
    @State private var drivers: [DBUser] = []
    @State private var maintenancePersonnel: [DBUser] = []
    @State private var messages: [DBMessage] = []
    @State private var isLoading = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var showBroadcastSheet = false
    
    enum RoleFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case drivers = "Drivers"
        case maintenance = "Maintenance"
        
        var id: String { rawValue }
    }
    
    private var currentUser: DBUser? {
        supabase.currentUser
    }
    
    private var allUsers: [DBUser] {
        drivers + maintenancePersonnel
    }
    
    private var filteredUsers: [DBUser] {
        allUsers.filter { user in
            // Role filter
            let matchesRole: Bool
            switch selectedRoleFilter {
            case .all:
                matchesRole = true
            case .drivers:
                matchesRole = user.role == .driver
            case .maintenance:
                matchesRole = user.role == .maintenance
            }
            
            // Search filter
            let matchesSearch = searchText.isEmpty || user.name.localizedCaseInsensitiveContains(searchText)
            
            return matchesRole && matchesSearch
        }
        .sorted { u1, u2 in
            // Sort by last message timestamp (most recent first)
            let t1 = lastMessageTimestamp(for: u1.id) ?? Date.distantPast
            let t2 = lastMessageTimestamp(for: u2.id) ?? Date.distantPast
            if t1 == t2 {
                return u1.name < u2.name
            }
            return t1 > t2
        }
    }
    
    private func conversationMessages(for userId: UUID) -> [DBMessage] {
        return messages.filter {
            $0.senderId == userId || $0.receiverId == userId
        }
    }
    
    private func lastMessage(for userId: UUID) -> DBMessage? {
        conversationMessages(for: userId).last
    }
    
    private func lastMessageText(for userId: UUID) -> String {
        guard let msg = lastMessage(for: userId) else {
            return "No messages yet"
        }
        return msg.message
    }
    
    private func lastMessageTimestamp(for userId: UUID) -> Date? {
        lastMessage(for: userId)?.timestamp
    }
    
    private func lastMessageTimeText(for userId: UUID) -> String {
        guard let timestamp = lastMessageTimestamp(for: userId) else {
            return ""
        }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(timestamp) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: timestamp)
    }
    
    private func hasUnread(for userId: UUID) -> Bool {
        guard let msg = lastMessage(for: userId) else {
            return false
        }
        // If the last message was sent by the other user, we show it as unread/new
        return msg.senderId == userId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search chats...", text: $searchText)
                        .font(.system(size: 15))
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Role filter picker
                Picker("Role", selection: $selectedRoleFilter) {
                    ForEach(RoleFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                // Contact list
                ScrollView {
                    VStack(spacing: 10) {
                        if isLoading && allUsers.isEmpty {
                            ProgressView()
                                .padding(.top, 40)
                        } else if filteredUsers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 40)
                                Text("No conversations found")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(filteredUsers) { user in
                                if let current = currentUser {
                                    NavigationLink(destination: FleetManagerChatDetailView(currentUser: current, chatUser: user)) {
                                        chatRow(for: user)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.royalBlue)
                    .bold()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showBroadcastSheet = true
                    } label: {
                        Image(systemName: "megaphone.fill")
                            .foregroundColor(AppTheme.Brand.primary)
                    }
                }
            }
            .sheet(isPresented: $showBroadcastSheet) {
                FleetManagerBroadcastSheet(
                    drivers: drivers,
                    maintenance: maintenancePersonnel,
                    currentUser: currentUser
                )
            }
            .task {
                await loadData()
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
    }
    
    @ViewBuilder
    private func chatRow(for user: DBUser) -> some View {
        HStack(spacing: 14) {
            // Avatar with Active indicator
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(roleColor(for: user.role).opacity(0.12))
                        .frame(width: 48, height: 48)
                    Text(String(user.name.prefix(2)).uppercased())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor(for: user.role))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: 48, height: 48, alignment: .center)
                }
                
                // Status dot indicator
                Circle()
                    .fill(user.isActive ? AppTheme.Status.success : AppTheme.Brand.primary.opacity(0.4))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 2, y: 2)
            }
            
            // Name, Role and Last message preview
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(user.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(lastMessageTimeText(for: user.id))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 6) {
                    Text(user.role.displayName)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(roleColor(for: user.role))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleColor(for: user.role).opacity(0.1))
                        .cornerRadius(4)
                    
                    if !user.isActive {
                        Text("Offline")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                
                Text(lastMessageText(for: user.id))
                    .font(.system(size: 13, weight: hasUnread(for: user.id) ? .semibold : .regular, design: .rounded))
                    .foregroundColor(hasUnread(for: user.id) ? .black : .gray)
                    .lineLimit(1)
            }
            
            if hasUnread(for: user.id) {
                Circle()
                    .fill(AppTheme.Brand.primary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.04), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.01), radius: 5, x: 0, y: 2)
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
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.drivers = try await supabase.fetchDrivers()
            self.maintenancePersonnel = try await supabase.fetchMaintenancePersonnel()
            self.messages = try await supabase.fetchMessages()
        } catch {
            print("Failed to load Fleet Manager chat list: \(error)")
        }
    }
    
    private func startRealtimeListener() {
        guard realtimeChannel == nil else { return }
        let client = supabase.client
        let channel = client.channel("fleet_manager_list_messages_realtime")
        
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
                guard let _ = try? change.record.decode(as: MessageHeader.self) else { continue }
                _ = await MainActor.run {
                    Task {
                        self.messages = (try? await supabase.fetchMessages()) ?? []
                    }
                }
            }
        }
    }
}

struct FleetManagerBroadcastSheet: View {
    let drivers: [DBUser]
    let maintenance: [DBUser]
    let currentUser: DBUser?
    
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var sending = false
    @State private var sent = false
    @State private var errorMsg: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header / Info
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Brand.accent.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppTheme.Brand.accent)
                    }
                    Text("Broadcast Message")
                        .font(.system(size: 20, weight: .bold))
                    Text("Send a message to all drivers and maintenance personnel.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 20)

                // Input field
                TextField("Type your broadcast message here...", text: $messageText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(4...8)
                    .padding(14)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Status.danger)
                        .padding(.horizontal, 20)
                }

                Spacer()

                // Action buttons
                Button {
                    sendBroadcast()
                } label: {
                    Group {
                        if sending {
                            ProgressView().tint(.white)
                        } else if sent {
                            Label("Broadcast Sent!", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        } else {
                            Label("Send Broadcast", systemImage: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(sent ? AppTheme.Status.success.gradient : AppTheme.Brand.primary.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending || sent)
            }
            .background(Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea())
            .navigationTitle("Broadcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sendBroadcast() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        sending = true
        errorMsg = nil
        
        Task {
            do {
                let myId = currentUser?.id ?? UUID()
                let allRecipients = (drivers + maintenance).filter { $0.id != myId }
                
                if allRecipients.isEmpty {
                    await MainActor.run {
                        errorMsg = "No recipients found."
                        sending = false
                    }
                    return
                }
                
                let messages = allRecipients.map { recipient in
                    DBMessage(
                        id: UUID(),
                        senderId: myId,
                        receiverId: recipient.id,
                        message: text,
                        timestamp: Date()
                    )
                }
                
                try await SupabaseManager.shared.sendBroadcastMessages(messages)
                
                await MainActor.run {
                    sending = false
                    sent = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            } catch {
                print("Failed to send manager broadcast messages: \(error.localizedDescription)")
                await MainActor.run {
                    errorMsg = "Failed to broadcast message: \(error.localizedDescription)"
                    sending = false
                }
            }
        }
    }
}
