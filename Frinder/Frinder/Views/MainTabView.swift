import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var radarViewModel = RadarViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()

    var body: some View {
        TabView {
            RadarView()
                .environmentObject(radarViewModel)
                .tabItem {
                    Label("Radar", systemImage: "dot.radiowaves.left.and.right")
                }

            FriendsView()
                .environmentObject(friendsViewModel)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            // Use Firebase Auth user ID directly (works even when Firestore is offline)
            if let userId = authViewModel.currentUserId {
                radarViewModel.startTracking(userId: userId)
                friendsViewModel.setup(userId: userId)
            }
        }
        .onDisappear {
            radarViewModel.stopTracking()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
