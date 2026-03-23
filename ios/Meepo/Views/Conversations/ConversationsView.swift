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
            ZStack {
                MeshBackground()

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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
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
                                .listRowSeparatorTint(Color.white.opacity(0.04))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
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
        HStack(spacing: 14) {
            AvatarView(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(conv.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    PlatformBadge(platform: conv.platform)
                }

                if let lastMsg = conv.lastMessage {
                    Text(lastMsg)
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let date = conv.lastMessageAt {
                    Text(date, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }

                Text("\(conv.messageCount)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.emerald.opacity(0.2))
                    .foregroundColor(Theme.emeraldLight)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isSelected ? Theme.emerald : Theme.cardBgElevated)
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
                )
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
