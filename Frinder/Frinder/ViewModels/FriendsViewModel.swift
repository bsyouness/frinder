import Foundation

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let friendService = FriendService.shared
    private var userId: String?

    func setup(userId: String) {
        self.userId = userId
        friendService.startListeningToFriends(userId: userId)

        // Bind friends
        friendService.$friends
            .receive(on: DispatchQueue.main)
            .assign(to: &$friends)
    }

    func loadPendingRequests() async {
        guard let userId = userId else { return }

        do {
            pendingRequests = try await friendService.fetchPendingRequests(userId: userId)
        } catch {
            print("Error loading pending requests: \(error)")
        }
    }

    func sendFriendRequest(email: String) async {
        guard let userId = userId else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await friendService.sendFriendRequest(from: userId, to: email)
            successMessage = "Friend request sent!"
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func acceptRequest(from user: User) async {
        guard let userId = userId else { return }

        do {
            try await friendService.acceptFriendRequest(userId: userId, friendId: user.id)
            await loadPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(from user: User) async {
        guard let userId = userId else { return }

        do {
            try await friendService.declineFriendRequest(userId: userId, friendId: user.id)
            await loadPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friend: Friend) async {
        guard let userId = userId else { return }

        do {
            try await friendService.removeFriend(userId: userId, friendId: friend.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
