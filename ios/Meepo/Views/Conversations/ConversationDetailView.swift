import SwiftUI

struct ConversationDetailView: View {
    let contactId: Int
    
    @State private var detail: ConversationDetailResponse?
    @State private var isLoading = true
    
    private let api = APIClient.shared
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView().tint(Theme.emerald)
                Spacer()
            } else if let detail = detail {
                // Contact header
                HStack(spacing: 12) {
                    AvatarView(url: detail.contact.profilePicUrl, size: 36)
                    VStack(alignment: .leading) {
                        Text(detail.contact.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        if let username = detail.contact.channelUsername {
                            Text("@\(username)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    PlatformBadge(platform: detail.contact.platform)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(detail.messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onAppear {
                        if let lastId = detail.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                
                // Info bar
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.textSecondary)
                    Text("Messages are handled by AI assistant")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .background(Theme.darkBg.ignoresSafeArea())
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadConversation() }
    }
    
    private func messageBubble(_ message: MessageResponse) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isUser ? Color.blue.opacity(0.3) : Theme.cardBg)
                    .cornerRadius(16)
                
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func loadConversation() async {
        isLoading = true
        do {
            detail = try await api.getConversation(contactId: contactId)
        } catch { }
        isLoading = false
    }
}
