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
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isLoading {
                            ProgressView()
                                .tint(Theme.emerald)
                                .padding(60)
                        } else if let status = channelStatus {
                            // Instagram
                            channelCard(
                                platform: "Instagram",
                                icon: "camera.fill",
                                color: Theme.instagram,
                                channel: status.instagram,
                                connectAction: { showConnectIG = true }
                            )

                            // Messenger
                            channelCard(
                                platform: "Messenger",
                                icon: "message.fill",
                                color: Theme.messenger,
                                channel: status.messenger,
                                connectAction: { showConnectFB = true }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
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

    private func channelCard(platform: String, icon: String, color: Color, channel: ChannelResponse?, connectAction: @escaping () -> Void) -> some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(platform)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                        Text(channel != nil ? "Connected" : "Not connected")
                            .font(.caption)
                            .foregroundColor(channel != nil ? Theme.emerald : Theme.textTertiary)
                    }
                    Spacer()
                    if let ch = channel {
                        StatusBadge(status: ch.webhookStatus)
                    }
                }

                if let channel = channel {
                    VStack(spacing: 8) {
                        infoRow("Name", value: channel.channelName ?? "-")
                        infoRow("Assistant", value: channel.assistantName)
                        if let link = channel.sellerLink {
                            infoRow("Link", value: link)
                        }
                        infoRow("Partners", value: channel.allowPartners ? "Enabled" : "Disabled")
                    }
                    .padding(.vertical, 4)

                    Button {
                        selectedChannel = channel
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                                .font(.subheadline)
                            Text("Settings")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.cardBgElevated)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("Connect your \(platform) account")
                            .font(.subheadline)
                            .foregroundColor(Theme.textTertiary)

                        Button(action: connectAction) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Connect \(platform)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: color.opacity(0.3), radius: 8, y: 3)
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
                .foregroundColor(Theme.textTertiary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func loadChannels() async {
        isLoading = true
        do {
            channelStatus = try await api.getChannelStatus()
        } catch { }
        isLoading = false
    }
}
