import SwiftUI
import AuthenticationServices

struct RegisterView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var refCode = ""
    @State private var localError: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.emerald)
                        Text("Create Account")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 14) {
                        StyledTextField(placeholder: "Name", text: $name, autocapitalization: .words)
                        StyledTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        StyledTextField(placeholder: "Password (min 6 characters)", text: $password, isSecure: true)
                        StyledTextField(placeholder: "Confirm password", text: $confirmPassword, isSecure: true)
                        StyledTextField(placeholder: "Referral code (optional)", text: $refCode)
                        
                        if let error = localError ?? auth.errorMessage {
                            ErrorBanner(message: error)
                        }
                        
                        PrimaryButton("Sign Up", isLoading: auth.isLoading) {
                            register()
                        }
                    }
                    
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(Theme.inputBg)
                        Text("or").foregroundColor(Theme.textSecondary).font(.caption)
                        Rectangle().frame(height: 1).foregroundColor(Theme.inputBg)
                    }
                    
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    HStack {
                        Text("Already have an account?")
                            .foregroundColor(Theme.textSecondary)
                        Button("Sign In") { dismiss() }
                            .foregroundColor(Theme.emerald)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 24)
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
    
    private func register() {
        localError = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            localError = "Please enter your name"
            return
        }
        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters"
            return
        }
        guard password == confirmPassword else {
            localError = "Passwords don't match"
            return
        }
        Task {
            await auth.register(
                email: email,
                password: password,
                name: name.trimmingCharacters(in: .whitespaces),
                refCode: refCode.isEmpty ? nil : refCode
            )
            if auth.isAuthenticated { dismiss() }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else { return }
            
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            
            Task {
                await self.auth.loginWithApple(
                    identityToken: identityToken,
                    name: fullName.isEmpty ? nil : fullName,
                    refCode: refCode.isEmpty ? nil : refCode
                )
                if self.auth.isAuthenticated { dismiss() }
            }
        case .failure(let error):
            localError = error.localizedDescription
        }
    }
}
