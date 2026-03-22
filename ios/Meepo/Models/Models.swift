import Foundation

// MARK: - Auth

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let name: String
    let refCode: String?
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct AppleAuthRequest: Codable {
    let identityToken: String
    let name: String?
    let refCode: String?
}

struct GoogleAuthRequest: Codable {
    let credential: String
    let refCode: String?
}

struct ResetPasswordRequest: Codable {
    let email: String
}

struct VerifyCodeRequest: Codable {
    let email: String
    let code: String
}

struct SetPasswordRequest: Codable {
    let token: String
    let password: String
}

// MARK: - Profile

struct ProfileResponse: Codable, Identifiable {
    let id: Int
    let email: String
    let name: String
    let createdAt: Date
    let hasChannel: Bool
    let isAdmin: Bool
    let refCode: String?
    let refLink: String?
    let cashbackBalance: Double
    let referralsCount: Int
}

struct ProfileUpdateRequest: Codable {
    let name: String
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

// MARK: - Channel

struct ChannelConnectRequest: Codable {
    let code: String
    let assistantName: String
    let sellerLink: String?
    let greetingMessage: String?
    let botDescription: String?
}

struct ChannelUpdateRequest: Codable {
    let assistantName: String
    let sellerLink: String?
    let greetingMessage: String?
    let botDescription: String?
    let allowPartners: Bool?
}

struct ChannelResponse: Codable, Identifiable {
    let id: Int
    let platform: String
    let channelName: String?
    let assistantName: String
    let sellerLink: String?
    let greetingMessage: String?
    let botDescription: String?
    let avatarUrl: String?
    let allowPartners: Bool
    let isActive: Bool
    let webhookStatus: String
    let createdAt: Date
    
    var platformDisplayName: String {
        switch platform {
        case "instagram": return "Instagram"
        case "facebook_messenger": return "Messenger"
        default: return platform.capitalized
        }
    }
    
    var platformIcon: String {
        switch platform {
        case "instagram": return "camera"
        case "facebook_messenger": return "message"
        default: return "bubble.left"
        }
    }
}

struct ChannelStatusResponse: Codable {
    let instagram: ChannelResponse?
    let messenger: ChannelResponse?
    
    var all: [ChannelResponse] {
        [instagram, messenger].compactMap { $0 }
    }
    
    var hasAny: Bool {
        instagram != nil || messenger != nil
    }
}

// MARK: - Contact

struct ContactResponse: Codable, Identifiable {
    let id: Int
    let platform: String
    let channelUserId: String?
    let channelUsername: String?
    let profilePicUrl: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
    let firstMessageAt: Date
    let lastMessageAt: Date?
    let messageCount: Int
    
    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }
        if parts.isEmpty { return channelUsername ?? "User \(id)" }
        return parts.joined(separator: " ")
    }
}

struct ContactListResponse: Codable {
    let contacts: [ContactResponse]
    let total: Int
}

// MARK: - Conversation

struct MessageResponse: Codable, Identifiable {
    let id: Int
    let role: String
    let content: String
    let createdAt: Date
    
    var isUser: Bool { role == "user" }
}

struct ConversationPreview: Codable, Identifiable {
    let contactId: Int
    let platform: String
    let channelUsername: String?
    let firstName: String?
    let lastName: String?
    let lastMessage: String?
    let lastMessageAt: Date?
    let messageCount: Int
    let linkSent: Bool
    
    var id: Int { contactId }
    
    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }
        if parts.isEmpty { return channelUsername ?? "User \(contactId)" }
        return parts.joined(separator: " ")
    }
}

struct ConversationListResponse: Codable {
    let conversations: [ConversationPreview]
    let total: Int
}

struct ConversationDetailResponse: Codable {
    let contact: ContactResponse
    let messages: [MessageResponse]
    let total: Int
}

// MARK: - Referral

struct ChannelCatalogItem: Codable, Identifiable {
    let id: Int
    let channelName: String?
    let assistantName: String
    let avatarUrl: String?
}

struct ReferralPartnerCreate: Codable {
    let channelId: Int
    let sellerLink: String
}

struct ReferralPartnerUpdate: Codable {
    let sellerLink: String
}

struct ReferralPartnerResponse: Codable, Identifiable {
    let id: Int
    let channelId: Int
    let channelName: String?
    let assistantName: String
    let sellerLink: String
    let refCode: String
    let refLink: String
    let credits: Int
    let isActive: Bool
    let createdAt: Date
}

struct ReferralSessionResponse: Codable, Identifiable {
    let id: Int
    let channelUserId: String
    let channelUsername: String?
    let firstName: String?
    let startedAt: Date
    let expiresAt: Date
    let isActive: Bool
}

struct AddCreditsRequest: Codable {
    let partnerId: Int
    let credits: Int
}

struct ChannelPartnerInfo: Codable, Identifiable {
    let id: Int
    let userName: String
    let userEmail: String
    let sellerLink: String
    let refCode: String
    let credits: Int
    let totalSessions: Int
    let activeSessions: Int
    let createdAt: Date
}

struct TreeNodeResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let level: Int
    let totalSpent: Double
    let cashbackEarned: Double
    let joinedAt: Date
    let children: [TreeNodeResponse]
}

// MARK: - Broadcast

struct BroadcastResponse: Codable, Identifiable {
    let id: Int
    let messageText: String
    let imageUrl: String?
    let totalContacts: Int
    let eligibleContacts: Int
    let sentCount: Int
    let failedCount: Int
    let status: String
    let createdAt: Date
}

struct CashbackTransactionResponse: Codable, Identifiable {
    let id: Int
    let fromUserName: String
    let amount: Double
    let sourceAmount: Double
    let level: Int
    let sourceType: String
    let createdAt: Date
}

// MARK: - Push

struct PushTokenRequest: Codable {
    let deviceToken: String
    let platform: String
}

// MARK: - Admin

struct AdminStatsResponse: Codable {
    let totalUsers: Int
    let activeChannels: Int
    let totalContacts: Int
    let totalMessages: Int
}

struct AdminUserResponse: Codable, Identifiable {
    let id: Int
    let email: String
    let name: String
    let isActive: Bool
    let isAdmin: Bool
    let createdAt: Date
    let channelsCount: Int
}

struct AdminChannelResponse: Codable, Identifiable {
    let id: Int
    let userId: Int?
    let ownerName: String?
    let platform: String
    let channelName: String?
    let assistantName: String
    let isActive: Bool
    let webhookStatus: String
    let contactsCount: Int
    let createdAt: Date
}

// MARK: - Generic

struct MessageOnly: Codable {
    let message: String
}
