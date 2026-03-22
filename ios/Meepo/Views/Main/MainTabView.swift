import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            if auth.hasChannel {
                ChannelView()
                    .tabItem {
                        Label("Channels", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(1)
                
                ConversationsView()
                    .tabItem {
                        Label("Chats", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(2)
                
                ContactsView()
                    .tabItem {
                        Label("Contacts", systemImage: "person.2")
                    }
                    .tag(3)
            }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(8)
        }
        .tint(Theme.emerald)
    }
}
