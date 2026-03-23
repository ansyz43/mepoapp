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
            ZStack {
                MeshBackground()

                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 8) {
                        tabButton("Stats", icon: "chart.bar.fill", tag: 0)
                        tabButton("Users", icon: "person.2.fill", tag: 1)
                        tabButton("Channels", icon: "antenna.radiowaves.left.and.right", tag: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    if isLoading {
                        Spacer()
                        ProgressView().tint(Theme.emerald)
                        Spacer()
                    } else {
                        switch selectedTab {
                        case 0: statsTab
                        case 1: usersTab
                        case 2: channelsTab
                        default: EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("Admin")
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }

    private func tabButton(_ title: String, icon: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tag }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(selectedTab == tag ? Theme.emerald.opacity(0.15) : Theme.cardBg)
            .foregroundColor(selectedTab == tag ? Theme.emerald : Theme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selectedTab == tag ? Theme.emerald.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 1)
            )
        }
    }

    // MARK: - Stats Tab

    private var statsTab: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let s = stats {
                    StatCard(title: "Total Users", value: "\(s.totalUsers)", icon: "person.2")
                    StatCard(title: "Active Channels", value: "\(s.activeChannels)", icon: "antenna.radiowaves.left.and.right")
                    StatCard(title: "Total Contacts", value: "\(s.totalContacts)", icon: "person.crop.rectangle.stack")
                    StatCard(title: "Total Messages", value: "\(s.totalMessages)", icon: "bubble.left.and.bubble.right")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Users Tab

    private var usersTab: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(users) { user in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(user.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                if user.isAdmin {
                                    Text("ADMIN")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.emerald.opacity(0.15))
                                        .foregroundColor(Theme.emerald)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            Text("\(user.channelsCount) channels • Joined \(user.createdAt, style: .date)")
                                .font(.caption2)
                                .foregroundColor(Theme.textTertiary)
                        }

                        Spacer()

                        Button {
                            toggleUser(user.id)
                        } label: {
                            Image(systemName: user.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(user.isActive ? Theme.emerald : .red)
                        }
                    }
                    .padding(14)
                    .background(Theme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Channels Tab

    private var channelsTab: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(channels) { channel in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            PlatformBadge(platform: channel.platform)
                            Text(channel.channelName ?? channel.assistantName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
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
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .padding(14)
                    .background(Theme.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
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
