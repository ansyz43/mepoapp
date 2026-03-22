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
            VStack(spacing: 0) {
                // Platform filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("All", isSelected: selectedPlatform == nil) {
                            selectedPlatform = nil
                            Task { await loadContacts() }
                        }
                        filterChip("Instagram", isSelected: selectedPlatform == "instagram") {
                            selectedPlatform = "instagram"
                            Task { await loadContacts() }
                        }
                        filterChip("Messenger", isSelected: selectedPlatform == "facebook_messenger") {
                            selectedPlatform = "facebook_messenger"
                            Task { await loadContacts() }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Total count
                HStack {
                    Text("\(total) contacts")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal)
                
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
                    List {
                        ForEach(contacts) { contact in
                            contactRow(contact)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(Theme.inputBg)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
            AvatarView(url: contact.profilePicUrl, size: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    PlatformBadge(platform: contact.platform)
                }
                
                if let username = contact.channelUsername {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(contact.messageCount) msgs")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                
                if let date = contact.lastMessageAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
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
