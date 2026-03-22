import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var channelStatus: ChannelStatusResponse?
    @State private var isLoading = true
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome back,")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                Text(auth.profile?.name ?? "User")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title)
                                .foregroundColor(Theme.emerald)
                        }
                    }
                    
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
                    if let status = channelStatus {
                        channelsOverview(status)
                    }
                }
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("Dashboard")
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }
    
    private var setupCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(Theme.emerald)
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Connect your Instagram or Messenger to start using AI assistant")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                
                NavigationLink(destination: ChannelView()) {
                    Text("Connect Channel")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.emerald)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func statsSection(_ status: ChannelStatusResponse) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(title: "Channels", value: "\(status.all.count)", icon: "antenna.radiowaves.left.and.right")
            StatCard(title: "Status", value: status.all.allSatisfy({ $0.isActive }) ? "Active" : "Mixed", icon: "circle.fill")
        }
    }
    
    private var quickActionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Actions")
                    .font(.headline)
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if auth.hasChannel {
                        quickAction(icon: "bubble.left.and.bubble.right", title: "Chats", destination: AnyView(ConversationsView()))
                        quickAction(icon: "megaphone", title: "Broadcast", destination: AnyView(BroadcastView()))
                    }
                    quickAction(icon: "storefront", title: "Catalog", destination: AnyView(CatalogView()))
                    quickAction(icon: "person.2", title: "Partners", destination: AnyView(PartnerView()))
                }
            }
        }
    }
    
    private func quickAction(icon: String, title: String, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(Theme.emerald)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.inputBg)
            .cornerRadius(10)
        }
    }
    
    private func channelsOverview(_ status: ChannelStatusResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Channels")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ForEach(status.all) { channel in
                    HStack {
                        Image(systemName: channel.platformIcon)
                            .foregroundColor(Theme.emerald)
                        VStack(alignment: .leading) {
                            Text(channel.channelName ?? channel.platformDisplayName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text(channel.assistantName)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        StatusBadge(status: channel.webhookStatus)
                    }
                    .padding(.vertical, 4)
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
