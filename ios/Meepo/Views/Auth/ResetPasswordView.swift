import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var step = 1
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var resetToken = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accentGradient)
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 20)
                                    .opacity(0.4)
                                ZStack {
                                    Circle()
                                        .fill(Theme.cardBgElevated)
                                        .frame(width: 70, height: 70)
                                    Image(systemName: step == 3 ? "checkmark.shield" : "key.fill")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(Theme.accentGradient)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(colors: [Theme.emerald.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            lineWidth: 2
                                        )
                                )
                            }

                            Text(stepTitle)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(stepDescription)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 30)

                        // Step content
                        GlassCard {
                            VStack(spacing: 16) {
                                switch step {
                                case 1:
                                    StyledTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                                case 2:
                                    StyledTextField(placeholder: "6-digit code", text: $code, keyboardType: .numberPad)
                                case 3:
                                    StyledTextField(placeholder: "New password (min 6 characters)", text: $newPassword, isSecure: true)
                                    StyledTextField(placeholder: "Confirm password", text: $confirmPassword, isSecure: true)
                                default:
                                    EmptyView()
                                }

                                if let error = errorMessage {
                                    ErrorBanner(message: error)
                                }

                                if let success = successMessage {
                                    SuccessBanner(message: success)
                                }

                                PrimaryButton(stepButtonTitle, isLoading: isLoading) {
                                    handleStep()
                                }
                            }
                        }

                        // Progress dots
                        HStack(spacing: 10) {
                            ForEach(1...3, id: \.self) { i in
                                Capsule()
                                    .fill(i <= step ? Theme.emerald : Theme.inputBg)
                                    .frame(width: i == step ? 24 : 8, height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: step)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
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
    
    private var stepTitle: String {
        switch step {
        case 1: return "Reset Password"
        case 2: return "Verify Code"
        case 3: return "New Password"
        default: return ""
        }
    }
    
    private var stepDescription: String {
        switch step {
        case 1: return "Enter your email to receive a reset code"
        case 2: return "Enter the 6-digit code sent to \(email)"
        case 3: return "Choose a new password"
        default: return ""
        }
    }
    
    private var stepButtonTitle: String {
        switch step {
        case 1: return "Send Code"
        case 2: return "Verify"
        case 3: return "Set Password"
        default: return ""
        }
    }
    
    private func handleStep() {
        errorMessage = nil
        successMessage = nil
        
        switch step {
        case 1:
            guard !email.isEmpty else { errorMessage = "Please enter your email"; return }
            isLoading = true
            Task {
                do {
                    try await api.requestPasswordReset(email: email)
                    step = 2
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            
        case 2:
            guard code.count == 6 else { errorMessage = "Enter the 6-digit code"; return }
            isLoading = true
            Task {
                do {
                    let response = try await api.verifyResetCode(email: email, code: code)
                    resetToken = response.accessToken
                    step = 3
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            
        case 3:
            guard newPassword.count >= 6 else { errorMessage = "Password must be at least 6 characters"; return }
            guard newPassword == confirmPassword else { errorMessage = "Passwords don't match"; return }
            isLoading = true
            Task {
                do {
                    try await api.setNewPassword(token: resetToken, password: newPassword)
                    successMessage = "Password updated! You can now sign in."
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            
        default:
            break
        }
    }
}
