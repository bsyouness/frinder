import Foundation
import CoreLocation
import Combine

@MainActor
class RadarViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var deviceHeading: Double = 0
    @Published var devicePitch: Double = 0 // Tilt forward/backward in radians
    @Published var currentLocation: CLLocation?
    @Published var isLocationAuthorized = false
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    let landmarks = Landmark.allLandmarks
    var showLandmarks: Bool { AppSettings.shared.showLandmarks }

    /// Horizontal field of view in degrees (total angle visible on screen width)
    private let horizontalFOV: Double = 60.0
    /// Vertical field of view in degrees (total angle visible on screen height)
    private let verticalFOV: Double = 90.0
    /// Earth's radius in meters
    private let earthRadius: Double = 6_371_000.0

    /// Get landmarks that are within the current field of view
    var visibleLandmarks: [Landmark] {
        guard let userLocation = currentLocation else { return [] }
        return landmarks.filter { landmark in
            isWithinFieldOfView(bearing: landmark.bearing(from: userLocation.coordinate))
        }
    }

    /// Get friends that are within the current field of view
    var visibleFriends: [Friend] {
        guard let userLocation = currentLocation else { return [] }
        return friends.filter { friend in
            guard let bearing = friend.bearing(from: userLocation) else { return false }
            return isWithinFieldOfView(bearing: bearing)
        }
    }

    /// Check if a bearing is within the current horizontal field of view
    private func isWithinFieldOfView(bearing: Double) -> Bool {
        let halfFOV = horizontalFOV / 2.0
        let relativeAngle = normalizeAngle(bearing - deviceHeading)
        return abs(relativeAngle) <= halfFOV
    }

    /// Check if item is within vertical field of view based on pitch
    private func isWithinVerticalFOV() -> Bool {
        let halfFOV = verticalFOV / 2.0 * .pi / 180.0
        let neutralPitch = Double.pi / 2.0 // Phone held upright
        let pitchDelta = devicePitch - neutralPitch
        return abs(pitchDelta) <= halfFOV
    }

    /// Normalize angle to -180 to 180 range
    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle
        while normalized > 180 { normalized -= 360 }
        while normalized < -180 { normalized += 360 }
        return normalized
    }

    /// Calculate a scaled elevation angle for a straight-line path to a point on Earth's surface
    /// True angle is compressed to fit on screen while preserving relative order
    /// Returns angle in radians (negative = below horizon)
    private func elevationAngle(forDistance distance: Double) -> Double {
        // Central angle on Earth's surface (great circle)
        let centralAngle = distance / earthRadius
        // True elevation would be -centralAngle/2, but that's too extreme for display
        // Scale it down: map 0-20000km to 0-20° below horizon
        let maxDisplayAngle: Double = 20.0 * .pi / 180.0  // 20 degrees max
        let maxDistance: Double = 20_000_000.0  // 20,000 km
        let normalized = min(distance / maxDistance, 1.0)
        return -normalized * maxDisplayAngle
    }

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

        // Bind pitch updates (tilt forward/backward)
        motionService.$pitch
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pitch in
                self?.devicePitch = pitch
            }
            .store(in: &cancellables)

        // Bind authorization status
        locationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthorizationStatus = status
                self?.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            }
            .store(in: &cancellables)

        // Bind friends from service
        friendService.$friends
            .receive(on: DispatchQueue.main)
            .assign(to: &$friends)
    }

    func requestLocationAuthorization() {
        locationService.requestAuthorization()
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
    /// Maps horizontal angle to X position, combines pitch and dip angle for Y position
    func friendPosition(for friend: Friend, in size: CGSize) -> CGPoint {
        guard let userLocation = currentLocation,
              let bearing = friend.bearing(from: userLocation),
              let distance = friend.distance(from: userLocation) else {
            return .zero
        }

        // Calculate horizontal position based on relative bearing
        let relativeAngle = normalizeAngle(bearing - deviceHeading)
        let halfHFOV = horizontalFOV / 2.0
        // Map angle linearly: -halfFOV -> 0, 0 -> center, +halfFOV -> width
        let normalizedX = (relativeAngle + halfHFOV) / horizontalFOV
        let x = normalizedX * size.width

        // Calculate vertical position based on true 3D direction to target
        // elevationAngle: the true angle below horizontal for straight-line path through Earth
        let elevation = elevationAngle(forDistance: distance)

        // devicePitch: with xMagneticNorthZVertical, 0 = upright, negative = tilted forward (looking down)
        // We want: looking down should reveal things below horizon (negative elevation)
        let halfVFOV = verticalFOV / 2.0 * .pi / 180.0

        // Relative angle: where is the object relative to where phone is pointing?
        // Phone pointing at horizon (pitch=0) + object at -30° elevation = object appears below center
        let relativeElevation = elevation - devicePitch

        // Map to screen: negative relative elevation = below center = higher Y value
        let normalizedY = 0.5 - (relativeElevation / (2.0 * halfVFOV))
        let y = normalizedY * size.height

        return CGPoint(x: x, y: y)
    }

    /// Calculate the position of a landmark on the radar view
    /// Maps horizontal angle to X position, elevation angle to Y position
    func landmarkPosition(for landmark: Landmark, in size: CGSize) -> CGPoint {
        guard let userLocation = currentLocation else {
            return .zero
        }

        let bearing = landmark.bearing(from: userLocation.coordinate)
        let distance = landmark.distance(from: userLocation.coordinate)

        // Calculate horizontal position based on relative bearing
        let relativeAngle = normalizeAngle(bearing - deviceHeading)
        let halfHFOV = horizontalFOV / 2.0
        // Map angle linearly: -halfFOV -> 0, 0 -> center, +halfFOV -> width
        let normalizedX = (relativeAngle + halfHFOV) / horizontalFOV
        let x = normalizedX * size.width

        // Calculate vertical position based on true 3D direction to target
        // elevationAngle: the true angle below horizontal for straight-line path through Earth
        let elevation = elevationAngle(forDistance: distance)

        // devicePitch: with xMagneticNorthZVertical, 0 = upright, negative = tilted forward (looking down)
        let halfVFOV = verticalFOV / 2.0 * .pi / 180.0

        // Relative angle: where is the object relative to where phone is pointing?
        let relativeElevation = elevation - devicePitch

        // Map to screen: negative relative elevation = below center = higher Y value
        let normalizedY = 0.5 - (relativeElevation / (2.0 * halfVFOV))
        let y = normalizedY * size.height

        return CGPoint(x: x, y: y)
    }

    /// Get distance to landmark formatted as string
    func landmarkDistance(for landmark: Landmark) -> String? {
        guard let userLocation = currentLocation else { return nil }
        let distance = landmark.distance(from: userLocation.coordinate)
        return AppSettings.shared.distanceUnit.format(meters: distance)
    }

    /// Cluster overlapping landmarks based on screen positions
    func clusterLandmarks(in size: CGSize, threshold: CGFloat = 60) -> [LandmarkCluster] {
        let visible = visibleLandmarks
        guard !visible.isEmpty else { return [] }

        var clusters: [LandmarkCluster] = []
        var assigned = Set<String>()

        for landmark in visible {
            if assigned.contains(landmark.id) { continue }

            let position = landmarkPosition(for: landmark, in: size)
            var clusterLandmarks = [landmark]
            assigned.insert(landmark.id)

            // Find other landmarks that overlap with this one
            for other in visible {
                if assigned.contains(other.id) { continue }
                let otherPosition = landmarkPosition(for: other, in: size)
                let distance = hypot(position.x - otherPosition.x, position.y - otherPosition.y)
                if distance < threshold {
                    clusterLandmarks.append(other)
                    assigned.insert(other.id)
                }
            }

            // Sort landmarks in cluster by distance
            if let userLocation = currentLocation {
                clusterLandmarks.sort { l1, l2 in
                    l1.distance(from: userLocation.coordinate) < l2.distance(from: userLocation.coordinate)
                }
            }

            clusters.append(LandmarkCluster(landmarks: clusterLandmarks, position: position))
        }

        return clusters
    }
}

/// Represents a cluster of landmarks at a position
struct LandmarkCluster: Identifiable {
    let landmarks: [Landmark]
    let position: CGPoint

    /// Stable ID based on landmark IDs so SwiftUI preserves state across updates
    var id: String {
        landmarks.map { $0.id }.sorted().joined(separator: "-")
    }

    var isSingle: Bool { landmarks.count == 1 }
    var first: Landmark? { landmarks.first }
}
