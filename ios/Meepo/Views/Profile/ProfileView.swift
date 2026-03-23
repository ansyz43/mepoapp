import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var showEditName = false
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false
    @State private var cashback: [CashbackTransactionResponse] = []
    @State private var copiedLink = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Profile header
                        GlassCard {
                            VStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.accentGradient)
                                        .frame(width: 76, height: 76)
                                        .blur(radius: 16)
                                        .opacity(0.5)
                                    ZStack {
                                        Circle()
                                            .fill(Theme.cardBgElevated)
                                            .frame(width: 76, height: 76)
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 30, weight: .medium))
                                            .foregroundStyle(Theme.accentGradient)
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(colors: [Theme.emerald.opacity(0.5), Theme.emeraldLight.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                lineWidth: 2
                                            )
                                    )
                                }

                                Text(auth.profile?.name ?? "User")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)

                                Text(auth.profile?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textSecondary)

                                if let joined = auth.profile?.createdAt {
                                    Text("Joined \(joined, style: .date)")
                                        .font(.caption)
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }

                        // Stats row
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(
                                title: "Cashback",
                                value: String(format: "$%.2f", auth.profile?.cashbackBalance ?? 0),
                                icon: "dollarsign.circle"
                            )
                            StatCard(
                                title: "Referrals",
                                value: "\(auth.profile?.referralsCount ?? 0)",
                                icon: "person.2"
                            )
                        }

                        // Referral code
                        if let refCode = auth.profile?.refCode, let refLink = auth.profile?.refLink {
                            GlassCard {
                                VStack(spacing: 12) {
                                    SectionHeader(title: "Referral Code")

                                    Text(refCode)
                                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.accentGradient)

                                    Button {
                                        UIPasteboard.general.string = refLink
                                        copiedLink = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedLink = false }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: copiedLink ? "checkmark" : "doc.on.doc")
                                                .font(.subheadline)
                                            Text(copiedLink ? "Copied!" : "Copy Referral Link")
                                                .fontWeight(.medium)
                                        }
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Theme.emerald.opacity(0.12))
                                        .foregroundColor(Theme.emerald)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }

                        // Actions
                        GlassCard {
                            VStack(spacing: 0) {
                                profileAction(icon: "pencil", title: "Edit Name", color: .blue) {
                                    showEditName = true
                                }
                                actionDivider
                                profileAction(icon: "lock.rotation", title: "Change Password", color: .orange) {
                                    showChangePassword = true
                                }
                                actionDivider

                                NavigationLink(destination: CatalogView()) {
                                    actionRow(icon: "storefront", title: "Catalog", color: .purple)
                                }
                                actionDivider

                                NavigationLink(destination: PartnerView()) {
                                    actionRow(icon: "person.2.badge.gearshape", title: "My Partners", color: Theme.emerald)
                                }

                                if auth.hasChannel {
                                    actionDivider
                                    NavigationLink(destination: BroadcastView()) {
                                        actionRow(icon: "megaphone", title: "Broadcasts", color: .orange)
                                    }
                                }

                                if auth.isAdmin {
                                    actionDivider
                                    NavigationLink(destination: AdminView()) {
                                        actionRow(icon: "shield.checkered", title: "Admin Panel", color: .red)
                                    }
                                }
                            }
                        }

                        // Logout
                        Button {
                            Task { await auth.logout() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.subheadline)
                                Text("Log Out")
                                    .fontWeight(.semibold)
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

                        Button {
                            showDeleteAccount = true
                        } label: {
                            Text("Delete Account")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.5))
                        }
                        .padding(.bottom, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showEditName) {
                EditNameView()
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView()
            }
            .alert("Delete Account?", isPresented: $showDeleteAccount) {
                Button("Delete", role: .destructive) {
                    Task { await auth.deleteAccount() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action is permanent and cannot be undone.")
            }
        }
    }

    private var actionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.leading, 44)
    }

    private func profileAction(icon: String, title: String, color: Color = Theme.emerald, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionRow(icon: icon, title: title, color: color)
        }
    }

    private func actionRow(icon: String, title: String, color: Color = Theme.emerald) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Edit Name

struct EditNameView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                VStack(spacing: 20) {
                    StyledTextField(placeholder: "Name", text: $name, autocapitalization: .words)

                    if let error = errorMessage {
                        ErrorBanner(message: error)
                    }

                    PrimaryButton("Save", isLoading: isLoading) {
                        saveName()
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .onAppear {
                name = auth.profile?.name ?? ""
            }
        }
    }
    
    private func saveName() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let _ = try await api.updateProfile(ProfileUpdateRequest(name: name.trimmingCharacters(in: .whitespaces)))
                await auth.refreshProfile()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Change Password

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()

                VStack(spacing: 16) {
                    StyledTextField(placeholder: "Current password", text: $currentPassword, isSecure: true)
                    StyledTextField(placeholder: "New password (min 6)", text: $newPassword, isSecure: true)
                    StyledTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)

                    if let error = errorMessage {
                        ErrorBanner(message: error)
                    }

                    PrimaryButton("Change Password", isLoading: isLoading) {
                        changePassword()
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func changePassword() {
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await api.changePassword(ChangePasswordRequest(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                ))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
