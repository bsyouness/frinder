import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var radarViewModel = RadarViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                VStack(spacing: 0) {
                    RadarView()
                        .environmentObject(radarViewModel)
                    BannerAdView()
                        .frame(height: bannerAdHeight)
                }
                .tabItem {
                    Label("Radar", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(0)

                VStack(spacing: 0) {
                    FriendsView(onNavigate: { friend in
                        radarViewModel.targetFriend = friend
                        selectedTab = 0
                    })
                    .environmentObject(friendsViewModel)
                    BannerAdView()
                        .frame(height: bannerAdHeight)
                }
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
                .tag(1)

                VStack(spacing: 0) {
                    SettingsView()
                    BannerAdView()
                        .frame(height: bannerAdHeight)
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
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

            // Offline banner (non-dismissable)
            if authViewModel.isOffline {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.white)
                        Text("Offline mode - You can only see landmarks")
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 50)

                    Spacer()
                }
            }

            // Error banner (dismissable)
            if let error = authViewModel.errorMessage {
                VStack {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            authViewModel.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, authViewModel.isOffline ? 100 : 50)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: authViewModel.errorMessage)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
