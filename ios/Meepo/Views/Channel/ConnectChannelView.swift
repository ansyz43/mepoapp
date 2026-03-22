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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Instructions
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: platform == "instagram" ? "camera" : "message")
                                    .font(.title2)
                                    .foregroundColor(Theme.emerald)
                                Text("Connect \(platformName)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Text("Enter the authorization code from Meta Business to connect your \(platformName) account.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    
                    // Form
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Authorization Code *")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            StyledTextField(placeholder: "Paste code here", text: $code)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Assistant Name *")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                            StyledTextField(placeholder: "My Assistant", text: $assistantName, autocapitalization: .words)
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
                            StyledTextField(placeholder: "What does your assistant do?", text: $botDescription)
                        }
                        
                        if let error = errorMessage {
                            ErrorBanner(message: error)
                        }
                        
                        PrimaryButton("Connect", isLoading: isLoading) {
                            connectChannel()
                        }
                    }
                }
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
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
