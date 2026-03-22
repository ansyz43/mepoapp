import SwiftUI

// MARK: - Theme

enum Theme {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255) // #10B981
    static let darkBg = Color(red: 17/255, green: 24/255, blue: 39/255)     // #111827
    static let cardBg = Color(red: 31/255, green: 41/255, blue: 55/255)     // #1F2937
    static let inputBg = Color(red: 55/255, green: 65/255, blue: 81/255)    // #374151
    static let textSecondary = Color(red: 156/255, green: 163/255, blue: 175/255) // #9CA3AF
}

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    
    init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.emerald)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Styled Text Field

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .padding()
        .background(Theme.inputBg)
        .cornerRadius(12)
        .foregroundColor(.white)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(Theme.emerald)
                    Spacer()
                }
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Platform Badge

struct PlatformBadge: View {
    let platform: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: platform == "instagram" ? "camera" : "message")
                .font(.caption2)
            Text(platform == "instagram" ? "IG" : "FB")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(platform == "instagram" ? Color.purple.opacity(0.3) : Color.blue.opacity(0.3))
        .foregroundColor(platform == "instagram" ? .purple : .blue)
        .cornerRadius(8)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String
    
    var color: Color {
        switch status.lowercased() {
        case "active", "sent", "completed": return .green
        case "pending", "sending": return .orange
        case "error", "failed": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let url: String?
    let size: CGFloat
    let fallbackIcon: String
    
    init(url: String? = nil, size: CGFloat = 40, fallbackIcon: String = "person.crop.circle.fill") {
        self.url = url
        self.size = size
        self.fallbackIcon = fallbackIcon
    }
    
    var body: some View {
        if let url = url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: fallbackIcon)
                    .resizable()
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            Image(systemName: fallbackIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.2))
        .foregroundColor(.red)
        .cornerRadius(12)
    }
}
