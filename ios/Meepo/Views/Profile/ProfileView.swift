import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var showEditName = false
    @State private var showChangePassword = false
    @State private var showDeleteAccount = false
    @State private var cashback: [CashbackTransactionResponse] = []
    
    private let api = APIClient.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile card
                    GlassCard {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(Theme.emerald)
                            
                            Text(auth.profile?.name ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(auth.profile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            
                            if let joined = auth.profile?.createdAt {
                                Text("Joined \(joined, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                    
                    // Stats
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
                            VStack(spacing: 10) {
                                Text("Your Referral Code")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(refCode)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.emerald)
                                
                                Button {
                                    UIPasteboard.general.string = refLink
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy Referral Link")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(Theme.emerald)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.inputBg)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Actions
                    GlassCard {
                        VStack(spacing: 0) {
                            profileAction(icon: "pencil", title: "Edit Name") {
                                showEditName = true
                            }
                            Divider().background(Theme.inputBg)
                            profileAction(icon: "lock.rotation", title: "Change Password") {
                                showChangePassword = true
                            }
                            Divider().background(Theme.inputBg)
                            
                            NavigationLink(destination: CatalogView()) {
                                actionRow(icon: "storefront", title: "Catalog")
                            }
                            Divider().background(Theme.inputBg)
                            
                            NavigationLink(destination: PartnerView()) {
                                actionRow(icon: "person.2.badge.gearshape", title: "My Partners")
                            }
                            
                            if auth.hasChannel {
                                Divider().background(Theme.inputBg)
                                NavigationLink(destination: BroadcastView()) {
                                    actionRow(icon: "megaphone", title: "Broadcasts")
                                }
                            }
                            
                            if auth.isAdmin {
                                Divider().background(Theme.inputBg)
                                NavigationLink(destination: AdminView()) {
                                    actionRow(icon: "shield.checkered", title: "Admin Panel")
                                }
                            }
                        }
                    }
                    
                    // Logout + Delete
                    VStack(spacing: 12) {
                        Button {
                            Task { await auth.logout() }
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Log Out")
                            }
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.inputBg)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            showDeleteAccount = true
                        } label: {
                            Text("Delete Account")
                                .font(.subheadline)
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
                .padding()
            }
            .background(Theme.darkBg.ignoresSafeArea())
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
    
    private func profileAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionRow(icon: icon, title: title)
        }
    }
    
    private func actionRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.emerald)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 12)
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
            .padding()
            .background(Theme.darkBg.ignoresSafeArea())
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
            VStack(spacing: 20) {
                StyledTextField(placeholder: "Current password", text: $currentPassword, isSecure: true)
                StyledTextField(placeholder: "New password (min 6 characters)", text: $newPassword, isSecure: true)
                StyledTextField(placeholder: "Confirm new password", text: $confirmPassword, isSecure: true)
                
                if let error = errorMessage {
                    ErrorBanner(message: error)
                }
                
                PrimaryButton("Change Password", isLoading: isLoading) {
                    changePassword()
                }
                
                Spacer()
            }
            .padding()
            .background(Theme.darkBg.ignoresSafeArea())
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
