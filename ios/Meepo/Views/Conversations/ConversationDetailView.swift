import SwiftUI

struct ConversationDetailView: View {
    let contactId: Int

    @State private var detail: ConversationDetailResponse?
    @State private var isLoading = true

    private let api = APIClient.shared

    var body: some View {
        ZStack {
            MeshBackground()

            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.emerald)
                    Spacer()
                } else if let detail = detail {
                    // Contact header
                    HStack(spacing: 12) {
                        AvatarView(url: detail.contact.profilePicUrl, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(detail.contact.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            if let username = detail.contact.channelUsername {
                                Text("@\(username)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        Spacer()
                        PlatformBadge(platform: detail.contact.platform)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.cardBg.opacity(0.8))

                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 6) {
                                ForEach(detail.messages) { message in
                                    messageBubble(message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onAppear {
                            if let lastId = detail.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }

                    // Info bar
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(Theme.emerald)
                        Text("Messages are handled by AI assistant")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Theme.cardBg.opacity(0.8))
                }
            }
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadConversation() }
    }

    private func messageBubble(_ message: MessageResponse) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser
                            ? AnyShapeStyle(Theme.accentGradient)
                            : AnyShapeStyle(Theme.cardBgElevated)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                Text(message.createdAt, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 50) }
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
