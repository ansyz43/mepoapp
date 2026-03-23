import SwiftUI

// MARK: - Theme

enum Theme {
    // Primary accent — vivid emerald
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let emeraldLight = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let emeraldDark = Color(red: 5/255, green: 150/255, blue: 105/255)

    // Backgrounds — deep dark with blue undertone
    static let darkBg = Color(red: 8/255, green: 10/255, blue: 18/255)
    static let cardBg = Color(red: 14/255, green: 17/255, blue: 28/255)
    static let cardBgElevated = Color(red: 20/255, green: 24/255, blue: 38/255)
    static let inputBg = Color(red: 22/255, green: 27/255, blue: 42/255)
    static let surfaceBg = Color(red: 16/255, green: 20/255, blue: 32/255)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let textTertiary = Color(red: 100/255, green: 116/255, blue: 139/255)

    // Accents
    static let instagram = Color(red: 225/255, green: 48/255, blue: 108/255)
    static let messenger = Color(red: 0/255, green: 132/255, blue: 255/255)

    // Gradient
    static let accentGradient = LinearGradient(
        colors: [emerald, emeraldLight],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let meshGradient = LinearGradient(
        colors: [
            Color(red: 6/255, green: 11/255, blue: 17/255),
            Color(red: 10/255, green: 18/255, blue: 32/255),
            Color(red: 8/255, green: 12/255, blue: 22/255)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
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
                    ProgressView().tint(.white)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accentGradient)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Theme.emerald.opacity(0.35), radius: 12, y: 4)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.subheadline) }
                Text(title).fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.cardBgElevated)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.cardBg)
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1
                    )
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.inputBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .foregroundColor(.white)
        .tint(Theme.emerald)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var accentColor: Color = Theme.emerald

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Platform Badge

struct PlatformBadge: View {
    let platform: String

    private var isIG: Bool { platform == "instagram" }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isIG ? "camera.fill" : "message.fill")
                .font(.system(size: 9, weight: .bold))
            Text(isIG ? "IG" : "MSG")
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (isIG ? Theme.instagram : Theme.messenger).opacity(0.15)
        )
        .foregroundColor(isIG ? Theme.instagram : Theme.messenger)
        .clipShape(Capsule())
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
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(status.capitalized)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.emerald.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Theme.emerald.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
        Group {
            if let url = url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var fallbackView: some View {
        ZStack {
            Circle().fill(Theme.cardBgElevated)
            Image(systemName: fallbackIcon)
                .resizable()
                .scaledToFit()
                .padding(size * 0.25)
                .foregroundColor(Theme.textTertiary)
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.12))
        .foregroundColor(Color(red: 1, green: 0.4, blue: 0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Success Banner

struct SuccessBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.emerald.opacity(0.12))
        .foregroundColor(Theme.emeraldLight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }
}

// MARK: - Mesh Background

struct MeshBackground: View {
    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()
            // Subtle gradient orbs
            Circle()
                .fill(Theme.emerald.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.03))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 150, y: 100)
        }
        .ignoresSafeArea()
    }
}
