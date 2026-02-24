import Foundation
import FirebaseAuth
import Combine
import UIKit
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isOffline = false
    @Published var needsEmailVerification = false

    private let authService = AuthService.shared

    /// Get the current user ID from Firebase Auth (works even when offline)
    var currentUserId: String? {
        authService.currentUserId
    }

    var isEmailPasswordUser: Bool {
        authService.isEmailPasswordUser
    }
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            authService.removeAuthStateListener(handle)
        }
    }

    private func setupAuthStateListener() {
        authStateHandle = authService.addAuthStateListener { [weak self] isAuthenticated in
            Task { @MainActor in
                self?.isAuthenticated = isAuthenticated
                if isAuthenticated {
                    await self?.fetchCurrentUser()
                    // Restore verification gate on app restart for unverified email/password accounts
                    if let self, self.authService.isEmailPasswordUser && !self.authService.isEmailVerified {
                        self.needsEmailVerification = true
                    }
                } else {
                    self?.currentUser = nil
                    self?.needsEmailVerification = false
                }
            }
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signUp(
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
            currentUser = user
            isAuthenticated = true
            // Verification email is sent by the Cloud Function trigger (onUserCreate)
            needsEmailVerification = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signIn(
                email: email.lowercased().trimmingCharacters(in: .whitespaces),
                password: password
            )
            currentUser = user
            isAuthenticated = true
            if !authService.isEmailVerified {
                needsEmailVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get root view controller"
            isLoading = false
            return
        }

        do {
            let user = try await authService.signInWithGoogle(presenting: rootViewController)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signInWithApple(credential: credential, rawNonce: rawNonce)
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        // Stop Firestore listeners before signing out to prevent "client is offline" errors
        FriendService.shared.stopListening()

        // Remove FCM token before signing out
        Task {
            await NotificationService.shared.removeToken()
        }

        do {
            try authService.signOut()
            currentUser = nil
            isAuthenticated = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        do {
            try await authService.sendPasswordReset(email: trimmedEmail)
            print("Password reset email sent successfully to: \(trimmedEmail)")
            isLoading = false
            return true
        } catch {
            print("Password reset error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func checkEmailVerification() async -> Bool {
        do {
            try await authService.reloadUser()
            if authService.isEmailVerified {
                needsEmailVerification = false
                return true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    func resendVerificationEmail() async {
        do {
            try await authService.sendEmailVerification()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateDisplayName(_ name: String) async {
        do {
            try await authService.updateDisplayName(name)
            currentUser?.displayName = name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAvatar(_ imageData: Data) async {
        do {
            let url = try await authService.updateAvatar(imageData)
            currentUser?.avatarURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePassword(_ newPassword: String) async throws {
        try await authService.updatePassword(newPassword)
    }

    private func fetchCurrentUser() async {
        do {
            currentUser = try await authService.fetchCurrentUser()
            isOffline = false
        } catch {
            print("Error fetching user: \(error)")
            isOffline = true
        }
    }
}
