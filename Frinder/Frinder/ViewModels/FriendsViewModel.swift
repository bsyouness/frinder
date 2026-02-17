import Foundation
import CoreLocation
import Combine

@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var friendLocations: [String: String] = [:]

    private let friendService = FriendService.shared
    private var userId: String?
    private var lastGeocodedCoordinates: [String: CLLocationCoordinate2D] = [:]
    private var geocodingInProgress = Set<String>()
    private var cancellables = Set<AnyCancellable>()

    func friendLocationLabel(for friendId: String) -> String? {
        friendLocations[friendId]
    }

    private func reverseGeocodeIfNeeded(for friend: Friend) {
        guard let location = friend.location else { return }
        let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)

        if let lastCoord = lastGeocodedCoordinates[friend.id] {
            let lastLoc = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let newLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if lastLoc.distance(from: newLoc) < 1000 { return }
        }

        guard !geocodingInProgress.contains(friend.id) else { return }
        geocodingInProgress.insert(friend.id)
        lastGeocodedCoordinates[friend.id] = coord

        let friendId = friend.id
        let clLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        Task { [weak self] in
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
                if let placemark = placemarks.first {
                    let city = placemark.locality ?? placemark.administrativeArea ?? ""
                    let country = placemark.country ?? ""
                    let label = city.isEmpty ? country : (country.isEmpty ? city : "\(city), \(country)")
                    await MainActor.run {
                        self?.friendLocations[friendId] = label
                        self?.geocodingInProgress.remove(friendId)
                    }
                } else {
                    await MainActor.run {
                        self?.geocodingInProgress.remove(friendId)
                    }
                }
            } catch {
                await MainActor.run {
                    self?.geocodingInProgress.remove(friendId)
                }
            }
        }
    }

    func setup(userId: String) {
        self.userId = userId
        friendService.startListeningToFriends(userId: userId)

        // Bind friends
        friendService.$friends
            .receive(on: DispatchQueue.main)
            .assign(to: &$friends)

        // Also observe friends for geocoding
        friendService.$friends
            .receive(on: DispatchQueue.main)
            .sink { [weak self] friends in
                for friend in friends {
                    self?.reverseGeocodeIfNeeded(for: friend)
                }
            }
            .store(in: &cancellables)
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
        } catch let error as FriendError where error == .inviteSent {
            // inviteSent is a success case - user doesn't exist but invite was created
            successMessage = error.errorDescription
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
