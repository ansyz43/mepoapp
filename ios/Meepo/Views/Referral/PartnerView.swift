import SwiftUI

struct PartnerView: View {
    @State private var partners: [ReferralPartnerResponse] = []
    @State private var isLoading = true
    @State private var selectedPartner: ReferralPartnerResponse?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                if isLoading {
                    ProgressView().tint(Theme.emerald)
                } else if partners.isEmpty {
                    EmptyStateView(
                        icon: "person.2.badge.gearshape",
                        title: "No Partnerships",
                        message: "Join a channel from the Catalog to become a partner"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(partners) { partner in
                                partnerRow(partner)
                                    .onTapGesture { selectedPartner = partner }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("My Partners")
            .refreshable { await loadPartners() }
            .task { await loadPartners() }
            .sheet(item: $selectedPartner) { partner in
                PartnerDetailView(partner: partner) {
                    await loadPartners()
                }
            }
        }
    }

    private func partnerRow(_ partner: ReferralPartnerResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(partner.channelName ?? partner.assistantName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    StatusBadge(status: partner.isActive ? "active" : "inactive")
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Credits")
                            .font(.caption2)
                            .foregroundColor(Theme.textTertiary)
                        Text("\(partner.credits)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ref Code")
                            .font(.caption2)
                            .foregroundColor(Theme.textTertiary)
                        Text(partner.refCode)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.emerald)
                    }
                }

                Button {
                    UIPasteboard.general.string = partner.refLink
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                        Text("Copy Referral Link")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.emerald.opacity(0.12))
                    .foregroundColor(Theme.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func loadPartners() async {
        isLoading = partners.isEmpty
        do {
            partners = try await api.getMyPartners()
        } catch { }
        isLoading = false
    }
}

// MARK: - Partner Detail

struct PartnerDetailView: View {
    @Environment(\.dismiss) var dismiss
    let partner: ReferralPartnerResponse
    let onUpdate: () async -> Void

    @State private var sessions: [ReferralSessionResponse] = []
    @State private var sellerLink: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var copiedLink = false

    private let api = APIClient.shared

    init(partner: ReferralPartnerResponse, onUpdate: @escaping () async -> Void) {
        self.partner = partner
        self.onUpdate = onUpdate
        _sellerLink = State(initialValue: partner.sellerLink)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Info card
                        GlassCard {
                            VStack(spacing: 14) {
                                Text(partner.channelName ?? partner.assistantName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                HStack(spacing: 24) {
                                    statItem("Credits", "\(partner.credits)")
                                    statItem("Ref Code", partner.refCode)
                                }

                                Button {
                                    UIPasteboard.general.string = partner.refLink
                                    copiedLink = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedLink = false }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: copiedLink ? "checkmark" : "doc.on.doc")
                                            .font(.subheadline)
                                        Text(copiedLink ? "Copied!" : "Copy Link")
                                            .fontWeight(.medium)
                                    }
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Theme.emerald.opacity(0.12))
                                    .foregroundColor(Theme.emerald)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                        }

                        // Update link
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Seller Link")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                HStack(spacing: 10) {
                                    StyledTextField(placeholder: "https://yourstore.com", text: $sellerLink, keyboardType: .URL)
                                    Button {
                                        updateLink()
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Theme.accentGradient)
                                    }
                                }
                            }
                        }

                        if let error = errorMessage {
                            ErrorBanner(message: error)
                        }

                        // Sessions
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Sessions (\(sessions.count))")

                                if sessions.isEmpty {
                                    Text("No sessions yet")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textTertiary)
                                } else {
                                    ForEach(sessions) { session in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(session.firstName ?? session.channelUsername ?? "User")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                Text(session.startedAt, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textTertiary)
                                            }
                                            Spacer()
                                            StatusBadge(status: session.isActive ? "active" : "expired")
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Partner Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .task { await loadSessions() }
        }
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accentGradient)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func loadSessions() async {
        do {
            sessions = try await api.getPartnerSessions(partnerId: partner.id)
        } catch { }
    }

    private func updateLink() {
        guard !sellerLink.isEmpty else { return }
        errorMessage = nil
        Task {
            do {
                let _ = try await api.updatePartner(sellerLink: sellerLink)
                await onUpdate()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
