import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthService {
    static let shared = AuthService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    private init() {}

    var currentUserId: String? {
        auth.currentUser?.uid
    }

    var isAuthenticated: Bool {
        auth.currentUser != nil
    }

    func signUp(email: String, password: String, displayName: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        let user = User(id: result.user.uid, email: email, displayName: displayName)
        try await saveUser(user)
        return user
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        guard let user = try await fetchUser(id: result.user.uid) else {
            throw AuthError.userNotFound
        }
        return user
    }

    func signOut() throws {
        try auth.signOut()
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

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .notAuthenticated:
            return "Not authenticated"
        }
    }
}
