import SwiftUI

struct CatalogView: View {
    @State private var channels: [ChannelCatalogItem] = []
    @State private var isLoading = true
    @State private var showPartnerForm: ChannelCatalogItem?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                if isLoading {
                    ProgressView().tint(Theme.emerald)
                } else if channels.isEmpty {
                    EmptyStateView(
                        icon: "storefront",
                        title: "No Channels Available",
                        message: "Channels allowing partners will appear here"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(channels) { channel in
                                catalogCard(channel)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Catalog")
            .refreshable { await loadCatalog() }
            .task { await loadCatalog() }
            .sheet(item: $showPartnerForm) { channel in
                BecomePartnerView(channel: channel) {
                    await loadCatalog()
                }
            }
        }
    }

    private func catalogCard(_ channel: ChannelCatalogItem) -> some View {
        Button {
            showPartnerForm = channel
        } label: {
            VStack(spacing: 12) {
                AvatarView(url: channel.avatarUrl, size: 56, fallbackIcon: "antenna.radiowaves.left.and.right")

                Text(channel.channelName ?? channel.assistantName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("Become Partner")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.emerald)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background(Theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
    }

    private func loadCatalog() async {
        isLoading = channels.isEmpty
        do {
            channels = try await api.getCatalog()
        } catch { }
        isLoading = false
    }
}

// MARK: - Become Partner

struct BecomePartnerView: View {
    @Environment(\.dismiss) var dismiss
    let channel: ChannelCatalogItem
    let onDone: () async -> Void

    @State private var sellerLink = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Channel info
                        GlassCard {
                            VStack(spacing: 14) {
                                AvatarView(url: channel.avatarUrl, size: 64, fallbackIcon: "antenna.radiowaves.left.and.right")
                                Text(channel.channelName ?? channel.assistantName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        GlassCard {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Your Seller Link *")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    StyledTextField(placeholder: "https://yourstore.com", text: $sellerLink, keyboardType: .URL)
                                }

                                if let error = errorMessage {
                                    ErrorBanner(message: error)
                                }

                                PrimaryButton("Become Partner", isLoading: isLoading) {
                                    submitPartner()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Partner Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private func submitPartner() {
        guard !sellerLink.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Seller link is required"
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let _ = try await api.becomePartner(ReferralPartnerCreate(
                    channelId: channel.id,
                    sellerLink: sellerLink
                ))
                await onDone()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
