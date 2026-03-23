import SwiftUI

struct ContactsView: View {
    @State private var contacts: [ContactResponse] = []
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
                                Task { await loadContacts() }
                            }
                            filterChip("Instagram", isSelected: selectedPlatform == "instagram", color: Theme.instagram) {
                                selectedPlatform = "instagram"
                                Task { await loadContacts() }
                            }
                            filterChip("Messenger", isSelected: selectedPlatform == "facebook_messenger", color: Theme.messenger) {
                                selectedPlatform = "facebook_messenger"
                                Task { await loadContacts() }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }

                    // Total count
                    HStack {
                        Text("\(total) contacts")
                            .font(.caption)
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(Theme.emerald)
                        Spacer()
                    } else if contacts.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "person.2",
                            title: "No Contacts",
                            message: "Contacts will appear when people message your channel"
                        )
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 4) {
                                ForEach(contacts) { contact in
                                    contactRow(contact)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Search contacts")
            .onChange(of: searchText) { _, _ in
                Task { await loadContacts() }
            }
            .refreshable { await loadContacts() }
            .task { await loadContacts() }
        }
    }

    private func contactRow(_ contact: ContactResponse) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: contact.profilePicUrl, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    PlatformBadge(platform: contact.platform)
                }

                if let username = contact.channelUsername {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(Theme.textTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(contact.messageCount) msgs")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textSecondary)

                if let date = contact.lastMessageAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    private func filterChip(_ title: String, isSelected: Bool, color: Color = Theme.emerald, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isSelected ? color.opacity(0.15) : Theme.cardBg)
                .foregroundColor(isSelected ? color : Theme.textSecondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private func loadContacts() async {
        isLoading = contacts.isEmpty
        do {
            let response = try await api.getContacts(
                platform: selectedPlatform,
                search: searchText.isEmpty ? nil : searchText
            )
            contacts = response.contacts
            total = response.total
        } catch { }
        isLoading = false
    }
}
