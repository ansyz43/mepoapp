import Foundation
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var profile: ProfileResponse?
    @Published var errorMessage: String?
    
    private let api = APIClient.shared
    
    var isAdmin: Bool { profile?.isAdmin ?? false }
    var hasChannel: Bool { profile?.hasChannel ?? false }
    
    func tryRestoreSession() async {
        let restored = await api.restoreTokens()
        guard restored else { return }
        do {
            let profile: ProfileResponse = try await api.request("GET", path: "/api/profile/me")
            self.profile = profile
            self.isAuthenticated = true
        } catch {
            await api.clearTokens()
        }
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: TokenResponse = try await api.request(
                "POST", path: "/api/auth/login",
                body: LoginRequest(email: email, password: password),
                authenticated: false
            )
            await api.setTokens(access: response.accessToken, refresh: response.refreshToken)
            let profile: ProfileResponse = try await api.request("GET", path: "/api/profile/me")
            self.profile = profile
            self.isAuthenticated = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func register(email: String, password: String, name: String, refCode: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: TokenResponse = try await api.request(
                "POST", path: "/api/auth/register",
                body: RegisterRequest(email: email, password: password, name: name, refCode: refCode),
                authenticated: false
            )
            await api.setTokens(access: response.accessToken, refresh: response.refreshToken)
            let profile: ProfileResponse = try await api.request("GET", path: "/api/profile/me")
            self.profile = profile
            self.isAuthenticated = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func loginWithApple(identityToken: String, name: String?, refCode: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: TokenResponse = try await api.request(
                "POST", path: "/api/auth/apple",
                body: AppleAuthRequest(identityToken: identityToken, name: name, refCode: refCode),
                authenticated: false
            )
            await api.setTokens(access: response.accessToken, refresh: response.refreshToken)
            let profile: ProfileResponse = try await api.request("GET", path: "/api/profile/me")
            self.profile = profile
            self.isAuthenticated = true
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func logout() async {
        do {
            try await api.requestVoid("POST", path: "/api/auth/logout")
        } catch { }
        await api.clearTokens()
        self.profile = nil
        self.isAuthenticated = false
    }
    
    func refreshProfile() async {
        do {
            let profile: ProfileResponse = try await api.request("GET", path: "/api/profile/me")
            self.profile = profile
        } catch { }
    }
    
    func deleteAccount() async -> Bool {
        do {
            try await api.requestVoid("DELETE", path: "/api/auth/account")
            await api.clearTokens()
            self.profile = nil
            self.isAuthenticated = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
