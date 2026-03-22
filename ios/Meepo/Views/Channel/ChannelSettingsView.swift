import SwiftUI
import PhotosUI

struct ChannelSettingsView: View {
    @Environment(\.dismiss) var dismiss
    let channel: ChannelResponse
    let onSave: () async -> Void
    
    @State private var assistantName: String
    @State private var sellerLink: String
    @State private var greetingMessage: String
    @State private var botDescription: String
    @State private var allowPartners: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    private let api = APIClient.shared
    
    init(channel: ChannelResponse, onSave: @escaping () async -> Void) {
        self.channel = channel
        self.onSave = onSave
        _assistantName = State(initialValue: channel.assistantName)
        _sellerLink = State(initialValue: channel.sellerLink ?? "")
        _greetingMessage = State(initialValue: channel.greetingMessage ?? "")
        _botDescription = State(initialValue: channel.botDescription ?? "")
        _allowPartners = State(initialValue: channel.allowPartners)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar
                    VStack(spacing: 12) {
                        AvatarView(url: channel.avatarUrl, size: 80)
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change Avatar")
                                .font(.subheadline)
                                .foregroundColor(Theme.emerald)
                        }
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await uploadAvatar(data)
                                }
                            }
                        }
                    }
                    
                    // Settings form
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Assistant Name")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            StyledTextField(placeholder: "Assistant", text: $assistantName, autocapitalization: .words)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Seller Link")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            StyledTextField(placeholder: "https://yourstore.com", text: $sellerLink, keyboardType: .URL)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Greeting Message")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            TextEditor(text: $greetingMessage)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Theme.inputBg)
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            StyledTextField(placeholder: "Description", text: $botDescription)
                        }
                        
                        Toggle("Allow Partners", isOn: $allowPartners)
                            .tint(Theme.emerald)
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                        
                        if let error = errorMessage {
                            ErrorBanner(message: error)
                        }
                        
                        PrimaryButton("Save", isLoading: isLoading) {
                            saveSettings()
                        }
                    }
                    
                    // Danger Zone
                    GlassCard {
                        VStack(spacing: 12) {
                            Text("Danger Zone")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                Text("Delete Channel")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("\(channel.platformDisplayName) Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .alert("Delete Channel?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { deleteChannel() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently remove this channel and all its data.")
            }
        }
    }
    
    private func saveSettings() {
        isLoading = true
        errorMessage = nil
        
        let req = ChannelUpdateRequest(
            assistantName: assistantName.trimmingCharacters(in: .whitespaces),
            sellerLink: sellerLink.isEmpty ? nil : sellerLink,
            greetingMessage: greetingMessage.isEmpty ? nil : greetingMessage,
            botDescription: botDescription.isEmpty ? nil : botDescription,
            allowPartners: allowPartners
        )
        
        Task {
            do {
                let _ = try await api.updateChannel(id: channel.id, req)
                await onSave()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func uploadAvatar(_ data: Data) async {
        do {
            let _ = try await api.uploadAvatar(channelId: channel.id, imageData: data)
        } catch { }
    }
    
    private func deleteChannel() {
        Task {
            do {
                try await api.deleteChannel(id: channel.id)
                await onSave()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
