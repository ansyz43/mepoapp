import Foundation

// MARK: - Channel API
extension APIClient {
    func getChannelStatus() async throws -> ChannelStatusResponse {
        try await request("GET", path: "/api/channel/status")
    }
    
    func connectInstagram(_ req: ChannelConnectRequest) async throws -> ChannelResponse {
        try await request("POST", path: "/api/channel/instagram/connect", body: req)
    }
    
    func connectMessenger(_ req: ChannelConnectRequest) async throws -> ChannelResponse {
        try await request("POST", path: "/api/channel/messenger/connect", body: req)
    }
    
    func updateChannel(platform: String, _ req: ChannelUpdateRequest) async throws -> ChannelResponse {
        let slug = platform == "facebook_messenger" ? "messenger" : platform
        return try await request("PUT", path: "/api/channel/\(slug)", body: req)
    }
    
    func deleteChannel(platform: String) async throws {
        let slug = platform == "facebook_messenger" ? "messenger" : platform
        let _: MessageOnly = try await request("DELETE", path: "/api/channel/\(slug)")
    }
    
    func uploadAvatar(channelId: Int, imageData: Data) async throws -> ChannelResponse {
        try await upload(
            path: "/api/channel/\(channelId)/avatar",
            fileData: imageData,
            fileName: "avatar.jpg",
            mimeType: "image/jpeg"
        )
    }
}

// MARK: - Contacts API
extension APIClient {
    func getContacts(platform: String? = nil, search: String? = nil, page: Int = 1, perPage: Int = 50) async throws -> ContactListResponse {
        var params: [String] = []
        if let p = platform { params.append("platform=\(p)") }
        if let s = search, !s.isEmpty { params.append("search=\(s)") }
        params.append("page=\(page)")
        params.append("per_page=\(perPage)")
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request("GET", path: "/api/contacts\(query)")
    }
    
    func exportContacts() async throws -> Data {
        guard let url = URL(string: baseURL + "/api/contacts/export") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

// MARK: - Conversations API
extension APIClient {
    func getConversations(platform: String? = nil, search: String? = nil, skip: Int = 0, limit: Int = 50) async throws -> ConversationListResponse {
        var params: [String] = []
        if let p = platform { params.append("platform=\(p)") }
        if let s = search, !s.isEmpty { params.append("search=\(s)") }
        params.append("skip=\(skip)")
        params.append("limit=\(limit)")
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request("GET", path: "/api/conversations\(query)")
    }
    
    func getConversation(contactId: Int, skip: Int = 0, limit: Int = 100) async throws -> ConversationDetailResponse {
        try await request("GET", path: "/api/conversations/\(contactId)?skip=\(skip)&limit=\(limit)")
    }
}

// MARK: - Broadcast API
extension APIClient {
    func getBroadcasts() async throws -> [BroadcastResponse] {
        try await request("GET", path: "/api/channel/broadcasts")
    }
    
    func createBroadcast(messageText: String, imageData: Data? = nil) async throws -> BroadcastResponse {
        if let imageData = imageData {
            return try await upload(
                path: "/api/channel/broadcast",
                fileData: imageData,
                fileName: "broadcast.jpg",
                mimeType: "image/jpeg",
                additionalFields: [
                    "message_text": messageText
                ]
            )
        } else {
            struct BroadcastCreate: Encodable {
                let messageText: String
            }
            return try await request("POST", path: "/api/channel/broadcast", body: BroadcastCreate(messageText: messageText))
        }
    }
}

// MARK: - Referral API
extension APIClient {
    func getCatalog() async throws -> [ChannelCatalogItem] {
        try await request("GET", path: "/api/referral/catalog")
    }
    
    func becomePartner(_ req: ReferralPartnerCreate) async throws -> ReferralPartnerResponse {
        try await request("POST", path: "/api/referral/partner", body: req)
    }
    
    func getMyPartners() async throws -> [ReferralPartnerResponse] {
        try await request("GET", path: "/api/referral/my-partners")
    }
    
    func updatePartner(sellerLink: String) async throws -> ReferralPartnerResponse {
        try await request("PUT", path: "/api/referral/partner", body: ReferralPartnerUpdate(sellerLink: sellerLink))
    }
    
    func getPartnerSessions() async throws -> [ReferralSessionResponse] {
        try await request("GET", path: "/api/referral/sessions")
    }
    
    func getMyCashback() async throws -> [CashbackTransactionResponse] {
        try await request("GET", path: "/api/referral/my-cashback")
    }
    

}

// MARK: - Profile API
extension APIClient {
    func updateProfile(_ req: ProfileUpdateRequest) async throws -> ProfileResponse {
        try await request("PUT", path: "/api/profile", body: req)
    }
    
    func changePassword(_ req: ChangePasswordRequest) async throws {
        let _: MessageOnly = try await request("PUT", path: "/api/profile/password", body: req)
    }
}

// MARK: - Admin API
extension APIClient {
    func getAdminStats() async throws -> AdminStatsResponse {
        try await request("GET", path: "/api/admin/stats")
    }
    
    func getAdminUsers(skip: Int = 0, limit: Int = 50) async throws -> [AdminUserResponse] {
        try await request("GET", path: "/api/admin/users?skip=\(skip)&limit=\(limit)")
    }
    
    func toggleUserActive(userId: Int) async throws -> AdminUserResponse {
        try await request("PATCH", path: "/api/admin/users/\(userId)/toggle")
    }
    
    func getAdminChannels(skip: Int = 0, limit: Int = 50) async throws -> [AdminChannelResponse] {
        try await request("GET", path: "/api/admin/channels?skip=\(skip)&limit=\(limit)")
    }
}

// MARK: - Password Reset API
extension APIClient {
    func requestPasswordReset(email: String) async throws {
        let _: MessageOnly = try await request(
            "POST", path: "/api/auth/reset-password",
            body: ResetPasswordRequest(email: email),
            authenticated: false
        )
    }
    
    func verifyResetCode(email: String, code: String) async throws -> TokenResponse {
        try await request(
            "POST", path: "/api/auth/verify-code",
            body: VerifyCodeRequest(email: email, code: code),
            authenticated: false
        )
    }
    
    func setNewPassword(token: String, password: String) async throws {
        let _: MessageOnly = try await request(
            "POST", path: "/api/auth/set-password",
            body: SetPasswordRequest(token: token, password: password),
            authenticated: false
        )
    }
}
