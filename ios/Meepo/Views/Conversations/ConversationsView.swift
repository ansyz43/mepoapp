import SwiftUI

struct ConversationsView: View {
    @State private var conversations: [ConversationPreview] = []
    @State private var total = 0
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedPlatform: String?
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Platform filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", isSelected: selectedPlatform == nil) {
                            selectedPlatform = nil
                            Task { await loadConversations() }
                        }
                        filterChip("Instagram", isSelected: selectedPlatform == "instagram") {
                            selectedPlatform = "instagram"
                            Task { await loadConversations() }
                        }
                        filterChip("Messenger", isSelected: selectedPlatform == "facebook_messenger") {
                            selectedPlatform = "facebook_messenger"
                            Task { await loadConversations() }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.emerald)
                    Spacer()
                } else if conversations.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No Conversations",
                        message: "Conversations will appear when your contacts message you"
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(conversations) { conv in
                            NavigationLink(destination: ConversationDetailView(contactId: conv.contactId)) {
                                conversationRow(conv)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Theme.inputBg)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("Conversations")
            .searchable(text: $searchText, prompt: "Search conversations")
            .onChange(of: searchText) { _, _ in
                Task { await loadConversations() }
            }
            .refreshable { await loadConversations() }
            .task { await loadConversations() }
        }
    }
    
    private func conversationRow(_ conv: ConversationPreview) -> some View {
        HStack(spacing: 12) {
            AvatarView(size: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conv.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    PlatformBadge(platform: conv.platform)
                }
                
                if let lastMsg = conv.lastMessage {
                    Text(lastMsg)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let date = conv.lastMessageAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Text("\(conv.messageCount)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.emerald.opacity(0.3))
                    .foregroundColor(Theme.emerald)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.emerald : Theme.inputBg)
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .cornerRadius(20)
        }
    }
    
    private func loadConversations() async {
        isLoading = conversations.isEmpty
        do {
            let response = try await api.getConversations(
                platform: selectedPlatform,
                search: searchText.isEmpty ? nil : searchText
            )
            conversations = response.conversations
            total = response.total
        } catch { }
        isLoading = false
    }
}
