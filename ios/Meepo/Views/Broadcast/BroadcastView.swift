import SwiftUI
import PhotosUI

struct BroadcastView: View {
    @State private var broadcasts: [BroadcastResponse] = []
    @State private var isLoading = true
    @State private var showCompose = false
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView().tint(Theme.emerald)
                    Spacer()
                } else if broadcasts.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "megaphone",
                        title: "No Broadcasts",
                        message: "Send your first broadcast to reach all your contacts"
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(broadcasts) { broadcast in
                            broadcastRow(broadcast)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(Theme.inputBg)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("Broadcasts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.emerald)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusBadge(status: broadcast.status)
                    Spacer()
                    Text(broadcast.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Text(broadcast.messageText)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3)
                
                HStack(spacing: 16) {
                    statLabel("Eligible", value: "\(broadcast.eligibleContacts)")
                    statLabel("Sent", value: "\(broadcast.sentCount)")
                    statLabel("Failed", value: "\(broadcast.failedCount)")
                }
            }
        }
    }
    
    private func statLabel(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
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
            ScrollView {
                VStack(spacing: 20) {
                    // Channel selector
                    if let status = channelStatus {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select Channel")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                ForEach(status.all) { channel in
                                    Button {
                                        selectedChannelId = channel.id
                                    } label: {
                                        HStack {
                                            Image(systemName: channel.platformIcon)
                                                .foregroundColor(Theme.emerald)
                                            Text(channel.channelName ?? channel.platformDisplayName)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if selectedChannelId == channel.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Theme.emerald)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Message
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Message")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        TextEditor(text: $messageText)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Theme.inputBg)
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                    }
                    
                    // Image
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: imageData != nil ? "photo.fill" : "photo")
                            Text(imageData != nil ? "Change Image" : "Attach Image (optional)")
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.inputBg)
                        .foregroundColor(Theme.emerald)
                        .cornerRadius(10)
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
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
