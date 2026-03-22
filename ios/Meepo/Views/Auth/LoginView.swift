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
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
                    // Logo
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 56))
                            .foregroundColor(Theme.emerald)
                        Text("Meepo")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("AI Channel Assistant")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer().frame(height: 20)
                    
                    // Form
                    VStack(spacing: 16) {
                        StyledTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        StyledTextField(placeholder: "Password", text: $password, isSecure: true)
                        
                        if let error = auth.errorMessage {
                            ErrorBanner(message: error)
                        }
                        
                        PrimaryButton("Sign In", isLoading: auth.isLoading) {
                            Task { await auth.login(email: email, password: password) }
                        }
                        
                        Button("Forgot password?") {
                            showResetPassword = true
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.emerald)
                    }
                    
                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(Theme.inputBg)
                        Text("or").foregroundColor(Theme.textSecondary).font(.caption)
                        Rectangle().frame(height: 1).foregroundColor(Theme.inputBg)
                    }
                    
                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    // Register link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(Theme.textSecondary)
                        Button("Sign Up") {
                            showRegister = true
                        }
                        .foregroundColor(Theme.emerald)
                        .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 24)
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
