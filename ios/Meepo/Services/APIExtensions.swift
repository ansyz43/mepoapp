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
    
    func updateChannel(id: Int, _ req: ChannelUpdateRequest) async throws -> ChannelResponse {
        try await request("PUT", path: "/api/channel/\(id)", body: req)
    }
    
    func deleteChannel(id: Int) async throws {
        let _: MessageOnly = try await request("DELETE", path: "/api/channel/\(id)")
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
    func getContacts(platform: String? = nil, search: String? = nil, skip: Int = 0, limit: Int = 50) async throws -> ContactListResponse {
        var params: [String] = []
        if let p = platform { params.append("platform=\(p)") }
        if let s = search, !s.isEmpty { params.append("search=\(s)") }
        params.append("skip=\(skip)")
        params.append("limit=\(limit)")
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request("GET", path: "/api/conversations/contacts\(query)")
    }
    
    func exportContacts(format: String = "csv") async throws -> Data {
        // This returns file data, handle separately
        guard let url = URL(string: "https://meepo.su/api/conversations/contacts/export?format=\(format)") else {
            throw APIError.invalidURL
        }
        var req = URLRequest(url: url)
        if let token = KeychainHelper.load(key: "access_token") {
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
    func getBroadcasts(skip: Int = 0, limit: Int = 20) async throws -> [BroadcastResponse] {
        try await request("GET", path: "/api/broadcast?skip=\(skip)&limit=\(limit)")
    }
    
    func createBroadcast(channelId: Int, messageText: String, imageData: Data? = nil) async throws -> BroadcastResponse {
        if let imageData = imageData {
            return try await upload(
                path: "/api/broadcast",
                fileData: imageData,
                fileName: "broadcast.jpg",
                mimeType: "image/jpeg",
                additionalFields: [
                    "channel_id": "\(channelId)",
                    "message_text": messageText
                ]
            )
        } else {
            struct BroadcastCreate: Encodable {
                let channelId: Int
                let messageText: String
            }
            return try await request("POST", path: "/api/broadcast", body: BroadcastCreate(channelId: channelId, messageText: messageText))
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
    
    func updatePartner(id: Int, sellerLink: String) async throws -> ReferralPartnerResponse {
        try await request("PUT", path: "/api/referral/partner/\(id)", body: ReferralPartnerUpdate(sellerLink: sellerLink))
    }
    
    func deletePartner(id: Int) async throws {
        let _: MessageOnly = try await request("DELETE", path: "/api/referral/partner/\(id)")
    }
    
    func getPartnerSessions(partnerId: Int) async throws -> [ReferralSessionResponse] {
        try await request("GET", path: "/api/referral/partner/\(partnerId)/sessions")
    }
    
    func getMyCashback() async throws -> [CashbackTransactionResponse] {
        try await request("GET", path: "/api/referral/my-cashback")
    }
    
    func getReferralTree() async throws -> [TreeNodeResponse] {
        try await request("GET", path: "/api/referral/tree")
    }
}

// MARK: - Profile API
extension APIClient {
    func updateProfile(_ req: ProfileUpdateRequest) async throws -> ProfileResponse {
        try await request("PUT", path: "/api/profile/me", body: req)
    }
    
    func changePassword(_ req: ChangePasswordRequest) async throws {
        let _: MessageOnly = try await request("POST", path: "/api/profile/change-password", body: req)
    }
    
    func registerPushToken(deviceToken: String) async throws {
        let _: MessageOnly = try await request(
            "POST", path: "/api/profile/push-token",
            body: PushTokenRequest(deviceToken: deviceToken, platform: "ios")
        )
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
        try await request("PUT", path: "/api/admin/users/\(userId)/toggle-active")
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
            "POST", path: "/api/auth/verify-reset-code",
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
