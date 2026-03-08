import SwiftUI
import FirebaseCore
import GoogleSignIn
import AppTrackingTransparency

@main
struct FrinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await ATTrackingManager.requestTrackingAuthorization()
                }
            }
        }
    }
}
