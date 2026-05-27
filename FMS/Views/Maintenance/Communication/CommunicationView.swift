//
//  CommunicationView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI
import SwiftData
import Supabase

struct CommunicationChannel: Identifiable, Hashable {
    let id: UUID
    let senderName: String
    let textPreview: String
    let timestamp: String
    var unreadCount: Int
    let initials: String
    let avatarColor: Color
    let category: ChatCategory
    let autoReplies: [String]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunicationChannel, rhs: CommunicationChannel) -> Bool {
        lhs.id == rhs.id
    }
}

struct CommunicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allUsers: [User]
    
    @StateObject private var supabase = SupabaseManager.shared
    
    @State private var searchText: String = ""
    @State private var selectedCategory: ChatCategory = .all
    @State private var dbMessages: [DBMessage] = []
    @State private var realtimeChannel: RealtimeChannelV2?

    private var computedChannels: [CommunicationChannel] {
        guard let currentUserId = supabase.currentUser?.id else { return [] }
        
        let otherUsers = allUsers.filter { $0.id != currentUserId }
        var list: [CommunicationChannel] = []
        
        for user in otherUsers {
            let userMessages = dbMessages.filter {
                ($0.senderId == currentUserId && $0.receiverId == user.id) ||
                ($0.senderId == user.id && $0.receiverId == currentUserId)
            }.sorted(by: { $0.timestamp < $1.timestamp })
            
            let textPreview: String
            let timestamp: String
            let unreadCount: Int
            
            if let lastMsg = userMessages.last {
                textPreview = lastMsg.message
                
                let formatter = DateFormatter()
                if Calendar.current.isDateInToday(lastMsg.timestamp) {
                    formatter.dateFormat = "h:mm a"
                } else {
                    formatter.dateFormat = "MMM d"
                }
                timestamp = formatter.string(from: lastMsg.timestamp)
                unreadCount = 0
            } else {
                textPreview = "Start conversation"
                timestamp = ""
                unreadCount = 0
            }
            
            let category: ChatCategory
            switch user.role {
            case .driver: category = .drivers
            case .fleetManager: category = .managers
            case .maintenance: category = .maintenance
            }
            
            let avatarColor: Color
            switch user.role {
            case .driver: avatarColor = AppTheme.Brand.primary
            case .fleetManager: avatarColor = AppTheme.Brand.violet
            case .maintenance: avatarColor = AppTheme.Brand.teal
            }
            
            let parts = user.fullName.split(separator: " ")
            let initials: String
            if parts.count >= 2 {
                initials = String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
            } else {
                initials = String(user.fullName.prefix(2)).uppercased()
            }
            
            let channel = CommunicationChannel(
                id: user.id,
                senderName: user.fullName,
                textPreview: textPreview,
                timestamp: timestamp,
                unreadCount: unreadCount,
                initials: initials,
                avatarColor: avatarColor,
                category: category,
                autoReplies: []
            )
            
            list.append(channel)
        }
        
        return list.sorted { c1, c2 in
            let m1 = dbMessages.last(where: { ($0.senderId == currentUserId && $0.receiverId == c1.id) || ($0.senderId == c1.id && $0.receiverId == currentUserId) })
            let m2 = dbMessages.last(where: { ($0.senderId == currentUserId && $0.receiverId == c2.id) || ($0.senderId == c2.id && $0.receiverId == currentUserId) })
            if let t1 = m1?.timestamp, let t2 = m2?.timestamp {
                return t1 > t2
            }
            return m1 != nil && m2 == nil
        }
    }

    // Filtered channels list
    private var filteredChannels: [CommunicationChannel] {
        computedChannels.filter { channel in
            // Filter by search query
            let matchesSearch = searchText.isEmpty ||
                                channel.senderName.localizedCaseInsensitiveContains(searchText) ||
                                channel.textPreview.localizedCaseInsensitiveContains(searchText)
            
            // Filter by category
            let matchesCategory = (selectedCategory == .all) || (channel.category == selectedCategory)
            
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        ZStack {
            AppTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Bar
                TaskSearchBar(text: $searchText, placeholder: "Search messages...")
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Category filters
                MessageFilterView(selectedCategory: $selectedCategory)
                    .padding(.bottom, 8)

                if filteredChannels.isEmpty {
                    Spacer()
                    DetailEmptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: "No Conversations Found",
                        message: "We couldn't find any message thread matching your search filters.",
                        accentColor: AppTheme.Brand.primary
                    )
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredChannels) { channel in
                                NavigationLink(destination: ChatDetailView(channel: channel)) {
                                    CommunicationRow(channel: channel)
                                }
                                .buttonStyle(PlainButtonStyle())

                                if channel.id != filteredChannels.last?.id {
                                    Divider().padding(.leading, 74)
                                }
                            }
                        }
                        .background(AppTheme.Background.card)
                        .cornerRadius(AppTheme.Radius.card)
                        .shadow(color: AppTheme.Shadow.card, radius: 8, y: 3)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationTitle("Messages")
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
            let msgs = try await supabase.fetchMessages()
            await MainActor.run {
                self.dbMessages = msgs
            }
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func startRealtimeListener() {
        guard realtimeChannel == nil else { return }
        let client = supabase.client
        let channel = client.channel("maintenance_messages_realtime")
        
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
}

// MARK: - Row preview component
private struct CommunicationRow: View {
    let channel: CommunicationChannel

    var body: some View {
        HStack(spacing: 14) {
            // Circular avatar
            ZStack {
                Circle()
                    .fill(channel.avatarColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Text(channel.initials)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(channel.avatarColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.senderName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Text.primary)
                    
                    Spacer()
                    
                    Text(channel.timestamp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Text.tertiary)
                }
                
                HStack {
                    Text(channel.textPreview)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Text.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if channel.unreadCount > 0 {
                        Text("\(channel.unreadCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        CommunicationView()
    }
}
