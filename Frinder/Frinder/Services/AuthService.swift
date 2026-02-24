import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import FirebaseStorage
import GoogleSignIn
import AuthenticationServices

class AuthService {
    static let shared = AuthService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    private init() {}

    var clientID: String? {
        FirebaseApp.app()?.options.clientID
    }

    var currentUserId: String? {
        auth.currentUser?.uid
    }

    var isAuthenticated: Bool {
        auth.currentUser != nil
    }

    var isEmailPasswordUser: Bool {
        auth.currentUser?.providerData.contains(where: { $0.providerID == "password" }) ?? false
    }

    var isEmailVerified: Bool {
        auth.currentUser?.isEmailVerified ?? false
    }

    func sendEmailVerification() async throws {
        guard let user = auth.currentUser else { throw AuthError.notAuthenticated }
        let idToken = try await user.getIDToken()

        let url = URL(string: "https://us-central1-frinder-e1b07.cloudfunctions.net/resendVerificationEmail")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    func reloadUser() async throws {
        guard let user = auth.currentUser else { throw AuthError.notAuthenticated }
        try await user.reload()
    }

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = User(id: result.user.uid, email: email, displayName: displayName)
            try await saveUser(user)
            return user
        } catch let error as NSError {
            // Check if email already exists with different provider
            if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                let providers = try? await auth.fetchSignInMethods(forEmail: email)
                if let providers = providers, !providers.isEmpty, !providers.contains("password") {
                    throw AuthError.differentProvider(providers: providers)
                }
            }
            throw error
        }
    }

    func signIn(email: String, password: String) async throws -> User {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)

            // Try to fetch existing user, create if missing (e.g., if Firestore was reset)
            if let user = try await fetchUser(id: result.user.uid) {
                return user
            }

            // User exists in Auth but not Firestore - recreate document
            let displayName = result.user.displayName ?? email.components(separatedBy: "@").first ?? "User"
            let user = User(id: result.user.uid, email: email, displayName: displayName)
            try await saveUser(user)
            return user
        } catch {
            // Check if this email is registered with a different provider
            let providers = try? await auth.fetchSignInMethods(forEmail: email)
            if let providers = providers, !providers.isEmpty, !providers.contains("password") {
                throw AuthError.differentProvider(providers: providers)
            }
            throw error
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> User {
        guard let clientID = clientID else {
            throw AuthError.configurationError
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await auth.signIn(with: credential)

        // Check if user exists in Firestore
        if let existingUser = try await fetchUser(id: authResult.user.uid) {
            return existingUser
        }

        // Create new user
        let displayName = result.user.profile?.name ?? "User"
        let email = result.user.profile?.email ?? ""
        let user = User(id: authResult.user.uid, email: email, displayName: displayName)
        try await saveUser(user)
        return user
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws -> User {
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: credential.fullName
        )

        let authResult = try await auth.signIn(with: firebaseCredential)

        if let existingUser = try await fetchUser(id: authResult.user.uid) {
            return existingUser
        }

        // New Apple user — name is only provided on the first sign-in
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let email = credential.email ?? authResult.user.email ?? ""
        let user = User(
            id: authResult.user.uid,
            email: email,
            displayName: fullName.isEmpty ? "Apple User" : fullName
        )
        try await saveUser(user)
        return user
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try auth.signOut()
    }

    func sendPasswordReset(email: String) async throws {
        let normalised = email.lowercased().trimmingCharacters(in: .whitespaces)
        let providers = try? await auth.fetchSignInMethods(forEmail: normalised)
        if let providers, !providers.isEmpty, !providers.contains("password") {
            throw AuthError.differentProvider(providers: providers)
        }
        try await auth.sendPasswordReset(withEmail: normalised)
    }

    func saveUser(_ user: User) async throws {
        let data = try Firestore.Encoder().encode(user)
        try await db.collection("users").document(user.id).setData(data)
    }

    func fetchUser(id: String) async throws -> User? {
        let document = try await db.collection("users").document(id).getDocument()
        guard document.exists else { return nil }
        return try document.data(as: User.self)
    }

    func fetchCurrentUser() async throws -> User? {
        guard let userId = currentUserId else { return nil }
        return try await fetchUser(id: userId)
    }

    func searchUsers(query: String) async throws -> [User] {
        guard !query.isEmpty else { return [] }

        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: query.lowercased())
            .limit(to: 10)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: User.self)
        }.filter { $0.id != currentUserId }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let user = auth.currentUser, let uid = currentUserId else {
            throw AuthError.notAuthenticated
        }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        try await db.collection("users").document(uid).updateData(["displayName": name])
    }

    func updateAvatar(_ imageData: Data) async throws -> String {
        guard let uid = currentUserId else {
            throw AuthError.notAuthenticated
        }
        let storageRef = Storage.storage().reference().child("avatars/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString
        try await db.collection("users").document(uid).updateData(["avatarURL": urlString])
        return urlString
    }

    func updatePassword(_ newPassword: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.notAuthenticated
        }
        do {
            try await user.updatePassword(to: newPassword)
        } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue {
            throw AuthError.requiresRecentLogin
        }
    }

    func addAuthStateListener(_ listener: @escaping (Bool) -> Void) -> AuthStateDidChangeListenerHandle {
        return auth.addStateDidChangeListener { _, user in
            listener(user != nil)
        }
    }

    func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }
}

enum AuthError: LocalizedError {
    case userNotFound
    case notAuthenticated
    case configurationError
    case missingToken
    case differentProvider(providers: [String])
    case requiresRecentLogin

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .notAuthenticated:
            return "Not authenticated"
        case .configurationError:
            return "Google Sign-In configuration error"
        case .missingToken:
            return "Failed to get authentication token"
        case .differentProvider(let providers):
            let method = providers.first.map { providerDisplayName($0) } ?? "another method"
            return "This email is registered with \(method). Please sign in using that method instead."
        case .requiresRecentLogin:
            return "Please sign out and sign back in before changing your password."
        }
    }

    private func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "google.com":
            return "Google"
        case "apple.com":
            return "Apple"
        case "facebook.com":
            return "Facebook"
        case "password":
            return "email and password"
        default:
            return provider
        }
    }
}
