import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthManager
    
    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
        .task {
            await auth.tryRestoreSession()
        }
    }
}
