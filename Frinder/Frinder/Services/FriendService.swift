import Foundation
import FirebaseFirestore
import Combine

class FriendService: ObservableObject {
    static let shared = FriendService()

    private let db = Firestore.firestore()
    private var locationListener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?

    @Published var friends: [Friend] = []

    private init() {}

    func updateLocation(_ location: UserLocation, for userId: String) async throws {
        let data: [String: Any] = [
            "location": [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "timestamp": Timestamp(date: location.timestamp)
            ],
            "lastUpdated": Timestamp(date: Date())
        ]
        try await db.collection("users").document(userId).updateData(data)
    }

    func sendFriendRequest(from senderId: String, to receiverEmail: String) async throws {
        // Find user by email
        let snapshot = try await db.collection("users")
            .whereField("email", isEqualTo: receiverEmail.lowercased())
            .limit(to: 1)
            .getDocuments()

        guard let receiverDoc = snapshot.documents.first else {
            throw FriendError.userNotFound
        }

        let receiverId = receiverDoc.documentID

        if receiverId == senderId {
            throw FriendError.cannotAddSelf
        }

        // Check if already friends
        let senderDoc = try await db.collection("users").document(senderId).getDocument()
        let senderData = senderDoc.data()
        let existingFriends = senderData?["friendIds"] as? [String] ?? []

        if existingFriends.contains(receiverId) {
            throw FriendError.alreadyFriends
        }

        // Add to pending requests
        try await db.collection("users").document(senderId).updateData([
            "friendRequestsSent": FieldValue.arrayUnion([receiverId])
        ])

        try await db.collection("users").document(receiverId).updateData([
            "friendRequestsReceived": FieldValue.arrayUnion([senderId])
        ])
    }

    func acceptFriendRequest(userId: String, friendId: String) async throws {
        let batch = db.batch()

        let userRef = db.collection("users").document(userId)
        let friendRef = db.collection("users").document(friendId)

        // Add each other as friends
        batch.updateData(["friendIds": FieldValue.arrayUnion([friendId])], forDocument: userRef)
        batch.updateData(["friendIds": FieldValue.arrayUnion([userId])], forDocument: friendRef)

        // Remove from pending requests
        batch.updateData(["friendRequestsReceived": FieldValue.arrayRemove([friendId])], forDocument: userRef)
        batch.updateData(["friendRequestsSent": FieldValue.arrayRemove([userId])], forDocument: friendRef)

        try await batch.commit()
    }

    func declineFriendRequest(userId: String, friendId: String) async throws {
        let batch = db.batch()

        let userRef = db.collection("users").document(userId)
        let friendRef = db.collection("users").document(friendId)

        batch.updateData(["friendRequestsReceived": FieldValue.arrayRemove([friendId])], forDocument: userRef)
        batch.updateData(["friendRequestsSent": FieldValue.arrayRemove([userId])], forDocument: friendRef)

        try await batch.commit()
    }

    func removeFriend(userId: String, friendId: String) async throws {
        let batch = db.batch()

        let userRef = db.collection("users").document(userId)
        let friendRef = db.collection("users").document(friendId)

        batch.updateData(["friendIds": FieldValue.arrayRemove([friendId])], forDocument: userRef)
        batch.updateData(["friendIds": FieldValue.arrayRemove([userId])], forDocument: friendRef)

        try await batch.commit()
    }

    func startListeningToFriends(userId: String) {
        // First listen to user's friend list changes
        friendsListener = db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data(),
                      let friendIds = data["friendIds"] as? [String],
                      !friendIds.isEmpty else {
                    self?.friends = []
                    return
                }

                // Listen to all friends' locations
                self.listenToFriendsLocations(friendIds: friendIds)
            }
    }

    private func listenToFriendsLocations(friendIds: [String]) {
        locationListener?.remove()

        locationListener = db.collection("users")
            .whereField(FieldPath.documentID(), in: friendIds)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else { return }

                self.friends = documents.compactMap { doc -> Friend? in
                    let data = doc.data()
                    guard let displayName = data["displayName"] as? String else { return nil }

                    var location: UserLocation? = nil
                    if let locationData = data["location"] as? [String: Any],
                       let lat = locationData["latitude"] as? Double,
                       let lon = locationData["longitude"] as? Double,
                       locationData["timestamp"] is Timestamp {
                        location = UserLocation(
                            coordinate: .init(latitude: lat, longitude: lon)
                        )
                    }

                    return Friend(
                        id: doc.documentID,
                        displayName: displayName,
                        avatarURL: data["avatarURL"] as? String,
                        location: location
                    )
                }
            }
    }

    func stopListening() {
        locationListener?.remove()
        friendsListener?.remove()
        locationListener = nil
        friendsListener = nil
    }

    func fetchPendingRequests(userId: String) async throws -> [User] {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        guard let data = userDoc.data(),
              let requestIds = data["friendRequestsReceived"] as? [String],
              !requestIds.isEmpty else {
            return []
        }

        let snapshot = try await db.collection("users")
            .whereField(FieldPath.documentID(), in: requestIds)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            try? doc.data(as: User.self)
        }
    }
}

enum FriendError: LocalizedError {
    case userNotFound
    case alreadyFriends
    case cannotAddSelf

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found with that email"
        case .alreadyFriends:
            return "You're already friends with this user"
        case .cannotAddSelf:
            return "You cannot add yourself as a friend"
        }
    }
}
