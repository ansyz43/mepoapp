import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showResetPassword = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer().frame(height: 50)

                        // Logo
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.emerald.opacity(0.15))
                                    .frame(width: 96, height: 96)
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 44, weight: .medium))
                                    .foregroundStyle(Theme.accentGradient)
                            }
                            Text("Meepo")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("AI Channel Assistant")
                                .font(.subheadline)
                                .foregroundColor(Theme.textTertiary)
                        }

                        // Form
                        VStack(spacing: 14) {
                            StyledTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                            StyledTextField(placeholder: "Password", text: $password, isSecure: true)

                            if let error = auth.errorMessage {
                                ErrorBanner(message: error)
                            }

                            PrimaryButton("Sign In", isLoading: auth.isLoading) {
                                Task { await auth.login(email: email, password: password) }
                            }
                            .padding(.top, 4)

                            Button("Forgot password?") {
                                showResetPassword = true
                            }
                            .font(.subheadline)
                            .foregroundColor(Theme.emerald)
                        }

                        // Divider
                        HStack(spacing: 12) {
                            Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.08))
                            Text("or")
                                .foregroundColor(Theme.textTertiary)
                                .font(.caption)
                            Rectangle().frame(height: 0.5).foregroundColor(Color.white.opacity(0.08))
                        }

                        // Apple Sign In
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Register link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(Theme.textTertiary)
                            Button("Sign Up") {
                                showRegister = true
                            }
                            .foregroundColor(Theme.emerald)
                            .fontWeight(.semibold)
                        }
                        .font(.subheadline)

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 28)
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else { return }
            
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            Task {
                await self.auth.loginWithApple(
                    identityToken: identityToken,
                    name: fullName.isEmpty ? nil : fullName,
                    refCode: nil
                )
            }
        case .failure(let error):
            self.auth.errorMessage = error.localizedDescription
        }
    }
}
