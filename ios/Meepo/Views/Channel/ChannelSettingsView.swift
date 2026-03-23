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

    private var platformColor: Color {
        channel.platform == "instagram" ? Theme.instagram : Theme.messenger
    }

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
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Avatar
                        VStack(spacing: 12) {
                            AvatarView(url: channel.avatarUrl, size: 80)

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                    Text("Change Avatar")
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                                .foregroundColor(platformColor)
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
                        GlassCard {
                            VStack(spacing: 16) {
                                formField("Assistant Name", placeholder: "Assistant", text: $assistantName)
                                formField("Seller Link", placeholder: "https://yourstore.com", text: $sellerLink, keyboard: .URL)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Greeting Message")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    TextEditor(text: $greetingMessage)
                                        .frame(minHeight: 80)
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

                                formField("Description", placeholder: "Description", text: $botDescription)

                                Toggle(isOn: $allowPartners) {
                                    Text("Allow Partners")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .tint(Theme.emerald)
                                .padding(.vertical, 4)

                                if let error = errorMessage {
                                    ErrorBanner(message: error)
                                }

                                PrimaryButton("Save Changes", isLoading: isLoading) {
                                    saveSettings()
                                }
                            }
                        }

                        // Danger Zone
                        GlassCard {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                    Text("Danger Zone")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red.opacity(0.8))
                                    Spacer()
                                }

                                Button {
                                    showDeleteConfirm = true
                                } label: {
                                    Text("Delete Channel")
                                        .fontWeight(.medium)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.red.opacity(0.12))
                                        .foregroundColor(.red)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
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

    private func formField(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            StyledTextField(placeholder: placeholder, text: text, keyboardType: keyboard)
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
                let _ = try await api.updateChannel(platform: channel.platform, req)
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
                try await api.deleteChannel(platform: channel.platform)
                await onSave()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
