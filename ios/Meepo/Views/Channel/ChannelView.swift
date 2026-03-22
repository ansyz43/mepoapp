import SwiftUI

struct ChannelView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var channelStatus: ChannelStatusResponse?
    @State private var isLoading = true
    @State private var showConnectIG = false
    @State private var showConnectFB = false
    @State private var selectedChannel: ChannelResponse?
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView()
                            .tint(Theme.emerald)
                            .padding(60)
                    } else if let status = channelStatus {
                        // Instagram
                        channelCard(
                            platform: "Instagram",
                            icon: "camera",
                            channel: status.instagram,
                            connectAction: { showConnectIG = true }
                        )
                        
                        // Messenger
                        channelCard(
                            platform: "Messenger",
                            icon: "message",
                            channel: status.messenger,
                            connectAction: { showConnectFB = true }
                        )
                    }
                }
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("Channels")
            .refreshable { await loadChannels() }
            .task { await loadChannels() }
            .sheet(isPresented: $showConnectIG) {
                ConnectChannelView(platform: "instagram") {
                    await loadChannels()
                    await auth.refreshProfile()
                }
            }
            .sheet(isPresented: $showConnectFB) {
                ConnectChannelView(platform: "facebook_messenger") {
                    await loadChannels()
                    await auth.refreshProfile()
                }
            }
            .sheet(item: $selectedChannel) { channel in
                ChannelSettingsView(channel: channel) {
                    await loadChannels()
                }
            }
        }
    }
    
    private func channelCard(platform: String, icon: String, channel: ChannelResponse?, connectAction: @escaping () -> Void) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(Theme.emerald)
                    Text(platform)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let ch = channel {
                        StatusBadge(status: ch.webhookStatus)
                    }
                }
                
                if let channel = channel {
                    VStack(spacing: 10) {
                        infoRow("Name", value: channel.channelName ?? "-")
                        infoRow("Assistant", value: channel.assistantName)
                        if let link = channel.sellerLink {
                            infoRow("Link", value: link)
                        }
                        infoRow("Partners", value: channel.allowPartners ? "Enabled" : "Disabled")
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            selectedChannel = channel
                        } label: {
                            HStack {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Theme.inputBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Not connected")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        PrimaryButton("Connect \(platform)") {
                            connectAction()
                        }
                    }
                }
            }
        }
    }
    
    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
    
    private func loadChannels() async {
        isLoading = true
        do {
            channelStatus = try await api.getChannelStatus()
        } catch { }
        isLoading = false
    }
}
