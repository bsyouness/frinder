import SwiftUI
import FirebaseCore
import GoogleSignIn
import GoogleMobileAds
import AppTrackingTransparency

@main
struct FrinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    // Delay so the launch transition finishes before the ATT dialog
                    // appears — iOS silently drops it if the window isn't fully visible.
                    try? await Task.sleep(for: .seconds(1))
                    await ATTrackingManager.requestTrackingAuthorization()
                    MobileAds.shared.start(completionHandler: nil)

                    // Request notification permissions when app starts
                    await NotificationService.shared.requestPermission()
                }
                .onChange(of: authViewModel.currentUser) { oldValue, newValue in
                    if let user = newValue {
                        // Configure notification service when user logs in
                        NotificationService.shared.configure(userId: user.id)
                    }
                }
        }
    }
}
