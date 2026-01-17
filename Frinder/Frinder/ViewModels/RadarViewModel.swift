import Foundation
import CoreLocation
import Combine

@MainActor
class RadarViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var deviceHeading: Double = 0
    @Published var currentLocation: CLLocation?
    @Published var isLocationAuthorized = false

    let landmarks = Landmark.allLandmarks
    var showLandmarks: Bool { AppSettings.shared.showLandmarks }

    private let locationService = LocationService.shared
    private let motionService = MotionService.shared
    private let friendService = FriendService.shared
    private var cancellables = Set<AnyCancellable>()
    private var userId: String?

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind location updates
        locationService.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentLocation = location
                if let location = location, let userId = self?.userId {
                    Task {
                        try? await self?.updateUserLocation(location, userId: userId)
                    }
                }
            }
            .store(in: &cancellables)

        // Bind heading updates
        locationService.$currentHeading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heading in
                self?.deviceHeading = heading
            }
            .store(in: &cancellables)

        // Bind authorization status
        locationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .map { status in
                status == .authorizedWhenInUse || status == .authorizedAlways
            }
            .assign(to: &$isLocationAuthorized)

        // Bind friends from service
        friendService.$friends
            .receive(on: DispatchQueue.main)
            .assign(to: &$friends)
    }

    func startTracking(userId: String) {
        self.userId = userId
        locationService.requestAuthorization()
        locationService.startUpdatingLocation()
        locationService.startUpdatingHeading()
        motionService.startUpdates()
        friendService.startListeningToFriends(userId: userId)
    }

    func stopTracking() {
        locationService.stopUpdatingLocation()
        locationService.stopUpdatingHeading()
        motionService.stopUpdates()
        friendService.stopListening()
    }

    private func updateUserLocation(_ location: CLLocation, userId: String) async throws {
        let userLocation = UserLocation(coordinate: location.coordinate)
        try await friendService.updateLocation(userLocation, for: userId)
    }

    /// Calculate the position of a friend on the radar view
    /// Returns (x, y) as percentages from center (-1 to 1)
    func friendPosition(for friend: Friend, in size: CGSize) -> CGPoint {
        guard let userLocation = currentLocation,
              let bearing = friend.bearing(from: userLocation) else {
            return .zero
        }

        // Calculate angle relative to device heading
        let relativeAngle = (bearing - deviceHeading + 360).truncatingRemainder(dividingBy: 360)
        let angleRadians = relativeAngle * .pi / 180

        // Calculate distance factor (closer friends are more centered)
        let distance = friend.distance(from: userLocation) ?? 0
        let maxDistance: Double = 50000 // 50km max
        let normalizedDistance = min(distance / maxDistance, 1.0)

        // Use logarithmic scale for better distribution
        let radiusFactor = 0.2 + (log10(normalizedDistance * 9 + 1) * 0.8)

        let radius = min(size.width, size.height) / 2 * radiusFactor * 0.85

        // Calculate position (0 degrees = up, clockwise)
        let x = size.width / 2 + radius * sin(angleRadians)
        let y = size.height / 2 - radius * cos(angleRadians)

        return CGPoint(x: x, y: y)
    }

    /// Calculate the position of a landmark on the radar view
    /// Returns (x, y) as percentages from center (-1 to 1)
    func landmarkPosition(for landmark: Landmark, in size: CGSize) -> CGPoint {
        guard let userLocation = currentLocation else {
            return .zero
        }

        let bearing = landmark.bearing(from: userLocation.coordinate)

        // Calculate angle relative to device heading
        let relativeAngle = (bearing - deviceHeading + 360).truncatingRemainder(dividingBy: 360)
        let angleRadians = relativeAngle * .pi / 180

        // Calculate distance factor (closer landmarks are more centered)
        let distance = landmark.distance(from: userLocation.coordinate)
        let maxDistance: Double = 20000000 // 20,000km max (half earth circumference)
        let normalizedDistance = min(distance / maxDistance, 1.0)

        // Use logarithmic scale for better distribution
        let radiusFactor = 0.15 + (log10(normalizedDistance * 99 + 1) * 0.425)

        let radius = min(size.width, size.height) / 2 * radiusFactor * 0.9

        // Calculate position (0 degrees = up, clockwise)
        let x = size.width / 2 + radius * sin(angleRadians)
        let y = size.height / 2 - radius * cos(angleRadians)

        return CGPoint(x: x, y: y)
    }

    /// Get distance to landmark formatted as string
    func landmarkDistance(for landmark: Landmark) -> String? {
        guard let userLocation = currentLocation else { return nil }
        let distance = landmark.distance(from: userLocation.coordinate)
        return AppSettings.shared.distanceUnit.format(meters: distance)
    }
}
