//
//  CommunicationView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

struct CommunicationChannel: Identifiable, Hashable {
    let id = UUID()
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
    @State private var searchText: String = ""
    @State private var selectedCategory: ChatCategory = .all

    @State private var channels = [
        CommunicationChannel(
            senderName: "Alex Johnson",
            textPreview: "Truck 12 repair completed",
            timestamp: "2m ago",
            unreadCount: 1,
            initials: "AJ",
            avatarColor: AppTheme.Brand.primary,
            category: .drivers,
            autoReplies: [
                "Thanks! I'm back on route now.",
                "Let me know if you need to run another odometer scan later.",
                "Awesome! Brakes feel highly responsive now."
            ]
        ),
        CommunicationChannel(
            senderName: "Fleet Manager",
            textPreview: "Check overdue maintenance tasks",
            timestamp: "10m ago",
            unreadCount: 2,
            initials: "FM",
            avatarColor: AppTheme.Brand.violet,
            category: .managers,
            autoReplies: [
                "Please prioritize the brakes repair on Truck 12.",
                "Diagnostics received. Ensure the checklist is completed by Thursday.",
                "Great! I will authorize the procurement budget right away."
            ]
        ),
        CommunicationChannel(
            senderName: "Mechanic Raj",
            textPreview: "Spark plugs catalog updated in inventory",
            timestamp: "1h ago",
            unreadCount: 0,
            initials: "MR",
            avatarColor: AppTheme.Brand.teal,
            category: .maintenance,
            autoReplies: [
                "Perfect! We got the spark plugs stored in Bin B.",
                "Caliper inventory is also checked and accounted for.",
                "I've placed the diagnostic scanner back on the charger."
            ]
        ),
        CommunicationChannel(
            senderName: "Driver David",
            textPreview: "Slight squealing noise detected on Van 05",
            timestamp: "2h ago",
            unreadCount: 0,
            initials: "DD",
            avatarColor: AppTheme.Brand.violet,
            category: .drivers,
            autoReplies: [
                "I'll bring the van into Service Bay 2 after my shift.",
                "Notes logged. Thanks for checking it so quickly.",
                "Yes, standard fluid check was successfully logged too."
            ]
        )
    ]

    // Filtered channels list
    private var filteredChannels: [CommunicationChannel] {
        channels.filter { channel in
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
                            ForEach(filteredChannels.indices, id: \.self) { idx in
                                NavigationLink(destination: ChatDetailView(channel: binding(for: filteredChannels[idx]))) {
                                    CommunicationRow(channel: filteredChannels[idx])
                                }
                                .buttonStyle(PlainButtonStyle())

                                if idx < filteredChannels.count - 1 {
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
    }

    // Dynamic Binding Helper for array indexing
    private func binding(for channel: CommunicationChannel) -> Binding<CommunicationChannel> {
        guard let index = channels.firstIndex(where: { $0.id == channel.id }) else {
            fatalError("Channel not found")
        }
        return $channels[index]
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
