import SwiftUI
import PhotosUI

struct BroadcastView: View {
    @State private var broadcasts: [BroadcastResponse] = []
    @State private var isLoading = true
    @State private var showCompose = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                if isLoading {
                    ProgressView().tint(Theme.emerald)
                } else if broadcasts.isEmpty {
                    EmptyStateView(
                        icon: "megaphone",
                        title: "No Broadcasts",
                        message: "Send your first broadcast to reach all your contacts"
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(broadcasts) { broadcast in
                                broadcastRow(broadcast)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Broadcasts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.accentGradient)
                    }
                }
            }
            .sheet(isPresented: $showCompose) {
                ComposeBroadcastView {
                    await loadBroadcasts()
                }
            }
            .refreshable { await loadBroadcasts() }
            .task { await loadBroadcasts() }
        }
    }

    private func broadcastRow(_ broadcast: BroadcastResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusBadge(status: broadcast.status)
                    Spacer()
                    Text(broadcast.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.textTertiary)
                }

                Text(broadcast.messageText)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3)

                HStack(spacing: 0) {
                    statPill("Eligible", value: "\(broadcast.eligibleContacts)", color: .blue)
                    Spacer()
                    statPill("Sent", value: "\(broadcast.sentCount)", color: Theme.emerald)
                    Spacer()
                    statPill("Failed", value: "\(broadcast.failedCount)", color: broadcast.failedCount > 0 ? .red : Theme.textTertiary)
                }
            }
        }
    }

    private func statPill(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadBroadcasts() async {
        isLoading = broadcasts.isEmpty
        do {
            broadcasts = try await api.getBroadcasts()
        } catch { }
        isLoading = false
    }
}

// MARK: - Compose Broadcast

struct ComposeBroadcastView: View {
    @Environment(\.dismiss) var dismiss
    let onSend: () async -> Void

    @State private var messageText = ""
    @State private var channelStatus: ChannelStatusResponse?
    @State private var selectedChannelId: Int?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Channel selector
                        if let status = channelStatus {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: "Select Channel")

                                    ForEach(status.all) { channel in
                                        Button {
                                            selectedChannelId = channel.id
                                        } label: {
                                            HStack(spacing: 12) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(channelColor(channel).opacity(0.12))
                                                        .frame(width: 32, height: 32)
                                                    Image(systemName: channel.platformIcon)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(channelColor(channel))
                                                }
                                                Text(channel.channelName ?? channel.platformDisplayName)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                if selectedChannelId == channel.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Theme.accentGradient)
                                                }
                                            }
                                            .padding(.vertical, 6)
                                        }
                                    }
                                }
                            }
                        }

                        // Message
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Message")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                TextEditor(text: $messageText)
                                    .frame(minHeight: 120)
                                    .padding(10)
                                    .background(Theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                            }
                        }

                        // Image
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: imageData != nil ? "photo.fill" : "photo")
                                Text(imageData != nil ? "Change Image" : "Attach Image (optional)")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.cardBg)
                            .foregroundColor(Theme.emerald)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Theme.emerald.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                imageData = try? await newItem?.loadTransferable(type: Data.self)
                            }
                        }

                        if let error = errorMessage {
                            ErrorBanner(message: error)
                        }

                        PrimaryButton("Send Broadcast", isLoading: isLoading) {
                            sendBroadcast()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("New Broadcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .task {
                do {
                    channelStatus = try await api.getChannelStatus()
                    selectedChannelId = channelStatus?.all.first?.id
                } catch { }
            }
        }
    }

    private func channelColor(_ channel: ChannelResponse) -> Color {
        channel.platform == "instagram" ? Theme.instagram : Theme.messenger
    }

    private func sendBroadcast() {
        guard let channelId = selectedChannelId else {
            errorMessage = "Please select a channel"
            return
        }
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a message"
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                let _ = try await api.createBroadcast(
                    messageText: messageText.trimmingCharacters(in: .whitespaces),
                    imageData: imageData
                )
                await onSend()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
