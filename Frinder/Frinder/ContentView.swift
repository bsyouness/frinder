import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.needsEmailVerification {
                    VerifyEmailView()
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authViewModel.isAuthenticated)
        .animation(.easeInOut, value: authViewModel.needsEmailVerification)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
