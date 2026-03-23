import SwiftUI

struct ConnectChannelView: View {
    @Environment(\.dismiss) var dismiss
    let platform: String
    let onConnect: () async -> Void

    @State private var code = ""
    @State private var assistantName = "Assistant"
    @State private var sellerLink = ""
    @State private var greetingMessage = ""
    @State private var botDescription = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var platformName: String {
        platform == "instagram" ? "Instagram" : "Messenger"
    }

    private var platformColor: Color {
        platform == "instagram" ? Theme.instagram : Theme.messenger
    }

    private var platformIcon: String {
        platform == "instagram" ? "camera.fill" : "message.fill"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Instructions header
                        GlassCard {
                            VStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(platformColor.opacity(0.12))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: platformIcon)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(platformColor)
                                }

                                Text("Connect \(platformName)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Enter the authorization code from Meta Business to connect your \(platformName) account.")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Form
                        GlassCard {
                            VStack(spacing: 16) {
                                formField("Authorization Code *", placeholder: "Paste code here", text: $code)
                                formField("Assistant Name *", placeholder: "My Assistant", text: $assistantName)
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

                                formField("Description", placeholder: "What does your assistant do?", text: $botDescription)

                                if let error = errorMessage {
                                    ErrorBanner(message: error)
                                }

                                PrimaryButton("Connect", isLoading: isLoading) {
                                    connectChannel()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
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

    private func connectChannel() {
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Authorization code is required"
            return
        }
        guard !assistantName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Assistant name is required"
            return
        }

        errorMessage = nil
        isLoading = true

        let request = ChannelConnectRequest(
            code: code.trimmingCharacters(in: .whitespaces),
            assistantName: assistantName.trimmingCharacters(in: .whitespaces),
            sellerLink: sellerLink.isEmpty ? nil : sellerLink,
            greetingMessage: greetingMessage.isEmpty ? nil : greetingMessage,
            botDescription: botDescription.isEmpty ? nil : botDescription
        )

        Task {
            do {
                if platform == "instagram" {
                    let _ = try await api.connectInstagram(request)
                } else {
                    let _ = try await api.connectMessenger(request)
                }
                await onConnect()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
