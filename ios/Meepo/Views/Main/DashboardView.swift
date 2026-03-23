import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var channelStatus: ChannelStatusResponse?
    @State private var isLoading = true

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Welcome header
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back,")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textTertiary)
                                Text(auth.profile?.name ?? "User")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Theme.emerald.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.accentGradient)
                            }
                        }
                        .padding(.top, 8)

                        // Setup Progress
                        if !auth.hasChannel {
                            setupCard
                        }

                        // Stats
                        if let status = channelStatus, status.hasAny {
                            statsSection(status)
                        }

                        // Quick Actions
                        quickActionsSection

                        // Channels Overview
                        if let status = channelStatus, status.hasAny {
                            channelsOverview(status)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }

    private var setupCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.emerald.opacity(0.1))
                        .frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.accentGradient)
                }
                Text("Get Started")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Connect your Instagram or Messenger\nto start using AI assistant")
                    .font(.subheadline)
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)

                NavigationLink(destination: ChannelView()) {
                    Text("Connect Channel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accentGradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Theme.emerald.opacity(0.3), radius: 8, y: 3)
                }
            }
        }
    }

    private func statsSection(_ status: ChannelStatusResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Channels",
                value: "\(status.all.count)",
                icon: "antenna.radiowaves.left.and.right"
            )
            StatCard(
                title: "Status",
                value: status.all.allSatisfy({ $0.isActive }) ? "Active" : "Mixed",
                icon: "circle.fill",
                accentColor: status.all.allSatisfy({ $0.isActive }) ? .green : .orange
            )
        }
    }

    private var quickActionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Quick Actions")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if auth.hasChannel {
                        quickAction(icon: "bubble.left.and.bubble.right", title: "Chats", color: Theme.messenger, destination: AnyView(ConversationsView()))
                        quickAction(icon: "megaphone.fill", title: "Broadcast", color: .orange, destination: AnyView(BroadcastView()))
                    }
                    quickAction(icon: "storefront.fill", title: "Catalog", color: .purple, destination: AnyView(CatalogView()))
                    quickAction(icon: "person.2.fill", title: "Partners", color: Theme.emerald, destination: AnyView(PartnerView()))
                }
            }
        }
    }

    private func quickAction(icon: String, title: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.cardBgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func channelsOverview(_ status: ChannelStatusResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Your Channels")

                ForEach(status.all) { channel in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(channel.platform == "instagram" ? Theme.instagram.opacity(0.12) : Theme.messenger.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: channel.platformIcon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(channel.platform == "instagram" ? Theme.instagram : Theme.messenger)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.channelName ?? channel.platformDisplayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text(channel.assistantName)
                                .font(.caption)
                                .foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                        StatusBadge(status: channel.webhookStatus)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            channelStatus = try await api.getChannelStatus()
            await auth.refreshProfile()
        } catch { }
        isLoading = false
    }
}
