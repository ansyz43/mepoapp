import SwiftUI

struct AdminView: View {
    @State private var stats: AdminStatsResponse?
    @State private var users: [AdminUserResponse] = []
    @State private var channels: [AdminChannelResponse] = []
    @State private var selectedTab = 0
    @State private var isLoading = true
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("Stats").tag(0)
                    Text("Users").tag(1)
                    Text("Channels").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.emerald)
                    Spacer()
                } else {
                    switch selectedTab {
                    case 0:
                        statsTab
                    case 1:
                        usersTab
                    case 2:
                        channelsTab
                    default:
                        EmptyView()
                    }
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("Admin")
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }
    
    // MARK: - Stats Tab
    
    private var statsTab: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let s = stats {
                    StatCard(title: "Total Users", value: "\(s.totalUsers)", icon: "person.2")
                    StatCard(title: "Active Channels", value: "\(s.activeChannels)", icon: "antenna.radiowaves.left.and.right")
                    StatCard(title: "Total Contacts", value: "\(s.totalContacts)", icon: "person.crop.rectangle.stack")
                    StatCard(title: "Total Messages", value: "\(s.totalMessages)", icon: "bubble.left.and.bubble.right")
                }
            }
            .padding()
        }
    }
    
    // MARK: - Users Tab
    
    private var usersTab: some View {
        List {
            ForEach(users) { user in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(user.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            if user.isAdmin {
                                Text("ADMIN")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.emerald.opacity(0.3))
                                    .foregroundColor(Theme.emerald)
                                    .cornerRadius(4)
                            }
                        }
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(user.channelsCount) channels • Joined \(user.createdAt, style: .date)")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        toggleUser(user.id)
                    } label: {
                        Image(systemName: user.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(user.isActive ? .green : .red)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.inputBg)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Channels Tab
    
    private var channelsTab: some View {
        List {
            ForEach(channels) { channel in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        PlatformBadge(platform: channel.platform)
                        Text(channel.channelName ?? channel.assistantName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                        StatusBadge(status: channel.webhookStatus)
                    }
                    
                    HStack {
                        if let owner = channel.ownerName {
                            Text("Owner: \(owner)")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Text("\(channel.contactsCount) contacts")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Theme.inputBg)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func toggleUser(_ userId: Int) {
        Task {
            do {
                let updated = try await api.toggleUserActive(userId: userId)
                if let idx = users.firstIndex(where: { $0.id == userId }) {
                    users[idx] = updated
                }
            } catch { }
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            async let s = api.getAdminStats()
            async let u = api.getAdminUsers()
            async let c = api.getAdminChannels()
            stats = try await s
            users = try await u
            channels = try await c
        } catch { }
        isLoading = false
    }
}
