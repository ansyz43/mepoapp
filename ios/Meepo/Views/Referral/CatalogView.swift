import SwiftUI

struct CatalogView: View {
    @State private var channels: [ChannelCatalogItem] = []
    @State private var isLoading = true
    @State private var showPartnerForm: ChannelCatalogItem?
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.emerald)
                    Spacer()
                } else if channels.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "storefront",
                        title: "No Channels Available",
                        message: "Channels allowing partners will appear here"
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(channels) { channel in
                                catalogCard(channel)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
            GlassCard {
                VStack(spacing: 10) {
                    AvatarView(url: channel.avatarUrl, size: 56, fallbackIcon: "antenna.radiowaves.left.and.right")
                    
                    Text(channel.channelName ?? channel.assistantName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text("Become Partner")
                        .font(.caption)
                        .foregroundColor(Theme.emerald)
                }
            }
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
            ScrollView {
                VStack(spacing: 24) {
                    // Channel info
                    GlassCard {
                        VStack(spacing: 12) {
                            AvatarView(url: channel.avatarUrl, size: 64, fallbackIcon: "antenna.radiowaves.left.and.right")
                            Text(channel.channelName ?? channel.assistantName)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
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
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
