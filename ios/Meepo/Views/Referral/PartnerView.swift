import SwiftUI

struct PartnerView: View {
    @State private var partners: [ReferralPartnerResponse] = []
    @State private var isLoading = true
    @State private var selectedPartner: ReferralPartnerResponse?
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.emerald)
                    Spacer()
                } else if partners.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "person.2.badge.gearshape",
                        title: "No Partnerships",
                        message: "Join a channel from the Catalog to become a partner"
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(partners) { partner in
                            partnerRow(partner)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(Theme.inputBg)
                                .onTapGesture {
                                    selectedPartner = partner
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(partner.channelName ?? partner.assistantName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Spacer()
                    StatusBadge(status: partner.isActive ? "active" : "inactive")
                }
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Credits")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Text("\(partner.credits)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ref Code")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Text(partner.refCode)
                            .font(.subheadline)
                            .foregroundColor(Theme.emerald)
                    }
                }
                
                // Copy link
                Button {
                    UIPasteboard.general.string = partner.refLink
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Referral Link")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.emerald)
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
    
    private let api = APIClient.shared
    
    init(partner: ReferralPartnerResponse, onUpdate: @escaping () async -> Void) {
        self.partner = partner
        self.onUpdate = onUpdate
        _sellerLink = State(initialValue: partner.sellerLink)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info card
                    GlassCard {
                        VStack(spacing: 12) {
                            Text(partner.channelName ?? partner.assistantName)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 20) {
                                statItem("Credits", "\(partner.credits)")
                                statItem("Ref Code", partner.refCode)
                            }
                            
                            Button {
                                UIPasteboard.general.string = partner.refLink
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Link")
                                }
                                .font(.subheadline)
                                .foregroundColor(Theme.emerald)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Theme.inputBg)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Update link
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Seller Link")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        HStack {
                            StyledTextField(placeholder: "https://yourstore.com", text: $sellerLink, keyboardType: .URL)
                            Button {
                                updateLink()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.emerald)
                            }
                        }
                    }
                    
                    if let error = errorMessage {
                        ErrorBanner(message: error)
                    }
                    
                    // Sessions
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sessions (\(sessions.count))")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if sessions.isEmpty {
                                Text("No sessions yet")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                            } else {
                                ForEach(sessions) { session in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(session.firstName ?? session.channelUsername ?? "User")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Text(session.startedAt, style: .date)
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        StatusBadge(status: session.isActive ? "active" : "expired")
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.emerald)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
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
